//
// --------------------------------------------------------------------------
// KeyCaptureViewBackground.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "KeyCaptureViewBackground.h"
#import "KeyCaptureView.h"
#import "AppDelegate.h"
#import <Carbon/Carbon.h>

@interface KeyCaptureViewBackground ()

@property IBOutlet KeyCaptureView *captureView;

@end

@implementation KeyCaptureViewBackground

// We meant to draw an artificial focusRing around, this but for some reason, self.bounds alwyas contained the bounds of the superView. So we're drawing the focusRing around KeyCaptureView instead
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    BOOL focus = AppDelegate.mainWindow.firstResponder == self.captureView;

    if (focus) { // This check isn't necessary, bc focus should always be true when this is drawing

        NSGraphicsContext* contextMgr = [NSGraphicsContext currentContext];
        CGContextRef drawingContext = (CGContextRef)[contextMgr graphicsPort];

        int padX = 7; // Values from IB (Actually, those don't work, wtf is goin on?)
        int padY = 5;
        int cornerRadius = 5.0;

        NSRect frame = NSInsetRect(self.bounds, padX, padY); // self.frame and self.bounds don't work, so we need to get the frame manually
        frame.origin.y -= 1;
        
//        NSRect bounds = self.bounds; // for some reason, self.bounds alwyas contains the bounds of the superView. The drawing coordinate system seems to be of the superview, too.
//        NSRect frame = self.captureView.frame; // Should have the same frame and bounds as this view. Size is correct but origin is always (0,0)?
        
        NSBezierPath *clipPath = [NSBezierPath bezierPathWithRoundedRect:frame xRadius:cornerRadius yRadius:cornerRadius];
        
        HIThemeBeginFocus(drawingContext, kHIThemeFocusRingOnly, NULL);
        [clipPath fill];
        HIThemeEndFocus(drawingContext);
    }
}

- (void)mouseDown:(NSEvent *)event {
    // Ignore clicks
}

@end
