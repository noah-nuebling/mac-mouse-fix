//
// --------------------------------------------------------------------------
// ScrollUtility.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ScrollUtility.h"

@implementation ScrollUtility

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
    
    NSLog(@"FROGLAND");
    
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
