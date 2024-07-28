//
// --------------------------------------------------------------------------
// SubPixelator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/**
 Notes:
 - Is it really a good idea to make all the properties here atomic? I'm not sure it prevents any race conditions, and it might have a significant performance impact.
 
*/


#import "SubPixelator.h"
#import "SharedUtility.h"
#import "MathObjc.h"
#import "Logging.h"

@interface SubPixelator ()
@property (readwrite, assign, atomic) double accumulatedRoundingError;
@property (readwrite, assign, atomic, nullable) RoundingFunction roundingFunction;
@property (readwrite, assign, atomic) BOOL isBiasedPixelator;
@property (readwrite, assign, atomic) double threshold; /// Only start pixelating if `abs(val) < threshold`
@end

@implementation SubPixelator

/// Convenience init

+ (SubPixelator *)ceilPixelator {
    return [[self alloc] initWithRoundingFunction:ceil threshold:INFINITY];
}
+ (SubPixelator *)roundPixelator {
    return [[self alloc] initWithRoundingFunction:round threshold:INFINITY];
}
+ (SubPixelator *)biasedPixelator {
    /// A biased pixelator becomes a floor or a ceil pixelator depending on whether it's first non-zero input is negative (floor) or positive (ceil)
    ///     That means it's first input will always result in a non-zero output.
    ///     We're using this in TouchAnimator. I can't remember why.
    
    return [[self alloc] initAsBiasedPixelatorWithThreshold:INFINITY];
}
+ (SubPixelator *)floorPixelator {
    return [[self alloc] initWithRoundingFunction:floor threshold:INFINITY];
}

/// Init

- (instancetype)init {
    assert(false);
    exit(1);
}
- (instancetype)initWithRoundingFunction:(double (*)(double))roundingFunction threshold:(double)threshold {
    
    self = [super init];
    if (self) {
        self.roundingFunction = roundingFunction;
        self.isBiasedPixelator = NO;
        self.threshold = threshold;
    }
    return self;
}
- (instancetype)initAsBiasedPixelatorWithThreshold:(double)threshold {
    self = [super init];
    if (self) {
        self.isBiasedPixelator = true;
        self.threshold = threshold;
    }
    return self;
}

static RoundingFunction getBiasedRoundingFunction(double inpDelta) {
    if (sign(inpDelta) == 1) {
        return ceil;
    } else if (sign(inpDelta) == -1) {
        return floor;
    } else { /* sign == 0 */
        return NULL;
    }
}

/// Set threshold

- (void)setPixelationThreshold:(double)threshold {
    
    /// Notes
    /// - pixelationThreshold will make it so the pixelator will only pixelate if `abs(inputDelta) < threshold`
    /// - TODO: Consider removing the "threshold" from all the initializers and just setting it to infinity by default. Since those are never used.
    /// See GestureScrollSimulator > getDeltaVectors for explanation.
    ///     That's the only place where this is used at the time of writing

    self.threshold = threshold;
}

/// Main

- (double)intDeltaWithDoubleDelta:(double)inpDelta {
    
    /// Nothing to round if input is 0
    if (inpDelta == 0) {
        return 0;
    }
    
    /// If this is biased pixelator, initialize rounding function if it isn't already
    ///     Store the `roundingFunction` in `rf` to handle race conditions where self.roundingFunction becomes NULL while this function executes.
    RoundingFunction rf;
    if (self.isBiasedPixelator && self.roundingFunction == NULL) {
        rf = getBiasedRoundingFunction(inpDelta);
        self.roundingFunction = rf;
    } else {
        rf = self.roundingFunction;
    }
    assert(rf != NULL);
    
    /// Get preciseDelta
    double preciseDelta = inpDelta + self.accumulatedRoundingError;
    
    /// Get ouputDelta
    double outputDelta;
    if (greaterEqual(fabs(preciseDelta), self.threshold, 10e-4)) { 
        outputDelta = preciseDelta;
    } else {
        outputDelta = rf(preciseDelta);
    }
    
    ///  Debug
    DDLogDebug(@"\nSubpixelator eval with d: %f, oldErr: %f, roundedD: %f, newErr: %f", inpDelta, self.accumulatedRoundingError, outputDelta, preciseDelta - outputDelta);
    
    /// Update roundingError
    self.accumulatedRoundingError = preciseDelta - outputDelta;
    
    /// Return
    return outputDelta;
}

- (double)peekIntDeltaWithDoubleDelta:(double)inpDelta {
    /// See what int delta a certain double input would yield without changing the state of the subpixelator
    
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
    
    /// Get preciseDelta
    double preciseDelta = inpDelta + self.accumulatedRoundingError;
    
    /// Get ouputDelta
    double outputDelta;
    if (greaterEqual(fabs(preciseDelta), self.threshold, 10e-4)) {
        outputDelta = preciseDelta;
    } else {
        outputDelta = rf(preciseDelta);
    }
    
    ///  Debug
    DDLogDebug(@"\nSubpixelator PEEK with d: %f, oldErr: %f, roundedD: %f", inpDelta, self.accumulatedRoundingError, outputDelta);
    
    /// Return
    return outputDelta;
    
}

- (void)reset {
    self.accumulatedRoundingError = 0;
    if (self.isBiasedPixelator) {
        self.roundingFunction = NULL;
    }
}

@end
