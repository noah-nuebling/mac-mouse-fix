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
#import <Cocoa/Cocoa.h>
#import "SharedUtility.h"
#import "NSAttributedString+Additions.h"
#import "NSTextField+Additions.h"
#import "UIStrings.h"
#import "SharedMessagePort.h"
#import "CaptureNotifications.h"

@interface RemapTableController ()
@property NSTableView *tableView;
@property NSArray *dataModel; // Is actually an NSMutableArray I think. Take care not to accidentally corrupt this!
@end

@implementation RemapTableController
@synthesize dataModel = _dataModel;

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
    self.dataModel = ConfigFileInterface_App.config[kMFConfigKeyRemaps];
}
- (void)writeDataModelToConfig {
    [ConfigFileInterface_App.config setObject:self.dataModel forKey:kMFConfigKeyRemaps];
    [ConfigFileInterface_App writeConfigToFileAndNotifyHelper];
}

- (void)awakeFromNib {
    // Force Autohiding scrollers - to keep layout consistent (doesn't work)
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.scrollerStyle = NSScrollerStyleOverlay;
}

- (NSScrollView *)scrollView {
    NSClipView *clipView = (NSClipView *)self.tableView.superview;
    NSScrollView *scrollView = (NSScrollView *)clipView.superview;
    return scrollView;
}

- (void)viewDidLoad {
    // Not getting called for some reason -> I had to set the view outlet of the controller object in IB to the tableView.
    
#if DEBUG
    NSLog(@"RemapTableView did load.");
#endif
    
    // Set rounded corners and appropriate border
    
    NSScrollView * scrollView = self.scrollView;
    
    CGFloat cr = 5.0;
    // ^ Should be equal to cornerRadius of surrounding NSBox
    //   Hardcoding this might lead to bad visuals on pre-BigSur macOS versions with lower corner radius, but idk how to access the NSBox's effective cornerRadius
    
    scrollView.borderType = NSNoBorder;
    scrollView.wantsLayer = YES;
    scrollView.layer.masksToBounds = YES;
    if (@available(macOS 10.14, *)) {
        scrollView.layer.borderColor = NSColor.separatorColor.CGColor;
    } else {
        scrollView.layer.borderColor = NSColor.gridColor.CGColor;
    }
    scrollView.layer.borderWidth = 1.0;
    scrollView.layer.cornerRadius = cr;
    
    // Load table data from config
    [self loadDataModelFromConfig];
    // Initialize sorting
    [self initSorting];
    // Do first sorting (Not sure where soring and reloading is appropriate but this seems fine)
    [self sortDataModel];
    [self.tableView reloadData];
}

// IBActions
- (IBAction)addRemoveControl:(id)sender {
    if ([sender selectedSegment] == 0) {
        [self addButtonAction];
    } else {
        [self removeButtonAction];
    }
}
- (void)removeButtonAction {
    NSSet<NSNumber *> *capturedButtonsBefore = (NSSet *)[SharedMessagePort sendMessage:@"getCapturedButtons" withPayload:nil expectingReply:YES];
    
    NSMutableArray *mutableDataModel = self.dataModel.mutableCopy;
    [mutableDataModel removeObjectsAtIndexes:self.tableView.selectedRowIndexes];
    self.dataModel = (NSArray *)mutableDataModel;
    [self writeDataModelToConfig];
    [self loadDataModelFromConfig]; // Not sure if necessary
    [self.tableView removeRowsAtIndexes:self.tableView.selectedRowIndexes withAnimation:NSTableViewAnimationSlideUp];
    
    NSSet *capturedButtonsAfter = (NSSet *)[SharedMessagePort sendMessage:@"getCapturedButtons" withPayload:nil expectingReply:YES];
    [CaptureNotifications showButtonCaptureNotificationWithBeforeSet:capturedButtonsBefore afterSet:capturedButtonsAfter];
}
- (void)addButtonAction {
    [AddWindowController begin];
}
- (void)addRowWithHelperPayload:(NSDictionary *)payload {
    
    NSSet<NSNumber *> *capturedButtonsBefore = (NSSet *)[SharedMessagePort sendMessage:@"getCapturedButtons" withPayload:nil expectingReply:YES];
    
    NSMutableDictionary *pl = payload.mutableCopy;
    // ((Check if payload is valid tableEntry))
    // Check if already in table
    NSIndexSet *existingIndexes = [self.dataModel indexesOfObjectsPassingTest:^BOOL(NSDictionary * _Nonnull tableEntry, NSUInteger idx, BOOL * _Nonnull stop) {
        BOOL triggerMatches = [tableEntry[kMFRemapsKeyTrigger] isEqualTo:pl[kMFRemapsKeyTrigger]];
        BOOL modificationPreconditionMatches = [tableEntry[kMFRemapsKeyModificationPrecondition] isEqualTo:pl[kMFRemapsKeyModificationPrecondition]];
        return triggerMatches && modificationPreconditionMatches;
    }];
    NSAssert(existingIndexes.count <= 1, @"Duplicate remap triggers found in table");
    NSIndexSet *toHighlightIndexSet;
    if (existingIndexes.count == 0) {
        // Fill out effect in payload with first effect from effects table (to make behaviour appropriate when user doesn't choose any effect)
        //      We could also consider removing the tableEntry, if the user just dismisses the popup menu without choosing an effect, instead of this.
        pl[kMFRemapsKeyEffect] = [self getEffectsTableForRemapsTableEntry:pl][0][@"dict"];
        // Add new row to data model
        self.dataModel = [self.dataModel arrayByAddingObject:pl];
        // Sort data model
        [self sortDataModel];
        // Display new row with animation and highlight by selecting it
        NSUInteger insertedIndex = [self.dataModel indexOfObject:pl];
        toHighlightIndexSet = [NSIndexSet indexSetWithIndex:insertedIndex];
        [self.tableView insertRowsAtIndexes:toHighlightIndexSet withAnimation:NSTableViewAnimationSlideDown];
        // Set config to file (to make behaviour appropriate when user doesn't choose any effect)
        [self setConfigToUI:nil];
    } else {
        toHighlightIndexSet = existingIndexes;
    }
    [self.tableView selectRowIndexes:toHighlightIndexSet byExtendingSelection:NO];
    [self.tableView scrollRowToVisible:toHighlightIndexSet.firstIndex];
    // Open the NSMenu on the newly created row's popup button
    NSInteger tableColumn = [self.tableView columnWithIdentifier:@"effect"];
    NSPopUpButton *popUpButton = [self.tableView viewAtColumn:tableColumn row:toHighlightIndexSet.firstIndex makeIfNecessary:NO].subviews[0];
    [popUpButton performSelector:@selector(performClick:) withObject:nil afterDelay:0.2];
    
    NSSet<NSNumber *> *capturedButtonsAfter = (NSSet *)[SharedMessagePort sendMessage:@"getCapturedButtons" withPayload:nil expectingReply:YES];
    [CaptureNotifications showButtonCaptureNotificationWithBeforeSet:capturedButtonsBefore afterSet:capturedButtonsAfter];
    
//    if ([capturedButtonsBefore isEqual:capturedButtonsAfter]) {
        // If they aren't equal then `showButtonCaptureNotificationWithBeforeSet:` will show a notification
        //      This notification will not be interactable if we also open the popup button menu.
//        [popUpButton performSelector:@selector(performClick:) withObject:nil afterDelay:0.2];
//    }

}

- (IBAction)setConfigToUI:(id)sender {
    // Set popupbutton content to datamodel
    for (NSInteger row = 0; row < self.dataModel.count; row++) {
        // Get effect dicts
        NSTableCellView *cell = [self.tableView viewAtColumn:1 row:row makeIfNecessary:YES];
        NSPopUpButton *pb = cell.subviews[0];
        NSString *selectedTitle = pb.selectedItem.title;
        // Get effects table for row of sender
        NSArray *effectsTable = [self getEffectsTableForRemapsTableEntry:self.dataModel[row]];
        NSDictionary *effectsTableEntryForSelected = [self getEntryFromEffectsTable:effectsTable withUIString:selectedTitle];
        NSDictionary *effectDictForSelected = effectsTableEntryForSelected[@"dict"];
        // Write effect dict to data model and then write datamodel to file
        self.dataModel[row][kMFRemapsKeyEffect] = effectDictForSelected;
    }
    // Write datamodel to file
    [self writeDataModelToConfig];
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

static NSDictionary *separatorEffectsTableEntry() {
    return @{@"noeffect": @"separator"};
}
// Hideablility doesn't seem to work on separators
//static NSDictionary *hideableSeparatorEffectsTableEntry() {
//    return @{@"noeffect": @"separator", @"hideable": @YES};
//}
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
        @{@"ui": @"Mission Control & Spaces", @"tool": @"Move your mouse: \n - Up to show Mission Control \n - Down to show Application Windows \n - Left or Right to move between Spaces" , @"dict": @{
                  kMFModifiedDragDictKeyType: kMFModifiedDragTypeThreeFingerSwipe,
        }},
//        @{@"ui": @"Scroll & navigate pages", @"tool": @"Scroll by moving your mouse in any direction \nNavigate pages in Safari, delete messages in Mail, and more, by moving your mouse horizontally \nWorks like swiping with 2 fingers on an Apple Trackpad" , @"dict": @{
//                  kMFModifiedDragDictKeyType: kMFModifiedDragTypeTwoFingerSwipe,
//        }},
//        separatorEffectsTableEntry(),
        @{@"ui": [NSString stringWithFormat:@"Click and Drag %@", [UIStrings getButtonString:3]],
          @"tool": [NSString stringWithFormat: @"Simulates clicking and dragging %@ \nUsed to rotate in some 3d software like Blender", getButtonStringToolTip(3)],
          @"hideable": @YES,
          @"dict": @{
                  kMFModifiedDragDictKeyType: kMFModifiedDragTypeFakeDrag,
                  kMFModifiedDragDictKeyFakeDragVariantButtonNumber: @3,
        }},
    ];
    return dragEffectsTable;
}
static NSArray *getOneShotEffectsTable(NSDictionary *buttonTriggerDict) {
    
    int buttonNumber = ((NSNumber *)buttonTriggerDict[kMFButtonTriggerKeyButtonNumber]).intValue;
    
    NSArray *oneShotEffectsTable = @[
        @{@"ui": @"Mission Control", @"tool": @"Show Mission Control", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHMissionControl)
        }},
        @{@"ui": @"Application Windows", @"tool": @"Show all windows of the active app", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHAppExpose)
        }},
        @{@"ui": @"Show Desktop", @"tool": @"Show the desktop", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHShowDesktop)
        }},
        separatorEffectsTableEntry(),
        @{@"ui": @"Launchpad", @"tool": @"Open Launchpad", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHLaunchpad)
        }},
        separatorEffectsTableEntry(),
        @{@"ui": @"Look Up", @"tool": @"Look up words in the Dictionary, Quick Look files in Finder, and more... \nWorks like Force Touch on an Apple Trackpad", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHLookUp)
        }},
        @{@"ui": @"Smart Zoom", @"tool": @"Zoom in or out in Safari and other apps \nSimulates a two-finger double tap on an Apple Trackpad", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSmartZoom,
        }},
        @{@"ui": @"Open Link in New Tab",
          @"tool": [NSString stringWithFormat:@"Open links in a new tab, paste text in the Terminal, and more... \nSimulates clicking %@", getButtonStringToolTip(3)],
          @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeMouseButtonClicks,
                  kMFActionDictKeyMouseButtonClicksVariantButtonNumber: @3,
                  kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks: @1,
          }},
        separatorEffectsTableEntry(),
        @{@"ui": @"Move Left a Space", @"tool": @"Move one Space to the left", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHMoveLeftASpace)
        }},
        @{@"ui": @"Move Right a Space", @"tool": @"Move one Space to the right", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHMoveRightASpace)
        }},
        separatorEffectsTableEntry(),
        @{@"ui": @"Back", @"tool": @"Go back one page in Safari and other apps", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeNavigationSwipe,
                  kMFActionDictKeyGenericVariant: kMFNavigationSwipeVariantLeft
        }},
        @{@"ui": @"Forward", @"tool": @"Go forward one page in Safari and other apps", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeNavigationSwipe,
                  kMFActionDictKeyGenericVariant: kMFNavigationSwipeVariantRight
        }},
    ];
    
    if (buttonNumber != 3) { // We already have the "Open Link in New Tab" entry for button 3
        NSDictionary *buttonClickEntry = @{
           @"ui": [NSString stringWithFormat:@"%@ Click", [UIStrings getButtonString:buttonNumber]],
           @"tool": [NSString stringWithFormat:@"Simulate Clicking %@", getButtonStringToolTip(buttonNumber)],
           @"hideable": @YES,
           @"dict": @{
               kMFActionDictKeyType: kMFActionDictTypeMouseButtonClicks,
               kMFActionDictKeyMouseButtonClicksVariantButtonNumber: @(buttonNumber),
               kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks: @1,
           }
        };
        NSMutableArray *temp = oneShotEffectsTable.mutableCopy;
        [temp insertObject:buttonClickEntry atIndex:9];
        oneShotEffectsTable = temp;
    }
    
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
- (NSArray *)getEffectsTableForRemapsTableEntry:(NSDictionary *)tableEntry {
    // Get info about what kind of trigger we're dealing with
    NSString *triggerType = @""; // Options "oneShot", "drag", "scroll"
    id triggerValue = tableEntry[kMFRemapsKeyTrigger];
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

#pragma mark - Filling the tableView

- (NSTableCellView *)getEffectCellWithRowDict:(NSDictionary *)rowDict {
    
    rowDict = rowDict.mutableCopy; // Not sure if necessary
    NSArray *effectsTable = [self getEffectsTableForRemapsTableEntry:rowDict];
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
            i.toolTip = effectDict[@"tool"];
            if ([effectDict[@"alternate"] isEqualTo:@YES]) {
                i.alternate = YES;
                i.keyEquivalentModifierMask = NSEventModifierFlagOption;
            }
            if ([effectDict[@"hideable"] isEqualTo:@YES]) {
                NSMenuItem *h = [[NSMenuItem alloc] init];
                h.view = [[NSView alloc] initWithFrame:NSZeroRect];
                [popupButton.menu addItem:h];
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
    if (effectDict) { // When inserting new rows through AddMode, there is no effectDict at first
        // Get title for effectDict from effectsTable
        NSDictionary *effectsTableEntry = [self getEntryFromEffectsTable:effectsTable withEffectDict:effectDict];
        NSString *title = effectsTableEntry[@"ui"];
        // Select item with title
        [popupButton selectItemWithTitle:title];
    }
    
    return triggerCell;
}

- (NSTableCellView *)getTriggerCellWithRowDict:(NSDictionary *)rowDict {
    rowDict = rowDict.mutableCopy; // This is necessary for some of this hacky mess to work // However, this is not a deep copy, so the _dataModel is still changed when we change some nested object. Watch out!
    
    // Define Data-to-UI-String mappings
    NSDictionary *clickLevelToUIString = @{
        @1: @"",
        @2: @"Double ",
        @3: @"Triple ",
    };
    
    // Get trigger string from data
    NSMutableAttributedString *tr;
    NSMutableAttributedString *trTool;
    id triggerGeneric = rowDict[kMFRemapsKeyTrigger];
    
    if ([triggerGeneric isKindOfClass:NSDictionary.class]) { // Trigger is button input
        
        // Get relevant values from button trigger dict
        NSDictionary *trigger = (NSDictionary *)triggerGeneric;
        NSNumber *btn = trigger[kMFButtonTriggerKeyButtonNumber];
        NSNumber *lvl = trigger[kMFButtonTriggerKeyClickLevel];
        NSString *dur = trigger[kMFButtonTriggerKeyDuration];
        
        // Generate substrings from data
        
        // lvl
        NSString *levelStr = (NSString *)clickLevelToUIString[lvl];
        if (!levelStr) {
            levelStr = [NSString stringWithFormat:@"%@", lvl];
        }
        if (lvl.intValue < 1) { // 0 or smaller
            @throw [NSException exceptionWithName:@"Invalid click level" reason:@"Remaps contain invalid click level" userInfo:@{@"Trigger dict containing invalid value": trigger}];
        }
        // dur
        NSString *durationStr;
        if ([dur isEqualToString:kMFButtonTriggerDurationClick]) {
            durationStr = @"Click ";
        } else if ([dur isEqualToString:kMFButtonTriggerDurationHold]) {
            if (lvl.intValue == 1) {
                durationStr = @"Hold ";
            } else {
                durationStr = @"Click and Hold ";
            }
        }
        if (!durationStr) {
            @throw [NSException exceptionWithName:@"Invalid duration" reason:@"Remaps contain invalid duration" userInfo:@{@"Trigger dict containing invalid value": trigger}];
        }
        // btn
        NSString * buttonStr = [UIStrings getButtonString:btn.intValue];
        NSString * buttonStrTool = getButtonStringToolTip(btn.intValue);
        if (btn.intValue < 1) {
            @throw [NSException exceptionWithName:@"Invalid button number" reason:@"Remaps contain invalid button number" userInfo:@{@"Trigger dict containing invalid value": trigger}];
        }
        
        // Form trigger string from substrings
        
        NSString *trRaw = [NSString stringWithFormat:@"%@%@%@", levelStr, durationStr, buttonStr];
        NSString *trToolRaw = [NSString stringWithFormat:@"%@%@%@", levelStr, durationStr, buttonStrTool];
        
        // Turn into attributedString and highlight button substrings
        tr = [self addBoldForSubstring:buttonStr inString:trRaw];
        trTool = [self addBoldForSubstring:buttonStrTool inString:trToolRaw];
        
    } else if ([triggerGeneric isKindOfClass:NSString.class]) { // Trigger is drag or scroll
        // We need part of the modification precondition to form the main trigger string here.
        //  E.g. if our precondition for a modified drag is single click button 3, followed by double click button 4, we want the string to be "Click Middle Button + Double Click and Drag Button 4", where the "Click Middle Button + " substring follows the format of a regular modification precondition string (we compute those further down) but the "Double Click and Drag Button 4" substring, which is also called the "trigger string" follows a different format which we compute here.
        // Get button strings from last button precond, or, if no button preconds exist, get keyboard modifier string
        NSString *levelStr = @"";
        NSString *clickStr = @"";
        NSString *buttonStr = @"";
        NSString *keyboardModStr = @"";
        NSString *buttonStrTool = @"";
        NSString *keyboardModStrTool = @"";
        
        // Extract last button press from button-modification-precondition. If it doesn't exist, get kb mod string
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
            levelStr = clickLevelToUIString[lvl];
            clickStr = @"Click ";
            buttonStr = [UIStrings getButtonString:btn.intValue];
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
            triggerStr = @"and Drag ";
        } else if ([trigger isEqualToString:kMFTriggerScroll]) {
            triggerStr = @"and Scroll ";
        } else {
            @throw [NSException exceptionWithName:@"Unknown string trigger value" reason:@"The value for the string trigger key is unknown" userInfo:@{@"Trigger value": trigger}];
        }
        
        // Form full trigger cell string from substrings
        
        NSString *trRaw = [NSString stringWithFormat:@"%@%@%@%@%@", levelStr, clickStr, keyboardModStr, triggerStr, buttonStr];
        NSString *trToolRaw = [NSString stringWithFormat:@"%@%@%@%@%@", levelStr, clickStr, keyboardModStrTool, triggerStr, buttonStrTool];
        
        // Turn into attributedString and highlight button substrings
        tr = [self addBoldForSubstring:buttonStr inString:trRaw];
        trTool = [self addBoldForSubstring:buttonStrTool inString:trToolRaw];
        
    } else {
        NSLog(@"Trigger value: %@, class: %@", triggerGeneric, [triggerGeneric class]);
        @throw [NSException exceptionWithName:@"Invalid trigger value type" reason:@"The value for the trigger key is not a String and not a dictionary" userInfo:@{@"Trigger value": triggerGeneric}];
    }
    
    // Get keyboard modifier strings
    
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
        NSString *buttonStr;
        NSString *buttonStrTool;
        buttonStr = [UIStrings getButtonString:btn.intValue];
        buttonStrTool = getButtonStringToolTip(btn.intValue);
        levelStr = clickLevelToUIString[lvl];
        NSString *buttonModString = [NSString stringWithFormat:@"%@Click %@ + ", levelStr, buttonStr];
        NSString *buttonModStringTool = [NSString stringWithFormat:@"%@Click and Hold %@, then ", levelStr, buttonStrTool];
        [buttonModifierStrings addObject:buttonModString];
        [buttonModifierStringsTool addObject:buttonModStringTool];
    }
    NSString *btnMod = [buttonModifierStrings componentsJoinedByString:@""];
    NSString *btnModTool = [buttonModifierStringsTool componentsJoinedByString:@""];
    
    // Join all substrings to get result string
    NSMutableAttributedString *fullTriggerCellString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@", kbMod, btnMod]];
    NSMutableAttributedString *fullTriggerCellTooltipString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@", kbModTool, btnModTool]];
    [fullTriggerCellString appendAttributedString:tr];
    [fullTriggerCellTooltipString appendAttributedString:trTool];
    
    
    // Generate view and set string to view
    NSTableCellView *triggerCell = [self.tableView makeViewWithIdentifier:@"triggerCell" owner:nil];
    triggerCell.textField.attributedStringValue = fullTriggerCellString;
    triggerCell.textField.toolTip = fullTriggerCellTooltipString.string;
    return triggerCell;
}

#pragma mark - TableViewDataSource functions

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    // Get data for this row
    NSDictionary *rowDict = self.dataModel[row];
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
    return self.dataModel.count;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    
    // Calculate trigger cell text height
    NSDictionary *rowDict = self.dataModel[row];
    rowDict = (NSDictionary *)[SharedUtility deepCopyOf:rowDict];
    NSTableCellView *view = [self getTriggerCellWithRowDict:rowDict];
    // ^ These lines are copied from `tableView:viewForTableColumn:row:`. Should change this cause copied code is bad.
    NSTextField *textField = view.subviews[0];
    NSMutableAttributedString *string = textField.effectiveAttributedStringValue.mutableCopy;
    NSLog(@"STRINGGGGGG HAS ATTRIBUTES: %@", [string attributesAtIndex:0 effectiveRange:nil]);
    
    CGFloat wdth = textField.bounds.size.width; // 326 for some reason, in IB it's 323
    // ^ TODO: Test method from [Utility_App actualTextViewWidth]
    CGFloat textHeight = [string heightAtWidth:wdth];
    
    // Get top and bottom margins around text from IB template
    NSTableCellView *templateView = [self.tableView makeViewWithIdentifier:@"triggerCell" owner:nil];
    NSTextField *templateTextField = templateView.subviews[0];
    CGFloat templateViewHeight = templateView.bounds.size.height;
    CGFloat templateTextFieldHeight = templateTextField.bounds.size.height;
    double margin = templateViewHeight - templateTextFieldHeight;
    
    // Add margins and text height to get result
    CGFloat result = textHeight + margin;
    if (result == templateViewHeight) {
        return result;
    } else {
#if DEBUG
        NSLog(@"Height of row %ld is non-standard - Template: %f, Actual: %f", (long)row, templateViewHeight, result);
#endif
        // This should occur, if the text doesn't fit the line. I don't know why + 2 is necessary (+ 4 If we don't use bold substrings)
        //  + 4 also wasn't enough in some cases. This doesn't seem like a very reliable method.
        // TODO: Find better solution than this + 10 stuff
//            return result + 10;
        return result;
    }
}

# pragma mark - String generating helper functions

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
- (NSMutableAttributedString *)addBoldForSubstring:(NSString *)subStr inString:(NSString *)baseStr {
    
    NSMutableAttributedString *ret = [[NSMutableAttributedString alloc] initWithString:baseStr];
    NSFont *boldFont = [NSFont boldSystemFontOfSize:NSFont.systemFontSize];
    NSRange subStrRange = [baseStr rangeOfString:subStr];
//    [ret addAttribute:NSFontAttributeName value:boldFont range:subStrRange]; // Commenting this out means the function doesn't do anything
    return ret;
}

#pragma mark - Sorting the table

- (void)sortDataModel {
    self.dataModel = [self.dataModel sortedArrayUsingDescriptors:self.tableView.sortDescriptors];
}

/// Might mutate the `tableEntryMutable` argument by deleting the last button precondition in the precond sequence. (But only if it extracted that info into the output arguments)
static void getTriggerValues(int *btn1, int *lvl1, NSString **dur1, NSString **type1, NSMutableDictionary *tableEntryMutable1) {
    id trigger1 = tableEntryMutable1[kMFRemapsKeyTrigger];
    BOOL isString1 = [trigger1 isKindOfClass:NSString.class];
    if (!isString1) {
        *type1 = @"button";
        *btn1 = ((NSNumber *)trigger1[kMFButtonTriggerKeyButtonNumber]).intValue;
        *lvl1 = ((NSNumber *)trigger1[kMFButtonTriggerKeyClickLevel]).intValue;
        *dur1 = ((NSString *)trigger1[kMFButtonTriggerKeyDuration]);
    } else {
        // Extract last element from button modification precondition and use that
        // (This is why we need it mutable)
        NSMutableArray *buttonPreconds = ((NSArray *)tableEntryMutable1[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyButtons]).mutableCopy;
        NSDictionary *lastButtonPress = buttonPreconds.lastObject;
        [buttonPreconds removeLastObject];
        tableEntryMutable1[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyButtons] = buttonPreconds;
        *btn1 = ((NSNumber *)lastButtonPress[kMFButtonModificationPreconditionKeyButtonNumber]).intValue;
        *lvl1 = ((NSNumber *)lastButtonPress[kMFButtonModificationPreconditionKeyClickLevel]).intValue;
        *dur1 = @"";
        if ([(NSString *)trigger1 isEqualToString:kMFTriggerDrag]) {
            *type1 = @"drag";
        } else if ([(NSString *)trigger1 isEqualToString:kMFTriggerScroll]) {
            *type1 = @"scroll";
        }
    }
}
- (void)initSorting {
    NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:nil ascending:YES comparator:^NSComparisonResult(NSDictionary * _Nonnull tableEntry1, NSDictionary * _Nonnull tableEntry2) {
        
        // Create mutable deep copies so we don't mess table up accidentally
        NSMutableDictionary *tableEntryMutable1 = (NSMutableDictionary *)[SharedUtility deepCopyOf:tableEntry1].mutableCopy;
        NSMutableDictionary *tableEntryMutable2 = (NSMutableDictionary *)[SharedUtility deepCopyOf:tableEntry2].mutableCopy;
        
        // Get trigger info (button and level, duration, type)
        int btn1;
        int lvl1;
        NSString *dur1;
        NSString *type1;
        getTriggerValues(&btn1, &lvl1, &dur1, &type1, tableEntryMutable1);
        int btn2;
        int lvl2;
        NSString *dur2;
        NSString *type2;
        getTriggerValues(&btn2, &lvl2, &dur2, &type2, tableEntryMutable2);
        
        // Get modification precondition info
        NSDictionary *preconds1 = tableEntryMutable1[kMFRemapsKeyModificationPrecondition];
        NSDictionary *preconds2 = tableEntryMutable2[kMFRemapsKeyModificationPrecondition];
        
        // 2.1 Sort by button precond
        NSArray *buttonSequence1 = preconds1[kMFModificationPreconditionKeyButtons];
        NSArray *buttonSequence2 = preconds2[kMFModificationPreconditionKeyButtons];
        uint64_t iterMax = MIN(buttonSequence1.count, buttonSequence2.count);
        NSLog(@"DEBUG - buttonSequence1: %@, buttonSequence2: %@, iterMax: %@", buttonSequence1, buttonSequence2, @(iterMax));
        // ^ We sometimes get a "index 0 beyond bounds for empty array" error for the `buttonSequence1[i]` instruction. Seemingly at random.
        for (int i = 0; i < iterMax; i++) {
            NSDictionary *buttonPress1 = buttonSequence1[i];
            NSDictionary *buttonPress2 = buttonSequence2[i];
            int btn1 = ((NSNumber *)buttonPress1[kMFButtonModificationPreconditionKeyButtonNumber]).intValue;
            int btn2 = ((NSNumber *)buttonPress2[kMFButtonModificationPreconditionKeyButtonNumber]).intValue;
            int lvl1 = ((NSNumber *)buttonPress1[kMFButtonModificationPreconditionKeyClickLevel]).intValue;
            int lvl2 = ((NSNumber *)buttonPress2[kMFButtonModificationPreconditionKeyClickLevel]).intValue;
            if (btn1 > btn2) {
                return NSOrderedDescending;
            } else if (btn1 < btn2) {
                return NSOrderedAscending;
            }
            if (lvl1 > lvl2) {
                return NSOrderedDescending;
            } else if (lvl1 < lvl2){
                return NSOrderedAscending;
            }
        }
        // If len is different, but everything up until iterMax is equal, take the shorter one
        if (buttonSequence1.count > buttonSequence2.count) {
            return NSOrderedDescending;
        } else if (buttonSequence1.count < buttonSequence2.count) {
            return NSOrderedAscending;
        }
        // 2.2 Sort by keyboard precond
        NSNumber *modifierFlags1 = preconds1[kMFModificationPreconditionKeyKeyboard];
        NSNumber *modifierFlags2 = preconds2[kMFModificationPreconditionKeyKeyboard];
        if (modifierFlags1.integerValue > modifierFlags2.integerValue) {
            return NSOrderedDescending;
        } else if (modifierFlags1.integerValue < modifierFlags2.integerValue) {
            return NSOrderedAscending;
        }
        
        // 1. Sort by button
        if (btn1 > btn2) {
            return NSOrderedDescending;
        } else if (btn1 < btn2) {
            return NSOrderedAscending;
        }
        // 1.1. Sort by trigger type (drag, scroll, button)
        NSArray *orderedTypes = @[@"drag", @"scroll", @"button"];
        NSUInteger typeIndex1 = [orderedTypes indexOfObject:type1];
        NSUInteger typeIndex2 = [orderedTypes indexOfObject:type2];
        if (typeIndex1 > typeIndex2) {
            return NSOrderedDescending;
        } else if (typeIndex1 < typeIndex2) {
            return NSOrderedAscending;
        }
        // 1.2 Sort by click level
        if (lvl1 > lvl2) {
            return NSOrderedDescending;
        } else if (lvl1 < lvl2) {
            return NSOrderedAscending;
        }
        // 1.3 Sort by duration
        NSArray *orderedDurations = @[kMFButtonTriggerDurationClick, kMFButtonTriggerDurationHold];
        NSUInteger durationIndex1 = [orderedDurations indexOfObject:dur1];
        NSUInteger durationIndex2 = [orderedDurations indexOfObject:dur2];
        if (durationIndex1 > durationIndex2) {
            return NSOrderedDescending;
        } else if (durationIndex1 < durationIndex2) {
            return NSOrderedAscending;
        }
        return NSOrderedSame;
    }];
    [self.tableView setSortDescriptors:@[sd]];
}

@end
