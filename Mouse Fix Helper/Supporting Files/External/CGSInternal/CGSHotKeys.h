/*
 * Copyright (C) 2007-2008 Alacatia Labs
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Joe Ranieri joe@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_HOTKEYS_INTERNAL_H
#define CGS_HOTKEYS_INTERNAL_H

#include "CGSConnection.h"

/// The system defines a limited number of "symbolic" hot keys that are remembered system-wide.  The
/// original intent is to have a common registry for the action of function keys and numerous
/// other event-generating system gestures.
typedef enum {
    
    // my own stuff
    kCGSHotKeyLaunchpad             = 160,
    kCGSHotKeySiri                  = 176,
    kCGSHotKeyNotificationCenter    = 163,
    kCGSHotKeyToggleDoNotDisturb    = 175,
    
    
	// full keyboard access hotkeys
	kCGSHotKeyToggleFullKeyboardAccess = 12,
	kCGSHotKeyFocusMenubar = 7,
	kCGSHotKeyFocusDock = 8,
	kCGSHotKeyFocusNextGlobalWindow = 9,
	kCGSHotKeyFocusToolbar = 10,
	kCGSHotKeyFocusFloatingWindow = 11,
	kCGSHotKeyFocusApplicationWindow = 27,
	kCGSHotKeyFocusNextControl = 13,
	kCGSHotKeyFocusDrawer = 51,
	kCGSHotKeyFocusStatusItems = 57,

	// screenshot hotkeys
	kCGSHotKeyScreenshot = 28,
	kCGSHotKeyScreenshotToClipboard = 29,
	kCGSHotKeyScreenshotRegion = 30,
	kCGSHotKeyScreenshotRegionToClipboard = 31,

	// universal access
	kCGSHotKeyToggleZoom = 15,
	kCGSHotKeyZoomOut = 19,
	kCGSHotKeyZoomIn = 17,
	kCGSHotKeyZoomToggleSmoothing = 23,
	kCGSHotKeyIncreaseContrast = 25,
	kCGSHotKeyDecreaseContrast = 26,
	kCGSHotKeyInvertScreen = 21,
	kCGSHotKeyToggleVoiceOver = 59,

	// Dock
	kCGSHotKeyToggleDockAutohide = 52,
	kCGSHotKeyExposeAllWindows = 32,
	kCGSHotKeyExposeAllWindowsSlow = 34,
	kCGSHotKeyExposeApplicationWindows = 33,
	kCGSHotKeyExposeApplicationWindowsSlow = 35,
	kCGSHotKeyExposeDesktop = 36,
	kCGSHotKeyExposeDesktopsSlow = 37,
	kCGSHotKeyDashboard = 62,
	kCGSHotKeyDashboardSlow = 63,

	// spaces (Leopard and later)
	kCGSHotKeySpaces = 75,
	kCGSHotKeySpacesSlow = 76,
	// 77 - fn F7 (disabled)
	// 78 - ⇧fn F7 (disabled)
	kCGSHotKeySpaceLeft = 79,
	kCGSHotKeySpaceLeftSlow = 80,
	kCGSHotKeySpaceRight = 81,
	kCGSHotKeySpaceRightSlow = 82,
	kCGSHotKeySpaceDown = 83,
	kCGSHotKeySpaceDownSlow = 84,
	kCGSHotKeySpaceUp = 85,
	kCGSHotKeySpaceUpSlow = 86,

	// input
	kCGSHotKeyToggleCharacterPallette = 50,
	kCGSHotKeySelectPreviousInputSource = 60,
	kCGSHotKeySelectNextInputSource = 61,

	// Spotlight
	kCGSHotKeySpotlightSearchField = 64,
	kCGSHotKeySpotlightWindow = 65,

	kCGSHotKeyToggleFrontRow = 73,
	kCGSHotKeyLookUpWordInDictionary = 70,
	kCGSHotKeyHelp = 98,

	// displays - not verified
	kCGSHotKeyDecreaseDisplayBrightness = 53,
	kCGSHotKeyIncreaseDisplayBrightness = 54,
} CGSSymbolicHotKey;

/// The possible operating modes of a hot key.
typedef enum {
	/// All hot keys are enabled app-wide.
	kCGSGlobalHotKeyEnable							= 0,
	/// All hot keys are disabled app-wide.
	kCGSGlobalHotKeyDisable							= 1,
	/// Hot keys are disabled app-wide, but exceptions are made for Accessibility.
	kCGSGlobalHotKeyDisableAllButUniversalAccess	= 2,
} CGSGlobalHotKeyOperatingMode;

/// Options representing device-independent bits found in event modifier flags:
typedef enum : unsigned int {
	/// Set if Caps Lock key is pressed.
	kCGSAlphaShiftKeyMask = 1 << 16,
	/// Set if Shift key is pressed.
	kCGSShiftKeyMask      = 1 << 17,
	/// Set if Control key is pressed.
	kCGSControlKeyMask    = 1 << 18,
	/// Set if Option or Alternate key is pressed.
	kCGSAlternateKeyMask  = 1 << 19,
	/// Set if Command key is pressed.
	kCGSCommandKeyMask    = 1 << 20,
	/// Set if any key in the numeric keypad is pressed.
	kCGSNumericPadKeyMask = 1 << 21,
	/// Set if the Help key is pressed.
	kCGSHelpKeyMask       = 1 << 22,
	/// Set if any function key is pressed.
	kCGSFunctionKeyMask   = 1 << 23,
	/// Used to retrieve only the device-independent modifier flags, allowing applications to mask
	/// off the device-dependent modifier flags, including event coalescing information.
	kCGSDeviceIndependentModifierFlagsMask = 0xffff0000U
} CGSModifierFlags;


#pragma mark - Symbolic Hot Keys


/// Gets the current global hot key operating mode for the application.
CG_EXTERN CGError CGSGetGlobalHotKeyOperatingMode(CGSConnectionID cid, CGSGlobalHotKeyOperatingMode *outMode);

/// Sets the current operating mode for the application.
///
/// This function can be used to enable and disable all hot key events on the given connection.
CG_EXTERN CGError CGSSetGlobalHotKeyOperatingMode(CGSConnectionID cid, CGSGlobalHotKeyOperatingMode mode);


#pragma mark - Symbol Hot Key Properties


/// Returns whether the symbolic hot key represented by the given UID is enabled.
CG_EXTERN bool CGSIsSymbolicHotKeyEnabled(CGSSymbolicHotKey hotKey);

/// Sets whether the symbolic hot key represented by the given UID is enabled.
CG_EXTERN CGError CGSSetSymbolicHotKeyEnabled(CGSSymbolicHotKey hotKey, bool isEnabled);

/// Returns the values the symbolic hot key represented by the given UID is configured with.
CG_EXTERN CGError CGSGetSymbolicHotKeyValue(CGSSymbolicHotKey hotKey, unichar *outKeyEquivalent, unichar *outVirtualKeyCode, CGSModifierFlags *outModifiers);


#pragma mark - Custom Hot Keys


/// Sets the value of the configuration options for the hot key represented by the given UID,
/// creating a hot key if needed.
///
/// If the given UID is unique and not in use, a hot key will be instantiated for you under it.
CG_EXTERN void CGSSetHotKey(CGSConnectionID cid, int uid, unichar options, unichar key, CGSModifierFlags modifierFlags);

/// Functions like `CGSSetHotKey` but with an exclusion value.
///
/// The exact function of the exclusion value is unknown.  Working theory: It is supposed to be
/// passed the UID of another existing hot key that it supresses.  Why can only one can be passed, tho?
CG_EXTERN void CGSSetHotKeyWithExclusion(CGSConnectionID cid, int uid, unichar options, unichar key, CGSModifierFlags modifierFlags, int exclusion);

/// Returns the value of the configured options for the hot key represented by the given UID.
CG_EXTERN bool CGSGetHotKey(CGSConnectionID cid, int uid, unichar *options, unichar *key, CGSModifierFlags *modifierFlags);

/// Removes a previously created hot key.
CG_EXTERN void CGSRemoveHotKey(CGSConnectionID cid, int uid);


#pragma mark - Custom Hot Key Properties


/// Returns whether the hot key represented by the given UID is enabled.
CG_EXTERN BOOL CGSIsHotKeyEnabled(CGSConnectionID cid, int uid);

/// Sets whether the hot key represented by the given UID is enabled.
CG_EXTERN void CGSSetHotKeyEnabled(CGSConnectionID cid, int uid, bool enabled);

#endif /* CGS_HOTKEYS_INTERNAL_H */
