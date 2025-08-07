//
// --------------------------------------------------------------------------
// MFModifiedAnimation.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <QuartzCore/CAAnimation.h>

@interface MFModifiedAnimation : CAKeyframeAnimation

NSArray <NSNumber *> *mf_sampleCurve(CABasicAnimation *base, int samplesPerSecond);

+ (instancetype _Nonnull)newWithBase: (CABasicAnimation *_Nonnull)base modifier: (double (^_Nonnull)(double))modifier;
- (CABasicAnimation *_Nonnull)cast; /// This is useful for Swift since it makes it annoying to cast natively.

@end
