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

// Other

#define kMFBundleIDApp      @"com.nuebling.mac-mouse-fix"
#define kMFBundleIDHelper   @"com.nuebling.mac-mouse-fix.helper"

#define kMFRelativeAccomplicePath           @"Contents/Library/LaunchServices/Mac Mouse Fix Accomplice"
#define kMFRelativeHelperAppPath            @"Contents/Library/LoginItems/Mac Mouse Fix Helper.app"
#define kMFRelativeHelperExecutablePath     @"Contents/Library/LoginItems/Mac Mouse Fix Helper.app/Contents/MacOS/Mac Mouse Fix Helper"

#define kMFRelativeMainAppPathFromHelperBundle          @"../../../../"
#define kMFRelativeMainAppPathFromAccomplice            @"../../../../"
#define kMFRelativeMainAppPathFromAccompliceFolder      @"../../../"

#define kMFMainAppName      @"Mac Mouse Fix.app"
#define kMFAccompliceName   @"Mac Mouse Fix Accomplice"

#define kMFLaunchdHelperIdentifier  @"mouse.fix.helper"   // Keep this in sync with `Label` value in `default_launchd.plist`
#define kMFLaunchctlPath            @"/bin/launchctl"

// Accomplice Arguments

#define kMFAccompliceModeUpdate         @"update"
#define kMFAccompliceModeReloadHelper   @"reloadHelper"

// Website

#define kMFWebsiteAddress   @"https://noah-nuebling.github.io/mac-mouse-fix-website" //@"https://mousefix.org"

// Remapping dictionary keywords

typedef NSString*                                                       MFStringConstant; // Not sure if this is useful

#pragma mark - NSNotificationCenter notification names

#define kMFNotificationNameRemapsChanged                                @"remapsChanged"

#pragma mark - Config dict

#define kMFConfigKeyRemaps @"Remaps"
#define kMFConfigKeyScroll @"Scroll"
#define kMFConfigKeyOther @"Other" // TODO: This occurs in keypaths a few times - replace with constant (search for 'Other.')
#define kMFConfigKeyAppOverrides @"AppOverrides"

#pragma mark - Remaps dict

// Modification preconditions
// Buttons
#define kMFModificationPreconditionKeyButtons                           @"buttonModifiers"
#define kMFButtonModificationPreconditionKeyButtonNumber                @"button"
#define kMFButtonModificationPreconditionKeyClickLevel                  @"level"
// Keyboard
#define kMFModificationPreconditionKeyKeyboard                          @"keyboardModifiers"
// (^ Use NSModifierFlags (CGEventFlags would probably work, too) as values)

// Modified drag

// Trigger key
#define kMFTriggerKeyDrag                                               @"dragTrigger"
// Type key
#define kMFModifiedDragDictKeyType                                      @"modifiedDragType"
// Type values
#define kMFModifiedDragDictTypeTwoFingerSwipe                           @"twoFingerSwipe"
#define kMFModifiedDragDictTypeThreeFingerSwipe                         @"threeFingerSwipe"
#define kMFModifiedDragDictTypeFakeDrag                                 @"fakeDrag"
// Variant keys
#define kMFModifiedDragDictKeyFakeDragVariantButtonNumber               @"buttonNumber"

// Modified Scroll

// Trigger key
#define kMFTriggerKeyScroll                                             @"scrollTrigger"
// Type key
#define kMFModifiedScrollDictKeyType                                    @"modifiedScrollType"
// Type values
#define kMFModifiedScrollTypeZoom                                       @"zoom"
#define kMFModifiedScrollTypeHorizontalScroll                           @"horizontal"
#define kMFModifiedScrollTypePrecisionScroll                            @"precision"
#define kMFModifiedScrollTypeFastScroll                                 @"fast"

// Oneshot Actions

// Trigger Keys
#define kMFTriggerKeyButton                                             @"buttonTrigger" // Probs unnecessary
#define kMFButtonTriggerSubKeyButtonNumber                              @"button"
#define kMFButtonTriggerSubKeyClickLevel                                @"level"
#define kMFButtonTriggerSubKeyDuration                                  @"duration"
// Trigger Values
#define kMFButtonTriggerDurationClick                                   @"click"
#define kMFButtonTriggerDurationHold                                    @"hold"
// Type key
#define kMFActionDictKeyType                                            @"type"
// Type values
#define kMFActionDictTypeSymbolicHotkey                                 @"symbolicHotkey"
#define kMFActionDictTypeNavigationSwipe                                @"navigationSwipe"
#define kMFActionDictTypeSmartZoom                                      @"smartZoom"
#define kMFActionDictTypeKeyboardShortcut                               @"keyboardShortcut"
#define kMFActionDictTypeMouseButtonClicks                              @"mouseButton"

// Variant keys

// Generic variant key (Use when a variant consists of just one value - so when we only need one variant key)
#define kMFActionDictKeySingleVariant                                   @"variant"
// Keyboard shortcut variant keys
#define kMFActionDictKeyKeyboardShortcutVariantKeycode                  @"keycode"
#define kMFActionDictKeyKeyboardShortcutVariantModifierFlags            @"flags"
// Button click variant keys
#define kMFActionDictKeyMouseButtonClicksVariantButtonNumber            @"button"
#define kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks          @"nOfClicks"

// Variant values

// Navigation swipe variants
#define kMFNavigationSwipeVariantUp                                     @"up"
#define kMFNavigationSwipeVariantRight                                  @"right"
#define kMFNavigationSwipeVariantDown                                   @"down"
#define kMFNavigationSwipeVariantLeft                                   @"left"

// Symbolic Hotkeys
// (Used as oneshot action dict variants (for actions of type `kMFActionDictTypeSymbolicHotkey`))

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
} MFSymbolicHotkey;

// Mosue Buttons
// (Used as oneshot action dict variants (for actions of type `kMFActionDictTypeMouseButtonClicks`))
/// Note that CGMouseButton (and all CG APIs) assign 0 to left mouse button while MFMouseButtonNumber (and the rest of Mac Mouse Fix which doesn't use it yet) assigns 1 to lmb
typedef enum {
    kMFMouseButtonNumberLeft = 1,
    kMFMouseButtonNumberRight = 2,
    kMFMouseButtonNumberMiddle = 3,
} MFMouseButtonNumber;

@end

NS_ASSUME_NONNULL_END
