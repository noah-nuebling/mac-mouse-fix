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
#import "ScrollUtility.h"
#import "TransformationUtility.h"

@implementation ScrollAnalyzer

#pragma mark Init

+ (void)initialize {
    if (self == [ScrollAnalyzer class]) {
        
        /// Get default config
        ///     Note that this will never update because the init function only runs once. So make sure that whatever values you use here aren't intended to update!
        ScrollConfig *_scrollConfig = [ScrollConfig currentConfig];
        
        /// Setup smoothing algorithm for `timeBetweenTicks`
        
        _tickTimeSmoother = [[RollingAverage alloc] initWithCapacity:3]; /// Capacity 1 turns off smoothing
        /// ^ No smoothing feels the best.
        ///     - Without smoothing, there will somemtimes randomly be extremely small `timeSinceLastTick` values. I was worried that these would overdrive the acceleration curve, producing extremely high `pxToScrollForThisTick` values at random. But since we've capped the acceleration curve to a maximum `pxToScrollForThisTick` this isn't a noticable issue anymore.
        ///     - No smoothing is way more responsive than RollingAverage
        ///     - No smoothing is more responsive than DoubleExponential. And when there are extremely small `timeSinceLastTick` values (avoiding these is the whole reason we use smoothing), the DoubleExponentialSmoother will extrapolate the trend and make it even *worse* - sometimes it even produces negative values!
        ///     - We could try if a light exponential smoothing would feel better, but this is good enought for now
        
//        _tickTimeSmoother = [[ExponentialSmoother alloc] initWithA:_scrollConfig.ticksPerSecond_ExponentialSmoothing_InputValueWeight];
        /// ^ Light exponential smoothing is also worse than no smoothing at all. The loss in responsiveness is not worth the added "stability"z   imo
        
    }
}

#pragma mark Vars

/// Constant

static NSObject<Smoother> *_tickTimeSmoother;

/// Dynamic

static double _previousScrollTickTimeStamp = 0;
static MFDirection _previousDirection = kMFDirectionNone;

static int _consecutiveScrollTickCounter;
static int _consecutiveScrollSwipeCounter;
static int _consecutiveScrollSwipeCounter_ForFreeScrollWheel;

#pragma mark - Interface

/// Reset ticks and swipes

+ (void)resetState {
    
    _previousScrollTickTimeStamp = 0;
    
    _previousDirection = kMFDirectionNone;
    /// ^ This needs to be set to 0, so that scrollDirectionDidChange will definitely evaluate to NO on the next tick
    
    /// The following are probably not necessary to reset, because the above resets will indirectly cause them to be reset on the next tick
    _consecutiveScrollTickCounter = 0;
    _consecutiveScrollSwipeCounter = 0;
    
//    [_tickTimeSmoother resetState]; /// Don't do this here
    
    /// We shouldn't definitely not reset _scrollDirectionDidChange here, because a scroll direction change causes this function to be called, and then the information about the scroll direction changing would be lost as it's reset immediately
}

+ (BOOL)peekIsFirstConsecutiveTickWithTickOccuringAt:(CFTimeInterval)thisScrollTickTimeStamp withDirection:(MFDirection)direction withConfig:(ScrollConfig *)scrollConfig {
    
    /// Checks if a given tick is the first consecutive tick. Without changing state.
    
    /// Return direction change
    if (directionChanged(_previousDirection, direction)) {
        return YES;
    }
    
    /// Get seconds since last tick
    double secondsSinceLastTick = thisScrollTickTimeStamp - _previousScrollTickTimeStamp;
    /// Get timeout
    BOOL didTimeOut = secondsSinceLastTick > scrollConfig.consecutiveScrollTickIntervalMax;
    
    return didTimeOut;
}

/// This is the main input function which should be called on each scrollwheel tick event
+ (ScrollAnalysisResult)updateWithTickOccuringAt:(CFTimeInterval)thisScrollTickTimeStamp withDirection:(MFDirection)direction withConfig:(ScrollConfig *)scrollConfig {
    
    /// Update directionDidChange
    ///     Checks whether the scrolling direction is different from when this function was last called. Writes result into `_scrollDirectionDidChange`.
    
    BOOL scrollDirectionDidChange = NO;
    
    if (directionChanged(_previousDirection, direction)) {
        scrollDirectionDidChange = YES;
    }
    _previousDirection = direction;
    
    /// Reset state if scroll direction changed
    if (scrollDirectionDidChange) {
        [self resetState];
    }

    /// Get raw seconds since last tick
    double secondsSinceLastTick = thisScrollTickTimeStamp - _previousScrollTickTimeStamp;
    
    /// Clip time since last tick to >= 15ms
    ///     Not sure this makes sense
    ///     15ms seemst to be smallest that you can naturally produce, but when performance drops, the secondsSinceLastTick that we see can be much smaller sometimes.
    ///     We're also addressing this issue through `consecutiveScrollTickInterval_AccelerationEnd`, but capping the timeBetweenTicks here let's us be more free with the acceleration curve.
    if (secondsSinceLastTick < 15/1000) {
        secondsSinceLastTick = 15/1000;
    }
    
    /// Update consecutive tick and swipe counters
    
    if (secondsSinceLastTick > scrollConfig.consecutiveScrollTickIntervalMax) { /// Should `secondsSinceLastTick` be smoothed *before* this comparison?
        /// This is the first consecutive tick
        
        /// Update swipes
        
        if (scrollConfig.scrollSwipeThreshold_inTicks <= _consecutiveScrollTickCounter) {
            /// The last batch of consecutive ticks had more ticks in it than the swipe threshold
            
            double thisScrollSwipeTimeStamp = thisScrollTickTimeStamp;
            double interval = thisScrollSwipeTimeStamp - _previousScrollTickTimeStamp;
            
            if (interval <= scrollConfig.consecutiveScrollSwipeMaxInterval) {
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
    
    if (_consecutiveScrollTickCounter >= scrollConfig.scrollSwipeMax_inTicks) {
        if (_consecutiveScrollTickCounter % scrollConfig.scrollSwipeMax_inTicks == 0) {
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
