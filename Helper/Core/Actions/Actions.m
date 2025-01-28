//
// --------------------------------------------------------------------------
// Actions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Actions.h"
#import "TouchSimulator.h"
#import "SharedUtility.h"
#import "ModificationUtility.h"
#import "HelperUtility.h"
#import "Modifiers.h"
#import "Remap.h"
#import "Constants.h"
#import "CGSHotKeys.h"
#import "SymbolicHotKeys.h"

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
            [SymbolicHotKeys post:(CGSSymbolicHotKey)shk];
            
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

+ (void)__SWIFT_UNBRIDGED_executeActionArray:(id)actionArray phase:(MFActionPhase)phase {
    [self executeActionArray:actionArray phase:phase];
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
    
    CGEventPost(tapLoc, e.CGEvent); /// `.CGEvent` "Returns an autoreleased CGEvent" -> Make sure there's an autoreleasepool when calling this!
    
    /// Post key up
    ts = [ModificationUtility nsTimeStamp];
    e = [NSEvent otherEventWithType:14 location:loc modifierFlags:modifierFlags timestamp:ts windowNumber:-1 context:nil subtype:8 data1:upData data2:-1];
    
    CGEventPost(tapLoc, e.CGEvent);
}

#pragma mark - Keyboard shortcuts

static void postKeyboardShortcut(CGKeyCode keyCode, CGSModifierFlags modifierFlags) {
    
    CGEventTapLocation tapLoc = kCGSessionEventTap;
    
    /// Create key events
    CGEventRef keyDown = CGEventCreateKeyboardEvent(NULL, keyCode, true);
    CGEventRef keyUp = CGEventCreateKeyboardEvent(NULL, keyCode, false);
    CGEventSetFlags(keyDown, (CGEventFlags)modifierFlags);
    CGEventSetFlags(keyUp, (CGEventFlags)modifierFlags);
    
    /// Create modifier restore event
    ///  (Restoring original modifier state the way `postKeyboardEventsForSymbolicHotkey()` does leads to issues with triggering Spotlight)
    ///      (Sometimes triggered Siri instead)
//    CGEventFlags originalModifierFlags = CGEventGetFlags(CGEventCreate(NULL));
    CGEventRef modEvent = CGEventCreate(NULL);
//    CGEventSetFlags(modEvent, originalModifierFlags);
    
    /// Send key events
    CGEventPost(tapLoc, keyDown);
    CGEventPost(tapLoc, keyUp);
    CGEventPost(tapLoc, modEvent);
    
    CFRelease(keyDown);
    CFRelease(keyUp);
    CFRelease(modEvent);
}

@end
