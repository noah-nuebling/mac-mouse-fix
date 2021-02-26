//
// --------------------------------------------------------------------------
// main.m (Target: Mouse Fix Updater)
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Constants.h"

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
        
        
        // Kill the helper app
        // (the updated helper application will subsequently be launched by launchd due to the keepAlive attribute in Mac Mouse Fix helper's launchd.plist)
        
        NSArray *helperApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:kMFBundleIDHelper];
        for (NSRunningApplication *helpApp in helperApps) {
            [helpApp terminate];
        }
        
        // open the newly installed app
        
        NSURL *mainAppURL = [[[NSURL fileURLWithPath:NSProcessInfo.processInfo.arguments[0]] URLByAppendingPathComponent:@"/../../../.."] URLByStandardizingPath];
        [NSWorkspace.sharedWorkspace openURL:mainAppURL];
        
        
    }
    
    return 0;
}
