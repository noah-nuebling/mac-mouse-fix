//
// --------------------------------------------------------------------------
// ModifierManager.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Constants.h"

#import "ModifierManager.h"
#import "ButtonTriggerGenerator.h"
#import "TransformationManager.h"
#import "ModifiedDrag.h"
#import "DeviceManager.h"
#import "SharedUtility.h"
#import "TransformationUtility.h"
#import <os/signpost.h>
#import "Mac_Mouse_Fix_Helper-Swift.h"

@implementation ModifierManager

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

#pragma mark - Load

/// This used to be initialize but  that didn't execute until the first mouse buttons were pressed
/// Then it was load, but that led to '"Mac Mouse Fix Helper" would like to receive keystrokes from any application' prompt. (I think)
+ (void)load_Manual {
    if (self == [ModifierManager class]) {
        // Create keyboard modifier event tap
        CGEventMask mask = CGEventMaskBit(kCGEventFlagsChanged);
        _keyboardModifierEventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionListenOnly, mask, handleKeyboardModifiersHaveChanged, NULL);
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _keyboardModifierEventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
        CFRelease(runLoopSource);
        // Enable/Disable eventTap based on TransformationManager.remaps
        CGEventTapEnable(_keyboardModifierEventTap, false); // Disable eventTap first (Might prevent `_keyboardModifierEventTap` from always being called twice - Nope doesn't make a difference)
        toggleModifierEventTapBasedOnRemaps(TransformationManager.remaps);
        
        /// Re-toggle keyboard modifier callbacks whenever TransformationManager.remaps changes
        /// TODO:! Test if this works
        [NSNotificationCenter.defaultCenter addObserverForName:kMFNotifCenterNotificationNameRemapsChanged
                                                        object:nil
                                                         queue:nil
                                                    usingBlock:^(NSNotification * _Nonnull note) {
            DDLogDebug(@"Received notification that remaps have changed");
            toggleModifierEventTapBasedOnRemaps(TransformationManager.remaps);
        }];
    }
}


#pragma mark - Handle feedback

+ (void)handleModificationHasBeenUsedWithDevice:(Device *)device {
    /// Convenience wrapper for `handleModifiersHaveHadEffect:activeModifiers:` if you don't have access to `activeModifiers`
    
    NSDictionary *activeModifiers = [self getActiveModifiersForDevice:device event:nil];
    [ModifierManager handleModificationHasBeenUsedWithDevice:device activeModifiers:activeModifiers];
}
+ (void)handleModificationHasBeenUsedWithDevice:(Device *)device activeModifiers:(NSDictionary *)activeModifiers {
    /// Make sure to pass in device, otherwise this method (in its current form) won't do anything
    
    if (device != nil) {
        /// Notify active *modifiers* that they have had an effect
        for (NSDictionary *buttonPrecondDict in activeModifiers[kMFModificationPreconditionKeyButtons]) {
            NSNumber *precondButtonNumber = buttonPrecondDict[kMFButtonModificationPreconditionKeyButtonNumber];
            [Buttons handleButtonHasHadEffectAsModifierWithDevice:device button:precondButtonNumber];
            /// ^ I think we might only have to notify the last button in the sequence (instead of all of them), because all previous buttons should already have been zombified or sth due to consecutive button presses
        }
    }
}

#pragma mark - Modifier driven modification



#pragma mark Keyboard modifiers

static CFMachPortRef _keyboardModifierEventTap;
static void toggleModifierEventTapBasedOnRemaps(NSDictionary *remaps) {
    
    if (TransformationManager.addModeIsEnabled) {
        CGEventTapEnable(_keyboardModifierEventTap, true);
        return;
    }

    /// If a modification collection exists such that it contains a proactive modification (aka modifierDriver modification) and its precondition contains a keyboard modifier, then activate the event tap.
    for (NSDictionary *modificationPrecondition in remaps) {
        NSDictionary *modificationCollection = remaps[modificationPrecondition];
        BOOL collectionContainsProactiveModification = modificationCollection[kMFTriggerDrag] != nil;
        if (collectionContainsProactiveModification) {
            BOOL modificationDependsOnKeyboardModifier = modificationPrecondition[kMFModificationPreconditionKeyKeyboard] != nil;
            if (modificationDependsOnKeyboardModifier) {
                CGEventTapEnable(_keyboardModifierEventTap, true);
                return;
            }
        }
    }
    CGEventTapEnable(_keyboardModifierEventTap, false);
}

CGEventRef _Nullable handleKeyboardModifiersHaveChanged(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {

    /// Get mouse
    Device *activeDevice = State.activeDevice;
    
    /// Get activeModifiers
    ///     Need to pass in event here as source for keyboard modifers, otherwise the returned kb-modifiers won't be up-to-date.
    ///     -> Idea: This might be because we're using a passive listener eventTap?
    NSDictionary *activeModifiers = [ModifierManager getActiveModifiersForDevice:activeDevice event:event];
    
    /// Do stuff
    reactToModifierChange(activeModifiers, activeDevice);

    /// Return
    return event;
}

#pragma mark Button modifiers

os_log_t _log;
os_signpost_id_t _log_id;

NSArray *_prevButtonModifiers;
/// Analyzing this with `os_signpost` reveals it is called 3 times per button click - we should look into optimizing this.
///     Edit: Why `mightHave`? Do we really need to test again if they actually changed?
+ (void)handleButtonModifiersMightHaveChangedWithDevice:(Device *)device {
    
    NSArray *buttonModifiers = [Buttons getActiveButtonModifiers_UnsafeWithDevice:device];
    if (![buttonModifiers isEqual:_prevButtonModifiers]) {
        handleButtonModifiersHaveChangedWithDevice(device);
    }
    _prevButtonModifiers = buttonModifiers;
}
static void handleButtonModifiersHaveChangedWithDevice(Device *device) {
    NSDictionary *activeModifiers = [ModifierManager getActiveModifiersForDevice:device event:nil];
    reactToModifierChange(activeModifiers, device);
}

#pragma mark Helper

static void reactToModifierChange(NSDictionary *_Nonnull activeModifiers, Device * _Nonnull device) {
    
    /// Get active modifications and initialize any which are modifier driven
    
    /// Debug
    
//    DDLogDebug(@"MODIFIERS HAVE CHANGED TO - %@", activeModifiers);
//    DDLogDebug(@"...ON DEVICE - %@", device);
//    DDLogDebug(@"...CALLED BY %@", [SharedUtility getInfoOnCaller]);
    
    /// Get activeModifications
    NSDictionary *activeModifications = [RemapSwizzler swizzleRemaps:TransformationManager.remaps activeModifiers:activeModifiers];
    
    /// Notify ScrollModifiers of modifierChange
    ///     It needs that to commit to an app in the app switcher when the user releases a button
    ///     TODO: Make sure this always works, and not only when a ModifieDrag makes ModifierManager listen to modifierChanged events
    
    [ScrollModifiers reactToModiferChangeWithActiveModifications:activeModifications];
    
    /// Kill old modifications
    
    /// Kill the currently active modifiedDrag if the modifiers have changed since it started.
    ///     (If there were other modifier driven effects than modifiedDrag in the future, we would also kill them here)

    BOOL modifiedDragIsStillUpToDate = NO;
    
    if ([activeModifiers isEqual:ModifiedDrag.initialModifiers]) {
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
                ///     See TransformationManager.m -> AddMode for context.
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
                
                /// Init modifiedDrag
                [ModifiedDrag initializeDragWithDict:modifiedDragEffectDict initialModifiers:activeModifiers onDevice:device];
            }
        }
    }
}

#pragma mark - Trigger driven modification


#pragma mark Get Modifiers

+ (NSDictionary *)getActiveModifiersForDevice:(Device *)device event:(CGEventRef)event {

    /// \discussion If you pass in an a CGEvent via the `event` argument, the returned keyboard modifiers will be more up-to-date. This is sometimes necessary to get correct data when calling this right after the keyboard modifiers have changed.
    /// \discussion Analyzing with `os_signpost` reveals this is called 9 times per button click and takes around 20% of the time.
    ///     That's over a third of the time which is used by our code (I think) - We should look into optimizing this (if we have too much time - the program is plenty fast). Maybe caching the values or calling it less, or making it faster.
    
    NSMutableDictionary *outDict = [NSMutableDictionary dictionary];
    
    CGEventFlags kb = [self getActiveKeyboardModifiersWithEvent:event];
    NSArray *btn = [Buttons getActiveButtonModifiers_UnsafeWithDevice:device];
        
    if (kb != 0) {
        outDict[kMFModificationPreconditionKeyKeyboard] = @(kb);
    }
    if (btn.count != 0) {
        outDict[kMFModificationPreconditionKeyButtons] = btn;
    }
    
    return outDict;
}

+ (NSUInteger)getActiveKeyboardModifiersWithEvent:(CGEventRef _Nullable)event {
    
    BOOL passedInEventIsNil = NO;
    if (event == nil) {
        passedInEventIsNil = YES;
        event = CGEventCreate(NULL);
    }
    
    uint64_t mask = 0xFF0000; // Only lets bits 16-23 through
    /// NSEventModifierFlagDeviceIndependentFlagsMask == 0xFFFF0000 -> it only allows bits 16 - 31.
    ///  But bits 24 - 31 contained weird stuff which messed up the return value and modifiers are only on bits 16-23, so we defined our own mask
    
    mask &= ~kCGEventFlagMaskAlphaShift;
    /// Ignore caps lock. Otherwise modfifications won't work normally when caps lock is enabled.
    ///     Maybe we need to ignore caps lock in other places, too make this work properly but I don't think so
    ///         We should probably remove this once we update RemapsOverrider to work with subset matches and stuff
    ///         TODO: Remove this now.
    
    CGEventFlags modifierFlags = CGEventGetFlags(event) & mask;
    
    if (passedInEventIsNil) CFRelease(event);
    
    return modifierFlags;
}

@end
