//
// --------------------------------------------------------------------------
// Conditions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#pragma mark - Notes

/**
All the functionality for this has been moved to HelperState.swift at the time of writing
 TODO: Remove this class
*/

#import "Conditions.h"

@implementation Conditions

#pragma mark - Storage

static NSMutableDictionary *_conditions;

#pragma mark - Load

+ (void)load_Manual {
    
    assert(false);
    
    /// Note: I'm not sure this should be `load_Manual` over `initialize` or `load`. We copied this from `Modifiers.m`
    
    if (self == [Conditions class]) {
        
        /// Init `_conditions`
        _conditions = [NSMutableDictionary dictionary];
    }
}

#pragma mark Toggle listening

//static MFModifierPriority _kbModPriority;
//static MFModifierPriority _btnModPriority;
//static CFMachPortRef _kbModEventTap;

//+ (void)setKeyboardModifierPriority:(MFModifierPriority)priority {
//    _kbModPriority = priority;
//    CGEventTapEnable(_kbModEventTap, _kbModPriority == kMFModifierPriorityActiveListen);
//}
//
//+ (void)setButtonModifierPriority:(MFModifierPriority)priority {
//    /// NOTE:
//    /// We can't passively retrieve the button mods, so we always need to actively listen to the buttons, even if the modifierPriority is `passive`.
//    /// Also we don't only listen to buttons to use them as modifiers but also to use them as triggers.
//    /// As a consequence of this, we only toggle off some of the button modifier processing here if the button mods are completely unused and we don't toggle off the button input receiving entirely here at all. That is done by MasterSwitch when there are no effects for the buttons either as modifiers or as triggers.
//    _btnModPriority = priority;
//    Buttons.useButtonModifiers = _btnModPriority != kMFModifierPriorityUnused;
//}

#pragma mark Inspect State
/// At the time of writing we just need this for debugging
//
//+ (MFModifierPriority)kbModPriority {
//    return _kbModPriority;
//}
//
//+ (MFModifierPriority)btnModPriority {
//    return _btnModPriority;
//}

#pragma mark Handle condition change

//CGEventRef _Nullable kbModsChanged(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
//    
//    
//    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
//        
//        if (type == kCGEventTapDisabledByTimeout) {
//            CGEventTapEnable(_kbModEventTap, true);
//        }
//        
//        return event;
//    }
//    
//    /// Get mouse
//    
//    //    Device *activeDevice = HelperState.shared.activeDevice;
//    
//    /// Get activeModifiers
//    /// Notes:
//    /// - We can't use CGEventCreate() here for the source of the keyboard modifers, because the kbMods won't be up-to-date.
//    /// -> Idea: This might be because we're using a passive listener eventTap?
//    
//    NSUInteger newFlags = flagsFromEvent(event);
//    
//    /// Check Change
//    NSNumber *newFlagsNS = @(newFlags);
//    NSNumber *oldFlags = _modifiers[kMFModificationPreconditionKeyKeyboard];
//    BOOL didChange = ![oldFlags isEqualToNumber:newFlagsNS];
//    
//    if (didChange) {
//        
//        /// Store result
//        if (newFlags == 0) {
//            [_modifiers removeObjectForKey:kMFModificationPreconditionKeyKeyboard];
//        } else {
//            _modifiers[kMFModificationPreconditionKeyKeyboard] = newFlagsNS;
//        }
//        
//        /// Notify
////        [ReactiveModifiers.shared handleModifiersDidChangeTo:_modifiers];
//        [SwitchMaster.shared modifiersChangedWithModifiers:_modifiers];
//    }
//    
//    /// Return
//    return event;
//}

//+ (void)buttonModsChangedTo:(ButtonModifierState)newModifiers {
//    
//    /// Debug
//    DDLogDebug(@"buttonMods changed to: %@", newModifiers);
//    
//    /// Assert change
//    if (runningPreRelease()) {
//        NSArray *oldModifiers = _modifiers[kMFModificationPreconditionKeyButtons];
//        assert(![newModifiers isEqualToArray:oldModifiers]);
//    }
//    
//    /// Store
//    if (newModifiers.count == 0) {
//        [_modifiers removeObjectForKey:kMFModificationPreconditionKeyButtons];
//    } else {
//        _modifiers[kMFModificationPreconditionKeyButtons] = [newModifiers copy]; /// I think we only copy here so the newModifers != oldModifiers assert works
//    }
//    
//    if (_btnModPriority == kMFModifierPriorityActiveListen) {
//        
//        /// Also update kbMods before notifying
//        if (_kbModPriority == kMFModifierPriorityPassiveUse) {
//            updateKBMods(nil);
//        }
//        
//        /// Notify
////        [ReactiveModifiers.shared handleModifiersDidChangeTo:_modifiers];
//        [SwitchMaster.shared modifiersChangedWithModifiers:_modifiers];
//    }
//}
//
//+ (void)__SWIFT_UNBRIDGED_buttonModsChangedTo:(id)newModifiers {
//    [self buttonModsChangedTo:newModifiers];
//}

/// Helper for modifier change handling

//static void updateKBMods(CGEventRef _Nullable event) {
//    
//    assert(_kbModPriority == kMFModifierPriorityPassiveUse);
//    
//    NSUInteger flags = flagsFromEvent(event);
//    if (flags == 0) {
//        [_modifiers removeObjectForKey:kMFModificationPreconditionKeyKeyboard];
//    } else {
//        _modifiers[kMFModificationPreconditionKeyKeyboard] = @(flags);
//    }
//}

//static NSUInteger flagsFromEvent(CGEventRef _Nullable event) {
//    
//    /// When you don't pass in an event sometimes the flags won't be up to date (e.g. from the kbModsChanged eventTap). Also it will be somewhat slower
//    
//    /// Create event
//    BOOL eventWasNULL = NO;
//    if (event == NULL) {
//        eventWasNULL = YES;
//        event = CGEventCreate(NULL);
//    }
//    
//    /// Mask
//    /// - Only lets bits 16-23 through
//    /// - NSEventModifierFlagDeviceIndependentFlagsMask == 0xFFFF0000 -> it allows bits 16 - 31. But bits 24 - 31 contained weird stuff which messed up the return value and modifiers are only on bits 16-23, so we defined our own mask.
//    uint64_t mask = 0xFF0000;
//    
//    /// We ignore caps lock.
//    /// - Otherwise modfifications won't work normally when caps lock is enabled.
//    /// - Maybe we need to ignore caps lock in other places, too make this work properly but I don't think so
//    /// - We should probably remove this once we update RemapsOverrider to work with subset matches and stuff
//    /// -> TODO: Remove capslock ignoring now.
//    mask &= ~kCGEventFlagMaskAlphaShift;
//    
//    /// Get new flags
//    NSUInteger flags = CGEventGetFlags(event) & mask;
//    
//    /// Release
//    if (eventWasNULL) CFRelease(event);
//    
//    /// Return
//    return flags;
//}

#pragma mark Main Interface

//+ (NSDictionary *)conditionsWithEvent:(CGEventRef _Nullable)event {
//    
////    if (_kbModPriority == kMFModifierPriorityPassiveUse) {
////        updateKBMods(event);
////    }
//    
//    return _modifiers;
//}

//+ (id)__SWIFT_UNBRIDGED_modifiersWithEvent:(CGEventRef _Nullable)event {
//    
//    return [self modifiersWithEvent:event];
//}

#pragma mark Handle mod usage

//+ (void)handleModificationHasBeenUsed {
//    
//    /// Notify active *modifiers* that they have had an effect
//    for (NSDictionary *buttonMods in _modifiers[kMFModificationPreconditionKeyButtons]) {
//        NSNumber *buttonNumber = buttonMods[kMFButtonModificationPreconditionKeyButtonNumber];
//        [Buttons handleButtonHasHadEffectAsModifierWithButton:buttonNumber];
//        /// ^ I think we might only have to notify the last button in the sequence (instead of all of them), because all previous buttons should already have been zombified or sth due to consecutive button presses
//    }
//}


@end
