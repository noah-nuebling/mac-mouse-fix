//
// --------------------------------------------------------------------------
// MFNotificationOverlayController.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

// Medium article on views with rounded corners and shadows:
//      https://medium.com/swifty-tim/views-with-rounded-corners-and-shadows-c3adc0085182
//      -> Using overlay window instead

// This is really the same thing as a "toast" or a "snackbar"

#import "ToastNotificationController.h"
#import "AppDelegate.h"
#import "Utility_App.h"
#import "ToastNotification.h"
//#import "NSTextField+Additions.h"
#import "ToastNotificationLabel.h"
#import "NSAttributedString+Additions.h"
#import "WannabePrefixHeader.h"

@interface ToastNotificationController ()
@property (unsafe_unretained) IBOutlet ToastNotificationLabel *label;
@end

@implementation ToastNotificationController {
}

static ToastNotificationController *_instance;
static NSDictionary *_labelAttributesFromIB;
static id _localEventMonitor;

+ (void)initialize {
    
    if (self == [ToastNotificationController class]) {
        
        // Setup window closing notification
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(windowResignKey:) name:NSWindowDidResignKeyNotification object:nil];
        
        // Setup notfication window
        _instance = [[ToastNotificationController alloc] initWithWindowNibName:@"ToastNotification"];
        
        NSPanel *w = (NSPanel *)_instance.window;
        
        w.styleMask =  NSTitledWindowMask | NSFullSizeContentViewWindowMask;
        w.titlebarAppearsTransparent  =   YES;
        w.titleVisibility             =   NSWindowTitleHidden;
        w.movable = NO;
        
        // Remove scrollView edge insets, because those are nothing but trouble (cause links to be not clickable and stuff)
        NSScrollView *scrollView = (NSScrollView *)_instance.label.superview.superview;
        scrollView.automaticallyAdjustsContentInsets = NO; // Doesn't remove insets // Probably calling this too late
        scrollView.contentInsets = NSEdgeInsetsMake(0, 0, 0, 0);
        // Disable scrollView elasticity while we're at it to make it seem like it's not even there
        scrollView.verticalScrollElasticity = NSScrollElasticityNone;
        scrollView.horizontalScrollElasticity = NSScrollElasticityNone;
        
        // Get default label text attributes
        _labelAttributesFromIB = [_instance.label.attributedString attributesAtIndex:0 effectiveRange:nil];
    }
}

static double _animationDurationFadeIn = 0.3;
static double _animationDurationFadeOut = 0.2;
static double _toastAnimationOffset = 20;

// Convenience function
+ (void)attachNotificationWithMessage:(NSAttributedString *)message toWindow:(NSWindow *)window forDuration:(NSTimeInterval)showDuration {
    
    [self attachNotificationWithMessage:message toWindow:window forDuration:showDuration alignment:kToastNotificationAlignmentTopMiddle];
}

/// Pass 0 to `showDuration` to get the default duration
+ (void)attachNotificationWithMessage:(NSAttributedString *)message toWindow:(NSWindow *)attachWindow forDuration:(NSTimeInterval)showDuration alignment:(ToastNotificationAlignment)alignment {
    
    // Override default font size from interface builder. This also overrides font size we set to `message` before passing it to this function which might be bad.
//    message = [message attributedStringBySettingFontSize:NSFont.smallSystemFontSize];
    
    // Constants
    if (showDuration <= 0) {
        showDuration = message.length * 0.08;
    }
    
    double mainWindowTitleBarHeight = 0.0;
    double topEdgeMargin = 0.0;
    double sideMargin = 0.0;
    double bottomMargin = 0.0;
    
    if (alignment == kToastNotificationAlignmentTopMiddle) {
        mainWindowTitleBarHeight = 30;
        topEdgeMargin = 5.0; // 0.0 // -25.0
        sideMargin = 20;
        _toastAnimationOffset = 20;
    } else if (alignment == kToastNotificationAlignmentBottomRight){
        sideMargin = bottomMargin = 10;
        _toastAnimationOffset = -20;
    } else if (alignment == kToastNotificationAlignmentBottomMiddle) {
        bottomMargin = 10;
        sideMargin = 20;
        _toastAnimationOffset = -20;
    } else assert(false);
    
    // Execution
    
    // Get existing notif instance and close
    NSPanel *w = (NSPanel *)_instance.window;
    NSWindow *mainW = AppDelegate.mainWindow;
    [w close];
    
    // Set message text and text attributes to label
    NSDictionary *baseAttributes = _labelAttributesFromIB;
    NSAttributedString *m = [message attributedStringByAddingBaseAttributes:baseAttributes];
    m = [m attributedStringByFillingOutDefaultAttributes];
    
    [_instance.label.textStorage setAttributedString:m];

    DDLogDebug(@"Attaching notification with attributed string: %@", m);
    
    // Set notification frame
    
    // Calc size to fit content
    NSRect newNotifFrame = w.frame;
    // Get insets around label
    ToastNotificationLabel *label = _instance.label;
    NSRect notifFrame = w.frame;
#if DEBUG
    CGFloat sh = label.superview.superview.superview.frame.size.height;
    CGFloat sw = label.superview.superview.superview.frame.size.width;
    CGFloat nh = notifFrame.size.height;
    CGFloat nw = notifFrame.size.width;
    assert(sh == nh && sw == nw);
#endif
    NSRect labelFrame = label.superview.superview.frame;
    CGFloat bottomInset = labelFrame.origin.y;
    CGFloat topInset = notifFrame.size.height - (labelFrame.size.height + bottomInset);
    CGFloat leftInset = labelFrame.origin.x;
    CGFloat rightInset = notifFrame.size.width - (labelFrame.size.width + leftInset);
    assert(leftInset == rightInset);
    // Calculate new label size
    CGFloat maxLabelWidth = mainW.frame.size.width - 2*sideMargin - leftInset - rightInset;
    NSSize newLabelSize = [label.attributedString sizeAtMaxWidth:maxLabelWidth];
    
    // Setting actual width for newLabelSize. See https://stackoverflow.com/questions/13621084/boundingrectwithsize-for-nsattributedstring-returning-wrong-size
    //  ... Actually this breaks short "Primary Mouse Button can't be used" notifications.
//    CGFloat padding = label.textContainer.lineFragmentPadding;
//    newLabelSize.width -= padding * 2;
    
    // Calculate new notification window frame
    NSSize newNotifSize = NSMakeSize(newLabelSize.width + leftInset + rightInset, newLabelSize.height + topInset + bottomInset);
    newNotifFrame.size = newNotifSize;
    
    // Calc Position
    
    if (alignment == kToastNotificationAlignmentTopMiddle) {
        // Top middle alignment
        newNotifFrame.origin.x = NSMidX(mainW.frame) - (newNotifSize.width / 2);
        newNotifFrame.origin.y = (mainW.frame.origin.y + mainW.frame.size.height - (mainWindowTitleBarHeight + topEdgeMargin)) - newNotifSize.height;
    } else if (alignment == kToastNotificationAlignmentBottomRight) {
        // Bottom right alignment
        newNotifFrame.origin.x = mainW.frame.origin.x + mainW.frame.size.width - newNotifFrame.size.width - sideMargin;
        newNotifFrame.origin.y = mainW.frame.origin.y + bottomMargin;
    } else if (alignment == kToastNotificationAlignmentBottomMiddle) {
        newNotifFrame.origin.x = NSMidX(mainW.frame) - (newNotifSize.width / 2);
        newNotifFrame.origin.y = mainW.frame.origin.y + bottomMargin;
    } else assert(false);
    
    // Set new notification frame
    [w setFrame:newNotifFrame display:YES];
    
    // Set label frame (Don't actually need this if we set autoresizing for the label in IB, which we do)
    NSRect newLabelFrame = label.superview.superview.frame;
    newLabelFrame.size = newLabelSize;
    newLabelFrame.origin.x = NSMidX(label.superview.bounds) - (newLabelSize.width / 2);
    newLabelFrame.origin.y = NSMidY(label.superview.bounds) - (newLabelSize.height / 2);
    [label setFrame:newLabelFrame];
    
    // Attach notif as child window to attachWindow
    [attachWindow addChildWindow:w ordered:NSWindowAbove];
    [attachWindow makeKeyWindow];
    
    // Fade and animate the notification window in
    // Set pre animation alpha
    w.alphaValue = 0.0;
    // Set pre animation position
    NSRect targetFrame = w.frame;
    NSRect preAnimFrame = w.frame;
    preAnimFrame.origin.y += _toastAnimationOffset;
    [w setFrame:preAnimFrame display:NO];
    // Animate
    [NSAnimationContext beginGrouping];
    NSAnimationContext.currentContext.duration = _animationDurationFadeIn;
    w.animator.alphaValue = 1.0;
    [w.animator setFrame:targetFrame display:YES];
    [NSAnimationContext endGrouping];
    
    // Close if user clicks elsewhere
    _localEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskLeftMouseDown) handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        
        NSPoint loc = NSEvent.mouseLocation;
        
        // Check where mouse is located relative to other stuff
        
        // Get mouse location in the main content views' coordinate system. Need this to do a hit-test later.
        NSView *mainContentView = AppDelegate.mainWindow.contentView;
        NSPoint locWindow = [AppDelegate.mainWindow convertRectFromScreen:(NSRect){.origin=loc}].origin; // convertPointFromScreen: only available in 10.12+
        NSPoint locContentView = [mainContentView convertPoint:locWindow fromView:nil];
        
        BOOL locIsOverNotification = [NSWindow windowNumberAtPoint:NSEvent.mouseLocation belowWindowWithWindowNumber:0] == _instance.window.windowNumber; // So notification isn't dismissed when we click on it. Not sure if necessary when we're using `locIsOverMainWindowContentView`.
        BOOL locIsOverMainWindowContentView = [mainContentView hitTest:locContentView] != nil; // So that we can drag the window by its titlebar without dismissing the notification.
        
        if (!locIsOverNotification && locIsOverMainWindowContentView) {
            [_closeTimer invalidate];
            [self closeNotification:nil];
        }
        
        return event;
    }];
    
    // Close after showDuration
    [_closeTimer invalidate];
    _closeTimer = [NSTimer scheduledTimerWithTimeInterval:showDuration target:self selector:@selector(closeNotification:) userInfo:nil repeats:NO];
}

static NSTimer *_closeTimer;
+ (void)closeNotification:(NSTimer *)timer {
    [self closeNotificationWithFadeOut];
}

static void removeLocalEventMonitor() {
    if (_localEventMonitor != nil) {
        [NSEvent removeMonitor:_localEventMonitor];
        _localEventMonitor = nil;
    }
}

+ (void)closeNotificationWithFadeOut {
    
    removeLocalEventMonitor();
    
    NSPanel *w = (NSPanel *)_instance.window;
    [NSAnimationContext beginGrouping];
    NSAnimationContext.currentContext.duration = _animationDurationFadeOut;
    NSAnimationContext.currentContext.completionHandler = (void (^) (void)) ^{
//        [w orderOut:nil]; // This breaks displaying new notfication while old one is fading out
    };
    w.animator.alphaValue = 0.0;
    NSRect postAnimFrame = w.frame;
    postAnimFrame.origin.y += _toastAnimationOffset;
    [w.animator setFrame:postAnimFrame display:YES];
    [NSAnimationContext endGrouping];
}

+ (void)closeNotificationImmediately {
    
    removeLocalEventMonitor();
    
    NSPanel *w = (NSPanel *)_instance.window;
    [w orderOut:nil];
}

/// We use this to close the notification when the window it's attached to resigns key.
/// This prevents some jank when closing and then reopening the AddWindow while a notification is attached to it
/// This won't work when using `closeNotificationWithFadeOut` instead of `closeNotificationImmediately` because of some conflicts between animations or something.
/// This could also lead to weird behaviour whhen a notification starts to display while the Mac Mouse Fix window it attaches to is not in the foreground
/// What we really want to do here is to close the notification as soon as the window whcih is it's parent becomes invisible, but I haven't found a way to do that. So we're resorting to tracking key status.
/// This hacky solution might cause more weirdness and jank than it's worth.
+ (void)windowResignKey:(NSNotification *)notification {
    NSWindow *closedWindow = notification.object;
    
    DDLogDebug(@"RESIGNED KEY: %@", closedWindow.title);
    if ([_instance.window.parentWindow isEqual:closedWindow]) {
        [_closeTimer invalidate];
//        [self closeNotificationWithFadeOut];
        [self closeNotificationImmediately];
    }
}

@end
