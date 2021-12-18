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

- (instancetype)init {
    if (self = [super init]) {
        /// Nothing
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    /// Clip for background drawing
    NSRect clippingRect = NSInsetRect(dirtyRect, 1, 0); /// Clip side borders
    clippingRect.size.height -= 1; /// Clip bottom (?) border
    NSRectClip(clippingRect);
    
    /// Get background color
    NSColor *backgroundColor;
    if (@available(macOS 10.14, *)) {
        backgroundColor = NSColor.alternatingContentBackgroundColors[1];
    } else {
        backgroundColor = NSColor.controlAlternatingRowBackgroundColors[1];
    }
    CGFloat alpha = backgroundColor.alphaComponent;
    if ([NSAppearance.currentAppearance.name isEqual:NSAppearanceNameAqua]) {
        alpha = alpha / 3;
        backgroundColor = [backgroundColor colorWithAlphaComponent:alpha];
    }
    
    /// Draw background
    [backgroundColor setFill];
    NSRectFill(dirtyRect);
        
    
    if ((NO)) { /// Don't need to draw border manually when using horizontal grid
        
        // Clip for border drawing
        NSRect clippingRect = NSInsetRect(dirtyRect, 1, 0); // Clip side borders
        clippingRect.size.height -= 1; // Clip top border
        clippingRect.origin.y += 1;
        NSRectClip(clippingRect);
        
        // Get border color
        NSColor *gridColor;
        if (@available(macOS 10.14, *)) {
             gridColor = NSColor.separatorColor;
        } else {
            gridColor = AppDelegate.instance.remapsTable.gridColor; // Should be same as NSColor.gridColor
        }
        
        // Draw border
        NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:dirtyRect];
        borderPath.lineWidth = 2;
        [gridColor setStroke];
        [borderPath stroke];
    }
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
