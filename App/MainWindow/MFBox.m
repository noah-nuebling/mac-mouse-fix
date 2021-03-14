//
// --------------------------------------------------------------------------
// MFBox.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MFBox.h"

@implementation MFBox

- (void)drawRect:(NSRect)dirtyRect { //  This is not called for some reason
    [super drawRect:dirtyRect];
#if DEBUG
    NSLog(@"DRAWING RECT");
#endif
    [self drawBoxBorder:dirtyRect];
}

// See https://stackoverflow.com/questions/15184133/add-a-border-outside-of-a-uiview-instead-of-inside for more ways to draw external border
- (void)drawBoxBorder:(NSRect)rect {
//    CGFloat cornerRadius = self.cornerRadius;
//    NSRect borderRect = NSMakeRect(rect.origin.x-1, rect.origin.y-1, rect.size.width+2, rect.size.height+2);
//    
//    NSBezierPath *borderPath = [NSBezierPath bezierPathWithRoundedRect:borderRect xRadius:cornerRadius yRadius:cornerRadius];
//    [borderPath setLineWidth:5.0];
//    NSColor *borderColor = NSColor.greenColor;
//    [borderColor set];
//    [borderPath stroke];
}

@end
