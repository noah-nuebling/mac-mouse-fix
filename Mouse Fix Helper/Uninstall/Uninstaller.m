//
//  Uninstaller.m
//  Mouse Fix Helper
//
//  Created by Noah Nübling on 10.09.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
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
    
    NSArray *contents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:[Utility_HelperApp prefPaneBundle].bundlePath error:NULL];
    
    if (![contents containsObject:@"Mouse Fix.prefPane"]) {
        
        [HelperServices_HelperApp enableHelperAsUserAgent:NO];
    }
    
}


@end
