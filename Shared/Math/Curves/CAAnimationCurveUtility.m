//
// --------------------------------------------------------------------------
// CAAnimationCurveUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "CAAnimationCurveUtility.h"
#import <objc/message.h>
#import "SharedUtility.h"

@implementation CAAnimationCurveUtility

NSArray <NSNumber *> *_Nonnull MFCABasicAnimation_Sample(CABasicAnimation *_Nonnull base, int samplesPerSecond) {

    /// [Aug 2025] Added this on master branch. IIRC we already have similar tools in the feature-strings-catalog branch. Perhaps we should merge them.
    
    SEL sel = NSSelectorFromString(@"_timeFunction:");
    
    if (![base respondsToSelector: sel]) {
        DDLogError(@"Error: MFCABasicAnimation_Sample: Passed-in CAAnimation (%@) doesn't support _timeFunction:.", base); /// [Aug 2025] Relying on weird private stuff here. I hope this is portable.
        assert(false);
        return @[];
    }
    
    double duration = [base duration];
    int nSamples = duration * samplesPerSecond;

    NSMutableArray *samples = [NSMutableArray array];
    for (int i = 0; i < nSamples; i++) {
        double time = i * (duration / nSamples);
        double progress = ((double (*) (id, SEL, double))objc_msgSend)(base, sel, time);
        [samples addObject: @(progress)];
    }

    return samples;
}

@end
