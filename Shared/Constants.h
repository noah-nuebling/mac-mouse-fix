//
// --------------------------------------------------------------------------
// Constants.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Constants : NSObject

/// Input processing

typedef enum {
    kMFAxisNone,
    kMFAxisHorizontal,
    kMFAxisVertical,
} MFAxis;

typedef enum {
    kMFDirectionNone,
    kMFDirectionUp,
    kMFDirectionRight,
    kMFDirectionDown,
    kMFDirectionLeft,
} MFDirection;

/// Bundles and Bezelservices

/// Added some x's to the bundleID. See notes.md for context.
#define kMFBundleIDApp      @"com.nuebling.mac-mouse-fix"
#define kMFBundleIDHelper   @"com.nuebling.mac-mouse-fix.helper"

//#define kMFRelativeAccomplicePath           @"Contents/Library/LaunchServices/Mac Mouse Fix Accomplice"
#define kMFRelativeHelperAppPath            @"Contents/Library/LoginItems/Mac Mouse Fix Helper.app"
#define kMFRelativeHelperExecutablePath     @"Contents/Library/LoginItems/Mac Mouse Fix Helper.app/Contents/MacOS/Mac Mouse Fix Helper"

#define kMFRelativeMainAppPathFromHelperBundle          @"../../../../"
//#define kMFRelativeMainAppPathFromAccomplice            @"../../../../"
//#define kMFRelativeMainAppPathFromAccompliceFolder      @"../../../"

#define kMFMainAppName      @"Mac Mouse Fix.app"
#define kMFAccompliceName   @"Mac Mouse Fix Accomplice"
#define kMFHelperName       @"Mac Mouse Fix Helper.app"

#define kMFLaunchdHelperIdentifier  @"mouse.fix.helper" /// Should rename to `kMFLaunchdHelperLabel`
/// ^ Keep this in sync with `Label` value in `default_launchd.plist`
/// ^ The old value "mouse.fix.helper" was also used with the old prefpane version which could lead to conflicts. See Mail beginning with 'I attached the system log. Happening with this version too'. Edit: We moved back to the old `mouse.fix.helper` label for the app version of Mac Mouse Fix. Reasoning:
///      We meant to move the launchd label over to a new one to avoid conlicts when upgrading from the old prefpane, but I think it can actually lead to more complications. Also we'd fragment things, because the first few versions of the app version already shipped with the old "mouse.fix.helper" label.

#define kMFLaunchdHelperIdentifierSM  @"com.nuebling.mac-mouse-fix.helper"
/// ^ Keep this in sync with `sm_launchd.plist`
/// ^ We finally moved to this new label when moving to the new Service Management API for enabling the Helper as background task for Ventura.
/// We experienced strange issues when using the old label, so we're giving this new one a try.

#define kMFLaunchctlPath            @"/bin/launchctl"
#define kMFXattrPath                @"/usr/bin/xattr"
#define kMFOpenCLTPath              @"/usr/bin/open"
#define kMFTccutilPath              @"/usr/bin/tccutil"


/// Accomplice Arguments

#define kMFAccompliceModeUpdate         @"update"
#define kMFAccompliceModeReloadHelper   @"reloadHelper"

/// Message dict keys

#define kMFMessageKeyMessage        @"message"
#define kMFMessageKeyBundleVersion  @"version"
#define kMFMessageKeyPayload        @"payload"

/// Other AddMode keys (more below)
#define kMFAddModeModificationPrecondition  @"addModeModifier"

/// Web URLs

#define kMFWebsiteAddress  @"https://noah-nuebling.github.io/mac-mouse-fix-website"
#define kMFWebsiteRepoAddressRaw @"https://raw.githubusercontent.com/noah-nuebling/mac-mouse-fix-website/gh-pages"
#define kMFUpdateFeedRepoAddressRaw @"https://raw.githubusercontent.com/noah-nuebling/mac-mouse-fix/update-feed"
#define kMFLicenseInfoURLSub @"licenseinfo/config.json"

/// Sparkle

/// Only the main app deals with Sparkle, so maybe we shouldn't put these constants in this shared class

/// Public encryption key for signing Sparkle Updates
///  Also found in Info.plist
#define kSUPublicEDKey ZC69ciDfGYN4t3kwRiPc2SC7J4hchv9w+FfVv59r4+U=

/// Sub-URLs that, when appended to kMFWebsiteAddress, will point to an RSS Feed (.xml file) describing Sparkle Updates.
///  SUFeedURL is also found in Info.plist. Also see https://sparkle-project.org/documentation/customization/.
#define kSUFeedURLSub @"appcast.xml"
#define kSUFeedURLSubBeta @"appcast-pre.xml"

/// Remapping dictionary keywords

typedef NSString*                                                       MFStringConstant; // Not sure if this is useful

#pragma mark - NSNotificationCenter notification names

//#define kMFNotifCenterNotificationNameRemapsChanged                                @"remapsChanged"

#pragma mark - Config dict

#define kMFConfigKeyRemaps @"Remaps"
#define kMFConfigKeyScroll @"Scroll"
#define kMFConfigKeyPointer @"Pointer"
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

// Trigger (Not just key, also value for key kMFRemapsKeyTrigger)
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

// Trigger key (value for key kMFRemapsKeyTrigger)
#define kMFTriggerScroll                                                @"scrollTrigger"
// Type keys
#define kMFModifiedScrollDictKeyInputModificationType                   @"modifiedScrollInputModification"
#define kMFModifiedScrollDictKeyEffectModificationType                  @"modifiedScrollEffectModification"
// Type values
#define kMFModifiedScrollInputModificationTypePrecisionScroll                               @"precision"
#define kMFModifiedScrollInputModificationTypeQuickScroll                                   @"fast"
#define kMFModifiedScrollEffectModificationTypeZoom                                         @"zoom"
#define kMFModifiedScrollEffectModificationTypeHorizontalScroll                             @"horizontal"
#define kMFModifiedScrollEffectModificationTypeFourFingerPinch                              @"fourFingerPinch"
#define kMFModifiedScrollEffectModificationTypeThreeFingerSwipeHorizontal                   @"threeFingerSwipeHorizontal"
#define kMFModifiedScrollEffectModificationTypeRotate                                       @"rotate"
#define kMFModifiedScrollEffectModificationTypeCommandTab                                   @"commandTab"
#define kMFModifiedScrollEffectModificationTypeAddModeFeedback                              @"addModeScroll"

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
#define kMFActionDictTypeSystemDefinedEvent                             @"systemDefinedEvent"
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

#define kMFActionDictKeySystemDefinedEventVariantType                   @"systemDefinedEventType"
#define kMFActionDictKeySystemDefinedEventVariantModifierFlags          @"flags"


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
    
    /// These shk are assigned to some function keys on apple keyboards
    
    kMFFunctionKeySHKMissionControl = 108,
    kMFFunctionKeySHKDictation = 186,
    kMFFunctionKeySHKSpotlight = 187,
    kMFFunctionKeySHKSwitchKeyboard = 188,
    kMFFunctionKeySHKDoNotDisturb = 189,
    
    kMFFunctionKeySHKLaunchpad = 173,
    
} MFSymbolicHotkey;

/// SystemEvents

///  NSEvents with type systemDefined and subtype 8 are fired when pressing some keys on Apple keyboards
///         All the interesting info is in the `data1` field

typedef enum {

    /// These types are found in the `data1` field, shifted left by 16 bits
    
    kMFSystemEventTypeBrightnessDown = 3,
    kMFSystemEventTypeBrightnessUp = 2,
    kMFSystemEventTypeMediaBack = 16 + 4,
    kMFSystemEventTypeMediaPlayPause = 16 + 0,
    kMFSystemEventTypeMediaForward = 16 + 3,
    kMFSystemEventTypeVolumeMute = 7,
    kMFSystemEventTypeVolumeDown = 1,
    kMFSystemEventTypeVolumeUp = 0,
    
    kMFSystemEventTypeKeyboardBacklightDown = 22,
    kMFSystemEventTypeKeyboardBacklightUp = 21,
    
    kMFSystemEventTypePower = 6,
    kMFSystemEventTypeCapsLock = 4, /// Should probably disable remapping to this. Doesn't work
    
} MFSystemDefinedEventType;

enum {
    /// More definitions for the `data1` field

    kMFSystemDefinedEventPressedMask = 1 << 8, ///  0 is keyDown, 1 is keyUp
    kMFSystemDefinedEventBase = (1 << 9) | (1 << 11), /// These two bits are always set    
};

// Mosue Buttons
// (Used as oneshot action dict variants (for actions of type `kMFActionDictTypeMouseButtonClicks`))
/// Note that CGMouseButton (and all CG APIs) assign 0 to left mouse button while MFMouseButtonNumber (and the rest of Mac Mouse Fix which doesn't use it yet) assigns 1 to lmb
typedef enum {
    kMFMouseButtonNumberLeft = 1,
    kMFMouseButtonNumberRight = 2,
    kMFMouseButtonNumberMiddle = 3,
} MFMouseButtonNumber;

#define kMFMaxButtonNumber 32

///
/// CGEventFields
///

/// Most CGEventFields we discovered aren't documented here but are indirectly documented in the touchSimulator classes

typedef CF_ENUM(uint32_t, MFCGEventField) {
    
    kMFCGEventFieldSenderID = 87, /// Use `CGEventGetSenderID()` instead of using this directly
};

///
/// Processes
///

/// Define invalid process identifier
///     - There should be a constant already defined for this somewhere inside macOS, but I can't find it.
///     - -1 as the invalid PID is a convention on POSIX systems according to ChatGPT
#define kMFInvalidPID -1

@end

NS_ASSUME_NONNULL_END
