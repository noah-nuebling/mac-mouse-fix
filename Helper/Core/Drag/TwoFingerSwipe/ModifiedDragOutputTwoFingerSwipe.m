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

@implementation ModifiedDragOutputTwoFingerSwipe

#pragma mark - Vars

static ModifiedDragState *_drag;

static TouchAnimator *_smoothingAnimator;
//static DynamicSystemAnimator *_smoothingAnimator;
static BOOL _smoothingAnimatorShouldStartMomentumScroll = NO;
static dispatch_group_t _momentumScrollWaitGroup;

#pragma mark - Init

+ (void)load_Manual {
    
    /// Setup smoothingAnimator
    ///  Notes:
    /// - When using a twoFingerModifedDrag and performance drops, the timeBetweenEvents can sometimes be erratic, and this sometimes leads apps like Xcode to start their custom momentumScroll algorithms with way too high speeds (At least I think that's whats going on) So we're using an animator to smooth things out and hopefully achieve more consistent behaviour
    ///     - Edit: Using the `_smoothingAnimator` forces us to use some very very error prone parallel code. I should seriously consider if this is the best approach.
    ///         Maybe you could just introduce a delay between the last two events? I feel like the lack of that delay causes most of the erratic behaviour.
    ///
    /// - Using a TouchAnimator here might not be the best choice. We made the TouchAnimator primarily for scrollwheel input. But then we started using it here too. In both situations we needed pretty different functionality so now it's this weird swiss army knife hybrid. For example it supports Vectors which we don't need for scroll wheel input and it supports generating touchPhases which we don't need for click and drag. The reason we did this is we had so much trouble getting the TouchAnimator to be free of multithreading bugs so we thought there was less potential for error if we only implement that stuff once. But we might get some performance improvements and simpler code if we make a separate animator for the dragSmoothing.
    
    _smoothingAnimator = [[TouchAnimator alloc] init];
//    _smoothingAnimator = [[DynamicSystemAnimator alloc] initWithSpeed:3 damping:1.0 initialResponser:1.0 stopTolerance:1.0];
    
    /// Setup smoothingGroup
    ///     It allows us to wait until the _smoothingAnimator is done.
    
    _momentumScrollWaitGroup = dispatch_group_create();
    
    /// Make cursor settable
    [ModificationUtility makeCursorSettable];
}

#pragma mark - Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    
    /// Store drag state
    _drag = dragStateRef;
    
    /// Stop momentum scroll
    ///     TODO: Think about this - I don't think this is an adequate solution
    ///     Edit:
    ///         Thought: I think we should remove the initializeWithDragState: method from the protocol entirely
    ///             All of the momentumScroll stopping interaction between scroll and drag I still have to think about.
    [GestureScrollSimulator stopMomentumScroll];
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
    CGDirectDisplayID dsp = [HelperState.shared displayAtPoint:_drag->origin];
    [_smoothingAnimator linkToDisplay:dsp];
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
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
    
    /// Start cool dynamic system animator
    
//    if (firstCallback) {
//        eventPhase = kIOHIDEventPhaseBegan;
//    }
//    [_smoothingAnimator animateWithDistance:(Vector){ .x = deltaX*twoFingerScale, .y = deltaY*twoFingerScale} callback:^(Vector deltaVec, MFAnimationCallbackPhase animatorPhase, MFMomentumHint momentumHint) {
//
//        /// Debug
//
//
//        if (animatorPhase == kMFAnimationCallbackPhaseEnd) {
//
//             if (_smoothingAnimatorShouldStartMomentumScroll) {
//                 [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded autoMomentumScroll:YES];
//             }
//
//            _smoothingAnimatorShouldStartMomentumScroll = false;
//
//            return;
//        }
//
//        [GestureScrollSimulator postGestureScrollEventWithDeltaX:deltaVec.x deltaY:deltaVec.y phase:eventPhase autoMomentumScroll:YES];
//
//        eventPhase = kIOHIDEventPhaseChanged;
//    }];
    
    /// Start animator
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

        DDLogDebug(@"twoFinger SmoothingAnimator start - time since last: %f", tsDiff * 1000);

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
            DDLogWarn(@"twoFinger Not starting baseAnimator since combinedMagnitude is 0.0");
            p[@"doStart"] = @NO;
        } else {
            p[@"vector"] = nsValueFromVector(combinedVec);
            p[@"curve"] = ScrollConfig.linearCurve;
            p[@"duration"] = @(3.0/60.0);
//            p[@"durationInFrames"] = @3;
        }

        /// Debug

        static Vector scrollDeltaSum = { .x = 0, .y = 0};
        scrollDeltaSum.x += fabs(currentVec.x);
        scrollDeltaSum.y += fabs(currentVec.y);
        DDLogDebug(@"twoFinger Delta sum pre-animator: (%f, %f)", scrollDeltaSum.x, scrollDeltaSum.y);
        DDLogDebug(@"twoFinger Value left pre-animator: (%f, %f)", valueLeft.x, valueLeft.y);

        /// Return

        return p;

    } integerCallback:^(Vector deltaVec, MFAnimationCallbackPhase animatorPhase, MFMomentumHint subCurve) {

        /// Debug

//        static double scrollDeltaSummm = 0;
//        scrollDeltaSummm += fabs(valueDeltaD);
//        DDLogDebug(@"Delta sum in-animator: %f", scrollDeltaSummm);

        DDLogDebug(@"\n twoFinger smoothingAnimator callback - delta: (%f, %f), phase: %d, shouldStartMomentumScroll: %d", deltaVec.x, deltaVec.y, animatorPhase, _smoothingAnimatorShouldStartMomentumScroll);
        
        if (animatorPhase == kMFAnimationCallbackPhaseEnd) {

             if (_smoothingAnimatorShouldStartMomentumScroll) {
                 [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded autoMomentumScroll:YES invertedFromDevice:_drag->naturalDirection];
             }

            _smoothingAnimatorShouldStartMomentumScroll = false;

            return;
        }

        [GestureScrollSimulator postGestureScrollEventWithDeltaX:deltaVec.x deltaY:deltaVec.y phase:eventPhase autoMomentumScroll:YES invertedFromDevice:_drag->naturalDirection];

        eventPhase = kIOHIDEventPhaseChanged;

    }];
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancelation {
    
    /// Handle cancelation
    
    if (cancelation) {
        if (_smoothingAnimator.isRunning) {
            [_smoothingAnimator cancel];
        }
        [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded autoMomentumScroll:YES invertedFromDevice:_drag->naturalDirection];
        [GestureScrollSimulator suspendMomentumScroll];
        
        [PointerFreeze unfreeze];

        return;
    }
    
    /// Handle non-cancelation
    
    /// Setup waiting for momentumScroll
    
    DDLogDebug(@"twoFinger Entering _momentumScrollWaitGroup");
    dispatch_group_enter(_momentumScrollWaitGroup);
    
    [GestureScrollSimulator afterStartingMomentumScroll:^{
        
        DDLogDebug(@"twoFinger Leaving _momentumScrollWaitGroup");
        dispatch_group_leave(_momentumScrollWaitGroup);
        
        /// Delete momentumScroll callback
        ///     App will crash if `dispatch_group_leave()` is called again!
        [GestureScrollSimulator afterStartingMomentumScroll:NULL];
    }];
    
    /// Start momentumScroll
    
    if (_smoothingAnimator.isRunning) { /// Let `_smoothingAnimator` start momentumScroll
        _smoothingAnimatorShouldStartMomentumScroll = YES;
        DDLogDebug(@"twoFinger Set _smoothingAnimatorShouldStartMomentumScroll = YES");
    } else { /// Start momentumScroll directly
        DDLogDebug(@"twoFinger Starting momentumScroll directly");
        [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded autoMomentumScroll:YES invertedFromDevice:_drag->naturalDirection];
    }
    
    /// Wait until momentumScroll has been started
    ///     We want to wait for momentumScroll so it is started before the warp. That way momentumScroll will work, even if we moved the pointer outside the scrollView that we started scrolling in.
    ///     Waiting here will also block all other items on `_twoFingerDragQueue`
    
    ///     This whole `_momentumScrollWaitGroup` thing is pretty risky, because if there is any race condition and we don't leave the group properly, then we need to crash the app
    ///     It's really hard to avoid race conditions here though the different  eventTap threads that control ModifiedDrag and all the different nested dispatch queues of ModifiedDrag and its smoothingAnimator and the GestureScrollSimulator queue and it's momentumAnimator's queue and then all those animators have displayLinks with their own queues.... All of these queues call each other in a mix of synchronous and asynchronous, and it all needs to work perfectly without race conditions or deadlocks... Really hard to keep track of.
    ///     If we manage to figure this out, this will make for a great user experience though.
    ///         - Update: We mostly made this work after TONS of blood sweat and tears, but there are still very rare crashes from `dispatch_group_wait()` timing out because `dispatch_group_leave()` isn't called while we're waiting. A (pretty hacky) workaround for some of the crashes might be to build a `dispatch_group_reset()` function. To do this we could get the current count of the `dispatch_group` from the debug description, and then reset the count to 0. We could use this to replace `dispatch_group_leave()` which decrements the count by 1. Currently, the problem is that if the count is already 0 then calling `dispatch_group_leave()` causes a crash, so we need to make absolutely sure that our calls to `dispatch_group_enter()` and `dispatch_group_leave()` are balanced, which is super hard due to race conditions. But if we could use a `dispatch_group_reset()` method, then we could possibly recover when the `dispatch_group_wait()` times out instead of crashing.
    
    /// Wait for momentumScroll to start
    
    DDLogDebug(@"twoFinger Waiting for dispatch group");
    intptr_t rt = dispatch_group_wait(_momentumScrollWaitGroup, dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC));
    
    if (rt != 0) {
        
        /// Log error
        DDLogError(@"twoFinger _momentumScrollWaitGroup timed out. _momentumScrollWaitGroup info: %@. Will crash.", _momentumScrollWaitGroup.debugDescription);
        
        /// Clean up
        ///     Unhide mouse pointer
        if (!runningPreRelease()) {
            [PointerFreeze unfreeze]; /// Only in release so the crashes are more noticable in prereleases
        }
        
        /// Crash
        assert(false);
        exit(EXIT_FAILURE); /// Make sure it also quits in release builds
    }
    
    /// Unfreeze dispatch point
    
    [PointerFreeze unfreeze];
}

+ (void)suspend {
//    [PointerFreeze unfreeze];
}

+ (void)unsuspend {
    
//    /// Convert and add vectors to get current pointer location
//    Vector usageOrigin = { .x = _drag->usageOrigin.x, .y = _drag->usageOrigin.y };
//    Vector pointerPosVec = addedVectors(usageOrigin, _drag->originOffset);
//    CGPoint pointerPos = CGPointMake(pointerPosVec.x, pointerPosVec.y);
//
//    pointerPos = getRoundedPointerLocation();
//
//    /// Freeze pointer
//    if (OtherConfig.freezePointerDuringModifiedDrag) {
//        [PointerFreeze freezePointerAtPosition:pointerPos];
//    } else {
//        [PointerFreeze freezeEventDispatchPointAtPosition:pointerPos];
//    }
}

@end
