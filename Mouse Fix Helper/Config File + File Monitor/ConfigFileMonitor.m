//
//  ConfigFileMonitor.m
//  Mouse Remap Helper
//
//  Created by Noah Nübling on 19.11.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//


// TODO: implement callback when frontmost application changes - change settings accordingly
// NSWorkspaceDidActivateApplicationNotification?

#import "ConfigFileMonitor.h"
#import "AppDelegate.h"

#import "MomentumScroll.h"
#import "InputReceiver.h"

@implementation ConfigFileMonitor

+ (void)start {
    setupFSEventStreamCallback();
    fillConfigDictFromFile();
    updateScrollSettings();
}

static void fillConfigDictFromFile() {
    
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
        
        [appDelegate updateConfig:config];
        
        //NSLog(@"configDictFromFile after setting: %@", [ConfigFileMonitor configDictFromFile]);
        
        if ( ( ([[config allKeys] count] == 0) || (config == nil) || (err != nil) ) == FALSE ) {
            
        }
    }
}

static void updateScrollSettings() {
    AppDelegate *delegate = [NSApp delegate];
    NSDictionary *config = [delegate configDictFromFile];
    NSDictionary *scrollSettings = [config objectForKey:@"ScrollSettings"];
    if ([[scrollSettings objectForKey:@"enabled"] boolValue] == TRUE) {
        NSArray *values = [scrollSettings objectForKey:@"values"];
        NSNumber *px = [values objectAtIndex:0];
        NSNumber *ms = [values objectAtIndex:1];
        NSNumber *f = [values objectAtIndex:2];
    
        [MomentumScroll configureWithPxPerStep:px.intValue msPerStep:ms.intValue friction:f.floatValue];
        MomentumScroll.isEnabled = TRUE;
        NSLog(@"MomentumScroll.isEnabled: %hhd", MomentumScroll.isEnabled);
        if (InputReceiver.relevantDevicesAreAttached && !MomentumScroll.isRunning) {
            [MomentumScroll start];
        }
    }
    else {
        MomentumScroll.isEnabled = FALSE;
        [MomentumScroll stop];
    }
}



void Handle_FSEventStreamCallback (ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    NSLog(@"remaps.plist changed - reloading buttonRemapDictFromFile");
    
    fillConfigDictFromFile();
    updateScrollSettings();
}

static void setupFSEventStreamCallback() {
    
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
