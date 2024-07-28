//
// --------------------------------------------------------------------------
// VectorUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "VectorUtility.h"
#import "SharedUtility.h"
#import "Logging.h"

@implementation VectorUtility


Vector vectorByApplyingToEachDimension(Vector vec, OneDTransform f) {
    
    double newX = f(vec.x);
    double newY = f(vec.y);
    
    return (Vector){ .x = newX, .y = newY };
}

Vector scaledVectorWithFunction(Vector vec, OneDTransform f) {
    
    double magIn = magnitudeOfVector(vec);
    if (magIn == 0) return (Vector){0};  /// To prevent division by 0 from producing nan.
    double magOut = f(magIn);
    double scale = magOut / magIn;
    return scaledVector(vec, scale);
}

double magnitudeOfVector(Vector vec) {
    
    /// Handle simple cases separately for optimization. Probably very unnecessary
    if (vec.x == 0) {
        return fabs(vec.y);
    } else if (vec.y == 0) {
        return fabs(vec.x);
    }
    
    return sqrt(pow(vec.x, 2) + pow(vec.y, 2));
}
Vector unitVector(Vector vec) {
    double mag = magnitudeOfVector(vec);
    if (mag == 0) {
        DDLogWarn(@"Can't calculate unit vector for vector with magnitude 0. Returning zero vector.");
        return (Vector){0}; /// To prevent mag == 0 from producing NaN vector. Should we throw error here or sth?
    }
    return scaledVector(vec, 1.0/mag);
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
Vector subtractedVectors(Vector vec1, Vector vec2) {
    Vector outVec;
    outVec.x = vec1.x - vec2.x;
    outVec.y = vec1.y - vec2.y;
    return outVec;
}
double dotProduct(Vector vec1, Vector vec2) {
    return vec1.x * vec2.x + vec1.y * vec2.y;
}

bool isZeroVector(Vector vec) {
    return vec.x == 0 && vec.y == 0;
}

bool vectorHasNan(Vector vec) {
    return isnan(vec.x) || isnan(vec.y);
}

bool vectorsAreEqual(Vector vec1, Vector vec2) {
    return vec1.x == vec2.x && vec1.y == vec2.y;
}

Vector vectorFromDeltaAndDirectionVector(double delta, Vector direction) {
    
    assert(delta >= 0);
    
    Vector result = direction;
    
    result = unitVector(result);
    result = scaledVector(result, delta);
    
    return result;
}

Vector vectorFromDeltaAndDirection(double delta, MFDirection direction) {
    
    assert(delta != 0);
    assert(delta > 0);
    
    Vector outVec = { .x = 0, .y = 0 };
    
    if (direction == kMFDirectionUp
        || direction == kMFDirectionDown) {
        
//        assert((delta < 0 && direction == kMFDirectionDown)
//               || (delta > 0 && direction == kMFDirectionUp));
        
        outVec.y = delta;
        
    } else if (direction == kMFDirectionLeft
               || direction == kMFDirectionRight) {
        
//        assert((delta < 0 && direction == kMFDirectionLeft)
//               || (delta > 0 && direction == kMFDirectionRight));
        
        outVec.x = delta;
    }
    
    return outVec;
}

Vector vectorFromNSValue(NSValue *value) {
    Vector result;
    [value getValue: &result];
    return result;
}

NSValue *nsValueFromVector(Vector vector) {
    NSValue *result = [NSValue value:&vector withObjCType:@encode(Vector)];
    return result;
}

NSString *vectorDescription(Vector vector) {
    return stringf(@"(%f, %f)", vector.y, vector.x); // ! prints y before x
}

@end
