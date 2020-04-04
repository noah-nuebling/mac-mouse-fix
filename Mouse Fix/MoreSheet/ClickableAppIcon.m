//
// --------------------------------------------------------------------------
// ClickableImageView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ClickableAppIcon.h"
#import "ConfigFileInterface_PrefPane.h"

@implementation ClickableAppIcon

/// Command-shift clicking the app icon in the more sheet will reveal th config.plist file in the finder.
- (void)mouseDown:(NSEvent *)event {
    NSEventModifierFlags flags = [event modifierFlags];
    if (flags & NSEventModifierFlagCommand && flags & NSEventModifierFlagShift) {
        
        [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[ConfigFileInterface_PrefPane.configURL]];
    }
}

@end
