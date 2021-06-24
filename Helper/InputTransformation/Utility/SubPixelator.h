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

- (instancetype)init NS_UNAVAILABLE;

- (int64_t)intDeltaWithDoubleDelta:(double)inp;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
