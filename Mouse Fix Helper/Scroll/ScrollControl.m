//
// --------------------------------------------------------------------------
// ScrollControl.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ScrollControl.h"
#import "DeviceManager.h"
#import "SmoothScroll.h"
#import "RoughScroll.h"
#import "TouchSimulator.h"
#import "ModifierInputReceiver.h"
#import "ConfigFileInterface_HelperApp.h"

@implementation ScrollControl

#pragma mark - Globals

static NSString *_bundleIdentifierOfAppWhichCausesOverride;
static AXUIElementRef _systemWideAXUIElement;
static int _scrollDirection;

#pragma mark - Interface

+ (void)resetDynamicGlobals {
    _horizontalScrolling    =   NO;
    [SmoothScroll resetDynamicGlobals];
}

// ??? whenever relevantDevicesAreAttached or isEnabled are changed, MomentumScrolls class method decide is called. Start or stop decide will start / stop momentum scroll and set _isRunning

// Used to switch between SmoothScroll and RoughScroll
static BOOL _isSmoothEnabled;
+ (BOOL)isSmoothEnabled {
    return _isSmoothEnabled;
}
+ (void)setIsSmoothEnabled:(BOOL)B {
    _isSmoothEnabled = B;
}

static CGPoint _previousMouseLocation;
+ (CGPoint)previousMouseLocation {
    return _previousMouseLocation;
}
+ (void)setPreviousMouseLocation:(CGPoint)p {
    _previousMouseLocation = p;
}

+ (void)load_Manual {
    _systemWideAXUIElement = AXUIElementCreateSystemWide();
}

+ (int)scrollDirection {
    return _scrollDirection;
}

/// Either activate SmoothScroll or RoughScroll or stop scroll interception entirely
+ (void)decide {
    
    NSLog(@"ScrollControl decide");
    
    [ScrollControl setConfigVariablesForActiveApp]; // TODO: Is this necessary?
    
    BOOL disableAll =
    ![DeviceManager relevantDevicesAreAttached]
    || (!_isSmoothEnabled && _scrollDirection == 1);
//    || isEnabled == NO;
    
    if (disableAll) {
        [SmoothScroll stop];
        [RoughScroll stop];
        [ModifierInputReceiver stop];
        return;
    }
    [ModifierInputReceiver start];
    if (_isSmoothEnabled) {
        [SmoothScroll start];
    } else {
        [RoughScroll start];
    }
}

static BOOL     _horizontalScrolling;
+ (BOOL)horizontalScrolling {
    return _horizontalScrolling;
}
+ (void)setHorizontalScrolling:(BOOL)B {
    _horizontalScrolling = B;
}
static BOOL     _magnificationScrolling;
+ (BOOL)magnificationScrolling {
    return _magnificationScrolling;
}
+ (void)setMagnificationScrolling:(BOOL)B {
    _magnificationScrolling = B;
    if (_magnificationScrolling && !B) {
//        if (_scrollPhase != kMFPhaseEnd) {
            [TouchSimulator postEventWithMagnification:0.0 phase:kIOHIDEventPhaseEnded];
//            [TouchSimulator postEventWithMagnification:0.0 phase:kIOHIDEventPhaseBegan];
//            [TouchSimulator postEventWithMagnification:0.0 phase:kIOHIDEventPhaseEnded];
//        }
    } else if (!_magnificationScrolling && B) {
//        if (_scrollPhase == kMFPhaseMomentum || _scrollPhase == kMFPhaseWheel) {
            [TouchSimulator postEventWithMagnification:0.0 phase:kIOHIDEventPhaseBegan];
//        }
    }
}

#pragma mark - Helper functions

#pragma mark App exceptions

// CLEAN: maybe put this into ConfigFileInterface_HelperApp
+ (void)setConfigVariablesForActiveApp {
    
 
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
    
//    CGEventRef fakeEvent = CGEventCreate(NULL);
//    CGPoint mouseLocation = CGEventGetLocation(fakeEvent);
//    CFRelease(fakeEvent);

//    if (_previousMouseLocation.x == mouseLocation.x && _previousMouseLocation.y == mouseLocation.y) {
//        return;
//    }
//    _previousMouseLocation = mouseLocation;
//
//    AXUIElementRef elementUnderMousePointer;
//    AXUIElementCopyElementAtPosition(_systemWideAXUIElement, mouseLocation.x, mouseLocation.y, &elementUnderMousePointer);
//    pid_t elementUnderMousePointerPID;
//    AXUIElementGetPid(elementUnderMousePointer, &elementUnderMousePointerPID);
//    NSRunningApplication *appUnderMousePointer = [NSRunningApplication runningApplicationWithProcessIdentifier:elementUnderMousePointerPID];
//
//    @try {
//        CFRelease(elementUnderMousePointer);
//    } @finally {}
//    NSString *bundleIdentifierOfScrolledApp_New = appUnderMousePointer.bundleIdentifier;
    
    
    
//     3. fast, but only get info about frontmost application
    
    NSString *bundleIdentifierOfScrolledApp_New = [NSWorkspace.sharedWorkspace frontmostApplication].bundleIdentifier;
    
    
    
    // 4. swift copied from MOS - should be fast and gathers info on app under mouse pointer - I couldn't manage to import the Swift code though :/
    
//    CGEventRef fakeEvent = CGEventCreate(NULL);
//    NSString *bundleIdentifierOfScrolledApp_New = [_appOverrides getBundleIdFromMouseLocation:fakeEvent];
//    CFRelease(fakeEvent);
    
    

    
    
    // if app under mouse pointer changed, adjust settings
    
    if ([_bundleIdentifierOfAppWhichCausesOverride isEqualToString:bundleIdentifierOfScrolledApp_New] == FALSE) {
        
        
        NSDictionary *config = [ConfigFileInterface_HelperApp config];
        

        // get default settings
        
            NSDictionary *defaultScrollSettings = [config objectForKey:@"ScrollSettings"];
            
            // top level
            
                // _disableAll = [[defaultScrollSettings objectForKey:@"disableAll"] boolValue]; // this is currently unused. Could be used as a killswitch for all scrolling interception
                _scrollDirection = [[defaultScrollSettings objectForKey:@"direction"] intValue];
                _isSmoothEnabled = [[defaultScrollSettings objectForKey:@"smooth"] boolValue];
            
            // smoothParameters
            
                NSDictionary *p = [defaultScrollSettings objectForKey:@"smoothParameters"];
                int     sp1     =   [[p objectForKey:@"pxPerStep"] intValue];
                int     sp2     =   [[p objectForKey:@"msPerStep"] intValue];
                float   sp3     =   [[p objectForKey:@"friction"] floatValue];
                float   sp4     =   [[p objectForKey:@"frictionDepth"] floatValue];
                float   sp5     =   [[p objectForKey:@"acceleration"] floatValue];
                int     sp6     =   [[p objectForKey:@"onePixelScrollsLimit"] intValue];
                float   sp7     =   [[p objectForKey:@"fastScrollExponentialBase"] floatValue];
                int     sp8     =   [[p objectForKey:@"fastScrollThreshold_inSwipes"] intValue];
                int     sp9     =   [[p objectForKey:@"scrollSwipeThreshold_inTicks"] intValue];
                float   sp10    =   [[p objectForKey:@"consecutiveScrollTickMaxIntervall"] floatValue];
                float   sp11    =   [[p objectForKey:@"consecutiveScrollSwipeMaxIntervall"] floatValue];
        
            // roughParameters
            
                // nothing here yet
            
        
        // get app specific settings
        
        // TODO: Continue here – 30. March 2020
        
            NSDictionary *overrides = [config objectForKey:@"AppOverrides"];
            NSDictionary *appOverrideScrollSettings;
            for (NSString *b in overrides.allKeys) {
                if ([bundleIdentifierOfScrolledApp_New containsString:b]) {
                    appOverrideScrollSettings = [[overrides objectForKey: b] objectForKey:@"ScrollSettings"];
                }
            }
            
            // If custom overrides for scrolled app exist, apply them
        
            if (appOverrideScrollSettings) {
                
                // top level
                
                    // Syntax explanation:
                    // x = y ? x : y === if y is not nil then x = y
                
                    int dir = [[appOverrideScrollSettings objectForKey:@"direction"] intValue];
                    _scrollDirection = dir ? _scrollDirection : dir;
                    int sm = [[appOverrideScrollSettings objectForKey:@"smooth"] boolValue];
                    _isSmoothEnabled = sm ? _isSmoothEnabled : sm;
                
                    // smoothParameters
                    
                    NSDictionary *p = [appOverrideScrollSettings objectForKey:@"smoothParameters"];
                    if (p) {
                        int     osp1     =   [[p objectForKey:@"pxPerStep"] intValue];
                        int     osp2     =   [[p objectForKey:@"msPerStep"] intValue];
                        float   osp3     =   [[p objectForKey:@"friction"] floatValue];
                        float   osp4     =   [[p objectForKey:@"frictionDepth"] floatValue];
                        float   osp5     =   [[p objectForKey:@"acceleration"] floatValue];
                        int     osp6     =   [[p objectForKey:@"onePixelScrollsLimit"] intValue];
                        float   osp7     =   [[p objectForKey:@"fastScrollExponentialBase"] floatValue];
                        int     osp8     =   [[p objectForKey:@"fastScrollThreshold_inSwipes"] intValue];
                        int     osp9     =   [[p objectForKey:@"scrollSwipeThreshold_inTicks"] intValue];
                        float   osp10    =   [[p objectForKey:@"consecutiveScrollTickMaxIntervall"] floatValue];
                        float   osp11    =   [[p objectForKey:@"consecutiveScrollSwipeMaxIntervall"] floatValue];
                        
                        sp1 = osp1 ? sp1 : osp1;
                        sp2 = osp2 ? sp2 : osp2;
                        sp3 = osp3 ? sp3 : osp3;
                        sp4 = osp4 ? sp4 : osp4;
                        sp5 = osp5 ? sp5 : osp5;
                        sp6 = osp6 ? sp6 : osp6;
                        sp7 = osp7 ? sp7 : osp7;
                        sp8 = osp8 ? sp8 : osp8;
                        sp9 = osp9 ? sp9 : osp9;
                        sp10 = osp10 ? sp10 : osp10;
                        sp11 = osp11 ? sp11 : osp11;
                        
                    }
                
                    // roughParameters
                    
                        // nothing here yet
                    
                

            }
        
        [SmoothScroll configureWithPxPerStep:sp1
                                   msPerStep:sp2
                                    friction:sp3
                               fricitonDepth:sp4
                                acceleration:sp5
                        onePixelScrollsLimit:sp6
                   fastScrollExponentialBase:sp7
                fastScrollThreshold_inSwipes:sp8
                scrollSwipeThreshold_inTicks:sp9
          consecutiveScrollSwipeMaxIntervall:sp10
           consecutiveScrollTickMaxIntervall:sp11];
        
        [ScrollControl decide];
    }

    
//    NSLog(@"override bench: %f", CACurrentMediaTime() - ts);
}

@end
