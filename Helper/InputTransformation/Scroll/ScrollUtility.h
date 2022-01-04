//
// --------------------------------------------------------------------------
// ScrollUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

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
+ (BOOL)point:(CGPoint)p1 isAboutTheSameAs:(CGPoint)p2 threshold:(int)th;

+ (CGEventRef)makeScrollEventHorizontal:(CGEventRef)event;
+ (BOOL)sameSign:(double)n and:(double)m;
+ (BOOL)mouseDidMove;
+ (void)updateMouseDidMove;
+ (BOOL)frontMostAppDidChange;
+ (void)updateFrontMostAppDidChange;
+ (BOOL)scrollDirectionDidChange;
+ (void)updateScrollDirectionDidChange:(long long)thisScrollValue;

+ (int)consecutiveScrollTickCounter;
+ (int)consecutiveScrollSwipeCounter;
+ (void)updateConsecutiveScrollTickAndSwipeCountersWithTickOccuringNow;
+ (void)resetConsecutiveTicksAndSwipes;

@end

NS_ASSUME_NONNULL_END
