//
// --------------------------------------------------------------------------
// ScrollAnalyzer.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "Constants.h"
#import "ScrollConfigObjC.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "ModificationUtility.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScrollAnalyzer : NSObject

typedef struct {
    
    int64_t consecutiveScrollTickCounter;
    double consecutiveScrollSwipeCounter;
    BOOL scrollDirectionDidChange;
    CFTimeInterval timeBetweenTicks;
    
    CFTimeInterval DEBUG_timeBetweenTicksRaw;
    /// ^ Unsmoothed time between ticks. For debugging, don't use this.
    int64_t DEBUG_consecutiveScrollSwipeCounterRaw;
    /// ^ Mice with free scrollwheels (e.g. MX Master) make it hard to input several consecutive scroll swipes, because the swipes will bleed into each other and will be registered as a very long sequence of consecutive ticks instead.
    ///     `consecutiveScrollSwipeCounter` will count these long tick sequences as several consecutive swipes, while `DEBUG_consecutiveScrollSwipeCounterRaw` will not
    
} ScrollAnalysisResult;

+ (BOOL)peekIsFirstConsecutiveTickWithTickOccuringAt:(CFTimeInterval)thisScrollTickTimeStamp direction:(MFDirection)direction config:(ScrollConfig *)scrollConfig;

+ (ScrollAnalysisResult)updateWithTickOccuringAt:(CFTimeInterval)thisScrollTickTimeStamp direction:(MFDirection)direction config:(ScrollConfig *)scrollConfig;

+ (void)resetState;

+ (NSString *)scrollAnalysisResultDescription:(ScrollAnalysisResult)analysis;

@end

NS_ASSUME_NONNULL_END
