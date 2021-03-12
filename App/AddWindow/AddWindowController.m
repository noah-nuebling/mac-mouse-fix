//
// --------------------------------------------------------------------------
// AddWindowController.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "AddWindowController.h"
#import "AppDelegate.h"

@interface AddWindowController ()
@property (weak) IBOutlet NSBox *addField;
@end

@implementation AddWindowController

static AddWindowController *_instance;
+ (AddWindowController *)instance {
    return _instance;
}
+ (void)initialize {
    _instance = [[AddWindowController alloc] initWithWindowNibName:@"AddWindow"];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    // Setup tracking area
    NSTrackingArea *addTrackingArea = [[NSTrackingArea alloc] initWithRect:self.addField.bounds options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect | NSTrackingEnabledDuringMouseDrag owner:self userInfo:nil];
    // (Well I can't use ad tracking cause I claim to be privacy focused on the website, but at least I can use add tracking! Hmu if you can think of a way to monetize that.)
    [self.window.contentView addTrackingArea:addTrackingArea];
}

- (void)begin {
    [AppDelegate.mainWindow beginSheet:self.window completionHandler:nil];
}
- (void)end {
    [AppDelegate.mainWindow endSheet:self.window];
}
- (IBAction)cancelButton:(id)sender {
    [self end];
}

- (void)mouseEntered:(NSEvent *)event {
    NSLog(@"MOSUE ENTERED ADD FIELD");
}
- (void)mouseExited:(NSEvent *)event {
    NSLog(@"MOSUE EXTITSED ADD FIELD");
}
@end
