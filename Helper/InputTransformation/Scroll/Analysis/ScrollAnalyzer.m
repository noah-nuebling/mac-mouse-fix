//
// --------------------------------------------------------------------------
// ScrollAnalyzer.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ScrollAnalyzer.h"
#import <Cocoa/Cocoa.h>
#import "Scroll.h"
#import "ScrollConfigObjC.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "ScrollUtility.h"

@implementation ScrollAnalyzer

#pragma mark Init

+ (void)initialize
{
    if (self == [ScrollAnalyzer class]) {
        
        /// Setup smoothing algorithm for `timeBetweenTicks`
        
//        _tickTimeSmoother = [[DoubleExponentialSmoother alloc] initWithA:ScrollConfig.ticksPerSecondSmoothingInputValueWeight
//                                                                       y:ScrollConfig.ticksPerSecondSmoothingTrendWeight
//                                                           initialValue1:ScrollConfig.consecutiveScrollTickIntervalMax
//                                                           initialValue2:ScrollConfig.consecutiveScrollTickIntervalMax];
//        _tickTimeSmoother = [[RollingAverage alloc] initWithCapacity:3
//                                                       initialValues:@[@(ScrollConfig.consecutiveScrollTickIntervalMax)]];
        
//        _tickTimeSmoother = [[RollingAverage alloc] initWithCapacity:1]; /// Capacity 1 turns off smoothing
        /// ^ No smoothing feels the best.
        ///     - Without smoothing, there will somemtimes randomly be extremely small `timeSinceLastTick` values. I was worried that these would overdrive the acceleration curve, producing extremely high `pxToScrollForThisTick` values at random. But since we've capped the acceleration curve to a maximum `pxToScrollForThisTick` this isn't a noticable issue anymore.
        ///     - No smoothing is way more responsive than RollingAverage
        ///     - No smoothing is more responsive than DoubleExponential. And when there are extremely small `timeSinceLastTick` values (avoiding these is the whole reason we use smoothing), the DoubleExponentialSmoother will extrapolate the trend and make it even *worse* - sometimes it even produces negative values!
        ///     - We could try if a light exponential smoothing would feel better, but this is good enought for now
        
        _tickTimeSmoother = [[ExponentialSmoother alloc] initWithA:ScrollConfig.ticksPerSecond_ExponentialSmoothing_InputValueWeight];
        /// ^ Light exponential smoothing is also worse than no smoothing at all. The loss in responsiveness is not worth the added "stability"z   imo
        
    }
}

#pragma mark Vars

/// Constant

static NSObject<Smoother> *_tickTimeSmoother;

/// Dynamic

static double _previousScrollTickTimeStamp = 0;
static int64_t _previousDelta = 0;

static int _consecutiveScrollTickCounter;
static int _consecutiveScrollSwipeCounter;
static int _consecutiveScrollSwipeCounter_ForFreeScrollWheel;

#pragma mark - Interface

/// Reset ticks and swipes

+ (void)resetState {
    
    _previousScrollTickTimeStamp = 0;
    
    _previousDelta = 0;
    /// ^ This needs to be set to 0, so that scrollDirectionDidChange will definitely evaluate to NO on the next tick
    
    /// The following are probably not necessary to reset, because the above resets will indirectly cause them to be reset on the next tick
    _consecutiveScrollTickCounter = 0;
    _consecutiveScrollSwipeCounter = 0;
    
//    [_smoother resetState]; /// Don't do this here
    
    /// We shouldn't definitely not reset _scrollDirectionDidChange here, because a scroll direction change causes this function to be called, and then the information about the scroll direction changing would be lost as it's reset immediately
}

/// This is the main input function which should be called on each scrollwheel tick event
+ (ScrollAnalysisResult)updateWithTickOccuringNowWithDirection:(int64_t)delta {
    
    /// Update directionDidChange
    ///     Checks whether the scrolling direction is different from when this function was last called. Writes result into `_scrollDirectionDidChange`.
    
    BOOL scrollDirectionDidChange = NO;
    
    if (![ScrollUtility sameSign:delta and:_previousDelta]) {
        scrollDirectionDidChange = YES;
    }
    _previousDelta = delta;
    
    /// Reset state if scroll direction changed
    if (scrollDirectionDidChange) {
        [self resetState];
    }

    /// Get raw seconds since last tick
    
    double thisScrollTickTimeStamp = CACurrentMediaTime();
    double secondsSinceLastTick = thisScrollTickTimeStamp - _previousScrollTickTimeStamp;
    
    /// Update consecutive tick and swipe counters
    
    if (secondsSinceLastTick > ScrollConfig.consecutiveScrollTickIntervalMax) { /// Should `secondsSinceLastTick` be smoothed *before* this comparison?
        /// This is the first consecutive tick
        
        /// Update swipes
        
        if (ScrollConfig.scrollSwipeThreshold_inTicks <= _consecutiveScrollTickCounter) {
            /// The last batch of consecutive ticks had more ticks in it than the swipe threshold
            
            double thisScrollSwipeTimeStamp = CACurrentMediaTime();
            double interval = thisScrollSwipeTimeStamp - _previousScrollTickTimeStamp;
            
            if (interval <= ScrollConfig.consecutiveScrollSwipeMaxInterval) {
                /// Time between the last tick of the previous swipe and the first tick of the current swipe (now) is smaller than swipe threshold

                _consecutiveScrollSwipeCounter += 1;
                _consecutiveScrollSwipeCounter_ForFreeScrollWheel += 1;
            }
            else goto resetSwipes;
            
        } else {
        resetSwipes:
            _consecutiveScrollSwipeCounter = 0;
            _consecutiveScrollSwipeCounter_ForFreeScrollWheel = 0;
        }
        
        /// Update ticks
        
        _consecutiveScrollTickCounter = 0;
        
    } else { /// This is not the first consecutive tick
        _consecutiveScrollTickCounter += 1;
    }
    
    /// Update `_consecutiveScrollSwipeCounter_ForFreeScrollWheel`
    ///     It's a little awkward to update this down here after the other swipe-updating code , but we need to do it this way because we need the `consecutiveTickCounter` to be updated after the stuff above but before this
    
    if (_consecutiveScrollTickCounter >= ScrollConfig.scrollSwipeMax_inTicks) {
        if (_consecutiveScrollTickCounter % ScrollConfig.scrollSwipeMax_inTicks == 0) {
            _consecutiveScrollSwipeCounter_ForFreeScrollWheel += 1;
        }
    }
    
    /// Smoothing
    
    double smoothedTimeBetweenTicks;
    
    if (_consecutiveScrollTickCounter == 0) { /// This is first consecutive tick – reset smoothedTimeBetweenTicks state
        smoothedTimeBetweenTicks = DBL_MAX;
        ///     ^ DBL_MAX indicates that it has been longer than `consecutiveScrollTickIntervalMax` since the last tick. Maybe we should define a constant for this.
        [_tickTimeSmoother reset];
    } else { /// This is not first consecutive tick
        smoothedTimeBetweenTicks = [_tickTimeSmoother smoothWithValue:secondsSinceLastTick];
    }
    
    /// Update `_previousScrollTickTimeStamp` for next call
    ///     This needs to be executed after `updateConsecutiveScrollSwipeCounterWithSwipeOccuringNow()`, because that function uses `_previousScrollTickTimeStamp`
    
    _previousScrollTickTimeStamp = thisScrollTickTimeStamp;
    
    /// Debug
    
//    DDLogDebug(@"tickTime: %f, Smoothed tickTime: %f", secondsSinceLastTick, smoothedTimeBetweenTicks);
    
    /// Output
    
    ScrollAnalysisResult result = (ScrollAnalysisResult) {
        .consecutiveScrollTickCounter = _consecutiveScrollTickCounter,
        .consecutiveScrollSwipeCounter = _consecutiveScrollSwipeCounter,
        .consecutiveScrollSwipeCounter_ForFreeScrollWheel = _consecutiveScrollSwipeCounter_ForFreeScrollWheel,
        .scrollDirectionDidChange = scrollDirectionDidChange,
        .timeBetweenTicks = smoothedTimeBetweenTicks,
        /// ^ We should only use `smoothedTimeBetweenTicks` instead of `secondsSinceLastTick`. Because it's our best approximation of the true value of `secondsSinceLastTick`. If `smoothedTimeBetweenTicks`, doesn't work, adjust the alorithm until it does
        ///     Edit: Actually we've turned smoothing off for now so the two are the same.
        .timeBetweenTicksRaw = secondsSinceLastTick,
    };
    
    
    return result;
}

@end
