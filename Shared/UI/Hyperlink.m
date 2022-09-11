//
// --------------------------------------------------------------------------
// Hyperlink.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
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
    BOOL _alwaysTracking;
    id _eventMonitor;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        
        /// Init from IB
        ///     Don't use awakeFromNib because that's sometimes called more than once.
        
        /// Register mouse clicked callbacks
        _alwaysTracking = NO;
    }
    return self;
}

+ (instancetype)hyperlinkWithTitle:(NSString *)title url:(NSString *)href alwaysTracking:(BOOL)alwaysTracking leftPadding:(int)leftPadding {
    
    /// Init from code
    
    Hyperlink *link = [Hyperlink labelWithString:title];
    link.textColor = [NSColor linkColor];
    link.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
    link.href = href;
    link.leftPadding = leftPadding;
    
    link->_alwaysTracking = alwaysTracking;
    
    return link;
}

- (void)dealloc {
    [self stopTracking];
}

- (void)startTracking {
    
    _eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown|NSEventMaskLeftMouseUp handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        
        if (event.type == NSEventTypeLeftMouseDown) {
            [self mouseDown:event];
        } else if (event.type == NSEventTypeLeftMouseUp) {
            [self mouseUp:event];
        } else assert(false);
        
        return event;
    }];
}

- (void)stopTracking {
    [NSEvent removeMonitor:_eventMonitor];
}

- (void)viewDidMoveToWindow {
    
    /// Toggle tracking depending on whether view is displaying or not
    ///     Fixes bugs when view is removed from superView while tracking
    
    if (self.window != nil) {
        [self startTracking];
    } else {
        [self stopTracking];
        if (_mouseIsOverSelf) {
            [self mouseExited:[[NSEvent alloc] init]];
        }
    }
}


- (void)updateTrackingAreas {
    
    [super updateTrackingAreas];
    
    _mouseIsOverSelf = NO;
    _mouseDownOverSelf = NO;
    
    /// Remove old tracking area
    
    [self removeTrackingArea:_trackingArea];
    
    /// Setup new tracking area
    
    /// Options
    
    NSTrackingAreaOptions trackingAreaOptions =  NSTrackingMouseEnteredAndExited | NSTrackingEnabledDuringMouseDrag;
    trackingAreaOptions |= _alwaysTracking ? NSTrackingActiveAlways : NSTrackingActiveInKeyWindow;
    
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
    
    DDLogDebug(@"MOUSEE enter");
    
    _mouseIsOverSelf = YES;
    
    NSMutableAttributedString *underlinedString = [[NSMutableAttributedString alloc] initWithAttributedString: self.attributedStringValue];
    NSRange wholeStringRange = NSMakeRange(0, [underlinedString length]);
    [underlinedString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:wholeStringRange];
    self.attributedStringValue = underlinedString;
    
//    [NSCursor.pointingHandCursor push]; // This is maybe a little tacky, cause nothing else in the UI does this
}
- (void)mouseExited:(NSEvent *)event {
    
    DDLogDebug(@"MOUSEE exit");
    
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
