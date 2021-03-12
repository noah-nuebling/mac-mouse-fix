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
#import "Constants.h"
#import "Utility_App.h"
#import "NSArray+Additions.h"
#import "SharedUtility.h"
#import "AddWindowController.h"

@interface RemapTableController ()
@property NSTableView *tableView;
@property NSMutableArray *dataModel;
@end

@implementation RemapTableController

// Setup the `tableView` property
- (NSTableView *)tableView {
    return (NSTableView *)self.view;
}
- (void)setTableView:(NSTableView *)tableView {
    self.view = tableView;
}

// Methods

- (void)loadDataModelFromConfig {
    [ConfigFileInterface_App loadConfigFromFile]; // Not sure if necessary
    _dataModel = ConfigFileInterface_App.config[kMFConfigKeyRemaps];
}
- (void)writeDataModelToConfig {
    [ConfigFileInterface_App.config setObject:_dataModel forKey:kMFConfigKeyRemaps];
    [ConfigFileInterface_App writeConfigToFileAndNotifyHelper];
}

// IBActions
- (IBAction)addRemoveControl:(id)sender {
    if ([sender selectedSegment] == 0) {
        [self addButtonAction];
    } else {
        [self removeButtonAction];
    }
}

- (void)addButtonAction {
    [AddWindowController begin];
}
- (void)removeButtonAction {
    [self.dataModel removeObjectsAtIndexes:self.tableView.selectedRowIndexes];
    [self writeDataModelToConfig];
    [self loadDataModelFromConfig]; // Not sure if necessary
    [self.tableView removeRowsAtIndexes:self.tableView.selectedRowIndexes withAnimation:NSTableViewAnimationSlideUp];
}

- (IBAction)setConfigToUI:(id)sender {
    // Set popupbutton content to datamodel
    for (NSInteger row = 0; row < self.dataModel.count; row++) {
        // Get effect dicts
        NSTableCellView *cell = [self.tableView viewAtColumn:1 row:row makeIfNecessary:YES];
        NSPopUpButton *pb = cell.subviews[0];
        NSString *selectedTitle = pb.selectedItem.title;
        // Get effects table for row of sender
        NSArray *effectsTable = [self getEffectsTableForRowDict:self.dataModel[row]];
        NSDictionary *effectsTableEntryForSelected = [self getEntryFromEffectsTable:effectsTable withUIString:selectedTitle];
        NSDictionary *effectDictForSelected = effectsTableEntryForSelected[@"dict"];
        // Write effect dict to data model and then write datamodel to file
        _dataModel[row][kMFRemapsKeyEffect] = effectDictForSelected;
    }
    // Write datamodel to file
    [self writeDataModelToConfig];
}

- (void)viewDidLoad { // Not getting called for some reason -> I had to set the view outlet of the controller object in IB to the tableView
    // Set corner radius
    NSScrollView *scrollView = (NSScrollView *)self.view.superview.superview;
    scrollView.wantsLayer = TRUE;
//    scrollView.layer.cornerRadius = 5;
    // Load table data from config
    [self loadDataModelFromConfig];
}

#pragma mark - Generate Table content

#pragma mark Define Effects Tables
// ^ Effects tables are one-to-one mappings between UI stirngs and effect dicts. The effect dicts encode the exact effect in a way the helper can read
// They are used to generate the popup button menus and relate between the data model (which contains effectDicts) and the UI (which contains UI stirngs)
// Effects tables are arrays of dictionaries called effect table entries. Table entries currently support the folling keys:
//  "ui" - The main UI string of the effect. This will be the title of the popupbutton-menu-item for the effect
//  "tool" - Tooltip of the popupbutton-menu-item
//  "dict" - The effect dict
//  "alternate" - If set to @YES, this entry will revealed by pressing a modifier key in the popupbutton menu
// ? TODO: Create constants for these keys
// There are also separatorTableEntry()s which become a separator in the popupbutton-menu generated from the effectsTable
// There are 3 different effectsTables for 3 different types of triggers

static NSDictionary *separatorTableEntry() {
    return @{@"noeffect": @"separator"};
}
static NSArray *getScrollEffectsTable() {
    NSArray *scrollEffectsTable = @[
        @{@"ui": @"Zoom in or out", @"tool": @"Zoom in or out in Safari, Maps, and other apps \nWorks like Pinch to Zoom on an Apple Trackpad" , @"dict": @{}
        },
        @{@"ui": @"Horizontal scroll", @"tool": @"Scroll horizontally \nNavigate pages in Safari, delete messages in Mail, and more \nWorks like swiping horizontally with 2 fingers on an Apple Trackpad" , @"dict": @{}
        },
//        @{@"ui": @"Rotate", @"tool": @"", @"dict": @{}},
//        @{@"ui": @"Precision Scroll", @"tool": @"", @"dict": @{}},
//        @{@"ui": @"Fast scroll", @"tool": @"", @"dict": @{}},
    ];
    return scrollEffectsTable;
}
static NSArray *getDragEffectsTable() {
    NSArray *dragEffectsTable = @[
        @{@"ui": @"Mission Control & Spaces", @"tool": @"Move your mouse: \n - up to show Mission Control \n - down to show App Exposé \n - left/right to move between Spaces" , @"dict": @{
                  kMFModifiedDragDictKeyType: kMFModifiedDragTypeThreeFingerSwipe,
        }},
//        @{@"ui": @"Scroll & navigate pages", @"tool": @"Scroll by moving your mouse in any direction \nNavigate pages in Safari, delete messages in Mail, and more, by moving your mouse horizontally \nWorks like swiping with 2 fingers on an Apple Trackpad" , @"dict": @{
//                  kMFModifiedDragDictKeyType: kMFModifiedDragTypeTwoFingerSwipe,
//        }},
        separatorTableEntry(),
        @{@"ui": [NSString stringWithFormat:@"Click and Drag %@", getButtonString(3)],
          @"tool": [NSString stringWithFormat: @"Simulates clicking and dragging %@ \nUsed to rotate in some 3d software like Blender", getButtonStringToolTip(3)] ,
          @"dict": @{
                  kMFModifiedDragDictKeyType: kMFModifiedDragTypeFakeDrag,
                  kMFModifiedDragDictKeyFakeDragVariantButtonNumber: @3,
        }},
    ];
    return dragEffectsTable;
}
static NSArray *getOneShotEffectsTable(NSDictionary *buttonTriggerDict) {
    NSMutableArray *oneShotEffectsTable = @[
        @{@"ui": @"Mission Control", @"tool": @"Show Mission Control", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHMissionControl)
        }},
        @{@"ui": @"App Exposé", @"tool": @"Show all windows of the active app", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHAppExpose)
        }},
        @{@"ui": @"Show Desktop", @"tool": @"Show the desktop", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHShowDesktop)
        }},
        separatorTableEntry(),
        @{@"ui": @"Move left a Space", @"tool": @"Move one Space to the left", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHMoveLeftASpace)
        }},
        @{@"ui": @"Move right a Space", @"tool": @"Move one Space to the right", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHMoveRightASpace)
        }},
        separatorTableEntry(),
        @{@"ui": @"Back", @"tool": @"Go back \nWorks like a horizontal three finger swipe on an Apple Trackpad if \"System Preferences\" → \"Trackpad\" → \"More Gestures\" → \"Swipe between pages\" is set to \"Swipe with three fingers\"", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeNavigationSwipe,
                  kMFActionDictKeyGenericVariant: kMFNavigationSwipeVariantLeft
        }},
        @{@"ui": @"Forward", @"tool": @"Go forward \nWorks like a horizontal three finger swipe on an Apple Trackpad if \"System Preferences\" → \"Trackpad\" → \"More Gestures\" → \"Swipe between pages\" is set to \"Swipe with three fingers\"", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeNavigationSwipe,
                  kMFActionDictKeyGenericVariant: kMFNavigationSwipeVariantRight
        }},
        separatorTableEntry(),
        @{@"ui": @"Launchpad", @"tool": @"Open Launchpad", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHLaunchpad)
        }},
        separatorTableEntry(),
        @{@"ui": @"Look Up", @"tool": @"Look up words in the Dictionary, Quick Look files in Finder, and more... \nWorks like Force Touch on an Apple Trackpad", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHLookUp)
        }},
        @{@"ui": @"Smart Zoom", @"tool": @"Zoom in and out in Safari and other apps \nSimulates a two-finger double tap on an Apple Trackpad", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSmartZoom,
        }},
        @{@"ui": @"Open link in new tab",
          @"tool": [NSString stringWithFormat:@"Open Links in a new tab, paste text in the Terminal, and more... \nSimulates clicking %@ on a standard mouse", getButtonStringToolTip(3)],
          @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeMouseButtonClicks,
                  kMFActionDictKeyMouseButtonClicksVariantButtonNumber: @3,
                  kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks: @1,
        }},
    ].mutableCopy;
    // Create button specific entry
    NSMutableDictionary *buttonClickEntry = [NSMutableDictionary dictionary];
    int buttonNumber = ((NSNumber *)buttonTriggerDict[kMFButtonTriggerKeyButtonNumber]).intValue;
    buttonClickEntry[@"ui"] = [NSString stringWithFormat:@"%@ click", getButtonString(buttonNumber)];
    buttonClickEntry[@"tool"] = [NSString stringWithFormat:@"Simulate clicking %@", getButtonStringToolTip(buttonNumber)];
    buttonClickEntry[@"dict"] = @{
        kMFActionDictKeyType: kMFActionDictTypeMouseButtonClicks,
        kMFActionDictKeyMouseButtonClicksVariantButtonNumber: @(buttonNumber),
        kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks: @1,
    };
    buttonClickEntry[@"alternate"] = @YES; // Press Option to see this entry
    // Add button sppecific entry(s) to effects table
    [oneShotEffectsTable insertObject:buttonClickEntry atIndex:15];
    // Return
    return oneShotEffectsTable;
}
// Convenience functions for effects tables
- (NSDictionary *)getEntryFromEffectsTable:(NSArray *)effectsTable withEffectDict:(NSDictionary *)effectDict {
    NSIndexSet *inds = [effectsTable indexesOfObjectsPassingTest:^BOOL(NSDictionary * _Nonnull tableEntry, NSUInteger idx, BOOL * _Nonnull stop) {
        return [tableEntry[@"dict"] isEqualToDictionary:effectDict];
    }];
    NSAssert(inds.count == 1, @"");
    // TODO: React well to inds.count == 0, to support people editing remaps dict by hand (If I'm reallyyy bored)
    NSDictionary *effectsTableEntry = (NSDictionary *)effectsTable[inds.firstIndex];
    return effectsTableEntry;
}
- (NSDictionary *)getEntryFromEffectsTable:(NSArray *)effectsTable withUIString:(NSString *)uiString {
    NSIndexSet *inds = [effectsTable indexesOfObjectsPassingTest:^BOOL(NSDictionary * _Nonnull tableEntry, NSUInteger idx, BOOL * _Nonnull stop) {
        return [tableEntry[@"ui"] isEqualToString:uiString];
    }];
    NSAssert(inds.count == 1, @"");
    NSDictionary *effectsTableEntry = effectsTable[inds.firstIndex];
    return effectsTableEntry;
}
- (NSArray *)getEffectsTableForRowDict:(NSDictionary *)rowDict {
    // Get info about what kind of trigger we're dealing with
    NSString *triggerType = @""; // Options "oneShot", "drag", "scroll"
    id triggerValue = rowDict[kMFRemapsKeyTrigger];
    if ([triggerValue isKindOfClass:NSDictionary.class]) {
        triggerType = @"button";
    } else if ([triggerValue isKindOfClass:NSString.class]) {
        NSString *triggerValueStr = (NSString *)triggerValue;
        if ([triggerValueStr isEqualToString:kMFTriggerDrag]) {
            triggerType = @"drag";
        } else if ([triggerValueStr isEqualToString:kMFTriggerScroll]) {
            triggerType = @"scroll";
        } else {
            NSAssert(YES, @"Can't determine trigger type.");
        }
    }
    // Get effects Table
    NSArray *effectsTable;
    if ([triggerType isEqualToString:@"button"]) {
        // We determined that trigger value is a dict -> convert to dict
        NSDictionary *buttonTriggerDict = (NSDictionary *)triggerValue;
        effectsTable = getOneShotEffectsTable(buttonTriggerDict);
    } else if ([triggerType isEqualToString:@"drag"]) {
        effectsTable = getDragEffectsTable();
    } else if ([triggerType isEqualToString:@"scroll"]) {
        effectsTable = getScrollEffectsTable();
    } else {
        NSAssert(NO, @"");
    }
    return effectsTable;
}

#pragma mark - Filling the table

- (NSTableCellView *)getEffectCellWithRowDict:(NSDictionary *)rowDict {
    rowDict = rowDict.mutableCopy; // Not sure if necessary
    NSArray *effectsTable = [self getEffectsTableForRowDict:rowDict];
    // Create trigger cell and fill out popup button contained in it
    NSTableCellView *triggerCell = [self.tableView makeViewWithIdentifier:@"effectCell" owner:nil];
    // Get popup button
    NSPopUpButton *popupButton = triggerCell.subviews[0];
    // Delete existing menu items from IB
    [popupButton removeAllItems];
    // Iterate oneshot effects table and fill popupButton
    for (NSDictionary *effectDict in effectsTable) {
        NSMenuItem *i;
        if ([effectDict[@"noeffect"] isEqualToString: @"separator"]) {
            i = (NSMenuItem *)NSMenuItem.separatorItem;
        } else {
            i = [[NSMenuItem alloc] initWithTitle:effectDict[@"ui"] action:@selector(setConfigToUI:) keyEquivalent:@""];
            [i setToolTip:effectDict[@"tool"]];
            if ([effectDict[@"alternate"] isEqualTo:@YES]) {
                i.alternate = YES;
                i.keyEquivalentModifierMask = NSEventModifierFlagOption;
            }
            i.target = self;
        }
        [popupButton.menu addItem:i];
    }
    
    // Select popup button item corresponding to datamodel
    // Get effectDict from datamodel
    NSDictionary *effectDict = rowDict[kMFRemapsKeyEffect];
    // Get title for effectDict from effectsTable
    NSDictionary *effectsTableEntry = [self getEntryFromEffectsTable:effectsTable withEffectDict:effectDict];
    NSString *title = effectsTableEntry[@"ui"];
    // Select item with title
    [popupButton selectItemWithTitle:title];
    
    return triggerCell;
}
- (NSTableCellView *)getTriggerCellWithRowDict:(NSDictionary *)rowDict {
    rowDict = rowDict.mutableCopy; // This is necessary for some of this hacky mess to work // Somehow the datamodel is still modified, when we
    // Define Data-to-UI-String mappings
    NSDictionary *clickLevelToUIString = @{
        @1: @"",
        @2: @"Double ",
        @3: @"Triple ",
    };
    NSDictionary *durationToUIString = @{
        kMFButtonTriggerDurationClick: @"",
        kMFButtonTriggerDurationHold: @"and Hold ",
    };
    // Get trigger string from data
    NSString *tr = @"";
    NSString *trTool = @"";
    id triggerGeneric = rowDict[kMFRemapsKeyTrigger];
    if ([triggerGeneric isKindOfClass:NSDictionary.class]) {
        // Trigger is button input
        // Get relevant values from button trigger dict
        NSDictionary *trigger = (NSDictionary *)triggerGeneric;
        NSNumber *btn = trigger[kMFButtonTriggerKeyButtonNumber];
        NSNumber *lvl = trigger[kMFButtonTriggerKeyClickLevel];
        NSString *dur = trigger[kMFButtonTriggerKeyDuration];
        // Generate substrings from data
        // lvl & click
        NSString *levelStr;
        NSString *clickStr;
        getClickAndLevelStrings(clickLevelToUIString, lvl, &clickStr, &levelStr);
        if (lvl.intValue < 1) { // 0 or smaller
            @throw [NSException exceptionWithName:@"Invalid click level" reason:@"Remaps contain invalid click level" userInfo:@{@"Trigger dict containing invalid value": trigger}];
        }
        // dur
        NSString *durationStr = durationToUIString[dur];
        if (!durationStr) {
            @throw [NSException exceptionWithName:@"Invalid duration" reason:@"Remaps contain invalid duration" userInfo:@{@"Trigger dict containing invalid value": trigger}];
        }
        // btn
        NSString * buttonStr = getButtonString(btn.intValue);
        NSString * buttonStrTool = getButtonStringToolTip(btn.intValue);
        if (btn.intValue < 1) {
            @throw [NSException exceptionWithName:@"Invalid button number" reason:@"Remaps contain invalid button number" userInfo:@{@"Trigger dict containing invalid value": trigger}];
        }
        // Form trigger string from substrings
        tr = [NSString stringWithFormat:@"%@%@%@%@", levelStr, clickStr, durationStr, buttonStr];
        trTool = [NSString stringWithFormat:@"%@%@%@%@", levelStr, clickStr, durationStr, buttonStrTool];
    } else if ([triggerGeneric isKindOfClass:NSString.class]) {
        // Trigger is drag or scroll
        // Get button strings or, if no button preconds exist, get keyboard modifier string
        NSString *levelStr = @"";
        NSString *clickStr = @"";
        NSString *buttonStr = @"";
        NSString *keyboardModStr = @"";
        NSString *buttonStrTool = @"";
        NSString *keyboardModStrTool = @"";
        // Extract last button press from button-modification-precondition (if it exists)
        NSDictionary *lastButtonPress;
        NSMutableArray *buttonPressSequence = ((NSArray *)rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyButtons]).mutableCopy;
        NSNumber *keyboardModifiers = rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyKeyboard];
        if (buttonPressSequence) {
            lastButtonPress = buttonPressSequence.lastObject;
            [buttonPressSequence removeLastObject];
            rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyButtons] = buttonPressSequence;
            // Generate Level, click, and button strings based on last button press from sequence
            NSNumber *btn = lastButtonPress[kMFButtonModificationPreconditionKeyButtonNumber];
            NSNumber *lvl = lastButtonPress[kMFButtonModificationPreconditionKeyClickLevel];
            getClickAndLevelStrings(clickLevelToUIString, lvl, &clickStr, &levelStr);
            buttonStr = getButtonString(btn.intValue);
            buttonStrTool = getButtonStringToolTip(btn.intValue);
        } else if (keyboardModifiers) {
            // Extract keyboard modifiers
            keyboardModStr = getKeyboardModifierString(keyboardModifiers);
            keyboardModStrTool = getKeyboardModifierStringToolTip(keyboardModifiers);
            rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyKeyboard] = nil;
        } else {
            @throw [NSException exceptionWithName:@"No precondition" reason:@"Modified drag or scroll has no preconditions" userInfo:@{@"Precond dict": (rowDict[kMFRemapsKeyModificationPrecondition])}];
        }
        // Get trigger string
        NSString *triggerStr;
        NSString *trigger = (NSString *)triggerGeneric;
        if ([trigger isEqualToString:kMFTriggerDrag]) {
            // Trigger is drag
            triggerStr = @"and Drag ";
        } else if ([trigger isEqualToString:kMFTriggerScroll]) {
            // Trigger is scroll
            triggerStr = @"and Scroll ";
        } else {
            @throw [NSException exceptionWithName:@"Unknown string trigger value" reason:@"The value for the string trigger key is unknown" userInfo:@{@"Trigger value": trigger}];
        }
        // Form full trigger string from substrings
        tr = [NSString stringWithFormat:@"%@%@%@%@%@", levelStr, clickStr, keyboardModStr, triggerStr, buttonStr];
        trTool = [NSString stringWithFormat:@"%@%@%@%@%@", levelStr, clickStr, keyboardModStrTool, triggerStr, buttonStrTool];
        
    } else {
        NSLog(@"Trigger value: %@, class: %@", triggerGeneric, [triggerGeneric class]);
        @throw [NSException exceptionWithName:@"Invalid trigger value type" reason:@"The value for the trigger key is not a String and not a dictionary" userInfo:@{@"Trigger value": triggerGeneric}];
    }
    // Get keyboard modifier main string and tooltip string
    NSNumber *flags = (NSNumber *)rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyKeyboard];
    NSString *kbModRaw = getKeyboardModifierString(flags);
    NSString *kbModTooltipRaw = getKeyboardModifierStringToolTip(flags);
    NSString *kbMod = @"";
    NSString *kbModTool = @"";
    if (![kbModRaw isEqualToString:@""]) {
        kbMod = [kbModRaw stringByAppendingString:@""]; // @"+ "
        kbModTool = [kbModTooltipRaw stringByAppendingString:@", then "];
    }
    // Get button modifier string
    NSMutableArray *buttonPressSequence = rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyButtons];
    NSMutableArray *buttonModifierStrings = [NSMutableArray array];
    NSMutableArray *buttonModifierStringsTool = [NSMutableArray array];
    for (NSDictionary *buttonPress in buttonPressSequence) {
        NSNumber *btn = buttonPress[kMFButtonModificationPreconditionKeyButtonNumber];
        NSNumber *lvl = buttonPress[kMFButtonModificationPreconditionKeyClickLevel];
        NSString *levelStr;
        NSString *clickStr;
        NSString *buttonStr;
        NSString *buttonStrTool;
        buttonStr = getButtonString(btn.intValue);
        buttonStrTool = getButtonStringToolTip(btn.intValue);
        getClickAndLevelStrings(clickLevelToUIString, lvl, &clickStr, &levelStr);
        NSString *buttonModString = [NSString stringWithFormat:@"%@%@%@ + ", levelStr, clickStr, buttonStr];
        NSString *buttonModStringTool = [NSString stringWithFormat:@"%@%@and Hold %@, then ", levelStr, clickStr, buttonStrTool];
        [buttonModifierStrings addObject:buttonModString];
        [buttonModifierStringsTool addObject:buttonModStringTool];
    }
    NSString *btnMod = [buttonModifierStrings componentsJoinedByString:@""];
    NSString *btnModTool = [buttonModifierStringsTool componentsJoinedByString:@""];
    // Join all substrings to get result string
    NSString *fullTriggerCellString = [NSString stringWithFormat:@"%@%@%@", kbMod, btnMod, tr];
    NSString *fullTriggerCellTooltipString = [NSString stringWithFormat:@"%@%@%@", kbModTool, btnModTool, trTool];
    // Generate view and set string to view
    NSTableCellView *triggerCell = [self.tableView makeViewWithIdentifier:@"triggerCell" owner:nil];
    triggerCell.textField.stringValue = fullTriggerCellString;
    triggerCell.textField.toolTip = fullTriggerCellTooltipString;
    return triggerCell;
}

#pragma mark - TableViewDataSource functions

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    // Get data for this row
    NSDictionary *rowDict = _dataModel[row];
    // Create deep copy of row.
    //  `getTriggerCellWithRowDict` is written badly and needs to manipulate some values nested in rowDict.
    //  I we don't deep copy, the changes to rowDict will reflect into self.dataModel and be written to file causing corruption.
    //      (The fact that rowDict is NSDictionary not NSMutableDictionary doesn't help, cause the stuff being manipulated is nested)
    rowDict = (NSDictionary *)[SharedUtility deepCopyOf:rowDict];
    if ([tableColumn.identifier isEqualToString:@"trigger"]) { // The trigger column should display the trigger as well as the modification precondition
        return [self getTriggerCellWithRowDict:rowDict];
    } else if ([tableColumn.identifier isEqualToString:@"effect"]) {
        return [self getEffectCellWithRowDict:rowDict];
    } else {
        @throw [NSException exceptionWithName:@"Unknown column identifier" reason:@"TableView is requesting data for a column with an unknown identifier" userInfo:@{@"requested data for column": tableColumn}];
        return nil;
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _dataModel.count;
}

# pragma mark - String generating helper functions

static void getClickAndLevelStrings(NSDictionary *clickLevelToUIString, NSNumber *lvl, NSString **clickStr, NSString **levelStr) {
    *levelStr = clickLevelToUIString[lvl];
    if (!*levelStr) {
        *levelStr = [NSString stringWithFormat:@"%@", lvl];
    }
    // click // TODO: Refactor, so this just returns levelStr, because click string doesn't depend to level string anymore
    *clickStr = @"Click ";
}

static NSString *getButtonString(int buttonNumber) {
    NSDictionary *buttonNumberToUIString = @{
        @1: @"Primary Button",
        @2: @"Secondary Button",
        @3: @"Middle Button",
    };
    NSString *buttonStr = buttonNumberToUIString[@(buttonNumber)];
    if (!buttonStr) {
        buttonStr = [NSString stringWithFormat:@"Button %@", @(buttonNumber)];
    }
    return buttonStr;
}
static NSString *getButtonStringToolTip(int buttonNumber) {
    NSDictionary *buttonNumberToUIString = @{
        @1: @"the Primary Mouse Button (also called the Left Mouse Button or Mouse Button 1)",
        @2: @"the Secondary Mouse Button (also called the Right Mouse Button or Mouse Button 2)",
        @3: @"the Middle Mouse Button (also called the Scroll Wheel Button or Mouse Button 3)",
    };
    NSString *buttonStr = buttonNumberToUIString[@(buttonNumber)];
    if (!buttonStr) {
        buttonStr = [NSString stringWithFormat:@"Mouse Button %@", @(buttonNumber)];
    }
    return buttonStr;
}

static NSString *getKeyboardModifierString(NSNumber *flags) {
    NSString *kb = @"";
    if (flags) {
        CGEventFlags f = flags.longLongValue;
        kb = [NSString stringWithFormat:@"%@%@%@%@ ",
              (f & kCGEventFlagMaskControl ?    @"^" : @""),
              (f & kCGEventFlagMaskAlternate ?  @"⌥" : @""),
              (f & kCGEventFlagMaskShift ?      @"⇧" : @""),
              (f & kCGEventFlagMaskCommand ?    @"⌘" : @"")];
    }
    return kb;
}
static NSString *getKeyboardModifierStringToolTip(NSNumber *flags) {
    NSString *kb = @"";
    if (flags) {
        CGEventFlags f = flags.longLongValue;
        kb = [NSString stringWithFormat:@"%@%@%@%@",
              (f & kCGEventFlagMaskControl ?    @"Control (^)-" : @""),
              (f & kCGEventFlagMaskAlternate ?  @"Option (⌥)-" : @""),
              (f & kCGEventFlagMaskShift ?      @"Shift (⇧)-" : @""),
              (f & kCGEventFlagMaskCommand ?    @"Command (⌘)-" : @"")];
    }
    if (kb.length > 0) {
        kb = [kb substringToIndex:kb.length-1]; // Delete trailing dash
//        kb = [kb stringByAppendingString:@" "]; // Append trailing space
        kb = [kb stringByReplacingOccurrencesOfString:@"-" withString:@" and "];
        kb = [@"Hold " stringByAppendingString:kb];
    }
    
    return kb;
}

@end
