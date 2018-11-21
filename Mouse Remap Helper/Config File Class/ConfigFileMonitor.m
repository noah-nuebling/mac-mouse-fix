//
//  ConfigFileMonitor.m
//  Mouse Remap Helper
//
//  Created by Noah Nübling on 19.11.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import "ConfigFileMonitor.h"
#import "AppDelegate.h"

@implementation ConfigFileMonitor


+ (void) fillConfigDictFromFile {
    
    NSBundle *thisBundle = [NSBundle mainBundle];
    NSString *configFilePath = [thisBundle pathForResource:@"config" ofType:@"plist"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ( [fileManager fileExistsAtPath: configFilePath] == TRUE ) {
        
        NSData *configFileData = [NSData dataWithContentsOfFile:configFilePath];
        
        NSError *err;
        NSMutableDictionary *config = [NSPropertyListSerialization propertyListWithData:configFileData options:NSPropertyListMutableContainersAndLeaves format:nil error: &err];
        
        AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
        
        NSLog(@"prop from configMonitor: %@", [appDelegate configDictFromFile]);
        
        NSLog(@"setting new prop from configMonitor: %@", config);
        
        [appDelegate setConfigDictFromFile:config];
        
        //NSLog(@"configDictFromFile after setting: %@", [ConfigFileMonitor configDictFromFile]);
        
        if ( ( ([[config allKeys] count] == 0) || (config == nil) || (err != nil) ) == FALSE ) {
            
        }
    }
}


void Handle_FSEventStreamCallback (ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    NSLog(@"remaps.plist changed - reloading buttonRemapDictFromFile");
    
    [ConfigFileMonitor fillConfigDictFromFile];
}

+ (void) setupFSEventStreamCallback {
    NSBundle *thisBundle = [NSBundle mainBundle];
    CFStringRef configFilePath = (__bridge CFStringRef) [thisBundle pathForResource:@"config" ofType:@"plist"];
    CFArrayRef pathsToWatch = CFArrayCreate(NULL, (const void **)&configFilePath, 1, NULL);
    void *callbackInfo = NULL; // could put stream-specific data here.
    NSLog(@"pathsToWatch : %@", pathsToWatch);
    
    CFAbsoluteTime latency = 0.3;
    FSEventStreamRef remapsFileEventStream = FSEventStreamCreate(kCFAllocatorDefault, &Handle_FSEventStreamCallback, callbackInfo, pathsToWatch, kFSEventStreamEventIdSinceNow, latency, kFSEventStreamCreateFlagFileEvents ^ kFSEventStreamCreateFlagUseCFTypes);
    
    FSEventStreamScheduleWithRunLoop(remapsFileEventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    BOOL EventStreamStarted = FSEventStreamStart(remapsFileEventStream);
    NSLog(@"EventStreamStarted: %d", EventStreamStarted);
}

@end
