//
// --------------------------------------------------------------------------
// ScrollAnalyzer.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ScrollAnalyzer.h"
#import <Cocoa/Cocoa.h>
#import "Scroll.h"
#import "ScrollUtility.h"
#import "ModificationUtility.h"

@implementation ScrollAnalyzer

#pragma mark Init

+ (void)initialize {
    if (self == [ScrollAnalyzer class]) {
        
        /// Get default config
        ///     Note that this will never update because the init function only runs once. So make sure that whatever values you use here aren't intended to update!
//        ScrollConfig *_scrollConfig = [ScrollConfig copyOfConfig];
        
        /// Setup smoothing algorithm for `timeBetweenTicks`
        
        _tickTimeSmoother = [[RollingAverage alloc] initWithCapacity:3]; /// Capacity 1 turns off smoothing
        /// ^ No smoothing feels the best.
        ///     - Without smoothing, there will somemtimes randomly be extremely small `timeSinceLastTick` values. I was worried that these would overdrive the acceleration curve, producing extremely high `pxToScrollForThisTick` values at random. But since we've capped the acceleration curve to a maximum `pxToScrollForThisTick` this isn't a noticable issue anymore.
        ///     - No smoothing is way more responsive than RollingAverage
        ///     - No smoothing is more responsive than DoubleExponential. And when there are extremely small `timeSinceLastTick` values (avoiding these is the whole reason we use smoothing), the DoubleExponentialSmoother will extrapolate the trend and make it even *worse* - sometimes it even produces negative values!
        ///     - We could try if a light exponential smoothing would feel better, but this is good enought for now
        ///     Edit: I do prefer the smoothness over the responsiveness now. Like a LOT. Capacity 3 works well.
        
//        _tickTimeSmoother = [[ExponentialSmoother alloc] initWithA:_scrollConfig.ticksPerSecond_ExponentialSmoothing_InputValueWeight];
        /// ^ Light exponential smoothing is also worse than no smoothing at all. The loss in responsiveness is not worth the added "stability" imo
        
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
static double _consecutiveScrollSwipeCounter_ForFreeScrollWheel;

static int _ticksInCurrentConsecutiveSwipeSequence;
static CFTimeInterval _consecutiveSwipeSequenceStartTime;

#pragma mark - Interface

/// Reset ticks and swipes

+ (void)resetState {
    
    _previousScrollTickTimeStamp = 0;
    
    _previousDirection = kMFDirectionNone;
    /// ^ This needs to be set to 0, so that scrollDirectionDidChange will definitely evaluate to NO on the next tick
    
    /// The following are probably not necessary to reset, because the above resets will indirectly cause them to be reset on the next tick
    _consecutiveScrollTickCounter = 0;
    _consecutiveScrollSwipeCounter = 0;
    
    _ticksInCurrentConsecutiveSwipeSequence = 0;
    _consecutiveSwipeSequenceStartTime = -1;
//    [_tickTimeSmoother resetState]; /// Don't do this here
    
    /// We shouldn't definitely not reset _scrollDirectionDidChange here, because a scroll direction change causes this function to be called, and then the information about the scroll direction changing would be lost as it's reset immediately
}

+ (BOOL)peekIsFirstConsecutiveTickWithTickOccuringAt:(CFTimeInterval)thisScrollTickTimeStamp direction:(MFDirection)direction config:(ScrollConfig *)scrollConfig {
    
    /// Checks if a given tick is the first consecutive tick. Without changing state.
    
    /// Return direction change
    if (directionChanged(_previousDirection, direction)) {
        return YES;
    }
    
    /// Get seconds since last tick
    double secondsSinceLastTick = thisScrollTickTimeStamp - _previousScrollTickTimeStamp;
    /// Get timeout
    BOOL didTimeOut = secondsSinceLastTick > scrollConfig.consecutiveScrollTickIntervalMax; /// Should secondsSinceLastTick be smoothed before the comparison?
    
    return didTimeOut;
}

/// This is the main input function which should be called on each scrollwheel tick event
+ (ScrollAnalysisResult)updateWithTickOccuringAt:(CFTimeInterval)thisScrollTickTimeStamp direction:(MFDirection)direction config:(ScrollConfig *)scrollConfig {
    
    /// Update scrollDirectionDidChange
    ///     Checks whether the scrolling direction is different from when this function was last called.
    
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
    
    /// Clip time since last tick to realistic value
    ///     We're also addressing this issue by capping the acceleration curve (See `consecutiveScrollTickInterval_AccelerationEnd`), but capping the timeBetweenTicks here let's us be more free with the acceleration curve.
    
    if (secondsSinceLastTick < scrollConfig.consecutiveScrollTickIntervalMin) {
        secondsSinceLastTick = scrollConfig.consecutiveScrollTickIntervalMin;
    }
    
    /// Update consecutive tick and swipe counters
    
    _ticksInCurrentConsecutiveSwipeSequence += 1; /// Not totally sure if it makes sense to update this up here, but it seems to work well
    
    if (secondsSinceLastTick > scrollConfig.consecutiveScrollTickIntervalMax) { /// Should `secondsSinceLastTick` be smoothed *before* this comparison?
        /// This is the first consecutive tick
        
        /// --- Update swipes ---
        
        /// Guard: Enough ticks in last swipe
        
        if (scrollConfig.scrollSwipeThreshold_inTicks > _consecutiveScrollTickCounter)
            goto resetSwipes;
            
        /// Guard: Not too much time since last swipe
        
        double thisScrollSwipeTimeStamp = thisScrollTickTimeStamp;
        double interval = thisScrollSwipeTimeStamp - _previousScrollTickTimeStamp;
        
        if (interval > scrollConfig.consecutiveScrollSwipeMaxInterval)
            goto resetSwipes; /// Time between the last tick of the previous swipe and the first tick of the current swipe (now) is greater than swipe threshold
        
        /// Guard: Average speed high enough
        ///     We purely use _consecutiveScrollSwipeCounter to drive fastScroll. That's why we don't want to increase it when the user scrolls slowly. -> Should consider renaming to signify coupling with fastScroll
        
        double tickSpeedThisSwipeSequence = ((double)_ticksInCurrentConsecutiveSwipeSequence) / (CACurrentMediaTime() - _consecutiveSwipeSequenceStartTime);
        
        if (tickSpeedThisSwipeSequence < scrollConfig.consecutiveScrollSwipeMinTickSpeed)
            goto resetSwipes;
        
        /// Increment swipes
        
        _consecutiveScrollSwipeCounter += 1;
        _consecutiveScrollSwipeCounter_ForFreeScrollWheel += 1;
        
        goto updateTicks; /// Don't resetSwipes
        
    resetSwipes: /// Using goto even thought my professor said I'm not allowed to muahahaha
        _consecutiveScrollSwipeCounter = 0;
        _consecutiveScrollSwipeCounter_ForFreeScrollWheel = 0;
        _consecutiveSwipeSequenceStartTime = CACurrentMediaTime();
        _ticksInCurrentConsecutiveSwipeSequence = 0;
        
    updateTicks:
        
        /// --- Update ticks ---
        _consecutiveScrollTickCounter = 0;
        
    } else { /// This is not the first consecutive tick
        
        /// --- Update ticks ---
        _consecutiveScrollTickCounter += 1;
    }
    
    /// Update `_consecutiveScrollSwipeCounter_ForFreeScrollWheel`
    ///     It's a little awkward to update this down here after the other swipe-updating code , but we need to do it this way because we need the `consecutiveTickCounter` to be updated after the stuff above but before this
    if (_consecutiveScrollTickCounter >= scrollConfig.scrollSwipeMax_inTicks) {
        _consecutiveScrollSwipeCounter_ForFreeScrollWheel += 1.0/scrollConfig.scrollSwipeMax_inTicks;
    }
    
    /// Smoothing
    
    double smoothedTimeBetweenTicks;
    
    if (_consecutiveScrollTickCounter == 0) { /// This is first consecutive tick –> reset smoothedTimeBetweenTicks state
        
        /// Reset smoothed tickTime
        /// Note: `DBL_MAX` indicates that it has been longer than `consecutiveScrollTickIntervalMax` since the last tick. Maybe we should define a constant for this.
        smoothedTimeBetweenTicks = DBL_MAX;
        
        /// Reset smoother:
        /// Note: Initializing the smoother with the tickMax should make things a bit more stable. Not sure if good idea. Added this to make `baseMsPerStepMin` speed up the animation more slowly for fast-but-short scrollSwipes. This might make the scroll distance acceleration slower though.
        [_tickTimeSmoother reset];
        (void)[_tickTimeSmoother smoothWithValue:scrollConfig.consecutiveScrollTickIntervalMax];
        
        
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
        .consecutiveScrollSwipeCounter = _consecutiveScrollSwipeCounter_ForFreeScrollWheel,
        .scrollDirectionDidChange = scrollDirectionDidChange,
        .timeBetweenTicks = smoothedTimeBetweenTicks,
        /// ^  `smoothedTimeBetweenTicks` is our best approximation of the true value of `secondsSinceLastTick`. Don't use secondsSinceLastTick directly.
        .DEBUG_timeBetweenTicksRaw = secondsSinceLastTick,
        .DEBUG_consecutiveScrollSwipeCounterRaw = _consecutiveScrollSwipeCounter,
    };
    
    return result;
}

#pragma mark - Debug

+ (NSString *)scrollAnalysisResultDescription:(ScrollAnalysisResult)analysis {
    
    NSString *timeDeltaStr = analysis.timeBetweenTicks > 5.0 ? @"?" : stringf(@"%f", analysis.timeBetweenTicks);
    
    return stringf(@"dirChange: %d, ticks: %lld, swipes: %f, time: %@, rawTime: %f, rawSwipes: %lld", analysis.scrollDirectionDidChange, analysis.consecutiveScrollTickCounter, analysis.consecutiveScrollSwipeCounter, timeDeltaStr, analysis.DEBUG_timeBetweenTicksRaw, analysis.DEBUG_consecutiveScrollSwipeCounterRaw);
}

@end
