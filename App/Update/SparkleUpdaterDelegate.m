//
// --------------------------------------------------------------------------
// SparkleUpdateDelegate.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SparkleUpdaterDelegate.h"
#import "AppDelegate.h"

// See https://sparkle-project.org/documentation/customization/

@implementation SparkleUpdaterDelegate


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
