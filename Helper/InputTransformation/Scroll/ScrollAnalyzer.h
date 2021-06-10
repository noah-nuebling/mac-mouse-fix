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
#import "ScrollConfigObjC.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScrollAnalyzer : NSObject

typedef struct {
    
    int64_t consecutiveScrollTickCounter;
    int64_t consecutiveScrollSwipeCounter;
    BOOL scrollDirectionDidChange;
    CFTimeInterval smoothedTimeBetweenTicks;
    CFTimeInterval timeSinceLastTick; /// Only use this for debugging. Use `smoothedTimeBetweenTicks` for everything else. If `smoothedTimeBetweenTicks` doesn't work, adjust the smoothing parameters until it does
    
} ScrollAnalysisResult;

+ (ScrollAnalysisResult)updateWithTickOccuringNowWithDirection:(MFScrollDirection)direction;

+ (void)resetState;

@end

NS_ASSUME_NONNULL_END
