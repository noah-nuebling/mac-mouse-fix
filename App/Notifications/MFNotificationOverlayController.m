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

@interface MFNotificationOverlayController ()
@property (weak) IBOutlet NSTextField *label;
@end

@implementation MFNotificationOverlayController

MFNotificationOverlayController *_instance;

+ (void)initialize {
    
    if (self == [MFNotificationOverlayController class]) {
        _instance = [[MFNotificationOverlayController alloc] initWithNibName:@"NotificationOverlay" bundle:nil];
    }
}

+ (NSView *)getNotificationWithMessage:(NSAttributedString *)message {
    
    _instance.label.attributedStringValue = message;
    
    _instance.view.wantsLayer = YES;
    _instance.view.superview.wantsLayer =  YES;
    
    [_instance.view setFrame:NSMakeRect(20, 20, 300, 100)];
    _instance.view.layer.shadowOffset = NSZeroSize;
    _instance.view.layer.shadowOpacity = 0.2;
    _instance.view.layer.shadowRadius = 10;
    _instance.view.layer.shadowColor = NSColor.blackColor.CGColor;
    _instance.view.layer.masksToBounds = false;
    
    return _instance.view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

@end
