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
#import "Logging.h"

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

int64_t floorDivision(int64_t n, int64_t d) {
    return (n / d) - (n < 0 && n % d);
}

int64_t roundToGrid_Int(int64_t x, int64_t grid0, int64_t grid1, char *upOrDown) {

    /// Only used in `CGDisplay_NearestVBLTime` [Oct 2026]
    /// Use over the double-based `roundToGrid` for large number precision e.g. for `mach_absolute_time()` values. (Not totally sure it matters) [Oct 2026]
    /// Called something like `snapToGrid` in some older Python script or sth I wrote [Oct 2026]

    bool onGrid = (x - grid0) % (grid1 - grid0) == 0;
    if (onGrid) return x;

    int64_t unit = floorDivision(x - grid0, grid1 - grid0);

    if      (!strcmp(upOrDown, "up"))   unit += 1;
    else if (!strcmp(upOrDown, "down")) unit += 0;
    else                                mfrequire(false, "Invalid argument");

    return unit * (grid1 - grid0) + grid0;
}

double roundToGrid(double x, double grid0, double grid1, char *upOrDown) {

    /// Companion to `roundToGrid_Int` [Oct 2026]

    double unit = (x - grid0) / (grid1 - grid0);

    if      (!strcmp(upOrDown, "up"))   unit = ceil(unit);
    else if (!strcmp(upOrDown, "down")) unit = floor(unit);
    else                                mfrequire(false, "Invalid argument");

    return unit * (grid1 - grid0) + grid0;
}

@end
