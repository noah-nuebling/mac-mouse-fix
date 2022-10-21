//
// --------------------------------------------------------------------------
// SparkleUpdateDelegate.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SparkleUpdaterController.h"
#import "AppDelegate.h"
#import "SharedUtility.h"
#import "Locator.h"
#import "HelperServices.h"

// See https://sparkle-project.org/documentation/customization/

@implementation SparkleUpdaterController

+ (void)enablePrereleaseChannel:(BOOL)pre {
    if (pre) {
        SUUpdater.sharedUpdater.feedURL = [NSURL URLWithString:stringf(@"%@/%@", kMFUpdateFeedRepoAddressRaw, kSUFeedURLSubBeta)];
    } else {
        SUUpdater.sharedUpdater.feedURL = [NSURL URLWithString:stringf(@"%@/%@", kMFUpdateFeedRepoAddressRaw, kSUFeedURLSub)];
    }
}

- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SUUpdater *)updater {
    // We don't use Sparkles automatic scheduled updates anyways. Instead we simply check every time the app is started. So what the user chooses in this prompt doesn't make difference anyways. So were disabling the prompts.
    return NO;
}

- (void)updater:(SUUpdater *)updater willInstallUpdate:(SUAppcastItem *)update {
    
    NSLog(@"About to install update");
    
    [MoreSheet.instance end]; // Close more sheet so it doesn't block popup
}

- (void)updaterDidRelaunchApplication:(SUUpdater *)updater {
    
    NSLog(@"Has been launched by Sparkle Updater");
    
    /// Log the fact that updater launched the application in appState()
    ///     We use this from `AppDelegate - applicationDidFinishLaunching`.
    appState().updaterDidRelaunchApplication = YES;
    
    /// Kill helper
    /// It might be more robust and simple to find and kill any strange helpers *whenever* the app starts, but this should work, too.
    [HelperServices killAllHelpers];
    
}



@end
