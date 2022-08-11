//
// --------------------------------------------------------------------------
// ConfigFileInterface_Helper.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// TODO: Implement callback when frontmost application changes - change settings accordingly
/// Need this when application changes but mouse doesn't move (e.g. Command-Tab). Without this the app specific settings for the new app aren't applied
/// NSWorkspaceDidActivateApplicationNotification?

#import "Config.h"
#import "AppDelegate.h"
#import "Scroll.h"
#import "ButtonInputReceiver.h"
#import "ScrollModifiers.h"
#import "SharedUtility.h"
#import "TransformationManager.h"
#import "Constants.h"
#import "TransformationUtility.h"
#import "HelperUtility.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"

@implementation Config

#pragma mark Globals

static NSString *_bundleIDOfAppWhichCausesAppOverride;
static NSDictionary *_stringToEventFlagMask;

static NSString*_configFilePath;

#pragma mark - Init

+ (void)load_Manual {
    /// Get config file path
    NSURL *applicationSupportURL = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    NSString *configFilePathRelative = [NSString stringWithFormat:@"%@/config.plist", kMFBundleIDApp];
    _configFilePath = [applicationSupportURL URLByAppendingPathComponent:configFilePathRelative].path;
    /// Load config
    [self reactToConfigFileChange];
    /// Setup stuff
    setupFSEventStreamCallback();
}

#pragma mark - Convenience

id config(NSString *keyPath) {
    return [Config.config valueForKeyPath:keyPath];
}
void setConfig(NSString *keyPath, id value) {
    /// This doesn't write to file. 
    return [Config.config setValue:value forKeyPath:keyPath];
}
/// Convenience function for writing config to file and notifying the helper app
//void commitConfig() {
//    [ConfigInterface_App writeConfigToFileAndNotifyHelper];
//}


#pragma mark - React to changes & notify other modules

+ (void)reactToConfigFileChange {
    
    /// Update self
    fillConfigFromFile();
    loadOverridesForApp(@""); /// Force update of internal state, (even the active app hastn't changed)
    
    /// Notify other modules
    [TransformationManager reload];
    [ScrollConfig reload];
    [PointerConfig reload];
    [OtherConfig reload];
    [MenuBarItem reload];
}

#pragma mark - Read from memory

static NSMutableDictionary *_config; // TODO: Make this immutable. I think helper should never modifiy this except by reloading from file.
+ (NSMutableDictionary *)config {
    return _config;
}
static NSMutableDictionary *_configWithAppOverridesApplied;
+ (NSMutableDictionary *)configWithAppOverridesApplied {
    return _configWithAppOverridesApplied;
}

#pragma mark - Load memory from file

/// Load contents of config.plist file into this class' config property
static void fillConfigFromFile() {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ( [fileManager fileExistsAtPath: _configFilePath] == TRUE ) {
        
        NSData *configFromFileData = [NSData dataWithContentsOfFile:_configFilePath];
        NSError *err;
        NSMutableDictionary *configFromFile = [NSPropertyListSerialization propertyListWithData:configFromFileData options:NSPropertyListMutableContainersAndLeaves format:nil error: &err];
        
        DDLogInfo(@"Loading new config from file: %@", configFromFile);
        
        _config = configFromFile;
        
        if ( ( ([[configFromFile allKeys] count] == 0) || (configFromFile == nil) || (err != nil) ) == FALSE ) {
            // TODO: Do sth
        }
    }
}

#pragma mark - Overrides

+ (BOOL)loadOverridesForAppUnderMousePointer {
    /// Returns yes when it's made a change
    /// TODO: Add compatibility for command line executables
    /// TODO: Look into using kCGMouseEventWindowUnderMousePointer to get the window under the mouse pointer
    
    /// Get app under mouse pointer
        
    CGPoint mouseLocation = getPointerLocation();

    AXUIElementRef elementUnderMousePointer;
    AXUIElementCopyElementAtPosition(Scroll.systemWideAXUIElement, mouseLocation.x, mouseLocation.y, &elementUnderMousePointer);
    pid_t elementUnderMousePointerPID;
    AXUIElementGetPid(elementUnderMousePointer, &elementUnderMousePointerPID);
    NSRunningApplication *appUnderMousePointer = [NSRunningApplication runningApplicationWithProcessIdentifier:elementUnderMousePointerPID];
    
    if (elementUnderMousePointer != nil) {
        CFRelease(elementUnderMousePointer); /// Using `@try { ... }` instead of `if (x != nil) { ... }` here results in a crash if elementUnderMousePointer is nil for some reason (Might be because it was running in debug configureation or something, or probably I just don't know how `@try` really works)
    }
    NSString *bundleID = appUnderMousePointer.bundleIdentifier;
    
    /// Set internal state
    if (![_bundleIDOfAppWhichCausesAppOverride isEqual:bundleID]) {
        loadOverridesForApp(bundleID);
        return YES;
    }
    
    return NO;
}

/// Applies AppOverrides from app with `bundleIdentifier` to `_config` and writes the result into `_configWithAppOverridesApplied`.
static void loadOverridesForApp(NSString *bundleID) {
    
    /// Store app
    _bundleIDOfAppWhichCausesAppOverride = bundleID;
    
    /// Get overrides for app
    NSDictionary *overrides = [_config objectForKey:kMFConfigKeyAppOverrides];
    NSDictionary *overridesForThisApp;
    for (NSString *b in overrides.allKeys) {
        if ([bundleID isEqualToString:b]) {
                overridesForThisApp = [[overrides objectForKey: b] objectForKey:@"Root"];
        }
    }
    if (overridesForThisApp) {
        _configWithAppOverridesApplied = [[SharedUtility dictionaryWithOverridesAppliedFrom:overridesForThisApp to:_config] mutableCopy];
    } else {
        _configWithAppOverridesApplied = _config;
    }
}

+ (void) repairConfigFile:(NSString *)info {
    // TODO: actually repair config dict
    DDLogInfo(@"Should repair configdict.... (not implemented)");
}

#pragma mark - Listen to filesystem changes

static void setupFSEventStreamCallback() {
    
    /**
     We're setting up a File System Monitor so that manual edits to the main configuration file have an effect.
     This allows you to easily test configurations.
     
     Secret trick to find the main configuration file: Open the Mac Mouse Fix app, and click on "More...". Then, hold Command and Shift while clicking the Mac Mouse Fix Icon in the top left.
     */
    
    CFArrayRef pathsToWatch;
    void *callbackInfo = NULL; /// Could put stream-specific data here.
    if (@available(macOS 13, *)) { /// The old code causes a crash on Ventura (specifically trying to log the cfPath using DDLogInfo)
        NSArray *pathsToWatchNS = @[_configFilePath];
        pathsToWatch = (__bridge_retained CFArrayRef)pathsToWatchNS; /// `__bridge_retained` -> we need to release this manually
    } else {
        CFStringRef cfPath = (__bridge CFStringRef)_configFilePath.copy; /// Why are we copying this?
        CFStringRef cfArray[1] = {cfPath};
        pathsToWatch = CFArrayCreate(NULL, (const void **)cfArray, 1, NULL);
    }
    
    
    DDLogInfo(@"pathsToWatch : %@", (__bridge NSArray *)pathsToWatch);
    
    /// Create eventStream
    CFAbsoluteTime latency = 0.3;
    FSEventStreamRef remapsFileEventStream = FSEventStreamCreate(kCFAllocatorDefault, &Handle_FSEventStreamCallback, callbackInfo, pathsToWatch, kFSEventStreamEventIdSinceNow, latency, kFSEventStreamCreateFlagFileEvents ^ kFSEventStreamCreateFlagUseCFTypes);
    
    /// Start eventStream
    FSEventStreamScheduleWithRunLoop(remapsFileEventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    BOOL EventStreamStarted = FSEventStreamStart(remapsFileEventStream);
    DDLogInfo(@"EventStreamStarted: %d", EventStreamStarted);
    
    /// Release stuff
    ///     We might be leaking a bunch of things here in this class but it doesn't matter since it's only run once when the app starts up
    CFRelease(pathsToWatch);
}

void Handle_FSEventStreamCallback (ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    DDLogInfo(@"config.plist changed (FSMonitor)");
    
    [Config reactToConfigFileChange];
}


@end
