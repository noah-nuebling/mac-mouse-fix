//
// --------------------------------------------------------------------------
// Uninstaller.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Uninstaller.h"
#import "HelperServices_HelperApp.h"
#import "../Utility/Utility_HelperApp.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@implementation Uninstaller

+ (void)load {
    [self setupFSMonitor];
}


/// Monitor possible prefpane install locations.
+ (void)setupFSMonitor {
    
    NSArray<NSURL *> *prefURLs = [NSFileManager.defaultManager URLsForDirectory:NSPreferencePanesDirectory inDomains:NSLocalDomainMask | NSUserDomainMask];
    NSMutableArray<NSString *> *prefPaths = [NSMutableArray array];
    for (NSURL *u in prefURLs) {
        [prefPaths addObject:u.path];
    }
    FSEventStreamRef stream = FSEventStreamCreate(kCFAllocatorDefault, Handle_FSCallback, NULL, (__bridge CFArrayRef) prefPaths, kFSEventStreamEventIdSinceNow, 1, kFSEventStreamCreateFlagIgnoreSelf ^ kFSEventStreamCreateFlagUseCFTypes);
    
    FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    FSEventStreamStart(stream);
    
}

void Handle_FSCallback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    NSArray *contents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:[[Utility_HelperApp prefPaneBundle].bundlePath stringByDeletingLastPathComponent] error:NULL];
    
    if (![contents containsObject:@"Mouse Fix.prefPane"]) {
        uninstall();
    }
    
}

void uninstall() {
    [HelperServices_HelperApp enableHelperAsUserAgent:NO];
}

@end
