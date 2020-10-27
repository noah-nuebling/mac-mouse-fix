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

@implementation VectorSubPixelator

+ (VectorSubPixelator *) pixelator {
    return [[self alloc] init];
}

static SubPixelator *_spX;
static SubPixelator *_spY;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _spX = [SubPixelator pixelator];
        _spY = [SubPixelator pixelator];
    }
    return self;
}

- (MFVector)intVectorWithDoubleVector:(MFVector)inpVec {
    inpVec.x = [_spX intDeltaWithDoubleDelta:inpVec.x];
    inpVec.y = [_spX intDeltaWithDoubleDelta:inpVec.y];
    return inpVec;
}

@end
