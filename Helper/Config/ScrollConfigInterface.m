//
// --------------------------------------------------------------------------
// ScrollConfigInterface.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ScrollConfigInterface.h"
#import "MainConfigInterface.h"
#import "Constants.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"

@implementation ScrollConfigInterface

// Constants

NSDictionary *_stringToEventFlagMask;

// Initialize

+ (void)initialize
{
    if (self == [ScrollConfigInterface class]) {
        _stringToEventFlagMask = @{
            @"command" : @(kCGEventFlagMaskCommand),
            @"control" : @(kCGEventFlagMaskControl),
            @"option" : @(kCGEventFlagMaskAlternate),
            @"shift" : @(kCGEventFlagMaskShift),
        };
    }
}

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

// Interface

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

// Scroll ticks/swipes, fast scroll, and ticksPerSecond

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
+ (double)ticksPerSecondSmoothingInputValueWeight {
    return 0.5;
}
+ (double)ticksPerSecondSmoothingTrendWeight {
    return 0.2;
}
//+ (double)ticksPerSecondSmoothingInitialLevel {
//    return 0.0;
//}
//+ (double)ticksPerSecondSmoothingInitialTrend {
//    return 0.0;
//}

// Smooth scrolling params


+ (NSUInteger)pxPerTickBase {
    return [[smooth() objectForKey:@"pxPerStep"] intValue];
}
+ (NSUInteger)msPerStep {
    return [[smooth() objectForKey:@"msPerStep"] intValue];
}
+ (double)frictionCoefficient {
    return [[smooth() objectForKey:@"friction"] doubleValue];
}
+ (double)frictionDepth {
    return [[smooth() objectForKey:@"frictionDepth"] doubleValue];
}
+ (double)accelerationForScrollBuffer { // TODO: Unused, remove
    return [[smooth() objectForKey:@"acceleration"] doubleValue];
}
+ (id<RealFunction>)accelerationCurve {
    
//    NSArray *controlPoints
    
    return nil;
}

+ (NSUInteger)nOfOnePixelScrollsMax {
    return [[smooth() objectForKey:@"onePixelScrollsLimit"] intValue]; // After opl+1 frames of only scrolling 1 pixel, scrolling stops. Should probably change code to stop after opl frames.
}



// Keyboard modifiers

// Event flag masks
+ (CGEventFlags)horizontalScrollModifierKeyMask {
    return (CGEventFlags)[_stringToEventFlagMask[mod()[@"horizontalScrollModifierKey"]] unsignedLongLongValue];
}
+ (CGEventFlags)magnificationScrollModifierKeyMask {
    return (CGEventFlags)[_stringToEventFlagMask[mod()[@"magnificationScrollModifierKey"]] unsignedLongLongValue];
}
// Modifier enabled
+ (BOOL)horizontalScrollModifierKeyEnabled {
    return [mod()[@"horizontalScrollModifierKeyEnabled"] boolValue];
}
+ (BOOL)magnificationScrollModifierKeyEnabled {
    return [mod()[@"magnificationScrollModifierKeyEnabled"] boolValue];
}


/*
 
 Old function from MainConfigInterface for reference:
 This class superseeds this function. This is for reference if sth goes wrong.
 
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
