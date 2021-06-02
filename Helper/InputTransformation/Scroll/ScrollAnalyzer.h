//
// --------------------------------------------------------------------------
// ScrollAnalyzer.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScrollAnalyzer : NSObject

+ (BOOL)scrollDirectionDidChange;
+ (void)updateScrollDirectionDidChange:(long long)thisScrollValue;

+ (int)consecutiveScrollTickCounter;
+ (int)consecutiveScrollSwipeCounter;
+ (void)updateConsecutiveScrollTickAndSwipeCountersWithTickOccuringNow;
+ (void)resetConsecutiveTicksAndSwipes;

@end

NS_ASSUME_NONNULL_END
