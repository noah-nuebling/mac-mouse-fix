//
// --------------------------------------------------------------------------
// ScrollOverride.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

// Tableview programming guide
// https://www.appcoda.com/macos-programming-tableview/

#import "ScrollOverridePanel.h"
#import "ConfigFileInterface_PrefPane.h"

@interface ScrollOverridePanel ()

@property (strong) IBOutlet NSTableView *tableView;

@end

@implementation ScrollOverridePanel

#pragma mark - Public

- (void)display {
    [self.window makeKeyAndOrderFront:NULL];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    

    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

#pragma mark TableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return 15;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *cell = [_tableView makeViewWithIdentifier:@"AppCellID" owner:nil];
    if (cell) {
        
        cell.textField.stringValue = @"LEELLLELELE";
        cell.imageView.image = [NSImage imageNamed:@"PayPal"];
    }
    return cell;
}

#pragma mark - Private

NSArray *_tableViewDataModel;
- (void)fillTableViewDataModelFromConfig {
    NSDictionary *config = ConfigFileInterface_PrefPane.config;
}

@end
