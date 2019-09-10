//
//  main.m
//  Mouse Fix Updater
//
//  Created by Noah Nübling on 27.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
//#import "PrefPaneDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
//        NSLog(@"updater bundle: %@", [[NSBundle bundleForClass:self] bundlePath]);
        
        // instead of applescript i could use nsworkspace https://developer.apple.com/documentation/appkit/nsworkspace/3025774-requestauthorizationoftype?language=objc
        
        
        // execute the install script (transfer the current settings to the updated bundle and then replace the current bundle with the updated one)
        
        const char *installScript = argv[1];

        NSDictionary *installErr = [NSDictionary new];
        NSAppleScript *installOSAObj = [[NSAppleScript alloc] initWithSource:[NSString stringWithCString:installScript encoding:NSUTF8StringEncoding]];
        if ([installOSAObj executeAndReturnError:&installErr]) {
            NSLog(@"successfully installed!");
        } else {
            NSLog(@"failed to install!");
            NSLog(@"%@", installErr);
            return 0;
        }
    
        
        // kill system preferences
        
        NSArray *prefApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.systempreferences"];
        for (NSRunningApplication *prefApp in prefApps) {
            [prefApp terminate];
        }
        
        // wait until system preferences terminates

        int i = 0;
        NSArray *runningApps;
        do {
            [NSThread sleepForTimeInterval:0.01];
            runningApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.systempreferences"];
            i++;
        } while ([runningApps count] > 0);
        
        
        // kill the helper app
        // (the updated helper application will subsequently be launched by launchd due to the keepAlive attribute in mouse fix helper's launchd.plist)
        NSArray *helperApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.nuebling.mousefix.helper"];
        for (NSRunningApplication *helpApp in helperApps) {
            [helpApp terminate];
        }
        
        // open the newly installed prefpane
        
        NSURL *prefPaneURL = [[[NSURL fileURLWithPath:NSProcessInfo.processInfo.arguments[0]] URLByAppendingPathComponent:@"/../../../.."] URLByStandardizingPath];
        [NSWorkspace.sharedWorkspace openURL:prefPaneURL];
        
        
//        // run apple script to relaunch system preferences and navigate to the mouse fix prefPane
//
//        NSDictionary *restartErr = [NSDictionary new];
//        NSAppleScript *restartOSAObj = [[NSAppleScript alloc] initWithSource:@"tell application \"System Preferences\"\nactivate\nset the current pane to pane id \"com.nuebling.mousefix\"\nend tell"];
//        if ([restartOSAObj executeAndReturnError:&restartErr]) {
//            NSLog(@"successfully restarted!");
//        } else {
//            NSLog(@"failed to restart!");
//            NSLog(@"%@", restartErr);
//        }
        
    }
    
    return 0;
}
