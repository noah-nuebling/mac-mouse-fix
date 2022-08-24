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
#import "RemapTableView.h"
#import "AppState.h"

@interface AppDelegate : NSObject<NSApplicationDelegate, NSWindowDelegate>
//@property (weak, readwrite) IBOutlet RemapTableView *remapsTable; // 
//@property (weak, readonly) RemapTableController *remapTableController;

+ (AppDelegate *)instance;

/// v Old MMF2 stuff that is handled differently now.

//+ (NSWindow *)mainWindow;
//+ (void)handleHelperEnabledMessage;
//- (void)handleAccessibilityDisabledMessage;
@end
