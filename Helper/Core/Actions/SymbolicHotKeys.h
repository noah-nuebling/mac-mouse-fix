//
// --------------------------------------------------------------------------
// SymbolicHotKeys.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "CGSHotKeys.h"
#import "MFDataClass.h"

MFDataClassInterface2(MFDataClassBase, MFVKCAndFlags, /// Belongs to `MFEmulateNSMenuItemRemapping()` [Aug 2025]
    readwrite, assign, , CGKeyCode, vkc,
    readwrite, assign, , CGEventFlags, modifierMask
)
MFVKCAndFlags *_Nonnull MFEmulateNSMenuItemRemapping(CGKeyCode vkc, CGEventFlags modifierMask);

@interface SymbolicHotKeys : NSObject

+ (void) post: (CGSSymbolicHotKey)shk;

@end
