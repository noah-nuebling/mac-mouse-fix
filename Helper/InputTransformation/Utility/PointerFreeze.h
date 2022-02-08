//
// --------------------------------------------------------------------------
// PointerFreeze.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PointerFreeze : NSObject

+ (void)load_Manual;

+ (void)freezeEventDispatchPointAtPosition:(CGPoint)origin;
+ (void)unfreezeEventDispatchPoint;

@end

NS_ASSUME_NONNULL_END
