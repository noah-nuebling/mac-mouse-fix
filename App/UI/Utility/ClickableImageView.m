//
// --------------------------------------------------------------------------
// ClickableImageView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "ClickableImageView.h"
#import "Config.h"
#import "NSArray+Additions.h"
#import "Locator.h"

IB_DESIGNABLE
@interface ClickableImageView ()

@property IBInspectable NSString *modifiers;
@property IBInspectable NSString *actionString;

@end

@implementation ClickableImageView


//static NSArray *modifiersStringToFlagArray(NSString *modifiers) {
//    NSArray *stringArray = [[modifiers stringByReplacingOccurrencesOfString:@" " withString:@""] componentsSeparatedByString:@","];
//    NSArray *modArray = [stringArray map:^id _Nonnull(id  _Nonnull obj) {
//        return modifierStringToFlag[obj];
//    }];
//    return modArray;
//}

NSArray *_requiredModifierFlags;

- (void)awakeFromNib {
    NSDictionary *modifierStringToFlag = @{
        @"shift": [NSNumber numberWithUnsignedInteger:NSEventModifierFlagShift],
        @"command": [NSNumber numberWithUnsignedInteger:NSEventModifierFlagCommand],
        @"option": [NSNumber numberWithUnsignedInteger:NSEventModifierFlagOption],
        @"control": [NSNumber numberWithUnsignedInteger:NSEventModifierFlagControl],
    };
    
    NSArray *modStringArray = [[_modifiers stringByReplacingOccurrencesOfString:@" " withString:@""] componentsSeparatedByString:@","];
    NSArray *modFlagArray = [modStringArray map:^id _Nonnull(id  _Nonnull obj) {
        return modifierStringToFlag[obj];
    }];
    _requiredModifierFlags = modFlagArray;
}
    
- (void)mouseDown:(NSEvent *)event {
    
    BOOL matchesAllRequired = YES;
    
    for (NSNumber *rf in _requiredModifierFlags) {
        if ((rf.unsignedIntegerValue & event.modifierFlags) == 0) {
            matchesAllRequired = NO;
        }
    }
    
    if (matchesAllRequired) {
        if ([_actionString isEqualToString:@"reveal-config"]) {
            [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[Locator.configURL]];
        } else if ([_actionString isEqualToString:@"reveal-helper"]) {
            [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[Locator.helperBundle.bundleURL]];
        }
    }
}

@end
