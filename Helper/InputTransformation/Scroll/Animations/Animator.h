//
// --------------------------------------------------------------------------
// Animator.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#ifndef Animator_h
#define Animator_h

typedef enum {
    kMFAnimationPhaseStart,
    kMFAnimationPhaseRunningStart, /// Animation has been started again while it was already running
    kMFAnimationPhaseContinue,
    kMFAnimationPhaseEnd,
    kMFAnimationPhaseStartingEnd, /// Used when there is only one delta in the animation. So that delta is the first _and_ the last one.
    kMFAnimationPhaseNone,
} MFAnimationPhase;

#endif /* Animator_h */
