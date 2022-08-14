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
    
    /// Save graphics context so we can undo clipping
    [NSGraphicsContext saveGraphicsState];
    
    /// Clip for background drawing
    NSRect clippingRect = NSInsetRect(dirtyRect, 0, 0); /// Don't Clip side borders (Since 2.2.0 or so we changed the table inset, so this isn't necessary any more.)
    clippingRect.size.height -= 1; /// Clip bottom border
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
    
    /// Undo clipping
    [NSGraphicsContext restoreGraphicsState];
    
    if (@available(macos 13.0, *)) {
        /// Before Ventura, we just made the tableView have a "Horizontal Grid" in IB and that drew a line under the groupRow.
        /// But in Ventura Beta, that doesn't seem to work anymore. There's no more line under the groupRow.
        /// So now we're drawing the bottom border manually!
    
        /// Get drawing rect
        ///     Make it one px too wide and then clip top and sides to just end up drawing a line.
        NSRect borderRect = NSInsetRect(dirtyRect, -1, 0);
        
        /// Clip for border drawing
        clippingRect = dirtyRect;
        clippingRect = NSInsetRect(dirtyRect, 0, 0); /// Clip side borders 
        clippingRect.size.height -= 1; /// Clip top border
        clippingRect.origin.y += 1;
        NSRectClip(clippingRect);
        
        /// Get border color
        NSColor *gridColor;
        if (@available(macOS 10.14, *)) {
            gridColor = NSColor.separatorColor;
        } else {
            gridColor = AppDelegate.instance.remapsTable.gridColor; /// Should be same as NSColor.gridColor
        }
        NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:borderRect];
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
