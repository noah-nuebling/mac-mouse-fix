//
// --------------------------------------------------------------------------
// ClickableImageView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ClickableImageView.h"
#import "Config.h"
#import "NSArray+Additions.h"
#import "Locator.h"
#import "IBUtility.h"

IB_DESIGNABLE
@interface ClickableImageView ()

@property IBInspectable NSString *modifiers;
@property IBInspectable NSString *actionString;

@end

@implementation ClickableImageView {
    NSEventModifierFlags _modifierMask;
}

- (void)awakeFromNib {
    _modifierMask = [IBUtility modifierMaskForLiteral:_modifiers];
}
    
- (void)mouseDown:(NSEvent *)event {
    
    BOOL eventFlagsAreSuperSetOfMask = (event.modifierFlags & _modifierMask) == _modifierMask;
    
    if (eventFlagsAreSuperSetOfMask) {
        if ([_actionString isEqualToString:@"reveal-config"]) {
            [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[Locator.configURL]];
        } else if ([_actionString isEqualToString:@"reveal-helper"]) {
            [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[Locator.helperBundle.bundleURL]];
        }
    }
}

@end
