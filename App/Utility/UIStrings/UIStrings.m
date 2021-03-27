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

///// Returns string representation of key, if it is printable.
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

+ (NSString *)stringForKeyCode:(NSInteger *)keyCode {
    MASShortcut *shortcut = [MASShortcut shortcutWithKeyCode:keyCode modifierFlags:0];
    NSString *keyStr = shortcut.keyCodeString;
    return keyStr;
}

@end
