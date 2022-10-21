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

+ (void)forceUpdateSystemSettings {
    
    /// Current solution where we restart the helper is terrible because launchd enforces maximum 1 start of the helper per 10 seconds. So when you enable the app into the non-accessibiliy-authorized state it freezes for 10 seconds. Because the "restartHelper" call takes 10 seconds. Even if we do that call in the background it messes things up because the accessibiltyOverlay will be removed when the helper doesn't respond for that long.
    ///     For more on the 10 second restriction, see: https://apple.stackexchange.com/questions/63482/can-launchd-run-programs-more-frequently-than-every-10-seconds
    
    /// This is a workaround
    ///     for an Apple bug where the Accessibility toggle for MMF Helper won't work after an update.
    ///     This bug occured between 2.2.0 and 2.2.1 when I moved the app from a Development Signature to a proper Developer Program Signature.
    ///     Bug also maybe occurs for 3.0.0 Beta 4. Not sure why. Maybe it's a different bug that just looks similar.
    /// See
    /// - https://github.com/noah-nuebling/mac-mouse-fix/issues/415
    /// - https://github.com/noah-nuebling/mac-mouse-fix/issues/412
    
    /// Log
    
    NSLog(@"Force update system settings");
    
    NSDate *restartTime = [HelperServices possibleRestartTime];
    
    NSTimer *restartTimer = [[NSTimer alloc] initWithFireDate:restartTime interval:0.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
        
        /// TODO: Invalidate this timer. Otherwise memory leaks (I think).
        
        /// Log
        NSLog(@"Actually force update system settings");
        
        /// Remove existing helper from System Settings
        /// - If an old helper exists, the user won't be able to enable the new helper!
        /// - This will make the system unresponsive if there is still an old helper running that's already tapped into the button event stream!
        [SharedUtility launchCTL:[NSURL fileURLWithPath:kMFTccutilPath] withArguments:@[@"reset", @"Accessibility", kMFBundleIDHelper] error:nil];
        
        /// Kill helper
        /// - It will then be restarted and then add itself to System Settings
        /// - We can't just send it a message to add itself to System Settings. Reason: Since the helper told us that accessibility is disabled it must've already called `AXIsProcessTrustedWithOptions()`. `AXIsProcessTrustedWithOptions()` has the side effect of adding the caller to the accessibility list in System Settings. But that seems to only work **once** after the app is launched. So we need to relaunch the helper so can add itself to System Settings via `AXIsProcessTrustedWithOptions()`.
        
        [HelperServices restartHelper];
    }];
    
    [NSRunLoop.currentRunLoop addTimer:restartTimer forMode:NSRunLoopCommonModes];
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
    
    /// Workaround for Apple bug
    [self forceUpdateSystemSettings];
    
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
