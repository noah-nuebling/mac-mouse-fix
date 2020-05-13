//
// --------------------------------------------------------------------------
// OneShotActions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "OneShotActions.h"
#import "CGSHotKeys.h"
#import "TouchSimulator.h"

@implementation OneShotActions

+ (void)handleActionArray:(NSArray *)actionArray {
    
    for (NSDictionary *actionDict in actionArray) {
    
        if ([actionDict[@"type"] isEqualToString:@"symbolicHotkey"]) {
            NSNumber *shk = actionDict[@"value"];
            [self doSymbolicHotKeyAction:[shk intValue]];
        }
        else if ([actionDict[@"type"] isEqualToString:@"twoFingerSwipeEvent"]) {
            NSString *dirString = actionDict[@"value"];
            
            if ([dirString isEqualToString:@"left"]) {
                [TouchSimulator SBFFakeSwipe:kTLInfoSwipeLeft];
            } else if ([dirString isEqualToString:@"right"]) {
                [TouchSimulator SBFFakeSwipe:kTLInfoSwipeRight];
            }
        }
    }
}

CG_EXTERN CGError CGSSetSymbolicHotKeyValue(CGSSymbolicHotKey hotKey, unichar keyEquivalent, CGKeyCode virtualKeyCode, CGSModifierFlags modifiers);

+ (void)doSymbolicHotKeyAction:(CGSSymbolicHotKey)shk {
    
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
        NSLog(@"(doSymbolicHotKeyAction) set shk params err: %d", err);
        if (err != 0) {
            // Do again or something if setting shk goes wrong
        }
    }
    
    // Post keyevents corresponding to shk
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
                                       selector:@selector(restoreSHK:)
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
+ (void)restoreSHK:(NSTimer *)timer { // TODO: Test if this works
    
    CGSSymbolicHotKey shk = [timer.userInfo[@"shk"] intValue];
    BOOL enabled = [timer.userInfo[@"enabled"] boolValue];
    unichar kEq = [timer.userInfo[@"keyEquivalent"] unsignedCharValue];
    CGKeyCode kCode = [timer.userInfo[@"virtualKeyCode"] unsignedIntValue];
    CGSModifierFlags mod = [timer.userInfo[@"flags"] intValue];
    
    CGSSetSymbolicHotKeyEnabled(shk, enabled);
    CGSSetSymbolicHotKeyValue(shk, kEq, kCode, mod);
}

@end
