//
// --------------------------------------------------------------------------
// Actions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Actions.h"
#import "CGSHotKeys.h"
#import "TouchSimulator.h"

@implementation Actions

+ (void)handleActionArray:(NSArray *)actionArray {
    
    for (NSDictionary *actionDict in actionArray) {
    
        if ([actionDict[@"type"] isEqualToString:@"symbolicHotkey"]) {
            NSNumber *shk = actionDict[@"value"];
            [self triggerSymbolicHotkey:[shk intValue]];
        }
        else if ([actionDict[@"type"] isEqualToString:@"navigationSwipe"]) {
            NSString *dirString = actionDict[@"value"];
            
            if ([dirString isEqualToString:@"left"]) {
                [TouchSimulator postNavigationSwipeEventWithDirection:kIOHIDSwipeLeft];
            } else if ([dirString isEqualToString:@"right"]) {
                [TouchSimulator postNavigationSwipeEventWithDirection:kIOHIDSwipeRight];
            } else if ([dirString isEqualToString:@"up"]) {
                [TouchSimulator postNavigationSwipeEventWithDirection:kIOHIDSwipeUp];
            } else if ([dirString isEqualToString:@"down"]) {
                [TouchSimulator postNavigationSwipeEventWithDirection:kIOHIDSwipeDown];
            }
            
        } else if ([actionDict[@"type"] isEqualToString:@"smartZoom"]) {
            [TouchSimulator postSmartZoomEvent];
        }
    }
}


/*
(Here are some old notes of mine regarding symbolic hotkeys. Might be useful for you
 if you wanna trigger system functions in your app)
 
 SymbolicHotkeys Reference:

 // resources

 Default Mappings with description:
 - /System/Library/PreferencePanes/Keyboard.prefPane/Contents/Resources/English.lproj

 Reverse Engineering of the CGSHotKeys.h header
 - https://github.com/NUIKit/CGSInternal/blob/master/CGSHotKeys.h

 Archived forum post
 - https://web.archive.org/web/20141112224103/http://hintsforums.macworld.com/showthread.php?t=114785

 // tested

 @“Mission Control”         :   @32,
 @"Show All Windows"        :   @33,
 @"Show Desktop"            :   @36,
 @"Launchpad"               :   @160,
 @"Look Up"                 :   @70,
 @“App Switcher”            :   @71,

 @“Move left a space”       :   @79,
 @“Move right a space”      :   @81,
     
 @"Cycle through Windows".  :   @27

 @"Switch to Desktop {1-16}     :   @{118-133},

 @“Spotlight”                   :   @64,

 @“Siri”                        :   @176,
 @“Show Notification Center”    :   @163,
 @"Turn Do Not Disturb On/Off"  :   @175,

 Others:
 Something directed to the right: @82;

 –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

 

 // For some (all?) system functions there are 2 (or more) shk's with → symbolicHotkey2Val = symbolicHotkey1Val + 8, and sometimes + 4
 // These seem to be used for mapping system functions to mouse buttons directly
 // Edit: It seems that there is only one shk for "Move right a space"... meh
 // -> It's probably best to trigger system functions by posting keyDown events.

 MB2:
 - type         = "button"
 - parameters     = [2, 2, 131072]
 MB3:
 - type         = "button"
 - parameters     = [4, 4, 131072]
 MB4:
 - type         = "button"
 - parameters     = [8, 8, 131072]
 MB4:
 - type         = "button"
 - parameters     = [16, 16, 131072]
 
 */

// I think these two private functions are the only thing preventing the app from being allowed on the Mac App Store, so if you know a way to trigger system functions without a private API it would be awesome if you let me know! :)
CG_EXTERN CGError CGSGetSymbolicHotKeyValue(CGSSymbolicHotKey hotKey, unichar *outKeyEquivalent, unichar *outVirtualKeyCode, CGSModifierFlags *outModifiers);
CG_EXTERN CGError CGSSetSymbolicHotKeyValue(CGSSymbolicHotKey hotKey, unichar keyEquivalent, CGKeyCode virtualKeyCode, CGSModifierFlags modifiers);


+ (void)triggerSymbolicHotkey:(CGSSymbolicHotKey)shk {
    
    unichar keyEquivalent;
    CGKeyCode virtualKeyCode;
    CGSModifierFlags modifierFlags;
    CGSGetSymbolicHotKeyValue(shk, &keyEquivalent, &virtualKeyCode, &modifierFlags);
    
    BOOL hotkeyIsEnabled = CGSIsSymbolicHotKeyEnabled(shk);
    BOOL oldVirtualKeyCodeIsUsable = (virtualKeyCode < 400);
    
    if (hotkeyIsEnabled == FALSE) {
        CGSSetSymbolicHotKeyEnabled(shk, TRUE);
    }
    if (oldVirtualKeyCodeIsUsable == FALSE) {
        // set new parameters for shk - not accessible through actual keyboard, cause values too high
        keyEquivalent = 65535; // TODO: Why this value? Does it event matter what value this is?
        virtualKeyCode = (CGKeyCode)shk + 200;
        modifierFlags = 10485760; // 0 Didn't work in my testing. This seems to be the 'empty' CGSModifierFlags value, used to signal that no modifiers are pressed. TODO: Test if this works
        CGError err = CGSSetSymbolicHotKeyValue(shk, keyEquivalent, virtualKeyCode, modifierFlags);
        if (err != 0) {
            NSLog(@"Error setting shk params: %d", err);
            // Do again or something if setting shk goes wrong
        }
    }
    
    // Post keyboard events corresponding to trigger shk
    CGEventRef shortcutDown = CGEventCreateKeyboardEvent(NULL, virtualKeyCode, TRUE);
    CGEventRef shortcutUp = CGEventCreateKeyboardEvent(NULL, virtualKeyCode, FALSE);
    CGEventSetFlags(shortcutDown, (CGEventFlags)modifierFlags);
    CGEventFlags originalModifierFlags = CGEventGetFlags(CGEventCreate(NULL));
    CGEventSetFlags(shortcutUp, originalModifierFlags); // Restore original keyboard modifier flags state on key up. This seems to fix `[RemapUtility getCurrentModifiers]`
    CGEventPost(kCGHIDEventTap, shortcutDown);
    CGEventPost(kCGHIDEventTap, shortcutUp);
    CFRelease(shortcutDown);
    CFRelease(shortcutUp);
    
    // Restore original hotkey parameter state after 20ms
    if (hotkeyIsEnabled == FALSE) { // Only really need to restore hotKeyIsEnabled. But the other stuff doesn't hurt.
        [NSTimer scheduledTimerWithTimeInterval:0.05
                                         target:self
                                       selector:@selector(restoreSymbolicHotkeyParameters_timerCallback:)
                                       userInfo:@{
                                           @"shk": @(shk),
                                           @"enabled": @(hotkeyIsEnabled),
                                           @"keyEquivalent": @(keyEquivalent),
                                           @"virtualKeyCode": @(virtualKeyCode),
                                           @"flags": @(modifierFlags),
                                       }
                                        repeats:NO];
    }
}

+ (void)restoreSymbolicHotkeyParameters_timerCallback:(NSTimer *)timer { // TODO: Test if this works
    
    CGSSymbolicHotKey shk = [timer.userInfo[@"shk"] intValue];
    BOOL enabled = [timer.userInfo[@"enabled"] boolValue];
    unichar kEq = [timer.userInfo[@"keyEquivalent"] unsignedCharValue];
    CGKeyCode kCode = [timer.userInfo[@"virtualKeyCode"] unsignedIntValue];
    CGSModifierFlags mod = [timer.userInfo[@"flags"] intValue];
    
    CGSSetSymbolicHotKeyEnabled(shk, enabled);
    CGSSetSymbolicHotKeyValue(shk, kEq, kCode, mod);
}

@end
