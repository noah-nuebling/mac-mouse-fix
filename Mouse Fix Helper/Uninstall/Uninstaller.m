//
//  Uninstaller.m
//  Mouse Fix Helper
//
//  Created by Noah Nübling on 10.09.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import "Uninstaller.h"
#import "../Utility/Utility_HelperApp.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@implementation Uninstaller

+ (void)load {
    [self setupFSMonitor];
}

+ (void)setupFSMonitor {
    
    NSArray<NSURL *> *prefURLs = [NSFileManager.defaultManager URLsForDirectory:NSPreferencePanesDirectory inDomains:NSLocalDomainMask | NSUserDomainMask];
    NSMutableArray<NSString *> *prefPaths = [NSMutableArray array];
    for (NSURL *u in prefURLs) {
        [prefPaths addObject:u.path];
    }
    FSEventStreamRef stream = FSEventStreamCreate(kCFAllocatorDefault, Handle_FSCallback, NULL, (__bridge CFArrayRef) prefPaths, kFSEventStreamEventIdSinceNow, 5, kFSEventStreamCreateFlagIgnoreSelf ^ kFSEventStreamCreateFlagUseCFTypes);
    
    FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    FSEventStreamStart(stream);
    
}

void Handle_FSCallback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    
    NSArray *prefPanesFolder = [NSFileManager.defaultManager contentsOfDirectoryAtPath:[[Utility_HelperApp prefPaneBundle].bundlePath stringByDeletingLastPathComponent] error:NULL];
    
    if (![prefPanesFolder containsObject:@"Mouse Fix.prefPane"]) {
        
        // TODO: implement "Updater" or maybe "Helper Services" Command Line Tool, so you can actually delete the launchd.plist file when uninstalling through system preferences, and so you don't have to duplicate the Helper Services Code
//        [HelperServices_HelperApp enableHelperAsUserAgent:NO];
        
        
        NSLog(@"helperBundleee: %@", [Utility_HelperApp helperBundle]);
        NSLog(@"prefBundleee: %@", [Utility_HelperApp prefPaneBundle]);
        
//        NSURL *executableURL = [[Utility_HelperApp prefPaneBundle].bundleURL URLByAppendingPathComponent:@"/Contents/Library/LaunchServices/Mouse Fix Launchd Interface"];
        NSURL *executableURL = [[NSFileManager.defaultManager homeDirectoryForCurrentUser] URLByAppendingPathComponent:@"Trash/Mouse Fix.prefPane/Contents/Library/LaunchServices/Mouse Fix Launchd Interface"];
        NSError *launchTaskErr;
        if (@available(macOS 10.13, *)) {
            NSLog(@"LAUNCHTASK");
            NSLog(@"executableURL: %@", launchTaskErr);

        [NSTask launchedTaskWithExecutableURL:executableURL arguments:@[@"disable"] error:&launchTaskErr terminationHandler:^(NSTask *task) {
            NSLog(@"Mouse Fox Launchd Interface launched");
        }];
        } else {
            // Fallback on earlier versions
        }
        if (launchTaskErr) {
            NSLog(@"Error launching Mouse Fix Launchd Interface: %@", launchTaskErr);
        }
        
    }
    
}


@end
