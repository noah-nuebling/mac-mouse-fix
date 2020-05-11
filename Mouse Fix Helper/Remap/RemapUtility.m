//
// --------------------------------------------------------------------------
// RemapUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "RemapUtility.h"
#import <Cocoa/Cocoa.h>

@implementation RemapUtility

+ (NSDictionary *)getCurrentModifiers {
    NSMutableDictionary *outDict = [NSMutableDictionary dictionary];
    
    // This is unusable, because it updates too slowly after posting a keyEvent with a modifier through `[ButtonInputParser doSymbolicHotKeyAction]`. It thinks the modifiers from the fake event are still pressed.
    NSEventModifierFlags modifierFlags = [NSEvent modifierFlags]
    & NSDeviceIndependentModifierFlagsMask; // Not sure if this does anything
    
    
//    CGEventFlags modifierFlags = CGEventGetFlags(CGEventCreate(NULL))
//    & NSDeviceIndependentModifierFlagsMask; // Not sure if this does anything
    if (modifierFlags != 0) {
        outDict[@"keyboardModifierFlags"] = @(modifierFlags);
    }
    
    return outDict;
}

@end
