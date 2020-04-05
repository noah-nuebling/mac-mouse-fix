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
#import "NSMutableDictionary+Additions.h"

@interface ScrollOverridePanel ()

#pragma mark Outlets

@property (strong) IBOutlet NSTableView *tableView;
@property (strong) IBOutlet NSButton *smoothEnabledCheckBox;

@end

@implementation ScrollOverridePanel

#pragma mark - Class

+ (void)load {
    _instance = [[ScrollOverridePanel alloc] initWithWindowNibName:@"ScrollOverridePanel"];
}
static ScrollOverridePanel *_instance;
+ (ScrollOverridePanel *)instance {
    return _instance;
}

#pragma mark - Instance

#pragma mark - Public variables

#pragma mark - Private variables

/// Keys are table column identifiers (These are set through interface builder). Values are keypaths to the values modified by the controls in the column with that identifier.
/// Keypaths relative to config root give default values. Relative to config[@"AppOverrides"][@"[bundle identifier of someApp]"] they give override values for someApp.
NSDictionary *_columnIdentifierToKeyPath;

/// This is never called
//- (instancetype)init
//{
//    self = [super init];
//    if (self) {
//        _columnIdentifierToKeyPath = @{
//            @"SmoothEnabledColumnID" : @"Scroll.smooth",
//            @"MagnificationEnabledColumnID" : @"Scroll.modifierKeys.magnificationScrollModifierKeyEnabled",
//            @"HorizontalEnabledColumnID" : @"Scroll.modifierKeys.horizontalScrollModifierKeyEnabled"
//        };
//    }
//    return self;
//}

#pragma mark - Public functions

- (void)windowDidLoad {
    [super windowDidLoad];
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}
- (void)setConfigFileToUI {
    [self writeTableViewDataModelToConfig];
    [ConfigFileInterface_PrefPane writeConfigToFile];
    [self loadTableViewDataModelFromConfig];
    [_tableView reloadData];
}
- (void)display {
    
    _columnIdentifierToKeyPath = @{
        @"SmoothEnabledColumnID" : @"Scroll.smooth",
        @"MagnificationEnabledColumnID" : @"Scroll.modifierKeys.magnificationScrollModifierKeyEnabled",
        @"HorizontalEnabledColumnID" : @"Scroll.modifierKeys.horizontalScrollModifierKeyEnabled"
    };
    [self loadTableViewDataModelFromConfig];
    if (self.window.isVisible) {
        [self.window close];
    } else {
        [self.window center];
    }
    [self.window makeKeyAndOrderFront:nil];
    [self.window performSelector:@selector(makeKeyWindow) withObject:nil afterDelay:0.05]; // Need to do this to make the window key. Magic.
    
    // Attempts to bring the window to the front when pressing the open button while it is open. Nothing worked reliably. Just closing it before reopening works though.
    
////    self.window.releasedWhenClosed = YES;
////    self.window.isReleasedWhenClosed = YES;
////    [self.window close];
////    [self.window performClose:nil];
//
////    CFRelease((__bridge void *) self.window);
//    [self.window makeKeyAndOrderFront:NULL]; // This allocates and displays the window I believe
////    [self.window makeKeyAndOrderFront:NULL];
//    [self.window makeKeyWindow];
//    [self.window orderFront:nil];
//
//
//    [NSApp activateIgnoringOtherApps:YES]; // Thought this might help with bringing the window to the foreground
//    [self.window orderFrontRegardless]; // Attempt #1 to bring the window to the foreground
//    [self.window makeKeyWindow]; // Attempt #2 to bring the window to the foreground
////     Can't bring the window to the foreground.
////    [self.window orderWindow:NSWindowBelow relativeTo:0];
////    [self.window orderWindow:NSWindowAbove relativeTo:0];
//    [self.window setOrderedIndex:0];
//
////    [self.window display];
}

#pragma mark TableView

- (IBAction)checkBoxInCell:(NSButton *)sender {
    NSInteger state = sender.state;
    NSInteger row = [_tableView rowForView:sender];
    NSInteger column = [_tableView columnForView:sender];
    NSString *columnIdentifier = _tableView.tableColumns[column].identifier;
    
//    _tableViewDataModel[row][columnIdentifier] = [NSNumber numberWithBool:state]; // Throws exception
//    NSNumber *newVal = [NSNumber numberWithBool:state];
//    NSMutableDictionary *val1 = _tableViewDataModel[row];
//    val1[columnIdentifier] = newVal;
    // This causes a crash, maybe the dict is not mutable?
    // TODO: Remove the lines above if fixed (Does the same thing as line below. Was for testing.)
    
    [_tableViewDataModel[row] setObject: [NSNumber numberWithBool:state] forKey: columnIdentifier];
    [self setConfigFileToUI];
  
    
    
//    NSString *keyPathToValueOverridenInColumn = _columnIdentifierToKeyPath[columnIdentifier];
    
//    NSMutableDictionary *dict1 = [NSMutableDictionary dictionary];
//    NSString *compoundKeyPath = [NSString stringWithFormat:@"AppOverrides.%@.%@", bundleIDForRowEscaped, keyPathToValueOverridenInColumn];
    
    
//    overrides[@"AppOverrides"][bundleIDForRow][keyPathToValueOverridenInColumn] = [NSNumber numberWithBool:state]; // Doesn't work in objc sadly. Using One keyPath for everything doesn't work either because bundleIDs contain periods.
//    NSDictionary *overrides = @{
//        @"AppOverrides": @{
//                bundleIDForRow: dict1
//        }
//    };
//    ConfigFileInterface_PrefPane.config = [[Utility_PrefPane applyOverridesFrom:(NSDictionary *)overrides to:ConfigFileInterface_PrefPane.config] mutableCopy];
//    [ConfigFileInterface_PrefPane.config setObject:[NSNumber numberWithBool:state] forCoolKeyPath:compoundKeyPath];
//    [ConfigFileInterface_PrefPane writeConfigToFile];
//    [self fillTableViewDataModelFromConfig];
//    [_tableView reloadData];
}
//- (IBAction)magnificationEnabledCheckBox:(NSButton *)sender {
//    NSInteger state = sender.state;
//    NSInteger row = [_tableView rowForView:sender];
//    NSString *bundleID = _tableViewDataModel[row][@"bundleID"];
//    NSDictionary *overrides = @{
//        @"AppOverrides": @{
//                bundleID: @{
//                        @"Scroll": @{
//                                @"modifierKeys": @{
//                                        @"magnificationScrollModifierKeyEnabled":[NSNumber numberWithInteger:state]
//                                }
//                        }
//                }
//        }
//    };
//    ConfigFileInterface_PrefPane.config = [Utility_PrefPane applyOverridesFrom:overrides to:ConfigFileInterface_PrefPane.config];
//    [ConfigFileInterface_PrefPane writeConfigToFile];
//    [self fillTableViewDataModelFromConfig];
//    [_tableView reloadData];
//}
//- (IBAction)horizontalEnabledCheckBox:(NSButton *)sender {
//    NSInteger state = sender.state;
//    NSInteger row = [_tableView rowForView:sender];
//    NSString *bundleID = _tableViewDataModel[row][@"bundleID"];
//    NSDictionary *overrides = @{
//        @"AppOverrides": @{
//                bundleID: @{
//                        @"Scroll": @{
//                                @"modifierKeys": @{
//                                        @"horizontalScrollModifierKeyEnabled":[NSNumber numberWithInteger:state]
//                                }
//                        }
//                }
//        }
//    };
//    ConfigFileInterface_PrefPane.config = [Utility_PrefPane applyOverridesFrom:overrides to:ConfigFileInterface_PrefPane.config];
//    [ConfigFileInterface_PrefPane writeConfigToFile];
//    [self fillTableViewDataModelFromConfig];
//    [_tableView reloadData];
//}

/// The tableView automatically calls this. The return determines how many rows the tableView will display.
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
//    return 3; // TODO: Change this to a proper value
    return _tableViewDataModel.count;
}

/// The tableView automatically calls this for every cell. It uses the return of this function as the content of the cell.
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    
    if (row >= _tableViewDataModel.count) {
        return nil;
    }
    
    if ([tableColumn.identifier isEqualToString:@"AppColumnID"]) {
        NSTableCellView *appCell = [_tableView makeViewWithIdentifier:@"AppCellID" owner:nil];
        if (appCell) {
            NSString *bundleID = [_tableViewDataModel objectAtIndex:row][@"AppColumnID"];
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
            appCell.textField.toolTip = appName;
            appCell.imageView.image = appIcon;
            
        }
        return appCell;
    } else if ([tableColumn.identifier isEqualToString:@"SmoothEnabledColumnID"]) {
        NSTableCellView *smoothEnabledCell = [_tableView makeViewWithIdentifier:@"CheckBoxCellID" owner:nil];
        if (smoothEnabledCell) {
            BOOL isEnabled = [_tableViewDataModel[row][@"SmoothEnabledColumnID"] boolValue];
            NSButton *checkBox = smoothEnabledCell.subviews[0];
            checkBox.state = isEnabled;
            checkBox.target = self;
            checkBox.action = @selector(checkBoxInCell:);
        }
        return smoothEnabledCell;
    } else if ([tableColumn.identifier isEqualToString:@"MagnificationEnabledColumnID"]) {
        NSTableCellView *smoothEnabledCell = [_tableView makeViewWithIdentifier:@"CheckBoxCellID" owner:nil];
        if (smoothEnabledCell) {
            BOOL isEnabled = [_tableViewDataModel[row][@"MagnificationEnabledColumnID"] boolValue];
            NSButton *checkBox = smoothEnabledCell.subviews[0];
            checkBox.state = isEnabled;
            checkBox.target = self;
            checkBox.action = @selector(checkBoxInCell:);
        }
        return smoothEnabledCell;
    } else if ([tableColumn.identifier isEqualToString:@"HorizontalEnabledColumnID"]) {
        NSTableCellView *smoothEnabledCell = [_tableView makeViewWithIdentifier:@"CheckBoxCellID" owner:nil];
        if (smoothEnabledCell) {
            BOOL isEnabled = [_tableViewDataModel[row][@"HorizontalEnabledColumnID"] boolValue];
            NSButton *checkBox = smoothEnabledCell.subviews[0];
            checkBox.state = isEnabled;
            checkBox.target = self;
            checkBox.action = @selector(checkBoxInCell:);
        }
        return smoothEnabledCell;
    }
    
    return nil;
}

#pragma mark - Private functions

NSMutableArray *_tableViewDataModel;

- (void)writeTableViewDataModelToConfig {
    for (NSDictionary *rowData in _tableViewDataModel) {
        NSString *bundleID = rowData[@"AppColumnID"];
        NSNumber *smoothEnabled = rowData[@"SmoothEnabledColumnID"];
        NSNumber *magnificationEnabled = rowData[@"MagnificationEnabledColumnID"];
        NSNumber *horizontalEnabled = rowData[@"HorizontalEnabledColumnID"];
        NSDictionary *dict = @{
            @"AppOverrides": @{
                    bundleID: @{
                            @"Scroll": @{
                                    @"smooth": smoothEnabled,
                                    @"modifierKeys": @{
                                            @"magnificationScrollModifierKeyEnabled": magnificationEnabled,
                                            @"horizontalScrollModifierKeyEnabled": horizontalEnabled
                                    }
                            }
                    }
            }
        };
        ConfigFileInterface_PrefPane.config = [[Utility_PrefPane dictionaryWithOverridesAppliedFrom:dict to:ConfigFileInterface_PrefPane.config] mutableCopy];
    }
//        NSInteger state = sender.state;
//        NSInteger row = [_tableView rowForView:sender];
//        NSInteger column = [_tableView columnForView:sender];
//        NSString *columnIdentifier = _tableView.tableColumns[column].identifier;
//        NSString *bundleIDForRow = _tableViewDataModel[row][@"AppColumnID"];
//        NSString *bundleIDForRowEscaped = [bundleIDForRow stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
//        NSString *keyPathToValueOverridenInColumn = _columnIdentifierToKeyPath[columnIdentifier];
//
//    //    NSMutableDictionary *dict1 = [NSMutableDictionary dictionary];
//        NSString *compoundKeyPath = [NSString stringWithFormat:@"AppOverrides.%@.%@", bundleIDForRowEscaped, keyPathToValueOverridenInColumn];
//
//
//    //    overrides[@"AppOverrides"][bundleIDForRow][keyPathToValueOverridenInColumn] = [NSNumber numberWithBool:state]; // Doesn't work in objc sadly. Using One keyPath for everything doesn't work either because bundleIDs contain periods.
//    //    NSDictionary *overrides = @{
//    //        @"AppOverrides": @{
//    //                bundleIDForRow: dict1
//    //        }
//    //    };
//    //    ConfigFileInterface_PrefPane.config = [[Utility_PrefPane applyOverridesFrom:(NSDictionary *)overrides to:ConfigFileInterface_PrefPane.config] mutableCopy];
//        [ConfigFileInterface_PrefPane.config setObject:[NSNumber numberWithBool:state] forCoolKeyPath:compoundKeyPath];
}


- (void)loadTableViewDataModelFromConfig {
    _tableViewDataModel = [NSMutableArray array];
    [ConfigFileInterface_PrefPane loadConfigFromFile];
    NSDictionary *config = ConfigFileInterface_PrefPane.config;
    if (!config) { // TODO: does this exception make sense? What is the consequence of it being thrown? Where is it caught? Should we just reload the config file instead?
        NSException *configNotLoadedException = [NSException exceptionWithName:@"ConfigNotLoadedException" reason:@"ConfigFileInterface config property is nil" userInfo:nil];
        @throw configNotLoadedException;
        return;
    }
    NSDictionary *overrides = config[@"AppOverrides"];
    if (!overrides) {
        NSLog(@"No overrides found in config while generating scroll override table data model.");
        return;
    }
    for (NSString *key in overrides) {
        
        // TODO: Put this inna loop
        NSNumber *smoothEnabled = [overrides[key] valueForKeyPath:@"Scroll.smooth"];
        NSNumber *magnificationEnabled = [overrides[key] valueForKeyPath:@"Scroll.modifierKeys.magnificationScrollModifierKeyEnabled"];
        NSNumber *horizontalEnabled = [overrides[key] valueForKeyPath:@"Scroll.modifierKeys.horizontalScrollModifierKeyEnabled"];
        
        if (smoothEnabled != nil || magnificationEnabled != nil || horizontalEnabled != nil) {
            if (smoothEnabled == nil || magnificationEnabled == nil || horizontalEnabled == nil) {
                [ConfigFileInterface_PrefPane repairConfigWithProblem:kMFConfigProblemIncompleteAppOverride info:[_columnIdentifierToKeyPath allValues]];
                
                smoothEnabled = [overrides[key] valueForKeyPath:@"Scroll.smooth"];
                magnificationEnabled = [overrides[key] valueForKeyPath:@"Scroll.modifierKeys.magnificationScrollModifierKeyEnabled"];
                horizontalEnabled = [overrides[key] valueForKeyPath:@"Scroll.modifierKeys.horizontalScrollModifierKeyEnabled"];
                
                
            }
            NSDictionary *rowData = @{
                @"AppColumnID":key,
                @"SmoothEnabledColumnID":smoothEnabled,
                @"MagnificationEnabledColumnID": magnificationEnabled,
                @"HorizontalEnabledColumnID": horizontalEnabled
            };
            [_tableViewDataModel addObject:[rowData mutableCopy]];
        }
    }
}

@end
