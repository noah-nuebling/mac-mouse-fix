//
// --------------------------------------------------------------------------
// Actions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Actions.h"
#import "CGSHotKeys.h"
#import "TouchSimulator.h"
#import "SharedUtility.h"
#import "ModificationUtility.h"
#import "HelperUtility.h"
#import "Modifiers.h"
#import "Remap.h"
#import "Constants.h"
#import "Logging.h"

@import Carbon;

@implementation Actions

+ (void)executeActionArray:(NSArray *)actionArray phase:(MFActionPhase)phase {
    
    DDLogDebug(@"Executing action array: %@, phase: %@", actionArray, @(phase));
    
    if (phase == kMFActionPhaseEnd) {
        return; /// TODO: Actually implement actions with different phases
    }
               
    for (NSDictionary *actionDict in actionArray) {
        
        MFStringConstant actionType = actionDict[kMFActionDictKeyType];
    
        if ([actionType isEqualToString:kMFActionDictTypeSymbolicHotkey]) {
            
            MFSymbolicHotkey shk = ((NSNumber *)actionDict[kMFActionDictKeyGenericVariant]).intValue;
            postSymbolicHotkey((CGSSymbolicHotKey) shk);
            
        } else if ([actionType isEqualToString:kMFActionDictTypeNavigationSwipe]) {
            
            /// TODO: Rename the action dict keys to 'back' and 'forward' instead of 'navigationSwipeVariantLeft' and 'navigationSwipeVariantRight', then send keyboard shortcuts for vscode, navigation swipes for safari, etc. 
            
            NSString *dirString = actionDict[kMFActionDictKeyGenericVariant];
            
            if ([dirString isEqualToString:kMFNavigationSwipeVariantLeft]) {
                [TouchSimulator postNavigationSwipeEventWithDirection:kIOHIDSwipeLeft];
            } else if ([dirString isEqualToString:kMFNavigationSwipeVariantRight]) {
                [TouchSimulator postNavigationSwipeEventWithDirection:kIOHIDSwipeRight];
            } else if ([dirString isEqualToString:kMFNavigationSwipeVariantUp]) {
                [TouchSimulator postNavigationSwipeEventWithDirection:kIOHIDSwipeUp];
            } else if ([dirString isEqualToString:kMFNavigationSwipeVariantDown]) {
                [TouchSimulator postNavigationSwipeEventWithDirection:kIOHIDSwipeDown];
            }
            
        } else if ([actionType isEqualToString:kMFActionDictTypeSmartZoom]) {
            
            [TouchSimulator postSmartZoomEvent];
            
        } else if ([actionType isEqualToString:kMFActionDictTypeKeyboardShortcut]) {
            
            NSNumber *keycode = actionDict[kMFActionDictKeyKeyboardShortcutVariantKeycode];
            NSNumber *flags = actionDict[kMFActionDictKeyKeyboardShortcutVariantModifierFlags];
            postKeyboardShortcut(keycode.intValue, flags.intValue);
            
        } else if ([actionType isEqualToString:kMFActionDictTypeSystemDefinedEvent]) {
            
            NSNumber *type = actionDict[kMFActionDictKeySystemDefinedEventVariantType];
            NSNumber *flags = actionDict[kMFActionDictKeySystemDefinedEventVariantModifierFlags];
            
            postSystemDefinedEvent(type.unsignedIntValue, flags.unsignedIntValue);
            
        } else if ([actionType isEqualToString:kMFActionDictTypeMouseButtonClicks]) {
            
            NSNumber *button = actionDict[kMFActionDictKeyMouseButtonClicksVariantButtonNumber];
            NSNumber *nOfClicks = actionDict[kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks];
            [ModificationUtility postMouseButtonClicks:button.intValue nOfClicks:nOfClicks.intValue];
        
        } else if ([actionType isEqualToString:kMFActionDictTypeAddModeFeedback]) {
            NSMutableDictionary *payload = ((NSMutableDictionary *)actionDict.mutableCopy);
            [payload removeObjectForKey:kMFActionDictKeyType];
            /// ^ Payload has the kMFRemapsKeyTrigger and kMFRemapsKeyModificationPrecondition keys.
            /// It is almost a valid remaps table entry.
            /// All that the main app has to do with the payload in order to make it a valid entry of the remap table's
            ///  dataModel is to add the kMFRemapsKeyEffect key and corresponding values
            [Remap sendAddModeFeedback:payload];
            
        }
    }
}

#pragma mark - System defined events

static void postSystemDefinedEvent(MFSystemDefinedEventType type, NSEventModifierFlags modifierFlags) {
    /// The timestamps, and location, and even the keyUp event seem to be unnecessary. Just trying stuff to try and fix weird bug where music is louder for a few seconds after starting it with a systemDefinedEvent.
    ///     Edit: The bug where the music is too loud for a few seconds also happens when using the keyboard, so the issue is not on our end.
    
    CGEventTapLocation tapLoc = kCGSessionEventTap;
    
    NSPoint loc = NSEvent.mouseLocation;
    
    NSInteger data = 0;
    data = data | kMFSystemDefinedEventBase;
    data = data | (type << 16);
    
    NSInteger downData = data;
    NSInteger upData = data | kMFSystemDefinedEventPressedMask;
    
    /// Post key down
    
    NSTimeInterval ts = [ModificationUtility nsTimeStamp];
    NSEvent *e = [NSEvent otherEventWithType:14 location:loc modifierFlags:modifierFlags timestamp:ts windowNumber:-1 context:nil subtype:8 data1:downData data2:-1];
    
    CGEventPost(tapLoc, e.CGEvent);
    
    /// Post key up
    ts = [ModificationUtility nsTimeStamp];
    e = [NSEvent otherEventWithType:14 location:loc modifierFlags:modifierFlags timestamp:ts windowNumber:-1 context:nil subtype:8 data1:upData data2:-1];
    
    CGEventPost(tapLoc, e.CGEvent);
}

#pragma mark - Keyboard shortcuts

static void postKeyboardShortcut(CGKeyCode keyCode, CGSModifierFlags modifierFlags) {
    
    CGEventTapLocation tapLoc = kCGSessionEventTap;
    
    // Create key events
    CGEventRef keyDown = CGEventCreateKeyboardEvent(NULL, keyCode, true);
    CGEventRef keyUp = CGEventCreateKeyboardEvent(NULL, keyCode, false);
    CGEventSetFlags(keyDown, (CGEventFlags)modifierFlags);
    CGEventSetFlags(keyUp, (CGEventFlags)modifierFlags);
    
    // Create modifier restore event
    //  (Restoring original modifier state the way postKeyboardEventsForSymbolicHotkey does leads to issues with triggering Spotlight)
    //      (Sometimes triggered Siri instead)
//    CGEventFlags originalModifierFlags = CGEventGetFlags(CGEventCreate(NULL));
    CGEventRef modEvent = CGEventCreate(NULL);
//    CGEventSetFlags(modEvent, originalModifierFlags);
    
    // Send key events
    CGEventPost(tapLoc, keyDown);
    CGEventPost(tapLoc, keyUp);
    CGEventPost(tapLoc, modEvent);
    
    CFRelease(keyDown);
    CFRelease(keyUp);
    CFRelease(modEvent);
}

#pragma mark - SymbolicHotkeys

static void postKeyboardEventsForSymbolicHotkey(CGKeyCode keyCode, CGSModifierFlags modifierFlags) {
    
    CGEventTapLocation tapLoc = kCGSessionEventTap;
    
    // Create key events
    CGEventRef keyDown = CGEventCreateKeyboardEvent(NULL, keyCode, true);
    CGEventRef keyUp = CGEventCreateKeyboardEvent(NULL, keyCode, false);
    CGEventSetFlags(keyDown, (CGEventFlags)modifierFlags);
    CGEventFlags originalModifierFlags = getModifierFlags();
    CGEventSetFlags(keyUp, originalModifierFlags); // Restore original keyboard modifier flags state on key up. This seems to fix `[Modifiers getCurrentModifiers]`
    
    // Send key events
    CGEventPost(tapLoc, keyDown);
    CGEventPost(tapLoc, keyUp);
    
    CFRelease(keyDown);
    CFRelease(keyUp);
}

CG_EXTERN CGError CGSGetSymbolicHotKeyValue(CGSSymbolicHotKey hotKey, unichar *outKeyEquivalent, unichar *outVirtualKeyCode, CGSModifierFlags *outModifiers);
CG_EXTERN CGError CGSSetSymbolicHotKeyValue(CGSSymbolicHotKey hotKey, unichar keyEquivalent, CGKeyCode virtualKeyCode, CGSModifierFlags modifiers);

static void postSymbolicHotkey(CGSSymbolicHotKey shk) {
    
    unichar keyEquivalent;
    CGKeyCode keyCode;
    CGSModifierFlags modifierFlags;
    CGSGetSymbolicHotKeyValue(shk, &keyEquivalent, &keyCode, &modifierFlags);
    
    BOOL hotkeyIsEnabled = CGSIsSymbolicHotKeyEnabled(shk);
    BOOL oldBindingIsUsable = shkBindingIsUsable(keyCode, keyEquivalent);
    
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
                                         target:[Actions class]
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

#pragma mark postSymbolicHotkey() - Helper funcs

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

BOOL shkBindingIsUsable(CGKeyCode keyCode, unichar keyEquivalent) {
    
    /// Check if keyCode is reasonable
    
    if (keyCode >= 400) return NO;
    
    /// Check if keyCode matches char
    ///  Why we do this:
    ///     (For context for this comment, see postSymbolicHotkey() - where this function is called)
    ///     When using a 'non-standard' keyboard layout, then the keycodes for certain keyboard shortcuts can change.
    ///         This is because keycodes seem to be hard mapped to physical keys on the keyboard. But the character values for those keys depend on the keyboard mapping. For example, with a German layout, the characters for the 'Y' and 'Z' keys will be swapped. Therefore the key that produces 'Z' will have a different keycode with the German layout vs the English layout. Therefore the keycodes that trigger certain keyboard shortcuts also change when changing the keyboard layout.
    ///     Now the problem is, that CGSGetSymbolicHotKeyValue() doesn't take this into account. It always returns the keycode for the 'standard' layout, not the current layout.
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
    ///     -> I'm not sure what the 'standard' layout is. I think the only 'standard' layout is the one that maps all keys to what it says on the keycaps. Or maybe the 'standard' layout is the US American layout. Not sure.
    
    NSString *chars;
    getCharsForKeyCode(keyCode, &chars);
    
    /// Check if keyCode and keyEquivalent (the args to this function) match the current keyboard layout
    
    if (chars.length != 1) return NO;
    if (keyEquivalent != [chars characterAtIndex:0]) return NO;
    
    /// Return
    return YES;
}

BOOL getCharsForKeyCode(CGKeyCode keyCode, NSString **chars) {
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
