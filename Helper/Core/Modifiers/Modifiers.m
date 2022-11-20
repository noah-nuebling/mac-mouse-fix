//
// --------------------------------------------------------------------------
// Modifiers.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "Constants.h"

#import "Modifiers.h"
#import "ButtonTriggerGenerator.h"
#import "Remap.h"
#import "ModifiedDrag.h"
#import "DeviceManager.h"
#import "SharedUtility.h"
#import "ModificationUtility.h"
#import <os/signpost.h>
#import "Mac_Mouse_Fix_Helper-Swift.h"

@implementation Modifiers

#pragma mark - Notes



#pragma mark - Terminology

/// Explanation:
/// **Trigger driven** modification -> We listen to triggers. Once a trigger to be modified comes in, we check what the active modiifers are and how we want to modify the trigger based on those
/// **Modifier driven** modification -> We listen to modifier changes. When the modifiers should affect a trigger, then we start listening to the trigger. We use this when it's bad to listen to the trigger all the time.

/// More detailed explanation:
/// The default is *trigger driven* modification.
/// That means only once the trigger comes in, we'll check for active modifiers and then apply those to the incoming trigger.
/// But sometimes its not feasible to always listen for triggers (concretely in the case of modified drags, for performance reasons, you don't want to listen to mouseMoved events all the time)
/// In those cases we'll use *modifier driven* modification.
/// Which means we listen for changes to the active modifiers and when they match a modifications' precondition, we'll initialize the modification components which are modifier driven. (which is only the drag modificaitons at this point)

#pragma mark - Storage

static NSMutableDictionary *_modifiers;

#pragma mark - Load

/// This used to be initialize but  that didn't execute until the first mouse buttons were pressed
/// Then it was load, but that led to '"Mac Mouse Fix Helper" would like to receive keystrokes from any application' prompt. (I think)
+ (void)load_Manual {
    if (self == [Modifiers class]) {
        
        /// Init `_modifiers`
        _modifiers = [NSMutableDictionary dictionary];
        
        /// Create keyboard modifier event tap
        CGEventMask mask = CGEventMaskBit(kCGEventFlagsChanged);
        _keyboardModifierEventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionListenOnly, mask, kbModsChanged, NULL);
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _keyboardModifierEventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
        CFRelease(runLoopSource);
        
        /// Enable/Disable eventTap based on Remap.remaps
        CGEventTapEnable(_keyboardModifierEventTap, false); /// Disable eventTap first (Might prevent `_keyboardModifierEventTap` from always being called twice - Nope doesn't make a difference)
        toggleModifierListening(Remap.remaps);
        
        /// Re-toggle keyboard modifier callbacks whenever Remap.remaps changes
        /// TODO:! Test if this works
        [NSNotificationCenter.defaultCenter addObserverForName:kMFNotifCenterNotificationNameRemapsChanged
                                                        object:nil
                                                         queue:nil
                                                    usingBlock:^(NSNotification * _Nonnull note) {
            DDLogDebug(@"Received notification that remaps have changed");
            toggleModifierListening(Remap.remaps);
        }];
    }
}

#pragma mark Toggle listening

static CFMachPortRef _keyboardModifierEventTap;
static void toggleModifierListening(NSDictionary *remaps) {

    ///
    /// Toggle buttonMod processing
    ///
    
    // TODO: Implement
    
    ///
    /// Toggle kbMod eventTap
    ///
    
    /// Decide
    
    bool doEnable = false;
    
    if (Remap.addModeIsEnabled) {
        doEnable = true;
    } else {
        /// If any keyboard modifier is used in remaps, enable tap
        for (NSDictionary *modifiers in remaps) {
            BOOL containsKB = modifiers[kMFModificationPreconditionKeyKeyboard] != nil;
            if (containsKB) {
                doEnable = true;
                break;
            }
        }
    }
    
    /// Toggle tap
    
    CGEventTapEnable(_keyboardModifierEventTap, doEnable);
}

#pragma mark Handle modifier change

CGEventRef _Nullable kbModsChanged(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {

    /// Get mouse
    
//    Device *activeDevice = HelperState.activeDevice;
    
    /// Get activeModifiers
    /// Notes:
    /// - We can't use CGEventCreate() here for the source of the keyboard modifers, because the kbMods won't be up-to-date.
    /// -> Idea: This might be because we're using a passive listener eventTap?

    /// Mask
    /// - Only lets bits 16-23 through
    /// - NSEventModifierFlagDeviceIndependentFlagsMask == 0xFFFF0000 -> it allows bits 16 - 31. But bits 24 - 31 contained weird stuff which messed up the return value and modifiers are only on bits 16-23, so we defined our own mask.
    uint64_t mask = 0xFF0000;
    
    /// We ignore caps lock.
    /// - Otherwise modfifications won't work normally when caps lock is enabled.
    /// - Maybe we need to ignore caps lock in other places, too make this work properly but I don't think so
    /// - We should probably remove this once we update RemapsOverrider to work with subset matches and stuff
    /// -> TODO: Remove capslock ignoring now.
    mask &= ~kCGEventFlagMaskAlphaShift;
    
    /// Get new flags
    NSUInteger newFlags = CGEventGetFlags(event) & mask;
    
    /// Check Change
    NSNumber *newFlagsNS = @(newFlags);
    NSNumber *oldFlags = _modifiers[kMFModificationPreconditionKeyKeyboard];
    BOOL didChange = ![oldFlags isEqualToNumber:newFlagsNS];
    
    if (didChange) {
        
        /// Store result
        if (newFlags == 0) {
            [_modifiers removeObjectForKey:kMFModificationPreconditionKeyKeyboard];
        } else {
            _modifiers[kMFModificationPreconditionKeyKeyboard] = newFlagsNS;
        }
        
        /// Notify
        [ReactiveModifiers.shared handleModifiersDidChange];
        reactToModifierChange();
    }

    /// Return
    return event;
}


#pragma mark Button modifiers

+ (void)buttonModsChangedTo:(NSArray<NSDictionary<NSString *, NSNumber *> *> *)newModifiers {
    
    /// Debug
    DDLogDebug(@"buttonMods changed to: %@", newModifiers);
    
    /// Assert change
    if (SharedUtility.runningPreRelease) {
        NSArray *oldModifiers = _modifiers[kMFModificationPreconditionKeyButtons];
        assert(![newModifiers isEqualToArray:oldModifiers]);
    }
    
    /// Store
    if (newModifiers.count == 0) {
        [_modifiers removeObjectForKey:kMFModificationPreconditionKeyButtons];
    } else {
        _modifiers[kMFModificationPreconditionKeyButtons] = newModifiers;
    }
    
    /// Notify
    [ReactiveModifiers.shared handleModifiersDidChange];
    reactToModifierChange();
}

#pragma mark Interface

+ (NSDictionary *)modifiers {
    return _modifiers;
}

#pragma mark Handle mod usage

+ (void)handleModificationHasBeenUsed {
    
    /// Notify active *modifiers* that they have had an effect
    for (NSDictionary *buttonMods in _modifiers[kMFModificationPreconditionKeyButtons]) {
        NSNumber *buttonNumber = buttonMods[kMFButtonModificationPreconditionKeyButtonNumber];
        [Buttons handleButtonHasHadEffectAsModifierWithButton:buttonNumber];
        /// ^ I think we might only have to notify the last button in the sequence (instead of all of them), because all previous buttons should already have been zombified or sth due to consecutive button presses
    }
}

//+ (void)handleModificationHasBeenUsedWithDevice:(Device *)device {
//    /// Convenience wrapper for `handleModifiersHaveHadEffect:activeModifiers:` if you don't have access to `activeModifiers`
//
//    NSDictionary *activeModifiers = [self getActiveModifiersForDevice:device event:nil];
//    [Modifiers handleModificationHasBeenUsedWithDevice:device activeModifiers:activeModifiers];
//}
//+ (void)handleModificationHasBeenUsedWithDevice:(Device *)device activeModifiers:(NSDictionary *)activeModifiers {
//    /// Make sure to pass in device, otherwise this method (in its current form) won't do anything
//
//    if (device != nil) {
//        /// Notify active *modifiers* that they have had an effect
//        for (NSDictionary *buttonPrecondDict in activeModifiers[kMFModificationPreconditionKeyButtons]) {
//            NSNumber *precondButtonNumber = buttonPrecondDict[kMFButtonModificationPreconditionKeyButtonNumber];
//            [Buttons handleButtonHasHadEffectAsModifierWithDevice:device button:precondButtonNumber];
//            /// ^ I think we might only have to notify the last button in the sequence (instead of all of them), because all previous buttons should already have been zombified or sth due to consecutive button presses
//        }
//    }
//}

#pragma mark React

static void reactToModifierChange() {
    
    /// Get active modifications and initialize any which are modifier driven
    
    /// Debug
    
    DDLogDebug(@"MODIFIERS HAVE CHANGED TO - %@", _modifiers);
//    DDLogDebug(@"...ON DEVICE - %@", device);
//    DDLogDebug(@"...CALLED BY %@", [SharedUtility getInfoOnCaller]);
    
    /// Get activeModifications
    NSDictionary *activeModifications = [Remap modificationsWithModifiers:_modifiers];
    
    /// Notify ScrollModifiers of modifierChange
    ///     It needs that to commit to an app in the app switcher when the user releases a button
    ///     TODO: Make sure this always works, and not only when a ModifieDrag makes the Modifiers class listen to modifierChanged events
    
    [ScrollModifiers reactToModiferChangeWithActiveModifications:activeModifications];
    
    /// Kill old modifications
    
    /// Kill the currently active modifiedDrag if the modifiers have changed since it started.
    ///     (If there were other modifier driven effects than modifiedDrag in the future, we would also kill them here)

    BOOL modifiedDragIsStillUpToDate = NO;
    
    if ([_modifiers isEqual:ModifiedDrag.initialModifiers]) {
        modifiedDragIsStillUpToDate = YES;
    } else {
        [ModifiedDrag deactivate];
    }
    
    /// Init new modifications
    
    if (activeModifications) {
        
        /// Init modifiedDrag
        ///    (If there were other modifier driven effects than modifiedDrag in the future, we would also init them here)
        
        if (!modifiedDragIsStillUpToDate) {
        
            NSMutableDictionary *modifiedDragEffectDict = activeModifications[kMFTriggerDrag]; /// Declared as NSMutableDictionary but probably not actually mutable at this point
            if (modifiedDragEffectDict) {
                
                /// If addMode is active, add activeModifiers to modifiedDragDict
                ///     See Remap.m -> AddMode for context.
//                if ([modifiedDragEffect[kMFModifiedDragDictKeyType] isEqualToString:kMFModifiedDragTypeAddModeFeedback]) {
//                    modifiedDragEffect = modifiedDragEffect.mutableCopy; /// Make actually mutable
//                    modifiedDragEffect[kMFRemapsKeyModificationPrecondition] = activeModifiers;
//                }
                
                /// Determine usage threshold based on other active modifications
                ///     It's easy to accidentally drag the mouse while trying to scroll so in that case we want a larger usageThreshold to avoid accidental drag activation
                BOOL largeUsageThreshold = NO;
                if (activeModifications[kMFTriggerScroll] != nil) {
                    largeUsageThreshold = YES;
                }
                
                /// Copy modifiers before passing into Modified drag
                ///     Can't just be reference because we later compare to `_modifiers`
                NSDictionary *copiedModifiers = (NSDictionary *)[SharedUtility deepCopyOf:_modifiers error:nil];
                
                /// Init modifiedDrag
                [ModifiedDrag initializeDragWithDict:modifiedDragEffectDict initialModifiers:copiedModifiers];
            }
        }
    }
}

@end
