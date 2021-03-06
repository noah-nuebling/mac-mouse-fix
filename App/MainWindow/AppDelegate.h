//
// --------------------------------------------------------------------------
// AppDelegate.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <PreferencePanes/PreferencePanes.h>
#import "MoreSheet.h"
#import "OverridePanel.h"

@interface AppDelegate : NSObject<NSApplicationDelegate, NSWindowDelegate>
+ (AppDelegate *)instance;
+ (NSWindow *)mainWindow;
- (void)stopRemoveAccOverlayTimer;
@end
