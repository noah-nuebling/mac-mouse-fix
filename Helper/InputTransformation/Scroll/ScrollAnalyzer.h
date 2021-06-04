//
// --------------------------------------------------------------------------
// ScrollAnalyzer.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScrollAnalyzer : NSObject

// Input

+ (void)updateWithTickOccuringNowWithDelta:(int64_t)delta axis:(MFAxis)axis;

+ (void)resetState;

// Analysis results

+ (int)consecutiveScrollTickCounter;
+ (int)consecutiveScrollSwipeCounter;
+ (BOOL)scrollDirectionDidChange;
+ (double)ticksPerSecond;
+ (double)ticksPerSecondRaw;

@end

NS_ASSUME_NONNULL_END
