//
// --------------------------------------------------------------------------
// VectorUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "TransformationUtility.h"

NS_ASSUME_NONNULL_BEGIN

@interface VectorUtility : NSObject

typedef double (^VectorScalingFunction)(double);

typedef struct __Vector {
    double x;
    double y;
} Vector;

Vector scaledVectorWithFunction(Vector vec, VectorScalingFunction f);
double magnitudeOfVector(Vector vec);
Vector unitVector(Vector vec);
Vector scaledVector(Vector vec, double scalar);
Vector addedVectors(Vector vec1, Vector vec2);
Vector subtractedVectors(Vector vec1, Vector vec2);
double dotProduct(Vector vec1, Vector vec2);
bool isZeroVector(Vector vec);

Vector vectorFromNSValue(NSValue *value);
NSValue *nsValueFromVector(Vector vector);

Vector vectorFromDeltaAndDirection(double delta, MFDirection direction);

@end

NS_ASSUME_NONNULL_END
