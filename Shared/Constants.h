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

#define kMFLaunchdHelperIdentifier  @"mouse.fix.helper" // Should rename to `kMFLaunchdHelperLabel`
    // ^ Keep this in sync with `Label` value in `default_launchd.plist`
    // ^ The old value @"mouse.fix.helper" was also used with the old prefpane version which could lead to conflicts. See Mail beginning with 'I attached the system log. Happening with this version too'. < We moved back to the old `mouse.fix.helper` label

// #define kMFLaunchdHelperIdentifier  @"com.nuebling.mac-mouse-fix.helper"
//      ^ We meant to move the launchd label over to a new one to avoid conlicts when upgrading from the old prefpane, but I think it can lead to more complications. Also we'd fragment things, because the first few versions of the app version already shipped with the old "mouse.fix.helper" label

#define kMFLaunchctlPath            @"/bin/launchctl"
#define kMFXattrPath                @"/usr/bin/xattr"
#define kMFOpenCLTPath              @"/usr/bin/open"


// Accomplice Arguments

#define kMFAccompliceModeUpdate         @"update"
#define kMFAccompliceModeReloadHelper   @"reloadHelper"

// Message dict keys

#define kMFMessageKeyMessage    @"message"
#define kMFMessageKeyPayload    @"payload"

// Other AddMode keys (more below)
#define kMFAddModeModificationPrecondition  @"addModeModifier"

// Website

#define kMFWebsiteAddress   @"https://noah-nuebling.github.io/mac-mouse-fix-website" //@"https://mousefix.org"

// Sparkle

// Only the main app deals with Sparkle, so maybe we shouldn't put these constants in this shared class

// Public encryption key for signing Sparkle Updates
//  Also found in Info.plist
#define kSUPublicEDKey ZC69ciDfGYN4t3kwRiPc2SC7J4hchv9w+FfVv59r4+U=

// Sub-URLs that, when appended to kMFWebsiteAddress, will point to an RSS Feed (.xml file) describing Sparkle Updates.
//  SUFeedURL is also found in Info.plist. Also see https://sparkle-project.org/documentation/customization/.
#define kSUFeedURLSub @"/appcast.xml"
#define kSUFeedURLSubBeta @"/appcast-beta.xml"

// Remapping dictionary keywords

typedef NSString*                                                       MFStringConstant; // Not sure if this is useful

#pragma mark - NSNotificationCenter notification names

#define kMFNotificationNameRemapsChanged                                @"remapsChanged"

#pragma mark - Config dict

#define kMFConfigKeyRemaps @"Remaps"
#define kMFConfigKeyScroll @"Scroll"
#define kMFConfigKeyOther @"Other" // TODO: This occurs in keypaths a few times - replace with constant (search for 'Other.')
#define kMFConfigKeyAppOverrides @"AppOverrides"

#pragma mark - Remaps array
// (^ Reuses many keys defined under "Remaps dict")
#define kMFRemapsKeyTrigger                     @"trigger"
#define kMFRemapsKeyModificationPrecondition    @"modifiers"
#define kMFRemapsKeyEffect                      @"effect"

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

// Trigger (value for key kMFRemapsKeyTrigger)
#define kMFTriggerDrag                                                  @"dragTrigger"
// Type key
#define kMFModifiedDragDictKeyType                                      @"modifiedDragType"
// Type values
#define kMFModifiedDragTypeTwoFingerSwipe                               @"twoFingerSwipe"
#define kMFModifiedDragTypeThreeFingerSwipe                             @"threeFingerSwipe"
#define kMFModifiedDragTypeFakeDrag                                     @"fakeDrag"
#define kMFModifiedDragTypeAddModeFeedback                              @"addModeDrag"
// Variant keys
#define kMFModifiedDragDictKeyFakeDragVariantButtonNumber               @"buttonNumber"

// Modified Scroll

// Trigger (value for key kMFRemapsKeyTrigger)
#define kMFTriggerScroll                                                @"scrollTrigger"
// Type key
#define kMFModifiedScrollDictKeyType                                    @"modifiedScrollType"
// Type values
#define kMFModifiedScrollTypeZoom                                       @"zoom"
#define kMFModifiedScrollTypeHorizontalScroll                           @"horizontal"
#define kMFModifiedScrollTypePrecisionScroll                            @"precision"
#define kMFModifiedScrollTypeFastScroll                                 @"fast"
#define kMFModifiedScrollTypeAddModeFeedback                            @"addModeScroll"

// Oneshot Actions
// TODO: Used to be named ActionDict... Rename to OneShot..., or OneShotDict

// Trigger Keys (value for key kMFRemapsKeyTrigger is dict using these keys)
#define kMFButtonTriggerKeyButtonNumber                                 @"button"
#define kMFButtonTriggerKeyClickLevel                                   @"level"
#define kMFButtonTriggerKeyDuration                                     @"duration"
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
#define kMFActionDictTypeAddModeFeedback                                @"addModeAction"

// Variant keys

// Generic variant key (Use when a variant consists of just one value - so when we only need one variant key)
#define kMFActionDictKeyGenericVariant                                   @"variant"
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

#define kMFMaxButtonNumber 32

@end

NS_ASSUME_NONNULL_END
