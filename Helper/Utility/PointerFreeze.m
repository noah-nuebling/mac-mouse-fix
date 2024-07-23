//
// --------------------------------------------------------------------------
// PointerFreeze.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

///
/// TODO: Build a failsafe so users never get stuck with a frozen pointer.
///     - July 2024 - I think I just got stuck with a 'frozen' pointer (it still moved, but clicking anything didn't work and sometimes the pointer teleported to the middle of the screen) I couldn't trace back how this issue happened, and it seems to be really rare, but I think it would be good to give some reliable way to the user for ending pointer freeze in case it gets stuck. For example we could end the freeze on left-click, or perhaps we could build some vaildation e.g. assert that the pointer is not frozen (aka `_coolEventTapIsEnabled == YES`) before freeze() is called.
///

#import "PointerFreeze.h"
@import Cocoa;
#import "HelperUtility.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "CGSConnection.h"
#import "ModificationUtility.h"
#import "GlobalEventTapThread.h"
#import "NSScreen+Additions.h"
@import CoreMedia;

@implementation PointerFreeze

/// Vars

static CGPoint _origin;
static CGPoint _puppetCursorPosition;

static BOOL _keepPointerMoving;

static int _cgsConnection; /// This is used by private APIs to talk to the window server and do fancy shit like hiding the cursor from a background application
static NSCursor *_puppetCursor;
static NSImageView *_puppetCursorView;
static CGDirectDisplayID _display;

static CFMachPortRef _eventTap;
static Boolean _coolEventTapIsEnabled; /// CGEventTapIsEnabled() is pretty slow, so we're using this instead

static dispatch_queue_t _queue;

static CFTimeInterval _lastEventTimestamp;
static int64_t _lastEventDelta;

/// + initialize

+ (void)load_Manual {
    /// We made this load instead of initialize, so that there isn't a large delay when using it for the first time.
    ///     This delay would cause the pointer to jump back to a previous position when using this for twoFingerModifiedDrag
    ///     For the same reason we made ScreenDrawer use load instead of init. (I think ScreenDrawer was the real bottleneck because it creates an NSWindow which I think is pretty slow)
    ///     -> I hope this doesn't make starting the helper super slow.
    ///         Also if the user doesn't have twoFingerSwipe (the only thing that currently uses ScreenDrawer) set up, then it's unnecessary to load ScreenDrawer... Is there a better solution?
    ///         Idea for better(?) solution 1: Create coolInit function with dispatch_once and call it when some feature that uses this is detected in the config -> That's a horrible solution
    ///         Idea 2: Fetch up-to-date pointer position after initializing -> Worth a shot. But the current solution using load_Manual seems fast enough.
    ///
    
    if (self == [PointerFreeze class]) {
        
        /// Setup cgs stuff
        _cgsConnection = CGSMainConnectionID();
        
        /// Setup queue
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, -1);
        _queue = dispatch_queue_create("com.nuebling.mac-mouse-fix.helper.pointer", attr);
        
        if (NSThread.isMainThread) {
            _puppetCursorView = [[NSImageView alloc] init];
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                /// Setup puppet cursor
                _puppetCursorView = [[NSImageView alloc] init];
            });
        }
        
        /// Setup eventTap
        ///     Using a listenOnly tap would be more appropriate but they sometimes behave weirdly
        _eventTap = [ModificationUtility createEventTapWithLocation:kCGHIDEventTap mask:CGEventMaskBit(kCGEventMouseMoved) | CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventRightMouseDragged) | CGEventMaskBit(kCGEventOtherMouseDragged) option:kCGEventTapOptionDefault placement:kCGHeadInsertEventTap callback:mouseMovedCallback runLoop:GlobalEventTapThread.runLoop];
    }
}

// MARK: Interface

+ (void)freezeEventDispatchPointAtPosition:(CGPoint)origin {
    /// Freezes the dispatch point for CGEvents in place while making it appear to the user as if the they are still controlling the pointer.
    ///     This is achieved through freezing the actual pointer in place, then making the actual pointer invisible, and then creating a fake 'puppet' pointer and letting the user move that around.
    /// `origin` should be the current pointer position. Not sure what happens if you choose another location
    
    
    [self freezeAtPosition:origin keepPointerMoving:YES];
}

+ (void)freezePointerAtPosition:(CGPoint)origin {
    /// Freezes the dispatch point for CGEvents in place while making it appear to the user as if the they are still controlling the pointer.
    ///     This is achieved through freezing the actual pointer in place, then making the actual pointer invisible, and then creating a fake 'puppet' pointer and letting the user move that around.
    /// `origin` should be the current pointer position. Not sure what happens if you choose another location
    
    
    [self freezeAtPosition:origin keepPointerMoving:NO];
}

+ (void)freezeAtPosition:(CGPoint)origin keepPointerMoving:(BOOL)keepPointerMoving {
    /// Internal helper function
    
    /// Lock
    ///     Not sure if necessary to lock, since we're starting the eventTap at the very end anyways.
    dispatch_sync(_queue, ^{
        
        /// Debug
        DDLogDebug(@"PointerFreeze - freezing");
        
        /// Store
        _origin = origin;
        _keepPointerMoving = keepPointerMoving;
        
        /// Decrease delay after warping
        ///     But only as much so that it doesn't break `CGWarpMouseCursorPosition(()` ability to stop cursor by calling repeatedly
        ///     This changes the timeout globally for many events, so we need to reset this after the drag is deactivated!
        setSuppressionInterval(kMFEventSuppressionIntervalForStoppingCursor);
        
        /// Enable eventTap
        CGEventTapEnable(_eventTap, true);
        _coolEventTapIsEnabled = true;
        
        if (keepPointerMoving) {
            
            /// Init puppet cursor pos
            _puppetCursorPosition = origin;
            
            /// Get display under mouse pointer
            CVReturn rt = [HelperUtility display:&_display atPoint:_origin];
            if (rt != kCVReturnSuccess) DDLogWarn(@"Couldn't get display under mouse pointer in PointerFreeze");
            
            /// Draw puppet cursor before hiding
            [PointerFreeze drawPuppetCursor:YES fresh:YES];
            
            /// Wait
            ///     The puppetCursor will only be drawn after a delay, while hiding the mouse pointer is really fast.
            ///     This leads to a little flicker when the puppetCursor is not yet drawn, but the real cursor is already hidden.
            ///     Not sure why this happens. But adding a delay of 0.02 before hiding makes it look seamless.
            ///     Edit: `dispatch_after` caused race conditions, so we're sleeping instead. Might be bad for performance because we're using dispatch_sync above
            ///
            usleep(USEC_PER_SEC * 0.01);
            
            /// Hid cursor
            [ModificationUtility hideMousePointer:YES];
        }
    });
}

CGEventRef _Nullable mouseMovedCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    /// Catch special events
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        
        DDLogInfo(@"PointerFreeze eventTap disabled by %@", type == kCGEventTapDisabledByTimeout ? @"timeout. Re-enabling." : @"user input.");
        
        if (type == kCGEventTapDisabledByTimeout) {
//            assert(false); /// Not sure this ever times out
            CGEventTapEnable(_eventTap, true);
            _coolEventTapIsEnabled = true;
        }
        
        return event;
    }
    
    /// Get deltas
    ///     Have to get delta's before dispatching async, otherwise they won't be correct
    int64_t dx = -1;
    int64_t dy = -1;
    if (_keepPointerMoving) {
        dx = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
        dy = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);
    }
    
    /// Record timestamp and delta
    _lastEventTimestamp = CACurrentMediaTime();
    _lastEventDelta = llabs(MAX(dx,dy));
    
    /// Lock
    ///     Edit: Why is this async? Doesn't that make for worse/inconsistent behaviour?
    dispatch_async(_queue, ^{
        
        /// Check interrupt
        if (!_coolEventTapIsEnabled) {
            return;
        }
        
        /// Warp pointer to origin to prevent cursor movement
        ///     This only works when the suppressionInterval is a certain size, and that will cause a slight stutter / delay until the mouse starts moving againg when we deactivate. So this isn't optimal
        CGWarpMouseCursorPosition(_origin);
        
        //        CGWarpMouseCursorPosition(_drag->origin);
        /// ^ Move pointer to origin instead of usageOrigin to make scroll events dispatch there - would be nice but that moves the pointer, which creates events which will feed back into our eventTap and mess everything up (even though `CGWarpMouseCursorPosition` docs say that it doesn't create events??)
        ///     I gues we'll just have to make the usageThreshold small instead
        
        /// Disassociate pointer to prevent cursor movements
        ///     This makes the inputDeltas weird I feel. Better to freeze pointer through calling CGWarpMouseCursorPosition repeatedly.
        //        CGAssociateMouseAndMouseCursorPosition(NO);
        
        if (_keepPointerMoving) {
        
            /// Update puppetCursorPosition
            updatePuppetCursorPosition(dx, dy);
            /// Draw puppet cursor
            [PointerFreeze drawPuppetCursor:YES fresh:NO];
        }
        
    });

   return event;
}

+ (void)unfreeze {
    
    /// Record timestamp
    CFTimeInterval timeSinceLastEvent = CACurrentMediaTime() - _lastEventTimestamp;
    
    /// Lock
    ///     Not sure whether to use sync or async here
    
    dispatch_async(_queue, ^{
        
        /// Process timestamp
        BOOL pointerIsMoving = (timeSinceLastEvent < GeneralConfig.mouseMovingMaxIntervalSmall) && _lastEventDelta > 0;
        
        /// Debug
        /// Doing this outside the queue led to race conditions (I think?)
        DDLogDebug(@"PointerFreeze - UNfreezing");
        DDLogDebug(@"PointerFreeze - pointerIsMoving: %d - time: %f, delta: %lld", pointerIsMoving, timeSinceLastEvent, _lastEventDelta);
        
        /// Disable eventTap
        /// Think about the order of getting pos, unfreezing, and disabling event tap. -> I think it doesn't matter since everything is locked.
        CGEventTapEnable(_eventTap, false);
        _coolEventTapIsEnabled = false;
        
        CGPoint warpDestination;
        if (_keepPointerMoving) {
            setSuppressionInterval(kMFEventSuppressionIntervalForWarping);
            warpDestination = _puppetCursorPosition;
        } else {
            /// When we're freezing the pointer, we still want to warp one last time, to create a the delay before the pointer unfreezes.
            
            MFEventSuppressionInterval delay;
            if (pointerIsMoving) {
                delay = kMFEventSuppressionIntervalForUnfreezingPointerDuringFlick;
            } else {
                delay = kMFEventSuppressionIntervalZero;
            }
            setSuppressionInterval(delay);
            warpDestination = _origin;
        }
        
        /// Warp actual cursor to position of puppet cursor
        CGWarpMouseCursorPosition(warpDestination);
        
        if (_keepPointerMoving) {
        
            /// Show mouse pointer again
            [ModificationUtility hideMousePointer:NO];
            
            /// Undraw puppet cursor
            [PointerFreeze drawPuppetCursor:NO fresh:NO];
        }
        
        /// Reset suppression interval to default
        setSuppressionInterval(kMFEventSuppressionIntervalDefault);
    });
}

#pragma mark - Helper functions

/// Event suppression

typedef enum {
    kMFEventSuppressionIntervalZero,
    kMFEventSuppressionIntervalForWarping,
    kMFEventSuppressionIntervalForStoppingCursor,
    kMFEventSuppressionIntervalForUnfreezingPointerDuringFlick,
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
        /// Can't be 0 or else repeatedly calling CGWarpMouseCursorPosition() won't work for stopping the cursor
        interval = 0.07 /*0.05*/;
    } else if (mfInterval == kMFEventSuppressionIntervalZero) {
        interval = 0.000;
    } else if (mfInterval == kMFEventSuppressionIntervalDefault) {
        interval = _defaultSuppressionInterval;
    } else if (mfInterval == kMFEventSuppressionIntervalForWarping) {
        interval = 0.000;
    } else if (mfInterval == kMFEventSuppressionIntervalForUnfreezingPointerDuringFlick) {
        /// We use a larger delay here so that the pointer doesn't suddenly get flicked around when unfreezing during a flick
        interval = 0.15;
    } else {
        assert(false);
    }
    
    /// Set new suppressionInterval
    CGEventSourceSetLocalEventsSuppressionInterval(src, interval);
    
    /// Analyze suppresionInterval
    CFTimeInterval intervalResult = CGEventSourceGetLocalEventsSuppressionInterval(src);
    DDLogDebug(@"PointerFreeze - Event suppression interval: %f", intervalResult);
    
    /// Store previous mfInterval
    _previousMFSuppressionInterval = mfInterval;
    
    /// Release
    CFRelease(src);
}

void setSuppressionIntervalWithTimeInterval(CFTimeInterval interval) {
    
    /// Get src
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    /// Set new suppressionInterval
    CGEventSourceSetLocalEventsSuppressionInterval(src, interval);
    /// Release
    CFRelease(src);
}

/// Puppet cursor

+ (void)drawPuppetCursor:(BOOL)draw fresh:(BOOL)fresh {
    
    /// Efficient undraw
    ///     -> Just make transparent
//    if (!draw) {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            _puppetCursorView.alphaValue = 0; /// Make the puppetCursor invisible
//        });
//        return;
//    }
    
    /// Get loc
    CGPoint loc = _puppetCursorPosition;
    
    /// Get default cursor
    if (_puppetCursor == nil) {
        /// Init puppetCursor
        ///     Might be better to do this during + initialize function
        _puppetCursor = NSCursor.arrowCursor;
    }
    
    /// Get current cursor
//    if (fresh) {
//        _puppetCursor = NSCursor.currentSystemCursor;
//    }
    
    /// Subtract hotspot to get puppet image loc
    CGPoint hotspot = _puppetCursor.hotSpot;
    CGPoint imageLoc = CGPointMake(loc.x - hotspot.x, loc.y - hotspot.y);
    
    /// Unflip coordinates to be compatible with Cocoa
    NSRect puppetImageFrame = NSMakeRect(imageLoc.x, imageLoc.y, _puppetCursor.image.size.width, _puppetCursor.image.size.height);
    NSRect puppetImageFrameUnflipped = [SharedUtility quartzToCocoaScreenSpace:puppetImageFrame];
    
    /// Define mainthread workload
    
    void (^workload)(void) = ^{
        
        /// Normal undraw
        ///     We need to use normal undraw instead of "efficient undraw" (see above) because (at least under Ventura Beta) mouseMoved causes CPU usage as long as the ScreenDrawers `canvas` window is open.
        ///     We might be able to somehow fix this when setting up the canvas in `ScreenDrawer.load_Manual()`
        if (!draw) {
            [ScreenDrawer.shared undrawWithView:_puppetCursorView];
            return;
        }
        
        /// Store image of cursor into puppetView
        if (fresh) {
            /// Store cursor image into puppet view
            _puppetCursorView.image = _puppetCursor.image;
        }
        
        /// Draw/move puppet cursor image
        if (fresh) {
            /// Draw puppetCursor
            NSScreen *screenUnderMousePointer = [NSScreen screenUnderMousePointerWithEvent:NULL]; /// We could also use `_display`?
            [ScreenDrawer.shared drawWithView:_puppetCursorView atFrame:puppetImageFrameUnflipped onScreen:screenUnderMousePointer];
        } else {
            /// Reposition  puppet cursor!
            [ScreenDrawer.shared moveWithView:_puppetCursorView toOrigin:puppetImageFrameUnflipped.origin];
        }
        
        /// Unhide puppet cursor
        if (fresh) {
            _puppetCursorView.alphaValue = 1;
        }
    };
    
    /// Make sure workload is executed on main thread
    ///     Since we call sync, we need to check if we're already on main to avoid deadlock
    
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
