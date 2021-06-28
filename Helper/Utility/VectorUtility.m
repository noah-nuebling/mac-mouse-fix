//
// --------------------------------------------------------------------------
// VectorUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "VectorUtility.h"

@implementation VectorUtility


Vector scaledVectorWithFunction(Vector vec, VectorScalingFunction f) {
    double magIn = magnitudeOfVector(vec);
    if (magIn == 0) return (Vector){0};  // To prevent division by 0 from producing nan
    double magOut = f(magIn);
    double scale = magOut / magIn;
    return scaledVector(vec, scale);
}

double magnitudeOfVector(Vector vec) {
    
    // Handle simple cases separately for optimization. Probably very unnecessary
    if (vec.x == 0) {
        return fabs(vec.y);
    } else if (vec.y == 0) {
        return fabs(vec.x);
    }
    
    return sqrt(pow(vec.x, 2) + pow(vec.y, 2));
}
Vector unitVector(Vector vec) {
    return scaledVector(vec, 1.0/magnitudeOfVector(vec));
}
Vector scaledVector(Vector vec, double scalar) {
    Vector outVec;
    outVec.x = vec.x * scalar;
    outVec.y = vec.y * scalar;
    return outVec;
}
Vector addedVectors(Vector vec1, Vector vec2) {
    Vector outVec;
    outVec.x = vec1.x + vec2.x;
    outVec.y = vec1.y + vec2.y;
    return outVec;
}
double dotProduct(Vector vec1, Vector vec2) {
    return vec1.x * vec2.x + vec1.y * vec2.y;
}

bool isZeroVector(Vector vec) {
    return vec.x == 0 && vec.y == 0;
}

@end
