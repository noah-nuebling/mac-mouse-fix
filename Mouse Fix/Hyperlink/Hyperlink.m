//
// --------------------------------------------------------------------------
// Hyperlink.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Hyperlink.h"

IB_DESIGNABLE

@implementation Hyperlink

- (void)awakeFromNib {
    
    NSTrackingAreaOptions option = NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow;
    NSTrackingArea * area = [[NSTrackingArea alloc] initWithRect:self.bounds options:option owner:self userInfo:nil];
    [self addTrackingArea:area];
}
- (void)resetCursorRects {
    [self discardCursorRects];
    [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor];
}
- (void)mouseEntered:(NSEvent *)event {
    NSMutableAttributedString *underlinedString = [[NSMutableAttributedString alloc] initWithString: self.stringValue];
    [underlinedString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:NSMakeRange(0, [underlinedString length])];
    self.attributedStringValue = underlinedString;
}
- (void)mouseExited:(NSEvent *)event {
    NSMutableAttributedString *notUnderlinedString = [[NSMutableAttributedString alloc] initWithString: self.stringValue];
    [notUnderlinedString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleNone) range:NSMakeRange(0, [notUnderlinedString length])];
    self.attributedStringValue = notUnderlinedString;
}
- (void)mouseUp:(NSEvent *)event {
    if ([self mouse:[self convertPoint:[event locationInWindow] fromView:nil] inRect:self.bounds]) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:_href]];
    }

/*
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    NSLog(@"drawRect");
    // Drawing code here.
}

- (void)initWithBundle {
    NSLog(@"initWithBundle");
 */
}

@end
