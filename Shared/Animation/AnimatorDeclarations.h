//
// --------------------------------------------------------------------------
// Animator.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#ifndef AnimatorDeclarations_h
#define AnimatorDeclarations_h

@import Foundation;

#pragma mark - General

typedef struct {
    double value;
    double duration;
//    id curve; /// Putting an Objc type into the struct makes the struct invisible to swift
} MFAnimatorStartParams;

typedef enum {
    kMFAnimationPhaseStart = 0,
    kMFAnimationPhaseRunningStart = 1, /// Animation has been started again while it was already running
    kMFAnimationPhaseContinue = 2,
    kMFAnimationPhaseEnd = 4,
    kMFAnimationPhaseNone = 16,
} MFAnimationPhase;

typedef enum {
    kMFAnimationCallbackPhaseStart = 0,
    kMFAnimationCallbackPhaseContinue = 1,
    kMFAnimationCallbackPhaseEnd = 2, /// Deltas will always be zero for this phase
    kMFAnimationCallbackPhaseCanceled = 3, /// Passed after stop() is called on the animator. Deltas will be zero.
    kMFAnimationCallbackPhaseNone = 4,
} MFAnimationCallbackPhase;

#pragma mark - Hybrid curves

typedef enum {
    kMFHybridSubCurveNone = 0,
    kMFHybridSubCurveBase = 1,
    kMFHybridSubCurveDrag = 2,
} MFHybridSubCurve;

typedef enum {
    kMFMomentumHintNone     = kMFHybridSubCurveNone,
    kMFMomentumHintGesture  = kMFHybridSubCurveBase,
    kMFMomentumHintMomentum = kMFHybridSubCurveDrag,
    
//    kMFMomentumHintMomentumFromGesture = 4,
//    kMFMomentumHintGestureFromMomentum = 8,
    
} MFMomentumHint;
/// ^ When animating a HybridCurve with TouchAnimator, and the the Drag (second) subcurve of the HybridCurve is configured to behave like the Trackpad momentum scrolling curve, then the Drag Curve is well suited to be used to send momentumScroll events instead of normal gestureScroll events. This enables scroll bouncing and nicer swiping between pages. The MFMomentumHint suggests to the client of the animator when to send momentumScrollEvents and when to send gestureScrollEvents.

#endif /* Animator_h */
