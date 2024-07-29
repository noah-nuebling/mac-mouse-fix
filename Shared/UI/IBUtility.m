//
// --------------------------------------------------------------------------
// IBUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "IBUtility.h"

@implementation IBUtility

/// Explanation: 
/// Sometimes we want to specify character in interface builder that can't be typed on a keyboard. For example kEscapeCharCode to define a keyEquivalent for the esc key.
/// The mappings here let you simply type `escape` in IB and have our code resolve it to the right char.

+ (NSEventModifierFlags)modifierMaskForLiteral:(NSString *)literalString {
    
    /// Parse a string like `command` or `control, shift, command` into NSEventModifierFlags.
    
    NSArray *splitFlagStrings = [[literalString stringByReplacingOccurrencesOfString:@" " withString:@""] componentsSeparatedByString:@","];
    
    NSEventModifierFlags mask = 0;
    for (NSString *flagString in splitFlagStrings) {
        NSEventModifierFlags flag = [self _modifierFlagForLiteral:flagString];
        mask = mask | flag;
    }
    
    return mask;
}

+ (NSEventModifierFlags)_modifierFlagForLiteral:(NSString *)literalString {
    
    /// Returns 0 or an NSEventModifierFlag
    
    literalString = [literalString lowercaseString];
    
    const NSDictionary *map = @{
        @"shift": @(NSEventModifierFlagShift),
        @"command": @(NSEventModifierFlagCommand),
        @"option": @(NSEventModifierFlagOption),
        @"control": @(NSEventModifierFlagControl),
    };
    NSNumber *resultNS = map[literalString];
    
    if (resultNS == nil) return 0;
    else return [resultNS intValue];
}

+ (NSString *)keyCharForLiteral:(NSString *)literalString {
    
    ///
    /// Returns the charCode for keyboard keys that can't easily be typed.
    ///     Made for easily setting NSResponder's `keyEquivalent` to keys such as `escape`.
    
    literalString = [literalString lowercaseString];
    
    const NSDictionary *map = @{
        @"return": @(kReturnCharCode),
        @"enter": @(kEnterCharCode),    /// Use return instead. Return is standard on macOS keyboard. Enter can only by typed by hitting function+return on a MacBook keyboard.
        @"escape": @(kEscapeCharCode),
        @"space": @(kSpaceCharCode),
        @"delete": @(kDeleteCharCode),
        @"leftarrow": @(kLeftArrowCharCode),
        @"rightarrow": @(kRightArrowCharCode),
        @"uparrow": @(kUpArrowCharCode),
        @"downarrow": @(kDownArrowCharCode),
    };
    int resultChar = [map[literalString] intValue];
    
    if (resultChar == 0) return nil;
    else return [NSString stringWithFormat:@"%c", resultChar];
}

@end
