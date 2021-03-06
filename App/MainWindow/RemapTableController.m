//
// --------------------------------------------------------------------------
// RemapTableController.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "RemapTableController.h"

@interface RemapTableController ()
@property (strong) IBOutlet NSTableView *table;
@end

@implementation RemapTableController

- (void)viewDidLoad { // Not getting called for some reason
    NSLog(@"SCROLL VIEWWW");
    NSScrollView *scrollView = (NSScrollView *)_table.superview.superview;
    scrollView.wantsLayer = TRUE;
    scrollView.layer.cornerRadius = 5;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    NSLog(@"SCROLL VIEWWW NUMMM");
    [self viewDidLoad];
    return 2;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return nil;
}

@end
