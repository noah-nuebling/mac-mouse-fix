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

NS_ASSUME_NONNULL_BEGIN

@interface VectorSubPixelator : NSObject
+ (VectorSubPixelator *)pixelator;
- (instancetype)init NS_UNAVAILABLE;
- (MFVector)intVectorWithDoubleVector:(MFVector)inpVec;
@end

NS_ASSUME_NONNULL_END
