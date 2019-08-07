//
//  ConfigFileMonitor.m
//  Mouse Remap Helper
//
//  Created by Noah Nübling on 19.11.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//


// TODO: implement callback when frontmost application changes - change settings accordingly
// NSWorkspaceDidActivateApplicationNotification?

#import "ConfigFileInterface.h"
#import "AppDelegate.h"

#import "MomentumScroll.h"
#import "InputReceiver.h"

@implementation ConfigFileInterface

static NSMutableDictionary *config;

+ (NSMutableDictionary *)config {
    return config;
}
// TODO: Why would I ever use this?
+ (void)setConfig:(NSMutableDictionary *)new {
    config = new;
}

+ (void)reactToConfigFileChange {
    fillConfigFromFile();
    updateScrollSettings();
}

static void fillConfigFromFile() {
    
    NSBundle *thisBundle = [NSBundle mainBundle];
    NSString *configFilePath = [thisBundle pathForResource:@"config" ofType:@"plist"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ( [fileManager fileExistsAtPath: configFilePath] == TRUE ) {
        
        NSData *configFileData = [NSData dataWithContentsOfFile:configFilePath];
        
        NSError *err;
        NSMutableDictionary *config = [NSPropertyListSerialization propertyListWithData:configFileData options:NSPropertyListMutableContainersAndLeaves format:nil error: &err];
        
        
        NSLog(@"prop from configMonitor: %@", ConfigFileInterface.config);
        
        NSLog(@"setting new prop from configMonitor: %@", config);
        
        ConfigFileInterface.config = config;
        
        //NSLog(@"configDictFromFile after setting: %@", [ConfigFileMonitor configDictFromFile]);
        
        if ( ( ([[config allKeys] count] == 0) || (config == nil) || (err != nil) ) == FALSE ) {
            
        }
    }
}

static void updateScrollSettings() {
    NSDictionary *config = ConfigFileInterface.config;
    NSDictionary *scrollSettings = [config objectForKey:@"ScrollSettings"];
    if ([[scrollSettings objectForKey:@"enabled"] boolValue] == TRUE) {
        NSArray *values = [scrollSettings objectForKey:@"values"];
        NSNumber *px = [values objectAtIndex:0];
        NSNumber *ms = [values objectAtIndex:1];
        NSNumber *f = [values objectAtIndex:2];
        NSNumber *d = [values objectAtIndex:3];
    
        [MomentumScroll configureWithPxPerStep:px.intValue msPerStep:ms.intValue friction:f.floatValue scrollDirection:d.intValue];
        
        MomentumScroll.isEnabled = TRUE;
        [MomentumScroll startOrStopDecide];
        
        NSLog(@"MomentumScroll.isEnabled: %hhd", MomentumScroll.isEnabled);
        NSLog(@"MomentumScroll.isRunning: %hhd", MomentumScroll.isRunning);
    } else {
        MomentumScroll.isEnabled = FALSE;
        [MomentumScroll startOrStopDecide];
    }
}

+ (void) repairConfigFile:(NSString *)info {
    // TODO: actually repair config dict
    NSLog(@"repairing configDict....");
}


/*
 
 + (void)start {
 //setupFSEventStreamCallback();
 fillConfigDictFromFile();
 updateScrollSettings();
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
*/
@end
