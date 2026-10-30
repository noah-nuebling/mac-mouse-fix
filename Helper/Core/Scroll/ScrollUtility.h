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

/// Pure direction arithmetic for scroll input. Kept dependency-free so it can be unit tested standalone.
///     - The inversion setting is chosen by the input axis: horizontal input (tilt wheel, horizontal buttons) uses `horizontalInvertSetting`, vertical input uses `verticalInvertSetting`.
///     - `horizontalModifier` only changes the output axis (a vertical wheel turned into horizontal scrolling). It doesn't change the setting used, because the user is still scrolling vertically.
static inline MFDirection MFScrollDirectionForInput(MFAxis inputAxis,
                                                    int64_t inputDelta,
                                                    MFScrollInversion verticalInvertSetting,
                                                    MFScrollInversion horizontalInvertSetting,
                                                    BOOL horizontalModifier) {

    MFScrollInversion invertSetting = (inputAxis == kMFAxisHorizontal) ? horizontalInvertSetting : verticalInvertSetting;
    int inputSign = (inputDelta > 0) - (inputDelta < 0);
    int effectiveAxisDirection = inputSign * invertSetting;

    if (inputAxis == kMFAxisHorizontal || horizontalModifier) {
        return (effectiveAxisDirection == -1) ? kMFDirectionLeft : kMFDirectionRight;
    } else {
        return (effectiveAxisDirection == -1) ? kMFDirectionDown : kMFDirectionUp;
    }
}

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
+ (BOOL)point:(CGPoint)p1 isAboutTheSameAs:(CGPoint)p2 threshold:(int)th;

+ (CGEventRef)makeScrollEventHorizontal:(CGEventRef)event;
+ (BOOL)sameSign:(double)n and:(double)m;
+ (MFAxis)axisForVerticalDelta:(int64_t)deltaV horizontalDelta:(int64_t)deltaH;
+ (MFDirection)directionForInputAxis:(MFAxis)axis
                           inputDelta:(int64_t)inputDelta
                verticalInvertSetting:(MFScrollInversion)verticalInvertSetting
              horizontalInvertSetting:(MFScrollInversion)horizontalInvertSetting
                   horizontalModifier:(BOOL)horizontalModifier;
+ (BOOL)mouseDidMove;
+ (void)updateMouseDidMoveWithEvent:(CGEventRef)event;
+ (BOOL)frontMostAppDidChange;
+ (void)updateFrontMostAppDidChange;

@end

NS_ASSUME_NONNULL_END
