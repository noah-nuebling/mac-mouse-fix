//
// --------------------------------------------------------------------------
// AppDelegate.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "AppDelegate.h"
#import "DeviceManager.h"
#import "LogitechButtonDiverter.h"

@interface AppDelegate ()
@property (strong) IBOutlet NSWindow *addedWindow;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    /// The effective entry point of this app is at [AccessibilityCheck load]
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [LogitechButtonDiverter restoreNativeBehavior];
}

@end
