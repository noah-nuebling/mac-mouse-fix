//
// --------------------------------------------------------------------------
// ConfigFileInterface_HelperApp.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

// TODO: implement callback when frontmost application changes - change settings accordingly
// NSWorkspaceDidActivateApplicationNotification?

#import "ConfigFileInterface_HelperApp.h"
#import "AppDelegate.h"

#import "ScrollControl.h"
#import "SmoothScroll.h"
#import "ButtonInputReceiver.h"
#import "ScrollModifiers.h"
#import "SharedUtility.h"

@implementation ConfigFileInterface_HelperApp

#pragma mark Globals

static BOOL _configFileChanged;
static NSString *_bundleIDOfAppWhichCausesAppOverride;
static NSDictionary *_stringToEventFlagMask;

#pragma mark - Interface

+ (void)load_Manual {
    [self reactToConfigFileChange];
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
    
    NSBundle *thisBundle = [NSBundle mainBundle];
    NSString *configFilePath = [thisBundle pathForResource:@"config" ofType:@"plist"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ( [fileManager fileExistsAtPath: configFilePath] == TRUE ) {
        
        NSData *configFromFileData = [NSData dataWithContentsOfFile:configFilePath];
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
// TODO: Look into using kCGMouseEventWindowUnderMousePointer to get the window under the mouse pointer
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

    // Set internal state
    
    if ([_bundleIDOfAppWhichCausesAppOverride isEqualToString:bundleIDOfCurrentApp] == NO
        || force) {
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

// TODO: Delete this
//static void updateScrollSettings() {
////    NSDictionary *config = ConfigFileInterface_HelperApp.config;
////    NSDictionary *scrollSettings = [config objectForKey:@"ScrollSettings"];
////    
////        NSArray *values = [scrollSettings objectForKey:@"values"];
////        NSNumber *px = [values objectAtIndex:0];
////        NSNumber *ms = [values objectAtIndex:1];
////        NSNumber *f = [values objectAtIndex:2];
////        NSNumber *d = [values objectAtIndex:3];
//        
////        [SmoothScroll configureWithPxPerStep:px.intValue msPerStep:ms.intValue friction:f.floatValue scrollDirection:d.intValue];
//    
////    ScrollControl.isSmoothEnabled = [[scrollSettings objectForKey:@"enabled"] boolValue];
//    
//    // CLEAN: I think that all the stuff above is probably not necessary, because decide calls setConfigVariablesForActiveApp(), which should do also set apropriate scroll settings.
//    [SmoothScroll decide];
//    
//}

/// Update internal state of scroll classes with values from _configWithAppOverridesApplied
/// \note Call loadAppOverridesForApp() to fill _configWithAppOverridesApplied
+ (void)updateScrollParameters {

    NSDictionary *scroll = [_configWithAppOverridesApplied objectForKey:@"Scroll"];
    
    // top level parameters
    
//        ScrollControl.disableAll = [[defaultScrollSettings objectForKey:@"disableAll"] boolValue]; // this is currently unused. Could be used as a killswitch for all scrolling interception
    ScrollControl.scrollDirection = [scroll[@"direction"] intValue];
    ScrollControl.isSmoothEnabled = [scroll[@"smooth"] boolValue];
    
    
    // other
    
    [ScrollControl configureWithParameters:scroll[@"other"]];

    // smoothParameters
    
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
        _configWithAppOverridesApplied = [[SharedUtility dictionaryWithOverridesAppliedFrom:overridesForThisApp to:_config] mutableCopy];
    } else {
        _configWithAppOverridesApplied = _config;
    }
}

// TODO: Delete this
/// This can only work, if the source array has the same number of objects as the destination array. So only specifying the values which you want to override in the source array doesn't work. So you always have to replace the whole array anyways which the apply overrides functio for dictionaries can do as well. There is no need for this function. Just avoid puting arrays or dicts into arrays in the config file.
//static NSArray* applyOverrides_Array(NSArray *src, NSArray *dst) {
//    NSMutableArray *dstMutable = [dst mutableCopy];
//    NSUInteger index = 0;
//    for (NSObject *srcVal in src) {
//        NSObject *dstVal = [dst objectAtIndex:index];
//        if ([srcVal isKindOfClass:[NSDictionary class]] || [srcVal isKindOfClass:[NSMutableDictionary class]]) {
//            NSDictionary *recursionResult = applyOverrides_Dict((NSDictionary *)srcVal, (NSDictionary *)dstVal);
//            [dstMutable setObject:recursionResult atIndexedSubscript:index];
//        } else if ([srcVal isKindOfClass:[NSArray class]]) {
//            NSArray *recursionResult = applyOverrides_Array((NSArray *)srcVal, (NSArray *)dstVal);
//            [dstMutable setObject:recursionResult atIndexedSubscript:index];
//        } else {
//            [dstMutable setObject:srcVal atIndexedSubscript:index];
//        }
//        index++;
//    }
//    return dstMutable;
//}
// TODO: Delete this
/// will apply app specific overrides.
/// Will only do something, if the active app has changed since the last time that this function was called
//+ (void)updateScrollSettingsWithActiveApp:(NSString *)bundleIdentifierOfScrolledApp {
//
//    // if app under mouse pointer changed, adjust settings
//
//    if ([_bundleIdentifierOfAppWhichCausesOverride isEqualToString:bundleIdentifierOfScrolledApp] == FALSE) {
//        _bundleIdentifierOfAppWhichCausesOverride = bundleIdentifierOfScrolledApp;
//
//        // get default settings
//        NSDictionary *config = [ConfigFileInterface_HelperApp config];
//
//        // get overrides for scrolled app
//            NSDictionary *overrides = [config objectForKey:@"AppOverrides"];
//            NSDictionary *overridesForScrolledApp;
//            for (NSString *b in overrides.allKeys) {
//                if ([bundleIdentifierOfScrolledApp containsString:b]) {
//                        overridesForScrolledApp = [overrides objectForKey: b];
//                }
//            }
//        // apply overrides
//        NSDictionary *config
//
//
//
//            // top level
//
//                // _disableAll = [[defaultScrollSettings objectForKey:@"disableAll"] boolValue]; // this is currently unused. Could be used as a killswitch for all scrolling interception
//                ScrollControl.scrollDirection = [[defaultScrollSettings objectForKey:@"direction"] intValue];
//                ScrollControl.isSmoothEnabled = [[defaultScrollSettings objectForKey:@"smooth"] boolValue];
//
//            // smoothParameters
//
//                NSDictionary *p = [defaultScrollSettings objectForKey:@"smoothParameters"];
//                int     sp1     =   [[p objectForKey:@"pxPerStep"] intValue];
//                int     sp2     =   [[p objectForKey:@"msPerStep"] intValue];
//                float   sp3     =   [[p objectForKey:@"friction"] floatValue];
//                float   sp4     =   [[p objectForKey:@"frictionDepth"] floatValue];
//                float   sp5     =   [[p objectForKey:@"acceleration"] floatValue];
//                int     sp6     =   [[p objectForKey:@"onePixelScrollsLimit"] intValue];
//                float   sp7     =   [[p objectForKey:@"fastScrollExponentialBase"] floatValue];
//                int     sp8     =   [[p objectForKey:@"fastScrollThreshold_inSwipes"] intValue];
//                int     sp9     =   [[p objectForKey:@"scrollSwipeThreshold_inTicks"] intValue];
//                float   sp10    =   [[p objectForKey:@"consecutiveScrollSwipeMaxIntervall"] floatValue];
//                float   sp11    =   [[p objectForKey:@"consecutiveScrollTickMaxIntervall"] floatValue];
//
//            // roughParameters
//
//                // nothing here yet
//
//            // keyboard modifier keys
//        NSDictionary *mod = [defaultScrollSettings objectForKey:@"modifierKeys"];
//        ScrollModifiers.horizontalScrollModifierKeyEnabled = [[mod objectForKey:@"horizontalScrollModifierKeyEnabled"] boolValue];
//        ScrollModifiers.magnificationScrollModifierKeyEnabled = [[mod objectForKey:@"magnificationScrollModifierKeyEnabled"] boolValue];
//
//
//        // get app specific settings
//
//            NSDictionary *overrides = [config objectForKey:@"AppOverrides"];
//            NSDictionary *appOverrideScrollSettings;
//            for (NSString *b in overrides.allKeys) {
//                if ([bundleIdentifierOfScrolledApp containsString:b]) {
//                    appOverrideScrollSettings = [[overrides objectForKey: b] objectForKey:@"ScrollSettings"];
//                }
//            }
//
//            // If custom overrides for scrolled app exist, apply them
//
//            if (appOverrideScrollSettings) {
//
//                // top level
//
//                    // Syntax explanation:
//                    // x = y ? y : x === if y != nil then x = y, else x = x
//
//                    NSNumber *dir = [appOverrideScrollSettings objectForKey:@"direction"];
//                    ScrollControl.scrollDirection = dir ? [dir integerValue] : ScrollControl.scrollDirection;
//                    NSNumber *sm = [appOverrideScrollSettings objectForKey:@"smooth"];
//                    ScrollControl.isSmoothEnabled = sm ? [sm boolValue] : ScrollControl.isSmoothEnabled;
//
//                    // smoothParameters
//
//                    NSDictionary *p = [appOverrideScrollSettings objectForKey:@"smoothParameters"];
//                    if (p) {
//                        int     osp1     =   [[p objectForKey:@"pxPerStep"] intValue];
//                        int     osp2     =   [[p objectForKey:@"msPerStep"] intValue];
//                        float   osp3     =   [[p objectForKey:@"friction"] floatValue];
//                        float   osp4     =   [[p objectForKey:@"frictionDepth"] floatValue];
//                        float   osp5     =   [[p objectForKey:@"acceleration"] floatValue];
//                        int     osp6     =   [[p objectForKey:@"onePixelScrollsLimit"] intValue];
//                        float   osp7     =   [[p objectForKey:@"fastScrollExponentialBase"] floatValue];
//                        int     osp8     =   [[p objectForKey:@"fastScrollThreshold_inSwipes"] intValue];
//                        int     osp9     =   [[p objectForKey:@"scrollSwipeThreshold_inTicks"] intValue];
//                        float   osp10    =   [[p objectForKey:@"consecutiveScrollSwipeMaxIntervall"] floatValue];
//                        float   osp11    =   [[p objectForKey:@"consecutiveScrollTickMaxIntervall"] floatValue];
//
//                        sp1 = osp1 ? osp1 : sp1;
//                        sp2 = osp2 ? osp2 : sp2;
//                        sp3 = osp3 ? osp3 : sp3;
//                        sp4 = osp4 ? osp4 : sp4;
//                        sp5 = osp5 ? osp5 : sp5;
//                        sp6 = osp6 ? osp6 : sp6;
//                        sp7 = osp7 ? osp7 : sp7;
//                        sp8 = osp8 ? osp8 : sp8;
//                        sp9 = osp9 ? osp9 : sp9;
//                        sp10 = osp10 ? osp10 : sp10;
//                        sp11 = osp11 ? osp11 : sp11;
//
//                    }
//
//                    // roughParameters
//
//                        // nothing here yet
//
//                    // modifierKeys
//
//                    NSDictionary *omod = [appOverrideScrollSettings objectForKey:@"modifierKeys"];
//                    if (omod) {
//                        BOOL hs = [[omod objectForKey:@"horizontalScrollModifierKeyEnabled"] boolValue];
//                        ScrollModifiers.horizontalScrollModifierKeyEnabled = hs ? hs : ScrollModifiers.horizontalScrollModifierKeyEnabled;
//                        BOOL ms = [[omod objectForKey:@"magnificationScrollModifierKeyEnabled"] boolValue];
//                        ScrollModifiers.magnificationScrollModifierKeyEnabled = ms ? ms : ScrollModifiers.magnificationScrollModifierKeyEnabled;
//                    }
//
//
//            }
//
//        /// TODO: Give this function one dictionary instead of so many arguments
//        [SmoothScroll configureWithPxPerStep:sp1
//                                   msPerStep:sp2
//                                    friction:sp3
//                               fricitonDepth:sp4
//                                acceleration:sp5
//                        onePixelScrollsLimit:sp6
//                   fastScrollExponentialBase:sp7
//                fastScrollThreshold_inSwipes:sp8
//                scrollSwipeThreshold_inTicks:sp9
//          consecutiveScrollSwipeMaxIntervall:sp10
//           consecutiveScrollTickMaxIntervall:sp11];
//
//        [ScrollControl decide];
//    }
//
//
////    NSLog(@"override bench: %f", CACurrentMediaTime() - ts);
//}

+ (void) repairConfigFile:(NSString *)info {
    // TODO: actually repair config dict
    NSLog(@"should repair configdict.... (not implemented)"); 
}



 
void Handle_FSEventStreamCallback (ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    NSLog(@"config.plist changed (FSMonitor)");
    
    [ConfigFileInterface_HelperApp reactToConfigFileChange];
}


/**
 We're setting up a File System Monitor so that manual edits to the main configuration file have an effect.
 This allows you to easily test configurations.
 
 To find the main configuration file:
 
 - 1. Open the `Mouse Fix` PrefPane, and click on `More...`. Then, hold Command and Shift while clicking the Mac Mouse Fix Icon in the top left.
 
 - 2. Paste one of the following in the terminal:
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
