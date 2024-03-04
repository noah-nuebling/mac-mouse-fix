//
// --------------------------------------------------------------------------
// MathObjc.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "MathObjc.h"

@implementation MathObjc

bool directionsAreOpposite(MFIntervalDirection dir1, MFIntervalDirection dir2) {
    
    if (dir1 == kMFIntervalDirectionNone || dir2 == kMFIntervalDirectionNone) {
        return false;
    }
    
    return dir1 != dir2;
}

bool equal(double a, double b, double tolerance) {

    /// If you want to be fancy you can make the epsilon relative to floating point precision. See https://stackoverflow.com/a/17467/10601702
    
    return fabs(a - b) <= tolerance;
}

bool lesserEqual(double a, double b, double tolerance) {
    
    if (equal(a, b, tolerance)) {
        return true;
    } else {
        return a < b;
    }
}
bool greaterEqual(double a, double b, double tolerance) {
    
    if (equal(a, b, tolerance)) {
        return true;
    } else {
        return a > b;
    }
}


double signedFloor(double num) {
    
    if (num == 0.0) {
        return 0.0;
    } else if (num > 0.0) {
        return floor(num);
    } else {
        return ceil(num);
    }
}

double signedCeil(double num) {
    
    if (num == 0.0) {
        return 0.0;
    } else if (num > 0.0) {
        return ceil(num);
    } else {
        return floor(num);
    }
}

@end
