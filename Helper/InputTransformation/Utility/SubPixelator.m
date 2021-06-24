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
@property double (*roundingFunction)(double);
@end

@implementation SubPixelator

+ (SubPixelator *)ceilPixelator {
    return [[self alloc] initWithRoundingFunction:ceil];
}
+ (SubPixelator *)roundPixelator {
    return [[self alloc] initWithRoundingFunction:round];
}

/// Init

- (instancetype)init {
    assert(false);
}
- (instancetype)initWithRoundingFunction:(double (*)(double))roundingFunction
{
    self = [super init];
    if (self) {
        self.roundingFunction = roundingFunction;
    }
    return self;
}

/// Main

- (int64_t)intDeltaWithDoubleDelta:(double)inpDelta {
    double preciseDelta = inpDelta + self.accumulatedRoundingError;
    int64_t roundedDelta = [self peekIntDeltaWithDoubleDelta:inpDelta];
    self.accumulatedRoundingError = preciseDelta - roundedDelta;
    
    return roundedDelta;
}

- (int64_t)peekIntDeltaWithDoubleDelta:(double)inpDelta {
    /// See what int delta a certain double input would yield without changing the state of the subpixelator
    
    double preciseDelta = inpDelta + self.accumulatedRoundingError;
    int64_t roundedDelta = (int64_t)self.roundingFunction(preciseDelta);
    
    return roundedDelta;
    
}

- (void)reset {
    self.accumulatedRoundingError = 0;
}

@end
