//
// --------------------------------------------------------------------------
// VectorSubPixelator.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "GestureScrollSimulator.h"
#import "VectorUtility.h"

NS_ASSUME_NONNULL_BEGIN

@interface VectorSubPixelator : NSObject

+ (VectorSubPixelator *)ceilPixelator;
+ (VectorSubPixelator *)roundPixelator;
+ (VectorSubPixelator *)biasedPixelator;
+ (VectorSubPixelator *)floorPixelator;

- (instancetype)init NS_UNAVAILABLE;

- (Vector)intVectorWithDoubleVector:(Vector)inpVec;
- (Vector)peekIntVectorWithDoubleVector:(Vector)inpDelta;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
