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
@end
