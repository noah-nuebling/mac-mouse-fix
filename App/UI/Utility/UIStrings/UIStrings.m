//
// --------------------------------------------------------------------------
// UIStrings.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "UIStrings.h"
#import <Carbon/Carbon.h>
#import "MASShortcut.h"
#import "CGSHotKeys.h"
#import "SharedUtility.h"
#import "NSAttributedString+Additions.h"
#import "Symbols.h"
#import "Mac_Mouse_Fix-Swift.h"

@implementation UIStrings

//func flag(country:String) -> String {
//    let base : UInt32 = 127397
//    var s = ""
//    for v in country.unicodeScalars {
//        s.unicodeScalars.append(UnicodeScalar(base + v.value)!)
//    }
//    return String(s)
//}

+ (NSString * _Nullable)flagEmoji:(NSString *)countryCode {
    
    /// Src: https://stackoverflow.com/a/34995291
    
    int base = 127462 - 65;

    wchar_t bytes[2] = {
        base + [countryCode characterAtIndex:0],
        base + [countryCode characterAtIndex:1]
    };

    return [[NSString alloc] initWithBytes:bytes
                                    length:countryCode.length * sizeof(wchar_t)
                                  encoding:NSUTF32LittleEndianStringEncoding];
}


/// Other code for obtaining UI strings found in RemapTableController
/// Function for getting extended button string for tooltips found in RemapTableController

+ (NSString *)systemSettingsName {
    
    if (@available(macOS 13.0, *)) {
        return NSLocalizedString(@"system-settings-name", @"First draft: System Settings");
    } else {
        return NSLocalizedString(@"system-settings-name.pre-ventura", @"First draft: System Preferences");
    }
}

+ (NSString *)stringForKeyCode:(NSInteger)keyCode {
    
    /// Get string from MASShortcut
    
    MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:keyCode modifierFlags:0];
    NSString *keyStr = shortcut.keyCodeString;
    
    return keyStr;
}

+ (NSString *)getButtonString:(MFMouseButtonNumber)buttonNumber {
    
    NSDictionary *buttonNumberToUIString = @{
        @1: NSLocalizedString(@"button-string.primary",     @"First draft: Primary Button"),
        @2: NSLocalizedString(@"button-string.secondary",   @"First draft: Secondary Button"),
        @3: NSLocalizedString(@"button-string.middle",      @"First draft: Middle Button"),
    };
    NSString *buttonStr = buttonNumberToUIString[@(buttonNumber)];
    if (!buttonStr) {
        buttonStr = stringf(NSLocalizedString(@"button-string.numbered", @"First Draft: Button %@"), @(buttonNumber));
    }
    return buttonStr;
}

+ (NSString *)getButtonStringToolTip:(MFMouseButtonNumber)buttonNumber {
    
    NSDictionary *buttonNumberToUIString = @{
        @1: NSLocalizedString(@"button-string.tool.primary",   @"First draft: Primary Mouse Button (also called Left Mouse Button or Mouse Button 1)"),
        @2: NSLocalizedString(@"button-string.tool.secondary", @"First draft: Secondary Mouse Button (also called Right Mouse Button or Mouse Button 2)"),
        @3: NSLocalizedString(@"button-string.tool.middle",    @"First draft: Middle Mouse Button (also called Scroll Wheel Button or Mouse Button 3) || Example usage: Open links in a new tab, paste text in the Terminal, and more.\n \nWorks like clicking the Middle Mouse Button (also called the Scroll Wheel Button or Mouse Button 3) on a standard mouse."),
    };
    NSString *buttonStr = buttonNumberToUIString[@(buttonNumber)];
    if (!buttonStr) {
        buttonStr = stringf(NSLocalizedString(@"button-string.tool.numbered", @"First draft: Mouse Button %@"), @(buttonNumber));
    }
    return buttonStr;
}

+ (NSString *)getKeyboardModifierString:(CGEventFlags)flags {
    NSString *kb = @"";
    CGEventFlags f = flags;
    kb = [NSString stringWithFormat:@"%@%@%@%@",
          (f & kCGEventFlagMaskControl ?    @"^" : @""),
          (f & kCGEventFlagMaskAlternate ?  @"⌥" : @""),
          (f & kCGEventFlagMaskShift ?      @"⇧" : @""),
          (f & kCGEventFlagMaskCommand ?    @"⌘" : @"")];

    return kb;
}
+ (NSString *)getKeyboardModifierStringToolTip:(CGEventFlags)flags {
    
    /// Unused. See `getButtonStringToolTip:`
    
    assert(false);
    
    NSString *kb = @"";
    CGEventFlags f = flags;
    kb = [NSString stringWithFormat:@"%@%@%@%@",
          (f & kCGEventFlagMaskControl ?    [NSLocalizedString(@"modifer-key.tool.control",  @"First draft: Control (^)")   stringByAppendingString:@"-"] : @""),
          (f & kCGEventFlagMaskAlternate ?  [NSLocalizedString(@"modifer-key.tool.option",   @"First draft: Option (⌥)")    stringByAppendingString:@"-"]  : @""),
          (f & kCGEventFlagMaskShift ?      [NSLocalizedString(@"modifer-key.tool.shift",    @"First draft: Shift (⇧)")     stringByAppendingString:@"-"]   : @""),
          (f & kCGEventFlagMaskCommand ?    [NSLocalizedString(@"modifer-key.tool.command",  @"First draft: Command (⌘)")   stringByAppendingString:@"-"] : @"")];
    if (kb.length > 0) {
        kb = [kb substringToIndex:kb.length-1]; /// Delete trailing dash
        NSArray *stringArray = [kb componentsSeparatedByString:@"-"];
        kb = [self naturalLanguageListFromStringArray:stringArray];
        kb = [@"Hold " stringByAppendingString:kb];
    }
    
    return kb;
}

+ (NSAttributedString *)getStringForSystemDefinedEvent:(MFSystemDefinedEventType)type flags:(CGEventFlags)flags font:(NSFont *)font {
    
    /// Font is used to get SFSymbol fallback images to align correctly
    
    /// Approach 1:
    ///     Embed the SF Symbol image as a text attachment
    
    NSString *symbolName = @"questionmark.square";
    NSString *stringFallback = @"<Key without description>";
    
    if (type == kMFSystemEventTypeBrightnessDown) {
        symbolName = @"sun.min";
        stringFallback = NSLocalizedString(@"apple-key-fallback.sun.min", @"First draft: <Decrease Brightness key> || Example usage: Works like pressing '<Decrease Brightness Key>' on an Apple keyboard. || Note: Unlike in the interface builder `.strings` files, in `Localizable.strings`, <> doesn't mean that the text is unused. I think the usage of <> here is a little weird, so let me know if you have a better idea!");
    } else if (type == kMFSystemEventTypeBrightnessUp) {
        symbolName = @"sun.max";
        stringFallback = NSLocalizedString(@"apple-key-fallback.sun.max" , @"First draft: <Increase Brightness key>");
    } else if (type == kMFSystemEventTypeMediaBack) {
        symbolName = @"backward";
        stringFallback = NSLocalizedString(@"apple-key-fallback.backward" , @"First draft: <Rewind key>");
    } else if (type == kMFSystemEventTypeMediaPlayPause) {
        symbolName = @"playpause";
        stringFallback = NSLocalizedString(@"apple-key-fallback.playpause" , @"First draft: <Play or Pause key>");
    } else if (type == kMFSystemEventTypeMediaForward) {
        symbolName = @"forward";
        stringFallback = NSLocalizedString(@"apple-key-fallback.forward" , @"First draft: <Fast-Forward key>");
    } else if (type == kMFSystemEventTypeVolumeMute) {
        symbolName = @"speaker";
        stringFallback = NSLocalizedString(@"apple-key-fallback.speaker" , @"First draft: <Mute key>");
    } else if (type == kMFSystemEventTypeVolumeDown) {
        symbolName = @"speaker.wave.1";
        stringFallback = NSLocalizedString(@"apple-key-fallback.speaker.wave.1" , @"First draft: <Decrease Volume key>");
    } else if (type == kMFSystemEventTypeVolumeUp) {
        symbolName = @"speaker.wave.3";
        stringFallback = NSLocalizedString(@"apple-key-fallback.speaker.wave.3" , @"First draft: <Increase Volume key>");
    } else if (type == kMFSystemEventTypeKeyboardBacklightDown) {
        symbolName = @"light.min";
        stringFallback = NSLocalizedString(@"apple-key-fallback.light.min" , @"First draft: <Decrease Keyboard Brightness key>");
    } else if (type == kMFSystemEventTypeKeyboardBacklightUp) {
        symbolName = @"light.max";
        stringFallback = NSLocalizedString(@"apple-key-fallback.light.max" , @"First draft: <Increase Keyboard Brightness key>");
    } else if (type == kMFSystemEventTypePower) {
        symbolName = @"power";
        stringFallback = NSLocalizedString(@"apple-key-fallback.power" , @"First draft: <Power key>");
    } else if (type == kMFSystemEventTypeCapsLock) {
        symbolName = @"capslock";
        stringFallback = NSLocalizedString(@"apple-key-fallback.capslock" , @"First draft: ⇪");
    }

    /// Get symbol and attach it to keyStr
    NSAttributedString *keyStr =  [Symbols keyStringWithSymbol:symbolName fallbackString:stringFallback font:font];
    
    /// Validate
    if ([symbolName isEqual: @"questionmark.square"]) {
        DDLogWarn(@"Couldn't find visualization for system event with type: %d, flags: %llu", type, flags);
    }
    
    /// Approach 2:
    ///   Use the SF Symbol unicode character directly.
    ///   Notes:
    ///   - This approach is preferable to Approach 1 because we don't need a stringFallback for the tooltip and because it simplifies the code a lot.
    ///   - However, I tested this under macOS Big Sur, and it didn't work – before I installed the SF Symbois app. After installing the app, it started working perfectly. Not sure what's going on there.
    ///     Also see the discussion on this GH pull request with @groverlynn: https://github.com/noah-nuebling/mac-mouse-fix/pull/385
    
//    NSString *keyStrRaw;
//
//    if (type == kMFSystemEventTypeBrightnessDown)               { keyStrRaw = @"􀆫"; }
//    else if (type == kMFSystemEventTypeBrightnessUp)            { keyStrRaw = @"􀆭"; }
//    else if (type == kMFSystemEventTypeMediaBack)               { keyStrRaw = @"􀊉"; }
//    else if (type == kMFSystemEventTypeMediaPlayPause)          { keyStrRaw = @"􀊇"; }
//    else if (type == kMFSystemEventTypeMediaForward)            { keyStrRaw = @"􀊋"; }
//    else if (type == kMFSystemEventTypeVolumeMute)              { keyStrRaw = @"􀊠"; }
//    else if (type == kMFSystemEventTypeVolumeDown)              { keyStrRaw = @"􀊤"; }
//    else if (type == kMFSystemEventTypeVolumeUp)                { keyStrRaw = @"􀊨"; }
//    else if (type == kMFSystemEventTypeKeyboardBacklightDown)   { keyStrRaw = @"􀇭"; }
//    else if (type == kMFSystemEventTypeKeyboardBacklightUp)     { keyStrRaw = @"􀇮"; }
//    else if (type == kMFSystemEventTypePower)                   { keyStrRaw = @"􀆨"; }
//    else if (type == kMFSystemEventTypeCapsLock)                { keyStrRaw = @"􀆡"; } /// This symbol doesn't appear on US keyboards, but we disable capturing capslock anyways
//    else {
//        keyStrRaw = @"􀅍";
//        DDLogWarn(@"Couldn't find visualization for system event with type: %d, flags: %llu", type, flags);
//    }
//    NSAttributedString *keyStr = keyStrRaw.attributed;

    
    /// Combine with flagsString and return
    NSString *flagsStr = [UIStrings getKeyboardModifierString:flags];
    return symbolStringWithModifierPrefix(flagsStr, keyStr);
}

static NSMutableDictionary *_hotKeyCache;
static CGSSymbolicHotKey _highestSymbolicHotKeyInCache = 0;

+ (NSAttributedString *)getStringForKeyCode:(CGKeyCode)keyCode flags:(CGEventFlags)flags font:(NSFont *)font {
    
    /// Font is used to get SFSymbol fallback images to align correctly
    
    /// Get key string
    NSString *keyStr = [UIStrings stringForKeyCode:keyCode];
    NSString *flagsStr = [UIStrings getKeyboardModifierString:flags];
    
    if (![keyStr isEqual:@""]) {
        
        NSString *combinedString = stringf(@"%@%@", flagsStr, keyStr);
        combinedString = [self stringByTrimmingLeadingWhiteSpace:combinedString];
        /// ^ Some keyStrings have leading whitespace (name " Space") to look better with preceding modifiers. But if there are no modifiers the leading space looks weird.
        
        return [[NSAttributedString alloc] initWithString:combinedString];
        
    } else {
        /// Couldn't retrieve keyStr using MAS
        
        NSAttributedString *keyStr;
        
        /// Fallback for apple proprietary function keys
        
        /// Init
        if (!_hotKeyCache) {
            _hotKeyCache = [NSMutableDictionary dictionary];
        }
        /// Get shk
        NSNumber *symbolicHotkey;
        
        /// Try to retrieve from cache
        symbolicHotkey = _hotKeyCache[@(keyCode)][@(flags)];
        
        /// If not found in cache - search new value
        if (symbolicHotkey == nil) {
            
            CGSSymbolicHotKey shk = _highestSymbolicHotKeyInCache;
            while (shk < 512) { /// 512 is arbitrary
                                
                unichar keyEquivalent;
                CGKeyCode virtualKeyCode;
                CGSModifierFlags modifiers;
                
                CGSGetSymbolicHotKeyValue(shk, &keyEquivalent, &virtualKeyCode, &modifiers);
                if (virtualKeyCode == 126) {
                    /// Why did we put this if-statement??
                }
                
                if (_hotKeyCache[@(virtualKeyCode)] == nil) {
                    _hotKeyCache[@(virtualKeyCode)] = [NSMutableDictionary dictionary];
                }
                
                /// Store in cache for later
                _hotKeyCache[@(virtualKeyCode)][@(modifiers)] = @(shk);
                
                /// Check if shk is what we're looking for.
                if (((CGKeyCode)virtualKeyCode) == keyCode) {
                    symbolicHotkey = @(shk);
                    break;
                }
                
                shk++;
            }
        }
        
        /// If symbolicHotKey found for keyCode and flags -> generate keyStr based on symbolicHotKey
        
        if (symbolicHotkey != nil) {
            
            CGSSymbolicHotKey shk = (CGSSymbolicHotKey)symbolicHotkey.integerValue;
            
            
            /// Approach 1:
            ///     Embed the SF Symbol image as a text attachment
            
            NSString *symbolName = @"questionmark.square";
            NSString *stringFallback = NSLocalizedString(@"apple-key-fallback.unknown-key", @"First draft: <Key without description>");

            if (shk == kMFFunctionKeySHKMissionControl) {
                symbolName = @"rectangle.3.group";
                stringFallback = NSLocalizedString(@"apple-key-fallback.rectangle.3.group", @"First draft: <Mission Control key>");
            } else if (shk == kMFFunctionKeySHKDictation) {
                symbolName = @"mic";
                stringFallback = NSLocalizedString(@"apple-key-fallback.mic", @"First draft: <Dictation key>");
            } else if (shk == kMFFunctionKeySHKSpotlight) {
                symbolName = @"magnifyingglass";
                stringFallback = NSLocalizedString(@"apple-key-fallback.magnifyingglass", @"First draft: <Spotlight key>");
            } else if (shk == kMFFunctionKeySHKDoNotDisturb) {
                symbolName = @"moon";
                stringFallback = NSLocalizedString(@"apple-key-fallback.moon", @"First draft: <Do Not Disturb key>");
            } else if (shk == kMFFunctionKeySHKSwitchKeyboard) {
                symbolName = @"globe";
                stringFallback = NSLocalizedString(@"apple-key-fallback.globe", @"First draft: <Emoji Picker key>");
            } else if (shk == kMFFunctionKeySHKLaunchpad) {
                symbolName = @"square.grid.3x2";
                stringFallback = NSLocalizedString(@"apple-key-fallback.square.grid.3x2", @"First draft: <Launchpad key>");
            }

            /// Get symbol and attach it to keyStr
            keyStr =  [Symbols keyStringWithSymbol:symbolName fallbackString:stringFallback font:font];

            /// Validiate
            if ([symbolName isEqual:@"questionmark.square"]) {
                DDLogError(@"Couldn't find visualization for keyCode: %d, flags: %llu, symbolicHotKey: %@", keyCode, flags, symbolicHotkey);
            }
            
            
            /// Approach 2:
            ///     Use the SF Symbol unicode character directly
            ///     See `+ getStringForSystemDefinedEvent:flags:`for more info
            
//            NSString *keyStrRaw;
//            if (shk == kMFFunctionKeySHKMissionControl)         { keyStrRaw = @"􀇴"; }
//            else if (shk == kMFFunctionKeySHKDictation)         { keyStrRaw = @"􀊰"; }
//            else if (shk == kMFFunctionKeySHKSpotlight)         { keyStrRaw = @"􀊫"; }
//            else if (shk == kMFFunctionKeySHKDoNotDisturb)      { keyStrRaw = @"􀆹"; }
//            else if (shk == kMFFunctionKeySHKSwitchKeyboard)    { keyStrRaw = @"􀆪"; }
//            else if (shk == kMFFunctionKeySHKLaunchpad)         { keyStrRaw = @"􀇵"; }
//            else {
//                keyStrRaw = @"􀅍";
//                DDLogError(@"Couldn't find visualization for keyCode: %d, flags: %llu, symbolicHotKey: %@", keyCode, flags, symbolicHotkey);
//            }
//            keyStr = keyStrRaw.attributed;
        }
        
        /// Append keyStr and modStr
        NSMutableAttributedString *result = symbolStringWithModifierPrefix(flagsStr, keyStr);
        
        return result;
    }
}

static NSMutableAttributedString *symbolStringWithModifierPrefix(NSString *flagsStr, NSAttributedString *symbolStr) {
    
    if (flagsStr == nil) {
        flagsStr = @"";
    }
    if (symbolStr == nil) {
        symbolStr = [[NSAttributedString alloc] initWithString:@""];
    }
    
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:flagsStr];
    [result appendAttributedString:symbolStr];
    
    return result;
}


/// vvv Moved this stuff to Symbols.swift TODO: Remove

//static NSAttributedString *stringWithSymbol(NSString *symbolName, NSString *fallbackString, NSFont *font) {
//
//    /// Image
//    /// Try to get SFSymbol first, fall back to bundled image
//    /// Why aren't we using [NSAttributedString stringWithSymbol:hPadding:vOffset:fallback:] anymore?
//
//    NSImage *sfSymbol = nil;
//    if (@available(macOS 11.0, *)) {
//        sfSymbol = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:@""];
//    }
//    BOOL useBundledImage = sfSymbol == nil; // arc4random_uniform(2) == 0; // YES; //sfSymbol == nil;
//
//    NSImage *symbol = nil;
//    if (useBundledImage) { /// Fallback to bundled image
//        symbol = [NSImage imageNamed:symbolName];
//    } else {
//        symbol = sfSymbol;
//    }
//
//    /// Early return
//    ///     If no symbol is found anywhere, just return the fallback string.
//    if (symbol == nil) {
//        return [[NSAttributedString alloc] initWithString:fallbackString];
//    }
//
//    /// Fix fallback tint
//    if (useBundledImage) {
//        symbol = [symbol coolTintedImage:symbol color:NSColor.textColor];
//    }
//
//    /// Store fallback
//    ///     This is read in `[NSAttributedString coolString]`. Maybe elsewhere
//    ///     Storing in `accessibilityDescription` is kind of hacky
//    symbol.accessibilityDescription = fallbackString;
//
//    /// Image ->  textAattachment
//    NSTextAttachment *symbolAttachment = [[NSTextAttachment alloc] init];
//    symbolAttachment.image = symbol;
//
//    /// Fix fallback alignment
//
//    if (useBundledImage) {
//
//        /// Fix alignmentRect centering
//        ///     - I don't think this makes any sense
//        ///     - The alignmentRect seems to be ignored when rendering non-SFSymbol images (Maybe it's also ignored for SFSymbol images - haven't tested much)
//        ///     - So we try to offset the image such that the alignment rect center is preserved. I don't think this makes sense since when we render non-sfsymbol images they don't even have an alignmentRect since they are just loaded from pure images. Also the SFSymbols alignment rects ARE always centered in the image from what I've seen
//        ///     -> TODO: Remove
//
//        double alignmentOffsetX = 0.0;
//        double alignmentOffsetY = 0.0;
//
//        if (useBundledImage) {
//
//            double centerX1 = symbol.alignmentRect.origin.x + symbol.alignmentRect.size.width/2.0;
//            double centerY1 = symbol.alignmentRect.origin.y + symbol.alignmentRect.size.height/2.0;
//
//            double centerX2 = symbol.size.width/2.0;
//            double centerY2 = symbol.size.height/2.0;
//
//            alignmentOffsetX = centerX2 - centerX1;
//            alignmentOffsetY = centerY2 - centerY1;
//        }
//
//        /// Fix font alignment
//        [UIStrings centerImageAttachment:symbolAttachment image:symbol font:font offsetX:alignmentOffsetX offsetY: alignmentOffsetY];
//    }
//
//    /// Create textAttachment -> String
//    NSAttributedString *string = [NSAttributedString attributedStringWithAttachment:symbolAttachment];
//
//    /// Check darmode
//    BOOL isDarkmode = NO;
//    if (@available(macOS 10.14, *)) if (NSApp.effectiveAppearance.name == NSAppearanceNameDarkAqua) isDarkmode = YES;
//
//
//    /// Polish weight, size, alighment
//    /// Not sure why this stuff also works for the fallback but it does
//    /// This is probably very specific to displaying in the keyCaptureView. Might want to refactor and put core functionality into `NSAttributedString+Additions`
//
//    if (isDarkmode) {
//        string = [string attributedStringByAddingWeight:0.4];
//        string = [string attributedStringByAddingBaseLineOffset:0.39];
//    } else {
//        string = [string attributedStringByAddingWeight:0.3];
//        string = [string attributedStringByAddingBaseLineOffset:0.39];
//    }
//
//    string = [string attributedStringBySettingFontSize:11.4];
//
//    /// Return
//    return string;
//}

+ (NSString *)naturalLanguageListFromStringArray:(NSArray<NSString *> *)stringArray {
    
    /// See:
    /// - https://developer.apple.com/forums/thread/91225
    /// - Locale.current.groupingSeparator
    
    NSMutableArray<NSString *> *sa = stringArray.mutableCopy;
    
    NSString *outString;
    
    if (sa.count == 0) {
        
        outString = @"";
        
    } else if (sa.count == 1) {
        
        outString = sa[0];
        
    } else if (sa.count > 1) {
        
        NSString *lastString = sa.lastObject;
        [sa removeLastObject];
        
        NSArray *firstStrings = sa;
        
        NSString *join = NSLocalizedString(@"join-list", @"First draft: ,  || Note: This string joins elements in a list except the second-to-last and last one. || Note: The first draft contains a space after the comma.");
        NSString *joinLast = NSLocalizedString(@"join-list.last", @"First draft: %@ and %@ || Note: This format string joins the second-to-last element and the last elements in a list of items");
        
        outString = stringf(joinLast, [firstStrings componentsJoinedByString:join], lastString);
    } else {
        assert(false);
    }
    
    /// On trimming whitespace: Not sure if trimming whitespace here is a good idea. If we always trim whitespace right before a string is displayed to the user this should be unnecessary.
    return outString.stringByTrimmingWhiteSpace;
}

/// Helper

+ (NSString *)stringByTrimmingLeadingWhiteSpace:(NSString *)str {

    NSRange range = [str rangeOfString:@"^\\s*" options:NSRegularExpressionSearch];
    return [str stringByReplacingCharactersInRange:range withString:@""];
}

@end
