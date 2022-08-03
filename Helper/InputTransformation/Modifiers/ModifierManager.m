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

/// Trigger driven modification -> when the trigger to be modified comes in, we check how we want to modify it
/// Modifier driven modification -> when the modification becomes active, we preemtively modify the triggers which it modifies
#pragma mark - --- Load

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
        
        // Re-toggle keyboard modifier callbacks whenever TransformationManager.remaps changes
        // TODO:! Test if this works
        [NSNotificationCenter.defaultCenter addObserverForName:kMFNotifCenterNotificationNameRemapsChanged
                                                        object:nil
                                                         queue:nil
                                                    usingBlock:^(NSNotification * _Nonnull note) {
            DDLogDebug(@"Received notification that remaps have changed");
            toggleModifierEventTapBasedOnRemaps(TransformationManager.remaps);
        }];
    }
}
#pragma mark - --- Modifier driven modification
///
///
///
#pragma mark Keyboard modifiers

static CFMachPortRef _keyboardModifierEventTap;
static void toggleModifierEventTapBasedOnRemaps(NSDictionary *remaps) {
    
    if (TransformationManager.addModeIsEnabled) {
        CGEventTapEnable(_keyboardModifierEventTap, true);
        return;
    }

    // If a modification collection exists such that it contains a proactive modification and its precondition contains a keyboard modifier, then activate the event tap.
    for (NSDictionary *modificationPrecondition in remaps) {
        NSDictionary *modificationCollection = remaps[modificationPrecondition];
        BOOL collectionContainsProactiveModification = modificationCollection[kMFTriggerDrag] != nil;
            // ^ proactive modification === modifier driven modification !== trigger driven modification
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

/// Helper function for `handleKeyboardModifiersHaveChanged()`.
/// If several mice are attached, they can have different modifier states (if different buttons are pressed on each device)
/// This function figures out, which mouse's' activeModifiers we want to send to `reactToModiferChange()`, when the kb mods change.
/// It's a heuristic which just returns the first device (and its active modifiers) it finds, which has any buttons pressed (or equivalently, which has a non-nil button component in its modification precondition). Or it returns the last devices precond, if none of them have a button pressed.
/// This is what this heuristic does in the three different possible scenarios:
///     - 1. No device has any pressed buttons -> Returns activeModifiers of last device it finds. This works well, because in this case, all devices' activeModifiers are the same and it doesn't matter which one it returns.
///     - 2.  Only one device has pressed buttons -> It will return that device and its activeModifers. This makes sense because if a device has pressed buttons, that's almost certainly the device which the user is currently using.
///     - 3. Several devices have pressed buttons -> In this case it will return an arbitrary device and its activeModifiers. This is not ideal, but this scenario is extremely unlikely so it's fine.
///     TODO: Delete this and use the new capability of `getActiveModifiersForDevice:` where you can just pass nil as the devID. ...But then we have no way of getting back the device with the pressed button that we found
void getActiveModifiersForDeviceWithPressedButtons(CGEventRef event, NSDictionary **activeModifiers, Device **device) {
    NSArray *devices = DeviceManager.attachedDevices;
    for (int i = 0; i < devices.count; i++) {
        BOOL isLast = devices.count-1 == i;
        Device *thisDevice = devices[i];
        Device *d;
        NSDictionary *activeModifiersForThisDevice = [ModifierManager getActiveModifiersForDevice:&d filterButton:nil event:event];
        if (activeModifiersForThisDevice[kMFModificationPreconditionKeyButtons] != nil || isLast) {
            *activeModifiers = activeModifiersForThisDevice;
            *device = thisDevice;
            return;
        }
    }
//    assert(false); // This leads to crash loop. I think if accessibility isn't enabled.
}
CGEventRef _Nullable handleKeyboardModifiersHaveChanged(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
//    CGEventTapPostEvent(proxy, event); // Why were we doing that? (Maybe it made sense when the eventTap was not listenOnly?)
    
    NSDictionary *activeModifiers;
    Device *device;
    getActiveModifiersForDeviceWithPressedButtons(event, &activeModifiers, &device);
    // ^ Need to pass in event here as source for keyboard modifers, otherwise the returned kb-modifiers won't be up-to-date.
    reactToModifierChange(activeModifiers, device);
    
    return nil; // This is a passive listener, so it doesn't matter what we return
}

#pragma mark Button modifiers

os_log_t _log;
os_signpost_id_t _log_id;

NSArray *_prevButtonModifiers;
/// Analyzing this with `os_signpost` reveals it is called 3 times per button click - we should look into optimizing this.
///     Edit: Why `mightHave`? Do we really need to test again if they actually changed?
+ (void)handleButtonModifiersMightHaveChangedWithDevice:(Device *)device {
    
    NSArray *buttonModifiers = [Buttons getActiveButtonModifiers_UnsafeWithDevicePtr:&device];
    if (![buttonModifiers isEqual:_prevButtonModifiers]) {
        handleButtonModifiersHaveChangedWithDevice(device);
    }
    _prevButtonModifiers = buttonModifiers;
}
static void handleButtonModifiersHaveChangedWithDevice(Device *device) {
    NSDictionary *activeModifiers = [ModifierManager getActiveModifiersForDevice:&device filterButton:nil event:nil];
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
    
    NSDictionary *activeModifications = RemapsOverrider.effectiveRemapsMethod(TransformationManager.remaps, activeModifiers);
    
    /// Notify ScrollModifiers of modifierChange
    ///     It needs that to commit to an app in the app switcher when the user releases a button
    
    [ScrollModifiers reactToModiferChangeWithActiveModifications: activeModifications];
    
    /// Kill old modifications
    
    /// Kill the currently active modifiedDrag if it's differrent from the one that the one in activeModifications
    ///     (If there were other modifier driven effects than modifiedDrag in the future, we would also kill them here)

    BOOL modifiedDragIsStillUpToDate = NO;
    
    if ([activeModifications[kMFTriggerDrag] isEqual: ModifiedDrag.dict]) {
        modifiedDragIsStillUpToDate = YES;
    } else {
        [ModifiedDrag deactivate];
    }
    
    /// Init new modifications
    
    if (activeModifications) {
        
        /// Init modifiedDrag
        ///    (If there were other modifier driven effects than modifiedDrag in the future, we would also init them here)
        
        if (!modifiedDragIsStillUpToDate) {
        
            NSMutableDictionary *modifiedDragEffect = activeModifications[kMFTriggerDrag]; /// Declared as NSMutableDictionary but probably not actually mutable at this point
            if (modifiedDragEffect) {
                
                /// If addMode is active, add activeModifiers to modifiedDragDict
                ///     See TransformationManager.m -> AddMode for context.
                if ([modifiedDragEffect[kMFModifiedDragDictKeyType] isEqualToString:kMFModifiedDragTypeAddModeFeedback]) {
                    modifiedDragEffect = modifiedDragEffect.mutableCopy; /// Make actually mutable
                    Device *d;
                    modifiedDragEffect[kMFRemapsKeyModificationPrecondition] = [ModifierManager getActiveModifiersForDevice:&d filterButton:nil event:nil despiteAddMode:YES]; /// Add activeModifiers
                }
                
                /// Determine usage threshold based on other active modifications
                ///     It's easy to accidentally drag the mouse while trying to scroll so in that case we want a larger usageThreshold to avoid accidental drag activation
                BOOL largeUsageThreshold = NO;
                if (activeModifications[kMFTriggerScroll] != nil) {
                    largeUsageThreshold = YES;
                }
                
                /// Init modifiedDrag
                [ModifiedDrag initializeDragWithModifiedDragDict:modifiedDragEffect onDevice:device];
            }
        }
    }
}

#pragma mark Send Feedback

+ (void)handleModificationHasBeenUsedWithDevice:(Device *)device {
    /// Convenience wrapper for `handleModifiersHaveHadEffect:activeModifiers:` if you don't have access to `activeModifiers`
    
    NSDictionary *activeModifiers = [self getActiveModifiersForDevice:&device filterButton:nil event:nil despiteAddMode:YES];
    /// ^ Using despiteAddMode: YES bc it works
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

#pragma mark - --- Trigger driven modification

/// Explanation: Modification of most triggers is *trigger driven*.
///      That means only once the trigger comes in, we'll check for active modifiers and then apply those to the incoming trigger.
///      But sometimes its not feasible to always listen for triggers (for example in the case of modified drags, for performance reasons, you don't want to listen to mouseMoved events all the time)
///      In those cases we'll use *modifier driven* modification.
///      That means we listen for changes to the active modifiers and when they match a modifications' precondition, we'll initialize the modification components which are modifier driven.
///      Then, when they do ((send their first trigger))?, they'll call `modifierDrivenModificationHasBeenUsedWithDevice` which will in turn notify the modifying buttons that they've had an effect
///         ( ^ Edit: I don't think the line above is still correct. I think instead, for both triggerDriven and modifierDriven modification, `handleModifiersHaveHadEffectWithDevice` is called once they first have an effect)
/// \discussion If you pass in an a CGEvent via the `event` argument, the returned keyboard modifiers will be more up-to-date. This is sometimes necessary to get correct data when calling this right after the keyboard modifiers have changed.
/// \discussion Analyzing with os_signpost reveals this is called 9 times per button click and takes around 20% of the time.
///      That's over a third of the time which is used by our code (I think) - We should look into optimizing this (if we have too much time - the program is plenty fast). Maybe caching the values or calling it less, or making it faster.
/// \discussion If you pass in a pointer to nil for the `devID`, this function will try to find some device that has buttons pressed and use that to get the active modifiers and write id of the device it found into the `devID` argument. We never expect the user to use several mice at once, so this should work fine. If no device with any pressed buttons can be found, `devIDPtr` will be a pointer to nil upon return.

+ (NSDictionary *)getActiveModifiersForDevice:(Device **)devicePtr filterButton:(NSNumber *)filteredButton event:(CGEventRef)event {
    
    return [self getActiveModifiersForDevice:devicePtr filterButton:filteredButton event:event despiteAddMode:NO];
}

+ (NSDictionary *)getActiveModifiersForDevice:(Device **)devicePtr filterButton:(NSNumber *)filteredButton event:(CGEventRef)event despiteAddMode:(BOOL)despiteAddMode {
    
//    DDLogDebug(@"ActiveModifiers requested by: %s\n", SharedUtility.callerInfo.UTF8String);
    
    if (TransformationManager.addModeIsEnabled && !despiteAddMode) {
        /// ^ AddMode needs to work no matter which modifiers are pressed, so we hack around things by lying and saying that no modifiers are pressed during addMode.
        ///     To get the real modifiers despite addMode, pass in `YES` for `despiteAddMode`. You should only need this when fetching modifiers for the addMode payload to send back to the mainApp
        return @{};
    };
    
    NSMutableDictionary *outDict = [NSMutableDictionary dictionary];
    
    CGEventFlags kb = [self getActiveKeyboardModifiersWithEvent:event];
    NSMutableArray *btn = [Buttons getActiveButtonModifiers_UnsafeWithDevicePtr:devicePtr].mutableCopy;
    
    if (filteredButton != nil && btn.count != 0) {
        NSIndexSet *filterIndexes = [btn indexesOfObjectsPassingTest:^BOOL(NSDictionary *_Nonnull dict, NSUInteger idx, BOOL * _Nonnull stop) {
            return [dict[kMFButtonModificationPreconditionKeyButtonNumber] isEqualToNumber:filteredButton];
        }];
        [btn removeObjectsAtIndexes:filterIndexes];
    }
    /// ^ filteredButton is used by `handleButtonTriggerWithButton:trigger:level:device:` to remove modification state caused by the button causing the current input trigger.
        /// Don't fully understand this but I think a button shouldn't modify its own triggers.
        /// You can't even produce a mouse down trigger without activating the button as a modifier... Just doesn't make sense.
    /// Edit: But if we make sure that a button can never define a button modification on itself, then shouldn't it not matter if we filter the buttons out or not?
    
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
