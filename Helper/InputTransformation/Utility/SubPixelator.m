//
// --------------------------------------------------------------------------
// SubPixelator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SubPixelator.h"

@interface SubPixelator ()
@property double accumulatedRoundingError;
@end

@implementation SubPixelator

+ (SubPixelator *) pixelator {
    return [[self alloc] init];
}

@synthesize accumulatedRoundingError;

- (int64_t)intDeltaWithDoubleDelta:(double)inpDelta {
    double preciseDelta = inpDelta + self.accumulatedRoundingError;
    int64_t roundedDelta = (int64_t) round(preciseDelta);
    self.accumulatedRoundingError = preciseDelta - roundedDelta;
    
    return roundedDelta;
}

- (void)reset {
    self.accumulatedRoundingError = 0;
}

@end
