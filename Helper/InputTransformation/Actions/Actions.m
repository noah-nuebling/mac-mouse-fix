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
#import "SharedUtility.h"
#import "Utility_Transformation.h"
#import "ModifierManager.h"
#import "MessagePort_Helper.h"
#import "TransformationManager.h"

@implementation Actions

+ (void)executeActionArray:(NSArray *)actionArray {
    
    DDLogDebug(@"Executing action array: %@", actionArray);
    
    for (NSDictionary *actionDict in actionArray) {
        
        MFStringConstant actionType = actionDict[kMFActionDictKeyType];
    
        if ([actionType isEqualToString:kMFActionDictTypeSymbolicHotkey]) {
            
            MFSymbolicHotkey shk = ((NSNumber *)actionDict[kMFActionDictKeyGenericVariant]).intValue;
            postSymbolicHotkey((CGSSymbolicHotKey) shk);
            
        } else if ([actionType isEqualToString:kMFActionDictTypeNavigationSwipe]) {
            
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
            
        } else if ([actionType isEqualToString:kMFActionDictTypeMouseButtonClicks]) {
            
            NSNumber *button = actionDict[kMFActionDictKeyMouseButtonClicksVariantButtonNumber];
            NSNumber *nOfClicks = actionDict[kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks];
            [Utility_Transformation postMouseButtonClicks:button.intValue nOfClicks:nOfClicks.intValue];
        
        } else if ([actionType isEqualToString:kMFActionDictTypeAddModeFeedback]) {
            NSMutableDictionary *payload = ((NSMutableDictionary *)actionDict.mutableCopy);
            [payload removeObjectForKey:kMFActionDictKeyType];
            // ^ Payload has the kMFRemapsKeyTrigger and kMFRemapsKeyModificationPrecondition keys.
            // It is almost a valid remaps table entry.
            // All that the main app has to do with the payload in order to make it a valid entry of the remap table's
            //  dataModel is to add the kMFRemapsKeyEffect key and corresponding values
            [TransformationManager concludeAddModeWithPayload:payload];
            
        }
    }
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
    CGEventFlags originalModifierFlags = Utility_Transformation.CGModifierFlagsWithoutEvent;
    CGEventSetFlags(keyUp, originalModifierFlags); // Restore original keyboard modifier flags state on key up. This seems to fix `[ModifierManager getCurrentModifiers]`
    
    // Send key events
    CGEventPost(tapLoc, keyDown);
    CGEventPost(tapLoc, keyUp);
    
    CFRelease(keyDown);
    CFRelease(keyUp);
}

// I think these two private functions are the only thing preventing the app from being allowed on the Mac App Store at the time of writing, so if you know a way to trigger system functions without a private API it would be awesome if you let me know! :)
CG_EXTERN CGError CGSGetSymbolicHotKeyValue(CGSSymbolicHotKey hotKey, unichar *outKeyEquivalent, unichar *outVirtualKeyCode, CGSModifierFlags *outModifiers);
CG_EXTERN CGError CGSSetSymbolicHotKeyValue(CGSSymbolicHotKey hotKey, unichar keyEquivalent, CGKeyCode virtualKeyCode, CGSModifierFlags modifiers);

static void postSymbolicHotkey(CGSSymbolicHotKey shk) {
    
    unichar keyEquivalent;
    CGKeyCode keyCode;
    CGSModifierFlags modifierFlags;
    CGSGetSymbolicHotKeyValue(shk, &keyEquivalent, &keyCode, &modifierFlags);
    
    BOOL hotkeyIsEnabled = CGSIsSymbolicHotKeyEnabled(shk);
    BOOL oldVirtualKeyCodeIsUsable = (keyCode < 400);
    
    if (hotkeyIsEnabled == FALSE) {
        CGSSetSymbolicHotKeyEnabled(shk, TRUE);
    }
    if (oldVirtualKeyCodeIsUsable == FALSE) {
        // set new parameters for shk - should not accessible through actual keyboard, cause values too high
        keyEquivalent = 65535; // TODO: Why this value? Does it event matter what value this is?
        keyCode = (CGKeyCode)shk + 400; // TODO: Test if 400 still works or is too much
        modifierFlags = 10485760; // 0 Didn't work in my testing. This seems to be the 'empty' CGSModifierFlags value, used to signal that no modifiers are pressed. TODO: Test if this works
        CGError err = CGSSetSymbolicHotKeyValue(shk, keyEquivalent, keyCode, modifierFlags);
        if (err != 0) {
            DDLogInfo(@"Error setting shk params: %d", err);
            // Do again or something if setting shk goes wrong
        }
    }
    
    // Post keyboard events corresponding to trigger shk
    postKeyboardEventsForSymbolicHotkey(keyCode, modifierFlags);
    
    // Restore original hotkey parameter state after 20ms
    if (hotkeyIsEnabled == FALSE) { // Only really need to restore hotKeyIsEnabled. But the other stuff doesn't hurt.
        [NSTimer scheduledTimerWithTimeInterval:0.05
                                         target:[Actions class]
                                       selector:@selector(restoreSymbolicHotkeyParameters_timerCallback:)
                                       userInfo:@{
                                           @"shk": @(shk),
                                           @"enabled": @(hotkeyIsEnabled),
                                           @"keyEquivalent": @(keyEquivalent),
                                           @"virtualKeyCode": @(keyCode),
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
