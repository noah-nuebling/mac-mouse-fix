//
// --------------------------------------------------------------------------
// ModifiedDragOutputTwoFingerSwipe.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
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
    ///     When using a twoFingerModifedDrag and performance drops, the timeBetweenEvents can sometimes be erratic, and this sometimes leads apps like Xcode to start their custom momentumScroll algorithms with way too high speeds (At least I think that's whats going on) So we're using an animator to smooth things out and hopefully achieve more consistent behaviour
    ///
    ///     Edit: Using the _smoothingAnimator forces us to use some very very error prone parallel code. I should seriously consider if this is the best approach.
    ///         Maybe you could just introduce a delay between the last two events? I feel like the lack of that delay causes most of the erratic behaviour.
    
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
    if (OtherConfig.freezePointerDuringModifiedDrag) {
        [PointerFreeze freezePointerAtPosition:_drag->usageOrigin];
    } else {
        [PointerFreeze freezeEventDispatchPointAtPosition:_drag->usageOrigin];
    }
    
    /// Setup animator
    [_smoothingAnimator resetSubPixelator];
    [_smoothingAnimator linkToMainScreen];
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
    [_smoothingAnimator startWithParams:^NSDictionary<NSString *,id> * _Nonnull(Vector valueLeft, BOOL isRunning, Curve * _Nullable curve) {

        NSMutableDictionary *p = [NSMutableDictionary dictionary];

        Vector currentVec = { .x = deltaX*twoFingerScale, .y = deltaY*twoFingerScale };
        Vector combinedVec = addedVectors(currentVec, valueLeft);

        if (firstCallback) eventPhase = kIOHIDEventPhaseBegan;

        /// Debug

        static double lastTs = 0;
        double ts = CACurrentMediaTime();
        double tsDiff = ts - lastTs;
        lastTs = ts;

        DDLogDebug(@"Time since last baseAnimator start: %f", tsDiff * 1000);

        /// Get return values

        if (magnitudeOfVector(combinedVec) == 0.0) {
            DDLogWarn(@"Not starting baseAnimator since combinedMagnitude is 0.0");
            p[@"doStart"] = @NO;
        } else {
            p[@"vector"] = nsValueFromVector(combinedVec);
            p[@"duration"] = @(3.0/60); // @(0.00001); // @(0.04);
            p[@"curve"] = ScrollConfig.linearCurve;
        }

        /// Debug

        static Vector scrollDeltaSum = { .x = 0, .y = 0};
        scrollDeltaSum.x += fabs(currentVec.x);
        scrollDeltaSum.y += fabs(currentVec.y);
        DDLogDebug(@"Delta sum pre-animator: (%f, %f)", scrollDeltaSum.x, scrollDeltaSum.y);
        DDLogDebug(@"Value left pre-animator: (%f, %f)", valueLeft.x, valueLeft.y);

        /// Return

        return p;

    } integerCallback:^(Vector deltaVec, MFAnimationCallbackPhase animatorPhase, MFMomentumHint subCurve) {

        /// Debug

//        static double scrollDeltaSummm = 0;
//        scrollDeltaSummm += fabs(valueDeltaD);
//        DDLogDebug(@"Delta sum in-animator: %f", scrollDeltaSummm);

//        DDLogDebug(@"\n twoFingerDragSmoother - delta: (%f, %f), phase: %d", deltaVec.x, deltaVec.y, animatorPhase);

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
    
    DDLogDebug(@"Entering _momentumScrollWaitGroup");
    dispatch_group_enter(_momentumScrollWaitGroup);
    
    [GestureScrollSimulator afterStartingMomentumScroll:^{
        
        DDLogDebug(@"Leaving _momentumScrollWaitGroup");
        dispatch_group_leave(_momentumScrollWaitGroup);
        
        /// Delete momentumScroll callback
        ///     App will crash if dispatch_group_leave() is called again!
        [GestureScrollSimulator afterStartingMomentumScroll:NULL];
    }];
    
    /// Start momentumScroll
    
    if (_smoothingAnimator.isRunning) { /// Let _smoothingAnimator start momentumScroll
        _smoothingAnimatorShouldStartMomentumScroll = YES;
        
    } else { /// Start momentumScroll directly
        [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded autoMomentumScroll:YES invertedFromDevice:_drag->naturalDirection];
    }
    
    /// Wait until momentumScroll has been started
    ///     We want to wait for momentumScroll so it is started before the warp. That way momentumScroll will work, even if we moved the pointer outside the scrollView that we started scrolling in.
    ///     Waiting here will also block all other items on _twoFingerDragQueue
    
    ///     This whole _momentumScrollWaitGroup thing is pretty risky, because if there is any race condition and we don't leave the group properly, then we need to crash the app
    ///     It's really hard to avoid race conditions here though the different  eventTap threads that control ModifiedDrag and all the different nested dispatch queues of ModifiedDrag and its smoothingAnimator and the GestureScrollSimulator queue and it's momentumAnimator's queue and then all those animators have displayLinks with their own queues.... All of these queues call each other in a mix of synchronous and asynchronous, and it all needs to work perfectly without race conditions or deadlocks... Really hard to keep track of.
    ///     If we manage to figure this out, this will make for a great user experience though.
    
    /// Wait for momentumScroll to start
    
    DDLogDebug(@"Waiting for dispatch group");
    
    intptr_t rt = dispatch_group_wait(_momentumScrollWaitGroup, dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC));
    
    if (rt != 0) {
        
        /// Log error
        DDLogError(@"_momentumScrollWaitGroup timed out. _momentumScrollWaitGroup info: %@. Will crash.", _momentumScrollWaitGroup.debugDescription);
        
        /// Clean up
        ///     Unhide mouse pointer
        if (!SharedUtility.runningPreRelease) {
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
