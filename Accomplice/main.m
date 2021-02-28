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
    
    // Execute the install script (replace the current bundle with the updated one)
    NSDictionary *installErr = [NSDictionary new];
    NSAppleScript *installOSAObj = [[NSAppleScript alloc] initWithSource:[NSString stringWithCString:installScript encoding:NSUTF8StringEncoding]];
    if ([installOSAObj executeAndReturnError:&installErr]) {
        NSLog(@"Update successfully installed!");
    } else {
        NSLog(@"Failed to install update with error: %@", installErr);
        return 0;
    }
    // Find main app
    NSRunningApplication *mainApp;
    for (NSRunningApplication *app in [NSRunningApplication runningApplicationsWithBundleIdentifier:kMFBundleIDApp]) {
        if ([app.bundleURL isEqualTo:Objects.mainAppOriginalBundle.bundleURL]) { // Not sure if have to use `helperOriginalBundle` or `helperBundle`
            mainApp = app;
            break;
        }
    }
    // Kill main app and wait until it terminates
    while (!mainApp.isTerminated) {
        [mainApp terminate];
        [NSThread sleepForTimeInterval:0.01];
    }
    // Find and kill helper
    // The updated helper application will subsequently be launched by launchd due to the keepAlive attribute in Mac Mouse Fix Helper's launchd.plist
    for (NSRunningApplication *app in [NSRunningApplication runningApplicationsWithBundleIdentifier:kMFBundleIDHelper]) {
        if ([app.bundleURL isEqualTo: Objects.helperOriginalBundle.bundleURL]) {
            [app terminate];
            break;
        }
    }
    // Open the newly installed main app
    NSURL *mainAppURL = [[Objects.currentExecutableURL URLByAppendingPathComponent:kMFRelativeMainAppPathFromAccomplice] URLByStandardizingPath];
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
        if ([@(mode) isEqualToString:kMFAccompliceModeUpdate]) {
            const char *installScript = argv[2];
            update(installScript);
        } else if ([@(mode) isEqualToString:kMFAccompliceModeReloadHelper]) {
            reloadHelper();
        }
    }
    
    return 0;
}
