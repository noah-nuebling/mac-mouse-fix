//
// --------------------------------------------------------------------------
// UIStrings.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "UIStrings.h"

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

@end
