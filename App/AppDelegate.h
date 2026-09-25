//
// --------------------------------------------------------------------------
// AppDelegate.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <PreferencePanes/PreferencePanes.h>
//#import "MoreSheet.h"
#import "OverridePanel.h"
#import "RemapTableController.h"
#import "RemapTableView.h"
#import "AppState.h"

@interface AppDelegate : NSObject<NSApplicationDelegate, NSWindowDelegate>

+ (AppDelegate *)instance;

/// Import and export user-configurable settings. License, state, and internal constants are never transferred.
- (IBAction)importSettings:(nullable id)sender;
- (IBAction)exportSettings:(nullable id)sender;

@end
