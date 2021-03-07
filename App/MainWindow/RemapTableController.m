//
// --------------------------------------------------------------------------
// RemapTableController.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "RemapTableController.h"
#import "ConfigFileInterface_App.h"

@interface RemapTableController ()
@end

@implementation RemapTableController

NSMutableArray *_data;

- (void)loadDataFromConfig {
    _data = ConfigFileInterface_App.config[remaps];
}
- (void)setDataToConfig {
    
}

- (void)viewDidLoad { // Not getting called for some reason -> I had to set the view outlet of the controller object in IB to the tableView
    // Set corner radius
    NSScrollView *scrollView = (NSScrollView *)self.view.superview.superview;
    scrollView.wantsLayer = TRUE;
    scrollView.layer.cornerRadius = 5;
    // Load table data from config
    _data = confi
    // Override table data for testing
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    NSLog(@"SCROLL VIEWWW NUMMM");
    return 2;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return nil;
}

@end
