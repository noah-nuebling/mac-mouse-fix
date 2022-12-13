//
// --------------------------------------------------------------------------
// ButtonGroupRowView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "ButtonGroupRowView.h"
#import "AppDelegate.h"
#import "Mac_Mouse_Fix-Swift.h"

@implementation ButtonGroupRowView

- (instancetype)init {
    if (self = [super init]) {
        /// Nothing
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    
//    [super drawRect:dirtyRect];
    
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
        
        CGFloat alpha = backgroundColor.alphaComponent;
        if ([NSAppearance.currentAppearance.name isEqual:NSAppearanceNameAqua]) {
            alpha = alpha / 3;
            backgroundColor = [backgroundColor colorWithAlphaComponent:alpha];
        }
        
    } else {
        backgroundColor = NSColor.controlAlternatingRowBackgroundColors[1];
        backgroundColor = [backgroundColor blendedColorWithFraction:0.4 ofColor:NSColor.whiteColor];
    }
    
    /// Draw background
    [backgroundColor setFill];
    NSRectFill(dirtyRect);
    
    /// Undo clipping
    [NSGraphicsContext restoreGraphicsState];
    
    /// Draw bottom border
    /// - Before Ventura, we just made the tableView have a "Horizontal Grid" in IB and that drew a line under the groupRow.
    ///     But in Ventura Beta, that doesn't seem to work anymore. There's no more line under the groupRow.
    ///  - So now we're drawing the bottom border manually!
    ///  - Edit: Under 10.13 and 10.14 and MMF 2.2.2 the groupRow borders didn't display properly. We fixed that by removing the `[super drawRect:dirtyRect]` call and drawing the bottom border for those versions, just like we are for Ventura.
    ///     - Tested this under. 10.13, 10.14, 12, and 13 -> Works fine on all these versions
    ///  - TODO?: Test if it also works on Catalina and Big Sur

    /// Get drawing rect
    ///     Make it one px too wide and then clip top and sides to just end up drawing a line.
    NSRect borderRect = NSInsetRect(dirtyRect, -1, 0);
    
    /// Clip for border drawing
    clippingRect = NSInsetRect(dirtyRect, 0, 0); /// Clip side borders
    clippingRect.size.height -= 1; /// Clip top border
    clippingRect.origin.y += 1;
    NSRectClip(clippingRect);
    
    /// Get border color
    NSColor *gridColor;
    if (@available(macOS 10.14, *)) {
        gridColor = NSColor.separatorColor;
    } else {
        gridColor = MainAppState.shared.remapTable.gridColor; /// Should be same as NSColor.gridColor
    }
    NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:borderRect];
    borderPath.lineWidth = 2;
    [gridColor setStroke];
    [borderPath stroke];
}


//- (void)drawSeparatorInRect:(NSRect)dirtyRect {
//    // v Doesn't work
//    [NSColor.redColor setFill];
//    NSRectFill(dirtyRect);
//}
//
- (void)awakeFromNib {
    /// Set backgroundColor
    ///     Doesn't work. We transitioned to overriding `drawRect:` instead
//    self.wantsLayer = YES;
//    self.layer.backgroundColor = (__bridge CGColorRef)NSColor.redColor;
}

@end
