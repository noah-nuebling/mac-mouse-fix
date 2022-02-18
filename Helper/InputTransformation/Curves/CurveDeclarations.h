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
    kMFHybridSubCurveBase,
    kMFHybridSubCurveDrag,
    kMFHybridSubCurveNone,
} MFHybridSubCurve;
/// ^ When animating a HybridCurve, the animator will tell the animation callback whether it's currently on the Base (first) or the Drag (second) subcurve of the HybridCurve.

#endif /* CurveDeclarations_h */
