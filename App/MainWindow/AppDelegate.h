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

@interface AppDelegate : NSObject<NSApplicationDelegate, NSWindowDelegate>
@property (weak) IBOutlet NSTableView *remapsTable;
+ (AppDelegate *)instance;
+ (NSWindow *)mainWindow;
+ (RemapTableController *)remapTableController;
- (void)stopRemoveAccOverlayTimer;
@end
