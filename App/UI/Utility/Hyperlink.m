//
// --------------------------------------------------------------------------
// Hyperlink.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Hyperlink.h"
#import "Utility_App.h"
#import "AppDelegate.h"
#import "WannabePrefixHeader.h"

IB_DESIGNABLE
@interface Hyperlink ()

@property (nonatomic) IBInspectable NSString *href;

/// TrackingArea padding
///     Extends the area that can be clicked to open the link beyond the frame of the link text.
///     Used to make neighboring icons clickable as well.
@property (nonatomic, assign) IBInspectable int topPadding;
@property (nonatomic, assign) IBInspectable int rightPadding;
@property (nonatomic, assign) IBInspectable int bottomPadding;
@property (nonatomic, assign) IBInspectable int leftPadding;

@end

@implementation Hyperlink {
    BOOL _mouseIsOverSelf;
    BOOL _mouseDownOverSelf;
    NSRect _trackingRect; /// Do we need to store this?
    NSTrackingArea *_trackingArea;
}

- (void)awakeFromNib {
    
    /// Register mouse clicked callbacks
    
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        [self mouseDown:event];
        return event;
    }];
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseUp handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        [self mouseUp:event];
        return event;
    }];
}

- (void)updateTrackingAreas {
    
    [super updateTrackingAreas];
    
    _mouseIsOverSelf = NO;
    _mouseDownOverSelf = NO;
    
    /// Remove old tracking area
    
    [self removeTrackingArea:_trackingArea];
    
    /// Setup new tracking area
    
    /// Options
    NSTrackingAreaOptions trackingAreaOptions =  NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingEnabledDuringMouseDrag;
    
    _trackingRect = self.bounds;
    
    /// Make area larger according to IBInspectable tracking margins
    /// Top
    _trackingRect.origin.y -= (double)_topPadding;
    _trackingRect.size.height += (double)_topPadding;
    /// Bottom
    _trackingRect.size.height += (double)_bottomPadding;
    /// Left
    _trackingRect.origin.x -= (double)_leftPadding;
    _trackingRect.size.width += (double)_leftPadding;
    /// Right
    _trackingRect.size.width += (double)_rightPadding;
    
    /// Add tracking area
    _trackingArea = [[NSTrackingArea alloc] initWithRect:_trackingRect
                                                         options:trackingAreaOptions
                                                           owner:self
                                                        userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (void)mouseEntered:(NSEvent *)event {
    
    _mouseIsOverSelf = YES;
    
    NSMutableAttributedString *underlinedString = [[NSMutableAttributedString alloc] initWithAttributedString: self.attributedStringValue];
    NSRange wholeStringRange = NSMakeRange(0, [underlinedString length]);
    [underlinedString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:wholeStringRange];
    self.attributedStringValue = underlinedString;
    
//    [NSCursor.pointingHandCursor push]; // This is maybe a little tacky, cause nothing else in the UI does this
}
- (void)mouseExited:(NSEvent *)event {
    
    _mouseIsOverSelf = NO;
    
    NSMutableAttributedString *notUnderlinedString = [[NSMutableAttributedString alloc] initWithAttributedString: self.attributedStringValue];
    NSRange wholeStringRange = NSMakeRange(0, [notUnderlinedString length]);
    [notUnderlinedString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleNone) range:wholeStringRange];
    
    self.attributedStringValue = notUnderlinedString;
    
//    [NSCursor.pointingHandCursor pop];
}
- (void)mouseDown:(NSEvent *)event {
    if (_mouseIsOverSelf) {
        _mouseDownOverSelf = YES;
    }
}
- (void)mouseUp:(NSEvent *)event {
    if (_mouseDownOverSelf && _mouseIsOverSelf) {
        [self reactToClick];
    }
    _mouseDownOverSelf = NO;
}
- (void)reactToClick {
    /// Open URL defined in Interface Builder
    DDLogInfo(@"Opening: %@",_href);
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:_href]];
    /// Send IBAction
    [self sendAction:self.action to:self.target];
}

@end
