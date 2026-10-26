//
// --------------------------------------------------------------------------
// PointerFreeze.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PointerFreeze : NSObject

+ (void)load_Manual;

+ (void)freezeEventDispatchPointAtPosition:(CGPoint)origin;
+ (void)freezePointerAtPosition:(CGPoint)origin;
+ (void)unfreeze;

@end

NS_ASSUME_NONNULL_END
