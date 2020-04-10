//
// --------------------------------------------------------------------------
// ScrollUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScrollUtility : NSObject

+ (CGEventRef)normalizedEventWithPixelValue:(int)lineHeight;
+ (CGEventRef)invertScrollEvent:(CGEventRef)event direction:(int)dir;
+ (void)logScrollEvent:(CGEventRef)event;
+ (BOOL)point:(CGPoint)p1 isAboutTheSameAs:(CGPoint)p2 threshold:(int)th;

+ (CGEventRef)makeScrollEventHorizontal:(CGEventRef)event;
+ (double)signOf:(double)n;
+ (BOOL)sameSign:(double)n and:(double)m;
+ (BOOL)mouseDidMove;
+ (BOOL)frontMostAppDidChange;
+ (BOOL)scrollDirectionDidChange:(long long)signedVal;

+ (int)consecutiveScrollTickCounter;
+ (int)consecutiveScrollSwipeCounter;
+ (void)updateConsecutiveScrollTickAndSwipeCountersWithTickOccuringNow;
+ (void)resetConsecutiveTicksAndSwipes;

@end

NS_ASSUME_NONNULL_END
