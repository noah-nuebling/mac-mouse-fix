//
// --------------------------------------------------------------------------
// ScrollUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import "Constants.h"
#import "ScrollConfigObjC.h"
#import "VectorUtility.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScrollUtility : NSObject

typedef enum {
    kMFPhaseNone,
    kMFPhaseStart,
    kMFPhaseLinear,
    kMFPhaseMomentum,
    kMFPhaseEnd,
} MFDisplayLinkPhase;

+ (NSDictionary *)MFScrollPhaseToIOHIDEventPhase;


+ (CGEventRef)createPixelBasedScrollEventWithValuesFromEvent:(CGEventRef)event __deprecated_msg("HHHH Use `Utility_HelperApp:createEventWithValuesFromEvent:` instead");
+ (CGEventRef)createNormalizedEventWithPixelValue:(int)lineHeight;
+ (CGEventRef)invertScrollEvent:(CGEventRef)event direction:(int)dir;
+ (void)logScrollEvent:(CGEventRef)event;

+ (CGEventRef)makeScrollEventHorizontal:(CGEventRef)event;
+ (BOOL)sameSign:(double)n and:(double)m;
+ (MFAxis)axisForVerticalDelta:(int64_t)deltaV horizontalDelta:(int64_t)deltaH;
+ (MFDirection)directionForInputAxis:(MFAxis)axis
                           inputDelta:(int64_t)inputDelta
                        invertSetting:(MFScrollInversion)invertSetting
                   horizontalModifier:(BOOL)horizontalModifier;

/// vvv All this stuff moved somewhere else (Swift implementation) so we can reused ti for buttons, etc

//+ (BOOL)point:(CGPoint)p1 isAboutTheSameAs:(CGPoint)p2 threshold:(int)th;
//+ (BOOL)mouseDidMove;
//+ (void)updateMouseDidMoveWithEvent:(CGEventRef)event;
//+ (BOOL)frontMostAppDidChange;
//+ (void)updateFrontMostAppDidChange;

@end

NS_ASSUME_NONNULL_END
