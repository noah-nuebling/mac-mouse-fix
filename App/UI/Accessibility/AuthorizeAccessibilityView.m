//
// --------------------------------------------------------------------------
// AuthorizeAccessibilityView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "AppDelegate.h"
#import "AuthorizeAccessibilityView.h"
#import "Utility_App.h"
#import "ToastController.h"
#import "MFMessagePort.h"
//#import "CaptureToasts.h" 
#import "Mac_Mouse_Fix-Swift.h"

@interface AuthorizeAccessibilityView ()

@property (weak) IBOutlet Hyperlink *openSettingsLink;

@end

@implementation AuthorizeAccessibilityView

AuthorizeAccessibilityView *_accViewController;

+ (void)load {
//    [self performSelector:@selector(addAccViewToWindow) withObject:NULL afterDelay:0.5];
//    [self performSelector:@selector(removeAccViewFromWindow) withObject:NULL afterDelay:3];
    
    
//    NSArray *windows = NSApplication.sharedApplication.windows;
//    NSWindow *prefWindow;
//    for (NSWindow *w in windows) {
//        if ([w.className isEqualToString:@"NSPrefWindow"]) {
//            prefWindow = w;
//        }
//    }
//
//    NSView *accView;
//    for (NSView *v in prefWindow.contentView.subviews) {
//        if ([v.identifier isEqualToString:@"accView"]) {
//            accView = v;
//        }
//    }
//
//    _accViewController = [[AuthorizeAccessibilityView alloc] initWithNibName:@"AuthorizeAccessibilityView" bundle:[NSBundle bundleForClass:[self class]]];
//    accView = _accViewController.view;
//    [prefWindow.contentView addSubview:accView];
//
//    accView.hidden = YES;
//
//    DDLogInfo(@"subviews: %@", prefWindow.contentView.subviews);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (@available(macOS 13.0, *)) { } else {
        self.openSettingsLink.stringValue = NSLocalizedString(@"accessibility.settings-link.pre-ventura", @"Note: 'System Preferences' were renamed to 'System Settings' in macOS Ventura. The string for Ventura and later is defined in another file, this is the string for earlier versions || Example: 1. Open 'Security & Privacy' Preferences 2. Switch on 'Mac Mouse Fix Helper'");
    }
}

- (IBAction)AuthorizeButton:(NSButton *)sender {
    
    /// This is defined in IB instead now. 
    
    assert(false);
    
    DDLogInfo(@"AuthorizeButton clicked");
    
    /// Open privacy prefpane
    
    NSString* urlString = @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:urlString]];
}
- (IBAction)cancelButton:(NSButton *)sender {
    [HelperServices enableHelperAsUserAgent:NO onComplete:nil];
    [AuthorizeAccessibilityView remove];
}

+ (void)add {
    
    DDLogInfo(@"adding AuthorizeAccessibilityView");
  
    ///
    /// New sheet method
    ///
    
    dispatch_async(dispatch_get_main_queue(), ^{ /// Remove just don't work sometimes when we don't dispatch to mainQueue. Also dispatching add to be safe.
        
        if (_accViewController == nil) {
            _accViewController = [[AuthorizeAccessibilityView alloc] initWithNibName:@"AuthorizeAccessibilityView" bundle:[NSBundle bundleForClass:[self class]]];
        }
        if ([MainAppState.shared.tabViewController.presentedViewControllers containsObject:_accViewController]) return;
        [MainAppState.shared.tabViewController presentViewControllerAsSheet:_accViewController];
    });
    
    ///
    /// Old overlay method for MMF 2.0
    ///
    
//    NSView *mainView = AppDelegate.mainWindow.contentView;
//
//    NSView *baseView;
//    for (NSView *v in mainView.subviews) {
//        if ([v.identifier isEqualToString:@"baseView"]) {
//            baseView = v;
//        }
//    }
//    NSView *accView;
//    for (NSView *v in mainView.subviews) {
//        if ([v.identifier isEqualToString:@"accView"]) {
//            accView = v;
//        }
//    }
//    if (accView == NULL) {
//        _accViewController = [[AuthorizeAccessibilityView alloc] initWithNibName:@"AuthorizeAccessibilityView" bundle:[NSBundle bundleForClass:[self class]]];
//        accView = _accViewController.view;
//        [mainView addSubview:accView];
//        accView.alphaValue = 0;
//        accView.hidden = YES;
//        /// Center in superview
////        mainView.translatesAutoresizingMaskIntoConstraints = NO;
//        accView.translatesAutoresizingMaskIntoConstraints = NO;
//        DDLogInfo(@"mainView frame: %@, accView frame: %@", [NSValue valueWithRect:mainView.frame], [NSValue valueWithRect:accView.frame]);
//        [mainView addConstraints:@[
//            [NSLayoutConstraint constraintWithItem:mainView
//                                         attribute:NSLayoutAttributeCenterX
//                                         relatedBy:NSLayoutRelationEqual
//                                            toItem:accView
//                                         attribute:NSLayoutAttributeCenterX
//                                        multiplier:1
//                                          constant:0],
//            [NSLayoutConstraint constraintWithItem:mainView
//                                         attribute:NSLayoutAttributeCenterY
//                                         relatedBy:NSLayoutRelationEqual
//                                            toItem:accView
//                                         attribute:NSLayoutAttributeCenterY
//                                        multiplier:1
//                                          constant:0],
//        ]];
//        [mainView layout];
//        DDLogInfo(@"mainView frame: %@, accView frame: %@", [NSValue valueWithRect:mainView.frame], [NSValue valueWithRect:accView.frame]);
//    }
//
//    [NSAnimationContext beginGrouping];
//    [[NSAnimationContext currentContext] setDuration:0.3];
//    baseView.animator.alphaValue = 0;
//    baseView.hidden = YES;
//    accView.animator.alphaValue = 1;
//    accView.hidden = NO;
//    [NSAnimationContext endGrouping];
}

+ (void)remove {
    
    DDLogInfo(@"Removing AuthorizeAccessibilityView");
    
    ///
    /// New sheet method
    ///
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (_accViewController == nil) return;
        if (![MainAppState.shared.tabViewController.presentedViewControllers containsObject:_accViewController]) return;
        
        [MainAppState.shared.tabViewController dismissViewController:_accViewController];
    });
    
    ///
    /// Old overlay method for MMF 2.0
    ///
    
//    NSView *mainView = AppDelegate.mainWindow.contentView;
//
//    NSView *baseView;
//    for (NSView *v in mainView.subviews) {
//        if ([v.identifier isEqualToString:@"baseView"]) {
//            baseView = v;
//        }
//    }
//    int i = 0;
//    NSView *accView;
//    for (NSView *v in mainView.subviews) {
//        if ([v.identifier isEqualToString:@"accView"]) {
//            accView = v;
//            i++;
//        }
//    }
//
//    if (accView) {
//        [accView removeFromSuperview];
//
//        [NSAnimationContext beginGrouping];
//        [NSAnimationContext.currentContext setDuration:0.3];
//        [NSAnimationContext.currentContext setCompletionHandler:^{
////            NSAttributedString *message = [[NSAttributedString alloc] initWithString:@"Welcome to Mac Mouse Fix!"];
////            [ToastController attachNotificationWithMessage:message toWindow:AppDelegate.mainWindow forDuration:-1];
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.0), dispatch_get_main_queue(), ^{
//                // v This usually fails because the remote message port can't be created
//                //      I think it happens because the helper kills itself after gaining accessibility access and is restarted by launchd too slowly. Weirdly, I think I remember that this used to work.
//                NSSet *capturedButtons = [RemapTableUtility getCapturedButtons];
//                [CaptureToasts showButtonCaptureToastWithBeforeSet:NSSet.set afterSet:capturedButtons];
////                NSAttributedString *message = [[NSAttributedString alloc] initWithString:@"Mac Mouse Fix will stay enabled after you restart your Mac"];
////                [ToastController attachNotificationWithMessage:message toWindow:AppDelegate.mainWindow forDuration:-1];
//            });
//        }];
//        baseView.animator.alphaValue = 1;
//        baseView.hidden = NO;
//        accView.animator.alphaValue = 0;
//        accView.hidden = YES;
//        [NSAnimationContext endGrouping];
//    }
}

@end
