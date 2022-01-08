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
#import "Constants.h"

@implementation Actions

+ (void)executeActionArray:(NSArray *)actionArray {
    
#if DEBUG
    NSLog(@"Executing action array: %@", actionArray);
#endif
    
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
            
        } else if ([actionType isEqualToString:kMFActionDictTypeSystemDefinedEvent]) {
            
            NSNumber *type = actionDict[kMFActionDictKeySystemDefinedEventVariantType];
            NSNumber *flags = actionDict[kMFActionDictKeySystemDefinedEventVariantModifierFlags];
            
            postSystemDefinedEvent(type.unsignedIntValue, flags.unsignedIntValue);
            
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

#pragma mark - System defined events

static void postSystemDefinedEvent(MFSystemDefinedEventType type, NSEventModifierFlags modifierFlags) {
    /// The timestamps, and location, and even the keyUp event seem to be unnecessary. Just trying stuff to try and fix weird bug where music is louder for a few seconds after starting it with a systemDefinedEvent.
    ///     Edit: The bug where the music is too loud for a few seconds also happens when using the keyboard, so the issue is not on our end.
    
    CGEventTapLocation tapLoc = kCGSessionEventTap;
    
    NSPoint loc = NSEvent.mouseLocation;
    
    NSInteger data = 0;
    data = data | kMFSystemDefinedEventBase;
    data = data | (type << 16);
    
    /// Post key down
    
    NSTimeInterval ts = [Utility_Transformation nsTimeStamp];
    NSEvent *e = [NSEvent otherEventWithType:14 location:loc modifierFlags:modifierFlags timestamp:ts windowNumber:-1 context:nil subtype:8 data1:data data2:-1];
    
    CGEventPost(tapLoc, e.CGEvent);
    
    /// Post key up
    ts = [Utility_Transformation nsTimeStamp];
    
    data = data | kMFSystemDefinedEventPressedMask;
    e = [NSEvent otherEventWithType:14 location:loc modifierFlags:modifierFlags timestamp:ts windowNumber:-1 context:nil subtype:8 data1:data data2:-1];
    
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
    CGEventFlags originalModifierFlags = Utility_Transformation.CGModifierFlagsWithoutEvent;
    CGEventSetFlags(keyUp, originalModifierFlags); // Restore original keyboard modifier flags state on key up. This seems to fix `[ModifierManager getCurrentModifiers]`
    
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
    BOOL oldBindingIsUsable = (keyCode < 400);
    
    if (!hotkeyIsEnabled) {
        CGSSetSymbolicHotKeyEnabled(shk, true);
    }
    if (!oldBindingIsUsable) {
        
        /// Temporarily set a usable binding for our shk
        unichar newKeyEquivalent = 65535; /// Not sure  this value matters
        CGKeyCode newKeyCode = (CGKeyCode)shk + 400; /// Keycodes on my keyboard go up to like 125, but we use 400 just to be safely out of reach for a real kb
        CGSModifierFlags newModifierFlags = 10485760; /// 0 Didn't work in my testing. This seems to be the 'empty' CGSModifierFlags value, used to signal that no modifiers are pressed. TODO: Test if this works
        CGError err = CGSSetSymbolicHotKeyValue(shk, newKeyEquivalent, newKeyCode, newModifierFlags);
        if (err != kCGErrorSuccess) {
            NSLog(@"Error setting shk params: %d", err);
            /// Do again or something if setting shk goes wrong
        }
        
        /// Post keyboard events trigger shk
        postKeyboardEventsForSymbolicHotkey(newKeyCode, newModifierFlags);
    } else {
            
        /// Post keyboard events trigger shk
        postKeyboardEventsForSymbolicHotkey(keyCode, modifierFlags);
    }
    
    /// Restore original binding after short delay
    if (!hotkeyIsEnabled || !oldBindingIsUsable) { /// Only really need to restore hotKeyIsEnabled. But the other stuff doesn't hurt.
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

@end
