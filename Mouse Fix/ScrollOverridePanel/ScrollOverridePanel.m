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
    
    // Make tableView drag and drop target
    
    NSString *fileURLUTI = @"public.file-url";
    [_tableView registerForDraggedTypes:@[fileURLUTI]]; // makes it accept apps
    [_tableView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
}

- (void)setConfigFileToUI {
    [self writeTableViewDataModelToConfig];
    [ConfigFileInterface_PrefPane writeConfigToFileAndNotifyHelper];
    [self loadTableViewDataModelFromConfig];
    [_tableView reloadData];
}
#pragma mark TableView

- (IBAction)reloadButton:(id)sender {
    [ConfigFileInterface_PrefPane loadConfigFromFile];
    [self loadTableViewDataModelFromConfig];
    [_tableView beginUpdates];
    [_tableView reloadData];
    [_tableView endUpdates];    
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

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    
    NSPasteboard *pb = info.draggingPasteboard;
    NSDictionary *options = @{NSPasteboardURLReadingContentsConformToTypesKey : @[@"com.apple.application-bundle"]};
    BOOL URLRefersToApp = [pb canReadObjectForClasses:@[NSURL.self] options:options];
    BOOL droppingAbove = (dropOperation == NSTableViewDropAbove);
    BOOL accept = droppingAbove && URLRefersToApp;
    if (accept) {
        return NSDragOperationMove;
    }
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    
    NSArray *items = info.draggingPasteboard.pasteboardItems;
    if (!items) {
        return false;
    }
//    [_tableViewDataModel insertObjects: atIndexes:<#(nonnull NSIndexSet *)#>]
    return true;
}

// Dragging source functions

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

@end
