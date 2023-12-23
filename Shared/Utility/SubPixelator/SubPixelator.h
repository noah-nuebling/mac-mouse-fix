//
// --------------------------------------------------------------------------
// SubPixelator.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SubPixelator : NSObject

typedef double (* RoundingFunction)(double);

+ (SubPixelator *)ceilPixelator;
+ (SubPixelator *)roundPixelator;
+ (SubPixelator *)biasedPixelator;
+ (SubPixelator *)floorPixelator;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithRoundingFunction:(double (*)(double))roundingFunction threshold:(double)threshold;
- (instancetype)initAsBiasedPixelatorWithThreshold:(double)threshold;

- (void)setPixelationThreshold:(double)threshold;

- (double)intDeltaWithDoubleDelta:(double)inp;
- (double)peekIntDeltaWithDoubleDelta:(double)inpDelta;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
