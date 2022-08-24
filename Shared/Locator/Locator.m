//
// --------------------------------------------------------------------------
// Locator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Locator.h"
#import "Constants.h"
#import <Cocoa/Cocoa.h>
#import "SharedUtility.h"

@implementation Locator

+ (NSBundle *)helperBundle {
    NSBundle *hhh;
    NSBundle *helperBundle;
    [self getBundlesForMainApp:&hhh helper:&helperBundle];
    return helperBundle;
}
+ (NSBundle *)mainAppBundle {
    NSBundle *mainAppBundle;
    NSBundle *hhh;
    [self getBundlesForMainApp:&mainAppBundle helper:&hhh];
    return mainAppBundle;
}
/// Return bundle at the location at which the app was launched - even after the app has been moved while running
+ (NSBundle *)helperOriginalBundle { // Get pre-move location if moved while running
    NSBundle *hhh;
    NSBundle *helperBundle;
    [self getOriginalBundlesForMainApp:&hhh helper:&helperBundle];
    return helperBundle;
}
/// Return bundle at the location at which the app was launched - even after the app has been moved while running
+ (NSBundle *)mainAppOriginalBundle {
    NSBundle *mainAppBundle;
    NSBundle *hhh;
    [self getOriginalBundlesForMainApp:&mainAppBundle helper:&hhh];
    return mainAppBundle;
}
/// This seems to return the URL at which the app was launched - even after the app has been moved while running
+ (NSURL *)currentExecutableURL {
    return [NSURL fileURLWithPath:NSProcessInfo.processInfo.arguments[0]];
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
    
    if (self == Locator.class) {
        /// Get appSupportURL & configURL
        NSURL *applicationSupportURL = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:NULL create:YES error:nil];
        _MFApplicationSupportFolderURL = [applicationSupportURL URLByAppendingPathComponent:self.mainAppBundle.bundleIdentifier];
        _configURL = [_MFApplicationSupportFolderURL URLByAppendingPathComponent:@"config.plist"];
    }
}

/// This gets bundles at locations at which they were launched. These locations are incorrect if the app was moved while it or the helper is open
/// To get (best estimate of) up-to-date bundles, use `getBundlesForMainApp:helper`
+ (void)getOriginalBundlesForMainApp:(NSBundle *__autoreleasing *)mainAppBundle helper:(NSBundle *__autoreleasing *)helperBundle {
    NSBundle *thisBundle = NSBundle.mainBundle;
    
    if (SharedUtility.runningMainApp) {
        NSString *helperPath = [thisBundle.bundleURL URLByAppendingPathComponent:kMFRelativeHelperAppPath].path;
        *mainAppBundle = thisBundle;
        *helperBundle = [NSBundle bundleWithPath:helperPath];
    } else if (SharedUtility.runningHelper) {
        NSString *mainAppPath = [thisBundle.bundleURL URLByAppendingPathComponent:kMFRelativeMainAppPathFromHelperBundle].path;
        *mainAppBundle = [NSBundle bundleWithPath:mainAppPath];
        *helperBundle = thisBundle;
    } else if (SharedUtility.runningAccomplice) {
        // Accomplice bundle doesn't have url only bundle path
        NSString *mainAppPath =  [thisBundle.bundlePath stringByAppendingPathComponent:kMFRelativeMainAppPathFromAccompliceFolder];
        NSString *helperPath = [mainAppPath stringByAppendingPathComponent:kMFRelativeHelperAppPath];
        *mainAppBundle = [NSBundle bundleWithPath:mainAppPath];
        *helperBundle = [NSBundle bundleWithPath:helperPath];
    } else {
        [NSException raise:@"UnknownCallerException" format:@"No handling code for caller at: %@", thisBundle.bundlePath];
    }
}

static NSURL *_lastValidMainAppFRURL;
static NSURL *_lastValidHelperFRURL;
+ (void)getBundlesForMainApp:(NSBundle **)mainAppBundle helper:(NSBundle **)helperBundle {
    
    [self getOriginalBundlesForMainApp:mainAppBundle helper:helperBundle];
     /// ^ I thought this would be very robust, but this stuff fails after moving the app.
      /// NSBundle.mainBundle.bundleURL will still report the pre-move location for some reason.
    
    /// v Attempt to fix
    ///  Store file reference URLs and fall back on last valid one if
    ///  the bundle obtained through the default method is invalid (that happens after the app is moved while helper is open)
    NSURL *mainAppFRURL = (*mainAppBundle).bundleURL.fileReferenceURL;
    NSURL *helperFRURL = (*helperBundle).bundleURL.fileReferenceURL;
    if (!mainAppFRURL || !helperFRURL) {
        mainAppFRURL = _lastValidMainAppFRURL;
        helperFRURL = _lastValidHelperFRURL;
        DDLogInfo(@"((Found that app bundles are invalid while retrieving app bundles. Resorting to last valid fileReferenceURLs to obtain bundles. This probably means the app moved.))");
    } else {
        _lastValidMainAppFRURL = mainAppFRURL;
        _lastValidHelperFRURL = helperFRURL;
    }
    *mainAppBundle = [NSBundle bundleWithURL:mainAppFRURL];
    *helperBundle = [NSBundle bundleWithURL:helperFRURL];
}

@end
