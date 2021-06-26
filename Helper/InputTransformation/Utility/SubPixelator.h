//
// --------------------------------------------------------------------------
// SubPixelator.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SubPixelator : NSObject

+ (SubPixelator *)ceilPixelator;
+ (SubPixelator *)roundPixelator;
+ (SubPixelator *)biasedPixelator;
+ (SubPixelator *)floorPixelator;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithRoundingFunction:(double (*)(double))roundingFunction;
- (instancetype)initAsBiasedPixelator;

- (int64_t)intDeltaWithDoubleDelta:(double)inp;
- (int64_t)peekIntDeltaWithDoubleDelta:(double)inpDelta;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
