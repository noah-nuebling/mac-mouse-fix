//
// --------------------------------------------------------------------------
// SFSymbolStrings.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "SFSymbolStrings.h"
#import "NSAttributedString+Additions.h"
#import "NSImage+Additions.h"

///
/// This file offers methods for creating NSAttributedString instances that display an SFSymbol through an NSImage Attachment.
///
/// It's also used to create NSAttributedStrings containing custom symbols (E.g. "CoolMenuBarIcon" as of 06.09.2024) (Therefore, perhaps, we should change the class name to not contain 'SFSymbols' )
///
/// Fallback mechanism:
///     There's a fallback mechanism where we set some plain NSString as the accessibilityDescription of the attached NSImage. Then we can use `[NSAttributedString(Additions) -stringWithAttachmentDescriptions]` to convert the NSAttributedString to a pure NSString but with the NSImage attachments replaced by their respective `accessibilityDescription`.
///
///     How we use this features is that we're setting the fallbackString of the SF Symbol image  to the unicode character for the SF Symbol. Then we ship a special font with MMF that can render those unicode characters. This allows us to use SF Symbols even inside of tooltips, where NSAttributedStrings are not possible.
///     Before this improved fallback mechanism was introduced (as I'm writing the new fallback mechanism, 3.0.2 is the latest release) we used to fallback to strings that looked like `<Increase Brightness Key>`. At the time of writing, we only really use this fallback stuff to display tooltips containing SF Symbols that appear on Apple Keyboard Keys.
///
/// Discussion:
///     Now that we ship the special font (CoolSFSymbols.otf), which can display SF Symbol unicode characters, you might think we'd want to do away with the NSImage attachments for displaying SFSymbols altogether. We might do that at some point, however, for now I wanna stick with the tried and true method, also, we already spent a lot of time perfecting the way that the NSImage attachments render and I think using unicode might be worse. Also, the more symbols we wanna render with CoolSFSymbols.otf the bigger we have to make the font file, althogh it'll probably stay very small (currently at 6 KB, able to render 10-20 symbols at regular weight.)
///

@implementation SFSymbolStrings

#pragma mark - Lvl 1 - Symbol strings

+ (NSAttributedString *)keyStringWithSymbol:(NSString *)symbolName fallbackString:(NSString *)fallbackString font:(NSFont *)font {
    
    /// This is intended specifically to display keyboad keys for the `Keyboard Shortcut...` feature
    /// Update: Unused now since we use CoolSFSymbols.otf to display sfSymbols representing keys on an Apple Keyboard, in a way that also works in plaintext (tooltips.)
    
    /// Call core
    NSAttributedString *string = [SFSymbolStrings stringWithSymbolName:symbolName stringFallback:fallbackString font:font];
    
    /// Check darkmode
    BOOL isDarkmode = NO;
    if (@available(macOS 10.14, *)) if (NSApp.effectiveAppearance.name == NSAppearanceNameDarkAqua) isDarkmode = YES;
    
    /// Set weight, size, alighment
    /// Not sure why this stuff also works for the fallback but it does
        
    if (isDarkmode) {
        string = [string attributedStringByAddingWeight:0.4 forRange:NULL];
        string = [string attributedStringByAddingBaseLineOffset:0.39 forRange:NULL];
    } else {
        string = [string attributedStringByAddingWeight:0.3 forRange:NULL];
        string = [string attributedStringByAddingBaseLineOffset:0.39 forRange:NULL];
    }
    
    string = [string attributedStringBySettingFontSize:11.4];
    
    /// Return
    return string;
}

+ (NSAttributedString *)stringWithSymbolName:(NSString *)symbolName stringFallback:(NSString *)stringFallback font:(NSFont *)font {

    /// Try to get SFSymbol with name `symbolName` first, fall back to bundled image with name `symbolName`, then fall back to `stringFallback`
    /// `font` is used to vertically align the symbol with the text
    
    BOOL usingBundledFallback;
    NSImage *symbol = [SFSymbolStrings imageWithSymbolName:symbolName accessibilityDescription:stringFallback usingBundledFallback:&usingBundledFallback];
    
    /// Early return
    ///     If no symbol is found anywhere, just return the fallback string
    if (symbol == nil) {
        return [[NSAttributedString alloc] initWithString:stringFallback];
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
        [SFSymbolStrings centerImageAttachment:symbolAttachment image:symbol font:font offsetX:alignmentOffsetX offsetY: alignmentOffsetY];
    }
    
    /// Create textAttachment -> String
    NSAttributedString *string = [NSAttributedString attributedStringWithAttachment:symbolAttachment];
    
    /// Return
    return string;
}

#pragma mark - Lvl 0 - Symbol images

+ (NSImage *_Nullable)imageWithSymbolName:(NSString *)symbolName {
    
    /// Use this over `[NSImage imageNamed:]` aka `NSImage(named:)` when getting symbols! It will dynamically either get the systemSymbol if it's available or fallback to a bundledImage.
    
    BOOL usingBundledFallback;
    NSString *description = symbolName; /// This is bad, but we don't really support accessibility at the moment anyways.
    return [SFSymbolStrings imageWithSymbolName:symbolName accessibilityDescription:description usingBundledFallback:&usingBundledFallback];
}

+ (NSImage *_Nullable)imageWithSymbolName:(NSString *)symbolName accessibilityDescription:(NSString *)description {
    
    BOOL usingBundledFallback;
    return [SFSymbolStrings imageWithSymbolName:symbolName accessibilityDescription:description usingBundledFallback:&usingBundledFallback];
}

+ (NSImage *_Nullable)imageWithSymbolName:(NSString *)symbolName accessibilityDescription:(NSString *)description usingBundledFallback:(BOOL *)usingBundledFallback {
    
    /// Try to get SFSymbol with name `symbolName` first. If that fails, fall back to bundledImage with name `symbolName` and set `usingBundledFallback` true. If both fail return nil
    /// `description` is stored as accessibilityDescription of the returned NSImage
    
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
    
    /// Store description
    ///     Not just used for accessibility! (Which we don't support at this point) This is read in `[NSAttributedString coolString]`. Maybe elsewhere.
    symbol.accessibilityDescription = description;
    
    /// Return
    return symbol;
}

#pragma mark - Helper

/// Attachment centering
///     Not totally sure this belongs here

+ (void)centerImageAttachment:(NSTextAttachment *)attachment image:(NSImage *)image font:(NSFont *)font {
    [SFSymbolStrings centerImageAttachment:attachment image:image font:font offsetX:0.0 offsetY:0.0];
}

+ (void)centerImageAttachment:(NSTextAttachment *)attachment image:(NSImage *)image font:(NSFont *)font offsetX:(double)offsetX offsetY:(double)offsetY {
    
    /// Vertically align the imageAttachment with normal text
    /// - This is not necessary if the NSImage represents an SFSymbol
    /// - Src: https://stackoverflow.com/a/45161058/10601702
    
    double fontCenterOffset = (font.capHeight - image.size.height)/2.0;
    attachment.bounds = NSMakeRect(offsetX, offsetY + fontCenterOffset, image.size.width, image.size.height);
}

@end
