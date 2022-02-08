//
// --------------------------------------------------------------------------
// PointerFreeze.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "PointerFreeze.h"
@import Cocoa;
#import "HelperUtility.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "CGSConnection.h"
#import "TransformationUtility.h"

@implementation PointerFreeze


/// Vars

static CGPoint _origin;
//static CGPoint _originOffset;
static CGPoint _puppetCursorPosition;

static int _cgsConnection; /// This is used by private APIs to talk to the window server and do fancy shit like hiding the cursor from a background application
static NSCursor *_puppetCursor;
static NSImageView *_puppetCursorView;
static CGDirectDisplayID _display;

static CFMachPortRef _eventTap;

static dispatch_queue_t _queue;

/// + initialize

+ (void)initialize
{
    if (self == [PointerFreeze class]) {
        
        /// Setup cgs stuff
        _cgsConnection = CGSMainConnectionID();
        
        /// Setup puppet cursor
        dispatch_sync(dispatch_get_main_queue(), ^{
            /// Views must be inited on the main thread. Not totally sure this makes sense.
            _puppetCursorView = [[NSImageView alloc] init];
        });
        
        /// Setup queue
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, -1);
        _queue = dispatch_queue_create("com.nuebling.mac-mouse-fix.helper.pointer", attr);
        
        /// Setup eventTap
        dispatch_sync(_queue, ^{
            _eventTap = [TransformationUtility createEventTapWithLocation:kCGHIDEventTap mask:CGEventMaskBit(kCGEventMouseMoved) | CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventRightMouseDragged) | CGEventMaskBit(kCGEventOtherMouseDragged) option:kCGEventTapOptionListenOnly placement:kCGHeadInsertEventTap callback:mouseMovedCallback runLoop:CFRunLoopGetMain()];
        });
        /// ^ It seems like only CFRunLoopGetMain() works here. With CFRunLoopGetCurrent() (and without dispatching to a queue) the callback is never called. Not sure why.
    }
}

/// Interface

+ (void)freezeEventDispatchPointWithCurrentLocation:(CGPoint)origin {
    
    /// Lock
    ///     Not sure if necessary to lock, since we're starting the eventTap at the very end anyways.
    dispatch_sync(_queue, ^{
        
        /// Debug
        
        DDLogDebug(@"frozen dispatch point - init - at origin: %f, %f", origin.x, origin.y);
        
        /// Store
        _origin = origin;
        _puppetCursorPosition = origin;
        
        /// Get display under mouse pointer
        CVReturn rt = [HelperUtility display:&_display atPoint:_origin];
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
            
            [TransformationUtility hideMousePointer:YES];
        });
        
        /// ^ TODO: We used to use _drag->queue instead of dispatch_get_main_queue(). Check if this works as well.
        
        /// Enable eventTap
        CGEventTapEnable(_eventTap, true);
    });
}

CGEventRef _Nullable mouseMovedCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    /// Catch special events
    if (type == kCGEventTapDisabledByTimeout) {
        /// Re-enable on timeout (Not sure if this ever times out)
        DDLogInfo(@"PointerUtility eventTap timed out. Re-enabling.");
        CGEventTapEnable(_eventTap, true);
        return event;
    } else if (type == kCGEventTapDisabledByUserInput) {
        DDLogInfo(@"PointerUtility eventTap disabled by user input.");
        return event;
    }
    
    /// Get deltas
    ///     Have to get delta's before dispatching async, otherwise they won't be correct
    int64_t dx = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
    int64_t dy = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);
    
    /// Lock
    
    dispatch_async(_queue, ^{
        
        /// Debug
        DDLogDebug(@"frozen dispatch point - move - with delta: %lld, %lld", dx, dy);
        
        /// Check interrupt
        if (!CGEventTapIsEnabled(_eventTap)) {
            /// More debug
            DDLogDebug(@"frozen dispatch point - actually don't move");
            return;
        }
        
        /// Update origin offset
        updatePuppetCursorPosition(dx, dy);
        
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
        
    });

   return NULL;
}

+ (void)unfreezeEventDispatchPoint {
    
    /// Lock
    ///     Not sure whether to use sync or async here
    
    dispatch_async(_queue, ^{
        
        DDLogDebug(@"frozen dispatch point - unfreeze");
        
        /// Disable eventTap
        /// Think about the order of getting pos, unfreezing, and disabling event tap. -> I think it doesn't matter since everything is locked.
        CGEventTapEnable(_eventTap, false);
        
        /// Set suppression interval for warping
        setSuppressionInterval(kMFEventSuppressionIntervalForWarping);
        
        /// Warp actual cursor to position of puppet cursor
        CGWarpMouseCursorPosition(_puppetCursorPosition);
        
        /// Show mouse pointer again
        [TransformationUtility hideMousePointer:NO];
        
        /// Undraw puppet cursor
        drawPuppetCursor(NO, NO);
        
        /// Reset suppression interval to default
        setSuppressionInterval(kMFEventSuppressionIntervalDefault);
    });
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
        
        CGPoint loc = _puppetCursorPosition;
        
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

void updatePuppetCursorPosition(int64_t dx, int64_t dy) {
    
    /// Store in local var
    ///     for easier readability
    CGPoint pos = _puppetCursorPosition;
    
    /// Add delta to current puppet pos
    pos.x += dx;
    pos.y += dy;
    
    /// Clip puppet pos to screen bounds
    CGRect screenBounds = CGDisplayBounds(_display);
    pos.x = CLIP(pos.x, CGRectGetMinX(screenBounds), CGRectGetMaxX(screenBounds)-1);
    pos.y = CLIP(pos.y, CGRectGetMinY(screenBounds), CGRectGetMaxY(screenBounds)-1);
    
    /// Write to global var
    _puppetCursorPosition = pos;
}

@end
