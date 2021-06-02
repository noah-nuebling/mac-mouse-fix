//
// --------------------------------------------------------------------------
// ScrollConfigInterface.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ScrollConfig.h"
#import "MainConfigInterface.h"
#import "Constants.h"

@implementation ScrollConfig

// Convenience functions for accessing top level dict and different sub-dicts

static NSDictionary *topLevel() {
    return MainConfigInterface.configWithAppOverridesApplied[kMFConfigKeyScroll];
}
static NSDictionary *other() {
    return topLevel()[@"other"];
}
static NSDictionary *smooth() {
    return topLevel()[@"smoothParameters"];
}
static NSDictionary *mod() {
    return topLevel()[@"modifierKeys"];
}

// General

+ (BOOL)smoothEnabled {
    return [topLevel()[@"smooth"] boolValue];
}
+ (MFScrollDirection)scrollDirection {
    return [topLevel()[@"direction"] intValue];
}
+ (BOOL)disableAll {
    return [topLevel()[@"disableAll"] boolValue]; // This is currently unused. Could be used as a killswitch for all scrolling interception
}

// Scroll ticks/wipes, and fast scroll

+ (NSUInteger)scrollSwipeThreshold_inTicks { // If `_scrollSwipeThreshold_inTicks` consecutive ticks occur, they are deemed a scroll-swipe.
    return [other()[@"scrollSwipeThreshold_inTicks"] intValue]; // 3
}
+ (NSUInteger)fastScrollThreshold_inSwipes { // If `_fastScrollThreshold_inSwipes` consecutive swipes occur, fast scrolling is enabled.
    return [other()[@"fastScrollThreshold_inSwipes"] intValue];
}
+ (NSTimeInterval)consecutiveScrollTickMaxInterval { // If more than `_consecutiveScrollTickMaxIntervall` seconds passes between two scrollwheel ticks, then they aren't deemed consecutive.
    return [other()[@"consecutiveScrollTickMaxIntervall"] doubleValue]; // == _msPerStep/1000 // oldval:0.03
}
+ (NSTimeInterval)consecutiveScrollSwipeMaxInterval { // If more than `_consecutiveScrollSwipeMaxIntervall` seconds passes between two scrollwheel swipes, then they aren't deemed consecutive.
    return [other()[@"consecutiveScrollSwipeMaxIntervall"] doubleValue];
}
+ (double)fastScrollExponentialBase { // How quickly fast scrolling gains speed.
    return [other()[@"fastScrollExponentialBase"] doubleValue]; // 1.05 //1.125 //1.0625 // 1.09375
}
+ (double)fastScrollFactor {
    return [other()[@"fastScrollFactor"] doubleValue];
}

// Smooth scrolling params




/*
 
 Old function from MainConfigInterface for reference:
 
 NSDictionary *scroll = [_configWithAppOverridesApplied objectForKey:kMFConfigKeyScroll];
 
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
 */

@end
