// TODO: implement callback when frontmost application changes - change settings accordingly
// NSWorkspaceDidActivateApplicationNotification?

#import "ConfigFileInterface_HelperApp.h"
#import "AppDelegate.h"

#import "SmoothScroll.h"
#import "MouseInputReceiver.h"

@implementation ConfigFileInterface_HelperApp

static NSMutableDictionary *config;

+ (void)load_Manual {
    [self reactToConfigFileChange];
    setupFSEventStreamCallback();
}

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
        
        
        NSLog(@"prop from configMonitor: %@", ConfigFileInterface_HelperApp.config);
        
        NSLog(@"setting new prop from configMonitor: %@", config);
        
        ConfigFileInterface_HelperApp.config = config;
        
        //NSLog(@"configDictFromFile after setting: %@", [ConfigFileMonitor configDictFromFile]);
        
        if ( ( ([[config allKeys] count] == 0) || (config == nil) || (err != nil) ) == FALSE ) {
            
        }
    }
}

static void updateScrollSettings() {
    NSDictionary *config = ConfigFileInterface_HelperApp.config;
    NSDictionary *scrollSettings = [config objectForKey:@"ScrollSettings"];
    if ([[scrollSettings objectForKey:@"enabled"] boolValue] == TRUE) {
        NSArray *values = [scrollSettings objectForKey:@"values"];
        NSNumber *px = [values objectAtIndex:0];
        NSNumber *ms = [values objectAtIndex:1];
        NSNumber *f = [values objectAtIndex:2];
        NSNumber *d = [values objectAtIndex:3];
    
        [SmoothScroll configureWithPxPerStep:px.intValue msPerStep:ms.intValue friction:f.floatValue scrollDirection:d.intValue];
        
        SmoothScroll.isEnabled = TRUE;
        [SmoothScroll startOrStopDecide];
        
        NSLog(@"MomentumScroll.isEnabled: %hhd", SmoothScroll.isEnabled);
        NSLog(@"MomentumScroll.isRunning: %hhd", SmoothScroll.isRunning);
    } else {
        SmoothScroll.isEnabled = FALSE;
        [SmoothScroll startOrStopDecide];
    }
}

+ (void) repairConfigFile:(NSString *)info {
    // TODO: actually repair config dict
    NSLog(@"should repair configdict.... (not implemented)");
}



 
void Handle_FSEventStreamCallback (ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    NSLog(@"config.plist changed (FSMonitor)");
    
    [ConfigFileInterface_HelperApp reactToConfigFileChange];
}


/**
 we're setting up a File System Monitor so that manual edits to the main configuration file have an effect.
 This allows you to test your own configurations!
 
 to find the main configuration file, paste one of the following in the terminal:
    - 1. (-> if you installed Mouse Fix for the current user)
    open "$HOME/Library/PreferencePanes/Mouse Fix.prefPane/Contents/Library/LoginItems/Mouse Fix Helper.app/Contents/Resources/config.plist"
    - 2. (-> if you installed Mouse Fix for all users)
    open "/Library/PreferencePanes/Mouse Fix.prefPane/Contents/Library/LoginItems/Mouse Fix Helper.app/Contents/Resources/config.plist"
 */
static void setupFSEventStreamCallback() {
    
    NSBundle *thisBundle = [NSBundle mainBundle];
    CFStringRef configFilePath = (__bridge CFStringRef) [thisBundle pathForResource:@"config" ofType:@"plist"];
    CFArrayRef pathsToWatch = CFArrayCreate(NULL, (const void **)&configFilePath, 1, NULL);
    void *callbackInfo = NULL; // could put stream-sp ecific data here.
    NSLog(@"pathsToWatch : %@", pathsToWatch);
    
    CFAbsoluteTime latency = 0.3;
    FSEventStreamRef remapsFileEventStream = FSEventStreamCreate(kCFAllocatorDefault, &Handle_FSEventStreamCallback, callbackInfo, pathsToWatch, kFSEventStreamEventIdSinceNow, latency, kFSEventStreamCreateFlagFileEvents ^ kFSEventStreamCreateFlagUseCFTypes);
    
    FSEventStreamScheduleWithRunLoop(remapsFileEventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    BOOL EventStreamStarted = FSEventStreamStart(remapsFileEventStream);
    NSLog(@"EventStreamStarted: %d", EventStreamStarted);
}
@end
