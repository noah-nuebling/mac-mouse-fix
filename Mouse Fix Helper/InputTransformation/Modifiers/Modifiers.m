//
// --------------------------------------------------------------------------
// ModifierManager.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Constants.h"

#import "Modifiers.h"
#import "ButtonInputParser.h"
#import "TransformationManager.h"
#import "ModifiedDrag.h"


@implementation Modifiers

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
    NSMutableDictionary *btn = ((NSDictionary *)[ButtonInputParser getActiveButtonModifiersForDevice:devID]).mutableCopy;
    if (filteredButton != nil) {
        [btn removeObjectForKey:filteredButton];
    }
    // ^ filteredButton is used by `handleButtonTriggerWithButton:trigger:level:device:` to remove modification state caused by the button causing the current input trigger.
        // Don't fully understand this but I think a button shouldn't modify its own triggers.
        // You can't even produce a mouse down trigger without activating the button as a modifier... Just doesn't make sense.
    
    if (kb != 0) {
        outDict[kMFModifierKeyKeyboard] = @(kb);
    }
    if (btn.allKeys.count != 0) {
        outDict[kMFModifierKeyButtons] = btn;
    }
    
    return outDict;
}
static NSUInteger getActiveKeyboardModifiers() {
    NSEventModifierFlags modifierFlags = [NSEvent modifierFlags]
        & NSDeviceIndependentModifierFlagsMask; // Not sure if this does anything
    return modifierFlags;
}

#pragma mark - Modifier driven modification

+ (void)handleButtonModifiersHaveChangedWithDevice:(MFDevice *)device {
    
    NSDictionary *activeModifiers = [self getActiveModifiersForDevice:device.uniqueID filterButton:nil];
    
    // Kill the currently active modified drag
    //      (or any other effects which are modifier driven, but currently modified drag is the only one)
    // \note The precondition for the currently active modified drag can't be true anymore because
    //      we know that the activeModifers have changed (that's why this function was called)
    //      Because of this we can simply kill it without any further checks
    
    // TODO:! Implement
    
    // Get active modifications and initialize any which are trigger driven
    NSDictionary *r = TransformationManager.remaps;
    NSDictionary *activeModifications = r[activeModifiers];
    if (activeModifications) {
        // Initialize effects which are trigger driven (modified drag)
        NSString *dragType = activeModifications[kMFRemapsKeyModifiedDrag];
        if (dragType) {
            [ModifiedDrag initializeModifiedDragWithType:dragType onDevice:device];
        }
    }
}

+ (void)modifierDrivenModificationHasBeenUsedWithDevice:(MFDevice *)device {
    
    NSDictionary *activeModifiers = [self getActiveModifiersForDevice:device.uniqueID filterButton:nil];
    for (NSNumber *button in activeModifiers[kMFModifierKeyButtons]) {
        [ButtonInputParser handleButtonHasHadEffectAsModifierWithDevice:device.uniqueID button:button];
    }
}

@end
