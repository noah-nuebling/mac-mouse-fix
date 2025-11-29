//
// --------------------------------------------------------------------------
// KeyCaptureScrollView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "KeyCaptureScrollView.h"
#import "Logging.h"

@implementation KeyCaptureScrollView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    /// Drawing code here.
}

#pragma mark - Drawing focus ring

/// We want it to look like the KeyCaptureView is an NSButton with a focus ring.
/// First we created a background button object but there were some problems:
/// - The textView (aka KeyCaptureView) needs to be first responder to display properly, but the background button also needs to be first responder to to display its focus ring natively. At least I couldn't find another way. I could draw a custom ring in the buttons `drawRect:` function but the `bounds` and `frame` properties weren't correct at all weirdly and I had to hardcode the insets to make things work. I had to do manual clipping and it didn't work properly. It also didn't do the native focus ring animation and I couldn't get the strokeWidth quite right I think. It was just a horrible solution
/// - We then tried to customize the way that the KeyCaptureViews focus ring draws but turns out it doesn't draw it's own focus ring. That is done by the scrollView it is embedded in (This class). I don't understand this at all. It seems impossible to get anything but the first responder to draw its native focus ring, but the scrollview somehow does it even though it's not first responder. Maybe it's because the firstResponder is its subview or something.
/// - Either solution works pretty well. The only problem is we manually have to set the same cornerRadius as an NSButton, to stay visually consitent

- (NSRect)focusRingMaskBounds {
    return NSInsetRect(self.bounds, 0, 0);
}

- (void)drawFocusRingMask {
    
    int cornerRadius;
    if (@available(macOS 11.0, *)) {
        cornerRadius = 4.0; // Not sure if 4 or 5
    } else {
        cornerRadius = 3.0; // I hope that's correct, can't test right now.
    }

    NSRect bounds = NSInsetRect(self.bounds, 0, 0);

    NSBezierPath *focusRingPath = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:cornerRadius yRadius:cornerRadius];
    
    [focusRingPath fill];
}

- (BOOL)becomeFirstResponder {
    DDLogInfo(@"SCROLLVIEW BECOME FIRST");
    
    return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
    DDLogInfo(@"SCROLLVIEW RESIGN FIRST");
    return [super resignFirstResponder];
}

@end
