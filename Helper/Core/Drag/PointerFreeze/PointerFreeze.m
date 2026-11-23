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
///     - July 2024 - I think I just got stuck with a 'frozen' pointer (it still moved, but clicking anything didn't work and sometimes the pointer teleported to the middle of the screen) I couldn't trace back how this issue happened, and it seems to be really rare, but I think it would be good to give some reliable way to the user for ending pointer freeze in case it gets stuck. For example we could end the freeze on left-click, or perhaps we could build some vaildation e.g. assert that the pointer is not frozen (aka `[MFEventTap isEnabledForListener:] == YES`) before freeze() is called.
///

#import "PointerFreeze.h"
@import Cocoa;
#import "HelperUtility.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "CGSConnection.h"
#import "ModificationUtility.h"
#import "Threads.h"
#import "NSScreen+Additions.h"
@import CoreMedia;
#import "MFGate.h"
#import "MFEventTap.h"
#import "WarpDeltaCompensator.h"

@implementation PointerFreeze

/// State

static CGPoint _origin;
static CGPoint _puppetCursorPosition;

static BOOL _keepPointerMoving;

static int _cgsConnection; /// This is used by private APIs to talk to the window server and do fancy shit like hiding the cursor from a background application
static NSCursor *_puppetCursor;
static NSImageView *_puppetCursorView;
static CGDirectDisplayID _display;

static CFTimeInterval _lastEventTimestamp;
static int64_t _lastEventDelta;
static WarpDeltaCompensator _warpDeltaCompensator = { .name = "PointerFreeze" };

#define pointerFreezeRunLoop()      CFRunLoopGetMain()  ///< runLoop that owns most of the state above [Oct 2026]
#define _ioThreadRunLoop()          eventTapRunLoop()   ///< runLoop where we expect the callers to run and where MFEventTap delivers us per-event callbacks. Owns a few state vars, which is probably stupid [Oct 2026]
#define slowWindowServerRunLoop()   CFRunLoopGetMain()  ///< runLoop for doing WindowServer IPC which can block for a long time. Only before the slow calls as documentation. See `Slow WindowServer IPC` notes. [Oct 2026]

#define kListenerID @"PointerFreeze"


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

    assertRunLoop(CFRunLoopGetMain());

    if (self == [PointerFreeze class]) {

        _cgsConnection = CGSMainConnectionID();
        _puppetCursorView = [[NSImageView alloc] init];
        [MFEventTap registerListener: kListenerID forEvents: kMFEventType_Sensor callback: mouseMovedCallback];
    }
}

// MARK: Interface

+ (void)freezeEventDispatchPointAtPosition:(CGPoint)origin {
    /// Freezes the dispatch point for CGEvents in place while making it appear to the user as if the they are still controlling the pointer.
    ///     This is achieved through freezing the actual pointer in place, then making the actual pointer invisible, and then creating a fake 'puppet' pointer and letting the user move that around.
    /// `origin` should be the current pointer position. Not sure what happens if you choose another location
    
    
    freezePointer(origin, YES);
}

+ (void)freezePointerAtPosition:(CGPoint)origin {
    /// Freezes the dispatch point for CGEvents in place while making it appear to the user as if the they are still controlling the pointer.
    ///     This is achieved through freezing the actual pointer in place, then making the actual pointer invisible, and then creating a fake 'puppet' pointer and letting the user move that around.
    /// `origin` should be the current pointer position. Not sure what happens if you choose another location
    
    
    freezePointer(origin, NO);
}

static void freezePointer(CGPoint origin, BOOL keepPointerMoving) {

    mfrunAndWait/*mfrun*/(pointerFreezeRunLoop(), ^{ /// Freeze and unfreeze is blocking via `mfrunAndWait()`. It matches older pre-'No more dispatch queues' behavior (which I'm not sure was explained). Not sure this helps [Oct 2026]

        /// Debug
        DDLogDebug("PointerFreeze - freezing");

        /// Store
        _origin = origin;
        _keepPointerMoving = keepPointerMoving;
        WarpDeltaCompensator_ReportFreeze(&_warpDeltaCompensator, _origin);

        /// Decrease delay after warping
        ///     But only as much so that it doesn't break `CGWarpMouseCursorPosition(()` ability to stop cursor by calling repeatedly
        ///     This changes the timeout globally for many events, so we need to reset this after the drag is deactivated!
        setEventSuppressionInterval(kMFEventSuppressionInterval_ForLockingPointerByWarping);

        /// Enable eventTap
        [MFEventTap enable: true forListener: kListenerID];

        if (keepPointerMoving) {

            /// Init puppet cursor pos
            _puppetCursorPosition = origin;

            /// Get display under mouse pointer
            CVReturn rt = [HelperUtility display:&_display atPoint:_origin];
            if (rt != kCVReturnSuccess) DDLogWarn("Couldn't get display under mouse pointer in PointerFreeze");

            /// Draw puppet cursor before hiding
            drawPuppetCursor(kPuppetCursorCommand_Draw);

            if ((0)) {
                /// Wait
                ///     [Sep 2026] Aparrently used to prevent flickers when I developed this (real pointer hiding before puppet cursor draws)
                ///         Don't think this is necessary anymore. Don't see any flicker when freezing. We're also waiting on mainThread in the `kPuppetCursorCommand_Draw` above, so maybe that helps. Not sure.
                ///         (However, I *am* seeing occasional flicker when unfreezing now! Maybe look into that at some point. [Sep 2026])
                ///         Old notes:
                ///             The puppetCursor will only be drawn after a delay, while hiding the mouse pointer is really fast.
                ///             This leads to a little flicker when the puppetCursor is not yet drawn, but the real cursor is already hidden.
                ///             Not sure why this happens. But adding a delay of 20 ms before hiding makes it look seamless.
                ///             Edit: deferring caused race conditions, so we're sleeping instead. Might be bad for performance because this is running on IOThread [Oct 2026]
                ///
                usleep(10 * 1000); /// Wait for 10 ms
            }

            /// Hide cursor
            assertRunLoop(slowWindowServerRunLoop()); /// Observed `CGDisplayHideCursor` to be slow - not sure it matters since it's at the start, not middle / end of the freeze. See `Slow WindowServer IPC` notes.
            [ModificationUtility hideMousePointer: YES];
        }
    });
}

void mouseMovedCallback(MFEventType eventType, CGEventRef *eventPtr) {

    assertRunLoop(_ioThreadRunLoop());

    CGEventRef event = *eventPtr;

    /// Get deltas
    int64_t dx = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
    int64_t dy = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);

    /// Compensate
    WarpDeltaCompensator_GetActualDelta(&_warpDeltaCompensator, dx, dy, CGEventGetLocation(event), &dx, &dy);

    /// Debug
    DDLogDebug("PointerFreeze mouseMovedCallback [debugWarpDelta] delta: (%lld, %lld), loc (%d, %d), isEnabledForListener: %d"
        ,CGEventGetIntegerValueField(event, kCGMouseEventDeltaX)
        ,CGEventGetIntegerValueField(event, kCGMouseEventDeltaY)
        ,(int)CGEventGetLocation(event).x
        ,(int)CGEventGetLocation(event).y
        ,[MFEventTap isEnabledForListener: kListenerID]
    );

    /// Record timestamp and delta
    /// TODO: _lastEventTimestamp -> Maybe use the more-accurate IOHIDEvent timestamp instead, or least CGEventGetTimestampInSeconds (throughout the codebase) [Oct 2026]
    /// TODO: _lastEventDelta -> This llabs calculation was broken in a way that made _lastEventDelta do nothing, but it's been working fine for years in practice [Oct 2026] -> Maybe remove
    ///     -> If we do both of these, we can remove `_ioThreadRunLoop()` checks [Oct 2026]
    _lastEventTimestamp = CACurrentMediaTime();
    _lastEventDelta = MAX(llabs(dx),llabs(dy)); /// This should be the correct llabs calculation, so it's taking effect, now. Probably doesn't make a difference. [Oct 2026]

    /// Check interrupt
    if (![MFEventTap isEnabledForListener: kListenerID]) return;

    mfrun(pointerFreezeRunLoop(), ^{ /// Defer so the per-event callback does not block on `slowWindowServerRunLoop()` stuff, competing with the `_smoothingAnimator`. See `Slow WindowServer IPC` notes. [Oct 2026]

        /// Check interrupt
        if (![MFEventTap isEnabledForListener: kListenerID]) return;

        /// Warp pointer to origin to prevent cursor movement
        ///     This only works when the suppressionInterval is a certain size, and that will cause a slight stutter / delay until the mouse starts moving againg when we deactivate. So this isn't optimal
        assertRunLoop(slowWindowServerRunLoop()); /// Observed `CGWarpMouseCursorPosition` to be slow. See `Slow WindowServer IPC` notes. [Oct 2026]
        CGWarpMouseCursorPosition(_origin);

        /// Move pointer to origin instead of usageOrigin to make scroll events dispatch there - would be nice but that moves the pointer, which creates events which will feed back into our eventTap and mess everything up (even though `CGWarpMouseCursorPosition` docs say that it doesn't create events??)
        ///     I gues we'll just have to make the usageThreshold small instead
        #if 0
        CGWarpMouseCursorPosition(_drag->origin);
        #endif

        /// Disassociate pointer to prevent cursor movements
        ///     This makes the inputDeltas weird I feel. Better to freeze pointer through calling CGWarpMouseCursorPosition repeatedly.
        if ((0)) CGAssociateMouseAndMouseCursorPosition(NO);

        if (_keepPointerMoving) {
            /// Update puppetCursorPosition
            updatePuppetCursorPosition(dx, dy);
            /// Draw puppet cursor
            drawPuppetCursor(kPuppetCursorCommand_Move);
        }

    });
}

+ (void)unfreeze {
    assertRunLoop(_ioThreadRunLoop()); /// `_ioThreadRunLoop()` owns `_lastEventTimestamp` and `_lastEventDelta` currently. Probably stupid and could be removed [Oct 2026]

    /// Record timestamp and access `_ioThreadRunLoop()`-owned vars before `mfrunAndWait` [Oct 2026]
    CFTimeInterval timeSinceLastEvent = CACurrentMediaTime() - _lastEventTimestamp;
    int64_t lastEventDelta = _lastEventDelta;

    /// Process timestamp
    BOOL pointerIsMoving = (timeSinceLastEvent < GeneralConfig.mouseMovingMaxIntervalSmall) && lastEventDelta > 0;

    mfrunAndWait(pointerFreezeRunLoop(), ^{

        /// Debug
        /// Doing this outside the queue led to race conditions (I think?)
        DDLogDebug("PointerFreeze - UNfreezing");
        DDLogDebug("PointerFreeze - pointerIsMoving: %d - time: %f, delta: %lld", pointerIsMoving, timeSinceLastEvent, lastEventDelta);
        
        /// Disable eventTap
        /// Think about the order of getting pos, unfreezing, and disabling event tap. -> I think it doesn't matter since everything is locked.
        [MFEventTap enable: false forListener: kListenerID];
        
        CGPoint warpDestination;
        if (_keepPointerMoving) {
            setEventSuppressionInterval(kMFEventSuppressionInterval_ForWarpingPointerToPuppet);
            warpDestination = _puppetCursorPosition;
        } else {
            /// When locking the pointer completely (without a moving puppet), we still want to warp one last time on unfreeze, to create a the delay before the pointer reacts to user input again.
            CFTimeInterval interval;
            if (pointerIsMoving) interval = kMFEventSuppressionInterval_ForReleasingLockedPointerDuringFlick;
            else                 interval = kMFEventSuppressionInterval_ForReleasingLockedPointer; /// This is 0 - does that turn this into a no-op? Forgot intention behind this code [Oct 2026]
            setEventSuppressionInterval(interval);
            warpDestination = _origin;
        }
        
        /// Warp pointer
        assertRunLoop(slowWindowServerRunLoop()); /// Observed `CGWarpMouseCursorPosition` to be slow. Not sure it matters since this is the end, not middle of the freeze. See `Slow WindowServer IPC` notes. [Oct 2026]
        CGWarpMouseCursorPosition(warpDestination);
        
        if (_keepPointerMoving) {

            /// Show mouse pointer again
            [ModificationUtility hideMousePointer: NO];

            /// Undraw puppet cursor
            drawPuppetCursor(kPuppetCursorCommand_Undraw);
        }
        
        /// Reset suppression interval to default
        setEventSuppressionInterval(kMFEventSuppressionInterval_Default);
    });
}

#pragma mark - Helper functions

/// Event suppression

static const CFTimeInterval kMFEventSuppressionInterval_ForLockingPointerByWarping           = 0.070; /*0.050*/  /// Can't be 0 or else repeatedly calling CGWarpMouseCursorPosition() won't work for stopping the cursor
static const CFTimeInterval kMFEventSuppressionInterval_ForWarpingPointerToPuppet            = 0.000;
static const CFTimeInterval kMFEventSuppressionInterval_ForReleasingLockedPointer            = 0.000;
static const CFTimeInterval kMFEventSuppressionInterval_ForReleasingLockedPointerDuringFlick = 0.150;            /// We use a larger delay here so that the pointer doesn't suddenly get flicked around when unfreezing during a flick
static const CFTimeInterval kMFEventSuppressionInterval_Default                             = -1;

static void setEventSuppressionInterval(CFTimeInterval interval) {

    /// We use CGWarpMousePointer to keep the pointer from moving during simulated touchScroll.
    ///     However, after that, the cursor will freeze for like half a second which is annoying.
    ///     To avoid this we need to set the CGEventSuppressionInterval to 0
    ///         (I also looked into permitting all (mouse) events during suppression using `CGEventSourceSetLocalEventsFilterDuringSuppressionState()`. However, it doesn't remove the delay after warping unfortunately. Only `CGEventSourceGetLocalEventsSuppressionInterval()` works.)
    ///     Butttt I just found that whe you set the suppressionInterval to zero then CGWarpMouseCursorPosition doesn't work at all anymore..., so maybe a small value like 0.1? ... 0.05 seems to be the smallest value that fully stops pointer from moving when repeatedly calling CGWarpMouseCursorPosition()
    ///         I thought about using CGAssociateMouseAndMouseCursorPosition(), but in the end we'll still have to use the warp when deactivating to get the real pointer position to where the puppetPointerPosition is. And that's where the delay comes from. Also when using CGAssociateMouseAndMouseCursorPosition() the deltas become really inaccurate and irratic, overdriving the momentumScroll. So there's no benefit to using CGAssociateMouseAndMouseCursorPosition().
    /// Src: https://stackoverflow.com/questions/8215413/why-is-cgwarpmousecursorposition-causing-a-delay-if-it-is-not-what-is
    
    /// Get eventSource
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);

    /// Dynamically retrieve the default suppressionInterval
    static CFTimeInterval _actualDefaultInterval = 0.250;
    {
        static CFTimeInterval _lastInterval = kMFEventSuppressionInterval_Default;
        if (_lastInterval == kMFEventSuppressionInterval_Default)
            _actualDefaultInterval = CGEventSourceGetLocalEventsSuppressionInterval(src);
        _lastInterval = interval;
    }

    /// Resolve the `kMFEventSuppressionInterval_Default` sentinel
    if (interval == kMFEventSuppressionInterval_Default) interval = _actualDefaultInterval;

    /// Set new interval
    CGEventSourceSetLocalEventsSuppressionInterval(src, interval);
    
    /// Validate
    if (runningDebugMode()) {
        CFTimeInterval intervalResult = CGEventSourceGetLocalEventsSuppressionInterval(src);
        DDLogDebug("PointerFreeze - Event suppression interval: %f (set to: %f)", intervalResult, interval);
    }

    /// Clean up
    CFRelease(src);
}

#if 0
void setEventSuppressionIntervalWithTimeInterval(CFTimeInterval interval) {

    /// Get src
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    /// Set new suppressionInterval
    CGEventSourceSetLocalEventsSuppressionInterval(src, interval);
    /// Release
    CFRelease(src);
}
#endif

/// Puppet cursor

typedef enum {
    kPuppetCursorCommand_Draw,
    kPuppetCursorCommand_Move,
    kPuppetCursorCommand_Undraw,
} PuppetCursorCommand;

NSString *PuppetCursorCommand_Description(PuppetCursorCommand command) {
    switch (command) {
        case kPuppetCursorCommand_Draw: return @"Draw";
        case kPuppetCursorCommand_Move: return @"Move";
        case kPuppetCursorCommand_Undraw: return @"Undraw";
    }
    return @"<>";
}

static void drawPuppetCursor(PuppetCursorCommand command) {

    assertRunLoop(pointerFreezeRunLoop());

    /// Get loc
    CGPoint loc = _puppetCursorPosition;
    
    /// Get default cursor
    if (_puppetCursor == nil) {
        /// Init puppetCursor
        ///     Might be better to do this during + initialize function
        _puppetCursor = NSCursor.arrowCursor;
    }
    
    /// Get current cursor
    //if (fresh) _puppetCursor = NSCursor.currentSystemCursor;

    /// Subtract hotspot to get puppet image loc
    CGPoint hotspot = _puppetCursor.hotSpot;
    CGPoint imageLoc = CGPointMake(loc.x - hotspot.x, loc.y - hotspot.y);
    
    /// Unflip coordinates to be compatible with Cocoa
    NSRect puppetImageFrame = NSMakeRect(imageLoc.x, imageLoc.y, _puppetCursor.image.size.width, _puppetCursor.image.size.height);
    NSRect puppetImageFrameUnflipped = [SharedUtility quartzToCocoaScreenSpace:puppetImageFrame];

    /// Decide about blocking
    /// I used to think blocking was necessary to get the order of hiding/drawing/processing gesture right/non janky. On my M4 MBA it doesn't seem to make a difference. (Still had the usleep enabled, so maybe test again) Still doing this just in case or whatever I guess [Sep 2026]
    /// Wating on main could deadlock if main ever waits on IOThread (caller)! Doesn't do that currently [Sep 2026]

    #define kAllOnMain 1
    #if !kAllOnMain /// [Oct 2026] We've now moved the whole `pointerFreezeRunLoop()` to `CFRunLoopGetMain()`, and the blocking is done earlier through `mfrunAndWait()`
        bool blockCaller = command != kPuppetCursorCommand_Move;
        MFGate *gate = blockCaller ? [MFGate new] : nil;

        /// Debug
        double tsBeforeMain = CACurrentMediaTime();
    #endif

    /// Interact with AppKit from mainThread
    /// Optimization idea: Maybe coalesce these like we're already doing for DisplayLink.m's displayLinkCallback or ModifiedDrag's coalescingDisplayLink (But don't skip draw/undraw commands!) [Sep 2026]
    mfassert(pointerFreezeRunLoop() == CFRunLoopGetMain());
    {
        if (command == kPuppetCursorCommand_Draw) {

            /// Store cursor image into puppet view
            _puppetCursorView.image = _puppetCursor.image;

            /// Draw puppetCursor
            NSScreen *_Nullable screenUnderMousePointer = [NSScreen screenUnderMousePointerWithEvent: NULL]; /// We could also use `_display`?
            screenUnderMousePointer = screenUnderMousePointer ?: NSScreen.screens[0]; /// [Aug 2025] Observed nil when no display cable plugged into Mac Mini – which lead to crashes when we passed this on to Swift as a non-optional
            [ScreenDrawer.shared drawWithView: _puppetCursorView atFrame: puppetImageFrameUnflipped onScreen: screenUnderMousePointer];

            /// Unhide puppet cursor
            _puppetCursorView.alphaValue = 1;
        }
        else if (command == kPuppetCursorCommand_Move) {
            /// Reposition  puppet cursor!
            [ScreenDrawer.shared moveWithView: _puppetCursorView toOrigin: puppetImageFrameUnflipped.origin];
        }
        else if (command == kPuppetCursorCommand_Undraw) {

            /// Efficient undraw
            if ((0))
            _puppetCursorView.alphaValue = 0; /// Just make transparent

            /// Normal undraw
            ///     We need to use normal undraw instead of "efficient undraw" (see above) because (at least under Ventura Beta) mouseMoved causes CPU usage as long as the ScreenDrawers `canvas` window is open.
            ///     We might be able to somehow fix this when setting up the canvas in `ScreenDrawer.load_Manual()`
            [ScreenDrawer.shared undrawWithView: _puppetCursorView];
        }

        #if !kAllOnMain
        [gate signalWorkCompleted];
        #endif
    }

    #if !kAllOnMain
    [gate waitForWork];
    if (gate) DDLogDebug("PointerFreeze waited %-7.2f (%@)", 1e3 * (CACurrentMediaTime() - tsBeforeMain), PuppetCursorCommand_Description(command));
    #endif

    #undef kAllOnMain
}

static void updatePuppetCursorPosition(int64_t dx, int64_t dy) {
    assertRunLoop(pointerFreezeRunLoop());

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
