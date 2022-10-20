//
// --------------------------------------------------------------------------
// MathObjc.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MathObjc : NSObject

/// When in doubt, use Math.swift instead of this
/// This is only used to do stuff that you can't do in Swift
/// Like define a struct or enum that can be used in Swift as well as ObjC

typedef enum {
    kMFIntervalDirectionAscending,
    kMFIntervalDirectionDescending,
    kMFIntervalDirectionNone
} MFIntervalDirection;

bool equal(double a, double b, double tolerance);
bool lesserEqual(double a, double b, double tolerance);
bool greaterEqual(double a, double b, double tolerance);

double signedFloor(double num);
double signedCeil(double num);

@end

NS_ASSUME_NONNULL_END
