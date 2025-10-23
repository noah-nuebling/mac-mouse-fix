//
// --------------------------------------------------------------------------
// NSColor+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>

@interface NSView (ColorAdditions)
    - (NSColor *)solidColorAtX:(NSInteger)x y:(NSInteger)y;
@end

@interface NSColor (Additions)
    - (NSColor *)flippedColor;
    - (NSColor *)solidColorWithBackground:(NSColor *)background;
    - (NSColor *)solidColor;
@end

@interface NSColor (PrivateStuff)
    - (BOOL) _getSemanticallyEquivalentVisualEffectMaterial: (NSVisualEffectMaterial *) arg1; /// [Aug 2025] Private method on `NSDynamicSystemColor` available in macOS Tahoe Beta 8 || Used in disassembly of `-[_NSBoxMaterialCapableCustomView _updateSubviews]`, which we're trying to emulate in AddField.swift, but we didn't end up using it.
@end
