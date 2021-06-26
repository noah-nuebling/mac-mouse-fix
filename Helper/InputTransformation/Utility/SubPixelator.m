//
// --------------------------------------------------------------------------
// SubPixelator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SubPixelator.h"
#import "SharedUtility.h"

@interface SubPixelator ()
@property double accumulatedRoundingError;
@property double (*roundingFunction)(double);
@property BOOL isBiasedPixelator;
@end

@implementation SubPixelator

+ (SubPixelator *)ceilPixelator {
    return [[self alloc] initWithRoundingFunction:ceil];
}
+ (SubPixelator *)roundPixelator {
    return [[self alloc] initWithRoundingFunction:round];
}
+ (SubPixelator *)biasedPixelator {
    /// A biased pixelator becomes a floor or a ceil pixelator depending on whether it's first non-zero input is negative (floor) or positive (ceil)
    ///     That means it's first
    
    return [[self alloc] initAsBiasedPixelator];
}
+ (SubPixelator *)floorPixelator {
    return [[self alloc] initWithRoundingFunction:floor];
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
        self.isBiasedPixelator = NO;
    }
    return self;
}
- (instancetype)initAsBiasedPixelator
{
    self = [super init];
    if (self) {
        self.isBiasedPixelator = true;
    }
    return self;
}

/// Main

- (int64_t)intDeltaWithDoubleDelta:(double)inpDelta {
    
    /// Nothing to round if input is 0
    if (inpDelta == 0) {
        return 0;
    }
    
    /// Initialize rounding function if it isn't already
    if (self.isBiasedPixelator && self.roundingFunction == NULL) {
        if (sign(inpDelta) == 1) {
            self.roundingFunction = ceil;
        } else if (sign(inpDelta) == -1) {
            self.roundingFunction = floor;
        } else { /* sign == 0 */ }
        
    }
    
    /// Get roundedDelta
    double preciseDelta = inpDelta + self.accumulatedRoundingError;
    int64_t roundedDelta = (int64_t)self.roundingFunction(preciseDelta);
    
    /// Update roundingError
    self.accumulatedRoundingError = preciseDelta - roundedDelta;
    
    /// Return
    return roundedDelta;
}

- (int64_t)peekIntDeltaWithDoubleDelta:(double)inpDelta {
    /// See what int delta a certain double input would yield without changing the state of the subpixelator
    ///     ^ With reference to this class's main function intDeltaWithDoubleDelta:
    
    /// Guard roundingFunction exists
    if (self.roundingFunction == NULL) {
        assert(false);
        /// ^ If this is a biasedPixelator, you need to call intDeltaWithDoubleDelta: first (with non-0 input) to intialize the roundingFunction, before you can call this
        ///     You can call intDeltaWithDoubleDelta: with -1 or 1 to initialize it without affecting any other state (self.accumulatedRoundingError)
    }
    
    /// Get roundedDelta
    double preciseDelta = inpDelta + self.accumulatedRoundingError;
    int64_t roundedDelta = (int64_t)self.roundingFunction(preciseDelta);
    
    /// Return
    return roundedDelta;
    
}

- (void)reset {
    self.accumulatedRoundingError = 0;
    if (self.isBiasedPixelator) {
        self.roundingFunction = NULL;
    }
}

@end
