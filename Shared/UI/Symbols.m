//
// --------------------------------------------------------------------------
// Symbols.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Symbols.h"
#import "NSAttributedString+Additions.h"
#import "NSImage+Additions.h"

@implementation Symbols

#pragma mark - Lvl 1 - Symbol strings

+ (NSAttributedString *)keyStringWithSymbol:(NSString *)symbolName fallbackString:(NSString *)fallbackString font:(NSFont *)font {
    
    /// This is intended specifically to display keyboad keys for the `Keyboard Shortcut...` feature
    
    /// Call core
    NSAttributedString *string = [Symbols stringWithSymbol:symbolName fallbackString:fallbackString font:font];
    
    /// Check darmode
    BOOL isDarkmode = NO;
    if (@available(macOS 10.14, *)) if (NSApp.effectiveAppearance.name == NSAppearanceNameDarkAqua) isDarkmode = YES;
    
    /// Set weight, size, alighment
    /// Not sure why this stuff also works for the fallback but it does
        
    if (isDarkmode) {
        string = [string attributedStringByAddingWeight:0.4];
        string = [string attributedStringByAddingBaseLineOffset:0.39];
    } else {
        string = [string attributedStringByAddingWeight:0.3];
        string = [string attributedStringByAddingBaseLineOffset:0.39];
    }
    
    string = [string attributedStringBySettingFontSize:11.4];
    
    /// Return
    return string;
}

+ (NSAttributedString *)stringWithSymbol:(NSString *)symbolName fallbackString:(NSString *)fallbackString font:(NSFont *)font {

    /// Try to get SFSymbol with name `symbolName` first, fall back to bundled image with name `symbolName`, then fall back to `fallbackString`
    /// `font` is used to vertically align the symbol with the text
    
    BOOL usingBundledFallback;
    NSImage *symbol = [Symbols imageWithSymbol:symbolName fallbackString:fallbackString usingBundledFallback:&usingBundledFallback];
    
    /// Early return
    ///     If no symbol is found anywhere, just return the fallback string
    if (symbol == nil) {
        return [[NSAttributedString alloc] initWithString:fallbackString];
    }
    
    /// Image ->  textAttachment
    NSTextAttachment *symbolAttachment = [[NSTextAttachment alloc] init];
    symbolAttachment.image = symbol;

    /// Fix fallback alignment
    
    if (usingBundledFallback) {
        
        /// Fix alignmentRect centering
        ///     - I don't think this makes any sense
        ///     - The alignmentRect seems to be ignored when rendering non-SFSymbol images (Maybe it's also ignored for SFSymbol images - haven't tested much)
        ///     - So we try to offset the image such that the alignment rect center is preserved. I don't think this makes sense since when we render non-sfsymbol images they don't even have an alignmentRect since they are just loaded from pure images. Also the SFSymbols alignment rects ARE always centered in the image from what I've seen
        ///     -> TODO: Remove
        
        double alignmentOffsetX = 0.0;
        double alignmentOffsetY = 0.0;

        if (usingBundledFallback) {

            double centerX1 = symbol.alignmentRect.origin.x + symbol.alignmentRect.size.width/2.0;
            double centerY1 = symbol.alignmentRect.origin.y + symbol.alignmentRect.size.height/2.0;

            double centerX2 = symbol.size.width/2.0;
            double centerY2 = symbol.size.height/2.0;

            alignmentOffsetX = centerX2 - centerX1;
            alignmentOffsetY = centerY2 - centerY1;
        }
        
        /// Fix font alignment
        [Symbols centerImageAttachment:symbolAttachment image:symbol font:font offsetX:alignmentOffsetX offsetY: alignmentOffsetY];
    }
    
    /// Create textAttachment -> String
    NSAttributedString *string = [NSAttributedString attributedStringWithAttachment:symbolAttachment];
    
    /// Return
    return string;
}

#pragma mark - Lvl 0 - Symbol images

+ (NSImage *_Nullable)imageWithSymbol:(NSString *)symbolName fallbackString:(NSString *)fallbackString {
    
    BOOL usingBundledFallback;
    return [Symbols imageWithSymbol:symbolName fallbackString:fallbackString usingBundledFallback:&usingBundledFallback];
}

+ (NSImage *_Nullable)imageWithSymbol:(NSString *)symbolName fallbackString:(NSString *)fallbackString usingBundledFallback:(BOOL *)usingBundledFallback {
    
    /// Try to get SFSymbol with name `symbolName` first, fall back to bundledImage with name `symbolName`. Return nil if both fails
    ///     Store `fallbackString` as accessibilityDescription of the NSImage
    
    NSImage *sfSymbol = nil;
    if (@available(macOS 11.0, *)) {
        sfSymbol = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:@""];
    }
    *usingBundledFallback = sfSymbol == nil; // arc4random_uniform(2) == 0; // YES; //sfSymbol == nil;
    
    NSImage *symbol = nil;
    if (*usingBundledFallback) { /// Fallback to bundled image
        symbol = [NSImage imageNamed:symbolName];
    } else {
        symbol = sfSymbol;
    }
    
    /// Early return
    ///     No symbol found
    if (symbol == nil) {
        return nil;
    }
    
    /// Fix fallback tint
    ///     Set it to NSColor.textColor - does that always make sense? Should we make the fallback color a parameter?
    if (*usingBundledFallback) {
        symbol = [symbol coolTintedImage:symbol color:NSColor.textColor];
    }
    
    /// Store fallback
    ///     This is read in `[NSAttributedString coolString]`. Maybe elsewhere.
    symbol.accessibilityDescription = fallbackString;
    
    /// Return
    return symbol;
}

#pragma mark - Helper

/// Attachment centering
///     Not totally sure this belongs here

+ (void)centerImageAttachment:(NSTextAttachment *)attachment image:(NSImage *)image font:(NSFont *)font {
    [Symbols centerImageAttachment:attachment image:image font:font offsetX:0.0 offsetY:0.0];
}

+ (void)centerImageAttachment:(NSTextAttachment *)attachment image:(NSImage *)image font:(NSFont *)font offsetX:(double)offsetX offsetY:(double)offsetY {
    
    /// Vertically align the imageAttachment with normal text
    /// - This is not necessary if the NSImage represents an SFSymbol
    /// - Src: https://stackoverflow.com/a/45161058/10601702
    
    double fontCenterOffset = (font.capHeight - image.size.height)/2.0;
    attachment.bounds = NSMakeRect(offsetX, offsetY + fontCenterOffset, image.size.width, image.size.height);
}

@end
