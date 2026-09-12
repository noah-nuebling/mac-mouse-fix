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

@interface AppDelegate ()
@property (strong) IBOutlet NSWindow *addedWindow;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    /// The effective entry point of this app is at [AccessibilityCheck load]
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    [DeviceManager deconfigureDevicesWithCompletion:^(__unused BOOL completedBeforeDeadline) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [sender replyToApplicationShouldTerminate:YES];
        });
    }];
    return NSTerminateLater;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    /// This doesn't seem to get called when the Helper is terminated through launchd.
    /// Instead we catch the `SIGTERM` UNIX signal.
}

@end
