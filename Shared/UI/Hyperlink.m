//
// --------------------------------------------------------------------------
// Hyperlink.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Hyperlink.h"
#import "Utility_App.h"
#import "AppDelegate.h"
#import "SharedUtility.h"
#import "Logging.h"

IB_DESIGNABLE
@interface Hyperlink ()

@property (nonatomic) IBInspectable NSString *MFLinkID;     /// This is actually an `MFLinkID`, but IBInspectable only works when set the type to literally `NSString *`
@property (nonatomic) NSString *href;                       /// Unused. Moved to using linkIDs instead.

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

- (void)awakeFromNib {
    
    /// Validate
    ///     Do this in awakeFromNib since the IB values aren't set yet inside initWithCoder:
    assert(_href == nil || _href.length == 0); /// We moved over to using `_MFLinkID`  instead.
}

+ (instancetype)hyperlinkWithTitle:(NSString *)title linkID:(MFLinkID)linkID alwaysTracking:(BOOL)alwaysTracking leftPadding:(int)leftPadding {
    
    /// Init from code
    
    Hyperlink *link = [Hyperlink labelWithString:title];
    link.textColor = [NSColor linkColor];
    link.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
    link.MFLinkID = linkID;
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
    
    DDLogDebug(@"Hyperlink updateTrackingAreas");
//    DDLogDebug(@"Hyperlink updateTrackingAreas caller: %@", SharedUtility.callerInfo);
    
    [super updateTrackingAreas];
    
    /// Reset state
    ///     Doing this lead to the Activate License link on the about tab sometimes not reacting to clicks even though it was moused-over, because updateTrackingAreas is called a lot as it animates in. I hope not resetting these doesn't have any negative side-effects.
    
//    _mouseIsOverSelf = NO;
//    _mouseDownOverSelf = NO;
    
    /// Remove old tracking area
    
    [self removeTrackingArea:_trackingArea];
    
    /// Setup new tracking area
    
    /// Options
    /// Notes:
    /// - Is NSTrackingEnabledDuringMouseDrag really necessary? I just read a bit of docs and it seems unnecessary
    /// - Why not use the NSTrackingInVisibleRect option instead of specifying the `_trackingRect` manually? Edit: It's because we make the `_trackingArea` larger than the view. See below.
    
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
    
    DDLogDebug(@"Hyperlink enter");
    
    _mouseIsOverSelf = YES;
    
    NSMutableAttributedString *underlinedString = [[NSMutableAttributedString alloc] initWithAttributedString: self.attributedStringValue];
    NSRange wholeStringRange = NSMakeRange(0, [underlinedString length]);
    [underlinedString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:wholeStringRange];
    self.attributedStringValue = underlinedString;
    
//    [NSCursor.pointingHandCursor push]; // This is maybe a little tacky, cause nothing else in the UI does this
}
- (void)mouseExited:(NSEvent *)event {
    
    DDLogDebug(@"Hyperlink exit");
    
    _mouseIsOverSelf = NO;
    
    NSMutableAttributedString *notUnderlinedString = [[NSMutableAttributedString alloc] initWithAttributedString: self.attributedStringValue];
    NSRange wholeStringRange = NSMakeRange(0, [notUnderlinedString length]);
    [notUnderlinedString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleNone) range:wholeStringRange];
    
    self.attributedStringValue = notUnderlinedString;
    
//    [NSCursor.pointingHandCursor pop];
}
- (void)mouseDown:(NSEvent *)event {
    
    DDLogDebug(@"Hyperlink mouseDown");
    
    if (_mouseIsOverSelf) {
        _mouseDownOverSelf = YES;
    }
}
- (void)mouseUp:(NSEvent *)event {
    
    DDLogDebug(@"Hyperlink mouseUp");
    
    if (_mouseDownOverSelf && _mouseIsOverSelf) {
        [self reactToClick];
    }
    _mouseDownOverSelf = NO;
    _mouseIsOverSelf = NO;
}
- (void)reactToClick {
    
    DDLogDebug(@"Hyperlink acceptClick");
    
    /// Get info
    BOOL hasAction = self.action != nil;
    NSString *link = [Links link:_MFLinkID]; /// We could cache this for performance.
    BOOL hasLink = link != nil && link.length > 0;
    
    /// Validate
    assert(hasAction || hasLink);
    assert(!(hasAction && hasLink));
    
    /// Send action / open link
    if (hasAction) {
        [self sendAction:self.action to:self.target];
    } else {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:link]];
    }
}

@end
