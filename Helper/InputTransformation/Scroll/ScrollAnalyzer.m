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
#import "ScrollControl.h"
#import "ScrollConfigInterface.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "ScrollUtility.h"

@implementation ScrollAnalyzer

#pragma mark Init

+ (void)initialize
{
    if (self == [ScrollAnalyzer class]) {
        _smoother = [[DoubleExponentialSmoother alloc] initWithA:ScrollConfigInterface.ticksPerSecondSmoothingInputValueWeight y:ScrollConfigInterface.ticksPerSecondSmoothingTrendWeight];
    }
}

#pragma mark Vars

// Constant

static DoubleExponentialSmoother *_smoother;

// Dynamic

static double _previousScrollTickTimeStamp = 0;
static double _previousScrollSwipeTimeStamp = 0;
static int64_t _previousDelta = 0;
static MFAxis _previousAxis = kMFAxisNone;

static int _consecutiveScrollTickCounter;
static int _consecutiveScrollSwipeCounter;

#pragma mark - Interface

// Reset ticks and swipes

+ (void)resetState {
    
    _previousScrollTickTimeStamp = 0;
    _previousScrollSwipeTimeStamp = 0;
    
    _previousDelta = 0;
    _previousAxis = kMFAxisNone;
    // ^ These need to be 0 and kMFAxisNone, so that _scrollDirectionDidChange will definitely evaluate to no on the next tick
    
    
    // The following are probably not necessary to reset, because the above resets will indirectly cause them to be reset on the next tick
    _consecutiveScrollTickCounter = 0;
    _consecutiveScrollSwipeCounter = 0;
    
//    [_smoother resetState]; // Don't do this here
    
    // We shouldn't definitely not reset _scrollDirectionDidChange here, because a scroll direction change causes this function to be called, and then the information about the scroll direction changing would be lost as it's reset immediately
}

/// This is the main input function which should be called on each scrollwheel tick event
+ (ScrollAnalysisResult)updateWithTickOccuringNowWithDelta:(int64_t)delta
                                                      axis:(MFAxis)axis
{
    
    // Update directionDidChange
    // Checks whether the sign of input number is different from when this function was last called. Writes result into `_scrollDirectionDidChange`.
    
    BOOL scrollDirectionDidChange = NO;
    if (!(_previousAxis == kMFAxisNone) && axis != _previousAxis) {
        scrollDirectionDidChange = YES;
    } else if (![ScrollUtility sameSign:delta and:_previousDelta]) {
        scrollDirectionDidChange = YES;
    }
    _previousAxis = axis;
    _previousDelta = delta;
    
    // Reset state if scroll direction changed
    if (scrollDirectionDidChange) {
        [self resetState];
    }
    
    // Update tick and swipe counters

    double thisScrollTickTimeStamp = CACurrentMediaTime();
    double secondsSinceLastTick = (thisScrollTickTimeStamp - _previousScrollTickTimeStamp);
    if (secondsSinceLastTick > ScrollConfigInterface.consecutiveScrollTickMaxInterval) {
        updateConsecutiveScrollSwipeCounterWithSwipeOccuringNow(); // Needs to be called before resetting _consecutiveScrollTickCounter = 0, because it uses _consecutiveScrollTickCounter to determine whether the last series of consecutive scroll ticks was a scroll swipe
        _consecutiveScrollTickCounter = 0;
        secondsSinceLastTick = 0; // Not sure if thise makes sense here
    } else {
        _consecutiveScrollTickCounter += 1;
    }
    _previousScrollTickTimeStamp = thisScrollTickTimeStamp;
    
    // Update ticks per second
    
    double ticksPerSecond;
    double ticksPerSecondRaw;
    
    if (_consecutiveScrollTickCounter == 0) {
        ticksPerSecond = 0; // Why are we resetting this here?
        ticksPerSecondRaw = 0;
    } else {
        if (_consecutiveScrollTickCounter == 1) {
            [_smoother resetState];
        }
        ticksPerSecondRaw = 1/secondsSinceLastTick;
        ticksPerSecond = [_smoother smoothWithValue:ticksPerSecondRaw];
    }
    
    // Output
    
    ScrollAnalysisResult result = (ScrollAnalysisResult) {
        .consecutiveScrollTickCounter = _consecutiveScrollTickCounter,
        .consecutiveScrollSwipeCounter = _consecutiveScrollSwipeCounter,
        .scrollDirectionDidChange = scrollDirectionDidChange,
        .ticksPerSecond = ticksPerSecond,
        .ticksPerSecondUnsmoothed = ticksPerSecondRaw,
    };
    
    return result;
}

static void updateConsecutiveScrollSwipeCounterWithSwipeOccuringNow() {
    
    double thisScrollSwipeTimeStamp = CACurrentMediaTime();
    double intervall = thisScrollSwipeTimeStamp - _previousScrollTickTimeStamp; // Time between the last tick of the previous swipe and the first tick of the current swipe (now)
    if (intervall > ScrollConfigInterface.consecutiveScrollSwipeMaxInterval) {
        _consecutiveScrollSwipeCounter = 0;
    } else {
        if (_consecutiveScrollTickCounter >= ScrollConfigInterface.scrollSwipeThreshold_inTicks) {
            _consecutiveScrollSwipeCounter += 1;
        } else {
            _consecutiveScrollSwipeCounter = 0;
        }
    }
    _previousScrollSwipeTimeStamp = thisScrollSwipeTimeStamp;
}

@end
