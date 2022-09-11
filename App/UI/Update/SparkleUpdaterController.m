//
// --------------------------------------------------------------------------
// SparkleUpdateDelegate.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "SparkleUpdaterController.h"
#import "AppDelegate.h"
#import "SharedUtility.h"
#import "Locator.h"

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
    
    DDLogInfo(@"About to install update");
    
    [MoreSheet.instance end]; // Close more sheet so it doesn't block popup
}

- (void)updaterDidRelaunchApplication:(SUUpdater *)updater {
    
    DDLogInfo(@"Has been launched by Sparkle Updater");
    
    // Log the fact that updater launched the application in appState()
    
    appState().updaterDidRelaunchApplication = YES;
    // ^ We use this from `AppDelegate - applicationDidFinishLaunching`.
    
    // Find and kill helper
    
    // The updated helper application will subsequently be launched by launchd due to the keepAlive attribute in Mac Mouse Fix Helper's launchd.plist
    // It might be more robust and simple to find and kill any strange helpers *whenever* the app starts, but this should work, too.
    // This is untested but it's copied over from the old Updating mechanism, so I trust that it works in this context, too.
    BOOL helperNeutralized = NO;
    for (NSRunningApplication *app in [NSRunningApplication runningApplicationsWithBundleIdentifier:kMFBundleIDHelper]) {
        if ([app.bundleURL isEqualTo: Locator.helperOriginalBundle.bundleURL]) {
            [app terminate];
            helperNeutralized = YES;
            break;
        }
    }
    
    if (helperNeutralized) {
        DDLogInfo(@"Helper has been neutralized");
    } else {
        DDLogInfo(@"No helper found to neutralize");
    }
    
}



@end
