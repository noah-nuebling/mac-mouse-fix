//
// --------------------------------------------------------------------------
// UIStrings.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

#import "Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface UIStrings : NSObject

+ (NSString *)stringForKeyCode:(NSInteger)keyCode;
+ (NSString *)getButtonString:(MFMouseButtonNumber)buttonNumber;
+ (NSString *)getButtonStringToolTip:(MFMouseButtonNumber)buttonNumber;
+ (NSString *)getKeyboardModifierString:(CGEventFlags)flags;
+ (NSString *)getKeyboardModifierStringToolTip:(CGEventFlags)flags;
+ (NSAttributedString *)getStringForKeyCode:(CGKeyCode)keyCode flags:(CGEventFlags)flags;
+ (NSAttributedString *)getStringForSystemDefinedEvent:(MFSystemDefinedEventType)type flags:(CGEventFlags)flags;
+ (NSAttributedString *)stringWithSymbol:(NSString *)symbolName fallback:(NSString *)fallbackString;
+ (NSString *)naturalLanguageListFromStringArray:(NSArray<NSString *> *)stringArray;

@end

NS_ASSUME_NONNULL_END
