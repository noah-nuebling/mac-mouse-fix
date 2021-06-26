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
    kMFAnimationPhaseStart = 0,
    kMFAnimationPhaseRunningStart = 1, /// Animation has been started again while it was already running
    kMFAnimationPhaseContinue = 2,
    kMFAnimationPhaseEnd = 4,
    kMFAnimationPhaseStartAndEnd = 8, /// Used when there is only one delta in the animation. So that delta is the first _and_ the last one.
    kMFAnimationPhaseNone = 16,
} MFAnimationPhase;

#endif /* Animator_h */
