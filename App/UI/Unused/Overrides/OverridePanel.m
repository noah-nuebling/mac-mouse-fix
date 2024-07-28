//
// --------------------------------------------------------------------------
// ScrollOverride.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/*
 Reference:
    Table view programming guide:
        https://www.appcoda.com/macos-programming-tableview/
    Drag and drop for table views:
        https://www.natethompson.io/2019/03/23/nstableview-drag-and-drop.html
    General Drag and drop tutorial:
        https://www.raywenderlich.com/1016-drag-and-drop-tutorial-for-macos
    Uniform Type Identifiers (UTIs) Reference: https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html#//apple_ref/doc/uid/TP40009259-SW1
 */

#import "OverridePanel.h"
#import "Config.h"
#import "Utility_App.h"
#import "NSDictionary+Additions.h"
#import <Foundation/Foundation.h>
//#import "MoreSheet.h"
#import "AppDelegate.h"
#import "Constants.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "Mac_Mouse_Fix-Swift.h"

@interface OverridePanel ()

#pragma mark Outlets

@property (strong) IBOutlet NSTableView *tableView;

@end

@implementation OverridePanel

#pragma mark - Class

+ (void)load {
    _instance = [[OverridePanel alloc] initWithWindowNibName:@"ScrollOverridePanel"];
        // Register for incoming drag and drop operation
}
static OverridePanel *_instance;
+ (OverridePanel *)instance {
    return _instance;
}

#pragma mark - Instance

#pragma mark - Public variables

#pragma mark - Private variables

/// Keys are table column identifiers (These are set through interface builder). Values are keypaths to the values modified by the controls in the column with that identifier.
/// Keypaths relative to config root give default values. Relative to config[kMFConfigKeyAppOverrides][@"[bundle identifier of someApp]"] they give override values for someApp.
NSDictionary *_columnIdentifierToKeyPath;

#pragma mark - Public functions

- (void)begin {
    
    /// Define column-to-setting mapping
    _columnIdentifierToKeyPath = @{
        @"SmoothEnabledColumnID" : @"Scroll.smooth",
        @"MagnificationEnabledColumnID" : @"Scroll.modifierKeys.magnificationScrollModifierKeyEnabled",
        @"HorizontalEnabledColumnID" : @"Scroll.modifierKeys.horizontalScrollModifierKeyEnabled"
    };
    
    /// Load table
    [Config.shared loadConfigFromFileAndRepair];
    [self loadTableViewDataModelFromConfig];
    [_tableView reloadData];

    /// Center window
    [self centerWindowOnMainWindow];
    
    /// Keep this window on top
    self.window.level = NSFloatingWindowLevel;
    
    /// Make window resizable
    self.window.styleMask = self.window.styleMask | NSWindowStyleMaskResizable;
    /// Remove window buttons
    [self.window standardWindowButton:NSWindowCloseButton].hidden = YES;
    [self.window standardWindowButton:NSWindowMiniaturizeButton].hidden = YES;
    [self.window standardWindowButton:NSWindowZoomButton].hidden = YES;
    
    /// Make tableView drag and drop target
    NSString *fileURLUTI = @"public.file-url";
    [_tableView registerForDraggedTypes:@[fileURLUTI]]; // makes it accept apps
    
    /// Display window
    [Utility_App openWindowWithFadeAnimation:self.window fadeIn:YES fadeTime:0.1];
}
- (void)end {
    if (self.window.isVisible) {
        [Utility_App openWindowWithFadeAnimation:self.window fadeIn:NO fadeTime:0.1];
    }
}

- (void)centerWindowOnMainWindow {
    NSPoint ctr = [Utility_App getCenterOfRect:MainAppState.shared.window.frame];
    [Utility_App centerWindow:self.window atPoint:ctr];
}
- (void)windowDidLoad {
    
    // v This solution caused other weird issues. When changing system appearance and then restarting the app, the first column sometimes became incredibly wide.
    //     We fixed the issue by setting the tableView 'Style' to 'Full Width' in IB
    // Resize first column so table columns take up full space of table view
    // We set the size properly in IB, but when the first column had its `Resizing` property set to `Autoresizes with Table` (which we want it to do) then it would always end up a little smaller than the table for some reason
//    NSTableColumn *col = _tableView.tableColumns[0];
//    [col setWidth:col.maxWidth];
}

- (void)setConfigFileToUI {
    [self writeTableViewDataModelToConfig];
    commitConfig();
    [self loadTableViewDataModelFromConfig];
    [_tableView reloadData];
}

#pragma mark TableView

- (IBAction)back:(id)sender {
    [self end];
}
- (IBAction)addRemoveControl:(id)sender {
    if ([sender selectedSegment] == 0) {
        [self addButtonAction];
    } else {
        [self removeButtonAction];
    }
}
- (IBAction)removeButton:(id)sender {
    [self removeButtonAction];
}

- (void)addButtonAction {

    NSOpenPanel* openPanel = [NSOpenPanel openPanel];

    openPanel.canChooseFiles = YES;
    openPanel.canChooseDirectories = NO;
    openPanel.canCreateDirectories = NO; // Doesn't work
    openPanel.allowsMultipleSelection = YES; // Doesn't work :/
    if (@available(macOS 13.0, *)) {
        openPanel.allowedContentTypes = @[[UTType typeWithIdentifier:@"com.apple.application"]];
    } else {
        openPanel.allowedFileTypes = @[@"com.apple.application"];
    }
    openPanel.prompt = @"Choose";
    
    NSString *applicationsFolderPath = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES).firstObject;
    openPanel.directoryURL = [NSURL fileURLWithPath:applicationsFolderPath];
    
    // Display the dialog.
    [openPanel beginSheetModalForWindow:self.window
                    completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) {  // If the OK button was pressed, process the files. Otherwise return.
            return;
        }
        NSArray* urls = [openPanel URLs];
        NSMutableArray* bundleIDs = [NSMutableArray array];
        // Loop through all the files and process them.
        for (NSURL *fileURL in urls) {
            NSString* bundleID = [NSBundle bundleWithURL:fileURL].bundleIdentifier;
            if (bundleID != nil) { /// Some apps just dont' have bundle IDs. TODO: Handle this more gracefully.
                [bundleIDs addObject:bundleID];
            } else {
                NSLog(@"Error in app specific settings: User selected an app without a bundle ID.");
            }
        }
        [self addAppsToTableWithBundleIDs:bundleIDs atRow:0];
    }];
}
- (void)removeButtonAction {
    [_tableViewDataModel removeObjectsAtIndexes:_tableView.selectedRowIndexes];
    [self writeTableViewDataModelToConfig];
    [self loadTableViewDataModelFromConfig]; // Not sure if necessary
    [_tableView removeRowsAtIndexes:_tableView.selectedRowIndexes withAnimation:NSTableViewAnimationSlideUp];
}
- (IBAction)checkBoxInCell:(NSButton *)sender {
    NSInteger state = sender.state;
    NSInteger row = [_tableView rowForView:sender];
    NSInteger column = [_tableView columnForView:sender];
    NSString *columnIdentifier = _tableView.tableColumns[column].identifier;
    
    [_tableViewDataModel[row] setObject: [NSNumber numberWithBool:state] forKey: columnIdentifier];
    [self setConfigFileToUI];
}

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
            NSString *appPath = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:bundleID].path;
//            NSBundle *bundle = [NSBundle bundleWithIdentifier:bundleID]; // This doesn't work for some reason
            NSImage *appIcon;
            NSString *appName;
            if (![Utility_App appIsInstalled:bundleID]) {
                /// User should never see this. We don't want to load uninstalled apps into _tableViewDataModel to begin with.
                appIcon = [NSImage imageNamed:NSImageNameStopProgressFreestandingTemplate];
                appName = [NSString stringWithFormat:@"Couldn't find app: %@", bundleID];
            } else {
                appIcon = [NSWorkspace.sharedWorkspace iconForFile:appPath];
                appName = [[NSBundle bundleWithPath:appPath] objectForInfoDictionaryKey:@"CFBundleName"];
                
                /// Fallbacks
                ///     Starcraft has no name. See https://github.com/noah-nuebling/mac-mouse-fix/issues/241
                if (appName == nil) {
                    if (appPath != nil) {
                        appName = [[NSURL fileURLWithPath:appPath] URLByDeletingPathExtension].lastPathComponent;
                    }
                }
                if (appName == nil) {
                    if (bundleID != nil) {
                        appName = bundleID;
                    }
                }
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

#pragma mark TableView - Drag and drop

// Validate drop
- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    
    NSPasteboard *pasteboard = info.draggingPasteboard;
    
    BOOL droppingAbove = (dropOperation == NSTableViewDropAbove);
    
    BOOL containsURL = [pasteboard.types containsObject:@"public.file-url"];
    NSDictionary *options = @{NSPasteboardURLReadingContentsConformToTypesKey : @[@"com.apple.application-bundle"]};
    BOOL containsApp = [pasteboard canReadObjectForClasses:@[NSURL.self] options:options];
    NSArray<NSString *> *draggedBundleIDs = bundleIDsFromPasteboard(pasteboard);
    if (draggedBundleIDs.count == 0) {
        containsApp = NO; /// Guard: some apps don't have bundle IDs
    }
    
    NSDictionary *draggedBundleIDsSorted = sortByAlreadyInTable(draggedBundleIDs);
    BOOL allAppsAlreadyInTable = (((NSArray *)draggedBundleIDsSorted[@"notInTable"]).count == 0);
    NSMutableArray *tableIndicesOfAlreadyInTable = [((NSArray *)draggedBundleIDsSorted[@"inTable"]) valueForKey:@"tableIndex"];
    
    if (droppingAbove && containsURL && containsApp && !allAppsAlreadyInTable) { // Why do we need containsURL and containsApp?
        return NSDragOperationCopy;
    }
    if (!containsApp) {
        [NSCursor.operationNotAllowedCursor push]; // I can't find a way to reset the cursor when it leaves the tableView
    } else if (allAppsAlreadyInTable) {
        NSMutableIndexSet *tableIndicesOfAlreadyInTable_IndexSet = indexSetFromIndexArray(tableIndicesOfAlreadyInTable);
        [_tableView selectRowIndexes:tableIndicesOfAlreadyInTable_IndexSet byExtendingSelection:NO];
        [_tableView scrollRowToVisible:((NSNumber *)tableIndicesOfAlreadyInTable[0]).integerValue];

    }
    return NSDragOperationNone;
}

// Accept drop
- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    
    NSArray *items = info.draggingPasteboard.pasteboardItems;
    if (!items || items.count == 0) {
        return false;
    }
    row = 0; // Always add items at the top cause it's nice
    
    NSArray<NSString *> * bundleIDs = bundleIDsFromPasteboard(info.draggingPasteboard);
    [self addAppsToTableWithBundleIDs:bundleIDs atRow:row];
    
    [self.window makeKeyWindow]; // Doesn't seem to work
    // ^ After dropping you probably wanna interact with the window to set app specific settings. Also helps seing the blue selected rows.
    
    return true;
}

- (void)addAppsToTableWithBundleIDs:(NSArray<NSString *> *)bundleIDs atRow:(NSInteger)row {
    
    NSMutableArray *newRows = [NSMutableArray array];
    bundleIDs = [bundleIDs valueForKeyPath:@"@distinctUnionOfObjects.self"]; /// Remove duplicates. This is only necessary when the user drags and drops in more than one app with the same bundleID.
    NSDictionary *bundleIDsSorted = sortByAlreadyInTable(bundleIDs);
    
    for (NSString *bundleID in bundleIDsSorted[@"notInTable"]) {
        NSMutableDictionary *newRow = [NSMutableDictionary dictionary];
        /// Fill out new row with bundle ID and default values
        newRow[@"AppColumnID"] = bundleID;
        for (NSString *columnID in _columnIdentifierToKeyPath) {
            NSString *keyPath = _columnIdentifierToKeyPath[columnID];
            NSObject *defaultValue = [Config.shared.config objectForCoolKeyPath:keyPath]; /// Could use valueForKeyPath as well, because there are no periods in the keys of the keyPath
            newRow[columnID] = defaultValue;
        }
        [newRows addObject:newRow];
    }
    
    NSIndexSet *newRowsIndices = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row, ((NSArray *)bundleIDsSorted[@"notInTable"]).count)];
    NSIndexSet *alreadyInTableRowsIndices = indexSetFromIndexArray(
                                                                   [((NSArray *)bundleIDsSorted[@"inTable"]) valueForKey:@"tableIndex"]
                                                                   );
    
    [_tableView selectRowIndexes:alreadyInTableRowsIndices byExtendingSelection:NO];
    
    [_tableViewDataModel insertObjects:newRows atIndexes:newRowsIndices];
    [self writeTableViewDataModelToConfig];
    [self loadTableViewDataModelFromConfig]; // At the time of writing: not necessary. Not sure if useful. Might make things more robust, if we run all of the validity checks in `loadTableViewDataModelFromConfig` again.
    NSTableViewAnimationOptions animation = NSTableViewAnimationSlideDown;
    
    [_tableView insertRowsAtIndexes:newRowsIndices withAnimation:animation];
    [_tableView selectRowIndexes:newRowsIndices byExtendingSelection:YES];
    if (newRowsIndices.count > 0) {
        [_tableView scrollRowToVisible:newRowsIndices.firstIndex];
    } else {
        [_tableView scrollRowToVisible:alreadyInTableRowsIndices.firstIndex];
    }
}

#pragma mark - Private functions

NSMutableArray *_tableViewDataModel;

- (void)writeTableViewDataModelToConfig {
    
    NSMutableSet *bundleIDsInTable = [NSMutableSet set];
    /// Write table data into config
    int orderKey = 0;
    for (NSMutableDictionary *rowDict in _tableViewDataModel) {
        NSString *bundleID = rowDict[@"AppColumnID"];
        [bundleIDsInTable addObject:bundleID];
        NSString *bundleIDEscaped = [bundleID stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
        [rowDict removeObjectsForKeys:@[@"AppColumnID", @"orderKey"]]; /// So we don't iterate over this in the loop below
        /// Write override values
        for (NSString *columnID in rowDict) {
            NSObject *cellValue = rowDict[columnID];
            NSString *defaultKeyPath = _columnIdentifierToKeyPath[columnID];
            NSString *overrideKeyPath = [NSString stringWithFormat:@"AppOverrides.%@.Root.%@", bundleIDEscaped, defaultKeyPath];
            [Config.shared.config setObject:cellValue forCoolKeyPath:overrideKeyPath];
        }
        /// Write order key
        NSString *orderKeyKeyPath = [NSString stringWithFormat:@"AppOverrides.%@.meta.scrollOverridePanelTableViewOrderKey", bundleIDEscaped];
        [Config.shared.config setObject:[NSNumber numberWithInt:orderKey] forCoolKeyPath:orderKeyKeyPath];
        orderKey += 1;
    }
    
    /// For all overrides for apps in the config, which aren't in the table, and which are installed - delete all values managed by the table from the config
    
    NSMutableSet *bundleIDsInConfigAndInstalledButNotInTable = [NSMutableSet setWithArray:((NSDictionary *)[Config.shared.config valueForKeyPath:kMFConfigKeyAppOverrides]).allKeys]; // Get all bundle IDs in the config
    
    bundleIDsInConfigAndInstalledButNotInTable = [bundleIDsInConfigAndInstalledButNotInTable filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [Utility_App appIsInstalled:evaluatedObject];
    }]].mutableCopy; // Filter out apps which aren't installed. We do this so we don't delete preinstalled overrides.
    [bundleIDsInConfigAndInstalledButNotInTable minusSet:bundleIDsInTable]; // Subtract apps in table
    
    for (NSString *bundleID in bundleIDsInConfigAndInstalledButNotInTable) {
        NSString *bundleIDEscaped = [bundleID stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
        /// Delete override values
        for (NSString *rootKeyPath in _columnIdentifierToKeyPath.allValues) {
        NSString *overrideKeyPath = [NSString stringWithFormat:@"AppOverrides.%@.Root.%@", bundleIDEscaped, rootKeyPath];
        [Config.shared.config setObject:nil forCoolKeyPath:overrideKeyPath];
        }
        /// Delete orderKey
        NSString *orderKeyKeyPath = [NSString stringWithFormat:@"AppOverrides.%@.meta.scrollOverridePanelTableViewOrderKey", bundleIDEscaped];
        [Config.shared.config setObject:nil forCoolKeyPath:orderKeyKeyPath];
    }
    
    [Config.shared cleanConfig];
    commitConfig();
}

- (void)loadTableViewDataModelFromConfig {
    _tableViewDataModel = [NSMutableArray array];
    NSDictionary *config = Config.shared.config;
    if (!config) { // TODO: does this exception make sense? What is the consequence of it being thrown? Where is it caught? Should we just reload the config file instead? Can this even happen if the Config class successfully loaded?
        NSException *configNotLoadedException = [NSException exceptionWithName:@"ConfigNotLoadedException" reason:@"Config class' config property is nil" userInfo:nil];
        @throw configNotLoadedException;
        return;
    }
    NSDictionary *overrides = config[kMFConfigKeyAppOverrides];
    if (!overrides) {
        DDLogInfo(@"No overrides found in config while generating scroll override table data model.");
        return;
    }
    for (NSString *bundleID in overrides.allKeys) { /// Every bundleID corresponds to one app/row
        /// Check if app exists on system
        if (![Utility_App appIsInstalled:bundleID]) {
            continue; // If not, skip this bundleID
        }
        /// Create rowDict for app with `bundleID` from data in config. Every key value pair in rowDict corresponds to a column. The key is the columnID and the value is the value for the column with `columnID` and the row of the app with `bundleID`
        NSMutableDictionary *rowDict = [NSMutableDictionary dictionary];
        NSArray *columnIDs = _columnIdentifierToKeyPath.allKeys;
        for (NSString *columnID in columnIDs) {
            NSString *keyPath = _columnIdentifierToKeyPath[columnID];
            NSObject *value = [overrides[bundleID][@"Root"] valueForKeyPath:keyPath];
            rowDict[columnID] = value; // If value is nil, no entry is added. (We use this fact in the allNil / someNil checks below)
        }
        /// Check existence / validity of generated rowDict
        BOOL allNil = (rowDict.allValues.count == 0);
        BOOL someNil = (rowDict.allValues.count < columnIDs.count);
        if (allNil) { /// None of the values controlled by the table exist for this app in config
            continue; /// Don't add this app to the table
        }
        if (someNil) { /// Only some of the values controlled by the table don't exist in this AppOverride
            /// Fill out missing values with default ones
            [Config.shared repairConfigWithReason:kMFConfigRepairReasonIncompleteAppOverride info:@{
                    @"bundleID": bundleID,
                    @"relevantKeyPaths": _columnIdentifierToKeyPath.allValues,
            }];
            [self loadTableViewDataModelFromConfig]; /// Restart the whole function. someNil will not occur next time because we filled out all the AppOverrides with some values missing.
            return;
        }
        /// Add everything thats not an override last, so the allNil check works properly
        rowDict[@"AppColumnID"] = bundleID; /// Not sure if the key `AppColumnID` makes sense here. Maybe it should be `bundleID` instead.
        rowDict[@"orderKey"] = overrides[bundleID][@"meta"][@"scrollOverridePanelTableViewOrderKey"];
        
        [_tableViewDataModel addObject:rowDict];
    }
    /// Sort `_tableViewDataModel` by orderKey
    NSSortDescriptor *sortDesc = [NSSortDescriptor sortDescriptorWithKey:@"orderKey" ascending:YES];
    [_tableViewDataModel sortUsingDescriptors:@[sortDesc]];
}

#pragma mark Utility

static NSArray<NSString *> * bundleIDsFromPasteboard(NSPasteboard *pasteboard) {
    NSArray *items = pasteboard.pasteboardItems;
    NSMutableArray *bundleIDs = [NSMutableArray arrayWithCapacity:items.count];
    for (NSPasteboardItem *item in items) {
        NSString *urlString = [item stringForType:@"public.file-url"];
        NSURL *url = [NSURL URLWithString:urlString];
        NSString *bundleID = [[NSBundle bundleWithURL:url] bundleIdentifier];
        if (bundleID) { // Adding nil to NSArray with `addObject:` yields a crash
            [bundleIDs addObject:bundleID];
        }
    }
    return bundleIDs;
}

static NSDictionary *sortByAlreadyInTable(NSArray *bundleIDs) {
    NSArray *bundleIDsFromTable = [_tableViewDataModel valueForKey:@"AppColumnID"];
    NSMutableArray<NSString *> *inpNotInTable = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *inpInTable = [NSMutableArray array];
    for (NSString *bundleID in bundleIDs) {
        if ([bundleIDsFromTable containsObject:bundleID]) {
            [inpInTable addObject:@{
                @"id": bundleID,
                @"tableIndex": [NSNumber numberWithUnsignedInteger:[bundleIDsFromTable indexOfObject:bundleID]]
            }];
        } else {
            [inpNotInTable addObject:bundleID];
        }
    }
    return @{
        @"inTable": inpInTable,
        @"notInTable": inpNotInTable
    };
}
static NSMutableIndexSet *indexSetFromIndexArray(NSArray<NSNumber *> *arrayOfIndices) {
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    for (NSNumber *index in arrayOfIndices) {
        [indexSet addIndex:index.unsignedIntegerValue];
    }
    return indexSet;
}


@end
