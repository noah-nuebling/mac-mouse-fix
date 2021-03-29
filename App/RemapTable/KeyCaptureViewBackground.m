//
// --------------------------------------------------------------------------
// KeyCaptureViewBackground.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "KeyCaptureViewBackground.h"
#import "AppDelegate.h"

@implementation KeyCaptureViewBackground

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    BOOL focus = AppDelegate.mainWindow.firstResponder == self;

    if (focus) {
        NSRect bounds = self.bounds;
        NSRect outerRect = NSMakeRect(bounds.origin.x - 2,
                                      bounds.origin.y - 2,
                                      bounds.size.width + 4,
                                      bounds.size.height + 4);

        NSRect innerRect = NSInsetRect(outerRect, 1, 1);

        NSBezierPath *clipPath = [NSBezierPath bezierPathWithRect:outerRect];
        [clipPath appendBezierPath:[NSBezierPath bezierPathWithRect:innerRect]];

        [clipPath setWindingRule:NSEvenOddWindingRule];
        [clipPath setClip];

        [[NSColor colorWithCalibratedWhite:0.6 alpha:1.0] setFill];
        [[NSBezierPath bezierPathWithRect:outerRect] fill];
    }
}

- (void)mouseDown:(NSEvent *)event {
    // Ignore clicks
}

@end
