//
// --------------------------------------------------------------------------
// UIStrings.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <CoreGraphics/CoreGraphics.h>
//#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#import "Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface UIStrings : NSObject

+ (NSString * _Nullable)flagEmoji:(NSString *)countryCode;
+ (NSString *)systemSettingsName;
+ (NSString *)stringForKeyCode:(NSInteger)keyCode;
+ (NSString *)getButtonString:(MFMouseButtonNumber)buttonNumber;
+ (NSString *)getButtonStringToolTip:(MFMouseButtonNumber)buttonNumber;
+ (NSString *)getKeyboardModifierString:(CGEventFlags)flags;
+ (NSString *)getKeyboardModifierStringToolTip:(CGEventFlags)flags;
+ (NSAttributedString *)getStringForKeyCode:(CGKeyCode)keyCode flags:(CGEventFlags)flags font:(NSFont *)font;
+ (NSAttributedString *)getStringForSystemDefinedEvent:(MFSystemDefinedEventType)type flags:(CGEventFlags)flags font:(NSFont *)font;
//+ (NSAttributedString *)stringWithSymbol:(NSString *)symbolName fallback:(NSString *)fallbackString;
+ (NSString *)naturalLanguageListFromStringArray:(NSArray<NSString *> *)stringArray;
//+ (void)centerImageAttachment:(NSTextAttachment *)attachment image:(NSImage *)image font:(NSFont *)font;

@end

NS_ASSUME_NONNULL_END
