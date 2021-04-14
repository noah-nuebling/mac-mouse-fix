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
    
    // Get grid color
//    NSColor *gridColor = AppDelegate.instance.remapsTable.gridColor;
    NSColor *gridColor = NSColor.gridColor;
    
    // Get backgroundColor
    NSColor *backgroundColor;
    if (@available(macOS 10.14, *)) {
        backgroundColor = NSColor.alternatingContentBackgroundColors[1];
    } else {
        backgroundColor = NSColor.controlAlternatingRowBackgroundColors[1];
    }
    CGFloat alpha = backgroundColor.alphaComponent;
    if ([NSAppearance.currentAppearance.name isEqual:NSAppearanceNameAqua]) {
        alpha = alpha / 2;
        backgroundColor = [backgroundColor colorWithAlphaComponent:alpha];
    }
    
    // Set clipping for background drawing. 
    NSRect clippingRect = NSInsetRect(dirtyRect, 1, 0); // Clip side borders
    NSRectClip(clippingRect);
    
    // Draw background
    [backgroundColor setFill];
    NSRectFill(dirtyRect);
    
    // Override background to border color
//    [gridColor setFill];
//    NSRectFill(dirtyRect);

    // Set clipping for border drawing
    clippingRect.size.height -= 1; // Clip top border
    clippingRect.origin.y += 1;
    NSRectClip(clippingRect);
    
    // Draw border
    
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
