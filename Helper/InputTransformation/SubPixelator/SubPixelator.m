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
//@property double accumulatedRoundingError; /// Declaring this in header for outside access to help debugging
@property RoundingFunction roundingFunction;
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

static RoundingFunction getBiasedRoundingFunction(double inpDelta) {
    if (sign(inpDelta) == 1) {
        return ceil;
    } else if (sign(inpDelta) == -1) {
        return floor;
    } else {
        /* sign == 0 */
        return NULL;
    }
}

/// Main

- (int64_t)intDeltaWithDoubleDelta:(double)inpDelta {
    
    /// Nothing to round if input is 0
    if (inpDelta == 0) {
        return 0;
    }
    
    /// If this is biased pixelator, initialize rounding function if it isn't already
    if (self.isBiasedPixelator && self.roundingFunction == NULL) {
        self.roundingFunction = getBiasedRoundingFunction(inpDelta);
        
    }
    
    /// Get roundedDelta
    double preciseDelta = inpDelta + self.accumulatedRoundingError;
    int64_t roundedDelta = (int64_t)self.roundingFunction(preciseDelta);
    
    ///  Debug
    
    DDLogDebug(@"\nSubpixelator eval with d: %f, oldErr: %f, roundedD: %lld, newErr: %f", inpDelta, self.accumulatedRoundingError, roundedDelta, preciseDelta - roundedDelta);
    
    /// Update roundingError
    self.accumulatedRoundingError = preciseDelta - roundedDelta;
    
    /// Return
    return roundedDelta;
}

- (int64_t)peekIntDeltaWithDoubleDelta:(double)inpDelta {
    /// See what int delta a certain double input would yield without changing the state of the subpixelator
    ///     ^ With reference to this class's main function intDeltaWithDoubleDelta:
    
    /// Nothing to round if input is 0
    if (inpDelta == 0) {
        return 0;
    }
    
    /// Get rounding functtion
    RoundingFunction rf;
    
    if (self.roundingFunction == NULL) {
        /// Get 'hypothetical' rounding function if none has been assigned
        rf = getBiasedRoundingFunction(inpDelta);
        /// Validate
        assert(self.accumulatedRoundingError == 0);
    } else {
        /// Get actual rounding function
        rf = self.roundingFunction;
    }
    
    /// Get roundedDelta
    double preciseDelta = inpDelta + self.accumulatedRoundingError;
    int64_t roundedDelta = (int64_t)rf(preciseDelta);
    
    ///  Debug
    DDLogDebug(@"\nSubpixelator PEEK with d: %f, oldErr: %f, roundedD: %lld", inpDelta, self.accumulatedRoundingError, roundedDelta);
    
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
