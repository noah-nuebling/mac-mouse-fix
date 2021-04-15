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
#import "RemapTableController.h"
#import "MFTableView.h"

@interface AppDelegate : NSObject<NSApplicationDelegate, NSWindowDelegate>
@property (weak, readwrite) IBOutlet MFTableView *remapsTable; // 
@property (weak, readonly) RemapTableController *remapTableController;
+ (AppDelegate *)instance;
+ (NSWindow *)mainWindow;
+ (void)handleHelperEnabledMessage;
- (void)stopRemoveAccOverlayTimer;
@end
