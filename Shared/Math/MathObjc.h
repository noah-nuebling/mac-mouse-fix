//
// --------------------------------------------------------------------------
// MathObjc.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
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

bool directionsAreOpposite(MFIntervalDirection dir1, MFIntervalDirection dir2);
bool equal(double a, double b, double tolerance);
bool lesserEqual(double a, double b, double tolerance);
bool greaterEqual(double a, double b, double tolerance);

double signedFloor(double num);
double signedCeil(double num);

/// CLIP aka CLAMP, BOUND
///     Other implementations: https://stackoverflow.com/a/14770282/10601702

#define CLIPLOW(x, low) (x < low ? low : x)
#define CLIPHIGH(x, high) (high < x ? high : x)
#define CLIP(x, low, high) (CLIPHIGH(CLIPLOW(x, low), high))

#define ISBETWEEN(x, low, high) (low <= x && x <= high)

//#define MIN(A,B)    ({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __a : __b; })
//#define MAX(A,B)    ({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __b : __a; })

@end

NS_ASSUME_NONNULL_END
