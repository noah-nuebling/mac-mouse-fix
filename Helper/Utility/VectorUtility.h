//
// --------------------------------------------------------------------------
// VectorUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VectorUtility : NSObject

typedef double (^VectorScalerFunction)(double);

typedef struct __Vector {
    double x;
    double y;
} Vector;

Vector scaledVectorWithFunction(Vector vec, VectorScalerFunction f);
double magnitudeOfVector(Vector vec);
Vector normalizedVector(Vector vec);
Vector scaledVector(Vector vec, double scalar);
Vector addedVectors(Vector vec1, Vector vec2);
double dotProduct(Vector vec1, Vector vec2);
bool isZeroVector(Vector vec);

@end

NS_ASSUME_NONNULL_END
