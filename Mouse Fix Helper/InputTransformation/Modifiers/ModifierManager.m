//
// --------------------------------------------------------------------------
// ModifierManager.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ModifierManager.h"
#import "ButtonInputParser.h"

@implementation ModifierManager

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
        outDict[@"keyboardModifiers"] = @(kb);
    }
    if (btn.allKeys.count != 0) {
        outDict[@"buttonModifiers"] = btn;
    }
    
    return outDict;
}
static NSUInteger getActiveKeyboardModifiers() {
    NSEventModifierFlags modifierFlags = [NSEvent modifierFlags]
        & NSDeviceIndependentModifierFlagsMask; // Not sure if this does anything
    return modifierFlags;
}

+ (void)handleButtonModifiersHaveChanged {
    // TODO: Implement
}

@end
