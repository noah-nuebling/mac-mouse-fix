//
// --------------------------------------------------------------------------
// ConfigFileInterface_HelperApp.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

// TODO: Implement callback when frontmost application changes - change settings accordingly
// Need this when application changes but mouse doesn't move (e.g. Command-Tab). Without this the app specific settings for the new app aren't applied
// NSWorkspaceDidActivateApplicationNotification?

#import "ConfigFileInterface_HelperApp.h"
#import "AppDelegate.h"

#import "ScrollControl.h"
#import "SmoothScroll.h"
#import "MouseInputReceiver.h"
#import "ScrollModifiers.h"
#import "Utility_HelperApp.h"

#import "Constants.h"

@implementation ConfigFileInterface_HelperApp

#pragma mark Globals

static BOOL _configFileChanged;
static NSString *_bundleIDOfAppWhichCausesAppOverride;
static NSDictionary *_stringToEventFlagMask;

static NSString*_configFilePath;

#pragma mark - Interface

+ (void)load_Manual {
    // Get config file path
    NSURL *applicationSupportURL = [NSFileManager.defaultManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    NSString *configFilePathRelative = [NSString stringWithFormat:@"%@/config.plist", kMFBundleIDApp];
    _configFilePath = [applicationSupportURL URLByAppendingPathComponent:configFilePathRelative].path;
    // Load config
    [self reactToConfigFileChange];
    // Setup stuff
    setupFSEventStreamCallback();
    _stringToEventFlagMask = @{
        @"command" : @(kCGEventFlagMaskCommand),
        @"control" : @(kCGEventFlagMaskControl),
        @"option" : @(kCGEventFlagMaskAlternate),
        @"shift" : @(kCGEventFlagMaskShift),
    };
}

static NSMutableDictionary *_config; // TODO: Make this immutable. I think helper should never modifiy this except by reloading from file.
+ (NSMutableDictionary *)config {
    return _config;
}
static NSMutableDictionary *_configWithAppOverridesApplied;
+ (NSMutableDictionary *)configWithAppOverridesApplied {
    return _configWithAppOverridesApplied;
}

+ (void)reactToConfigFileChange {
    fillConfigFromFile();
    _configFileChanged = YES; // Doing this to force update of internal state, even the active app hastn't chaged
    [ConfigFileInterface_HelperApp updateInternalParameters_Force:YES];
    _configFileChanged = NO;
}

/// Load contents of config.plist file into this class' config property
static void fillConfigFromFile() {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ( [fileManager fileExistsAtPath: _configFilePath] == TRUE ) {
        
        NSData *configFromFileData = [NSData dataWithContentsOfFile:_configFilePath];
        NSError *err;
        NSMutableDictionary *configFromFile = [NSPropertyListSerialization propertyListWithData:configFromFileData options:NSPropertyListMutableContainersAndLeaves format:nil error: &err];
        
        NSLog(@"Loading new config from file: %@", configFromFile);
        
        _config = configFromFile;
        
        if ( ( ([[configFromFile allKeys] count] == 0) || (configFromFile == nil) || (err != nil) ) == FALSE ) {
            // TODO: Do sth
        }
    }
}

/// Modify the helpers internal parameters according to _config and the currently active app.
/// Used to apply appOverrides (`force == NO`), and after loading new config from file. (`force == YES`)
/// \param force If NO, then it will only update the internal state, if the app currenly under the cursor is different to the one when this function was last called.
/// \returns YES, if internal parameters did update. NO otherwise.
/// ... wtf was I thinking when writing this, why didn't I write 2 functions?
+ (BOOL)updateInternalParameters_Force:(BOOL)force {

    // Get app under mouse pointer
    NSString *bundleIDOfCurrentApp;
    if (!force) {
        
        CGEventRef fakeEvent = CGEventCreate(NULL);
        CGPoint mouseLocation = CGEventGetLocation(fakeEvent);
        CFRelease(fakeEvent);

        AXUIElementRef elementUnderMousePointer;
        AXUIElementCopyElementAtPosition(ScrollControl.systemWideAXUIElement, mouseLocation.x, mouseLocation.y, &elementUnderMousePointer);
        pid_t elementUnderMousePointerPID;
        AXUIElementGetPid(elementUnderMousePointer, &elementUnderMousePointerPID);
        NSRunningApplication *appUnderMousePointer = [NSRunningApplication runningApplicationWithProcessIdentifier:elementUnderMousePointerPID];
        
        if (elementUnderMousePointer != nil) {
            CFRelease(elementUnderMousePointer); // Using `@try { ... }` instead of `if (x != nil) { ... }` here results in a crash if elementUnderMousePointer is nil for some reason (Might be because it was running in debug configureation or something, or probably I just don't know how `@try` really works)
        }
        bundleIDOfCurrentApp = appUnderMousePointer.bundleIdentifier;
    }

    if (bundleIDOfCurrentApp == nil) {
        // TODO: Make this work for command line executables
//        return NO; // Switching app override settings doesn't apply immediately if we return here
    }
    
    // Set internal state
    if ([_bundleIDOfAppWhichCausesAppOverride isEqualToString:bundleIDOfCurrentApp] == NO || force) {
//        if (bundleIDOfCurrentApp) {
//            NSLog(@"Setting Override For App %@", bundleIDOfCurrentApp);
//        }
        _bundleIDOfAppWhichCausesAppOverride = bundleIDOfCurrentApp;
        loadAppOverridesForApp(bundleIDOfCurrentApp);
        [ConfigFileInterface_HelperApp updateScrollParameters];
        [ScrollControl resetDynamicGlobals]; // Not entirely sure if necessary
        return YES;
    }
    
    return NO;
}

/// Update internal state of scroll classes with values from _configWithAppOverridesApplied
/// \note Call loadAppOverridesForApp() to fill _configWithAppOverridesApplied
+ (void)updateScrollParameters {

    NSDictionary *scroll = [_configWithAppOverridesApplied objectForKey:@"Scroll"];
    
    // top level parameters
    
//        ScrollControl.disableAll = [[defaultScrollSettings objectForKey:@"disableAll"] boolValue]; // this is currently unused. Could be used as a killswitch for all scrolling interception
    ScrollControl.scrollDirection = [scroll[@"direction"] intValue];
    ScrollControl.isSmoothEnabled = [scroll[@"smooth"] boolValue];
    
    
    // Other
    [ScrollControl configureWithParameters:scroll[@"other"]];

    // SmoothParameters
    [SmoothScroll configureWithParameters:scroll[@"smoothParameters"]];

    // roughParameters
        // nothing here yet

    // Keyboard modifier keys
    NSDictionary *mod = scroll[@"modifierKeys"];
    // Event flag masks
    ScrollModifiers.horizontalScrollModifierKeyMask = (CGEventFlags)[_stringToEventFlagMask[mod[@"horizontalScrollModifierKey"]] unsignedLongLongValue];
    ScrollModifiers.magnificationScrollModifierKeyMask = (CGEventFlags)[_stringToEventFlagMask[mod[@"magnificationScrollModifierKey"]] unsignedLongLongValue];
    // Enabled / disabled
    ScrollModifiers.horizontalScrollModifierKeyEnabled = [mod[@"horizontalScrollModifierKeyEnabled"] boolValue];
    ScrollModifiers.magnificationScrollModifierKeyEnabled = [mod[@"magnificationScrollModifierKeyEnabled"] boolValue];
}

/// Applies AppOverrides from app with `bundleIdentifier` to `_config` and writes the result into `_configWithAppOverridesApplied`.
static void loadAppOverridesForApp(NSString *bundleIdentifier) {
     // get AppOverrides for scrolled app
    NSDictionary *overrides = [_config objectForKey:@"AppOverrides"];
    NSDictionary *overridesForThisApp;
    for (NSString *b in overrides.allKeys) {
        if ([bundleIdentifier isEqualToString:b]) {
                overridesForThisApp = [[overrides objectForKey: b] objectForKey:@"Root"];
        }
    }
    if (overridesForThisApp) {
        _configWithAppOverridesApplied = [[Utility_HelperApp dictionaryWithOverridesAppliedFrom:overridesForThisApp to:_config] mutableCopy];
    } else {
        _configWithAppOverridesApplied = _config;
    }
}

+ (void) repairConfigFile:(NSString *)info {
    // TODO: actually repair config dict
    NSLog(@"Should repair configdict.... (not implemented)");
}
 
void Handle_FSEventStreamCallback (ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    NSLog(@"config.plist changed (FSMonitor)");
    
    [ConfigFileInterface_HelperApp reactToConfigFileChange];
}


/**
 We're setting up a File System Monitor so that manual edits to the main configuration file have an effect.
 This allows you to easily test configurations.
 
 Secret trick to find the main configuration file: Open the Mac Mouse Fix app, and click on "More...". Then, hold Command and Shift while clicking the Mac Mouse Fix Icon in the top left.
 */
static void setupFSEventStreamCallback() {
    
    
    CFStringRef cfPath = (__bridge CFStringRef)_configFilePath.copy;
    CFStringRef cfArray[1] = {cfPath};
    CFArrayRef pathsToWatch = CFArrayCreate(NULL, (const void **)cfArray, 1, NULL);
    void *callbackInfo = NULL; // could put stream-sp ecific data here.
    
    NSLog(@"pathsToWatch : %@", cfPath);
    
    CFAbsoluteTime latency = 0.3;
    FSEventStreamRef remapsFileEventStream = FSEventStreamCreate(kCFAllocatorDefault, &Handle_FSEventStreamCallback, callbackInfo, pathsToWatch, kFSEventStreamEventIdSinceNow, latency, kFSEventStreamCreateFlagFileEvents ^ kFSEventStreamCreateFlagUseCFTypes);
    
    FSEventStreamScheduleWithRunLoop(remapsFileEventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    BOOL EventStreamStarted = FSEventStreamStart(remapsFileEventStream);
    NSLog(@"EventStreamStarted: %d", EventStreamStarted);
}

@end
