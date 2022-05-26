//
// --------------------------------------------------------------------------
// CurveDeclarations.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#ifndef CurveDeclarations_h
#define CurveDeclarations_h

typedef enum {
    kMFHybridSubCurveNone = 0,
    kMFHybridSubCurveBase = 1,
    kMFHybridSubCurveDrag = 2,
} MFHybridSubCurve;

typedef enum {
    kMFHybridSubCurvePhaseNone = kMFHybridSubCurveNone,
    kMFHybridSubCurvePhaseBase = kMFHybridSubCurveBase,
    kMFHybridSubCurvePhaseDrag = kMFHybridSubCurveDrag,
    
    kMFHybridSubCurvePhaseDragBegan = 4,
    kMFHybridSubCurvePhaseBaseFromDrag = 8,
    
} MFHybridSubCurvePhase;
/// ^ When animating a HybridCurve, the animator will tell the animation callback whether it's currently on the Base (first) or the Drag (second) subcurve of the HybridCurve, and whether the subcurve has just changed to Drag (then it will send kMFHybridSubCurvePhaseDragBegan)

#endif /* CurveDeclarations_h */
