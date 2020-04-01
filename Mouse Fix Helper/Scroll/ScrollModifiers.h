//
// --------------------------------------------------------------------------
// ModifierInputReceiver.h
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

@interface ScrollModifiers : NSObject
+ (BOOL)horizontalScrollModifierKeyEnabled;
+ (void)setHorizontalScrollModifierKeyEnabled:(BOOL)B;
+ (BOOL)magnificationScrollModifierKeyEnabled;
+ (void)setMagnificationScrollModifierKeyEnabled:(BOOL)B;
+ (void)start;
+ (void)stop;
@end

