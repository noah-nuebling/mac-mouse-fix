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
#import "ScrollUtility.h"
#import "ScrollConfig.h"

@implementation ScrollAnalyzer


static BOOL _scrollDirectionDidChange;
+ (BOOL)scrollDirectionDidChange {
    return _scrollDirectionDidChange;
}
static long long _previousScrollValue;
/// Checks whether the sign of input number is different from when this function was last called. Writes result into `_scrollDirectionDidChange`.
+ (void)updateScrollDirectionDidChange:(long long)thisScrollValue {
    _scrollDirectionDidChange = NO;
    if (![ScrollUtility sameSign:thisScrollValue and:_previousScrollValue]) {
        _scrollDirectionDidChange = YES;
    }
    _previousScrollValue = thisScrollValue;
}

/// \note Shouldn't use this (at least when resetting dynamic globals) - leads to bugs
//+ (void)resetScrollDirectionDidChangeFunction {
//    _previousScrollValue = 0;
//}

static int _consecutiveScrollTickCounter;
+ (int)consecutiveScrollTickCounter {
    return _consecutiveScrollTickCounter;
}
static double _previousScrollTickTimeStamp;

+ (void) updateConsecutiveScrollTickAndSwipeCountersWithTickOccuringNow { // Starts counting at 0
    double thisScrollTickTimeStamp = CACurrentMediaTime();
    double intervall = (thisScrollTickTimeStamp - _previousScrollTickTimeStamp);
    if (intervall > ScrollConfig.consecutiveScrollTickMaxInterval) {
        [self updateConsecutiveScrollSwipeCounterWithSwipeOccuringNow]; // Needs to be called before resetting _consecutiveScrollTickCounter = 0, because it uses _consecutiveScrollTickCounter to determine whether the last series of consecutive scroll ticks was a scroll swipe
        _consecutiveScrollTickCounter = 0;
    } else {
        _consecutiveScrollTickCounter += 1;
    }
    _previousScrollTickTimeStamp = thisScrollTickTimeStamp;
}

static int _consecutiveScrollSwipeCounter;
+ (int)consecutiveScrollSwipeCounter {
    return _consecutiveScrollSwipeCounter;
}
static double _previousScrollSwipeTimeStamp;

+ (void)updateConsecutiveScrollSwipeCounterWithSwipeOccuringNow {
    
    double thisScrollSwipeTimeStamp = CACurrentMediaTime();
    double intervall = thisScrollSwipeTimeStamp - _previousScrollTickTimeStamp; // Time between the last tick of the previous swipe and the first tick of the current swipe (now)
    if (intervall > ScrollConfig.consecutiveScrollSwipeMaxInterval) {
        _consecutiveScrollSwipeCounter = 0;
    } else {
        if (_consecutiveScrollTickCounter >= ScrollConfig.scrollSwipeThreshold_inTicks) {
            _consecutiveScrollSwipeCounter += 1;
        } else {
            _consecutiveScrollSwipeCounter = 0;
        }
    }
    _previousScrollSwipeTimeStamp = thisScrollSwipeTimeStamp;
}

+ (void)resetConsecutiveTicksAndSwipes {
    _consecutiveScrollTickCounter = 0; // Probs not necessary
    _previousScrollTickTimeStamp = 0.0;
    _consecutiveScrollSwipeCounter = 0; // Probs not necessary
    _previousScrollSwipeTimeStamp = 0.0;
}


@end
