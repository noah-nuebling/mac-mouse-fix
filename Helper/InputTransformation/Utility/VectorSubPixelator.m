//
// --------------------------------------------------------------------------
// VectorSubPixelator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "VectorSubPixelator.h"
#import "SubPixelator.h"

@implementation VectorSubPixelator {
    SubPixelator *_spX;
    SubPixelator *_spY;
}

+ (VectorSubPixelator *)ceilPixelator {
    return [[self alloc] initCeil];
}
+ (VectorSubPixelator *)roundPixelator {
    return [[self alloc] initRound];
}

- (instancetype)initCeil
{
    self = [super init];
    if (self) {
        _spX = [SubPixelator ceilPixelator];
        _spY = [SubPixelator ceilPixelator];
    }
    return self;
}

- (instancetype)initRound;
{
    self = [super init];
    if (self) {
        _spX = [SubPixelator roundPixelator];
        _spY = [SubPixelator roundPixelator];
    }
    return self;
}

- (Vector)intVectorWithDoubleVector:(Vector)inpVec {
    inpVec.x = [_spX intDeltaWithDoubleDelta:inpVec.x];
    inpVec.y = [_spY intDeltaWithDoubleDelta:inpVec.y];
    return inpVec;
}

- (void)reset {
    [_spX reset];
    [_spY reset];
}

@end
