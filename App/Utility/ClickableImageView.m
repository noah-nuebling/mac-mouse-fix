//
// --------------------------------------------------------------------------
// ClickableImageView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ClickableImageView.h"
#import "ConfigFileInterface_App.h"
#import "NSArray+Additions.h"
#import "Objects.h"

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
            [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[Objects.configURL]];
        } else if ([_actionString isEqualToString:@"reveal-helper"]) {
            [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[Objects.helperBundle.bundleURL]];
        }
    }
}

@end
