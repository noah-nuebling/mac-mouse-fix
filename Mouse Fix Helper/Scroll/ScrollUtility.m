//
// --------------------------------------------------------------------------
// ScrollUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ScrollUtility.h"

@implementation ScrollUtility


/// Creates a vertical scroll event with a line delta value of 1 and a pixel value of `lineHeight`
+ (CGEventRef)normalizedEventWithPixelValue:(int)lineHeight {
    // invert vertical
    CGEventRef event = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 1, 0);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, 1);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, lineHeight);
    CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, lineHeight);
    
    NSLog(@"Normalized scroll event values:");
    NSLog(@"%lld",CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1));
    NSLog(@"%lld",CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1));
    NSLog(@"%f",CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1));
    
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
+ (double)signOf:(double)n {
    if (n == 0) {return 0;}
    return n >= 0 ? 1 : -1;
}
+ (BOOL)sameSign_n:(double)n m:(double)m {
    if (n == 0 || m == 0) {
        return true;
    }
    if ([self signOf:n] == [self signOf:m]) {
        return true;
    }
    return false;
}
@end
