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

+ (void)updateWithTickOccuringNowWithDelta:(int64_t)delta
                                      axis:(MFAxis)axis
          out_consecutiveScrollTickCounter:(int64_t *)out_consecutiveScrollTickCounter
         out_consecutiveScrollSwipeCounter:(int64_t *)out_consecutiveScrollSwipeCounter
              out_scrollDirectionDidChange:(BOOL *)out_scrollDirectionDidChange
                        out_ticksPerSecond:(double *)out_ticksPerSecond
                     out_ticksPerSecondRaw:(double *)out_ticksPerSecondRaw;

+ (void)resetState;

@end

NS_ASSUME_NONNULL_END
