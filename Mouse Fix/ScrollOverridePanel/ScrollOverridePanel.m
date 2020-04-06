//
// --------------------------------------------------------------------------
// ScrollOverride.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

/*
 Reference:
    Table view programming guide:
        https://www.appcoda.com/macos-programming-tableview/
    Drag and drop for table views:
        https://www.natethompson.io/2019/03/23/nstableview-drag-and-drop.html
    Uniform Type Identifiers (UTIs) Reference: https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html#//apple_ref/doc/uid/TP40009259-SW1
 */

#import "ScrollOverridePanel.h"
#import "ConfigFileInterface_PrefPane.h"
#import "Utility_PrefPane.h"
#import "NSMutableDictionary+Additions.h"
#import <Foundation/Foundation.h>

@interface ScrollOverridePanel ()

#pragma mark Outlets

@property (strong) IBOutlet NSTableView *tableView;
//@property (strong) IBOutlet NSButton *smoothEnabledCheckBox; // TODO: Delete if not needed

@end

@implementation ScrollOverridePanel

#pragma mark - Class

+ (void)load {
    _instance = [[ScrollOverridePanel alloc] initWithWindowNibName:@"ScrollOverridePanel"];
        // Register for incoming drag and drop operation
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

- (void)windowDidLoad { // I think I didn't use this because it gets called after `- openWindow`.
    [super windowDidLoad];
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)openWindow {
    _columnIdentifierToKeyPath = @{
        @"SmoothEnabledColumnID" : @"Scroll.smooth",
        @"MagnificationEnabledColumnID" : @"Scroll.modifierKeys.magnificationScrollModifierKeyEnabled",
        @"HorizontalEnabledColumnID" : @"Scroll.modifierKeys.horizontalScrollModifierKeyEnabled"
    };
    [ConfigFileInterface_PrefPane loadConfigFromFile];
    [self loadTableViewDataModelFromConfig];
    [_tableView reloadData];
    
    if (self.window.isVisible) {
        [self.window close];
    } else {
        [self.window center];
    }
    [self.window makeKeyAndOrderFront:nil];
    [self.window performSelector:@selector(makeKeyWindow) withObject:nil afterDelay:0.05]; // Need to do this to make the window key. Magic.
    
    // Make tableView drag and drop target
    
    NSString *bundleUTI = @"com.apple.bundle"; //kUTITypeBundle
    // public.executable
    // com.apple.application (kUTTypeApplication)
    // com.apple.application-​bundle (kUTTypeApplicationBundle)
    // com.apple.application-file (kUTTypeApplicationFile)
    // @"com.apple.application-bundle", @"public.text", @"public.url", @"public.file-url"
    
    // @"public.file-url" makes it accept apps
    
    [_tableView registerForDraggedTypes:@[@"public.file-url"]];
    [_tableView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
}
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
//}


- (void)setConfigFileToUI {
    [self writeTableViewDataModelToConfig];
    [ConfigFileInterface_PrefPane writeConfigToFileAndNotifyHelper];
    [self loadTableViewDataModelFromConfig];
    [_tableView reloadData];
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
            NSString *bundleID = _tableViewDataModel[row][tableColumn.identifier];
            NSString *appPath = [NSWorkspace.sharedWorkspace absolutePathForAppBundleWithIdentifier:bundleID];
//            NSBundle *bundle = [NSBundle bundleWithIdentifier:bundleID]; // This doesn't work for some reason
            NSImage *appIcon;
            NSString *appName;
            if (![Utility_PrefPane appIsInstalled:bundleID]) {
                // TODO: This will happen, when the user uninstalls an app. Handle gracefully. Prolly just remove the app from config or don't display it.
//                appIcon = [NSImage imageNamed:NSImageNameStopProgressFreestandingTemplate]; //NSImageNameStopProgressFreestandingTemplate
                appIcon = [NSImage imageNamed:NSImageNameStopProgressFreestandingTemplate];
                appName = [NSString stringWithFormat:@"Couldn't find app: %@", bundleID];
            } else {
                appIcon = [NSWorkspace.sharedWorkspace iconForFile:appPath];
                appName = [[NSBundle bundleWithPath:appPath] objectForInfoDictionaryKey:@"CFBundleName"];
            }
            
            appCell.textField.stringValue = appName;
            appCell.textField.toolTip = appName;
            appCell.imageView.image = appIcon;
        }
        return appCell;
    } else if ([tableColumn.identifier isEqualToString:@"SmoothEnabledColumnID"] ||
               [tableColumn.identifier isEqualToString:@"MagnificationEnabledColumnID"] ||
               [tableColumn.identifier isEqualToString:@"HorizontalEnabledColumnID"]) {
        NSTableCellView *cell = [_tableView makeViewWithIdentifier:@"CheckBoxCellID" owner:nil];
        if (cell) {
            BOOL isEnabled = [_tableViewDataModel[row][tableColumn.identifier] boolValue];
            NSButton *checkBox = cell.subviews[0];
            checkBox.state = isEnabled;
            checkBox.target = self;
            checkBox.action = @selector(checkBoxInCell:);
        }
        return cell;
    }
    return nil;
}

#pragma mark Drag and drop

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    if (dropOperation == NSTableViewDropAbove) {
        return NSDragOperationMove;
    }
    return NSDragOperationNone;
    
}
- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
    return @"Hello from table";
}

#pragma mark - Private functions

NSMutableArray *_tableViewDataModel;

- (void)writeTableViewDataModelToConfig {
    
    for (NSMutableDictionary *rowDict in _tableViewDataModel) {
        NSString *bundleID = rowDict[@"AppColumnID"];
        NSString *bundleIDEscaped = [bundleID stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
        rowDict[@"AppColumnID"] = nil; // So we don't iterate over this in the loop below
        for (NSString *columnID in rowDict) {
            NSObject *cellValue = rowDict[columnID];
            NSString *defaultKeyPath = _columnIdentifierToKeyPath[columnID];
            NSString *overrideKeyPath = [NSString stringWithFormat:@"AppOverrides.%@.%@", bundleIDEscaped, defaultKeyPath];
            [ConfigFileInterface_PrefPane.config setObject:cellValue forCoolKeyPath:overrideKeyPath];
        }
    }
    [ConfigFileInterface_PrefPane writeConfigToFileAndNotifyHelper];
}
//        NSNumber *smoothEnabled = rowDict[@"SmoothEnabledColumnID"];
//        NSNumber *magnificationEnabled = rowDict[@"MagnificationEnabledColumnID"];
//        NSNumber *horizontalEnabled = rowDict[@"HorizontalEnabledColumnID"];
//        NSDictionary *dict = @{
//            @"AppOverrides": @{
//                    bundleID: @{
//                            @"Scroll": @{
//                                    @"smooth": smoothEnabled,
//                                    @"modifierKeys": @{
//                                            @"magnificationScrollModifierKeyEnabled": magnificationEnabled,
//                                            @"horizontalScrollModifierKeyEnabled": horizontalEnabled
//                                    }
//                            }
//                    }
//            }
//        };
//        ConfigFileInterface_PrefPane.config = [[Utility_PrefPane dictionaryWithOverridesAppliedFrom:dict to:ConfigFileInterface_PrefPane.config] mutableCopy];
//    }
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
//}


- (void)loadTableViewDataModelFromConfig {
    _tableViewDataModel = [NSMutableArray array];
    NSDictionary *config = ConfigFileInterface_PrefPane.config;
    if (!config) { // TODO: does this exception make sense? What is the consequence of it being thrown? Where is it caught? Should we just reload the config file instead? Can this even happen if ConfigFileInterface successfully loaded?
        NSException *configNotLoadedException = [NSException exceptionWithName:@"ConfigNotLoadedException" reason:@"ConfigFileInterface config property is nil" userInfo:nil];
        @throw configNotLoadedException;
        return;
    }
    NSDictionary *overrides = config[@"AppOverrides"];
    if (!overrides) {
        NSLog(@"No overrides found in config while generating scroll override table data model.");
        return;
    }
    
    for (NSString *bundleID in overrides.allKeys) { // Every bundleID corresponds to one app/row
        // Check if app exists on system
        if (![Utility_PrefPane appIsInstalled:bundleID]) {
            [ConfigFileInterface_PrefPane cleanUpConfig];
            continue;
        }
        // Create row dict for app with `bundleID` from data in config. Every key value pair in row dict corresponds to a column. The key is the column identifier and the value is the value for the column with `columnID` and the row of the app with `bundleID`
        NSMutableDictionary *rowDict = [NSMutableDictionary dictionary];
        NSArray *columnIDs = _columnIdentifierToKeyPath.allKeys;
        for (NSString *columnID in columnIDs) { // Every columnID corresponds to one column (duh)
            NSString *keyPath = _columnIdentifierToKeyPath[columnID];
            NSObject *value = [overrides[bundleID] valueForKeyPath:keyPath];
            rowDict[columnID] = value; // if value is nil, no entry will be added
        }
        // Check existence / validity of generated rowDict
        BOOL allNil = (rowDict.allValues.count == 0);
        BOOL someNil = (rowDict.allValues.count < columnIDs.count);
        if (allNil) { // None of the values controlled by the table exist in this AppOverride
            continue; // Don't add this app to the table
        }
        if (someNil) { // Only some of the values controlled by the table don't exist in this AppOverride
            // Fill out missing values with default ones
            [ConfigFileInterface_PrefPane repairConfigWithProblem:kMFConfigProblemIncompleteAppOverride info:@{
                    @"bundleID": bundleID,
                    @"relevantKeyPaths": [_columnIdentifierToKeyPath allValues],
            }];
            [self loadTableViewDataModelFromConfig]; // restart the whole function
            return;
        }
        rowDict[@"AppColumnID"] = bundleID; // Add this last, so the allNil check works properly
        
        [_tableViewDataModel addObject:rowDict];
    }
}
        
        // rowDict will look like this: (If no new columns have been added since time of writing)
        //            rowDict = @{
        //                @"AppColumnID":[bundleIDString],
        //                @"SmoothEnabledColumnID":[smoothEnabledBOOL],
        //                @"MagnificationEnabledColumnID":[magnificationEnabledBOOL],
        //                @"HorizontalEnabledColumnID":[horizontalEnabledBOOL]
        //            };
        
        
//        NSNumber *smoothEnabled = [overrides[bundleID] valueForKeyPath:@"Scroll.smooth"];
//        NSNumber *magnificationEnabled = [overrides[bundleID] valueForKeyPath:@"Scroll.modifierKeys.magnificationScrollModifierKeyEnabled"];
//        NSNumber *horizontalEnabled = [overrides[bundleID] valueForKeyPath:@"Scroll.modifierKeys.horizontalScrollModifierKeyEnabled"];
//
//        if (smoothEnabled != nil || magnificationEnabled != nil || horizontalEnabled != nil) {
//
//            // Make sure the config file is valid. If not - repair.
//            if (smoothEnabled == nil || magnificationEnabled == nil || horizontalEnabled == nil) {
//                [ConfigFileInterface_PrefPane repairConfigWithProblem:kMFConfigProblemIncompleteAppOverride info:[_columnIdentifierToKeyPath allValues]];
//
//                smoothEnabled = [overrides[bundleID] valueForKeyPath:@"Scroll.smooth"];
//                magnificationEnabled = [overrides[bundleID] valueForKeyPath:@"Scroll.modifierKeys.magnificationScrollModifierKeyEnabled"];
//                horizontalEnabled = [overrides[bundleID] valueForKeyPath:@"Scroll.modifierKeys.horizontalScrollModifierKeyEnabled"];
//            }
////            rowData = @{
////                @"AppColumnID":bundleID,
////                @"SmoothEnabledColumnID":smoothEnabled,
////                @"MagnificationEnabledColumnID": magnificationEnabled,
////                @"HorizontalEnabledColumnID": horizontalEnabled
////            };
//        }
    
//    }
//}

@end
