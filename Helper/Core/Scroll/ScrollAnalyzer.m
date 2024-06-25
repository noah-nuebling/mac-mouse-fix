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
    /// Notes:
    /// - We originally introduced this to protect against putting super high tickSpeeds (that were the result of measurement errors) into the accelerationCurve, making the scrolling randomly too fast. But since then we've introduced other measures to protect against this, such as capped accelerationCurves and `consecutiveScrollTickInterval_AccelerationEnd` (And the tickTime smoothing is arguably also a measure against this?). Not sure if this is good or necessary.
    
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
        ///     We purely use `_consecutiveScrollSwipeCounter` to drive fastScroll. That's why we don't want to increase it when the user scrolls slowly. -> Should consider renaming to signify coupling with fastScroll
        
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
        [_tickTimeSmoother reset];
        
        /// Initialize smoother with tickMax
        /// Notes:
        /// - Initializing the smoother with the tickMax should make things a bit more stable. Not sure if good idea. Added this to make `baseMsPerStepMin` speed up the animation more slowly for fast-but-short scrollSwipes. Without this it feels a bit volatile. This might make the scroll distance acceleration slower though.
        /// - Update: V-Coba complained about scrolling being too slow with 'Precision' enabled in [this issue](https://github.com/noah-nuebling/mac-mouse-fix/issues/795). I'm pretty sure it is caused by this. This is a bit of a dilemma. I do think it might be good in principle to initialize the smoother with something, since otherwise the first timebetweenticks is unsmoothed and can be randomly very high or very low (as I understand currently, it's been a while since a wrote this). However, we've spent a LOT of time perfecting the acceleration curves without this additional smoothing, and adding the smoothing makes the acceleration curves noticably worse, especially with 'Precision' enabled. I don't use 'Precision', but from my limited testing I have the same impression as V-Coba.  So I'll turn the smoothing off for now, which should restore the original scroll-distance-acceleration, and try to tune the `baseMsPerStepMin` down a bit so that it doesn't feel as volatile even without the extra smoothing.
        /// - Plan: At some point, take more time to explore adding smoothing here, and then tune the acceleration curves and the `baseMsPerStepMin` to feel as good as possible with that.
        /// - Lesson: Don't ship changes to these fundamental aspects of the scrolling system, if you don't have a lot of time to test and tune curves to the changes.
        /// - Further reflection:
        ///     - My theory of how this affects scrolling in practise is that
        ///     - 1. The other way that this affects scrolling is that it makes it so the scrolling accelerates over time even if the speed of your finger is constant. That's an inevitable effect of the smoothing, which I thought would make things more 'stable' and 'predictable'. It does make things more stable in some sense, but to me, right now, this acceleration-over-time effect makes things less predictable and feel more volatile. But maybe my perception could change if we tune the acceleration curves accordingly or if I get used to it.
        ///     - 2. it makes the distance of small-but-fast 2-3 tick swipes closer to the unaccelerated distance. This has an especially large effect when 'Precise' is enabled because there the unaccelerated distance is super small. For high smoothness I actually liked the smaller distance for small-but-fast 2-3 tick swipes. 
        ///         - I think the way to think about that is that those small swipes are actually *easier* to execute that single ticks (might be mouse-dependent). That's because to do the single ticks you need to put tension in your finger in order to be precise. So it's easier to do a bunch of small swipes than a bunch of single ticks. I think this is also why I see quite a bunch of people prefer the 'Precise' setting - I makes it so you have to put less tension in your fingers to scroll a smaller distance instead of a too large distance.
        ///         - We should therefore very carefully tune the distance for those small swipes to be comfortable and consistent. For high smoothness, I think currently distance is a bit too high for many settings.
        ///         - HORRIBLE HACK: For now I've enabled the tickSmoother initing, but only for smoothness high and precise turned off. I like it better. I think what we're doing here is simply make the speed lower for small scroll swipes. For the other settings I didn't like the additional smoothing, I think because it either made things too slow or because the speedup over time made things harder to control. But not sure.
        ///         - TODO: Remove the hack and adjust acceleration curves instead.
        /// - Even further reflection:
        ///     - Since the first first timeBetweenTicks isn't smoothed at all, and is completely subject to any measurement errors, I don't think the smoothing of the consecutive ticks even makes any sense, right?
        
        if (scrollConfig.u_smoothness == kMFScrollSmoothnessHigh && !scrollConfig.u_precise) {
            /// HORRIBLE HACK
            (void)[_tickTimeSmoother smoothWithValue:scrollConfig.consecutiveScrollTickIntervalMax];
        }
        
    } else { /// This is not first consecutive tick
        assert(secondsSinceLastTick <= scrollConfig.consecutiveScrollTickIntervalMax);
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
        .DEBUG_timeBetweenTicksRaw = secondsSinceLastTick, /// Unsmoothed timeBetweenTicks
        .DEBUG_consecutiveScrollSwipeCounterRaw = _consecutiveScrollSwipeCounter,
    };
    
    /// TESTING
//    result.timeBetweenTicks = scrollConfig.consecutiveScrollTickIntervalMax + 1.0;
    
    /// Ensure that `tick <= max`
    ///
    /// Discussion:
    /// - tickTime was apparently sometimes `>` max (and `!= DBL_MAX`) inside Scroll.m, leading to assertion-failed-crashes.
    /// - I thought about the code and I don't understand how this can happen. So we're trying to log the weird state and recover without crashing. We're doing the log-and-recover attempts both in here and inside `Scroll.m` since we're not sure how and where the erroneous state arises.
    ///
    /// Also see:
    /// - For further discussion, see the "Ensure that `tick <= max`" section inside `Scroll.m`
    
    if (result.timeBetweenTicks > scrollConfig.consecutiveScrollTickIntervalMax && result.timeBetweenTicks != DBL_MAX) {
        DDLogError(@"ScrollAnalyzer - smoothed tickTime is over max. This is a bug but we can recover. Analysis result: %@", [self scrollAnalysisResultDescription:result]);
        result.timeBetweenTicks = scrollConfig.consecutiveScrollTickIntervalMax;
        assert(false);
    }
    
    return result;
}

#pragma mark - Debug

+ (NSString *)scrollAnalysisResultDescription:(ScrollAnalysisResult)analysis {
    
    NSString *tickTimeStr = analysis.timeBetweenTicks == DBL_MAX ? @"9999" : stringf(@"%f", analysis.timeBetweenTicks); /// 9999 signals that the analyzed tick is the first consecutive tick.
    
    return stringf(@"dirChange: %d, ticks: %lld, swipes: %f, tickTime: %@, rawTickTime: %f, rawSwipes: %lld", analysis.scrollDirectionDidChange, analysis.consecutiveScrollTickCounter, analysis.consecutiveScrollSwipeCounter, tickTimeStr, analysis.DEBUG_timeBetweenTicksRaw, analysis.DEBUG_consecutiveScrollSwipeCounterRaw);
}

@end
