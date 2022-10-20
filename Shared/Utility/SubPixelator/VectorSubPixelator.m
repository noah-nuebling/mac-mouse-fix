//
// --------------------------------------------------------------------------
// VectorSubPixelator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "VectorSubPixelator.h"
#import "SubPixelator.h"

@implementation VectorSubPixelator {
    SubPixelator *_spX;
    SubPixelator *_spY;
}

+ (VectorSubPixelator *)ceilPixelator {
    return [[self alloc] initWithRoundingFunction:ceil threshold:INFINITY];
}
+ (VectorSubPixelator *)roundPixelator {
    return [[self alloc] initWithRoundingFunction:round threshold:INFINITY];
}
+ (VectorSubPixelator *)biasedPixelator {
    return [[self alloc] initAsBiasedPixelator];
}
+ (VectorSubPixelator *)floorPixelator {
    return [[self alloc] initWithRoundingFunction:floor threshold:INFINITY];
}

- (instancetype)initWithRoundingFunction:(double (*)(double))roundingFunction threshold:(double)threshold {
    
    self = [super init];
    if (self) {
        _spX = [[SubPixelator alloc] initWithRoundingFunction:roundingFunction threshold:threshold];
        _spY = [[SubPixelator alloc] initWithRoundingFunction:roundingFunction threshold:threshold];
    }
    return self;
}
- (instancetype)initAsBiasedPixelator {
    
    self = [super init];
    if (self) {
        _spX = [SubPixelator biasedPixelator];
        _spY = [SubPixelator biasedPixelator];
    }
    return self;
}

- (void)setPixelationThreshold:(double)threshold {
    [_spX setPixelationThreshold:threshold];
    [_spY setPixelationThreshold:threshold];
}

- (Vector)intVectorWithDoubleVector:(Vector)inpVec {
    
    inpVec.x = [_spX intDeltaWithDoubleDelta:inpVec.x];
    inpVec.y = [_spY intDeltaWithDoubleDelta:inpVec.y];
    return inpVec;
}

- (Vector)peekIntVectorWithDoubleVector:(Vector)inpVec {
    
    inpVec.x = [_spX peekIntDeltaWithDoubleDelta:inpVec.x];
    inpVec.y = [_spY peekIntDeltaWithDoubleDelta:inpVec.y];
    return inpVec;
}

- (void)reset {
    [_spX reset];
    [_spY reset];
}

@end
