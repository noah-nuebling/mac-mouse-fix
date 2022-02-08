//
// --------------------------------------------------------------------------
// ModifiedDragOutputTwoFingerSwipe.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputTwoFingerSwipe.h"
static ModifiedDragState *_drag;
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "TransformationUtility.h"
#import "GestureScrollSimulator.h"
#import "CGSConnection.h"
#import "PointerFreeze.h"

@implementation ModifiedDragOutputTwoFingerSwipe

#pragma mark - Vars

static ModifiedDragState *_drag;

static /*PixelatedAnimator*/ BaseAnimator *_smoothingAnimator;
static BOOL _smoothingAnimatorShouldStartMomentumScroll = NO;
static dispatch_group_t _momentumScrollWaitGroup;

#pragma mark - Init

+ (void)load_Manual {
    
    /// Setup smoothingAnimator
    ///     When using a twoFingerModifedDrag and performance drops, the timeBetweenEvents can sometimes be erratic, and this sometimes leads apps like Xcode to start their custom momentumScroll algorithms with way too high speeds (At least I think that's whats going on) So we're using an animator to smooth things out and hopefully achieve more consistent behaviour
    ///     Edit:
    ///     TODO: maybe it would be smart to just delay the time between the last two events to be reasonable. That seemst to be matters for the erratic behaviour. Using the _smoothingAnimator forces us to use dispatch_group and stuff which is very very error prone. I should seriously consider if this is the best approach
    
    _smoothingAnimator = [[BaseAnimator alloc] init];
    
    /// Setup smoothingGroup
    ///     It allows us to wait until the _smoothingAnimator is done.
    
    _momentumScrollWaitGroup = dispatch_group_create();
}

#pragma mark - Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    
    /// Store drag state
    _drag = dragStateRef;
    
    /// Make cursor settable
    [TransformationUtility makeCursorSettable];
    /// ^ I think we only need to do this once, so it might be better to do this in load_Manual() instead. But it doesn't make a difference.
    
    /// Stop momentum scroll
    ///     TODO: I don't think this is an adequate solution - think deeply about this
    [GestureScrollSimulator stopMomentumScroll];
}

+ (void)handleBecameInUse {
    [PointerFreeze freezeEventDispatchPointAtPosition:_drag->usageOrigin];
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
    static Vector combinedDirection = { .x = 0, .y = 0 };
    
    /// Values that the block should copy instead of reference
    IOHIDEventPhaseBits dragPhase = _drag->phase;
    
    /// Start animator
    ///     We made this a BaseAnimator instead of a PixelatedAnimator for debugging
    [_smoothingAnimator startWithParams:^NSDictionary<NSString *,id> * _Nonnull(double valueLeft, BOOL isRunning, id<AnimationCurve> _Nullable curve) {
        
        NSMutableDictionary *p = [NSMutableDictionary dictionary];
        
        Vector lastDirection = combinedDirection;
        
        Vector currentVec = { .x = deltaX*twoFingerScale, .y = deltaY*twoFingerScale };
        double magnitudeLeft = valueLeft;
        
        Vector vectorLeft = scaledVector(lastDirection, magnitudeLeft);
        Vector combinedVec = addedVectors(currentVec, vectorLeft);
        
        double combinedMagnitude = magnitudeOfVector(combinedVec);
        combinedDirection = unitVector(combinedVec);
        
        if (dragPhase == kIOHIDEventPhaseBegan) eventPhase = kIOHIDEventPhaseBegan;
        
        /// Debug
        
        DDLogDebug(@"Starting BaseAnimator - deltaLeft: %f, inputVec: (%f, %f), oldDirection: (%f, %f), combinedDelta: %f", valueLeft, currentVec.x, currentVec.y, lastDirection.x, lastDirection.y, combinedMagnitude);
        
        static double lastTs = 0;
        double ts = CACurrentMediaTime();
        double tsDiff = ts - lastTs;
        lastTs = ts;
        
        DDLogDebug(@"Time since last baseAnimator start: %f", tsDiff * 1000);
        
        /// Return
        
        if (combinedMagnitude == 0.0) {
            DDLogWarn(@"Not starting baseAnimator since combinedMagnitude is 0.0");
            p[@"doStart"] = @NO;
        } else {
            p[@"value"] = @(combinedMagnitude);
            p[@"duration"] = @(3.0/60); // @(0.00001); // @(0.04);
            p[@"curve"] = ScrollConfig.linearCurve;
        }
        
        return p;
        
    } callback:^(double valueDeltaD, double timeDelta, MFAnimationPhase phase) {
        
        NSInteger valueDelta = ceil(valueDeltaD);
        
        if (_smoothingAnimatorShouldStartMomentumScroll
            && (phase == kMFAnimationPhaseEnd || phase == kMFAnimationPhaseStartAndEnd)) {
            /// Due to the nature of PixelatedAnimator, the last delta is almost always much smaller. This will make apps like Xcode start momentumScroll at a too low speed. Also apps like Xcode will have a litte stuttery jump when the time between the kIOHIDEventPhaseEnded event and the previous event is very small
            ///     Our solution to these two problems is to set the _smoothingAnimatorShouldStartMomentumScroll flag when the user releases the button, and if this flag is set, we transform the last delta callback from the animator into the kIOHIDEventPhaseEnded GestureScroll event. The deltas from this last callback are lost like this, but no one will notice.
            
            /// Start momentum scroll
            [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded];
            /// Reset flag
            _smoothingAnimatorShouldStartMomentumScroll = NO;
        } else {
            /// Get scroll direction
            Vector deltaVec = scaledVector(combinedDirection, valueDelta);
            /// Post event
            [GestureScrollSimulator postGestureScrollEventWithDeltaX:deltaVec.x deltaY:deltaVec.y phase:eventPhase];
            /// Update eventPhase
            if (eventPhase == kIOHIDEventPhaseBegan) eventPhase = kIOHIDEventPhaseChanged;
        }
        
    }];
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancelation {
    
    //        /// Draw puppet cursor
    //        drawPuppetCursorWithFresh(YES, YES);
    //
    //        /// Hide real cursor
    //        [Utility_Transformation hideMousePointer:YES];
    //_
    //        /// Set suppression interval
    //        setSuppressionInterval(kMFEventSuppressionIntervalForStartingMomentumScroll);
    //
    //        /// Set _drag to origin to start momentum scroll there
    //        CGWarpMouseCursorPosition(_drag->origin);
    
    /// Send final scroll event
    ///     This will set off momentum scroll
    //        [_smoothingAnimator onStopWithCallback:^{ /// Do this after the smoothingAnimator is done animating
    //            [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded];
    //        }];
    
    /// Setup waiting for momentumScroll
    
    DDLogDebug(@"Entering dispatch group from deactivate()");
    dispatch_group_enter(_momentumScrollWaitGroup);
    [GestureScrollSimulator afterStartingMomentumScroll:^{
        DDLogDebug(@"Leaving dispatch group from momentumScroll callback (Scheduled by deactivate())");
        dispatch_group_leave(_momentumScrollWaitGroup);
    }];
    
    /// Start momentumScroll
    
    if (_smoothingAnimator.isRunning) { /// Let _smoothingAnimator start momentumScroll
        _smoothingAnimatorShouldStartMomentumScroll = YES; /// _smoothingAnimator callback also manipulates this which is a race cond
        
    } else { /// Start momentumScroll directly
        [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded];
    }
    
    /// Wait until momentumScroll has been started
    ///     We want to wait for momentumScroll so it is started before the warp. That way momentumScrol will still kick in and work, even if we moved the pointer outside the scrollView that we started scrolling in.
    ///     Waiting here will also block all other items on _twoFingerDragQueue
    
    ///     This whole _momentumScrollWaitGroup thing is pretty risky, because if there is any race condition and we don't leave the group properly, then we need to crash the whole app (I think?).
    ///     It's really hard to avoid race conditions here though the different  eventTap threads that control ModifiedDrag and all the different nested dispatch queues of ModifiedDrag and its smoothingAnimator and the GestureScrollSimulator queue and it's momentumAnimator's queue and then all those animators have displayLinks with their own queues.... All of these queues call each other in a mix of synchronous and asynchronous, and it all needs to work perfectly without race conditions or deadlocks... Really hard to keep track of.
    ///     If our code is perfect, then it's a good solution though!
    
    /// Wait for momentumScroll to start
    
    intptr_t rt = dispatch_group_wait(_momentumScrollWaitGroup, dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC));
    if (rt != 0) {
        DDLogWarn(@"Waiting for dispatch group _momentumScrollWaitGroup timed out. _momentumScrollWaitGroup info: %@. Crashing.", _momentumScrollWaitGroup.debugDescription);
        assert(false);
    }
    
    /// Delete momentumScroll callback
    ///     Otherwise, there might be a 'dispatch_group_leave()' without a corresponding dispatch_group_enter() and the app will crash.
    [GestureScrollSimulator afterStartingMomentumScroll:NULL];
    
    /// Unfreeze dispatch point
    [PointerFreeze unfreezeEventDispatchPoint];
}

@end
