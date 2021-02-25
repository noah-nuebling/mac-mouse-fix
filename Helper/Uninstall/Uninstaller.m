//
// --------------------------------------------------------------------------
// Uninstaller.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Uninstaller.h"
#import "HelperServices_HelperApp.h"
#import "../Utility/Utility_HelperApp.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import "Constants.h"

@implementation Uninstaller

+ (void)load {
    [self setupFSMonitor];
}


/// Monitor possible application install locations.
+ (void)setupFSMonitor {
    
    NSArray<NSURL *> *appPaths = [NSFileManager.defaultManager URLsForDirectory:NSAllApplicationsDirectory inDomains:NSLocalDomainMask | NSUserDomainMask];
    NSMutableArray<NSString *> *appURLS = [NSMutableArray array];
    for (NSURL *u in appPaths) {
        [appURLS addObject:u.path];
    }
    FSEventStreamRef stream = FSEventStreamCreate(kCFAllocatorDefault, Handle_FSCallback, NULL, (__bridge CFArrayRef) appURLS, kFSEventStreamEventIdSinceNow, 1, kFSEventStreamCreateFlagIgnoreSelf ^ kFSEventStreamCreateFlagUseCFTypes);
    
    FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    FSEventStreamStart(stream);
    
}

void Handle_FSCallback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    NSArray *contents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:[[Utility_HelperApp mainAppBundle].bundlePath stringByDeletingLastPathComponent] error:NULL];
    
    if (![contents containsObject:kMFMainAppName]) {
        uninstall();
    }
    
}

void uninstall() {
    [HelperServices_HelperApp enableHelperAsUserAgent:NO];
}

@end
