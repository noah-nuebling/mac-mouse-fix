//
// --------------------------------------------------------------------------
// main.m (Target: Mouse Fix Accomplice)
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Constants.h"
#import "HelperServices.h"
#import "Objects.h"

static int update(const char *installScript) {
    
    NSLog(@"Updating Helper...");
    
    // Instead of applescript i could use nsworkspace https://developer.apple.com/documentation/appkit/nsworkspace/3025774-requestauthorizationoftype?language=objc
    
    // Execute the install script (transfer the current settings to the updated bundle and then replace the current bundle with the updated one)
    NSDictionary *installErr = [NSDictionary new];
    NSAppleScript *installOSAObj = [[NSAppleScript alloc] initWithSource:[NSString stringWithCString:installScript encoding:NSUTF8StringEncoding]];
    if ([installOSAObj executeAndReturnError:&installErr]) {
        NSLog(@"successfully installed!");
    } else {
        NSLog(@"failed to install!");
        NSLog(@"%@", installErr);
        return 0;
    }
    
    // Kill system preferences
    NSArray *prefApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.systempreferences"];
    for (NSRunningApplication *prefApp in prefApps) {
        [prefApp terminate];
    }
    
    // Wait until system preferences terminates
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
    
    // Open the newly installed app
    NSURL *mainAppURL = [[[NSURL fileURLWithPath:NSProcessInfo.processInfo.arguments[0]] URLByAppendingPathComponent:@"/../../../.."] URLByStandardizingPath];
    [NSWorkspace.sharedWorkspace openURL:mainAppURL];
    
    return 0;
}
void reloadHelper() {
    // v Disabling helper is inconsistent without waiting
    // I think NSFileManager gives wrong values if this was triggered due to the app being relocated and we don't wait
    [NSThread sleepForTimeInterval:0.5];
    NSLog(@"Unloading Helper from launchd...");
    [HelperServices enableHelperAsUserAgent:NO];
    [NSThread sleepForTimeInterval:0.5]; // Waiting seems to help consistency
    NSLog(@"Reloading Helper into launchd...");
    [HelperServices enableHelperAsUserAgent:YES];
}
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        NSLog(@"Accomplice is sitting there steepling its fingers...");
        NSLog(@"Running Accomplice at path: %@", NSBundle.mainBundle.bundlePath); // The "bundlePath" is the enclosing folder of the executable
        
        const char *mode = argv[1];
        if ([@(mode) isEqualToString:kMFAccompliceModeArgumentUpdate]) {
            const char *installScript = argv[2];
            update(installScript);
        } else if ([@(mode) isEqualToString:kMFAccompliceModeArgumentReloadHelper]) {
            reloadHelper();
        }
    }
    
    return 0;
}
