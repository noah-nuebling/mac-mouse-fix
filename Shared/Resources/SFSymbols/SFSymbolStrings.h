//
// --------------------------------------------------------------------------
// SFSymbolStrings.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SFSymbolStrings : NSObject

+ (NSAttributedString *)keyStringWithSymbol:(NSString *)symbolName fallbackString:(NSString *)fallbackString font:(NSFont *)font;
+ (NSAttributedString *)stringWithSymbolName:(NSString *)symbolName stringFallback:(NSString *)fallbackString font:(NSFont *)font;
+ (NSImage *_Nullable)imageWithSymbolName:(NSString *)symbolName;
+ (NSImage *_Nullable)imageWithSymbolName:(NSString *)symbolName accessibilityDescription:(NSString *)fallbackString;
+ (NSImage *_Nullable)imageWithSymbolName:(NSString *)symbolName accessibilityDescription:(NSString *)fallbackString usingBundledFallback:(BOOL *)usingBundledFallback;

@end

NS_ASSUME_NONNULL_END
