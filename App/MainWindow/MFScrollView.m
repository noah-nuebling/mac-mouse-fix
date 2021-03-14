//
// --------------------------------------------------------------------------
// MFScrollView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MFScrollView.h"

@implementation MFScrollView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Even if we don't do anything here, using this subclass allows us to set border color using view.layer.borderColor = ...
    // I have no clue why
    
    
//    // We're going to be modifying the state for this,
//    // so allow it to be restored later
//    [NSGraphicsContext saveGraphicsState];
//
//    // Choose the correct color; isFirstResponder is a custom
//    // ivar set in becomeFirstResponder and resignFirstResponder
//    [[NSColor redColor]set];
//
//    // Create two rects, one slightly outset from the bounds,
//    // one slightly inset
//    NSRect bounds = [self bounds];
//    NSRect innerRect = NSInsetRect(bounds, 2, 2);
//    NSRect outerRect = NSMakeRect(bounds.origin.x - 2,
//                                  bounds.origin.y - 2,
//                                  bounds.size.width + 4,
//                                  bounds.size.height + 4);
//
//    // Create a bezier path using those two rects; this will
//    // become the clipping path of the context
//    NSBezierPath * clipPath = [NSBezierPath bezierPathWithRect:outerRect];
//    [clipPath appendBezierPath:[NSBezierPath bezierPathWithRect:innerRect]];
//
//    // Change the current clipping path of the context to
//    // the enclosed area of clipPath; "enclosed" defined by
//    // winding rule. Drawing will be restricted to this area.
//    // N.B. that the winding rule makes the order that the
//    // rects were added to the path important.
//    [clipPath setWindingRule:NSEvenOddWindingRule];
//    [clipPath setClip];
//    // Fill the rect; drawing is clipped and the inner rect
//    // is not drawn in
//    [[NSBezierPath bezierPathWithRect:outerRect] fill];
//    [NSGraphicsContext restoreGraphicsState];
}

@end
