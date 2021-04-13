//
// --------------------------------------------------------------------------
// ButtonGroupRowView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ButtonGroupRowView.h"

@implementation ButtonGroupRowView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Clip so drawing doesn't spill out on the sides
    NSRect clippingRect = NSInsetRect(dirtyRect, 1, 0);
    NSRectClip(clippingRect);
    
    // Draw background
//    [NSColor.alternatingContentBackgroundColor setFill];
//    NSRectFill(dirtyRect);
    
    // Draw border

    NSBezierPath *borderPath = [NSBezierPath bezierPathWithRect:dirtyRect];
    borderPath.lineWidth = 2;
    [NSColor.gridColor setStroke];
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
