//
// --------------------------------------------------------------------------
// UIStrings.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "UIStrings.h"
#import <Carbon/Carbon.h>
#import "MASShortcut.h"
#import "CGSHotKeys.h"
#import "SharedUtility.h"

@implementation UIStrings

/// Other code for obtaining UI strings found in RemapTableController
/// Function for getting extended button string for tooltips found in RemapTableController

+ (NSString *)stringForKeyCode:(NSInteger)keyCode {
    
    /// Get string from MASShortcut
    
    MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:keyCode modifierFlags:0];
    NSString *keyStr = shortcut.keyCodeString;
    
    
    return keyStr;
}

+ (NSString *)getButtonString:(MFMouseButtonNumber)buttonNumber {
    NSDictionary *buttonNumberToUIString = @{
        @1: @"Primary Button",
        @2: @"Secondary Button",
        @3: @"Middle Button",
    };
    NSString *buttonStr = buttonNumberToUIString[@(buttonNumber)];
    if (!buttonStr) {
        buttonStr = [NSString stringWithFormat:@"Button %@", @(buttonNumber)];
    }
    return buttonStr;
}

+ (NSString *)getButtonStringToolTip:(MFMouseButtonNumber)buttonNumber {
    NSDictionary *buttonNumberToUIString = @{
        @1: @"the Primary Mouse Button (also called the Left Mouse Button or Mouse Button 1)",
        @2: @"the Secondary Mouse Button (also called the Right Mouse Button or Mouse Button 2)",
        @3: @"the Middle Mouse Button (also called the Scroll Wheel Button or Mouse Button 3)",
    };
    NSString *buttonStr = buttonNumberToUIString[@(buttonNumber)];
    if (!buttonStr) {
        buttonStr = [NSString stringWithFormat:@"Mouse Button %@", @(buttonNumber)];
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
    NSString *kb = @"";
    CGEventFlags f = flags;
    kb = [NSString stringWithFormat:@"%@%@%@%@",
          (f & kCGEventFlagMaskControl ?    @"Control (^)-" : @""),
          (f & kCGEventFlagMaskAlternate ?  @"Option (⌥)-" : @""),
          (f & kCGEventFlagMaskShift ?      @"Shift (⇧)-" : @""),
          (f & kCGEventFlagMaskCommand ?    @"Command (⌘)-" : @"")];
    if (kb.length > 0) {
        kb = [kb substringToIndex:kb.length-1]; // Delete trailing dash
        NSArray *stringArray = [kb componentsSeparatedByString:@"-"];
        kb = [self naturalLanguageListFromStringArray:stringArray];
        kb = [@"Hold " stringByAppendingString:kb];
    }
    
    return kb;
}

static NSMutableDictionary *_hotKeyCache;
static CGSSymbolicHotKey _highestSymbolicHotKeyInCache = 0;

+ (NSAttributedString *)getStringForKeyCode:(CGKeyCode)keyCode flags:(CGEventFlags)flags {
    
    /// Get key string
    NSString *keyStr = [UIStrings stringForKeyCode:keyCode];
    
    if (![keyStr isEqual:@""]) {
        
        NSString *flagsStr = [UIStrings getKeyboardModifierString:flags];
        
        NSString *combinedString = stringf(@"%@%@", flagsStr, keyStr);
        
        return [[NSAttributedString alloc] initWithString:combinedString];
        
    } else {
        /// Couldn't retrieve keyStr using MAS
        
        NSAttributedString *keyStr;
        
        /// Fallback for apple proprietary function keys
        
        if (flags != 0) {
            /// This is weird
            NSLog(@"Weird flag state when trying to get keyboard string");
        }
        
        /// Init
        if (!_hotKeyCache) {
            _hotKeyCache = [NSMutableDictionary dictionary];
        }
        
        /// Get shk
        NSNumber *symbolicHotkey;
        
        /// Try to retrieve from cache
        symbolicHotkey = _hotKeyCache[@(keyCode)][@(flags)];
        
        ///  Search new value
        if (symbolicHotkey == nil) {
            
            CGSSymbolicHotKey h = _highestSymbolicHotKeyInCache;
            while (h < 512) { /// 512 is arbitrary
                unichar keyEquivalent;
                CGKeyCode virtualKeyCode;
                CGSModifierFlags modifiers;
                CGSGetSymbolicHotKeyValue(h, &keyEquivalent, &virtualKeyCode, &modifiers);
                if (virtualKeyCode == 126) {
                    NSLog(@"");
                }
                if (_hotKeyCache[@(virtualKeyCode)] == nil) {
                    _hotKeyCache[@(virtualKeyCode)] = [NSMutableDictionary dictionary];
                }
                _hotKeyCache[@(virtualKeyCode)][@(modifiers)] = @(h);
                if (((CGKeyCode)virtualKeyCode) == keyCode) {
                    symbolicHotkey = @(h);
                    break;
                }
                h++;
            }
        }
        
        /// If found, generate keyStr based on shk
        
        if (symbolicHotkey != nil) {
            CGSSymbolicHotKey shk = (CGSSymbolicHotKey)symbolicHotkey.integerValue;
            NSString *symbolName = @"questionmark.square";
            NSString *stringFallback = @"<Key without description>";
            
            /// Debug
            NSLog(@"shk: %d", shk);
            
            if (shk == kMFFunctionKeySHKMissionControl) {
                symbolName = @"rectangle.3.group";
                stringFallback = @"<Mission Control key>";
            } else if (shk == kMFFunctionKeySHKDictation) {
                symbolName = @"mic";
                stringFallback = @"<Dictation key>";
            } else if (shk == kMFFunctionKeySHKSpotlight) {
                symbolName = @"magnifyingglass";
                stringFallback = @"<Spotlight key>";
            } else if (shk == kMFFunctionKeySHKDoNotDisturb) {
                symbolName = @"moon";
                stringFallback = @"<Do Not Disturb key>";
            } else if (shk == kMFFunctionKeySHKSwitchKeyboard) {
                symbolName = @"globe";
                stringFallback = @"<Emoji Picker key>";
            }
            
            /// Get symbol
            NSImage *symbol = [NSImage imageNamed:symbolName];
            NSTextAttachment *symbolAttachment = [[NSTextAttachment alloc] init];
            symbol.accessibilityDescription = stringFallback;
            symbolAttachment.image = symbol;
            keyStr = [NSAttributedString attributedStringWithAttachment:symbolAttachment];
        }
        
        /// Get modStr
        ///     This should be necessary - we do this just for debugging
        
        NSString *flagsStr = [UIStrings getKeyboardModifierString:flags];
        
        /// Append keyStr and modStr
        
        NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:flagsStr];
        [result appendAttributedString:keyStr];
        
        return result;
    }
}

+ (NSString *)naturalLanguageListFromStringArray:(NSArray<NSString *> *)stringArray {
    
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
        
        outString = [[firstStrings componentsJoinedByString:@", "] stringByAppendingFormat:@" and %@", lastString];
    }
    
    return outString;
}

@end
