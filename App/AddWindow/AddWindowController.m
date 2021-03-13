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
#import "MessagePort_App.h"
#import "RemapTableController.h"

@interface AddWindowController ()
@property (weak) IBOutlet NSBox *addField;
@end

@implementation AddWindowController

// Init

static AddWindowController *_instance;
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

// UI callbacks

- (IBAction)cancelButton:(id)sender {
    [AddWindowController end];
}
- (void)mouseEntered:(NSEvent *)event {
    NSLog(@"MOSUE ENTERED ADD FIELD");
    [MessagePort_App sendMessageToHelper:@"enableAddMode"];
}
- (void)mouseExited:(NSEvent *)event {
    NSLog(@"MOSUE EXTITSED ADD FIELD");
    [MessagePort_App sendMessageToHelper:@"disableAddMode"];
}

// Interface

+ (void)begin {
    [AppDelegate.mainWindow beginSheet:_instance.window completionHandler:nil];
}
+ (void)end {
    [AppDelegate.mainWindow endSheet:_instance.window];
}
+ (void)handleReceivedAddModeFeedbackFromHelperWithPayload:(NSDictionary *)payload {
    [self end];
    // The payload is an almost finished remapsTable (aka RemapTableController.dataModel) entry with the kMFRemapsKeyEffect key missing
    [((RemapTableController *)AppDelegate.instance.remapsTable.delegate) addRowWithHelperPayload:(NSDictionary *)payload];
}



@end

