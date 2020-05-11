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
    
    NSEventModifierFlags modifierFlags = [NSEvent modifierFlags];
    if (modifierFlags != 0) {
        outDict[@"keyboardModifierFlags"] = @(modifierFlags);
    }
    
    return outDict;
}

@end
