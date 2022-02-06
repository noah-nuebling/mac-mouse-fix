//
// --------------------------------------------------------------------------
// PointerUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "PointerUtility.h"
@import Cocoa;
#import "Utility_Helper.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "CGSConnection.h"
#import "Utility_Transformation.h"

@implementation PointerUtility


/// Vars

static CGPoint _origin;
static CGPoint _originOffset;

static int _cgsConnection; /// This is used by private APIs to talk to the window server and do fancy shit like hiding the cursor from a background application
static NSCursor *_puppetCursor;
static NSImageView *_puppetCursorView;
static CGDirectDisplayID _display;

static CFMachPortRef eventTap;

/// + initialize

+ (void)initialize
{
    if (self == [PointerUtility class]) {
        
        /// Setup cgs stuff
        _cgsConnection = CGSMainConnectionID();
        
        /// Setup puppet cursor
        dispatch_sync(dispatch_get_main_queue(), ^{
            /// Views must be inited on the main thread. Not totally sure this makes sense.
            _puppetCursorView = [[NSImageView alloc] init];
        });
        
        /// Setup eventTap
        eventTap = [Utility_Transformation createEventTapWithLocation:kCGHIDEventTap mask:CGEventMaskBit(kCGEventMouseMoved) | CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventRightMouseDragged) | CGEventMaskBit(kCGEventOtherMouseDragged) option:kCGEventTapOptionListenOnly placement:kCGHeadInsertEventTap callback:mouseMovedCallback runLoop:CFRunLoopGetMain()];
        /// ^ Not sure which runLoop to use here
        
    }
}

/// Interface

+ (void)freezeEventDispatchPointWithCurrentLocation:(CGPoint)origin {
    
    /// Debug
    
    DDLogDebug(@"frozen dispatch point - init - at origin: %f, %f", origin.x, origin.y);
    
    /// Store
    _origin = origin;
    _originOffset = CGPointZero;
    
    /// Get display under mouse pointer
    CVReturn rt = [Utility_Helper display:&_display atPoint:_origin];
    if (rt != kCVReturnSuccess) DDLogWarn(@"Couldn't get display under mouse pointer in modifiedDrag");
    
    /// Draw puppet cursor before hiding
    drawPuppetCursor(YES, YES);
    
    /// Decrease delay after warping
    ///     But only as much so that it doesn't break `CGWarpMouseCursorPosition(()` ability to stop cursor by calling repeatedly
    ///     This changes the timeout globally for many events, so we need to reset this after the drag is deactivated!
    setSuppressionInterval(kMFEventSuppressionIntervalForStoppingCursor);
    
    /// Hide cursor
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.02), dispatch_get_main_queue(), ^{
        /// The puppetCursor will only be drawn after a delay, while hiding the mouse pointer is really fast.
        ///     This leads to a little flicker when the puppetCursor is not yet drawn, but the real cursor is already hidden.
        ///     Not sure why this happens. But adding a delay of 0.02 before hiding makes it look seamless.
        
        [Utility_Transformation hideMousePointer:YES];
    });
    
    /// ^ TODO: We used to use _drag->queue instead of dispatch_get_main_queue(). Check if this works as well.
    
    /// Enable eventTap
    CGEventTapEnable(eventTap, true);
}

CGEventRef _Nullable mouseMovedCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    /// Catch special events
    if (type == kCGEventTapDisabledByTimeout) {
        /// Re-enable on timeout (Not sure if this ever times out)
        DDLogInfo(@"PointerUtility eventTap timed out. Re-enabling.");
        CGEventTapEnable(eventTap, true);
        return event;
    } else if (type == kCGEventTapDisabledByUserInput) {
        DDLogInfo(@"PointerUtility eventTap disabled by user input.");
        return event;
    }
    
    /// Get delta
    int64_t dx = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
    int64_t dy = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);
    
    _originOffset.x += dx;
    _originOffset.y += dy;
    
    /// Debug
    DDLogDebug(@"frozen dispatch point - move - with delta: %f, %f", _originOffset.x, _originOffset.y);
    
    /// Warp pointer to origin to prevent cursor movement
    ///     This only works when the suppressionInterval is a certain size, and that will cause a slight stutter / delay until the mouse starts moving againg when we deactivate. So this isn't optimal
    CGWarpMouseCursorPosition(_origin);
    //        CGWarpMouseCursorPosition(_drag->origin);
    /// ^ Move pointer to origin instead of usageOrigin to make scroll events dispatch there - would be nice but that moves the pointer, which creates events which will feed back into our eventTap and mess everything up (even though `CGWarpMouseCursorPosition` docs say that it doesn't create events??)
    ///     I gues we'll just have to make the usageThreshold small instead
    
    /// Disassociate pointer to prevent cursor movements
    ///     This makes the inputDeltas weird I feel. Better to freeze pointer through calling CGWarpMouseCursorPosition repeatedly.
    //        CGAssociateMouseAndMouseCursorPosition(NO);
    
    /// Draw puppet cursor
    drawPuppetCursor(YES, NO);
    
    return event;
}

+ (void)unfreezeEventDispatchPoint {
    
    /// Get puppet Cursor position
    CGPoint puppetPos = puppetCursorPosition();
    
    /// Disable eventTap
    /// TODO: Think about the order of getting pos, unfreezing, and disabling event tap.
    CGEventTapEnable(eventTap, false);
    
    /// Set suppression interval for warping
    setSuppressionInterval(kMFEventSuppressionIntervalForWarping);
    
    /// Warp actual cursor to position of puppet cursor
    CGWarpMouseCursorPosition(puppetPos);
    
    /// Show mouse pointer again
    [Utility_Transformation hideMousePointer:NO];
    
    /// Undraw puppet cursor
    drawPuppetCursor(NO, NO);
    
    /// Reset suppression interval to default
    setSuppressionInterval(kMFEventSuppressionIntervalDefault);
}

#pragma mark - Helper functions

/// Event suppression

typedef enum {
    kMFEventSuppressionIntervalForWarping,
    kMFEventSuppressionIntervalForStoppingCursor,
    kMFEventSuppressionIntervalForStartingMomentumScroll,
    kMFEventSuppressionIntervalDefault,
} MFEventSuppressionInterval;

static MFEventSuppressionInterval _previousMFSuppressionInterval = kMFEventSuppressionIntervalDefault;
static CFTimeInterval _defaultSuppressionInterval = 0.25;
void setSuppressionInterval(MFEventSuppressionInterval mfInterval) {
    /// We use CGWarpMousePointer to keep the pointer from moving during simulated touchScroll.
    ///     However, after that, the cursor will freeze for like half a second which is annoying.
    ///     To avoid this we need to set the CGEventSuppressionInterval to 0
    ///         (I also looked into permitting all (mouse) events during suppression using `CGEventSourceSetLocalEventsFilterDuringSuppressionState()`. However, it doesn't remove the delay after warping unfortunately. Only `CGEventSourceGetLocalEventsSuppressionInterval()` works.)
    ///     Butttt I just found that whe you set the suppressionInterval to zero then CGWarpMouseCursorPosition doesn't work at all anymore..., so maybe a small value like 0.1? ... 0.05 seems to be the smallest value that fully stops pointer from moving when repeatedly calling CGWarpMouseCursorPosition()
    ///         I thought about using CGAssociateMouseAndMouseCursorPosition(), but in the end we'll still have to use the warp when deactivating to get the real pointer position to where the puppetPointerPosition is. And that's where the delay comes from. Also when using CGAssociateMouseAndMouseCursorPosition() the deltas become really inaccurate and irratic, overdriving the momentumScroll. So there's no benefit to using CGAssociateMouseAndMouseCursorPosition().
    /// Src: https://stackoverflow.com/questions/8215413/why-is-cgwarpmousecursorposition-causing-a-delay-if-it-is-not-what-is
    
    /// Get source
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    
    /// Store default
    if (_previousMFSuppressionInterval == kMFEventSuppressionIntervalDefault) {
        _defaultSuppressionInterval = CGEventSourceGetLocalEventsSuppressionInterval(src);
    }
    
    /// Get interval
    double interval;
    if (mfInterval == kMFEventSuppressionIntervalForStoppingCursor) {
        interval = 0.07; /// 0.05; /// Can't be 0 or else repeatedly calling CGWarpMouseCursorPosition() won't work for stopping the cursor
    } else if (mfInterval == kMFEventSuppressionIntervalForStartingMomentumScroll) {
        assert(false); /// Not using this anymore
        interval = 0.01;
    } else if (mfInterval == kMFEventSuppressionIntervalDefault) {
        interval = _defaultSuppressionInterval;
    } else if (mfInterval == kMFEventSuppressionIntervalForWarping) {
        interval = 0.000;
    } else {
        assert(false);
    }
    
    /// Set new suppressionInterval
    CGEventSourceSetLocalEventsSuppressionInterval(src, interval);
    
    /// Analyze suppresionInterval
    CFTimeInterval intervalResult = CGEventSourceGetLocalEventsSuppressionInterval(src);
    DDLogDebug(@"Event suppression interval: %f", intervalResult);
    
    /// Store previous mfInterval
    _previousMFSuppressionInterval = mfInterval;
}

void setSuppressionIntervalWithTimeInterval(CFTimeInterval interval) {
    
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    /// Set new suppressionInterval
    CGEventSourceSetLocalEventsSuppressionInterval(src, interval);
}

/// Puppet cursor

void drawPuppetCursor(BOOL draw, BOOL fresh) {
    
    /// Define workload block
    ///     (Graphics code always needs to be executed on main)
    
    void (^workload)(void) = ^{
        
        if (!draw) {
            _puppetCursorView.alphaValue = 0; /// Make the puppetCursor invisible
            return;
        }
        
        if (_puppetCursor == nil) {
            /// Init puppetCursor
            ///     Might be better to do this during + initialize function
            _puppetCursor = NSCursor.arrowCursor;
        }
        
        if (fresh) {
            /// Use the currently displaying cursor, instead of the default arrow cursor
            //            _puppetCursor = NSCursor.currentSystemCursor;
            
            /// Store cursor image into puppet view
            _puppetCursorView.image = _puppetCursor.image;
        }
        
        /// Get puppet pointer location
        CGPoint loc = puppetCursorPosition();
        
        /// Subtract hotspot to get puppet image loc
        CGPoint hotspot = _puppetCursor.hotSpot;
        CGPoint imageLoc = CGPointMake(loc.x - hotspot.x, loc.y - hotspot.y);
        
        /// Unflip coordinates to be compatible with Cocoa
        NSRect puppetImageFrame = NSMakeRect(imageLoc.x, imageLoc.y, _puppetCursorView.image.size.width, _puppetCursorView.image.size.height);
        NSRect puppetImageFrameUnflipped = [SharedUtility quartzToCocoaScreenSpace:puppetImageFrame];
        
        
        if (fresh) {
            /// Draw puppetCursor
            [ScreenDrawer.shared drawWithView:_puppetCursorView atFrame:puppetImageFrameUnflipped onScreen:NSScreen.mainScreen];
        } else {
            /// Reposition  puppet cursor!
            [ScreenDrawer.shared moveWithView:_puppetCursorView toOrigin:puppetImageFrameUnflipped.origin];
        }
        
        /// Unhide puppet cursor
        _puppetCursorView.alphaValue = 1;
    };
    
    /// Make sure workload is executed on main thread
    
    if (NSThread.isMainThread) {
        workload();
    } else {
        dispatch_sync(dispatch_get_main_queue(), workload);
    }
}

CGPoint puppetCursorPosition(void) {
    
    /// Get base pos
    CGPoint pos = CGPointMake(_origin.x + _originOffset.x, _origin.y + _originOffset.y);
    
    /// Clip to screen bounds
    CGRect screenSize = CGDisplayBounds(_display);
    pos.x = CLIP(pos.x, CGRectGetMinX(screenSize), CGRectGetMaxX(screenSize));
    pos.y = CLIP(pos.y, CGRectGetMinY(screenSize), CGRectGetMaxY(screenSize));
    
    /// Clip originOffsets to screen bounds
    ///     Not sure if good idea. Origin offset is also used for other important stuff
    
    /// return
    return pos;
}


@end
