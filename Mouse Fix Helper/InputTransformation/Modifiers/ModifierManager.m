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


@implementation ModifierManager

#pragma mark - Load

+ (void)load {
    
    // Create keyboard modifier event tap
    CGEventMask mask = CGEventMaskBit(kCGEventFlagsChanged);
    _keyboardModifierEventTap = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, mask, handleKeyboardModifiersHaveChanged, NULL);
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _keyboardModifierEventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    CFRelease(runLoopSource);
    
    // Toggle keyboard modifier callbacks based on TransformationManager.remaps
    toggleModifierEventTapBasedOnRemaps(TransformationManager.remaps);
    
    // Re-toggle keyboard modifier callbacks whenever TransformationManager.remaps changes
    // TODO:! Test if this works
    [NSNotificationCenter.defaultCenter addObserverForName:kMFNotificationNameRemapsChanged
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification * _Nonnull note) {
#if DEBUG
        NSLog(@"Received notification that remaps have changed");
#endif
        toggleModifierEventTapBasedOnRemaps(TransformationManager.remaps);
    }];
}
#pragma mark - Modifier driven modification

#pragma mark Keyboard modifiers

static CFMachPortRef _keyboardModifierEventTap;
static void toggleModifierEventTapBasedOnRemaps(NSDictionary *remaps) {

    // If a modification collection exists such that it contains a proactive modification and its precondition contains a keyboard modifier, then activate the event tap.
    for (NSDictionary *modificationPrecondition in remaps) {
        NSDictionary *modificationCollection = remaps[modificationPrecondition];
        BOOL collectionContainsProactiveModification = modificationCollection[kMFRemapsKeyModifiedDrag] != nil;
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

CGEventRef _Nullable handleKeyboardModifiersHaveChanged(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    CGEventTapPostEvent(proxy, event);
    
    NSArray<MFDevice *> *devs = DeviceManager.attachedDevices;
    for (MFDevice *dev in devs) {
        NSDictionary *activeModifiers = [ModifierManager getActiveModifiersForDevice:dev.uniqueID filterButton:nil];
        
        // The keyboard component of activeModifiers doesn't update fast enough so we have to manually edit it
        // This is kinofa hack we should maybe look into a better solution
        NSMutableDictionary *activeModifiersNew = activeModifiers.mutableCopy;
        activeModifiersNew[kMFModificationPreconditionKeyKeyboard] = @(CGEventGetFlags(event) & NSDeviceIndependentModifierFlagsMask);
        
        reactToModifierChange(activeModifiersNew, dev);
    }
    return nil;
}

#pragma mark Button modifiers

+ (void)handleButtonModifiersHaveChangedWithDevice:(MFDevice *)device {
    NSDictionary *activeModifiers = [ModifierManager getActiveModifiersForDevice:device.uniqueID filterButton:nil];
    reactToModifierChange(activeModifiers, device);
}

#pragma mark Helper

static void reactToModifierChange(NSDictionary *_Nonnull activeModifiers, MFDevice * _Nonnull device) {
    
#if DEBUG
    //NSLog(@"MODFIERS HAVE CHANGED TO - %@", activeModifiers);
#endif
    
    // Kill the currently active modified drag
    //      (or any other effects which are modifier driven, but currently modified drag is the only one)
    // \note The precondition for any currently active modifications can't be true anymore because
    //      we know that the activeModifers have changed (that's why this function was called)
    //      Because of this we can simply kill everything without any further checks
    [ModifiedDrag deactivate];
    
    // Get active modifications and initialize any which are trigger driven
    NSDictionary *r = TransformationManager.remaps;
    NSDictionary *activeModifications = r[activeModifiers];
    if (activeModifications) {
        // Initialize effects which are trigger driven (only modified drag)
        NSString *modifiedDragType = activeModifications[kMFRemapsKeyModifiedDrag];
        if (modifiedDragType) {
            [ModifiedDrag initializeModifiedDragWithType:modifiedDragType onDevice:device];
        }
    }
}

#pragma mark Send Feedback

+ (void)handleModifiersHaveHadEffect:(NSNumber *)devID {
    
    NSDictionary *activeModifiers = [self getActiveModifiersForDevice:devID filterButton:nil];
        
    // Notify all active button modifiers that they have had an effect
    for (NSNumber *precondButton in activeModifiers[kMFModificationPreconditionKeyButtons]) {
        [ButtonTriggerGenerator handleButtonHasHadEffectAsModifierWithDevice:devID button:precondButton];
    }
}

#pragma mark - Trigger driven modification
// Explanation: Modification of most triggers is *trigger driven*.
//      That means only once the trigger comes in, we'll check for active modifiers and then apply those to the incoming trigger.
//      But sometimes its not feasible to always listen for triggers (for example in the case of modified drags, for performance reasons)
//      In those cases we'll use *modifier driven* modification.
//      That means we listen for changes to the active modifiers and when they match a modifications' precondition, we'll initialize the modification components which are modifier driven.
//      Then, when they do send their first trigger, they'll call modifierDrivenModificationHasBeenUsedWithDevice which will in turn notify the modifying buttons that they've had an effect

+ (NSDictionary *)getActiveModifiersForDevice:(NSNumber *)devID filterButton:(NSNumber * __nullable)filteredButton {
    
    NSMutableDictionary *outDict = [NSMutableDictionary dictionary];
    
    NSUInteger kb = getActiveKeyboardModifiers();
    NSMutableDictionary *btn = ((NSDictionary *)[ButtonTriggerGenerator getActiveButtonModifiersForDevice:devID]).mutableCopy;
    if (filteredButton != nil) {
        [btn removeObjectForKey:filteredButton];
    }
    // ^ filteredButton is used by `handleButtonTriggerWithButton:trigger:level:device:` to remove modification state caused by the button causing the current input trigger.
        // Don't fully understand this but I think a button shouldn't modify its own triggers.
        // You can't even produce a mouse down trigger without activating the button as a modifier... Just doesn't make sense.
    
    if (kb != 0) {
        outDict[kMFModificationPreconditionKeyKeyboard] = @(kb);
    }
    if (btn.allKeys.count != 0) {
        outDict[kMFModificationPreconditionKeyButtons] = btn;
    }
    
    return outDict;
}
static NSUInteger getActiveKeyboardModifiers() {
    CGEventFlags modifierFlags = CGEventGetFlags(CGEventCreate(nil)) & NSDeviceIndependentModifierFlagsMask;
    return modifierFlags;
}

@end
