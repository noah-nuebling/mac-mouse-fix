//
// --------------------------------------------------------------------------
// ModifierInputReceiver.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@interface ScrollModifiers : NSObject

+ (BOOL)magnificationScrollHasBeenUsed;
+ (void)setMagnificationScrollHasBeenUsed:(BOOL)B;

+ (BOOL)horizontalScrolling;
+ (void)setHorizontalScrolling:(BOOL)B;
+ (BOOL)magnificationScrolling;
+ (void)setMagnificationScrolling:(BOOL)B;

+ (void)handleMagnificationScrollWithAmount:(double)amount;

+ (void)setHorizontalScrollModifierKeyMask:(CGEventFlags)F;
+ (void)setMagnificationScrollModifierKeyMask:(CGEventFlags)F;

+ (BOOL)horizontalScrollModifierKeyEnabled;
+ (void)setHorizontalScrollModifierKeyEnabled:(BOOL)B;
+ (BOOL)magnificationScrollModifierKeyEnabled;
+ (void)setMagnificationScrollModifierKeyEnabled:(BOOL)B;

+ (void)start;
+ (void)stop;

@end

