//
// --------------------------------------------------------------------------
// VectorUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "TransformationUtility.h"

NS_ASSUME_NONNULL_BEGIN

@interface VectorUtility : NSObject

typedef double (^OneDTransform)(double);

typedef struct __Vector {
    double x;
    double y;
} Vector;

Vector vectorByApplyingToEachDimension(Vector vec, OneDTransform f);
Vector scaledVectorWithFunction(Vector vec, OneDTransform f);
double magnitudeOfVector(Vector vec);
Vector unitVector(Vector vec);
Vector scaledVector(Vector vec, double scalar);
Vector addedVectors(Vector vec1, Vector vec2);
Vector subtractedVectors(Vector vec1, Vector vec2);
double dotProduct(Vector vec1, Vector vec2);
bool isZeroVector(Vector vec);
bool vectorsAreEqual(Vector vec1, Vector vec2);

Vector vectorFromNSValue(NSValue *value);
NSValue *nsValueFromVector(Vector vector);
NSString *vectorDescription(Vector vector);

Vector vectorFromDeltaAndDirection(double delta, MFDirection direction);

@end

NS_ASSUME_NONNULL_END
