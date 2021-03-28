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

@implementation UIStrings

/// Other code for obtaining UI strings found in RemapTableController
/// Function for getting extended button string for tooltips found in RemapTableController

+ (NSString *)stringForKeyCode:(NSInteger)keyCode {
    MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:keyCode modifierFlags:0];
    NSString *keyStr = shortcut.keyCodeString;
    return keyStr;
}

+ (NSString *)getButtonString:(int)buttonNumber {
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

+ (NSString *)getButtonStringToolTip:(int)buttonNumber {
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
        // TODO: Use our function for creating proper natural language lists (with commas as well as 'and' before the last element)
        kb = [kb substringToIndex:kb.length-1]; // Delete trailing dash
//        kb = [kb stringByAppendingString:@" "]; // Append trailing space
        kb = [kb stringByReplacingOccurrencesOfString:@"-" withString:@" and "];
        kb = [@"Hold " stringByAppendingString:kb];
    }
    
    return kb;
}

// Arguments are NSNumber so we can throw in values from dataModel and get valid results if they are nil. This is probably a bad solution.
+ (NSString *)getStringForKeyCode:(CGKeyCode)keyCode flags:(CGEventFlags)flags {
    NSString *captureFieldContent;
    // Get key string
    NSString *keyStr = [UIStrings stringForKeyCode:keyCode];
    // Get modifier string
    NSString *flagsStr = [UIStrings getKeyboardModifierString:flags];
    captureFieldContent = [NSString stringWithFormat:@"%@%@",flagsStr, keyStr];
    return captureFieldContent;
}

///// Returns string representation of key, if it is printable.
/// Doesn't work properly
///// Source: https://stackoverflow.com/a/12548163/10601702
//+ (NSString *)stringForKey:(CGKeyCode)keyCode
//{
//    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
//    CFDataRef layoutData =
//        TISGetInputSourceProperty(currentKeyboard,
//                                  kTISPropertyUnicodeKeyLayoutData);
//    const UCKeyboardLayout *keyboardLayout =
//        (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
//
//    UInt32 keysDown = 0;
//    UniChar chars[4];
//    UniCharCount realLength;
//
//    UCKeyTranslate(keyboardLayout,
//                   keyCode,
//                   kUCKeyActionDisplay,
//                   0,
//                   LMGetKbdType(),
//                   kUCKeyTranslateNoDeadKeysBit,
//                   &keysDown,
//                   sizeof(chars) / sizeof(chars[0]),
//                   &realLength,
//                   chars);
//    CFRelease(currentKeyboard);
//
//    CFStringRef outStrCF = CFStringCreateWithCharacters(kCFAllocatorDefault, chars, 1);
//
//    return (__bridge_transfer NSString *)outStrCF;
//}

@end
