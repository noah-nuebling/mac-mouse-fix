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
@synthesize accumulatedRoundingError;

- (int64_t)intWithDouble:(double)inp {
    double preciseOutVal = inp + self.accumulatedRoundingError;
    int64_t roundedOutVal = (int64_t) floor(preciseOutVal);
    self.accumulatedRoundingError = preciseOutVal - roundedOutVal;
    
    return roundedOutVal;
}

@end
