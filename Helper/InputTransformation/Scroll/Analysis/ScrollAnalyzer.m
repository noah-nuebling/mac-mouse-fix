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
        _tickTimeSmoother = [[DoubleExponentialSmoother alloc] initWithA:ScrollConfig.ticksPerSecondSmoothingInputValueWeight
                                                                       y:ScrollConfig.ticksPerSecondSmoothingTrendWeight
                                                           initialValue1:ScrollConfig.consecutiveScrollTickIntervalMax
                                                           initialValue2:ScrollConfig.consecutiveScrollTickIntervalMax];
    }
}

#pragma mark Vars

// Constant

static DoubleExponentialSmoother *_tickTimeSmoother;

// Dynamic

static double _previousScrollTickTimeStamp = 0;
static double _previousScrollSwipeTimeStamp = 0;
static MFScrollDirection _previousDirection = kMFScrollDirectionNone;

static int _consecutiveScrollTickCounter;
static int _consecutiveScrollSwipeCounter;

#pragma mark - Interface

// Reset ticks and swipes

+ (void)resetState {
    
    _previousScrollTickTimeStamp = 0;
    _previousScrollSwipeTimeStamp = 0;
    
    _previousDirection = kMFScrollDirectionNone;
    // ^ This needs to be set to none, so that scrollDirectionDidChange will definitely evaluate to NO on the next tick
    
    // The following are probably not necessary to reset, because the above resets will indirectly cause them to be reset on the next tick
    _consecutiveScrollTickCounter = 0;
    _consecutiveScrollSwipeCounter = 0;
    
//    [_smoother resetState]; // Don't do this here
    
    // We shouldn't definitely not reset _scrollDirectionDidChange here, because a scroll direction change causes this function to be called, and then the information about the scroll direction changing would be lost as it's reset immediately
}

/// This is the main input function which should be called on each scrollwheel tick event
+ (ScrollAnalysisResult)updateWithTickOccuringNowWithDirection:(MFScrollDirection)direction
{
    
    // Update directionDidChange
    // Checks whether the sign of input number is different from when this function was last called. Writes result into `_scrollDirectionDidChange`.
    
    BOOL scrollDirectionDidChange = NO;
    
    if (direction != _previousDirection && _previousDirection != kMFScrollDirectionNone) {
        scrollDirectionDidChange = YES;
    }
    _previousDirection = direction;
    
    // Reset state if scroll direction changed
    if (scrollDirectionDidChange) {
        [self resetState];
    }

    /// Get raw seconds since last tick
    
    double thisScrollTickTimeStamp = CACurrentMediaTime();
    double secondsSinceLastTick = thisScrollTickTimeStamp - _previousScrollTickTimeStamp;
    _previousScrollTickTimeStamp = thisScrollTickTimeStamp;
    
    /// Get smoothed time between ticks
    
    double smoothedTimeBetweenTicks = [_tickTimeSmoother smoothWithValue:secondsSinceLastTick];
    
    /// Update consecutive tick and swipe counters
    ///     We used to do this based on raw `secondsSinceLastTick` instead of smoothed `smoothedTimeBetweenTicks`. Not entirely sure this makes sense.
    
    if (smoothedTimeBetweenTicks > ScrollConfig.consecutiveScrollTickIntervalMax) {
        /// This is the first consecutive tick
        
        if (ScrollConfig.scrollSwipeThreshold_inTicks <= _consecutiveScrollTickCounter) {
            /// If the last batch of consecutive ticks had more ticks in it than the swipe threshold, then update the swipe counter.
            updateConsecutiveScrollSwipeCounterWithSwipeOccuringNow();
        }
        _consecutiveScrollTickCounter = 0;
        
    } else { /// This is not the first consecutive tick
        _consecutiveScrollTickCounter += 1;
    }
    
    /// Reset timeBetweenTicks state if this is first consecutive tick
    
    if (_consecutiveScrollTickCounter == 0) {
        smoothedTimeBetweenTicks = DBL_MAX;
            ///     ^ DBL_MAX indicates that it has been longer than `consecutiveScrollTickIntervalMax` since the last tick. Maybe we should define a constant for this.
        [_tickTimeSmoother reset];
    }
    
    /// Output
    
    ScrollAnalysisResult result = (ScrollAnalysisResult) {
        .consecutiveScrollTickCounter = _consecutiveScrollTickCounter,
        .consecutiveScrollSwipeCounter = _consecutiveScrollSwipeCounter,
        .scrollDirectionDidChange = scrollDirectionDidChange,
        .timeBetweenTicks = smoothedTimeBetweenTicks,
        /// ^ We should only return `smoothedTimeBetweenTicks` instead of `timeSinceLastTick`. Because it's our best approximation of the true value of `timeSinceLastTick`. If `smoothedTimeBetweenTicks`, doesn't work, adjust the alorithm until it does.
    };
    
    return result;
}

static void updateConsecutiveScrollSwipeCounterWithSwipeOccuringNow() {
    
    double thisScrollSwipeTimeStamp = CACurrentMediaTime();
    double intervall = thisScrollSwipeTimeStamp - _previousScrollTickTimeStamp; // Time between the last tick of the previous swipe and the first tick of the current swipe (now)
    
    if (intervall <= ScrollConfig.consecutiveScrollSwipeMaxInterval) {
        _consecutiveScrollSwipeCounter += 1;
    } else {
        _consecutiveScrollSwipeCounter = 0;
    }
    
    _previousScrollSwipeTimeStamp = thisScrollSwipeTimeStamp;
}

@end
