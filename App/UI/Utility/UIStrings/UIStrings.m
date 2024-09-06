//
// --------------------------------------------------------------------------
// UIStrings.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "UIStrings.h"
#import <Carbon/Carbon.h>
#import "MASShortcut.h"
#import "CGSHotKeys.h"
#import "SharedUtility.h"
#import "NSAttributedString+Additions.h"
#import "SFSymbolStrings.h"
#import "Mac_Mouse_Fix-Swift.h"
#import "CoolSFSymbolsFont.h"

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
        return NSLocalizedString(@"system-settings-name", @"Note: The name of the system settings app in macOS 13 Ventura and later.");
    } else {
        return NSLocalizedString(@"system-settings-name.pre-ventura", @"Note: The name of the system settings app in macOS 12 Monterey and below.");
    }
}

+ (NSString *)getButtonString:(MFMouseButtonNumber)buttonNumber context:(MFButtonStringUsageContext)context {
    
    /// Notes:
    ///     - Having all these different strings for the same buttons, creates extra room for inconsistencies on the side of localizers - so we should do our best with comments and organization of the .xcloc files to help them avoid inconsistencies!
    ///     - Why do we define different button-name strings depending on context?:
    ///         - In some languages the button names have to be inflected differently depending on context.
    ///             -> E.g. if we were using Knopf (masculine) instead of Taste (feminine) in German it would have to be "Mittlerer Knopf" in the group row but "Mittleren Knopf klicken und ziehen" in the trigger string.
    ///         - Also in English we might wanna use title case in some contexts but not in others (although I'm sorta leaning towards using the same capitalization everywhere? Might make it easier to parse visually.)
    
    /// Get map
    ///     According to context.
    
    NSDictionary *map;
    
    if (context == kMFButtonStringUsageContextActionTableTriggerSubstring) {
        
        map = @{
            @1: NSLocalizedString(@"trigger.substring.button-name.primary",     @""),
            @2: NSLocalizedString(@"trigger.substring.button-name.secondary",   @""),
            @3: NSLocalizedString(@"trigger.substring.button-name.middle",      @"."),
            @-1: NSLocalizedString(@"trigger.substring.button-name.numbered",   @""), /// Note to self: Removed the old notes (see later in this line) after giving the trigger.substring. prefix to these string keys, since we're already explaining the capitalization on other `trigger.substring.[...]` comments. || Old notes: All the \"button-name.[...]\" strings should be lowercase unless there's a specific reason to capitalize some words. For example, in Vietnamese, \"Middle Button\" should be localized as \"nút giữa\". Note that not even the first letter is capitalized. That's because the button names will appear in the middle of other pieces of text, and we don't want a randomly capitalized button name in the middle of that text. In English, we capitalize because we're using \"Title Case\", but this isn't common in other languages. So for most languages, these strings should probably be all-lowercase, just like Vietnamese. Exceptions: Some languages have special capitalization rules similar to English \"Title Case\". For example, German always capitalizes all nouns, so therefore \"Middle Button\" should be localized as \"mittlere Taste\" in German. Please see the comment on \"trigger.substring.button-modifier.2\" for more info."), /// Note to self: We put the long comment on the 'numbered'-button-string since that shows up second in the .xcstrings file under alphabetic sorting. We think putting it second has the highest changes of the localizers noticing the comment. Since, if it's first, they might be busy processing "oh here's a new set of strings" /// Old note: || Note: This is capitalized in English since we use 'title case' there. In your language, 'title case' might not be a thing, and you might *not* want to capitalize this. If this string appears at the start of a line, it will be capitalized programmatically.
        };
        
    } else if (context == kMFButtonStringUsageContextActionTableGroupRow) {
        
        map = @{
            @1: NSLocalizedString(@"trigger.y.group-row.button-name.primary",     @""), /// The '.y.' is just used to group things in the .xcstrings file. Not sure if smart.
            @2: NSLocalizedString(@"trigger.y.group-row.button-name.secondary",   @""),
            @3: NSLocalizedString(@"trigger.y.group-row.button-name.middle",      @"Note: The \"trigger.y.group-row.button-name.[...]\" button names are used as headers to group together actions (e.g. 'Mission Control' or 'Scroll & Navigate') which are triggered by the same button. (I hope this is understandable! If not, please let me know so I can improve this. Thank you.)"),
            @-1: NSLocalizedString(@"trigger.y.group-row.button-name.numbered",   @"Note: For visual consistency, capitalization of the these button-name strings should probably follow the capitalization of the trigger.substring.button-name.[...] strings. - If you haven't filled those out, yet, you might want to fill them out first to figure out the capitalization, and then come back to fill out the button-names here. (This is just a guideline, if you have a specific reason to deviate it's up to your best judgement.)"),
        };
        
    } else if (context == kMFButtonStringUsageContextCaptureNotification) {
        
        map = @{
            @1: NSLocalizedString(@"capture-toast.button-name.primary",     @""),
            @2: NSLocalizedString(@"capture-toast.button-name.secondary",   @""),
            @3: NSLocalizedString(@"capture-toast.button-name.middle",      @"Note: These button names will be inserted into other \"capture-toast.[...]\" strings. Example: Middle Button and Button 4 are now captured by Mac Mouse Fix."),
            @-1: NSLocalizedString(@"capture-toast.button-name.numbered",   @"Note: For visual consistency, capitalization of the these button-name strings should probably follow the capitalization of the trigger.substring.button-name.[...] strings. - You might want to fill those out first to figure out the capitalization, and then come back to fill out the button-names here. (This is just a guideline, if you have a specific reason to deviate it's up to your best judgement.)"),
        };
        
    } else {
        assert(false);
        return nil;
    }

    /// Query map
    NSString *buttonStr = map[@(buttonNumber)];
    if (!buttonStr) {
        NSString *buttonStrFormat = map[@-1];
        buttonStr = stringf(buttonStrFormat, @(buttonNumber));
    }
    
    /// Return
    return buttonStr;
}

+ (NSString *)getButtonStringToolTip:(MFMouseButtonNumber)buttonNumber {
    
    /// Unused:
    ///     28.08.2024: Unused since separating these strings out didn't really make sense for the following reasons:
    ///              - The strings were only used in one place. (For the effect.primary-click, effect.secondary-click, etc. tooltips)
    ///              - We wanted to use these long button names in longer, more descriptive texts, where we'd wanna use them in full sentences like "works like clicking the Primary Mouse Button (also called ...)".
    ///                 But in German that doesn't always work, since we have to put the button names into different grammatical cases depending on context. ("Funktioniert wie das Klicken der Primären Maustaste" (auch genannt ...)")
    ///
    ///              Lesson: Make localized strings as non-modular and non-reused as possible, to give localizers more control over how the English strings are translated in different contexts.
    ///                 This goes against the general intuitions you have as a programmer, but it really makes sense.
    
    assert(false);
    return nil;
    
    #if 0
    
    NSDictionary *buttonNumberToUIString = @{
        @1: xxxNSLocalizedString(@"button-name.tool.primary",   @""),
        @2: xxxNSLocalizedString(@"button-name.tool.secondary", @""),
        @3: xxxNSLocalizedString(@"button-name.tool.middle",    @"Example usage: Open links in a new tab, paste text in the Terminal, and more.\n \nWorks like clicking the Middle Mouse Button (also called the Scroll Wheel Button or Mouse Button 3) on a standard mouse."),
    };
    NSString *buttonStr = buttonNumberToUIString[@(buttonNumber)];
    if (!buttonStr) {
        buttonStr = stringf(xxxNSLocalizedString(@"button-name.tool.numbered", @""), @(buttonNumber));
    }
    return buttonStr;
    
    #endif
}

+ (NSString *)getKeyboardModifierString:(CGEventFlags)flags {
    /// TODO: Maybe make this localizable.
    ///     See macOS keyboard shortcut help article in Korean (uses different convention for showing shortcuts) https://support.apple.com/ko-kr/102650
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
          (f & kCGEventFlagMaskControl ?    [NSLocalizedString(@"modifer-key.tool.control",  @"")   stringByAppendingString:@"-"] : @""),
          (f & kCGEventFlagMaskAlternate ?  [NSLocalizedString(@"modifer-key.tool.option",   @"")    stringByAppendingString:@"-"]  : @""),
          (f & kCGEventFlagMaskShift ?      [NSLocalizedString(@"modifer-key.tool.shift",    @"")     stringByAppendingString:@"-"]   : @""),
          (f & kCGEventFlagMaskCommand ?    [NSLocalizedString(@"modifer-key.tool.command",  @"")   stringByAppendingString:@"-"] : @"")];
    if (kb.length > 0) {
        kb = [kb substringToIndex:kb.length-1]; /// Delete trailing dash
        NSArray *stringArray = [kb componentsSeparatedByString:@"-"];
        kb = [self naturalLanguageListFromStringArray:stringArray];
        kb = [@"Hold " stringByAppendingString:kb];
    }
    
    return kb;
}

+ (NSAttributedString *)getStringForSymbolicHotkey:(CGSSymbolicHotKey)symbolicHotkey flags:(CGEventFlags)flags font:(NSFont *)font {
    return getStringForSystemDefinedEventOrSymbolicHotkey(symbolicHotkey, flags, font);
}

+ (NSAttributedString *)getStringForSystemDefinedEvent:(MFSystemDefinedEventType)systemDefinedEventType flags:(CGEventFlags)flags font:(NSFont *)font {
    return getStringForSystemDefinedEventOrSymbolicHotkey(systemDefinedEventType, flags, font);
}

static NSAttributedString *getStringForSystemDefinedEventOrSymbolicHotkey(int type, CGEventFlags flags, NSFont *fontArg) {
    
    /// Font is used to get SFSymbol fallback images to align correctly
    
    NSString *symbolUnicode = @"􀃬";
    NSString *symbolIdentifier = @"questionmark.square";

    /// Define map
    /// Explanation:
    ///     The values of the map are arrays where `array[0]` is the unicode character of an SF Symbol  and `array[1]` is the identifier of the SF Symbol.
    ///     The unicodeCharacters in the source code below will not display correctly, unless you have a font installed that can render them. The SF Pro font which you can download from Apple's website can render all SF Symbol unicode characters. Mac Mouse Fix ships with the CoolSFSymbols.otf font which can render a subset of SF Symbols that we need for Mac Mouse Fix. We need them for Mac Mouse Fix since unicode is the only way to display SF Symbols in a tooltip, because you can't use an NSAttributedString for a tooltip.
    ///
    ///     All the SF Symbols below should appear as 􀃬 in the source code, unless you have an SF Symbol-supporting font like SF Pro installed - or if you have force quit  Mac Mouse Fix the last time you ran it - which prevents it from unregistering the `CoolSFSymbols.otf` font which it registers as the app launches. If this happens, the `CoolSFSymbols.otf` font will also become unregistered after you you log out.
    ///
    ///     The `CoolSFSymbols.otf` font is registered/unregistered from AppDelegate.m at the time of writing.
    
    NSDictionary *map = @{
        
        /// Symbolic Hotkeys
        @(kMFFunctionKeySHKMissionControl):         @[@"􀇴", @"rectangle.3.group"],
        @(kMFFunctionKeySHKDictation):              @[@"􀊰", @"mic"],
        @(kMFFunctionKeySHKSpotlight):              @[@"􀊫", @"magnifyingglass"],
        @(kMFFunctionKeySHKDoNotDisturb):           @[@"􀆹", @"moon"],
        @(kMFFunctionKeySHKSwitchKeyboard):         @[@"􀆪", @"globe"],
        @(kMFFunctionKeySHKLaunchpad):              @[@"􀇵", @"square.grid.3x2"],
        
        /// System events
        ///     Note: All the SKHs are over 100 and the system events are under 100, so we can just put them all into one map. If there's a duplicate key in the literal, Xcode will warn us.
        @(kMFSystemEventTypeBrightnessDown):        @[@"􀆫", @"sun.min"], /// The symbols will all appear as 􀃬 unless you have SF Fonts installed from the Apple Website. But in MMF they will appear properly since we ship a font.
        @(kMFSystemEventTypeBrightnessUp):          @[@"􀆭", @"sun.max"],
        @(kMFSystemEventTypeMediaBack):             @[@"􀊉", @"backward"],
        @(kMFSystemEventTypeMediaPlayPause):        @[@"􀊇", @"playpause"],
        @(kMFSystemEventTypeMediaForward):          @[@"􀊋", @"forward"],
        @(kMFSystemEventTypeVolumeMute):            @[@"􀊠", @"speaker"],
        @(kMFSystemEventTypeVolumeDown):            @[@"􀊤", @"speaker.wave.1"],
        @(kMFSystemEventTypeVolumeUp):              @[@"􀊨", @"speaker.wave.3"],
        @(kMFSystemEventTypeKeyboardBacklightDown): @[@"􀇭", @"light.min"],
        @(kMFSystemEventTypeKeyboardBacklightUp):   @[@"􀇮", @"light.max"],
        @(kMFSystemEventTypePower):                 @[@"􀆨", @"power"],
        @(kMFSystemEventTypeCapsLock):              @[@"􀆡", @"capslock"], /// This symbol doesn't appear on US keyboards, but we disable capturing capslock anyways
        
        /// Validation
        /// - We should get an assert fail if we don't comment this out
        /// - Notes:
        ///     - The unicode character should always show up as 􀃬 unless you have SF fonts installed from Apples website.
        ///     - If this unicode character displays as 􀃬 but the ones above display properly, than means that SF Fonts are not registered but `CoolSFSymbols.otf` is.
        ///
        
//        @"someUnsupportedSFSymbol1":                @[@"􁖎", NSNull.null],
    };
    
    NSArray *rmap = map[@(type)];
    symbolUnicode = rmap[0];
    symbolIdentifier = rmap[1];
    
    /// Validate
    if (runningPreRelease()) {
        for (NSNumber *typeNS in map) {
            NSString *fallbackUnicode = map[typeNS][0];
            BOOL fallbackCharIsSupported = [CoolSFSymbolsFont symbolCharacterIsDisplayable:fallbackUnicode];
            if (!fallbackCharIsSupported) {
                DDLogError(@"Error: Fallback character %@ for SFSymbol %@ is not supported by our CoolSFSymbols font. It will not display correctly unless the user has a font installed that can display SF Symbols. To fix this, generate a new font using the createsfsymbols.py script and replace the CoolSFSymbols.otf font included in the Mac Mouse Fix bundle", fallbackUnicode, map[typeNS][1]);
                assert(false);
            }
        }
    }
    
    /// Validate
    if ([symbolIdentifier isEqual: @"questionmark.square"]) {
        DDLogWarn(@"No visualization programmed for system event with type: %d, flags: %llu", type, flags);
        assert(false);
    }
    
    NSAttributedString *keyStr;
    if ((NO)) {
        /// TEST - always use the SF Symbol unicode directly
        keyStr = symbolUnicode.attributed;
    } else {
        /// Get symbol image and attach it to keyStr
        keyStr = [SFSymbolStrings keyStringWithSymbol:symbolIdentifier fallbackString:symbolUnicode font:fontArg];
    }
    
    /// Combine with flagsString and return
    NSString *flagsStr = [UIStrings getKeyboardModifierString:flags];
    return symbolStringWithModifierPrefix(flagsStr, keyStr);
}


+ (NSAttributedString *)getStringForKeyCode:(CGKeyCode)keyCode flags:(CGEventFlags)flags font:(NSFont *)font {
    
    /// Note:
    /// - `font` is passed in to get image attachments to align correctly
    
    /// Declare statics
    static NSMutableDictionary *_hotKeyCache;
    static CGSSymbolicHotKey _highestSymbolicHotKeyInCache = 0;
    
    /// Get modifer flags str
    NSString *flagsStr = [UIStrings getKeyboardModifierString:flags];
    
    /// Get keyboard key string from MASShortcut
    MASShortcut *masShortcut = [MASShortcut shortcutWithKeyCode:keyCode modifierFlags:0];
    NSString *keyStr = masShortcut.keyCodeString;
    
    if (![keyStr isEqual:@""]) {
        
        NSString *combinedString = stringf(@"%@%@", flagsStr, keyStr);
        combinedString = stringByTrimmingLeadingWhiteSpace(combinedString);
        /// ^ Some keyStrings have leading whitespace (name " Space") to look better with preceding modifiers. But if there are no modifiers the leading space looks weird.
        
        return combinedString.attributed;
        
    } else {
        
        /// Fallback for special apple-keyboard keys which don't have corresponding unicode characters
        ///     E.g. the dictationKey, missionControlKey, etc.
        
        /// Create cache
        static dispatch_once_t onceToken;  dispatch_once(&onceToken, ^{
            _hotKeyCache = [NSMutableDictionary dictionary];
        });
        
        /// Get shk
        NSNumber *symbolicHotkey;
        
        /// Try to retrieve from cache
        symbolicHotkey = _hotKeyCache[@[@(keyCode), @(flags)]];
        
        /// If not found in cache - search new value
        if (symbolicHotkey == nil) {
            
            /// Search symbolic hotkeys.
            CGSSymbolicHotKey shk = _highestSymbolicHotKeyInCache;
            while (shk < 512) { /// 512 is arbitrary
                
                /// Get info about the SHK
                unichar keyEquivalent;
                CGKeyCode virtualKeyCode;
                CGSModifierFlags modifiers;
                CGSGetSymbolicHotKeyValue(shk, &keyEquivalent, &virtualKeyCode, &modifiers);
                if (virtualKeyCode == 126) {
                    /// Why did we put this if-statement??
                }
                
                /// Store in cache for later
                _hotKeyCache[@[@(virtualKeyCode), @(modifiers)]] = @(shk);
                
                /// Check if shk is what we're looking for.
                if (((CGKeyCode)virtualKeyCode) == keyCode) {
                    symbolicHotkey = @(shk);
                    break;
                }
                
                shk++;
            }
        }
        
        /// If symbolicHotKey found for keyCode and flags -> generate keyStr based on symbolicHotKey
        
        NSAttributedString *result = nil;
        
        if (symbolicHotkey != nil) {
            CGSSymbolicHotKey shk = (CGSSymbolicHotKey)symbolicHotkey.integerValue;
            result = [self getStringForSymbolicHotkey:shk flags:flags font:font];
        } else {
            assert(false);
        }
        
        return result;
    }
}

static NSMutableAttributedString *symbolStringWithModifierPrefix(NSString *modifierStr, NSAttributedString *symbolStr) {
    
    if (modifierStr == nil) {
        modifierStr = @"";
    }
    if (symbolStr == nil) {
        symbolStr = [[NSAttributedString alloc] initWithString:@""];
    }
    
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:modifierStr];
    [result appendAttributedString:symbolStr];
    
    return result;
}


/// vvv Moved this stuff to SFSymbolStrings.swift TODO: Remove

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
        
        NSString *join = NSLocalizedString(@"join-list", @"Note: This string joins elements in a list except the second-to-last and last one. || Note: The English string contains a space after the comma.");
        NSString *joinLast = NSLocalizedString(@"join-list.last", @"Note: This format string joins the second-to-last element and the last element in a list of items || Note: \"%1$@\" will be replaced by the second-to-last element, and \"%2$@\" will be replaced by the last element.");
        
        outString = stringf(joinLast, [firstStrings componentsJoinedByString:join], lastString);
    } else {
        assert(false);
    }
    
    /// On trimming whitespace: Not sure if trimming whitespace here is a good idea. If we always trim whitespace right before a string is displayed to the user this should be unnecessary.
    return outString.stringByTrimmingWhiteSpace;
}

/// Helper

NSString *stringByTrimmingLeadingWhiteSpace(NSString *str) {

    NSRange range = [str rangeOfString:@"^\\s*" options:NSRegularExpressionSearch];
    return [str stringByReplacingCharactersInRange:range withString:@""];
}

@end
