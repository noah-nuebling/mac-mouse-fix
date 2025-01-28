//
// --------------------------------------------------------------------------
// SymbolicHotKeys.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/**
    System features such as 'Open Mission Control' have an associated identifier which is called the *SymbolicHotKey* or SHK.
    In macOS' APIs, *SymbolicHotKeys* are used to map keyboard shortcuts and mouse buttons to the associated system features.
    
    We hijack the SHK system to trigger macOS features programmatically.
    
    Steps: (Nov 2024)
         1. Look up which keyboard shortcut is associated with the system feature we want to trigger
         2. (If there is no usable keyboard shortcut, modify the `keyboard shortcut -> system feature` map.)
         3. Simulate the keyboard shortcut – which will trigger the desired system feature
         4. (In case it was modified - reset the `keyboard shortcut -> system feature` map.)
         
    Alternatives:
        - There are also SHKs for mouse buttons – not only for keyboard shortcuts. We could possibly use those directly.
            (Src: the `type: button` entries inside ~/Library/Preferences/com.apple.symbolichotkeys.plist)
        - In IOKit there's `IOHIDEventCreateSymbolicHotKeyEvent()` - this sounds like a promising way to simplify triggering of SHKs
            (But we'd first have to figure out how to use that function and how to convert from `IOHIDEvent` to `CGEvent`, so it might take a while.)
            (Also see `CGEventHIDEventBridge.h`)
        - Public HIToolbox APIs such as`CopySymbolicHotKeys()`
            I think these are more for registering new SHKs for the current app, not for modifying/triggering global SHK – but I haven't tested them, yet.
    
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
#import "SharedUtility.h"

@implementation SymbolicHotKeys

/// Define extern CGS function
///     All the other extern functions we need are already defined in `CGSHotKeys.h`
CG_EXTERN CGError CGSSetSymbolicHotKeyValue(CGSSymbolicHotKey hotKey, unichar keyEquivalent, CGKeyCode virtualKeyCode, CGSModifierFlags modifiers);


/**
    Define constants
     
    On the `kEmpty` constants:
        When you call `CGSGetSymbolicHotKeyValue()` on a SHK which is assigned to `none` by macOS, you see the following values:
        ```
        keyEquivalent:      65535
        virtualKeyCode:     65535
        modifierFlags:      0
        ```
        (When you 'Restore Defaults', macOS assigns 'Show Launchpad' to 'none' - that's how I could find these values.)
    
    We call these values the 'empty' values.
    Note that `65535 == (1<<16)-1` - it's the largest number that fits into an unsigned 16 bit int.
    
    On `keyEquivalent`:
        CGSGetSymbolicHotKeyValue() seems to spit out 65535 as the keyEquivalent when it can't find an actual keyEquivalent unicode character (Which is commonly the case, e.g. for arrow keys.)
        -> So we're using it in the same way - signalling that there is no keyEquivalent. In my testing the keyBinding always showed up as 'none' under the `Keyboard Shortcut...` System Settings (Using macOS Sequoia 15.1) which seems appropriate.
          (But if you map an SHK to an arrow key it will also have the 65535 keyEquivalent but show up as an arrow instead of 'none' in System Settings. Not sure how that works.)
    On `modifierFlags`:
        Setting this to the 'empty' value (0) renders the SHK unusable. I'm basing this on old comments and vague memories, but I'm but not sure.
    On`virtualKeyCode`
        Not sure what happens when this is set to its 'empty' value (65535). But based on logic, I think either `keyEquivalent` or `virtualKeyCode` need to be non-empty for the system to have any chance to map a keyboardEvent to the `symbolicHotKey` that these values belong to.

 */

#define kEmptyKeyEquivalent ((unichar)65535)
#define kEmptyVKC           ((CGKeyCode)65535)
#define kEmptyModifierFlags ((CGSModifierFlags)0)
#define kOutOfReachVKC      ((CGKeyCode)400)             /// VirtualKeyCodes (VKCs) on my keyboard go up to like 125, but we use 400 just to be safely out of reach of a real kb

+ (void)post:(CGSSymbolicHotKey)shk {

    /// Thread safety:
    ///     (Last updated: Nov 2024)
    ///     AFAIK, the only shared mutable state are the `CGS` functions that modify the global SHK configuration. The only two 'entry points' of this file which could produce simultaneous accesses to this shared state are the `+post:` and `+restoreSymbolicHotkeyParameters_timerCallback:` methods.
    ///     If we locked those two 'entry points' with a mutex and then never acquire another lock while holding that mutex, then our code should be guaranteed race condition and deadlock free.
    ///     However, I don't know whether functions such as `CGSSetSymbolicHotKeyValue()` acquire a lock or not, so I'm not confident that there can never be a deadlock if we used mutexes here.
    ///     -> I think the better solution would be to make sure that all the 'entry points' simply run on the same runLoop/thread. Alternatively, we could async dispatch to a dispatchQueue, but controlling the runLoop would be simpler and cleaner I think.

    DDLogDebug(@"[SymbolicHotKeys +post:] running on thread: %@", NSThread.currentThread);
    
    unichar keyEquivalent;
    CGKeyCode virtualKeyCode;
    CGSModifierFlags modifierFlags;
    CGSGetSymbolicHotKeyValue(shk, &keyEquivalent, &virtualKeyCode, &modifierFlags);
    
    BOOL hotkeyIsEnabled = CGSIsSymbolicHotKeyEnabled(shk);
    BOOL oldBindingIsUsable = shkBindingIsUsable(virtualKeyCode, keyEquivalent, modifierFlags);
    
    DDLogDebug(@"[SymbolicHotKeys +post:] hotkeyIsEnabled: %d, oldBindingIsUsable: %d,\nkeyEquivalent: %d, VKC: %d, modifierFlags: %@", hotkeyIsEnabled, oldBindingIsUsable, keyEquivalent, virtualKeyCode, binarystring(modifierFlags));
    
    if (!hotkeyIsEnabled) {
        CGSSetSymbolicHotKeyEnabled(shk, true);
    }
    if (!oldBindingIsUsable) {
        
        /// Temporarily set a usable binding for our shk
        unichar newKeyEquivalent = kEmptyKeyEquivalent;
        CGKeyCode newVirtualKeyCode = kOutOfReachVKC + (CGKeyCode)shk;
        CGSModifierFlags newModifierFlags = kCGSNumericPadKeyMask | kCGSFunctionKeyMask;
        /// ^ Why use fn flag? The fn flag indicates either the fn modifier being held or a function key being pressed.
        ///     1. Function keys can be directly mapped to features like Mission Control.
        ///     2. Normal keys like 'P' cannot be mapped to features like Mission Control without any modifiers being held.
        ///     -> The fn flag should solve both of these cases.
        ///     Testing: 0 (aka `kEmptyModifierFlags`) didn't work in my testing. Using fn or fn | numpad flags worked in my testing.
        ///     Note In older MMF versions, we used numpad | fn flags – probably because we saw that those are eternalmods of the arrow keys. But I don't think numpad really makes sense here (?) Still, it works, so we're leaving it.
        ///     Note:
        ///         In the new keyboard simulation code we built inside `EventLoggerForBrad`, we have more sophisticated logic for this stuff, which will completely replace this.
        ///         TODO: Maybe merge this note into EventLoggerForBrad before we replace this?
        CGError err = CGSSetSymbolicHotKeyValue(shk, newKeyEquivalent, newVirtualKeyCode, newModifierFlags);
        if (err != kCGErrorSuccess) {
            DDLogError(@"Error setting shk params: %d", err); /// We still post the keyboard events in this case, bc maybe it will still worked despite the error?
        }
    
        /// Post keyboard events
        postKeyboardEventsForSymbolicHotKey(newVirtualKeyCode, keyEquivalent, newModifierFlags);
    } else {
            
        /// Post keyboard events
        postKeyboardEventsForSymbolicHotKey(virtualKeyCode, keyEquivalent, modifierFlags);
    }
    
    /// Restore original binding after short delay
    if (!hotkeyIsEnabled || !oldBindingIsUsable) {
        [NSTimer scheduledTimerWithTimeInterval:0.05
                                         target:[SymbolicHotKeys class]
                                       selector:@selector(restoreSymbolicHotkeyParameters_timerCallback:)
                                       userInfo:@{
                                           @"enabled": @(hotkeyIsEnabled),
                                           @"oldBindingIsUsable": @(oldBindingIsUsable),
                                           @"shk": @(shk),
                                           @"keyEquivalent": @(keyEquivalent),
                                           @"virtualKeyCode": @(virtualKeyCode),
                                           @"flags": @(modifierFlags),
                                       }
                                        repeats:NO];
    }
}

+ (void)restoreSymbolicHotkeyParameters_timerCallback:(NSTimer *)timer {
    
    DDLogDebug(@"SymbolicHotKeys: timerCallback running on thread: %@", NSThread.currentThread);
    
    CGSSymbolicHotKey shk = [timer.userInfo[@"shk"] intValue];
    
    /// Restore enabled-state
    BOOL enabled = [timer.userInfo[@"enabled"] boolValue];
    CGSSetSymbolicHotKeyEnabled(shk, enabled);
    
    /// Restore old "unusable" binding
    ///     We wanna do this for the case that the binding *is* actually usable with a physical keyboard, but "unusable" for our code due to keyboard layout complications (See `shkBindingIsUsable()`)
    BOOL oldBindingIsUsable = [timer.userInfo[@"oldBindingIsUsable"] boolValue];
    if (!oldBindingIsUsable) {
        unichar kEq = [timer.userInfo[@"keyEquivalent"] unsignedShortValue];
        CGKeyCode kCode = [timer.userInfo[@"virtualKeyCode"] unsignedIntValue];
        CGSModifierFlags mod = [timer.userInfo[@"flags"] intValue];
        CGSSetSymbolicHotKeyValue(shk, kEq, kCode, mod);
    }
}

static void postKeyboardEventsForSymbolicHotKey(CGKeyCode virtualKeyCode, unichar keyEquivalent, CGSModifierFlags modifierFlags) {
    
    /// Constants
    const CGEventTapLocation tapLoc = kCGSessionEventTap;
    const CGEventSourceRef source = NULL;
    
    /// Create key events
    CGEventRef keyDown = CGEventCreateKeyboardEvent(source, virtualKeyCode, true);
    CGEventRef keyUp = CGEventCreateKeyboardEvent(source, virtualKeyCode, false);
    
    /// Set modifierFlags
    CGEventFlags originalModifierFlags = getModifierFlagsWithEvent(keyDown);
    CGEventSetFlags(keyDown, (CGEventFlags)modifierFlags);
    CGEventSetFlags(keyUp, originalModifierFlags); /// Restore original keyboard modifier flags state on key up. This seems to fix `[Modifiers getCurrentModifiers]`
    
    /// Send key events
    CGEventPost(tapLoc, keyDown);
    CGEventPost(tapLoc, keyUp);
    
    CFRelease(keyDown);
    CFRelease(keyUp);
}

static BOOL shkBindingIsUsable(CGKeyCode virtualKeyCode, unichar keyEquivalent, CGSModifierFlags modifierFlags) {
    
    /// Discussion
    ///
    /// Why check if a binding `isUsable`?
    ///     If there's an existing, usable binding for an SHK, then it's most efficient to use that.
    ///         Creating a new binding is around 30% - 100% slower in my testing.
    ///
    ///     However, we should err on the side of creating a new binding, if we're not sure that the binding `isUsable`. (Because otherwise the SHK might not be triggered correctly.)
    ///
    /// Why check if `virtualKeyCode` matches the `keyEquivalent`?
    ///     Explanation of basic concepts:
    ///     A VKC is specific to a hardware key, but does not necessarily correspond to a specific character on the keyboard. The VKC can be mapped to a unicode character using a keyboard layout.
    ///     The `keyEquivalent` is supposed to be the actual letter/symbol on the keyboard as a unicode character.
    ///     The `CGS...SymbolicHotKey...()` APIs seem to be defined in terms of a keyEquivalent *and* a VKC.
    ///
    ///     Based on my observations, the keyEquivalent takes precendence over the VKC.
    ///     That means, if you're using a German layout, the 'Y' key on the keyboard might have VKC 222, and on a US layout the 'Y' key might have VKC 333, but if Mission Control is mapped to Command-D, then it will still work under both keyboard layouts, because the system cares about the keyEquivalent (D) more than the VKC (222 or 333)
    ///
    ///     However, for our programmatic triggering of SymbolicHotKeys, this is problematic, because we simply create a CGEvent with a VKC and then send it. After we send the event, macOS will seemingly translate the VKC to a keyEquivalent unicode char, using the current keyboard layout. Then it will decide whether to execute the SHK based on whether the keyEquivalent it computed from the event matches the keyEquivalent defined for a SHK.
    ///
    ///     Possible solutions:
    ///         1. Use `CGEventKeyboardSetUnicodeString()` to explicitly set the keyEquivalent on the events we send to try and prevent macOS from computing the keyEquivalent itself based on the current keyboard layout. -> I tested this and it didn't seem to work.
    ///             The docs are pretty relevant: https://developer.apple.com/documentation/coregraphics/1456028-cgeventkeyboardsetunicodestring
    ///         2. Send the events with a custom `CGEventSource`, which we configure using `CGEventSourceSetKeyboardType()` to try and force macOS' SHK handling code to use some default keyboard layout instead of the current keyboard layout. -> Tested this, didn't work.
    ///             Sidenote: About the keyboardType values for CGEventSourceSetKeyboardTypeBased() and LMGetKbdType() APIs – I based them on the old Gestalt.h header mentioned here: https://stackoverflow.com/questions/54428368/get-keyboard-type-macos-and-detect-built-in-onscreen-or-usb
    ///         3. Find/Build a function that maps `(keyEquivalent, currentKeyboardLayout) -> virtualKeyCode`
    ///             Then we could create a CGEvent with the exact `virtualKeyCode` that macOS' SHK handling code will convert to the correct `keyEquivalent` and therefore correctly triggers the SHK we desire.
    ///             This should always work. However, Apple only provides `UCKeyTranslate()` which maps `(virtualKeyCode, currentKeyboardLayout) -> keyEquivalent`. (The inverse of what we want)
    ///                 To invert it we'd have to iterate over all `virtualKeyCode`s and apply `UCKeyTranslate()` to every single one, until we find the `keyEquivalent` we're looking for. This seems annoying.
    ///         4. Check whether the combination of `virtualKeyCode` and `keyEquivalent` that CGSGetSymbolicHotKeyValue() returns, corresponds to the current layout.
    ///             If yes, then we can simply create our CGEvent with that `virtualKeyCode` - this should always be translated to the correct `keyEquivalent` by macOS' SHK handling code - and therefore correctly trigger the SHK.
    ///             Otherwise, just declare the binding 'unusable' (return NO from this function) – then we will create a fresh SHK binding that doesn't have a `keyEquivalent` at all - only a `virtualKeyCode`. This means processing is independent of the current keyboardLayout, and the SHK should always be triggered correctly. This is slower but it should ensure consistency.
    ///             -> **We went with this approach**
    ///
    /// Alternatives:
    ///     - (Since we implemented solution 4.) the goal of this is to see whether a CGEvent, constructed using `virtualKeyCode`, would successfully cause macOS to trigger the desired SHK.
    ///       -> Alternatively we might use `SLSIsEventMatchingSymbolicHotKey()` to find this out.
    ///       -> You can find interesting functions by typing this in LLDB: `image lookup -r -n SymbolicHotKey`

    /// Check if VKC is empty
    if (virtualKeyCode == kEmptyVKC) { /// Can the `virtualKeyCode` ever be empty with only the `keyEquivalent` filled? Logically it should work, but I've never seen that.
        DDLogDebug(@"SymbolicHotKeys: isUsable: Not usable due to empty VKC");
        return NO;
    }
    
    /// Check if VKC is out of reach
    ///     We don't need to check for this, because while an 'out of reach' VKC can (probably) never be triggered with a real keyboard, we should still be able to trigger it programmatically.
    if ((false)) {
        if (virtualKeyCode >= kOutOfReachVKC) {
            DDLogDebug(@"SymbolicHotKeys: isUsable: Not usable due to out-of-reach VKC");
            return NO;
        }
    }
    
    /// Check if flags are empty
    if (modifierFlags == kEmptyModifierFlags) {
        DDLogDebug(@"SymbolicHotKeys: isUsable: Not usable due to empty modifierFlags");
        return NO;
    }
    
    /// Check if flags are unexpected
    if ((false)) { /// It seems there need to be some flags for the SHK to be triggered successfully, but I'm not sure these are all the possible flags - so we're turning this test off to avoid false negatives for the 'isUsable' question.
        if (1 != (modifierFlags & (kCGSAlphaShiftKeyMask|kCGSShiftKeyMask|kCGSControlKeyMask|kCGSAlternateKeyMask|kCGSCommandKeyMask|kCGSNumericPadKeyMask|kCGSHelpKeyMask|kCGSFunctionKeyMask))) {
            DDLogDebug(@"SymbolicHotKeys: isUsable: Not usable due to unexpected modifierFlags: %d", modifierFlags);
            return NO;
        }
    }
    
    /// Check if the VKC matches the keyEquivalent
    ///     under the current keyboard layout
    if (keyEquivalent != kEmptyKeyEquivalent) { /// If there is no `keyEquivalent` then macOS will use the VKC instead and everything should work fine. Otherwise, the `keyEquivalent` needs to match.
        NSString *chars = getCharsForVirtualKeyCode(virtualKeyCode);
        if (!chars || chars.length != 1) {
            DDLogDebug(@"SymbolicHotKeys: isUsable: Not usable due to empty charsForVKC");
            return NO;
        }
        if (keyEquivalent != [chars characterAtIndex:0]) {
            DDLogDebug(@"SymbolicHotKeys: isUsable: Not usable due to char mismatch: keyEquivalent: %c, charsForVKC: %@", keyEquivalent, chars);
            return NO;
        }
    }
    
    /// Passed all tests
    return YES;
}

static NSString *_Nullable getCharsForVirtualKeyCode(CGKeyCode keyCode) {

    /// Get chars for a virtualKeyCode – based on currently active keyboard layout.
    /// Returns nil to indicate failure.
    ///
    /// Notes:
    /// - Think about putting this into some utility class
    ///     - The MASShortcut code which we're using also implements a UCKeyTranslate() wrapper. Maybe we should use that?
    /// - Here's a pretty competent-looking implementation of a UCKeyTranslate() wrapper (ended up in OpenEmu) https://stackoverflow.com/a/8263841/10601702

    
    /// Get layout
    
    const UCKeyboardLayout *layout = NULL;
    
    TISInputSourceRef inputSource = TISCopyCurrentKeyboardInputSource() /*TISCopyCurrentKeyboardLayoutInputSource()*/; /// Not sure what's better
    MFDefer ^{ if (inputSource) CFRelease(inputSource); };
    if (inputSource) {
        CFDataRef layoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData);
        if (layoutData) {
            layout = (UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
        }
    }
    
    if (!layout) {
        DDLogError(@"Failed to get UCKeyboardLayout");
        return nil;
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
        return nil;
    }
    
    /// Return
    NSString *result = [NSString stringWithCharacters:unicodeString length:actualStringLength];
    return result;
}

@end
