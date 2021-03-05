//
// --------------------------------------------------------------------------
// ScrollUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ScrollUtility.h"
#import "ScrollControl.h"
#import <Cocoa/Cocoa.h>
#import "IOHIDEventTypes.h"
#import "SharedUtility.h"

@implementation ScrollUtility


static NSDictionary *_MFScrollPhaseToIOHIDEventPhase;
+ (NSDictionary *)MFScrollPhaseToIOHIDEventPhase {
    return _MFScrollPhaseToIOHIDEventPhase;
}

+ (void)load {
    _MFScrollPhaseToIOHIDEventPhase = @{
        @(kMFPhaseNone):       @(kIOHIDEventPhaseUndefined),
        @(kMFPhaseStart):      @(kIOHIDEventPhaseBegan),
        @(kMFPhaseLinear):     @(kIOHIDEventPhaseChanged),
        @(kMFPhaseMomentum):   @(kIOHIDEventPhaseChanged),
        @(kMFPhaseEnd):        @(kIOHIDEventPhaseEnded),
    };
}

/// Basically creates a copy of a scroll event.
/// \discussion
/// When multithreading from within `ScrollControl -> eventTapCallback()` events would become invalid and unusable in the new thread.
/// Using CGEventCreateCopy didn't help, but this does fix the issue. Not sure why.
/// Xcode Analysis warns of potential memory leak here, even though we have `create` in the name. Maybe we should flag the return with `CF_RETURNS_RETAINED`
/// This doesn't produce identically behaving events (See https://github.com/noah-nuebling/mac-mouse-fix/issues/61)
///     So we made a more general version of this function, which copies over _all_ fields, at `Utility_HelperApp:createEventWithValuesFromEvent:` ... which couldn't produce identical results either... so we're back to trying to make CGEventCreateCopy work.
+ (CGEventRef)createPixelBasedScrollEventWithValuesFromEvent:(CGEventRef)event {
    CGEventRef newEvent = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 1, 0);
    NSArray *valueFields = @[@(kCGScrollWheelEventDeltaAxis1),
                             @(kCGScrollWheelEventDeltaAxis2),
                             @(kCGScrollWheelEventPointDeltaAxis1),
                             @(kCGScrollWheelEventPointDeltaAxis2),
                             @(kCGScrollWheelEventFixedPtDeltaAxis1),
                             @(kCGScrollWheelEventFixedPtDeltaAxis2)];
    for (NSNumber *f in valueFields) {
        int64_t ogVal = CGEventGetIntegerValueField(event, f.intValue);
        CGEventSetIntegerValueField(newEvent, f.intValue, ogVal);
    }
    return newEvent;
}

/// Creates a vertical scroll event with a line delta value of 1 and a pixel value of `lineHeight`
/// \discussion Xcode Analysis warns of potential memory leak here, even though we have `create` in the name. Maybe we should flag the return with `CF_RETURNS_RETAINED`
+ (CGEventRef)createNormalizedEventWithPixelValue:(int)lineHeight {
    // invert vertical
    CGEventRef event = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 1, 0);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, 1);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, lineHeight);
    CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, lineHeight);
    
    NSLog(@"Normalized scroll event values:");
    NSLog(@"%lld",CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1));
    NSLog(@"%lld",CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1));
    NSLog(@"%f",CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1));
    
    return event; // This is potentially a memory leak, because I'm creating a CGEvent but not releasing it??
}
/// Inverts the diection of a given scroll event if dir is -1.
/// @param event Event to be inverted
/// @param dir Either 1 or -1. 1 Will leave the event unchanged.
+ (CGEventRef)invertScrollEvent:(CGEventRef)event direction:(int)dir {
    // invert vertical
    long long line1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    long long point1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
    long long fixedPt1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, line1 * dir);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, point1 * dir);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, fixedPt1 * dir);
    // invert horizontal
    long long line2 = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
    long long point2 = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);
    long long fixedPt2 = CGEventGetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2, line2 * dir);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2, point2 * dir);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2, fixedPt2 * dir);
    return event;
}
+ (CGEventRef)makeScrollEventHorizontal:(CGEventRef)event {
    
    long long line1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    long long point1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
    long long fixedPt1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
    
    CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, 0);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, 0);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, 0);
    
    CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2, line1);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2, point1);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2, fixedPt1);
    
    return event;
}

+ (void)logScrollEvent:(CGEventRef)event {
    
    long long line1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    long long point1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
    long long fixedPt1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
    
    long long line2 = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
    long long point2 = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);
    long long fixedPt2 = CGEventGetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2);

    
    NSLog(@"Axis 1:");
    NSLog(@"  Line: %lld", line1);
    NSLog(@"  Point: %lld", point1);
    NSLog(@"  FixedPt: %lld", fixedPt1);
    
    NSLog(@"Axis 2:");
    NSLog(@"  Line: %lld", line2);
    NSLog(@"  Point: %lld", point2);
    NSLog(@"  FixedPt: %lld", fixedPt2);
    
}

+ (BOOL)point:(CGPoint)p1 isAboutTheSameAs:(CGPoint)p2 threshold:(int)th {
    if (abs((int)(p2.x - p1.x)) > th || abs((int)(p2.y - p1.y)) > th) {
        return NO;
    }
    return YES;
}

/// \note 0 is considered both positive and negative
+ (BOOL)sameSign:(double)n and:(double)m {
    if (n == 0 || m == 0) {
        return true;
    }
    if ([SharedUtility signOf:n] == [SharedUtility signOf:m]) {
        return true;
    }
    return false;
}

static BOOL _mouseDidMove = NO;
+ (BOOL)mouseDidMove {
    return _mouseDidMove;
}
static CGPoint _previousMouseLocation;
/// Checks if cursor did move since the last time this function was called. Writes result into `_mouseDidMove`.
+ (void)updateMouseDidMove {
    CGEventRef event = CGEventCreate(nil);
    CGPoint mouseLocation = CGEventGetLocation(event);
    CFRelease(event);
    _mouseDidMove = ![ScrollUtility point:mouseLocation
                          isAboutTheSameAs:_previousMouseLocation
                                 threshold:10];
    _previousMouseLocation = mouseLocation;
}

static BOOL _frontMostAppDidChange;
+ (BOOL)frontMostAppDidChange {
    return _frontMostAppDidChange;
}
static NSRunningApplication *_previousFrontMostApp;
/// Checks if frontmost application changed since the last time this function was called. Writes result into `_frontMostAppDidChange`.
+ (void)updateFrontMostAppDidChange {
    NSRunningApplication *frontMostApp = NSWorkspace.sharedWorkspace.frontmostApplication;
    _frontMostAppDidChange = ![frontMostApp isEqual:_previousFrontMostApp];
    _previousFrontMostApp = frontMostApp;
}

static BOOL _scrollDirectionDidChange;
+ (BOOL)scrollDirectionDidChange {
    return _scrollDirectionDidChange;
}
static long long _previousScrollValue;
/// Checks whether the sign of input number is different from when this function was last called. Writes result into `_frontMostAppDidChange`.
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
    if (intervall > ScrollControl.consecutiveScrollTickMaxIntervall) {
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
    double intervall = thisScrollSwipeTimeStamp - _previousScrollTickTimeStamp; // Time between the last tick of the previous swipe and the first tick of the current swipe (now) // TODO: subtracting `_previousScrollTickTimeStamp` instead of `_previousScrollSwipeTimeStamp` to help trigger fast scrolling exactly when intended. But not sure if this helps or makes it worse though.
    if (intervall > ScrollControl.consecutiveScrollSwipeMaxIntervall) {
        _consecutiveScrollSwipeCounter = 0;
    } else {
        if (_consecutiveScrollTickCounter >= ScrollControl.scrollSwipeThreshold_inTicks) {
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
