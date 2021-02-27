//
// --------------------------------------------------------------------------
// AuthorizeAccessibilityView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "../AppDelegate.h"
#import "AuthorizeAccessibilityView.h"
#import "../MessagePort/MessagePort_App.h"
#import "Utility_App.h"

@interface AuthorizeAccessibilityView ()

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
//    NSLog(@"subviews: %@", prefWindow.contentView.subviews);
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)AuthorizeButton:(NSButton *)sender {
    
    NSLog(@"AuthorizeButton clicked");
    
    // Open privacy prefpane
    
    NSString* urlString = @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:urlString]];
}

+ (void)add {
    
    NSLog(@"adding AuthorizeAccessibilityView");
    
    NSView *mainView = AppDelegate.mainWindow.contentView;
    
    NSView *baseView;
    for (NSView *v in mainView.subviews) {
        if ([v.identifier isEqualToString:@"baseView"]) {
            baseView = v;
        }
    }
    NSView *accView;
    for (NSView *v in mainView.subviews) {
        if ([v.identifier isEqualToString:@"accView"]) {
            accView = v;
        }
    }
    if (accView == NULL) {
        _accViewController = [[AuthorizeAccessibilityView alloc] initWithNibName:@"AuthorizeAccessibilityView" bundle:[NSBundle bundleForClass:[self class]]];
        accView = _accViewController.view;
        [mainView addSubview:accView];
        accView.alphaValue = 0;
        accView.hidden = YES;
    }
    
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.3];
    baseView.animator.alphaValue = 0;
    baseView.hidden = YES;
    accView.animator.alphaValue = 1;
    accView.hidden = NO;
    [NSAnimationContext endGrouping];
}

+ (void)remove {
    
    NSLog(@"removing AuthorizeAccessibilityView");
    
//    NSView *mainView = NSApp.mainWindow.contentView;
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
        NSLog(@"View ID: %@", v.identifier);
        if ([v.identifier isEqualToString:@"accView"]) {
            accView = v;
            i++;
        }
    }
    
    NSLog(@"NSApp: %@", NSApp);
    NSLog(@"NSApp window: %@", NSApp.mainWindow);
    NSLog(@"Main view: %@", mainView);
    NSLog(@"Main view: %@, %@", mainView.subviews, mainView.superview);
    NSLog(@"Acc view counter: %d", i);
    
    if (accView) {
        [accView removeFromSuperview];
    }
    
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.3];
    baseView.animator.alphaValue = 1;
    baseView.hidden = NO;
    accView.animator.alphaValue = 0;
    accView.hidden = YES;
    [NSAnimationContext endGrouping];
    
}

@end
