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
    General Drag and drop tutorial:
        https://www.raywenderlich.com/1016-drag-and-drop-tutorial-for-macos
    Uniform Type Identifiers (UTIs) Reference: https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html#//apple_ref/doc/uid/TP40009259-SW1
 */

#import "ScrollOverridePanel.h"
#import "ConfigFileInterface_PrefPane.h"
#import "Utility_PrefPane.h"
#import "NSMutableDictionary+Additions.h"
#import <Foundation/Foundation.h>
#import "MoreSheet.h"

@interface ScrollOverridePanel ()

#pragma mark Outlets

@property (strong) IBOutlet NSTableView *tableView;

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
    
//    self.window.movableByWindowBackground = YES;
    
    // Make tableView drag and drop target
    
    NSString *fileURLUTI = @"public.file-url";
//    NSString *tableRowType = @"com.nuebling.mousefix.table-row";
    [_tableView registerForDraggedTypes:@[fileURLUTI]]; // makes it accept apps, and table rows
//    [_tableView setDraggingSourceOperationMask:NSDragOperationDelete forLocal:NO];
    [_tableView setDraggingSourceOperationMask:NSDragOperationDelete forLocal:NO];
    [_tableView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:YES];
//    [_tableView setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
}

- (void)windowWillClose:(NSNotification *)notification {
//    dispatch_after(0.3, dispatch_get_main_queue(), ^{
//        [MoreSheet.instance end];
//    });
}

- (void)setConfigFileToUI {
    [self writeTableViewDataModelToConfig];
    [ConfigFileInterface_PrefPane writeConfigToFileAndNotifyHelper];
    [self loadTableViewDataModelFromConfig];
    [_tableView reloadData];
}
#pragma mark TableView

/// Was for testing. Not used anymore.
- (IBAction)reloadButton:(id)sender {
    [ConfigFileInterface_PrefPane loadConfigFromFile];
    [self loadTableViewDataModelFromConfig];
    [_tableView beginUpdates];
    [_tableView reloadData];
    [_tableView endUpdates];
}
- (IBAction)addButton:(id)sender {

    NSOpenPanel* openDlg = [NSOpenPanel openPanel];

    openDlg.canChooseFiles = YES;
    openDlg.canChooseDirectories = NO;
    openDlg.canCreateDirectories = NO; // Doesn't work
    openDlg.allowsMultipleSelection = YES; // Doesn't work :/
    openDlg.allowedFileTypes = @[@"com.apple.application"];
    openDlg.prompt = @"Choose";
    
    NSString *applicationsFolderPath = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES).firstObject;
    openDlg.directoryURL = [NSURL fileURLWithPath:applicationsFolderPath];
    
    // Display the dialog.
    [openDlg beginSheetModalForWindow:self.window
                    completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) {  // If the OK button was pressed, process the files. Otherwise return.
            return;
        }
        NSArray* urls = [openDlg URLs];
        NSMutableArray* bundleIDs = [NSMutableArray array];
        // Loop through all the files and process them.
        for (NSURL *fileURL in urls) {
            NSString* bundleID = [NSBundle bundleWithURL:fileURL].bundleIdentifier;
            [bundleIDs addObject:bundleID];
            // Do something with the filename.
        }
        [self tableAddAppsWithBundleIDs:bundleIDs atRow:0];
    }];
}
- (IBAction)removeButton:(id)sender {
    [_tableViewDataModel removeObjectsAtIndexes:_tableView.selectedRowIndexes];
    [self writeTableViewDataModelToConfig]; // TODO: This doesn't actually remove anything from the config file
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

#pragma mark TableView - Drag and drop

// Dragging destination functions

//- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
//    NSLog(@"DRAGGING ENTERED");
//    return NSDragOperationCopy;
//}

static NSMutableIndexSet *indexSetFromIndexArray(NSMutableArray *tableIndicesOfAlreadyInTable) {
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    for (NSNumber *index in tableIndicesOfAlreadyInTable) {
        [indexSet addIndex:index.unsignedIntegerValue];
    }
    return indexSet;
}

// Validate drop
- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    
    NSPasteboard *pasteboard = info.draggingPasteboard;
    
    BOOL droppingAbove = (dropOperation == NSTableViewDropAbove);
    
//    BOOL isTableRow = [pasteboard.types containsObject:@"com.nuebling.mousefix.table-row"];
//    if (isTableRow) {
//        NSArray *plist = [pasteboard.pasteboardItems[0] propertyListForType:@"com.nuebling.mousefix.table-row"];
//        NSInteger srcRow = ((NSNumber *)plist[0]).integerValue;
//        if (droppingAbove) {// && !(srcRow <= row && row <= srcRow + 1)) {
//            return NSDragOperationMove;
//        }
//        return NSDragOperationNone;
//    }
    
    BOOL isURL = [pasteboard.types containsObject:@"public.file-url"];
    NSDictionary *options = @{NSPasteboardURLReadingContentsConformToTypesKey : @[@"com.apple.application-bundle"]};
    BOOL URLRefersToApp = [pasteboard canReadObjectForClasses:@[NSURL.self] options:options];
    
    NSArray<NSString *> *draggedBundleIDs = bundleIDsFromPasteboard(pasteboard);
    
    NSDictionary *draggedBundleIDsSorted = sortByAlreadyInTable(draggedBundleIDs);
    BOOL allAlreadyInTable = (((NSArray *)draggedBundleIDsSorted[@"notInTable"]).count == 0);
    NSMutableArray *tableIndicesOfAlreadyInTable = [((NSArray *)draggedBundleIDsSorted[@"inTable"]) valueForKey:@"tableIndex"];
    
//    NSMutableSet *bundleIDsInTable = [NSMutableSet set];
//    for (NSDictionary *row in _tableViewDataModel) {
//        // The following is probably bs, I just need to remove rows properly
//        // TODO: ! This misbehaves when there are overrides for an app, but they are not represented in this table. Should maybe make a function `overridesRelevantForScrollOverrideTableViewExistForApp:`. Should then also use this function in other places where we do the same thing like. I can think of the `someNil` check.
//        NSString *rowBundleID = row[@"AppColumnID"];
//        [bundleIDsInTable addObject:rowBundleID];
//    }
//
//
//    if ([draggedBundleIDs isSubsetOfSet:bundleIDsInTable]) {
//        alreadyInTable = YES;
////        rowsOfAlreadyInTable =
//    }
    
//    if ([rowBundleID isEqualToString:draggedBundleID]) {
//        alreadyInTable = YES;
//        rowOfAlreadyInTable = [_tableViewDataModel indexOfObject:row];
//        break;
//    }
    
    NSMutableIndexSet * indexSet = indexSetFromIndexArray(tableIndicesOfAlreadyInTable);
    [_tableView selectRowIndexes:indexSet byExtendingSelection:NO];
    
    if (droppingAbove && isURL && URLRefersToApp && !allAlreadyInTable) {
        return NSDragOperationCopy;
    }
    if (allAlreadyInTable) {
        [NSCursor.operationNotAllowedCursor push]; // I can't find a way to reset the cursor when it leaves the tableView
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
    
    if ([info.draggingPasteboard.types containsObject:@"com.nuebling.mousefix.table-row"]) {
        
//        NSArray *plist = [items[0] propertyListForType:@"com.nuebling.mousefix.table-row"];
//        NSInteger srcRow = ((NSNumber *)plist[0]).integerValue;
//        if (srcRow <= row && row <= srcRow + 1) {
//            return false;
//        }
//
//        NSDictionary *srcRowObj = _tableViewDataModel[srcRow];
////        NSDictionary *rowObj = _tableViewDataModel[row];
//
//        [_tableViewDataModel insertObject:srcRowObj atIndex:row];
//        if (row < srcRow) {
//            [_tableViewDataModel removeObjectAtIndex:srcRow + 1];
//            [self writeTableViewDataModelToConfig];
//            [self loadTableViewDataModelFromConfig];
//            [_tableView moveRowAtIndex:srcRow toIndex:row];
//        } else {
//            [_tableViewDataModel removeObjectAtIndex:srcRow];
//            [self writeTableViewDataModelToConfig];
//            [self loadTableViewDataModelFromConfig];
//            [_tableView moveRowAtIndex:srcRow toIndex:row - 1];
//        }
//
//         return true;
    } else {
        // Retrieve bundleID of dragged app
        
        row = 0; //
//        [_tableView scrollRowToVisible:row];
        
        NSArray<NSString *> * bundleIDs = bundleIDsFromPasteboard(info.draggingPasteboard);
        [self tableAddAppsWithBundleIDs:bundleIDs atRow:row];
        
        [self.window makeKeyWindow];
        
        return true;
    }
    return false;
}

- (void)tableAddAppsWithBundleIDs:(NSArray<NSString *> *)bundleIDs atRow:(NSInteger)row {
    
    NSMutableArray *newRows = [NSMutableArray array];
    NSDictionary *bundleIDsSorted = sortByAlreadyInTable(bundleIDs);
    
    for (NSString *bundleID in bundleIDsSorted[@"notInTable"]) {
        NSMutableDictionary *newRow = [NSMutableDictionary dictionary];
        // Fill out new row with bundle ID and default values
        newRow[@"AppColumnID"] = bundleID;
        for (NSString *columnID in _columnIdentifierToKeyPath) {
            NSString *keyPath = _columnIdentifierToKeyPath[columnID];
            NSObject *defaultValue = [ConfigFileInterface_PrefPane.config objectForCoolKeyPath:keyPath]; // Could use valueForKeyPath as well, because there are no periods in the keys of the keyPath
            newRow[columnID] = defaultValue;
        }
        [newRows addObject:newRow];
    }
    
    NSIndexSet *newRowsIndices = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row, ((NSArray *)bundleIDsSorted[@"notInTable"]).count)];
    NSIndexSet *alreadyInTableRowsIndices = indexSetFromIndexArray(
                                                                   [((NSArray *)bundleIDsSorted[@"inTable"]) valueForKey:@"tableIndex"]
                                                                   );
    
    [_tableView selectRowIndexes:alreadyInTableRowsIndices byExtendingSelection:NO];
    
    // Moving the rows which were already in the tableView under the newly added ones (Only makes sense because we're always adding new rows to the top of the table)
    //        NSArray *alreadyInTableRows = [_tableViewDataModel objectsAtIndexes:alreadyInTableRowsIndices];
    //        [_tableViewDataModel removeObjectsAtIndexes:alreadyInTableRowsIndices];
    //        [_tableViewDataModel insertObjects:alreadyInTableRows atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, alreadyInTableRowsIndices.count)]];
    
    [_tableViewDataModel insertObjects:newRows atIndexes:newRowsIndices];
    [self writeTableViewDataModelToConfig];
    [self loadTableViewDataModelFromConfig]; // At the time of writing: not necessary. Not sure if useful. Might make things more robust, if we run all of the validity checks in `loadTableViewDataModelFromConfig` again.
    NSTableViewAnimationOptions animation = NSTableViewAnimationSlideDown;
    
    [_tableView insertRowsAtIndexes:newRowsIndices withAnimation:animation];
    
    // This causes some weird bug where row backrounds aren't alternating
    //        // Only makes sense because we're always adding new rows to the top of the table and shift rows for apps that are already in the table to the top as well.
    //        [tableView removeRowsAtIndexes:alreadyInTableRowsIndices withAnimation:NSTableViewAnimationSlideUp];
    //        [tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, bundleIDs.count)] withAnimation:animation];
    
    [_tableView selectRowIndexes:newRowsIndices byExtendingSelection:YES];
    
    if (newRowsIndices.count > 0) {
        [_tableView scrollRowToVisible:newRowsIndices.firstIndex];
    } else {
        [_tableView scrollRowToVisible:alreadyInTableRowsIndices.firstIndex];
    }
}

static NSDictionary * sortByAlreadyInTable(NSArray *bundleIDs) {
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

// Dragging source functions

//- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
//    NSPasteboardItem *item = [[NSPasteboardItem alloc] init];
//    NSNumber *rowNS = [NSNumber numberWithInteger:row];
//    [item setPropertyList:@[rowNS] forType:@"com.nuebling.mousefix.table-row"];
////    return item;
//    return NSColor.blackColor;
//}

//- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
//    pboard.
//}

//- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
//    NSLog(@"Dragging Operation: %lu", (unsigned long)operation);
//}

//- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation

//- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes {
//    NSTimer *timer = [NSTimer timerWithTimeInterval:0.3 target:self selector:@selector(dragToRemoveTimerFired:) userInfo:rowIndexes repeats:NO];
//    [NSRunLoop.currentRunLoop addTimer:timer forMode:NSDefaultRunLoopMode];
//}
//- (void)dragToRemoveTimerFired:(NSTimer *)timer {
//    [NSCursor.disappearingItemCursor push];
//}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    [NSCursor.closedHandCursor push];
    return NSDragOperationDelete;
}
- (void)tableView:(NSTableView *)tableView updateDraggingItemsForDrag:(id<NSDraggingInfo>)draggingInfo {
    
    if (draggingInfo.draggingDestinationWindow != self.window) {
        
    } else {
        
    }
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
    
}

- (void)mouseExited:(NSEvent *)event {
    
}

// Other functions
static NSArray<NSString *> * bundleIDsFromPasteboard(NSPasteboard *pasteboard) {
    NSArray *items = pasteboard.pasteboardItems;
    NSMutableArray *bundleIDs = [NSMutableArray arrayWithCapacity:items.count];
    for (NSPasteboardItem *item in items) {
        NSString *urlString = [item stringForType:@"public.file-url"];
        NSURL *url = [NSURL URLWithString:urlString];
        NSString *bundleID = [[NSBundle bundleWithURL:url] bundleIdentifier];
        if (bundleID) { // Adding nil to NSArray with addObject: yields a crash
            [bundleIDs addObject:bundleID];
        }
    }
//    NSURL *url = [NSURL URLFromPasteboard:pasteboard];
    return bundleIDs;
}


#pragma mark - Private functions

NSMutableArray *_tableViewDataModel;

- (void)writeTableViewDataModelToConfig {
    
    NSMutableSet *bundleIDsInTable = [NSMutableSet set];
    // Write table data into config
    int orderKey = 0;
    for (NSMutableDictionary *rowDict in _tableViewDataModel) {
        NSString *bundleID = rowDict[@"AppColumnID"];
        [bundleIDsInTable addObject:bundleID];
        NSString *bundleIDEscaped = [bundleID stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
        [rowDict removeObjectsForKeys:@[@"AppColumnID", @"orderKey"]]; // So we don't iterate over this in the loop below
        // Write override values
        for (NSString *columnID in rowDict) {
            NSObject *cellValue = rowDict[columnID];
            NSString *defaultKeyPath = _columnIdentifierToKeyPath[columnID];
            NSString *overrideKeyPath = [NSString stringWithFormat:@"AppOverrides.%@.Root.%@", bundleIDEscaped, defaultKeyPath];
            [ConfigFileInterface_PrefPane.config setObject:cellValue forCoolKeyPath:overrideKeyPath];
        }
        // Write order key
        NSString *orderKeyKeyPath = [NSString stringWithFormat:@"AppOverrides.%@.meta.scrollOverridePanelTableViewOrderKey", bundleIDEscaped];
        [ConfigFileInterface_PrefPane.config setObject:[NSNumber numberWithInt:orderKey] forCoolKeyPath:orderKeyKeyPath];
        orderKey += 1;
    }
    
    // For all overrides for apps in the config, which aren't in the table, delete all values managed by the table from the config
    
    NSMutableSet *bundleIDsInConfigButNotInTable = [NSMutableSet setWithArray:((NSDictionary *)[ConfigFileInterface_PrefPane.config valueForKeyPath:@"AppOverrides"]).allKeys]; // Get all bundle IDs in the config
    [bundleIDsInConfigButNotInTable minusSet:bundleIDsInTable]; // subtract the ones from the table
    for (NSString *bundleID in bundleIDsInConfigButNotInTable) {
        NSString *bundleIDEscaped = [bundleID stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
        // Delete override values
        for (NSString *rootKeyPath in _columnIdentifierToKeyPath.allValues) {
        NSString *overrideKeyPath = [NSString stringWithFormat:@"AppOverrides.%@.Root.%@", bundleIDEscaped, rootKeyPath];
        [ConfigFileInterface_PrefPane.config setObject:nil forCoolKeyPath:overrideKeyPath];
        }
        // Delete orderKey
        NSString *orderKeyKeyPath = [NSString stringWithFormat:@"AppOverrides.%@.meta.scrollOverridePanelTableViewOrderKey", bundleIDEscaped];
        [ConfigFileInterface_PrefPane.config setObject:nil forCoolKeyPath:orderKeyKeyPath];
    }
    
    
    [ConfigFileInterface_PrefPane writeConfigToFileAndNotifyHelper];
}

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
            NSObject *value = [overrides[bundleID][@"Root"] valueForKeyPath:keyPath];
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
        rowDict[@"orderKey"] = overrides[bundleID][@"meta"][@"scrollOverridePanelTableViewOrderKey"];
        
        [_tableViewDataModel addObject:rowDict];
    }
    // Sort _tableViewDataModel by orderKey
    NSSortDescriptor *sortDesc = [NSSortDescriptor sortDescriptorWithKey:@"orderKey" ascending:YES];
    [_tableViewDataModel sortUsingDescriptors:@[sortDesc]];
}

@end
