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

#import "MFNotificationOverlayController.h"
#import "AppDelegate.h"
#import "Utility_App.h"

@interface MFNotificationOverlayController ()
@property (weak) IBOutlet NSTextField *label;
@end

@implementation MFNotificationOverlayController

MFNotificationOverlayController *_instance;

+ (void)initialize {
    
    if (self == [MFNotificationOverlayController class]) {
        
        // Setup window closing notification
        
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(windowResignedKey:) name:NSWindowDidResignKeyNotification object:nil];
        
        // Setup notfication window
        
        _instance = [[MFNotificationOverlayController alloc] initWithWindowNibName:@"NotificationOverlay"];
        
        NSPanel *w = (NSPanel *)_instance.window;
        
        w.styleMask =  NSTitledWindowMask | NSFullSizeContentViewWindowMask;
        w.titlebarAppearsTransparent  =   YES;
        w.titleVisibility             =   NSWindowTitleHidden;
        w.showsToolbarButton          =   NO;
        w.movable = NO;
        w.ignoresMouseEvents = YES;
    }
}

double _animationDuration = 0.4;
+ (void)attachNotificationWithMessage:(NSAttributedString *)message toWindow:(NSWindow *)attachWindow {
    
    // Constants
    
    NSTimeInterval showDuration = 3.0;
    
    // Execution
    
    NSPanel *w = (NSPanel *)_instance.window;
    
    // Remove from parent if already attached
//    [w.parentWindow removeChildWindow:w];
    [w close];
    
    // Position notification window in main window
    
    double mainWindowTitleBarHeight = 30;
    double topEdgeMargin = mainWindowTitleBarHeight + 2.0;
    NSWindow *mainW = AppDelegate.mainWindow;
    [Utility_App centerWindow:_instance.window atPoint: [Utility_App getCenterOfRect:mainW.frame]];
    NSRect newFrame = w.frame;
    newFrame.origin.y = (mainW.frame.origin.y + mainW.frame.size.height - topEdgeMargin) - w.frame.size.height;
    [w setFrame:newFrame display:YES];
    
    // Make text centered
    NSMutableAttributedString *m = message.mutableCopy;
    NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
    p.alignment = NSTextAlignmentCenter;
    [m addAttributes:@{NSParagraphStyleAttributeName: p} range:NSMakeRange(0, m.length)];
    
    _instance.label.attributedStringValue = m;
    
    [attachWindow addChildWindow:w ordered:NSWindowAbove];
//    [w makeKeyAndOrderFront:nil];
//    [w resignKeyWindow];
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
+ (void)windowResignedKey:(NSNotification *)notification {
    NSWindow *closedWindow = notification.object;
    if ([_instance.window.parentWindow isEqual:closedWindow]) {
        [self closeNotificationWithFadeOut];
    }
}
@end
