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
#import "MouseInputReceiver.h"
#import "ScrollModifiers.h"
#import "Utility_HelperApp.h"

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
/// TODO: Remove this
//+ (void)setConfig:(NSMutableDictionary *)new {
//    config = new;
//}

/// config with some app specific AppOverrides applied
static NSMutableDictionary *_configWithAppOverridesApplied;
+ (NSMutableDictionary *)configWithAppOverridesApplied {
    return _configWithAppOverridesApplied;
}

+ (void)reactToConfigFileChange {
    fillConfigFromFile();
    _configFileChanged = YES; // Doing this to force update of internal state, even the active app hastn't chaged
    [ConfigFileInterface_HelperApp updateInternalParameters];
    _configFileChanged = NO;
}

/// Load contents of config.plist file into this class' config property
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
        
        _config = config;
        
        //NSLog(@"configDictFromFile after setting: %@", [ConfigFileMonitor configDictFromFile]);
        
        if ( ( ([[config allKeys] count] == 0) || (config == nil) || (err != nil) ) == FALSE ) {
            
        }
    }
}

/// Modify the helpers internal parameters according to _config and the currently active app.
/// \returns YES, if internal parameters did update. NO otherwise.
+ (BOOL)updateInternalParameters {
    // TODO: This function is still seems to be a huge resource hog (thinking this because RoughScroll calls this on every tick and is much more resource intensive than SmoothScroll) – even with the current optimization of only looking at the frontmost app for AppOverrides, instead of the app under the mouse pointer.
    
    NSString *bundleIDOfCurrentApp;
    
    if (_configFileChanged) {
        bundleIDOfCurrentApp = nil;
    } else {
    
        // get App under mouse pointer
            
            
            
        //CFTimeInterval ts = CACurrentMediaTime();
            
            
            // 1. Even slower
            
        //    CGEventRef fakeEvent = CGEventCreate(NULL);
        //    CGPoint mouseLocation = CGEventGetLocation(fakeEvent);
        //    CFRelease(fakeEvent);
            
        //    NSInteger winNUnderMouse = [NSWindow windowNumberAtPoint:(NSPoint)mouseLocation belowWindowWithWindowNumber:0];
        //    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListExcludeDesktopElements | kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
        ////    NSLog(@"windowList: %@", windowList);
        //    int windowPID = 0;
        //    for (int i = 0; i < CFArrayGetCount(windowList); i++) {
        //        CFDictionaryRef w = CFArrayGetValueAtIndex(windowList, i);
        //        int winN;
        //        CFNumberGetValue(CFDictionaryGetValue(w, CFSTR("kCGWindowNumber")), kCFNumberIntType, &winN);
        //        if (winN == winNUnderMouse) {
        //            CFNumberGetValue(CFDictionaryGetValue(w, CFSTR("kCGWindowOwnerPID")), kCFNumberIntType, &windowPID);
        //        }
        //    }
        //    NSRunningApplication *appUnderMousePointer = [NSRunningApplication runningApplicationWithProcessIdentifier:windowPID];
        //    NSString *bundleIdentifierOfScrolledApp_New = appUnderMousePointer.bundleIdentifier;
          
            
            // 2. very slow - but basically the way MOS does it, and MOS is fast somehow
            
            CGEventRef fakeEvent = CGEventCreate(NULL);
            CGPoint mouseLocation = CGEventGetLocation(fakeEvent);
            CFRelease(fakeEvent);

//            if (_previousMouseLocation.x == mouseLocation.x && _previousMouseLocation.y == mouseLocation.y) {
//                return;
//            }
//            _previousMouseLocation = mouseLocation;
        
            AXUIElementRef elementUnderMousePointer;
            AXUIElementCopyElementAtPosition(ScrollControl.systemWideAXUIElement, mouseLocation.x, mouseLocation.y, &elementUnderMousePointer);
            pid_t elementUnderMousePointerPID;
            AXUIElementGetPid(elementUnderMousePointer, &elementUnderMousePointerPID);
            NSRunningApplication *appUnderMousePointer = [NSRunningApplication runningApplicationWithProcessIdentifier:elementUnderMousePointerPID];
        
            @try {
                CFRelease(elementUnderMousePointer);
            } @finally {}
            bundleIDOfCurrentApp = appUnderMousePointer.bundleIdentifier;
            
            
            
        //     3. fast, but only get info about frontmost application
            
//            bundleIdentifierOfActiveApp = [NSWorkspace.sharedWorkspace frontmostApplication].bundleIdentifier;
            
            
            
            // 4. swift copied from MOS - should be fast and gathers info on app under mouse pointer - I couldn't manage to import the Swift code though :/
            
        //    CGEventRef fakeEvent = CGEventCreate(NULL);
        //    NSString *bundleIdentifierOfScrolledApp_New = [_appOverrides getBundleIdFromMouseLocation:fakeEvent];
        //    CFRelease(fakeEvent);
    }
    
    [ScrollControl resetDynamicGlobals];
    
    if ([_bundleIDOfAppWhichCausesAppOverride isEqualToString:bundleIDOfCurrentApp] == NO) {
        _bundleIDOfAppWhichCausesAppOverride = bundleIDOfCurrentApp;
        loadAppOverridesForApp(bundleIDOfCurrentApp);
        [ConfigFileInterface_HelperApp updateScrollParameters];
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

// Call loadAppOverridesForApp before calling this!
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
        _configWithAppOverridesApplied = [[Utility_HelperApp dictionaryWithOverridesAppliedFrom:overridesForThisApp to:_config] mutableCopy];
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
