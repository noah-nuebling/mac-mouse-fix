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

double _mfcycle(double n, double lower, double upper, char closedSide) {
    
    /// mfcycle
    ///     - Generalization of modulo.
    ///     - Moves n into the half-open interval `[lower, upper)` (if `closedSide == '['`) or `(lower, upper]` (if `closedSide == ']'`)
    ///     - If lower > upper, the result will be mirrored (see code)  – feels like a natural extension of this operation?
    ///     - `mfcycle(n, (0, z), '[')` is equivalent to `n % z`
    ///         ... Actually not quite true bc `%` is weird for negative inputs in C. Something about euclidian modulo iirc.
    /// Also see:
    ///     [May 22 2025] mfround, mffloor, mfceil function in our IDAPython scripts – They use a similar idea of 'extending' round/floor/ceil
    ///     Math.swift > cycle()
    
    assert(closedSide == '[' || closedSide == ']');
    
    if (lower == upper) return lower;
    if (lower > upper) { double temp = lower; lower = upper; upper = temp; closedSide = (closedSide == '[') ? ']' : '['; n = lower+upper-n; } /// Respond to inverted bounds by mirroring everything along the center of the interval.
    double stride = upper - lower;
    while (closedSide == '[' ? (n < lower) : (n <= lower)) n += stride;
    while (closedSide == ']' ? (n > upper) : (n >= upper)) n -= stride;
    
    return n;
}

@end
