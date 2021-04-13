//
// --------------------------------------------------------------------------
// ButtonGroupRowView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ButtonGroupRowView.h"
#import "AppDelegate.h"

@implementation ButtonGroupRowView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    
    // Clip so drawing doesn't spill out on the sides
    NSRect clippingRect = NSInsetRect(dirtyRect, 1, 0); // Clip side borders
    
    NSRectClip(clippingRect);
    
    // Draw background
    NSColor *backgroundColor;
    if (@available(macOS 10.14, *)) {
        backgroundColor = NSColor.alternatingContentBackgroundColors[1];
    } else {
        backgroundColor = NSColor.controlAlternatingRowBackgroundColors[1];
    }
//    backgroundColor = [[NSColor colorWithWhite:0.0 alpha:0.02] setFill];
    CGFloat originalAlpha = backgroundColor.alphaComponent;
    NSLog(@"Background color has alpha: %f", originalAlpha);
    if ([NSAppearance.currentAppearance.name isEqual:NSAppearanceNameAqua]) {
        CGFloat newAlpha = originalAlpha / 3;
        backgroundColor = [backgroundColor colorWithAlphaComponent:newAlpha];
    }
    [backgroundColor setFill];
    NSRectFill(dirtyRect);
    
    // Draw border

    clippingRect.size.height -= 1; // Clip top border
    clippingRect.origin.y += 1;
    NSRectClip(clippingRect);
    
//    NSColor *gridColor = AppDelegate.instance.remapsTable.gridColor;
    NSColor *gridColor = NSColor.gridColor;
    
    NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:dirtyRect];
    borderPath.lineWidth = 2;
    [gridColor setStroke];
//    [[NSColor colorWithWhite:0.0 alpha:0.15] setStroke];
    [borderPath stroke];
}

//- (void)drawSeparatorInRect:(NSRect)dirtyRect {
//    // v Doesn't work
//    [NSColor.redColor setFill];
//    NSRectFill(dirtyRect);
//}
//
//- (void)awakeFromNib {
//    // v Doesn't work
//    self.wantsLayer = YES;
//    self.layer.backgroundColor = (__bridge CGColorRef)NSColor.redColor;
//}

@end
