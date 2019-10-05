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
    long long line = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    long long point = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
    long long fixedPt = CGEventGetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, line * dir);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, point * dir);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, fixedPt * dir);
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
