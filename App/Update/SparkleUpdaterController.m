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

// See https://sparkle-project.org/documentation/customization/

@implementation SparkleUpdaterController

+ (void)enablePrereleaseChannel:(BOOL)pre {
    if (pre) {
        SUUpdater.sharedUpdater.feedURL = [NSURL URLWithString:fstring(@"%@/%@", kMFUpdateFeedRepoAddressRaw, kSUFeedURLSubBeta)];
    } else {
        SUUpdater.sharedUpdater.feedURL = [NSURL URLWithString:fstring(@"%@/%@", kMFUpdateFeedRepoAddressRaw, kSUFeedURLSub)];
    }
}

- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SUUpdater *)updater {
    return NO;
}

// We use this from `AppDelegate - applicationDidFinishLaunching`.
//  This needs to be called before that code for it to work. Not sure that's the case.
- (void)updaterDidRelaunchApplication:(SUUpdater *)updater {
    
    NSLog(@"Launched by Sparkle Updater");
    
    appState().updaterDidRelaunchApplication = YES;
}


@end
