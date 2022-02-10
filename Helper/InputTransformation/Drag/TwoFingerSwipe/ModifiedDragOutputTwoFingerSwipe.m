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
#import "ScrollUtility.h"

@implementation ModifiedDragOutputTwoFingerSwipe

#pragma mark - Vars

static ModifiedDragState *_drag;

static PixelatedVectorAnimator *_smoothingAnimator;
static BOOL _smoothingAnimatorShouldStartMomentumScroll = NO;
static dispatch_group_t _momentumScrollWaitGroup;

#pragma mark - Init

+ (void)load_Manual {
    
    /// Setup smoothingAnimator
    ///     When using a twoFingerModifedDrag and performance drops, the timeBetweenEvents can sometimes be erratic, and this sometimes leads apps like Xcode to start their custom momentumScroll algorithms with way too high speeds (At least I think that's whats going on) So we're using an animator to smooth things out and hopefully achieve more consistent behaviour
    ///     Edit:
    ///     TODO: maybe it would be smart to just delay the time between the last two events to be reasonable. That seemst to be matters for the erratic behaviour. Using the _smoothingAnimator forces us to use dispatch_group and stuff which is very very error prone. I should seriously consider if this is the best approach
    
    _smoothingAnimator = [[PixelatedVectorAnimator alloc] init];
    
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
    
    /// Freeze pointer
    if (OtherConfig.freezePointerDuringModifiedDrag) {
        [PointerFreeze freezePointerAtPosition:_drag->usageOrigin];
    } else {
        [PointerFreeze freezeEventDispatchPointAtPosition:_drag->usageOrigin];
    }
    
    /// Reset subpixelator
    [_smoothingAnimator resetSubPixelator];
    
    /// Link animator to main screen
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
    IOHIDEventPhaseBits dragPhase = _drag->phase;
    
    /// Start animator
    ///     We made this a BaseAnimator instead of a PixelatedAnimator for debugging
    [_smoothingAnimator startWithParams:^NSDictionary<NSString *,id> * _Nonnull(Vector valueLeft, BOOL isRunning, id<AnimationCurve> _Nullable curve) {
        
        NSMutableDictionary *p = [NSMutableDictionary dictionary];
        
        Vector currentVec = { .x = deltaX*twoFingerScale, .y = deltaY*twoFingerScale };
        Vector combinedVec = addedVectors(currentVec, valueLeft);
        
        if (dragPhase == kIOHIDEventPhaseBegan) eventPhase = kIOHIDEventPhaseBegan;
        
        /// Debug
        
        static double lastTs = 0;
        double ts = CACurrentMediaTime();
        double tsDiff = ts - lastTs;
        lastTs = ts;
        
        DDLogDebug(@"Time since last baseAnimator start: %f", tsDiff * 1000);
        
        /// Return
        
        if (magnitudeOfVector(combinedVec) == 0.0) {
            DDLogWarn(@"Not starting baseAnimator since combinedMagnitude is 0.0");
            p[@"doStart"] = @NO;
        } else {
            p[@"vector"] = valueFromVector(combinedVec);
            p[@"duration"] = @(3.0/60); // @(0.00001); // @(0.04);
            p[@"curve"] = ScrollConfig.linearCurve;
        }
        
        static Vector scrollDeltaSum = { .x = 0, .y = 0};
        scrollDeltaSum.x += fabs(currentVec.x);
        scrollDeltaSum.y += fabs(currentVec.y);
        DDLogDebug(@"Delta sum pre-animator: (%f, %f)", scrollDeltaSum.x, scrollDeltaSum.y);
        DDLogDebug(@"Value left pre-animator: (%f, %f)", valueLeft.x, valueLeft.y);
        
        /// Return
        return p;
        
    } integerCallback:^(Vector valueDeltaD, double timeDelta, MFAnimationPhase phase) {
        
//        static double scrollDeltaSummm = 0;
//        scrollDeltaSummm += fabs(valueDeltaD);
//        DDLogDebug(@"Delta sum in-animator: %f", scrollDeltaSummm);
        
        // TODO: Change this
        /// Even if we use a pixelated animator here (at least in it' current form), this is not going to work right.
        /// Why? Because when we make our delta the magnitude of the current direction, then the x and y values of the direction vector will not be integers, even if the delta is an int (which is what pixelated animator guarantees)
        /// Possible solutions:
        ///     - Create a new 'PixelatedVectorAnimator'
        ///     - Subpixelate in the callback of BaseAnimator
        ///         -> Will produce (0,0) deltas sometimes I think
        ///         -> But are we sure that (0,0) deltas are that bad? I don't remember why we avoid them so much. I think real events from the trackpad never have (0,0) deltas though
        ///     - Make separate Pixelated Animator for x and y values.
        ///         - This is a horrible idea. We'd have to sync them with condition vars and mutex locks and then when one skips a frame because it has a (0,0) delta we're f'ed.
        
        // TODO: v This is just random thoughts about animator, move it into the animator class or into a notes app
        /// Other random ideas for improving Animator:
        ///     1 We could turn the second to last delta event into the last one and send the remaining delta there. Then the last delta wouldn't be smaller than the others (But it would be bigger instead, which is probably not better - not that great of an idea)
        ///     2. We could sync animation time with the frame refreshes
        ///         - To be more precise, we could:
        ///             2.1. Set the animation start time at the first frame callback of the animation
        ///                 - If we do this the very first callback would never produce a delta, which might make things less responsive
        ///                 -> Instead we could set the animation start point to one frame before the first frame callback retroactively. Seems kind of strange but it might just work
        ///             2.2. Round the overall animation time to be divisible by the time between frames
        ///                 - When we combine 1. and 2. this should make all times between frames equal. So the first and last frame callback won't randomly produce larger or smaller deltas than the others
        ///                 - This might be useful because the last delta that is being produced determines the momentum scroll speed in some apps like Xcode
        ///                 - This would also make make idea 1. obsolete
        ///     3. We could make the animator send one last 'post-end' event after the last event which sends a delta.
        ///         Currently we use the last delta event to start momentum scroll in some cases (and ignore the delta that is being sent). We do this because the last delta will usually be smaller which will make momentum scroll too slow in apps that implement their own momentum scroll algortihm like Xcode, and because we need to have a little time between the last delta event and the momentum scroll start, because otherwise there will be a jittery jump when momentum scroll starts in apps like Xcode.
        ///         -> If we combine idea's 2. and 3. we could avoid this hack
        ///         -> But it's honestly probably not worth it, since all it would improve is not skipping those 2 pixels before momentum scroll starts, which no one will ever notice and maybe cleaning up the code a little bit.
        ///
        
//        valueDeltaD.x = ceil(valueDeltaD.x);
//        valueDeltaD.y = ceil(valueDeltaD.y);
        
        if (_smoothingAnimatorShouldStartMomentumScroll
            && (phase == kMFAnimationPhaseEnd || phase == kMFAnimationPhaseStartAndEnd)) {
            /// Due to the nature of PixelatedAnimator, the last delta is almost always much smaller. This will make apps like Xcode start momentumScroll at a too low speed. Also apps like Xcode will have a litte stuttery jump when the time between the kIOHIDEventPhaseEnded event and the previous event is very small
            ///     Our solution to these two problems is to set the _smoothingAnimatorShouldStartMomentumScroll flag when the user releases the button, and if this flag is set, we transform the last delta callback from the animator into the kIOHIDEventPhaseEnded GestureScroll event. The deltas from this last callback are lost like this, but no one will notice.
            
            /// Start momentum scroll
            [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded];
            /// Reset flag
            _smoothingAnimatorShouldStartMomentumScroll = NO;
        } else {
            /// Post event
            [GestureScrollSimulator postGestureScrollEventWithDeltaX:valueDeltaD.x deltaY:valueDeltaD.y phase:eventPhase];
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
    
    DDLogDebug(@"Entering _momentumScrollWaitGroup");
    dispatch_group_enter(_momentumScrollWaitGroup);
    
    [GestureScrollSimulator afterStartingMomentumScroll:^{
        
        DDLogDebug(@"Leaving _momentumScrollWaitGroup");
        dispatch_group_leave(_momentumScrollWaitGroup);
        
        /// Delete momentumScroll callback
        ///     Otherwise, there might be a 'dispatch_group_leave()' without a corresponding dispatch_group_enter() and the app will crash.
        [GestureScrollSimulator afterStartingMomentumScroll:NULL];
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
    
    DDLogDebug(@"Waiting for dispatch group");
    
    intptr_t rt = dispatch_group_wait(_momentumScrollWaitGroup, dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC));
    
    if (rt != 0) {
        
        /// Log error
        DDLogError(@"_momentumScrollWaitGroup timed out. _momentumScrollWaitGroup info: %@. Will crash.", _momentumScrollWaitGroup.debugDescription);
        
        /// Crash
        assert(false);
    }
    
    /// Unfreeze dispatch point
    
    [PointerFreeze unfreeze];
}

@end
