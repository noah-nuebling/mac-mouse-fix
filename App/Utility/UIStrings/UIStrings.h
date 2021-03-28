//
// --------------------------------------------------------------------------
// UIStrings.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface UIStrings : NSObject

+ (NSString *)stringForKeyCode:(NSInteger)keyCode;
+ (NSString *)getButtonString:(MFMouseButtonNumber)buttonNumber;
+ (NSString *)getButtonStringToolTip:(MFMouseButtonNumber)buttonNumber;
+ (NSString *)getKeyboardModifierString:(CGEventFlags)flags;
+ (NSString *)getKeyboardModifierStringToolTip:(CGEventFlags)flags;
+ (NSString *)getStringForKeyCode:(CGKeyCode)keyCode flags:(CGEventFlags)flags;

@end

NS_ASSUME_NONNULL_END
