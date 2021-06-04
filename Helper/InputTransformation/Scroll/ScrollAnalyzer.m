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

#pragma mark Init and constants

DoubleExponentialSmoother *_smoother;

+ (void)initialize
{
    if (self == [ScrollAnalyzer class]) {
        _smoother = [[DoubleExponentialSmoother alloc] initWithA:ScrollConfigInterface.ticksPerSecondSmoothingInputValueWeight y:ScrollConfigInterface.ticksPerSecondSmoothingTrendWeight];
    }
}

#pragma mark - Input

static double _previousScrollTickTimeStamp = 0;
static double _previousScrollSwipeTimeStamp = 0;
static int64_t _previousDelta = 0;
static MFAxis _previousAxis = kMFAxisNone;

// Reset ticks and swipes

+ (void)resetState {
    
    _previousScrollTickTimeStamp = 0;
    _previousScrollSwipeTimeStamp = 0;
    
    _previousDelta = 0;
    _previousAxis = kMFAxisNone;
    // ^ These need to be 0 and kMFAxisNone, so that _out_scrollDirectionDidChange will definitely evaluate to no on the next tick
    
    
    // The following are probably not necessary to reset, because the above resets will indirectly cause them to be reset on the next tick
    _out_consecutiveScrollTickCounter = 0;
    _out_consecutiveScrollSwipeCounter = 0;
    _out_ticksPerSecond = 0;
    
//    [_smoother resetState]; // Don't do this here
    
    // We shouldn't definitely not reset _out_scrollDirectionDidChange here, because a scroll direction change causes this function to be called, and then the information about the scroll direction changing would be lost as it's reset immediately
}

/// This is the main input function which should be called on each scrollwheel tick event
+ (void)updateWithTickOccuringNowWithDelta:(int64_t)delta axis:(MFAxis)axis  {
    
    // Update directionDidChange
    // Checks whether the sign of input number is different from when this function was last called. Writes result into `_scrollDirectionDidChange`.
    
    _out_scrollDirectionDidChange = NO;
    if (!(_previousAxis == kMFAxisNone) && axis != _previousAxis) {
        _out_scrollDirectionDidChange = YES;
    } else if (![ScrollUtility sameSign:delta and:_previousDelta]) {
        _out_scrollDirectionDidChange = YES;
    }
    _previousAxis = axis;
    _previousDelta = delta;
    
    // Reset state if scroll direction changed
    if (_out_scrollDirectionDidChange) {
        [self resetState];
    }
    
    // Update tick and swipe counters

    double thisScrollTickTimeStamp = CACurrentMediaTime();
    double secondsSinceLastTick = (thisScrollTickTimeStamp - _previousScrollTickTimeStamp);
    if (secondsSinceLastTick > ScrollConfigInterface.consecutiveScrollTickMaxInterval) {
        updateConsecutiveScrollSwipeCounterWithSwipeOccuringNow(); // Needs to be called before resetting _consecutiveScrollTickCounter = 0, because it uses _consecutiveScrollTickCounter to determine whether the last series of consecutive scroll ticks was a scroll swipe
        _out_consecutiveScrollTickCounter = 0;
        secondsSinceLastTick = 0; // Not sure if thise makes sense here
    } else {
        _out_consecutiveScrollTickCounter += 1;
    }
    _previousScrollTickTimeStamp = thisScrollTickTimeStamp;
    
    // Update ticks per second
    
    if (_out_consecutiveScrollTickCounter == 0) {
        _out_ticksPerSecond = 0; // Why are we resetting this here?
        _out_ticksPerSecondRaw = 0;
    } else {
        if (_out_consecutiveScrollTickCounter == 1) {
            [_smoother resetState];
        }
        _out_ticksPerSecondRaw = 1/secondsSinceLastTick;
        _out_ticksPerSecond = [_smoother smoothWithValue:_out_ticksPerSecondRaw];
    }
}

static void updateConsecutiveScrollSwipeCounterWithSwipeOccuringNow() {
    
    double thisScrollSwipeTimeStamp = CACurrentMediaTime();
    double intervall = thisScrollSwipeTimeStamp - _previousScrollTickTimeStamp; // Time between the last tick of the previous swipe and the first tick of the current swipe (now)
    if (intervall > ScrollConfigInterface.consecutiveScrollSwipeMaxInterval) {
        _out_consecutiveScrollSwipeCounter = 0;
    } else {
        if (_out_consecutiveScrollTickCounter >= ScrollConfigInterface.scrollSwipeThreshold_inTicks) {
            _out_consecutiveScrollSwipeCounter += 1;
        } else {
            _out_consecutiveScrollSwipeCounter = 0;
        }
    }
    _previousScrollSwipeTimeStamp = thisScrollSwipeTimeStamp;
}

#pragma mark - Output


// Consecutive ticks

static int _out_consecutiveScrollTickCounter;

+ (int)consecutiveScrollTickCounter {
    return _out_consecutiveScrollTickCounter;
}

// Consective swipes

static int _out_consecutiveScrollSwipeCounter;

+ (int)consecutiveScrollSwipeCounter {
    return _out_consecutiveScrollSwipeCounter;
}

// Direction did change

static BOOL _out_scrollDirectionDidChange;

+ (BOOL)scrollDirectionDidChange {
    return _out_scrollDirectionDidChange;
}

// Scrolling speed in scrollwheel ticks per second

static double _out_ticksPerSecond;

/// Current scrolling speed in mouse wheel ticks per second
+ (double)ticksPerSecond {
    return _out_ticksPerSecond;
}

static double _out_ticksPerSecondRaw;

+ (double)ticksPerSecondRaw {
    return _out_ticksPerSecondRaw;
}

@end
