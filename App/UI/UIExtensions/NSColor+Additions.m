//
// --------------------------------------------------------------------------
// NSColor+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "NSColor+Additions.h"
#import "Mac_Mouse_Fix-Swift.h"

@implementation NSView (ColorAdditions)

- (void)suspendTransparency {
    
    /// Idea for temporarily removing transparency:
    ///     1. Make view contents invisible. Take screenshot of invisible view (only contains background) 2. set image as background image of the view.
    ///     -> This way the view's appearance shouldn't change but any new changes to the *actual* background won't affect the view anymore.
    ///     Problem: Can't set background image easily
    
    assert(false);
}

- (NSColor *)solidColorAtX:(NSInteger)x y:(NSInteger)y {
    /// Not sure this is useful
    
    CGImageRef image = (__bridge CGImageRef)[self takeImage];
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithCGImage:image];
    NSColor *color = [bitmap colorAtX:x y:y];
    
    return color;
}

@end

@implementation NSColor (Additions)

- (NSColor *)flippedColor {
    /// Color that looks like receive on neutral background but with an alpha of 1.0
    
    NSColor *s = [self colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
    
    CGFloat a = s.alphaComponent;
    CGFloat r = s.redComponent;
    CGFloat g = s.greenComponent;
    CGFloat b = s.blueComponent;
    
    return [NSColor colorWithRed:(1-r) green:(1-g) blue:(1-b) alpha:a];
}

- (NSColor *)solidColor {
    /// Color that looks like receive on neutral background but with an alpha of 1.0
    
    NSColor *neutral = [NSColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    return [self solidColorWithBackground:neutral];
}

- (NSColor *)solidColorWithBackground:(NSColor *)background {
    /// Solid color that looks like receiver on top of `background` (Solid -> alpha == 1)
    /// background color needs to be solid
    
    NSColor *s = [self colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
    
    CGFloat a = s.alphaComponent;
    CGFloat r_s = s.redComponent;
    CGFloat g_s = s.greenComponent;
    CGFloat b_s = s.blueComponent;
    
    NSColor *bg = [background colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
    
    CGFloat a_bg = bg.alphaComponent;
    assert(a_bg == 1.0);
    CGFloat r_bg = bg.redComponent;
    CGFloat g_bg = bg.greenComponent;
    CGFloat b_bg = bg.blueComponent;
    
        
    CGFloat r_r = a * r_s + (1-a) * r_bg;
    CGFloat g_r = a * g_s + (1-a) * g_bg;
    CGFloat b_r = a * b_s + (1-a) * b_bg;
    
    NSColor *result = [NSColor colorWithRed:r_r green:g_r blue:b_r alpha:1.0];
    
    return result;
}

@end
