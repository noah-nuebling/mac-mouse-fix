//
// --------------------------------------------------------------------------
// SymbolicHotKeys.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/**
    System features such as 'Open Mission Control' have an associated number which is called the *SymbolicHotKey* or SHK.
    *SymbolicHotKey* APIs are used by macOS to map keyboard shortcuts and mouse buttons to these system features.
    
    We hijack the SHK system to trigger macOS features programmatically.
    
    Steps:
         1. Look up which keyboard shortcut is associated with the system feature we want to trigger
         2. (If there is no usable keyboard shortcut, modify the `keyboard shortcut -> system feature` map.)
         3. Simulate the keyboard shortcut – which will trigger the desired system feature
         4. (In case it was modified - reset the `keyboard shortcut -> system feature` map.)
         
    Alternatives:
        - There are also SHKs for mouse buttons – not only for keyboard shortcuts. We could possibly use those directly.
            (Src: /Users/Noah/Library/Preferences/com.apple.symbolichotkeys.plist)
        - In IOKit there's `IOHIDEventCreateSymbolicHotKeyEvent()` - this sounds like a promising way to simplify triggering of SHKs
            (But we'd first have to figure out how to use that function and how to convert from `IOHIDEvent` to `CGEvent`, so it might take a while. Also see `CGEventHIDEventBridge.h`)
        - HIToolbox APIs such as`CopySymbolicHotKeys()`
            I think these are more for registering new SHKs for the current app, not for modifying global SHK.
    
     Discussion:
         We implemented the SymbolicHotKey stuff really early in development (for MMF 1) the Apple Note below documents some of our thinking at the time.
    
    ----------------------------------------------
    
     Original Apple Note from 22.11.2018:
     
        Switching Spaces through Private API

        - [x] SOLVED - using symbolic hotkey private api

        Ways to go forward:
        * Try to really understand how other apps do it
        * Use CGSConnection.h to create custom symbolic hotkey, which we then trigger via CGEvent
            * private API not fully documented, pretty sure that we’d have to overridde existing hotkey, and/or activate it globally
        * Find way to make CGSSpace.h work properly
            * feel like I tried everything
        * Try to find, reverse engineer and emulate executable that parses symbolic hotkeys
            * (**harrrrrd**)

        Keyboard Shortcut Preferences File
        /Users/Noah/Library/Preferences/com.apple.symbolichotkeys.plist

        control key mask:
        * 0x040000:	262144
        * 0x840000:	8650752

        * left space: 		79
        * right space:		81
        * mission control: 	32
        * show all windows: 	33

        GitHub Projects that can do it:

            * [Demo of Spaces API discovered through RE](https://gist.github.com/puffnfresh/4054059) - old, no switching
            * [Spaces.h](https://github.com/NUIKit/CGSInternal/blob/master/CGSSpace.h) - “header for private Spaces Routines”

            * [hs._asm.undocumented.spaces](https://github.com/asmagill/hs._asm.undocumented.spaces) - Hammerspoon module for Space Switching functionality (built on Spaces.h) - relies on killing Dock, no animtions
            * [Hammerspoon](https://github.com/Hammerspoon/hammerspoon/tree/0.9.70) - “bridge between macOS and Lua Lang” (built on hs._asm.)

            * [Silica](https://github.com/ianyh/Silica/blob/master/Silica/CGSSpaces.h) - “window management framework” (interacts with private API but doesn't do space switching I believe)
            * [Amethyst](https://github.com/ianyh/Amethyst) - “window manager app” - “built on Silica”

        Steer Mouse Reverse Engineering:
            PS804ActionClass

*/

#import "WannaBePrefixHeader.h"
#import "SymbolicHotKeys.h"
#import "HelperUtility.h"
#import <Carbon/Carbon.h>

@implementation SymbolicHotKeys

CG_EXTERN CGError CGSGetSymbolicHotKeyValue(CGSSymbolicHotKey hotKey, unichar *outKeyEquivalent, unichar *outVirtualKeyCode, CGSModifierFlags *outModifiers);
CG_EXTERN CGError CGSSetSymbolicHotKeyValue(CGSSymbolicHotKey hotKey, unichar keyEquivalent, CGKeyCode virtualKeyCode, CGSModifierFlags modifiers);

+ (void)post:(CGSSymbolicHotKey)shk {
    
    unichar keyEquivalent;
    CGKeyCode keyCode;
    CGSModifierFlags modifierFlags;
    CGSGetSymbolicHotKeyValue(shk, &keyEquivalent, &keyCode, &modifierFlags);
    
    BOOL hotkeyIsEnabled = CGSIsSymbolicHotKeyEnabled(shk);
    BOOL oldBindingIsUsable = shkBindingIsUsable(keyCode, keyEquivalent);
    
    DDLogDebug(@"[SymbolicHotKeys +post]: hotkeyIsEnabled: %d, oldBindingIsUsable: %d", hotkeyIsEnabled, oldBindingIsUsable);
    
    if (!hotkeyIsEnabled) {
        CGSSetSymbolicHotKeyEnabled(shk, true);
    }
    if (!oldBindingIsUsable) {
        
        /// Temporarily set a usable binding for our shk
        unichar newKeyEquivalent = 65535; /// Tried to put an 'ö' face but it didn't work
        CGKeyCode newKeyCode = (CGKeyCode)shk + 400; /// Keycodes on my keyboard go up to like 125, but we use 400 just to be safely out of reach for a real kb
        CGSModifierFlags newModifierFlags = 10485760; /// 0 Didn't work in my testing. This seems to be the 'empty' CGSModifierFlags value, used to signal that no modifiers are pressed. TODO: Test if this works
        CGError err = CGSSetSymbolicHotKeyValue(shk, newKeyEquivalent, newKeyCode, newModifierFlags);
        if (err != kCGErrorSuccess) {
            DDLogError(@"Error setting shk params: %d", err);
            /// TODO: Do again or something if setting shk goes wrong?
    }
    
        /// Post keyboard events trigger shk
        postKeyboardEventsForSymbolicHotkey(newKeyCode, newModifierFlags);
    } else {
            
        /// Post keyboard events trigger shk
        postKeyboardEventsForSymbolicHotkey(keyCode, modifierFlags);
    }
    
    /// Restore original binding after short delay
    if (!hotkeyIsEnabled || !oldBindingIsUsable) { /// Only really need to restore hotKeyIsEnabled. But the other stuff doesn't hurt. Edit: now that we override oldBindingIsUsable to be false, we always need to restore.
        [NSTimer scheduledTimerWithTimeInterval:0.05
                                         target:[SymbolicHotKeys class]
                                       selector:@selector(restoreSymbolicHotkeyParameters_timerCallback:)
                                       userInfo:@{
                                           @"enabled": @(hotkeyIsEnabled),
                                           @"oldIsBindingIsUsable": @(oldBindingIsUsable),
                                           @"shk": @(shk),
                                           @"keyEquivalent": @(keyEquivalent),
                                           @"virtualKeyCode": @(keyCode),
                                           @"flags": @(modifierFlags),
                                       }
                                        repeats:NO];
    }
}


+ (void)restoreSymbolicHotkeyParameters_timerCallback:(NSTimer *)timer {
    
    CGSSymbolicHotKey shk = [timer.userInfo[@"shk"] intValue];
    BOOL enabled = [timer.userInfo[@"enabled"] boolValue];
    
    CGSSetSymbolicHotKeyEnabled(shk, enabled);
    
    BOOL oldIsBindingIsUsable = [timer.userInfo[@"oldIsBindingIsUsable"] boolValue];
    
    if (!oldIsBindingIsUsable) {
        /// Restore old, unusable binding
        unichar kEq = [timer.userInfo[@"keyEquivalent"] unsignedShortValue];
        CGKeyCode kCode = [timer.userInfo[@"virtualKeyCode"] unsignedIntValue];
        CGSModifierFlags mod = [timer.userInfo[@"flags"] intValue];
    CGSSetSymbolicHotKeyValue(shk, kEq, kCode, mod);
    }
}

static void postKeyboardEventsForSymbolicHotkey(CGKeyCode keyCode, CGSModifierFlags modifierFlags) {
    
    CGEventTapLocation tapLoc = kCGSessionEventTap;
    
    /// Create key events
    CGEventRef keyDown = CGEventCreateKeyboardEvent(NULL, keyCode, true);
    CGEventRef keyUp = CGEventCreateKeyboardEvent(NULL, keyCode, false);
    CGEventSetFlags(keyDown, (CGEventFlags)modifierFlags);
    CGEventFlags originalModifierFlags = getModifierFlags();
    CGEventSetFlags(keyUp, originalModifierFlags); // Restore original keyboard modifier flags state on key up. This seems to fix `[Modifiers getCurrentModifiers]`
    
    /// Send key events
    CGEventPost(tapLoc, keyDown);
    CGEventPost(tapLoc, keyUp);
    
    CFRelease(keyDown);
    CFRelease(keyUp);
}

static BOOL shkBindingIsUsable(CGKeyCode keyCode, unichar keyEquivalent) {
    
    /// Check if keyCode is reasonable
    
    if (keyCode >= 400) return NO;
    
    /// Check if keyCode matches char
    ///  Why we do this:
    ///     (For context for this comment, see postSymbolicHotkey() - where this function is called)
    ///     When using a 'non-standard' keyboard layout, then the keycodes for certain keyboard shortcuts can change.
    ///         This is because keycodes seem to be hard mapped to physical keys on the keyboard. But the character values for those keys depend on the keyboard mapping. For example, with a German layout, the characters for the 'Y' and 'Z' keys will be swapped. Therefore the key that produces 'Z' will have a different keycode with the German layout vs the English layout. Therefore the keycodes that trigger certain keyboard shortcuts also change when changing the keyboard layout.
    ///     Now the problem is, that CGSGetSymbolicHotKeyValue() doesn't take this into account. It always returns the keycode for the 'standard' layout, not the current layout.
    ///         (Update Nov 2024: I think this 'keycode for the standard layout' is called the 'virtual keycode')
    ///     Possible solutions:
    ///         1. Find an alternative function to CGSGetSymbolicHotKeyValue() that works properly.
    ///             - Problem: CGSInternal project on GH doesn't offer an alternative, so this probably involves reverse engineering Apple libraries -> a lot of work
    ///         2. Build a custom function that translates the keyEquivalent that CGSGetSymbolicHotKeyValue() returns into the correct keyCode according to the current layout.
    ///             - Problem: Some shortcuts may not have keyEquivalents
    ///             - Problem: There doesn't seem to be an API for this. UCKeyTranslate only translates keyCode -> char not char -> keyCode
    ///         3. Always assign a specific keyCode and then use that.
    ///             - We achieve this simply by overriding oldBindingIsUsable = NO -> It's easy
    ///             - Problem: This is around 30% - 100% slower when a functioning keyCode already exists.
    ///         4. Check if the combination of keyCode and keyEquivalent that CGSGetSymbolicHotKeyValue() returns corresponds to the current layout. If not, declare unusable
    ///             - This is like 3. but more optimized.
    ///             - I like this idea
    ///             -> We went with this approach
    ///
    
    NSString *chars;
    getCharsForKeyCode(keyCode, &chars);
    
    /// Check if keyCode and keyEquivalent (the args to this function) match the current keyboard layout
    
    if (chars.length != 1) return NO;
    if (keyEquivalent != [chars characterAtIndex:0]) return NO;
    
    /// Return
    return YES;
}

static BOOL getCharsForKeyCode(CGKeyCode keyCode, NSString **chars) {
    /// Get chars for a given keycode. Based on currently active keyboard layout
    /// Returns success
    ///
    /// TODO: Think about putting this into some utility class
    
    /// Init result
    
    *chars = @"";
    
    /// Get layout
    
    const UCKeyboardLayout *layout = NULL;
    
    TISInputSourceRef inputSource = TISCopyCurrentKeyboardInputSource() /*TISCopyCurrentKeyboardLayoutInputSource()*/; /// Not sure what's better
    
    if (inputSource != NULL) {
        CFDataRef layoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData);
        if (layoutData != NULL) {
            layout = (UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
        }
    }
    
    if (layout == NULL) {
        *chars = @"";
        if (inputSource != NULL) {
            CFRelease(inputSource);
        }
        return NO;
    }
    
    /// Get other input params
    
    UInt16 keyCodeForLayout = keyCode;
    UInt16 keyAction = kUCKeyActionDisplay; /// Should maybe be using kUCKeyActionDown instead. Some SO poster said it works better.
    UInt32 modifierKeyState = 0; /// The keyEquivalent arg is not affected by modifier flags. It's always lower case despite Shift, etc... That's why we can just set this to 0.
    UInt32 keyboardType = LMGetKbdType(); 
    OptionBits keyTranslateOptions = kUCKeyTranslateNoDeadKeysBit /*kUCKeyTranslateNoDeadKeysMask*/; /// Not sure what's correct. Edit: Obv mask is not appropriate here.
    
    /// Declare return buffers
    
    UInt32 deadKeyState = 0;
    UniCharCount maxStringLength = 4; /// 1 Should be enough I think
    UniCharCount actualStringLength = 0;
    UniChar unicodeString[maxStringLength];
    
    /// Translate
    
    OSStatus r = UCKeyTranslate(layout, keyCodeForLayout, keyAction, modifierKeyState, keyboardType, keyTranslateOptions, &deadKeyState, maxStringLength, &actualStringLength, unicodeString);
    
    /// Check errors
    if (r != noErr) {
        DDLogError(@"UCKeyTranslate() failed with error code: %d", r);
        *chars = @"";
        CFRelease(inputSource);
        return NO;
    }
    
    /// Get result
    *chars = [NSString stringWithCharacters:unicodeString length:actualStringLength];
    /// Release inputSource
    CFRelease(inputSource);
    /// Return success
    return YES;
}

@end
