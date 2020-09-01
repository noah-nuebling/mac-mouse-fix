//
// --------------------------------------------------------------------------
// Hyperlink.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Hyperlink.h"

IB_DESIGNABLE
@interface Hyperlink ()

@property (nonatomic) IBInspectable NSString *href;

@end

@implementation Hyperlink

- (void)awakeFromNib {
    
    // Setup tracking area
    
    NSTrackingAreaOptions trackingAreaOptions = NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow;
    NSTrackingArea * area = [[NSTrackingArea alloc] initWithRect:self.bounds options:trackingAreaOptions owner:self userInfo:nil];
    [self addTrackingArea:area];
    
}
- (void)resetCursorRects {
    [self discardCursorRects];
    [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor];
}
- (void)mouseEntered:(NSEvent *)event {
    
    NSMutableAttributedString *underlinedString = [[NSMutableAttributedString alloc] initWithAttributedString: self.attributedStringValue];
    
    NSRange wholeStringRange = NSMakeRange(0, [underlinedString length]);
    
    [underlinedString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:wholeStringRange];
    
//    [underlinedString setAlignment:NSTextAlignmentRight range:wholeStringRange];
    
    self.attributedStringValue = underlinedString;
}
- (void)mouseExited:(NSEvent *)event {
    
    NSMutableAttributedString *notUnderlinedString = [[NSMutableAttributedString alloc] initWithAttributedString: self.attributedStringValue];
    
    NSRange wholeStringRange = NSMakeRange(0, [notUnderlinedString length]);
    
    [notUnderlinedString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleNone) range:wholeStringRange];
    
//    [notUnderlinedString setAlignment:NSTextAlignmentRight range:wholeStringRange];
    
    self.attributedStringValue = notUnderlinedString;
}
- (void)mouseUp:(NSEvent *)event {
    
    if ([self mouse:[self convertPoint:[event locationInWindow] fromView:nil] inRect:self.bounds]) {
        // Open URL defined in Interface Builder
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:_href]];
        // Send IBAction
        [self sendAction:self.action to:self.target];
    }
}

@end
