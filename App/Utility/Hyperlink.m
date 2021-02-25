//
// --------------------------------------------------------------------------
// Hyperlink.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Hyperlink.h"
#import "Utility_PrefPane.h"
#import "AppDelegate.h"

IB_DESIGNABLE
@interface Hyperlink ()

@property (nonatomic) IBInspectable NSString *href;

@property IBInspectable NSNumber *tMrgn; // Top tracking margin
@property IBInspectable NSNumber *rMrgn; // Right tracking margin
@property IBInspectable NSNumber *bMrgn; // Bottom tracking margin
@property IBInspectable NSNumber *lMrgn; // Left tracking margin

@end

@implementation Hyperlink

NSRect _trackingRect;

- (void)awakeFromNib {
    
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseUp handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        NSLog(@"MOUSE UPPP");
        NSPoint loc = [AppDelegate.mainWindow.contentView convertPoint:event.locationInWindow toView:self];
        if (NSPointInRect(loc, _trackingRect)) {
            [self reactToClick];
        }
        return event;
    }];
    
    // Set IBInspectible default values
    
    NSNumber *zeroNS = [NSNumber numberWithInt:0.0];
    if (!_tMrgn) {
        _tMrgn = zeroNS;
    }
    if (!_rMrgn) {
        _rMrgn = zeroNS;
    }
    if (!_bMrgn) {
        _bMrgn = zeroNS;
    }
    if (!_lMrgn) {
        _lMrgn = zeroNS;
    }
    
    // Setup tracking area
    
    // Options
    NSTrackingAreaOptions trackingAreaOptions =  NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow;
    _trackingRect = self.bounds;
    
    // Make area larger according to IBInspectable tracking margins
    // Top
    _trackingRect.origin.y -= _tMrgn.doubleValue;
    _trackingRect.size.height += _tMrgn.doubleValue;
    // Bottom
    _trackingRect.size.height += _bMrgn.doubleValue;
    // Left
    _trackingRect.origin.x -= _lMrgn.doubleValue;
    _trackingRect.size.width += _lMrgn.doubleValue;
    // Right
    _trackingRect.size.width += _rMrgn.doubleValue;
    
    // Add tracking area
    NSTrackingArea * area = [[NSTrackingArea alloc] initWithRect:_trackingRect
                                                         options:trackingAreaOptions
                                                           owner:self
                                                        userInfo:nil];
    [self addTrackingArea:area];
    
}
//- (void)resetCursorRects {
//    [self discardCursorRects];
//    [self addCursorRect:_trackingRect cursor:NSCursor.pointingHandCursor];
//}
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

}

- (void) reactToClick {
    // Open URL defined in Interface Builder
    NSLog(@"Opening: %@",_href);
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:_href]];
    // Send IBAction
    [self sendAction:self.action to:self.target];
}


@end
