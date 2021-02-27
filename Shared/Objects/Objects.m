//
// --------------------------------------------------------------------------
// Objects.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Objects.h"
#import "Constants.h"
#import <Cocoa/Cocoa.h>

@implementation Objects

+ (NSBundle *)helperBundle {
    NSBundle *hhh;
    NSBundle *helperBundle;
    [self getBundleLocationsForMainApp:&hhh helper:&helperBundle];
    return helperBundle;
}
+ (NSBundle *)mainAppBundle {
    NSBundle *mainAppBundle;
    NSBundle *hhh;
    [self getBundleLocationsForMainApp:&mainAppBundle helper:&hhh];
    return mainAppBundle;
}
static NSURL *_MFApplicationSupportFolderURL;
+ (NSURL *)MFApplicationSupportFolderURL {
    return _MFApplicationSupportFolderURL;
}
static NSURL *_configURL;
+ (NSURL *)configURL {
    return _configURL;
}
+ (NSURL *)launchdPlistURL {
    NSString *launchdPlistRelativePathFromLibrary = [NSString stringWithFormat:@"LaunchAgents/%@.plist", kMFBundleIDHelper];
    NSURL *userLibURL = [NSFileManager.defaultManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask][0];
    return  [userLibURL URLByAppendingPathComponent:launchdPlistRelativePathFromLibrary];
}

+ (void)initialize {
    // Get appSupportURL & configURL
    NSURL *applicationSupportURL = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:NULL create:YES error:nil];
    _MFApplicationSupportFolderURL = [applicationSupportURL URLByAppendingPathComponent:self.mainAppBundle.bundleIdentifier];
    _configURL = [_MFApplicationSupportFolderURL URLByAppendingPathComponent:@"config.plist"];
}

+ (void)getBundleLocationsForMainApp:(NSBundle **)mainAppBundle helper:(NSBundle **)helperBundle {
//    NSBundle *thisBundle = [NSBundle bundleForClass:self.class];
//    if ([thisBundle.bundleIdentifier isEqualToString:kMFBundleIDApp]) {
//        NSString *helperPath = [thisBundle.bundleURL URLByAppendingPathComponent:kMFRelativeHelperAppPath].path;
//        *mainAppBundle = thisBundle;
//        *helperBundle = [NSBundle bundleWithPath:helperPath];
//    } else if ([thisBundle.bundleIdentifier isEqualToString:kMFBundleIDHelper]) {
//        NSString *mainAppPath = [thisBundle.bundleURL URLByAppendingPathComponent:kMFRelativeMainAppPathFromHelper].path;
//        *mainAppBundle = [NSBundle bundleWithPath:mainAppPath];
//        *helperBundle = thisBundle;
//    }
    // ^ I thought this would be very robust, but this stuff fails after moving the app.
    //  bundle.bundleURL wil still reports the pre-move location for some reason.
    //  NSWorkspace urlForBundleID works correctly though. I suspect that NSBundle bundleforBUndleID would work as well.
    //  But those functions are ambiguous when several apps witht the same BundleID are installed, which might be a problem while updating or so
    
    // v This stuff reacts to moving the app, but it's are ambiguous when several versions of the app are installed
    //      So I worry this might fail really hard in some situations, updates might be a problem, having different versions on the computer might be really bad too
    *mainAppBundle = nil;
    *helperBundle = nil;
    NSURL *appURL = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:kMFBundleIDApp];
    NSURL *helperURL = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:kMFBundleIDHelper];
    if (appURL) {
        *mainAppBundle = [NSBundle bundleWithURL:[NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:kMFBundleIDApp]];
    }
    if (helperURL) {
        *helperBundle = [NSBundle bundleWithURL:[NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:kMFBundleIDHelper]];
    }
    // v This doesn't work at all. I thought it would be the same as the NSWorkspace code above but it leads to immediate crash after launch. I think cause it returns nil or sth
//    *mainAppBundle = nil;
//    *helperBundle = nil;
//    *mainAppBundle = [NSBundle bundleWithIdentifier:kMFBundleIDApp];
//    *helperBundle = [NSBundle bundleWithIdentifier:kMFBundleIDHelper];
    
}

@end
