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
#import "SharedMessagePort.h"
#import "Objects.h"

#if IS_HELPER
#import "Mac_Mouse_Fix_Helper-Swift.h"
#endif

#if IS_MAIN_APP
#import "Mac_Mouse_Fix-Swift.h"
#endif

@implementation Config {
    
    NSString*_configFilePath; /// Should probably use `Objects.m` to find config and defaultConfig
    NSURL *_defaultConfigURL; /// `default_config` used to be known as `backup_config`
    NSString *_bundleIDOfAppWhichCausesAppOverride;
//    NSDictionary *_stringToEventFlagMask; /// Delete this
}
@synthesize config=_config, configWithAppOverridesApplied=_configWithAppOverridesApplied;

#pragma mark - Init & singleton instance

+ (void)load_Manual {
    
    /// Create instance
    _instance = [[Config alloc] init];
    
    /// Setup stuff
    ///     Can't do this in `[_instance init]` because the callchain accesses tries to access the `_instance` through `Config.shared`. (Might be fixable by making `handleConfigFileChange()` an instance method like everything else)
    
    if (SharedUtility.runningHelper) {
        /// Load config
        [Config handleConfigFileChange];
        /// Setup stuff
        [_instance setupFSEventStreamCallback];
    } else {
        /// Just load config
//        [_instance loadConfigFromFile];
        /// Load config
        [Config handleConfigFileChange];
    }
    
}

static Config *_instance;
+ (Config *)shared {
    return _instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        /// Get config file path
        NSURL *applicationSupportURL = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        NSString *configFilePathRelative = [NSString stringWithFormat:@"%@/config.plist", kMFBundleIDApp];
        _configFilePath = [applicationSupportURL URLByAppendingPathComponent:configFilePathRelative].path;
        
        /// Get default config url
        NSString *defaultConfigPathRelative = @"Contents/Resources/default_config.plist";
        _defaultConfigURL = [Objects.mainAppBundle.bundleURL URLByAppendingPathComponent:defaultConfigPathRelative];
    }
    return self;
}

#pragma mark - Convenience

NSObject *config(NSString *keyPath) {
    /// Convenience function for accessing config
    NSMutableDictionary *config = Config.shared.config;
    NSObject *result = [config valueForKeyPath:keyPath];
    return result;
}
void setConfig(NSString *keyPath, NSObject *value) {
    /// Convenience function for modifying config
    /// This doesn't write to file
    return [Config.shared.config setValue:value forKeyPath:keyPath];
}

void commitConfig() {
    /// Convenience function for notifying other modules of the changed config (and writing to file)
    
    /// Write to file
    [Config.shared writeConfigToFile];
    
    /// Notify other app (mainApp notifies helper, helper notifies mainApp
    [SharedMessagePort sendMessage:@"configFileChanged" withPayload:nil expectingReply:NO];
    
    /// Update own state
    [Config handleConfigFileChange];
}


#pragma mark - React

+ (void)handleConfigFileChange {
    
#if IS_MAIN_APP
    
    /// Update this class
    [self.shared loadConfigFromFile];
    
    /// Notify other modules
    [ReactiveConfig.shared reactWithNewConfig:Config.shared.config];

#endif
    
#if IS_HELPER
    
    /// Update this class
    [self.shared loadConfigFromFile];
    [self.shared loadOverridesForApp:@""]; /// Force update of internal state, (even the active app hastn't changed)
    
    /// Notify other modules
    [TransformationManager reload];
    [ScrollConfig reload];
    [Scroll decide];
    [PointerConfig reload];
    [OtherConfig reload];
    [MenuBarItem reload];

#endif
}

#pragma mark - Overrides

- (BOOL)loadOverridesForAppUnderMousePointer {
    /// Returns yes when it's made a change
    /// TODO: Add compatibility for command line executables
    /// TODO: Look into using kCGMouseEventWindowUnderMousePointer to get the window under the mouse pointer
    
    /// Validate
    
    assert(SharedUtility.runningHelper);
    
#if IS_HELPER
    
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
        [self loadOverridesForApp:bundleID];
        return YES;
    }
#endif
    
    return NO;
}

/// Applies AppOverrides from app with `bundleIdentifier` to `_config` and writes the result into `_configWithAppOverridesApplied`.
- (void)loadOverridesForApp:(NSString *)bundleID {
    
    /// Validate
    assert(SharedUtility.runningHelper);
    
#if IS_HELPER
    
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
#endif
}

#pragma mark - Listen to filesystem changes
/// This stuff is unused in MainApp (and can be removed entirely. Was just for testing.)

- (void)setupFSEventStreamCallback {
    
    /**
     We're setting up a File System Monitor so that manual edits to the main configuration file have an effect.
     This allows you to easily test configurations.
     
     Secret trick to find the main configuration file: Open the Mac Mouse Fix app, and click on "More...". Then, hold Command and Shift while clicking the Mac Mouse Fix Icon in the top left.
     */
    
    assert(SharedUtility.runningHelper);
    
#if IS_HELPER
    
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
    
#endif
}

void Handle_FSEventStreamCallback (ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    DDLogInfo(@"config.plist changed (FSMonitor)");
    
    [Config handleConfigFileChange];
}


#pragma mark - Read and write from file

- (void)writeConfigToFile {
    
    /**
     Writes the `_config` dicitonary to the plist file at `_configURL`
     You probably want to use `commitConfig()` instead of this
     */
    
    NSError *serializeErr;
    NSData *configData = [NSPropertyListSerialization dataWithPropertyList:self.config format:NSPropertyListXMLFormat_v1_0 options:0 error:&serializeErr];
    if (serializeErr) {
        DDLogInfo(@"ERROR serializing configDictFromFile: %@", serializeErr);
    }
    NSError *writeErr;
    [configData writeToURL:Objects.configURL options:NSDataWritingAtomic error:&writeErr];
    if (writeErr) {
        DDLogInfo(@"ERROR writing configDictFromFile to file: %@", writeErr);
    }
    DDLogInfo(@"Wrote config to file.");
}

- (void)loadConfigFromFile {
    
    /// Load data from plist file at `_configURL` into `_config` class variable
    /// This only really needs to be called when `ConfigFileInterface_App` is loaded, but I use it in other places as well, to make the program behave better, when I manually edit the config file.
    
    [self repairConfigWithProblem:kMFConfigProblemNone info:nil];
    
    NSData *configData = [NSData dataWithContentsOfURL:Objects.configURL];
    NSError *readErr;
    NSMutableDictionary *configDict = [NSPropertyListSerialization propertyListWithData:configData options:NSPropertyListMutableContainersAndLeaves format:nil error:&readErr];
    if (readErr) {
        DDLogInfo(@"Error Reading config File: %@", readErr);
        // TODO: handle this error
    }
    
    DDLogDebug(@"Loaded config from file: %@", configDict);
    
    _config = configDict;
    
    /// Send reactive signal -> Disabled because callers of this function do that now
//    [ReactiveConfig.shared reactWithNewConfig:configDict];
    
    /**
     Here's the old `fillConfigFromFile()` loading code from Helper. (This is the loading code for mainApp)
     
     ```
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
     ```
     */
    
}

#pragma mark - Repair

- (void)repairConfigWithProblem:(MFConfigProblem)problem info:(id _Nullable)info {
    
    /// Checks config for errors / incompatibilty and repairs it if necessary.
    /// TODO: Test if this still works
    /// TODO: Check whether all default (as opposed to override) values exist in config file. If they don't, then everything breaks. Maybe do this by comparing with default_config. Edit: Not sure this is feasible, also the comparing with default_config breaks if we want to have keys that are optional.
    /// TODO: Consider moving/copying this function to helper, so it can repair stuff as well.
    
    /// Create config file if none exists
    
    if (![NSFileManager.defaultManager fileExistsAtPath:Objects.configURL.path]) {
        [NSFileManager.defaultManager createDirectoryAtURL:Objects.configURL.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        [self replaceCurrentConfigWithDefaultConfig];
    }
    
    /// Check if config version matches, if not, replace with default.
    
    NSNumber *currentConfigVersion = [[NSDictionary dictionaryWithContentsOfURL:Objects.configURL] valueForKeyPath:@"Other.configVersion"];
    NSNumber *defaultConfigVersion = [[NSDictionary dictionaryWithContentsOfURL:_defaultConfigURL] valueForKeyPath:@"Other.configVersion"];
    if (currentConfigVersion.intValue != defaultConfigVersion.intValue) {
        [self replaceCurrentConfigWithDefaultConfig];
    }
    
    /// Repair incomplete App override
    ///     Do this by simply copying over the values from the default config
    ///     TODO: Check if this works
    
    if (problem == kMFConfigProblemIncompleteAppOverride) {
        NSAssert(info && [info isKindOfClass:[NSDictionary class]], @"Can't repair incomplete app override: invalid argument provided");
        
        NSString *bundleID = info[@"bundleID"]; /// Bundle ID of the app with the faulty override
        NSString *bundleIDEscaped = [bundleID stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
        NSArray *keyPathsToDefaultValues = info[@"relevantKeyPaths"]; /// KeyPaths to the values of which at least one is missing
        for (NSString *defaultKP in keyPathsToDefaultValues) {
            NSString *overrideKP = [NSString stringWithFormat:@"AppOverrides.%@.Root.%@", bundleIDEscaped, defaultKP];
            if ([_config objectForCoolKeyPath:overrideKP] == nil) {
                /// If an override value doesn't exist at overrideKP, put default value at overrideKP.
                [_config setObject:[_config objectForCoolKeyPath:defaultKP] forCoolKeyPath:overrideKP];
            }
        }
        commitConfig();
    }
}

- (void)replaceCurrentConfigWithDefaultConfig {
    
    /// Replaces the current config file which the helper app is reading from with the backup one and then terminates the helper. (Helper will restart automatically because of the KeepAlive attribute in its user agent config file.)
    
    assert(SharedUtility.runningMainApp);
    
    /// Overwrite `config.plist` with `default_config.plist`
    NSData *defaultData = [NSData dataWithContentsOfURL:_defaultConfigURL];
    [defaultData writeToURL:Objects.configURL atomically:YES];
    
    /// Update helper
    ///     Why aren't we just sending a configFileChanged message?
    [SharedMessagePort sendMessage:@"terminate" withPayload:nil expectingReply:NO];
    
    /// Update self (mainApp)
//    [self loadConfigFromFile];
    [Config handleConfigFileChange];
    
}

- (void)cleanConfig {
    NSMutableDictionary *appOverrides = _config[kMFConfigKeyAppOverrides];
    
    /// Note: We don't delete overrides for uninstalled apps because this might delete preinstalled overrides
    
    removeLeaflessSubDicts(appOverrides);
    
    commitConfig(); /// No need to notify the helper at the time of writing
}

static void removeLeaflessSubDicts(NSMutableDictionary *dict) {
    
    /// Delete all paths in the dictionary which don't lead to anything
    // TODO: Implement cleaning function which deletes all overrides that don't change the default config. Adding and removing different apps in ScrollOverridePanel will accumulate dead entries. v is that what I meant?
    
    for (NSString *key in dict.allKeys) {
        NSObject *val = dict[key];
        if ([val isKindOfClass:[NSMutableDictionary class]]) {
            removeLeaflessSubDicts((NSMutableDictionary *)val);
            if (((NSMutableDictionary *)val).count == 0) {
                dict[key] = nil;
            }
        }
    }
}


@end
