//
// --------------------------------------------------------------------------
// Constants.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Constants : NSObject

// TODO:! Apply these thouroughly in TransformationManager and related classes
//      - Define constants for all the strings that are used several times throughout
//      - Maybe do a string replace

#pragma mark - NSNotificationCenter notification names

#define kMFNotificationNameRemapsChanged                @"remapsChanged"

#pragma mark - Remaps dictionary keys

typedef NSString*                                       MFStringConstant;

#define kMFRemapsKeyModifiedDrag                        @"modifiedDrag"

#define kMFModifiedDragTypeTwoFingerSwipe               @"twoFingerSwipe"
#define kMFModifiedDragTypeThreeFingerSwipe             @"threeFingerSwipe"

#define kMFModifierKeyButtons                           @"buttonModifiers" // Rename to kMFModificationPreconditionKey...
#define kMFModifierKeyKeyboard                          @"keyboardModifiers"

#define kMFActionArrayKeyType                           @"type"
#define kMFActionArrayKeyVariant                        @"value"
#define kMFActionArrayTypeSymbolicHotkey                @"symbolicHotkey"
#define kMFActionArrayTypeNavigationSwipe               @"navigationSwipe"
#define kMFActionArrayTypeSmartZoom                     @"smartZoom"

#define kMFNavigationSwipeVariantUp                     @"up"
#define kMFNavigationSwipeVariantRight                  @"right"
#define kMFNavigationSwipeVariantDown                   @"down"
#define kMFNavigationSwipeVariantLeft                   @"left"

typedef enum {
    kMFSHMissionControl = 32,
    kMFSHAppExpose = 33,
    kMFSHShowDesktop = 36,
    kMFSHLaunchpad = 160,
    kMFSHLookUp = 70,
    kMFSHAppSwitcher = 71,
    kMFSHMoveLeftASpace = 79,
    kMFSHMoveRightASpace = 81,
    kMFSHCycleThroughWindows = 27,
    
    kMFSHSwitchToDesktop1 = 118,
    kMFSHSwitchToDesktop2 = 119,
    kMFSHSwitchToDesktop3 = 120,
    kMFSHSwitchToDesktop4 = 121,
    kMFSHSwitchToDesktop5 = 122,
    kMFSHSwitchToDesktop6 = 123,
    kMFSHSwitchToDesktop7 = 124,
    kMFSHSwitchToDesktop8 = 125,
    kMFSHSwitchToDesktop9 = 126,
    kMFSHSwitchToDesktop10 = 127,
    kMFSHSwitchToDesktop11 = 128,
    kMFSHSwitchToDesktop12 = 129,
    kMFSHSwitchToDesktop13 = 130,
    kMFSHSwitchToDesktop14 = 131,
    kMFSHSwitchToDesktop15 = 132,
    kMFSHSwitchToDesktop16 = 133,
    
    kMFSHSpotlight = 64,
    kMFSHSiri = 176,
    kMFSHNotificationCenter = 163,
    kMFSHToggleDoNotDisturb = 175,
} SymbolicHotkeys;

@end

NS_ASSUME_NONNULL_END
