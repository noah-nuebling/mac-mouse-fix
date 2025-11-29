//
// --------------------------------------------------------------------------
// BiMap.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BidirectionalMap<L, R> : NSObject

- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (void)setLeftValue:(L)leftValue forRightValue:(R)rightValue;
- (void)removePairForLeftValue:(L)leftValue;
- (void)removePairForRightValue:(R)rightValue;
- (R)rightValueForLeftValue:(L)leftValue;
- (L)leftValueForRightValue:(R)rightValue;

@end

NS_ASSUME_NONNULL_END
