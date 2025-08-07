//
// --------------------------------------------------------------------------
// CAAnimationCurveUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <QuartzCore/CAAnimation.h>

@interface CAAnimationCurveUtility : NSObject

NSArray <NSNumber *> *_Nonnull MFCABasicAnimation_Sample(CABasicAnimation *_Nonnull base, int samplesPerSecond);

@end
