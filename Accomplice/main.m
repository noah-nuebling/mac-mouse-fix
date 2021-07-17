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
#import "WannabePrefixHeader.h"

static int update(const char *installScript) {

    /// This is unused now because we're using Sparkle for updates
    
    DDLogInfo(@"Installing Mac Mouse Fix Update...");
    
    // Instead of applescript i could use nsworkspace https://developer.apple.com/documentation/appkit/nsworkspace/3025774-requestauthorizationoftype?language=objc
    // Note for debugging: Must clean build folder after running update in the build folder, otherwise Xcode will be confused and build frankensteins monster bundle
    
    // Execute the install script (replace the current bundle with the updated one)
    NSDictionary *installErr = [NSDictionary new];
    NSAppleScript *installOSAObj = [[NSAppleScript alloc] initWithSource:[NSString stringWithCString:installScript encoding:NSUTF8StringEncoding]];
    if ([installOSAObj executeAndReturnError:&installErr]) {
        DDLogInfo(@"Update successfully installed!");
    } else {
        DDLogInfo(@"Failed to install update with error: %@", installErr);
        return 0;
    }
    DDLogInfo(@"Finding and killing main app");
    // Find main app
    NSRunningApplication *mainApp;
    for (NSRunningApplication *app in [NSRunningApplication runningApplicationsWithBundleIdentifier:kMFBundleIDApp]) {
        if ([app.bundleURL isEqualTo:Objects.mainAppOriginalBundle.bundleURL]) { // Not sure if have to use `helperOriginalBundle` or `helperBundle`
            mainApp = app;
            break;
        }
    }
    DDLogInfo(@"Main app found at: %@", mainApp.bundleURL);
    // Kill main app and wait until it terminates
    do {
        DDLogInfo(@"Trying to terminate main app...");
        [mainApp terminate];
        [NSThread sleepForTimeInterval:2.0];
    } while (NO);
//    } while (![mainApp isTerminated]); // This doesn't work for some reason
    
    // ^ Since we're not waiting till the appis terminated, we need to make sure the app always quits quickly, or the updater won't be able to automatically restart the app
    //      TODO: We should probably try to find another method of waiting for the app to quit as it would make things a lot more robustl. (See method used in prefpane) This'll do for now. 
    
    DDLogInfo(@"Main app neutralized");
    
    DDLogInfo(@"Finding and killing Helper");
    // Find and kill helper
    // The updated helper application will subsequently be launched by launchd due to the keepAlive attribute in Mac Mouse Fix Helper's launchd.plist
    // This is (almost exactly) copied in HelperServices.m
    for (NSRunningApplication *app in [NSRunningApplication runningApplicationsWithBundleIdentifier:kMFBundleIDHelper]) {
        if ([app.bundleURL isEqualTo: Objects.helperOriginalBundle.bundleURL]) {
            [app terminate];
            DDLogInfo(@"Helper neutralized");
            break;
        }
    }
    
    // Open the newly installed main app
    NSURL *mainAppURL = [[Objects.currentExecutableURL URLByAppendingPathComponent:kMFRelativeMainAppPathFromAccomplice] URLByStandardizingPath];
    DDLogInfo(@"Opening updated app at: %@", mainAppURL);
    [NSWorkspace.sharedWorkspace openURL:mainAppURL];
    
    return 0;
}
void reloadHelper() {
    // v Disabling helper is inconsistent without waiting
    //      I think it's because NSFileManager gives wrong values for a short time after the app has been relocated (this is called as a result of the app being relocated)
    [NSThread sleepForTimeInterval:0.5];
    DDLogInfo(@"Unloading Helper from launchd...");
    [HelperServices enableHelperAsUserAgent:NO];
    [NSThread sleepForTimeInterval:0.5]; // Waiting seems to help consistency
    DDLogInfo(@"Reloading Helper into launchd...");
    [HelperServices enableHelperAsUserAgent:YES];
}
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        DDLogInfo(@"Accomplice is sitting there steepling its fingers...");
        DDLogInfo(@"Running Accomplice at path: %@", NSBundle.mainBundle.bundlePath); // The "bundlePath" is the enclosing folder of the executable
        
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
