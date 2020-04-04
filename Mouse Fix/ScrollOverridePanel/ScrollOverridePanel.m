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
#import "Utility_PrefPane.h"

@interface ScrollOverridePanel ()

@property (strong) IBOutlet NSTableView *tableView;
@property (strong) IBOutlet NSButton *smoothEnabledCheckBox;

@end

@implementation ScrollOverridePanel

#pragma mark - Public

- (void)display {
    [self fillTableViewDataModelFromConfig];
    [self.window makeKeyAndOrderFront:NULL]; // This allocates and displays the window I believe
    [NSApp activateIgnoringOtherApps:YES]; // Thought this might help with bringing the window to the foreground
    [self.window orderFrontRegardless]; // Attempt #1 to bring the window to the foreground
    [self.window makeKeyWindow]; // Attempt #2 to bring the window to the foreground
    // Can't bring the window to the foreground.
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    

    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

#pragma mark TableView

- (IBAction)smoothEnableCheckBox:(NSButton *)sender {
    NSInteger state = sender.state;
    NSInteger row = [_tableView rowForView:sender];
    NSString *bundleID = _tableViewDataModel[row][@"bundleID"];
    NSDictionary *overrides = @{
        @"AppOverrides": @{
                bundleID: @{
                        @"Scroll": @{
                                @"smooth": [NSNumber numberWithInteger:state]
                        }
                }
        }
    };
    ConfigFileInterface_PrefPane.config = [Utility_PrefPane applyOverridesFrom:overrides to:ConfigFileInterface_PrefPane.config];
    [ConfigFileInterface_PrefPane writeConfigToFile];
    [self fillTableViewDataModelFromConfig];
    [_tableView reloadData];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return 3;
//    return _tableViewDataModel.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    
    if (row >= _tableViewDataModel.count) {
        return nil;
    }
    
    if ([tableColumn.identifier isEqualToString:@"AppColumnID"]) {
        NSTableCellView *appCell = [_tableView makeViewWithIdentifier:@"AppCellID" owner:nil];
        if (appCell) {
            NSString *bundleID = [_tableViewDataModel objectAtIndex:row][@"bundleID"];
            NSString *appPath = [NSWorkspace.sharedWorkspace absolutePathForAppBundleWithIdentifier:bundleID];
//            NSBundle *bundle = [NSBundle bundleWithIdentifier:bundleID]; // This doesn't work for some reason
            NSImage *appIcon;
            NSString *appName;
            if (!appPath) {
                appIcon = [NSImage imageNamed:NSImageNameStatusUnavailable];
                appName = [NSString stringWithFormat:@"%@", bundleID];
            } else {
                appIcon = [NSWorkspace.sharedWorkspace iconForFile:appPath];
                appName = [[NSBundle bundleWithPath:appPath] objectForInfoDictionaryKey:@"CFBundleName"];
            }
            
            appCell.textField.stringValue = appName;
            appCell.imageView.image = appIcon;
            
        }
        return appCell;
    } else if ([tableColumn.identifier isEqualToString:@"SmoothEnabledColumnID"]) {
        NSTableCellView *smoothEnabledCell = [_tableView makeViewWithIdentifier:@"SmoothEnabledCellID" owner:nil];
        if (smoothEnabledCell) {
            BOOL smoothEnabled = [_tableViewDataModel[row][@"smoothEnabled"] boolValue];
            NSButton *checkBox = smoothEnabledCell.subviews[0];
            checkBox.state = smoothEnabled;
            checkBox.target = self;
            checkBox.action = @selector(smoothEnableCheckBox:);
        }
        return smoothEnabledCell;
    }
    
    return nil;
}

#pragma mark - Private

NSMutableArray *_tableViewDataModel;
- (void)fillTableViewDataModelFromConfig {
    _tableViewDataModel = [NSMutableArray array];
    NSDictionary *config = ConfigFileInterface_PrefPane.config;
    if (!config) {
        NSException *configNotLoadedException = [NSException exceptionWithName:@"ConfigNotLoadedException" reason:@"ConfigFileInterface config property is nil" userInfo:nil];
        @throw configNotLoadedException;
        return;
    }
    NSDictionary *overrides = config[@"AppOverrides"];
    if (!overrides) {
        NSLog(@"No overrides found in config while generating scroll override table view data model.");
        return;
    }
    for (NSString *key in overrides) {
        NSNumber *smoothEnabled = [overrides[key] valueForKeyPath:@"Scroll.smooth"];
        if (smoothEnabled != nil) {
            NSDictionary *rowData = @{
                @"bundleID":key,
                @"smoothEnabled":smoothEnabled
            };
            [_tableViewDataModel addObject:rowData];
        }
    }
}

@end
