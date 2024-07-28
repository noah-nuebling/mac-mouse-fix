//
// --------------------------------------------------------------------------
// ScrollUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ScrollUtility.h"
#import "Scroll.h"
#import <Cocoa/Cocoa.h>
#import "IOHIDEventTypes.h"
#import "SharedUtility.h"
#import "ModificationUtility.h"
#import "Logging.h"

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

+ (CGEventRef)createPixelBasedScrollEventWithValuesFromEvent:(CGEventRef)event {
    
    /// Basically creates a copy of a scroll event.
    /// \discussion
    /// When multithreading from within `ScrollControl -> eventTapCallback()` events would become invalid and unusable in the new thread.
    /// Using CGEventCreateCopy didn't help, but this does fix the issue. Not sure why.
    /// Xcode Analysis warns of potential memory leak here, even though we have `create` in the name. Maybe we should flag the return with `CF_RETURNS_RETAINED`
    /// This doesn't produce identically behaving events (See https://github.com/noah-nuebling/mac-mouse-fix/issues/61)
    ///     So we made a more general version of this function, which copies over _all_ fields, at `Utility_HelperApp:createEventWithValuesFromEvent:` ... which couldn't produce identical results either... so we're back to trying to make CGEventCreateCopy work.
    
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

+ (CGEventRef)createNormalizedEventWithPixelValue:(int)lineHeight {
    
    /// Creates a vertical scroll event with a line delta value of 1 and a pixel value of `lineHeight`
    /// \discussion Xcode Analysis warns of potential memory leak here, even though we have `create` in the name. Maybe we should flag the return with `CF_RETURNS_RETAINED`
    
    /// invert vertical
    CGEventRef event = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 1, 0);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, 1);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, lineHeight);
    CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, lineHeight);
    
    DDLogInfo(@"Normalized scroll event values:");
    DDLogInfo(@"%lld",CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1));
    DDLogInfo(@"%lld",CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1));
    DDLogInfo(@"%f",CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1));
    
    return event;
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

    
    DDLogInfo(@"Axis 1:");
    DDLogInfo(@"  Line: %lld", line1);
    DDLogInfo(@"  Point: %lld", point1);
    DDLogInfo(@"  FixedPt: %lld", fixedPt1);
    
    DDLogInfo(@"Axis 2:");
    DDLogInfo(@"  Line: %lld", line2);
    DDLogInfo(@"  Point: %lld", point2);
    DDLogInfo(@"  FixedPt: %lld", fixedPt2);
    
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

+ (MFAxis)axisForVerticalDelta:(int64_t)deltaV horizontalDelta:(int64_t)deltaH {
    
    NSCAssert(deltaV == 0 || deltaH == 0, @"Scroll event is not parallel to an axis.");
    
    MFAxis axis = kMFAxisVertical;
    if (deltaH != 0) {
        axis = kMFAxisHorizontal;
    }
    
    return axis;
}

+ (MFDirection)directionForInputAxis:(MFAxis)axis
                           inputDelta:(int64_t)inputDelta
                        invertSetting:(MFScrollInversion)invertSetting
                   horizontalModifier:(BOOL)horizontalModifier {
    
    /// Axis direction
    
    MFScrollInversion inputAxisDirection = [SharedUtility signOf:inputDelta];
    MFScrollInversion effectiveAxisDirection = inputAxisDirection * invertSetting;
    
    /// Direction
    
    if (axis == kMFAxisHorizontal || horizontalModifier) {
        /// H
        if (effectiveAxisDirection == -1) {
            return kMFDirectionLeft;
        } else {
            return kMFDirectionRight;
        }
    } else {
        /// V
        if (effectiveAxisDirection == -1) {
            return kMFDirectionDown;
        } else {
            return kMFDirectionUp;
        }
    }
}


static BOOL _mouseDidMove = NO;
+ (BOOL)mouseDidMove {
    return _mouseDidMove;
}
static CGPoint _previousMouseLocation;
/// Checks if cursor did move since the last time this function was called. Writes result into `_mouseDidMove`.
///     Storing result in _mouseDidMove instead of returning so that different parts of the program can reuse this info
/// Passing in event for optimization. Not sure if significatnt.
+ (void)updateMouseDidMoveWithEvent:(CGEventRef)event {
    CGPoint mouseLocation = CGEventGetLocation(event);
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

@end
