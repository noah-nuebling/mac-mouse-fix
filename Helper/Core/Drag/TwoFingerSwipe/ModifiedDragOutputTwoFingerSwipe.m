//
// --------------------------------------------------------------------------
// ModifiedDragOutputTwoFingerSwipe.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// @noGCDCleanup - Go over old comments about the threading issues. Describe how 'No more dispatch queues' refactor solves it, but also forces continuation stuff which is also a little complex (I anticipate)

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
    /// - When using a twoFingerModifedDrag and performance drops, the timeBetweenEvents can sometimes be erratic, and this sometimes leads apps like Xcode to start their custom momentumScroll algorithms with way too high speeds (At least I think that's whats going on) So we're using an animator to smooth things out and hopefully achieve more consistent behaviour
    ///     - Edit: Using the `_smoothingAnimator` forces us to use some very very error prone parallel code. I should seriously consider if this is the best approach.
    ///         Maybe you could just introduce a delay between the last two events? I feel like the lack of that delay causes most of the erratic behaviour.
    ///
    /// - Using a TouchAnimator here might not be the best choice. We made the TouchAnimator primarily for scrollwheel input. But then we started using it here too. In both situations we needed pretty different functionality so now it's this weird swiss army knife hybrid. For example it supports Vectors which we don't need for scroll wheel input and it supports generating touchPhases which we don't need for click and drag. The reason we did this is we had so much trouble getting the TouchAnimator to be free of multithreading bugs so we thought there was less potential for error if we only implement that stuff once. But we might get some performance improvements and simpler code if we make a separate animator for the dragSmoothing.
    
    _smoothingAnimator = [[TouchAnimator alloc] initWithRunLoop: GlobalEventTapThread.runLoop name: @"TwoFingerSwipeSmoothing"];
    //_smoothingAnimator = [[DynamicSystemAnimator alloc] initWithSpeed:3 damping:1.0 initialResponser:1.0 stopTolerance:1.0];
    
    /// Make cursor settable
    [ModificationUtility makeCursorSettable];
}

#pragma mark - Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    
    /// Store drag state
    _drag = dragStateRef;

    /// Cancel the smoothing animator
    ///     TODO-ish?: There's a race where a `threeFingerSwipe` could start trying to freeze the pointer before the smoothingAnimator finishes (Tried but could never trigger it, window maybe too small or I did it wrong.) but still ...
    ///         -> Freezing should probably be managed by ModifiedDrag.m to an extent to allow such coordinations. [Sep 2026]
    [_smoothingAnimator cancel]; /// Sends `kMFAnimationCallbackPhaseCanceled` or `kMFAnimationCallbackPhaseStoppedBeforeStart` to our callback, guaranteeing that the continuation for the last gesture (the pointer-unfreeze) runs [Sep 2026]

    /// Stop scrolling
    ///     - This calls `[GestureScrollSimulator stopMomentumScroll]` - triggering the continuation for the last gesture immediately. [Sep 2026]
    ///     - Forgot why exactly we're stopping *all* scrolling here. I think it's nice and consistent? [Sep 2026]
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

    [_smoothingAnimator startWithParams:^NSDictionary<NSString *,id> * _Nonnull(Vector valueLeft, BOOL isRunning, Curve * _Nullable curve, Vector currentSpeed) {

        NSMutableDictionary *p = [NSMutableDictionary dictionary];
        
        /// Get delta
        Vector currentVec = { .x = deltaX*twoFingerScale, .y = deltaY*twoFingerScale };
        Vector combinedVec = addedVectors(currentVec, valueLeft);

        /// Get Phase
        if (firstCallback) eventPhase = kIOHIDEventPhaseBegan;
        
        /// Debug

        static double lastTs = 0;
        double ts = CACurrentMediaTime();
        double tsDiff = ts - lastTs;
        lastTs = ts;

        DDLogDebug("twoFinger SmoothingAnimator start - time since last: %f", tsDiff * 1000);

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
        
        if (magnitudeOfVector(combinedVec) == 0.0) {
            DDLogWarn("twoFinger Not starting baseAnimator since combinedMagnitude is 0.0");
            p[@"doStart"] = @NO;
        } else {
            p[@"vector"] = nsValueFromVector(combinedVec);
            p[@"curve"] = ScrollConfig.linearCurve;
            p[@"duration"] = @(3.0/60.0);
            //p[@"durationInFrames"] = @3;
        }

        /// Debug

        static Vector scrollDeltaSum = { .x = 0, .y = 0};
        scrollDeltaSum.x += fabs(currentVec.x);
        scrollDeltaSum.y += fabs(currentVec.y);
        DDLogDebug("twoFinger Delta sum pre-animator: (%f, %f)", scrollDeltaSum.x, scrollDeltaSum.y);
        DDLogDebug("twoFinger Value left pre-animator: (%f, %f)", valueLeft.x, valueLeft.y);

        /// Return

        return p;

    } integerCallback:^(Vector deltaVec, MFAnimationCallbackPhase animatorPhase, MFMomentumHint subCurve) {

        /// Debug

        //static double scrollDeltaSummm = 0;
        //scrollDeltaSummm += fabs(valueDeltaD);
        //DDLogDebug("Delta sum in-animator: %f", scrollDeltaSummm);
        DDLogDebug(" twoFinger smoothingAnimator callback - delta: (%f, %f), phase: %d, shouldStartMomentumScroll: %d", deltaVec.x, deltaVec.y, animatorPhase, _smoothingAnimatorShouldStartMomentumScroll);
        
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
        mfassert(false); /// [Sep 2026] Dead code - remove the `cancelation` arg since it is never used. (Credits to Opus 5.5 for finding this)
        if (_smoothingAnimator.isRunning_Unsafe) /// [Sep 2026] This seems a bit stupid but harmless (Shouldn't -cancel be a no-op if it's not running?)
            [_smoothingAnimator cancel];

        [GestureScrollSimulator postGestureScrollEventWithDeltaX: 0 deltaY: 0 phase: kIOHIDEventPhaseEnded autoMomentumScroll: YES invertedFromDevice: _drag->naturalDirection];
        [GestureScrollSimulator stopMomentumScroll];

        [PointerFreeze unfreeze];

        return;
    }
    else {

        /// Handle non-cancelation

        /// Setup continuation of this method after momentuScroll starts
        void (^continuation)(void) = ^{
            DDLogDebug("twoFinger continuing deactivation after momentumScroll start.");
            [PointerFreeze unfreeze];
            [GestureScrollSimulator afterStartingMomentumScroll: NULL];
        };
        [GestureScrollSimulator afterStartingMomentumScroll: continuation];

        #if 0 /// [Sep 2026] Old code that crashed program after 2 second timeout for the continuation (we used `dispatch_group_wait` instead of continuation back then)
              ///       @noGCDCleanup Maybe reinstall timeout and/or delete this. (I think this was to catch deadlocks which probably don't happen anymore)
        if (rt != 0) {

            /// Log error
            DDLogError("twoFinger _momentumScrollWaitGroup timed out. _momentumScrollWaitGroup info: %@. Will crash.", _momentumScrollWaitGroup.debugDescription);

            /// Clean up
            ///     Unhide mouse pointer
            if (!runningPreRelease()) {
                [PointerFreeze unfreeze]; /// Only in release so the crashes are more noticable in prereleases
            }

            /// Crash
            assert(false);
            exit(EXIT_FAILURE); /// Make sure it also quits in release builds
        }
        #endif

        /// Setup starting of momentumScroll (or start it directly)
        if (_smoothingAnimator.isRunning_Unsafe) { /// Let `_smoothingAnimator` start momentumScroll
            DDLogDebug("twoFinger Setting _smoothingAnimatorShouldStartMomentumScroll = YES");
            _smoothingAnimatorShouldStartMomentumScroll = YES;
        } else { /// Start momentumScroll directly
            DDLogDebug("twoFinger Starting momentumScroll directly");
            [GestureScrollSimulator postGestureScrollEventWithDeltaX: 0 deltaY: 0 phase: kIOHIDEventPhaseEnded autoMomentumScroll: YES invertedFromDevice: _drag->naturalDirection];
        }
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
