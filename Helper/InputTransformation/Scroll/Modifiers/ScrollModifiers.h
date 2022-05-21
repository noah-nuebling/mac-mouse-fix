//
// --------------------------------------------------------------------------
// ModifierInputReceiver.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

typedef enum {
    kMFScrollInputModificationNone,
    kMFScrollInputModificationPrecise,
    kMFScrollInputModificationQuick,
    
} MFScrollInputModification;

typedef enum {
    kMFScrollEffectModificationNone,
    kMFScrollEffectModificationZoom,
    kMFScrollEffectModificationHorizontalScroll,
    kMFScrollEffectModificationRotate,
    kMFScrollEffectModificationFourFingerPinch,
    kMFScrollEffectModificationCommandTab,
    kMFScrollEffectModificationThreeFingerSwipeHorizontal,
} MFScrollEffectModification;

typedef struct {
    MFScrollInputModification inputMod;
    MFScrollEffectModification effectMod;
} MFScrollModificationResult;


/// v For the old Objc implementation of ScrollModifers

#import <CoreGraphics/CoreGraphics.h>
//#import <Foundation/Foundation.h>

@interface ScrollModifiers_old_ : NSObject

//+ (BOOL)horizontalScrolling;
//+ (BOOL)magnificationScrolling;
//
//+ (void)handleMagnificationScrollWithAmount:(double)amount;
//
//+ (void)start;
//+ (void)stop;

@end

