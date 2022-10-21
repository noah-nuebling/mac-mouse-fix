//
// --------------------------------------------------------------------------
// AuthorizeAccessibilityView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "AppDelegate.h"
#import "AuthorizeAccessibilityView.h"
#import "MessagePort_App.h"
#import "Utility_App.h"
#import "MFNotificationController.h"
#import "SharedMessagePort.h"
#import "CaptureNotifications.h"
#import "RemapTableUtility.h"
#import "SharedUtility.h"
#import "HelperServices.h"
#import "Locator.h"

@interface AuthorizeAccessibilityView ()

@end

@implementation AuthorizeAccessibilityView

AuthorizeAccessibilityView *_accViewController;

///
/// Functionality
///

- (IBAction)AuthorizeButton:(NSButton *)sender {
    
    NSLog(@"AuthorizeButton clicked");
    
    /// Open privacy prefpane
    
    NSString* urlString = @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:urlString]];
}

///
/// Add & Remove
///

+ (void)add {
    
    /// Get mainWindow contentView
    NSView *mainView = AppDelegate.mainWindow.contentView;
    
    /// Find accessibilityView
    NSView *accView;
    for (NSView *v in mainView.subviews) {
        if ([v.identifier isEqualToString:@"accView"]) {
            accView = v;
        }
    }
    
    /// Abort if accessibilityView already displaying
    
    BOOL alreadyShowing = accView != nil && accView.alphaValue != 0 && accView.isHidden == NO;
    if (alreadyShowing) return;
    
    /// Log
    NSLog(@"adding AuthorizeAccessibilityView");
    
    /// Find baseView
    NSView *baseView;
    for (NSView *v in mainView.subviews) {
        if ([v.identifier isEqualToString:@"baseView"]) {
            baseView = v;
        }
    }
    
    /// Instantiate accessibility view
    ///     If it hasn't been found
    
    if (accView == NULL) {
        _accViewController = [[AuthorizeAccessibilityView alloc] initWithNibName:@"AuthorizeAccessibilityView" bundle:[NSBundle bundleForClass:[self class]]];
        accView = _accViewController.view;
        [mainView addSubview:accView];
        accView.alphaValue = 0;
        accView.hidden = YES;
        /// Center in superview
//        mainView.translatesAutoresizingMaskIntoConstraints = NO;
        accView.translatesAutoresizingMaskIntoConstraints = NO;
        NSLog(@"mainView frame: %@, accView frame: %@", [NSValue valueWithRect:mainView.frame], [NSValue valueWithRect:accView.frame]);
        [mainView addConstraints:@[
            [NSLayoutConstraint constraintWithItem:mainView
                                         attribute:NSLayoutAttributeCenterX
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:accView
                                         attribute:NSLayoutAttributeCenterX
                                        multiplier:1
                                          constant:0],
            [NSLayoutConstraint constraintWithItem:mainView
                                         attribute:NSLayoutAttributeCenterY
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:accView
                                         attribute:NSLayoutAttributeCenterY
                                        multiplier:1
                                          constant:0],
        ]];
        [mainView layout];
        NSLog(@"mainView frame: %@, accView frame: %@", [NSValue valueWithRect:mainView.frame], [NSValue valueWithRect:accView.frame]);
    }
    
    /// Show accessibility view
    ///     Animate baseView out and accessibilityView in
    
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.3];
    baseView.animator.alphaValue = 0;
    baseView.hidden = YES;
    accView.animator.alphaValue = 1;
    accView.hidden = NO;
    [NSAnimationContext endGrouping];
}

+ (void)remove {
    
    NSLog(@"Removing AuthorizeAccessibilityView");
    
    NSView *mainView = AppDelegate.mainWindow.contentView;
    
    NSView *baseView;
    for (NSView *v in mainView.subviews) {
        if ([v.identifier isEqualToString:@"baseView"]) {
            baseView = v;
        }
    }
    int i = 0;
    NSView *accView;
    for (NSView *v in mainView.subviews) {
        if ([v.identifier isEqualToString:@"accView"]) {
            accView = v;
            i++;
        }
    }
    
    if (accView) {
        [accView removeFromSuperview];
        
        [NSAnimationContext beginGrouping];
        [NSAnimationContext.currentContext setDuration:0.3];
        [NSAnimationContext.currentContext setCompletionHandler:^{
//            NSAttributedString *message = [[NSAttributedString alloc] initWithString:@"Welcome to Mac Mouse Fix!"];
//            [MFNotificationController attachNotificationWithMessage:message toWindow:AppDelegate.mainWindow forDuration:-1];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.0), dispatch_get_main_queue(), ^{
                // v This usually fails because the remote message port can't be created
                //      I think it happens because the helper kills itself after gaining accessibility access and is restarted by launchd too slowly. Weirdly, I think I remember that this used to work.
                NSSet *capturedButtons = [RemapTableUtility getCapturedButtons];
                [CaptureNotifications showButtonCaptureNotificationWithBeforeSet:NSSet.set afterSet:capturedButtons];
//                NSAttributedString *message = [[NSAttributedString alloc] initWithString:@"Mac Mouse Fix will stay enabled after you restart your Mac"];
//                [MFNotificationController attachNotificationWithMessage:message toWindow:AppDelegate.mainWindow forDuration:-1];
            });
        }];
        baseView.animator.alphaValue = 1;
        baseView.hidden = NO;
        accView.animator.alphaValue = 0;
        accView.hidden = YES;
        [NSAnimationContext endGrouping];
    }
}

@end
