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
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "TransformationUtility.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScrollAnalyzer : NSObject

typedef struct {
    
    int64_t consecutiveScrollTickCounter;
    int64_t consecutiveScrollSwipeCounter;
    int64_t consecutiveScrollSwipeCounter_ForFreeScrollWheel;
    /// ^ Mice with free scrollwheels (e.g. MX Master) make it hard to input several consecutive scroll swipes, because the swipes will bleed into each other and will be registered as a very long sequence of consecutive ticks instead.
    ///     `consecutiveScrollSwipeCounter_ForFreeScrollWheel` will count these long tick sequences as several consecutive swipes.
    BOOL scrollDirectionDidChange;
    CFTimeInterval timeBetweenTicks;
    CFTimeInterval timeBetweenTicksRaw;
    /// ^ Unsmoothed time between ticks. For debugging, don't use this. 
    
} ScrollAnalysisResult;

+ (BOOL)peekIsFirstConsecutiveTickWithTickOccuringAt:(CFTimeInterval)thisScrollTickTimeStamp withDirection:(MFDirection)direction withConfig:(ScrollConfig *)scrollConfig;

+ (ScrollAnalysisResult)updateWithTickOccuringAt:(CFTimeInterval)thisScrollTickTimeStamp withDirection:(MFDirection)direction withConfig:(ScrollConfig *)scrollConfig;

+ (void)resetState;

@end

NS_ASSUME_NONNULL_END
