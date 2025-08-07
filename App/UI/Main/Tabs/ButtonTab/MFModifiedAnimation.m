//
// --------------------------------------------------------------------------
// MFModifiedAnimation.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// [Aug 2025]
///     Made this to apply a 'modifier' to CASpringAnimation that prevents it from overshooting. Cause the overshooting caused visual glitches on the shadow-animation inside AddField.swift

/// Using an NSProxy to customize functions on CASpringAnimation doesn't work
///     because the CASpringAnimation seems to be copied into a C++ struct/class (`CA::Render::SpringAnimation::SpringAnimation()`) before actually being queried. (And idk how to modify the C++ stuff's behavior)
///     The copying happens in `-[CASpringAnimation _copyRenderAnimationForLayer:]` and `-[CASpringAnimation _setCARenderAnimation:layer:]`
///     ChatGPT says the C++ struct is sent to WindowServer and it's impossible to customize stuff there without breaking SIP (but not sure it's hallucinating)
///
/// Another option would be to create a CAKeyFrameAnimation which contains modified samples from the original curve. I think you might be able to sample the original curve using `-[_timeFunction:]`. 
///
///

#import "MFModifiedAnimation.h"
#import <objc/message.h>
#import "SharedUtility.h"

@implementation MFModifiedAnimation {
    CABasicAnimation *_base;
    double (^_modifier)(double);
}

NSArray <NSNumber *> *mf_sampleCurve(CABasicAnimation *base, int samplesPerSecond) {

    double duration = [base duration];
    int nSamples = duration * samplesPerSecond;
    
    NSMutableArray *samples = [NSMutableArray array];
    for (int i = 0; i < nSamples; i++) {
        double time = i * (duration / nSamples);
        double progress = ((double (*) (id, SEL, double))objc_msgSend)(base, @selector(_timeFunction:), time);
        [samples addObject: @(progress)];
    }
    
    return samples;
    DDLogDebug(@"baseCurve samples: %@", samples);
}

/// Init
+ (instancetype)newWithBase: (CABasicAnimation *)base modifier: (double (^)(double))modifier {
    
    MFModifiedAnimation *new = [[self alloc] init];
    new->_base = base;
    new->_modifier = modifier;
    
    /// Sample base curve
    {
        double duration = [base duration];
        int fps = 60;
        int samplesPerFrame = 1;
        int nSamples = duration * fps * samplesPerFrame;
        
        NSMutableArray *samples = [NSMutableArray array];
        for (int i = 0; i < nSamples; i++) {
            double time = i * (duration / nSamples);
            double progress = ((double (*) (id, SEL, double))objc_msgSend)(base, @selector(_timeFunction:), time);
            progress = modifier(progress);
            
            [samples addObject: @(progress)];
        }
        
        DDLogDebug(@"baseCurve samples: %@", samples);
        
        #define xxx(propname) new.propname = base.propname
        
        /// CAMediaTiming
        xxx(beginTime);
        xxx(duration);
        xxx(speed);
        xxx(timeOffset);
        xxx(repeatCount);
        xxx(repeatDuration);
        xxx(autoreverses);
        xxx(fillMode);
        
        /// CAAnimation
        xxx(timingFunction);
        xxx(delegate);
        xxx(removedOnCompletion);
        if (@available(macOS 12.0, *)) xxx(preferredFrameRateRange);
        
        /// CAPropertyAnimation
        xxx(keyPath);
        xxx(additive);
        xxx(cumulative);
        xxx(valueFunction);
        
        /// CAKeyFrameAnimation
        new.values              = samples;
        new.path                = nil;
        new.keyTimes            = nil;
        new.timingFunctions     = nil;
        new.calculationMode     = kCAAnimationLinear;
        new.tensionValues       = nil;
        new.continuityValues    = nil;
        new.biasValues          = nil;
        new.rotationMode        = nil;
    }
    
    
    return new;
}

/// Cast
#if 0
- (CABasicAnimation *)cast {
    return (CABasicAnimation *)self;
}
#endif
- (CAKeyframeAnimation *)cast {
    return (CAKeyframeAnimation *)self;
}


- (instancetype) copy {
    return [MFModifiedAnimation newWithBase: [self->_base copy] modifier: [self->_modifier copy]]; /// Not sure it's necessary to copy the members.
}

/// Forward everything else to `_base`
///     [Aug 2025] Performance:
///         Apple docs say forwarding is slow.
///         Subclassing CABasicAnimation would be more performant, but less flexible (we wanna apply the modifiers on CABasicAnimation subclasses like CASpringAnimation)
///         Docs say `forwardingTargetForSelector:` is faster than standard forwarding – Maybe use that.

+ (BOOL) respondsToSelector: (SEL)aSelector {
    if ((0)) return NO;
    return [super respondsToSelector: aSelector];
}

#if 1
- (NSMethodSignature *) methodSignatureForSelector: (SEL)aSelector {
    NSLog(@"MFModifiedAnimation received methodSignature request for: %@", NSStringFromSelector(aSelector));
    return [self->_base methodSignatureForSelector: aSelector];
}
- (void) forwardInvocation: (NSInvocation *)anInvocation {
    NSLog(@"MFModifiedAnimation received invocation: %@", anInvocation);
    if ((1))
    [anInvocation invokeWithTarget: self->_base];
}
#endif

#if 0
- (id)forwardingTargetForSelector:(SEL)aSelector {
    NSLog(@"MFModifiedAnimation received message with selector: %@", NSStringFromSelector(aSelector));
    return self->_base;
}
#endif

@end
