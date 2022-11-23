//
// --------------------------------------------------------------------------
// Locator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "Locator.h"
#import "Constants.h"
#import <Cocoa/Cocoa.h>
#import "SharedUtility.h"

@implementation Locator

#pragma mark - Interface
+ (NSInteger)bundleVersion {
    return [[self.mainAppBundle objectForInfoDictionaryKey:@"CFBundleVersion"] integerValue];
}
+ (NSString *)bundleVersionShort {
    return (NSString *)[self.mainAppBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}
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
+ (NSBundle *)helperOriginalBundle { /// Get pre-move location if moved while running
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
+ (NSUserDefaults *)defaults {
    
    /// This allows both the helper and the main app to write into the same user defaults
    
    /// Use config instead of defaults. There's no good reason to use defaults
    assert(false);
    
    if (runningMainApp()) {
        return NSUserDefaults.standardUserDefaults;
    } else if (runningHelper()) {
        return [[NSUserDefaults alloc] initWithSuiteName:kMFBundleIDApp];
    } else {
        assert(false);
    }
}

#pragma mark - Init

+ (void)initialize {
    
    if (self == Locator.class) {
        /// Get appSupportURL & configURL
        NSURL *applicationSupportURL = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:NULL create:YES error:nil];
        _MFApplicationSupportFolderURL = [applicationSupportURL URLByAppendingPathComponent:kMFBundleIDApp];
        _configURL = [_MFApplicationSupportFolderURL URLByAppendingPathComponent:@"config.plist"];
    }
}

#pragma mark - Core

/// This gets bundles at locations at which they were launched. These locations are incorrect if the app was moved while it or the helper is open
/// To get (best estimate of) up-to-date bundles, use `getBundlesForMainApp:helper`
+ (void)getOriginalBundlesForMainApp:(NSBundle *__autoreleasing *)mainAppBundle helper:(NSBundle *__autoreleasing *)helperBundle {
    NSBundle *thisBundle = NSBundle.mainBundle;
    
    if (runningMainApp()) {
        NSString *helperPath = [thisBundle.bundleURL URLByAppendingPathComponent:kMFRelativeHelperAppPath].path;
        *mainAppBundle = thisBundle;
        *helperBundle = [NSBundle bundleWithPath:helperPath];
    } else if (runningHelper()) {
        NSString *mainAppPath = [thisBundle.bundleURL URLByAppendingPathComponent:kMFRelativeMainAppPathFromHelperBundle].path;
        *mainAppBundle = [NSBundle bundleWithPath:mainAppPath];
        *helperBundle = thisBundle;
//    } else if (SharedUtility.runningAccomplice) {
//        /// Accomplice bundle doesn't have url only bundle path
//        NSString *mainAppPath =  [thisBundle.bundlePath stringByAppendingPathComponent:kMFRelativeMainAppPathFromAccompliceFolder];
//        NSString *helperPath = [mainAppPath stringByAppendingPathComponent:kMFRelativeHelperAppPath];
//        *mainAppBundle = [NSBundle bundleWithPath:mainAppPath];
//        *helperBundle = [NSBundle bundleWithPath:helperPath];
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
    
    /// Validate bundles
    
    if ((*mainAppBundle).executableURL == nil) {
        *mainAppBundle = nil;
    }
    if ((*helperBundle).executableURL == nil) {
        *helperBundle = nil;
    }
    
    /// v Attempt to fix
    ///  Store file reference URLs and fall back on last valid one if
    ///  the bundle obtained through the default method is invalid (that happens after the app is moved while helper is open)
    
    NSURL *mainAppFRURL = (*mainAppBundle).bundleURL.fileReferenceURL;
    
    if (mainAppFRURL == nil) {
     
        if (_lastValidMainAppFRURL != nil) {
            *mainAppBundle = [NSBundle bundleWithURL:_lastValidMainAppFRURL];
        }
        
        NSLog(@"((Found that mainApp bundle is invalid while retrieving app bundles. Resorting to last valid fileReferenceURLs to obtain bundle. This might mean the app moved or the helper is not embedded in a mainApp.))");
    } else {
        _lastValidMainAppFRURL = mainAppFRURL;
    }
    
    NSURL *helperFRURL = (*helperBundle).bundleURL.fileReferenceURL;
    if (helperFRURL == nil) {
     
        if (_lastValidHelperFRURL != nil) {
            *helperBundle = [NSBundle bundleWithURL:_lastValidHelperFRURL];
        }
        
        NSLog(@"((Found that helper bundle is invalid while retrieving app bundles. Resorting to last valid fileReferenceURLs to obtain bundle. This might mean the app moved.))");
    } else {
        _lastValidHelperFRURL = helperFRURL;
    }
}

@end
