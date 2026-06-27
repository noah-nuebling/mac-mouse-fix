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
#import "DragInertiaEngine.h"

@implementation ModifiedDragOutputTwoFingerSwipe

#pragma mark - Vars

static ModifiedDragState *_drag;

static TouchAnimator *_smoothingAnimator;
static BOOL _smoothingAnimatorShouldStartMomentumScroll = NO;
static dispatch_group_t _momentumScrollWaitGroup;

/// Fling engine — tracks real mouse velocity for accurate momentum on release
static DragInertiaEngine *_swipeInertia;
/// Most recent raw mouse delta (int64 as received from event tap, for accurate exit velocity)
static int64_t _lastRawDx;
static int64_t _lastRawDy;

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
    
    /// Setup fling inertia engine
    _swipeInertia = [[DragInertiaEngine alloc] init];
}

#pragma mark - Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    
    /// Store drag state
    _drag = dragStateRef;
    
    /// Stop momentum scroll
    ///     Notes:
    ///     - I think we should remove the initializeWithDragState: method from the protocol entirely (Update: Not totally sure why I thought this) All of the scrollStop interactions between I still have to think about.
    ///     - Initially, here, we just called [GestureScrollSimulator stopMomentumScroll], then later we replaced it with [Scroll resetState], which stops both the momentumScroll animator and the scrollwheel animator.
    ///     - On the trackpad driver, scrolling seems to stop whenever any clicks or gestures come in. Maybe we should do a similar type of top-down management of when scrolling is stopped, instead of doing it here. Feels sorta hacky to do it here.

    [Scroll resetState];
    
    /// Cancel any running fling and stop its momentum scroll output
    [_swipeInertia cancel];
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
    [_smoothingAnimator linkToMainScreen];
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    double twoFingerScale = 1.0;
    
    /// Store raw delta and track velocity for fling on release
    _lastRawDx = (int64_t)deltaX;
    _lastRawDy = (int64_t)deltaY;
    double unused1, unused2;
    [_swipeInertia trackDeltaX:deltaX deltaY:deltaY outDeltaX:&unused1 outDeltaY:&unused2];
    
    /// Post event via smoothingAnimator (correct queue context)
    
    static IOHIDEventPhaseBits eventPhase = kIOHIDEventPhaseUndefined;
    IOHIDEventPhaseBits firstCallback = _drag->firstCallback;
    
    [_smoothingAnimator startWithParams:^NSDictionary<NSString *,id> * _Nonnull(Vector valueLeft, BOOL isRunning, Curve * _Nullable curve, Vector currentSpeed) {

        NSMutableDictionary *p = [NSMutableDictionary dictionary];
        
        Vector currentVec = { .x = deltaX*twoFingerScale, .y = deltaY*twoFingerScale };
        Vector combinedVec = addedVectors(currentVec, valueLeft);

        if (firstCallback) eventPhase = kIOHIDEventPhaseBegan;

        static double lastTs = 0;
        double ts = CACurrentMediaTime();
        double tsDiff = ts - lastTs;
        lastTs = ts;
        DDLogDebug(@"twoFinger SmoothingAnimator start - time since last: %f", tsDiff * 1000);

        if (magnitudeOfVector(combinedVec) == 0.0) {
            DDLogWarn(@"twoFinger Not starting baseAnimator since combinedMagnitude is 0.0");
            p[@"doStart"] = @NO;
        } else {
            p[@"vector"] = nsValueFromVector(combinedVec);
            p[@"curve"] = ScrollConfig.linearCurve;
            p[@"duration"] = @(3.0/60.0);
        }

        static Vector scrollDeltaSum = { .x = 0, .y = 0};
        scrollDeltaSum.x += fabs(currentVec.x);
        scrollDeltaSum.y += fabs(currentVec.y);
        DDLogDebug(@"twoFinger Delta sum pre-animator: (%f, %f)", scrollDeltaSum.x, scrollDeltaSum.y);
        DDLogDebug(@"twoFinger Value left pre-animator: (%f, %f)", valueLeft.x, valueLeft.y);

        return p;

    } integerCallback:^(Vector deltaVec, MFAnimationCallbackPhase animatorPhase, MFMomentumHint subCurve) {

        DDLogDebug(@"\n twoFinger smoothingAnimator callback - delta: (%f, %f), phase: %d, shouldStartMomentumScroll: %d", deltaVec.x, deltaVec.y, animatorPhase, _smoothingAnimatorShouldStartMomentumScroll);
        
        if (animatorPhase == kMFAnimationCallbackPhaseEnd) {
             if (_smoothingAnimatorShouldStartMomentumScroll) {
                 /// Send Ended without auto-momentum, then drive our own fling (same DragCurve physics as RotateZoom)
                 [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded autoMomentumScroll:NO invertedFromDevice:_drag->naturalDirection];
                 [self startFling];
                 _lastRawDx = 0; _lastRawDy = 0;
             }
            _smoothingAnimatorShouldStartMomentumScroll = false;
            return;
        }

        [GestureScrollSimulator postGestureScrollEventWithDeltaX:deltaVec.x deltaY:deltaVec.y phase:eventPhase autoMomentumScroll:YES invertedFromDevice:_drag->naturalDirection];
        eventPhase = kIOHIDEventPhaseChanged;
    }];
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancelation {
    
    if (cancelation) {
        if (_smoothingAnimator.isRunning) {
            [_smoothingAnimator cancel];
        }
        [_swipeInertia cancel];
        [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded autoMomentumScroll:NO invertedFromDevice:_drag->naturalDirection];
        [GestureScrollSimulator suspendMomentumScroll];
        [PointerFreeze unfreeze];
        return;
    }
    
    /// Normal release: use DragInertiaEngine fling (DragCurve physics, same as RotateZoom)
    /// for momentum instead of GestureScrollSimulator's built-in weaker auto-momentum.
    
    if (_smoothingAnimator.isRunning) {
        _smoothingAnimatorShouldStartMomentumScroll = YES;
    } else {
        /// Animator already finished — fire Ended and start fling directly
        [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded autoMomentumScroll:NO invertedFromDevice:_drag->naturalDirection];
        [self startFling];
        _lastRawDx = 0; _lastRawDy = 0;
    }
    
    [PointerFreeze unfreeze];
}

+ (void)startFling {
    BOOL naturalDirection = _drag->naturalDirection;
    __block BOOL firstFlingCallback = YES;
    
    /// Non-linear velocity scale: hard flings get extra momentum, gentle releases stay gentle.
    /// _swipeInertia internally tracks EMA velocity — we infer exit speed from last raw deltas.
    /// A hard flick produces large raw deltas (20-60px/event); gentle stop is 1-3px/event.
    double rawSpeed = sqrt((double)_lastRawDx * _lastRawDx + (double)_lastRawDy * _lastRawDy);
    double velocityScale = 1.0 + fmin(rawSpeed / 20.0, 2.0); /// 1x–3x boost at rawSpeed≥40
    
    [_swipeInertia startFlingWithVelocityScale:velocityScale callback:^(double dx, double dy) {
        CGMomentumScrollPhase phase = firstFlingCallback ? kCGMomentumScrollPhaseBegin : kCGMomentumScrollPhaseContinue;
        firstFlingCallback = NO;
        [GestureScrollSimulator postMomentumScrollDirectlyWithDeltaX:dx deltaY:dy momentumPhase:phase invertedFromDevice:naturalDirection];
    }];
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
