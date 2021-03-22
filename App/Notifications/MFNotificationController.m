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

#import "MFNotificationController.h"
#import "AppDelegate.h"
#import "Utility_App.h"
#import "MFNotification.h"
//#import "NSTextField+Additions.h"
#import "MFNotificationLabel.h"
#import "NSAttributedString+Additions.h"

@interface MFNotificationController ()
@property (unsafe_unretained) IBOutlet MFNotificationLabel *label;
@end

@implementation MFNotificationController

MFNotificationController *_instance;
NSDictionary *_labelAttributesFromIB;

+ (void)initialize {
    
    if (self == [MFNotificationController class]) {
        
        // Setup window closing notification
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(windowResignKey:) name:NSWindowDidResignKeyNotification object:nil];
        
        // Setup notfication window
        _instance = [[MFNotificationController alloc] initWithWindowNibName:@"MFNotification"];
        
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

double _animationDuration = 0.4;

/// Pass 0 to showDuration to get the default duration
+ (void)attachNotificationWithMessage:(NSAttributedString *)message toWindow:(NSWindow *)attachWindow forDuration:(NSTimeInterval)showDuration {
    
#if DEBUG
    NSLog(@"Attaching notification: %@", message);
#endif
    
    // Constants
    if (showDuration <= 0) {
        showDuration = 3.0;
    }
    double mainWindowTitleBarHeight = 30;
//    double topEdgeMargin = 1.0;
    double topEdgeMargin = -25;
    double sideMargin = 40;
    
    // Execution
    
    // Get existing notif instance and close
    NSPanel *w = (NSPanel *)_instance.window;
    NSWindow *mainW = AppDelegate.mainWindow;
    [w close];
    
    // Make label text centered (Don't need this with NSTextView)
//    NSMutableAttributedString *m = message.mutableCopy;
//    NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
//    p.alignment = NSTextAlignmentCenter;
//    [m addAttributes:@{NSParagraphStyleAttributeName: p} range:NSMakeRange(0, m.length)];
    
    // Set message text and text attributes to label
    NSMutableAttributedString *m = message.mutableCopy;
    [m addAttributes:_labelAttributesFromIB range:NSMakeRange(0, m.length)];
    // ^ Attributes of m which are also defined in _labelAttributesFromIB will be overriden by this.
    //      E.g. boldness I think. This is not ideal but works for now.
    [_instance.label.textStorage setAttributedString:m];

    // Set notification frame
    
    // Calc size to fit content
    NSRect newNotifFrame = w.frame;
    // Get insets around label
    MFNotificationLabel *label = _instance.label;
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
    NSLog(@"LABEL ATTRIBUTED STRING: %@", label.attributedString);
    NSSize newNotifSize = NSMakeSize(newLabelSize.width + leftInset + rightInset, newLabelSize.height + topInset + bottomInset);
    newNotifFrame.size = newNotifSize;
    
    // Calc Position
    // Center horizontally
    newNotifFrame.origin.x = NSMidX(mainW.frame) - (newNotifSize.width / 2);
    // Align with top edge of main window
    newNotifFrame.origin.y = (mainW.frame.origin.y + mainW.frame.size.height - (mainWindowTitleBarHeight + topEdgeMargin)) - newNotifSize.height;
    
    // Set new notification frame
    [w setFrame:newNotifFrame display:YES];
    
    // Set label frame (Don't need this if we set autoresizeing for the label in IB)
    NSRect newLabelFrame = label.superview.superview.frame;
    newLabelFrame.size = newLabelSize;
    newLabelFrame.origin.x = NSMidX(label.superview.bounds) - (newLabelSize.width / 2);
    newLabelFrame.origin.y = NSMidY(label.superview.bounds) - (newLabelSize.height / 2);
    [label setFrame:newLabelFrame];
    
    // Attach notif as child window to attachWindow
    [attachWindow addChildWindow:w ordered:NSWindowAbove];
    [attachWindow makeKeyWindow];
    
    // Fade in notification window
    w.alphaValue = 0.0;
    [NSAnimationContext beginGrouping];
    NSAnimationContext.currentContext.duration = _animationDuration;
    w.animator.alphaValue = 1.0;
    [NSAnimationContext endGrouping];
    
    // Fade out after showDuration
    [_closeTimer invalidate];
    _closeTimer = [NSTimer scheduledTimerWithTimeInterval:showDuration target:self selector:@selector(closeNotification:) userInfo:nil repeats:NO];
}

NSTimer *_closeTimer;
+ (void)closeNotification:(NSTimer *)timer {
    [self closeNotificationWithFadeOut];
}

+ (void)closeNotificationWithFadeOut {
    NSPanel *w = (NSPanel *)_instance.window;
    [NSAnimationContext beginGrouping];
    NSAnimationContext.currentContext.duration = _animationDuration;
    NSAnimationContext.currentContext.completionHandler = (void (^) (void)) ^{
        [w orderOut:nil];
    };
    w.animator.alphaValue = 0.0;
    [NSAnimationContext endGrouping];
}

+ (void)closeNotificationImmediately {
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
#if DEBUG
    NSLog(@"RESIGNED KEY: %@", closedWindow.title);
#endif
    if ([_instance.window.parentWindow isEqual:closedWindow]) {
        [_closeTimer invalidate];
        [self closeNotificationImmediately];
    }
}
@end
