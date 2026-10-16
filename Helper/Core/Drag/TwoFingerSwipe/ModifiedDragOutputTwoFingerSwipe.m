//
// --------------------------------------------------------------------------
// ModifiedDragOutputTwoFingerSwipe.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputTwoFingerSwipe.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "ModificationUtility.h"
#import "GestureScrollSimulator.h"
#import "CGSConnection.h"
#import "PointerFreeze.h"
#import "ScrollUtility.h"

///
/// - [May 2025] UX Problem: IDA Pro's Graph view is super unresponsive when scrolling it via "Scroll & Navigate".
///     Observation: When scrolling on the Trackpad *while* moving the mouse a similar effect can be observed.
///     Hypothesis: Even though MMF is locking the mouse pointer in place, it might still be generating mouse events, which slow down IDA.
///

@implementation ModifiedDragOutputTwoFingerSwipe

#pragma mark - Vars

static ModifiedDragState *_drag;

static TouchAnimator *_smoothingAnimator;
static BOOL _smoothingAnimatorShouldStartMomentumScroll = NO;

#pragma mark - Init

+ (void)load_Manual {
    
    /// Setup smoothingAnimator
    ///  Notes:
    /// - When using a twoFingerModifedDrag and performance drops, the timeBetweenEvents can sometimes be erratic, and this sometimes leads apps like Xcode to start their
    ///     custom momentumScroll algorithms with way too high speeds (At least I think that's whats going on) So we're using an animator to smooth things out and hopefully achieve more consistent behaviour
    ///     - Edit: Using the `_smoothingAnimator` forces complicated `continuation` code.
    ///         Maybe you could just introduce a delay between the last two events? I feel like the lack of that delay causes most of the erratic behaviour.
    ///     @afterNoGCDTodo [Oct 2026] In Safari (heavy load), I observe much more erratic momentum speeds after 'No more dispatch queues' refactor! Possibly `CommonEventTap` will fix this.
    ///
    /// - Using a TouchAnimator here might not be the best choice. We made the TouchAnimator primarily for scrollwheel input. But then we started using it here too.
    ///     In both situations we needed pretty different functionality so now it's this weird swiss army knife hybrid. For example it supports Vectors which we don't
    ///     need for scroll wheel input and it supports generating touchPhases which we don't need for click and drag. The reason we did this is we had so much trouble
    ///     getting the TouchAnimator to be free of multithreading bugs so we thought there was less potential for error if we only implement that stuff once.
    ///     But we might get some performance improvements and simpler code if we make a separate animator for the dragSmoothing.
    ///         Update: [Oct 2026] 'No more dispatch queues' refactor removed the multithreading! But it seems to work fine.
    ///

    _smoothingAnimator = [[TouchAnimator alloc] initWithPhaseShift: kVBLPhase_DefaultForEventSending runLoop: IOThread.runLoop name: @"TwoFingerSwipeSmoothing"];
    //_smoothingAnimator = [[DynamicSystemAnimator alloc] initWithSpeed:3 damping:1.0 initialResponser:1.0 stopTolerance:1.0];
    
    /// Make cursor settable
    [ModificationUtility makeCursorSettable];
}

#pragma mark - Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    
    /// Store drag state
    _drag = dragStateRef;

    /// Cancel the smoothing animator
    ///     TODO-ish?: [Oct 2026] There's a race where a `threeFingerSwipe` could start trying to freeze the pointer before the smoothingAnimator finishes (Tried but could never trigger it, window maybe too small or I did it wrong.) but still ...
    ///         -> Freezing should probably be managed by ModifiedDrag.m to an extent to allow such coordinations. [Sep 2026]
    [_smoothingAnimator cancel]; /// Sends `kMFAnimationCallbackPhaseCanceled` or `kMFAnimationCallbackPhaseStoppedBeforeStart` to our callback, guaranteeing that the continuation for the last gesture (the pointer-unfreeze) runs [Sep 2026]

    /// Stop scrolling
    ///     - This calls `[GestureScrollSimulator stopMomentumScroll]` - triggering the `continuation` for the last gesture immediately. [Sep 2026]
    ///     - Forgot why exactly we're stopping *all* scrolling here. I think it's what I ended up expecting as user, so good UX? [Sep 2026]
    ///         - Older note: On the trackpad driver, scrolling seems to stop whenever any clicks or gestures come in. Maybe we should do a similar type of top-down management of when scrolling is stopped, instead of doing it here.
    [Scroll resetState];
}

+ (void)handleBecameInUse {
    
    /// Freeze pointer
    if (GeneralConfig.freezePointerDuringModifiedDrag) {
        [PointerFreeze freezePointerAtPosition:_drag->usageOrigin];
    } else {
        [PointerFreeze freezeEventDispatchPointAtPosition:_drag->usageOrigin];
    }
    
    /// Setup animator
    [_smoothingAnimator resetSubPixelator];
    [_smoothingAnimator linkToMainScreen];
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY {
    
    /**
     scrollSwipe scaling
        A scale of 1.0 will make the pixel based animations (normal scrolling) follow the mouse pointer.
        Gesture based animations (swiping between pages in Safari etc.) seem to be scaled separately such that swiping 3/4 (or so) of the way across the Trackpad equals one whole page. No matter how wide the page is.
        So to scale the gesture deltas such that the page-change-animations follow the mouse pointer exactly, we'd somehow have to get the width of the underlying scrollview. This might be possible using the _systemWideAXUIElement we created in ScrollControl, but it'll probably be really slow.
     */
    double twoFingerScale = 1.0;
    
    /// Post event
    ///     Using animator for smoothing
    
    /// Declare static vars for animator
    static IOHIDEventPhaseBits eventPhase = kIOHIDEventPhaseUndefined;

    /// Values that the block should copy instead of reference
    IOHIDEventPhaseBits firstCallback = _drag->firstCallback;

    /// Start animator

    #if 0 /// Old code using dynamic system animator

    if (firstCallback) {
        eventPhase = kIOHIDEventPhaseBegan;
    }
    [_smoothingAnimator animateWithDistance:(Vector){ .x = deltaX*twoFingerScale, .y = deltaY*twoFingerScale} callback:^(Vector deltaVec, MFAnimationCallbackPhase animatorPhase, MFMomentumHint momentumHint) {

        /// Debug


        if (animatorPhase == kMFAnimationCallbackPhaseEnd) {

             if (_smoothingAnimatorShouldStartMomentumScroll) {
                 [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded autoMomentumScroll:YES];
             }

            _smoothingAnimatorShouldStartMomentumScroll = false;

            return;
        }

        [GestureScrollSimulator postGestureScrollEventWithDeltaX:deltaVec.x deltaY:deltaVec.y phase:eventPhase autoMomentumScroll:YES];

        eventPhase = kIOHIDEventPhaseChanged;
    }];

    #else /// Use TouchAnimator

    /// Get animator params
    Vector combinedVec = {};
    Curve *curve = {};
    double duration = -1;
    int durationInFrames = -1;
    bool doStart = true;
    {
        assertRunLoop(_smoothingAnimator.displayLink.runLoop);

        /// Get delta
        Vector currentVec = { .x = deltaX*twoFingerScale, .y = deltaY*twoFingerScale };
        combinedVec = addedVectors(currentVec, _smoothingAnimator.animationValueLeft);

        /// Get Phase
        if (firstCallback) eventPhase = kIOHIDEventPhaseBegan;
        
        /// Debug
        if (runningDebugMode()) {
            static double lastTs = 0;
            double ts = CACurrentMediaTime();
            double tsDiff = ts - lastTs;
            lastTs = ts;
            DDLogDebug("twoFinger SmoothingAnimator start - time since last: %f", tsDiff * 1000);
        }

        /// Get return values
        ///
        /// Notes:
        /// - On smoothing duration:
        ///   - We want the duration as low as possible while still preventing the erratic behaviour.
        ///     - For 1 frametime we still get erratic behaviour. I'm not sure any smoothing happens there.
        ///     - For 2 frametimes we still get slightly erratic behaviour.
        ///     - For 3 frameTimes we get almost no erratic behaviour.
        ///   - I'm on a 60 hz screen and I don't have a 120 hz screen to test. To make sure we also prevent erratic behaviour on an 120 hz screen, we are setting the duration to 3.0/60.0 seconds instead of 3 frames. 3.0/60.0 also doesn't seem to cause erratic behaviour when setting my monitor to 30hz.
        ///     - TODO: Set duration to 3 frames instead of 3.0/60.0 seconds if that doesn't lead to erratic behaviour on 120 hz screens.
        ///         @afterNoGCDTodo

        if (magnitudeOfVector(combinedVec) == 0.0) {
            DDLogWarn("twoFinger Not starting baseAnimator since combinedMagnitude is 0.0");
            doStart = false;
        } else {
            curve = ScrollConfig.linearCurve;
            duration = 3.0/60.0;
            //durationInFrames = 3;
        }

        /// Debug
        if (runningDebugMode()) {
            static Vector scrollDeltaSum = { .x = 0, .y = 0};
            scrollDeltaSum.x += fabs(currentVec.x);
            scrollDeltaSum.y += fabs(currentVec.y);
            DDLogDebug("twoFinger Delta sum pre-animator: (%f, %f)", scrollDeltaSum.x, scrollDeltaSum.y);
            DDLogDebug("twoFinger Value left pre-animator: (%f, %f)", _smoothingAnimator.animationValueLeft.x, _smoothingAnimator.animationValueLeft.y);
        }
    }

    /// Start the animator
    if (doStart)
    [_smoothingAnimator
        startWithDuration: duration
        durationInFrames: durationInFrames
        vector: combinedVec
        curve: curve
        integerCallback: ^(Vector deltaVec, MFAnimationCallbackPhase animatorPhase, MFMomentumHint subCurve)
    {
        if (runningDebugMode()) {
            //static double scrollDeltaSummm = 0;
            //scrollDeltaSummm += fabs(valueDeltaD);
            //DDLogDebug("Delta sum in-animator: %f", scrollDeltaSummm);
            DDLogDebug(" twoFinger smoothingAnimator callback - delta: (%f, %f), phase: %d, shouldStartMomentumScroll: %d", deltaVec.x, deltaVec.y, animatorPhase, _smoothingAnimatorShouldStartMomentumScroll);
        }

        if (animatorPhase == kMFAnimationCallbackPhaseEnd || animatorPhase == kMFAnimationCallbackPhaseCanceled || animatorPhase == kMFAnimationCallbackPhaseStoppedBeforeStart) {
             if (_smoothingAnimatorShouldStartMomentumScroll) {
                 [GestureScrollSimulator postGestureScrollEventWithDeltaX: 0 deltaY: 0 phase: kIOHIDEventPhaseEnded autoMomentumScroll: YES invertedFromDevice: _drag->naturalDirection];
             }
            _smoothingAnimatorShouldStartMomentumScroll = false;
        } else {
            [GestureScrollSimulator postGestureScrollEventWithDeltaX: deltaVec.x deltaY: deltaVec.y phase: eventPhase autoMomentumScroll: YES invertedFromDevice: _drag->naturalDirection];
            eventPhase = kIOHIDEventPhaseChanged;
        }

    }];
    #endif
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancelation {
    
    /// Handle cancelation
    if (cancelation) {
        mfassert(false); /// [Sep 2026] Dead code - should remove the `cancelation` arg since it is never used. (Credits to Opus 5.5 for finding this)
        if (_smoothingAnimator.isRunning) /// [Sep 2026] This seems a bit stupid but harmless (Shouldn't -cancel be a no-op if it's not running?)
            [_smoothingAnimator cancel];

        [GestureScrollSimulator postGestureScrollEventWithDeltaX: 0 deltaY: 0 phase: kIOHIDEventPhaseEnded autoMomentumScroll: YES invertedFromDevice: _drag->naturalDirection];
        [GestureScrollSimulator stopMomentumScroll];

        [PointerFreeze unfreeze];

        return;
    }
    else {

        /// Handle non-cancelation


        /// Crash if continuation (below) times out [Oct 2026]
        ///     We added this before 'No more dispatch queues' refactor when this was prone to deadlocks. Now I don't think this can permanently freeze anymore?
        ///     But still good to have a failsafe against freezing the user's pointer (really bad). [Oct 2026]
        NSTimer *continuationTimeout = [NSTimer timerWithTimeInterval: /** Crash after 2 seconds */2.0 repeats: NO block:^(NSTimer * _Nonnull timer) {
            if (!runningDebugMode()) /// Make failures more noticable in debug mode I guess [Oct 2026]
                [PointerFreeze unfreeze]; /// If we don't do this, I guess the pointer could stay hidden after crash? Not sure. Don't remember ever noticing this making a difference in the last years [Oct 2026]
            DDLogError("twoFinger continuation timed out. Aborting");
            abort();
        }];

        /// Setup continuation of this method (unfreezing the pointer) after momentumScroll starts
        ///     Explanation: [Oct 2026] In case the user moved the puppetCursor (See `PointerFreeze.m`) outside the scrolled window/view,
        ///         we have to send the `kIOHIDEventScrollMomentumStart` event at the `_drag->usageOrigin` *before*
        ///         warping the real cursor to the puppet cursor (`[PointerFreeze unfreeze]`) - that is necessary for the momentum scroll to apply to window/view the user was scrolling.
        ///             [Oct 2026] I thought we explained this somewhere else already but I don't know where. Maybe deleted it at start of 'No more dispatch queues' refactor? Should consolidate or cross-reference.
        ///         It makes the code a lot more complicated but is essential to nice UX.
        ///         Why so complicated?: Maybe there's a less complicated way. Feel like the architecture of GestureScrollSimulator having its own internal animator might stupid and causing this complication [Oct 2026]
        void (^continuation)(void) = ^{
            DDLogDebug("twoFinger continuing deactivation after momentumScroll start.");
            [PointerFreeze unfreeze];
            [GestureScrollSimulator afterStartingMomentumScroll: NULL];
            [continuationTimeout invalidate];
        };
        [GestureScrollSimulator afterStartingMomentumScroll: continuation];

        /// Let `_smoothingAnimator` start momentumScroll
        if (_smoothingAnimator.isRunning) { DDLogDebug("twoFinger Setting _smoothingAnimatorShouldStartMomentumScroll = YES");
                                            _smoothingAnimatorShouldStartMomentumScroll = YES; }
        /// Start momentumScroll directly
        else { DDLogDebug("twoFinger Starting momentumScroll directly");
               [GestureScrollSimulator postGestureScrollEventWithDeltaX: 0 deltaY: 0 phase: kIOHIDEventPhaseEnded autoMomentumScroll: YES invertedFromDevice: _drag->naturalDirection]; }
    }
}

#if 0
    + (void)suspend {
        [PointerFreeze unfreeze];
    }

    + (void)unsuspend {

        /// Convert and add vectors to get current pointer location
        Vector usageOrigin = { .x = _drag->usageOrigin.x, .y = _drag->usageOrigin.y };
        Vector pointerPosVec = addedVectors(usageOrigin, _drag->originOffset);
        CGPoint pointerPos = CGPointMake(pointerPosVec.x, pointerPosVec.y);

        pointerPos = getRoundedPointerLocation();

        /// Freeze pointer
        if (OtherConfig.freezePointerDuringModifiedDrag) {
            [PointerFreeze freezePointerAtPosition:pointerPos];
        } else {
            [PointerFreeze freezeEventDispatchPointAtPosition:pointerPos];
        }
    }
#endif

@end
