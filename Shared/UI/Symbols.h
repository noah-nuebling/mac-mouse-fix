//
// --------------------------------------------------------------------------
// Symbols.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface Symbols : NSObject

+ (NSAttributedString *)keyStringWithSymbol:(NSString *)symbolName fallbackString:(NSString *)fallbackString font:(NSFont *)font;
+ (NSAttributedString *)stringWithSymbol:(NSString *)symbolName fallbackString:(NSString *)fallbackString font:(NSFont *)font;
+ (NSImage *_Nullable)imageWithSymbol:(NSString *)symbolName fallbackString:(NSString *)fallbackString;
+ (NSImage *_Nullable)imageWithSymbol:(NSString *)symbolName fallbackString:(NSString *)fallbackString usingBundledFallback:(BOOL *)usingBundledFallback;

@end

NS_ASSUME_NONNULL_END
