//
// --------------------------------------------------------------------------
// RemapTableDataSource.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "RemapTableTranslator.h"
#import "Constants.h"
#import "UIStrings.h"
#import "SharedUtility.h"
#import "NSAttributedString+Additions.h"
#import "NSTextField+Additions.h"
#import "ConfigFileInterface_App.h"
#import "RemapTableController.h"
#import "KeyCaptureView.h"
#import "AppDelegate.h"
#import "NSView+Additions.h"
#import "RemapTableUtility.h"

@interface RemapTableTranslator ()

@end

@implementation RemapTableTranslator

#pragma mark (Pseudo) Properties

NSTableView *_tableView;
//
+ (void)initializeWithTableView:(NSTableView *)tableView {
    _tableView = tableView;
}
+ (NSTableView *)tableView {
    return _tableView;
}
+ (RemapTableController *)controller {
    return (RemapTableController *)self.tableView.delegate;
}
+ (NSArray *)dataModel {
    return self.controller.dataModel;
}
//+ (void)setGroupedDataModel:(NSArray *)newModel {
//    self.controller.dataModel = newModel;
//}
+ (NSArray *)groupedDataModel {
    return self.controller.groupedDataModel;
}

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
// Noah from future: an 'effectsTable' should probably be called an 'effectButtonMenuModel' or 'effectsMenuModel' or 'effectOptionsModel' or something else that's more descriptive and less close to 'remapsTable'

static NSDictionary *separatorEffectsTableEntry() {
    return @{@"isSeparator": @YES};
}
static NSArray *getScrollEffectsTable() {
    NSArray *scrollEffectsTable = @[
        @{@"ui": @"Zoom in or out", @"tool": @"Zoom in or out in Safari, Maps, and other apps \n \nWorks like Pinch to Zoom on an Apple Trackpad" , @"dict": @{}
        },
        @{@"ui": @"Horizontal scroll", @"tool": @"Scroll horizontally \nNavigate pages in Safari, delete messages in Mail, and more \n \nWorks like swiping horizontally with 2 fingers on an Apple Trackpad" , @"dict": @{}
        },
//        @{@"ui": @"Rotate", @"tool": @"", @"dict": @{}},
//        @{@"ui": @"Precision Scroll", @"tool": @"", @"dict": @{}},
//        @{@"ui": @"Fast scroll", @"tool": @"", @"dict": @{}},
    ];
    return scrollEffectsTable;
}
static NSArray *getDragEffectsTable() {
    NSArray *dragEffectsTable = @[
        @{@"ui": @"Mission Control & Spaces", @"tool": @"Move your mouse: \n - Up to show Mission Control \n - Down to show Application Windows \n - Left or Right to move between Spaces\n \nWorks like swiping with 3 fingers on an Apple Trackpad" , @"dict": @{
                  kMFModifiedDragDictKeyType: kMFModifiedDragTypeThreeFingerSwipe,
        }},
//        @{@"ui": @"Scroll & navigate pages", @"tool": @"Scroll by moving your mouse in any direction \nNavigate pages in Safari, delete messages in Mail, and more, by moving your mouse horizontally \n \nWorks like swiping with 2 fingers on an Apple Trackpad" , @"dict": @{
//                  kMFModifiedDragDictKeyType: kMFModifiedDragTypeTwoFingerSwipe,
//        }},
//        separatorEffectsTableEntry(),
        @{
//          @"ui": [NSString stringWithFormat:@"%@ Click and Drag", [UIStrings getButtonString:3]],
          @"ui": [NSString stringWithFormat:@"Middle Click and Drag"],
//          @"ui": [NSString stringWithFormat:@"%@ Drag", [UIStrings getButtonString:3]],
          @"tool": [NSString stringWithFormat: @"Works like clicking and dragging %@\nUsed to orbit in some 3D software like Blender", [UIStrings getButtonStringToolTip:3]],
          @"hideable": @YES,
          @"dict": @{
                  kMFModifiedDragDictKeyType: kMFModifiedDragTypeFakeDrag,
                  kMFModifiedDragDictKeyFakeDragVariantButtonNumber: @3,
        }},
    ];
    return dragEffectsTable;
}
static NSArray *getOneShotEffectsTable(NSDictionary *rowDict) {
    
    MFMouseButtonNumber buttonNumber = ((NSNumber *)rowDict[kMFRemapsKeyTrigger][kMFButtonTriggerKeyButtonNumber]).unsignedIntValue;
    NSDictionary *effectDict = rowDict[kMFRemapsKeyEffect];
    
    NSMutableArray *oneShotEffectsTable = @[
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
        @{@"ui": @"Look Up", @"tool": @"Look up words in the Dictionary, Quick Look files in Finder, and more. \n \nWorks like Force Touch on an Apple Trackpad.", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHLookUp)
        }},
        @{@"ui": @"Smart Zoom", @"tool": @"Zoom in or out in Safari and other apps. \n \nWorks like a two-finger double tap on an Apple Trackpad.", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSmartZoom,
        }},
        @{
//            @"ui": fstring(@"%@ Click", [UIStrings getButtonString:3]),
            @"ui": fstring(@"Middle Click"),
            @"tool": [NSString stringWithFormat:@"Open links in a new tab, paste text in the Terminal, and more. \n \nWorks like clicking %@ on a standard mouse.", [UIStrings getButtonStringToolTip:3]],
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
        separatorEffectsTableEntry(),
        @{@"ui": @"Keyboard Shortcut...", @"tool": @"Type a keyboard shortcut, then use it from your mouse", @"keyCaptureEntry": @YES},
    ].mutableCopy;
    
    // Insert button specific entry
    
    if (buttonNumber != 3) { // We already have the "Open Link in New Tab" entry for button 3
        NSDictionary *buttonClickEntry = @{
            @"ui": [NSString stringWithFormat:@"%@ Click", [UIStrings getButtonString:buttonNumber]],
            @"tool": [NSString stringWithFormat:@"Simulate Clicking %@", [UIStrings getButtonStringToolTip:buttonNumber]],
            @"hideable": @NO,
            @"alternate": @YES,
            @"dict": @{
                    kMFActionDictKeyType: kMFActionDictTypeMouseButtonClicks,
                    kMFActionDictKeyMouseButtonClicksVariantButtonNumber: @(buttonNumber),
                    kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks: @1,
            }
        };
        [oneShotEffectsTable insertObject:buttonClickEntry atIndex:9];
    }
    
    // Insert entry for keyboard shortcut effect
    
    if ([effectDict[kMFActionDictKeyType] isEqual:kMFActionDictTypeKeyboardShortcut]) {
        // Get index for new entry (right after keyCaptureEntry)
        NSIndexSet *keyCaptureIndexes = [oneShotEffectsTable indexesOfObjectsPassingTest:^BOOL(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj[@"keyCaptureEntry"] isEqual:@YES];
        }];
        assert(keyCaptureIndexes.count == 1);
        NSUInteger shortcutIndex = keyCaptureIndexes.firstIndex + 1;
        // Get keycode and flags
        CGKeyCode keyCode = ((NSNumber *)effectDict[kMFActionDictKeyKeyboardShortcutVariantKeycode]).unsignedShortValue;
        CGEventFlags flags = ((NSNumber *)effectDict[kMFActionDictKeyKeyboardShortcutVariantModifierFlags]).unsignedLongValue;
        // Get shortcut string
        NSString *shortcutString = [UIStrings getStringForKeyCode:keyCode flags:flags];
        // Create and insert new entry
        [oneShotEffectsTable insertObject:@{
            @"ui": shortcutString,
            @"tool": fstring(@"Works like pressing '%@' on your keyboard", shortcutString),
            @"dict": effectDict,
            @"indentation": @1,
        } atIndex:shortcutIndex];
    };
    
    return oneShotEffectsTable;
}
// Convenience functions for effects tables

// We wanted to rename 'effects table' to 'effects menu model', but we only did it in a few places. Thats why this is named weird
+ (NSDictionary *)getEntryFromEffectTable:(NSArray *)effectTable withEffectDict:(NSDictionary *)effectDict {
    
    if ([effectDict[@"drawKeyCaptureView"] isEqual: @YES]) {
        return nil;
    }
    
    NSIndexSet *inds = [effectTable indexesOfObjectsPassingTest:^BOOL(NSDictionary * _Nonnull tableEntry, NSUInteger idx, BOOL * _Nonnull stop) {
        return [tableEntry[@"dict"] isEqualToDictionary:effectDict];
    }];
    NSAssert(inds.count == 1, @"Inds: %@", inds);
    // TODO: React well to inds.count == 0, to support people editing remaps dict by hand (If I'm reallyyy bored)
    NSDictionary *effectsTableEntry = (NSDictionary *)effectTable[inds.firstIndex];
    return effectsTableEntry;
}
+ (NSDictionary *)getEntryFromEffectsTable:(NSArray *)effectsTable withUIString:(NSString *)uiString {
    NSIndexSet *inds = [effectsTable indexesOfObjectsPassingTest:^BOOL(NSDictionary * _Nonnull tableEntry, NSUInteger idx, BOOL * _Nonnull stop) {
        return [tableEntry[@"ui"] isEqualToString:uiString];
    }];
    NSAssert(inds.count == 1, @"");
    NSDictionary *effectsTableEntry = effectsTable[inds.firstIndex];
    return effectsTableEntry;
}

+ (NSArray *)getEffectsTableForRemapsTableEntry:(NSDictionary *)rowDict {
    
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
        effectsTable = getOneShotEffectsTable(rowDict);
    } else if ([triggerType isEqualToString:@"drag"]) {
        effectsTable = getDragEffectsTable();
    } else if ([triggerType isEqualToString:@"scroll"]) {
        effectsTable = getScrollEffectsTable();
    } else {
        NSAssert(NO, @"");
    }
    return effectsTable;
}

#pragma mark - Fill the tableView

static NSString *effectNameForRowDict(NSDictionary * _Nonnull rowDict) {
    NSArray *effectsTable = [RemapTableTranslator getEffectsTableForRemapsTableEntry:rowDict];
    NSDictionary *effectDict = rowDict[kMFRemapsKeyEffect];
    NSString *name;
    if (effectDict) { // When inserting new rows through AddMode, there is no effectDict at first // Noah from future: are you sure? I think this has changed.
//        if ([effectDict[kMFActionDictKeyType] isEqual:kMFActionDictTypeKeyboardShortcut]) {
//            NSNumber *keyCode = effectDict[kMFActionDictKeyKeyboardShortcutVariantKeycode];
//            NSNumber *flags = effectDict[kMFActionDictKeyKeyboardShortcutVariantModifierFlags];
//            name = [UIStrings getStringForKeyCode:keyCode.unsignedIntValue flags:flags.unsignedIntValue];
//        } else
//        {
            // Get title for effectDict from effectsTable
            NSDictionary *effectsMenuModelEntry = [RemapTableTranslator getEntryFromEffectTable:effectsTable withEffectDict:effectDict];
            name = effectsMenuModelEntry[@"ui"];
//        }
    }
    return name;
}

/// \discussion We only need the `row` parameter to insert data into the datamodel, which we shouldn't be doing from this function to begin with
/// \discussion We need the `tableViewEnabled` parameter to enabled / disable contained popUpButtons depending on whether the table view is enabled
///         We used to use the function 'disableUI:' in App Delegate to recursively go over all controls and disable them. But disabling controls contained in the table view sometimes didn't work, when they weren't scrolled into view. (It worked when disableUI: was called in response to toggling the "Enabled Mac Mouse Fix" checkbox, but it didn't work when it was called in response to the app launching. I'm not sure why.)
///            For a clean solution, the tableView should reload it's content, whenever tableView.enabled changes, so that this function is called again. I don't think it does this (automatically) though. However, things still seem to work fine. I assume, that's because we're still doing the recursive enabling/disabling from AppDelegate - disableUI:, and both that function and this one work together in some way I don't understand to enable/disable everything properly.
+ (NSTableCellView *)getEffectCellWithRowDict:(NSDictionary *)rowDict row:(NSUInteger)row tableViewEnabled:(BOOL)tableViewEnabled {
    
    rowDict = rowDict.mutableCopy; // Not sure if necessary
    NSArray *effectTable = [self getEffectsTableForRemapsTableEntry:rowDict];
    // Create trigger cell and fill out popup button contained in it
    NSTableCellView *triggerCell = [self.tableView makeViewWithIdentifier:@"effectCell" owner:nil];
    
    NSDictionary *effectDict = rowDict[kMFRemapsKeyEffect];
    
    if ([effectDict[@"drawKeyCaptureView"] isEqual:@YES]) { // This is not a real effectDict, but instead an instruction to draw a key capture view
        
        // Create captureField
        
        // Get MFKeystrokeCaptureCell instance from IB
        NSTableCellView *keyCaptureCell = [self.tableView makeViewWithIdentifier:@"keyCaptureCell" owner:self];
        // Get capture field
        KeyCaptureView *keyStrokeCaptureField = (KeyCaptureView *)[keyCaptureCell nestedSubviewsWithIdentifier:@"keyCaptureView"][0];
        
        [keyStrokeCaptureField setupWithCaptureHandler:^(CGKeyCode keyCode, CGEventFlags flags) {
            
            // Create new effectDict
            NSDictionary *newEffectDict = @{
                kMFActionDictKeyType: kMFActionDictTypeKeyboardShortcut,
                kMFActionDictKeyKeyboardShortcutVariantKeycode: @(keyCode),
                kMFActionDictKeyKeyboardShortcutVariantModifierFlags: @(flags),
            };
            
            // Insert new effectDict into dataModel and reload table
            //  Manipulating the datamodel should probably be done by RemapTableController, not RemapTableTranslator, and definitely not in this method, but oh well.
            
            NSInteger rowBaseDataModel = [RemapTableUtility baseDataModelIndexFromGroupedDataModelIndex:row withGroupedDataModel:self.groupedDataModel];
            
            self.dataModel[rowBaseDataModel][kMFRemapsKeyEffect] = newEffectDict;
            [self.tableView reloadData];
            [self.controller updateTableAndWriteToConfig:nil];
            
        } cancelHandler:^{
            
            [self.tableView reloadData];
            // Restore tableView to the ground truth dataModel
            //  This used to restore original state if the capture field has been created through `reloadDataWithTemporaryDataModel:`
            
        }];
        
        triggerCell = keyCaptureCell;
        
    } else {
        // Get popup button
        NSPopUpButton *popupButton = triggerCell.subviews[0];
        // Delete existing menu items from IB
        [popupButton removeAllItems];
        // Iterate oneshot effects table and fill popupButton
        for (NSDictionary *effectTableEntry in effectTable) {
            NSMenuItem *i;
            if ([effectTableEntry[@"isSeparator"] isEqual: @YES]) {
                i = (NSMenuItem *)NSMenuItem.separatorItem;
            } else {
                i = [[NSMenuItem alloc] init];
                i.title = effectTableEntry[@"ui"];
                i.action = @selector(updateTableAndWriteToConfig:);
                i.target = self.tableView.delegate;
                i.toolTip = effectTableEntry[@"tool"];
                
                if ([effectTableEntry[@"keyCaptureEntry"] isEqual:@YES]) {
                    i.action = @selector(handleKeystrokeMenuItemSelected:);
                }
                if ([effectTableEntry[@"alternate"] isEqual:@YES]) {
                    i.alternate = YES;
                    i.keyEquivalentModifierMask = NSEventModifierFlagOption;
                }
                if ([effectTableEntry[@"hideable"] isEqual:@YES]) {
                    NSMenuItem *h = [[NSMenuItem alloc] init];
                    h.view = [[NSView alloc] initWithFrame:NSZeroRect];
                    h.enabled = NO; // Prevent the zero-height item from being selected by keyboard. This only works if `autoenablesItems == NO` on the PopUpButton
                    [popupButton.menu addItem:h];
                    i.alternate = YES;
                    i.keyEquivalentModifierMask = NSEventModifierFlagOption;
                }
                if (effectTableEntry[@"indentation"] != nil) {
                    i.indentationLevel = ((NSNumber *)effectTableEntry[@"indentation"]).unsignedIntegerValue;
                }
            }
            [popupButton.menu addItem:i];
        }
        
        // Select popup button item corresponding to datamodel
        // Get effectDict from datamodel
        NSString * title = effectNameForRowDict(rowDict);
        if (title) {
            [popupButton selectItemWithTitle:title];
        }
        
        // Disable popupbutton, if tableView is disabled
        popupButton.enabled = tableViewEnabled;
       
    }
    
    return triggerCell;
}

+ (NSTableCellView *)getTriggerCellWithRowDict:(NSDictionary *)rowDict {
    
    rowDict = rowDict.mutableCopy; // This is necessary for some of this hacky mess to work // However, this is not a deep copy, so the _dataModel is still changed when we change some nested object. Watch out!
    
    // Define Data-to-UI-String mappings
    NSDictionary *clickLevelToUIString = @{
        @1: @"",
        @2: @"Double ",
        @3: @"Triple ",
    };
    
    // Get trigger string from data
    NSAttributedString *tr;
    NSAttributedString *trTool;
    NSString *mainButtonStr = @"";
    
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
        mainButtonStr = [UIStrings getButtonString:btn.intValue];
        NSString *mainButtonStrTool = [UIStrings getButtonStringToolTip:btn.intValue];
        if (btn.intValue < 1) {
            @throw [NSException exceptionWithName:@"Invalid button number" reason:@"Remaps contain invalid button number" userInfo:@{@"Trigger dict containing invalid value": trigger}];
        }
        
        // Form trigger string from substrings
        
        NSString *trRaw = [NSString stringWithFormat:@"%@%@", levelStr, durationStr]; // Append buttonStr later depending on whether there are button preconds
        NSString *trToolRaw = [NSString stringWithFormat:@"%@%@%@", levelStr, durationStr, mainButtonStrTool];
        
        // Turn into attributedString and highlight button substrings
        tr = [[NSAttributedString alloc] initWithString:trRaw];
        trTool = [[NSAttributedString alloc] initWithString:trToolRaw];
//        tr = [tr attributedStringBySettingSecondaryButtonTextColorForSubstring:buttonStr];
//        trTool = [trTool attributedStringBySettingSecondaryButtonTextColorForSubstring:buttonStrTool];
        
    } else if ([triggerGeneric isKindOfClass:NSString.class]) { // Trigger is drag or scroll
        // We need part of the modification precondition to form the main trigger string here.
        //  E.g. if our precondition for a modified drag is single click button 3, followed by double click button 4, we want the string to be "Click Middle Button + Double Click and Drag Button 4", where the "Click Middle Button + " substring follows the format of a regular modification precondition string (we compute those further down) but the "Double Click and Drag Button 4" substring, which is also called the "trigger string" follows a different format which we compute here.
        // Get button strings from last button precond, or, if no button preconds exist, get keyboard modifier string
        NSString *levelStr = @"";
        NSString *clickStr = @"";
        mainButtonStr = @"";
        NSString *keyboardModStr = @"";
        NSString *mainButtonStrTool = @"";
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
            mainButtonStr = [UIStrings getButtonString:btn.intValue];
            mainButtonStrTool = [UIStrings getButtonStringToolTip:btn.intValue];
        } else if (keyboardModifiers != nil) {
            // Extract keyboard modifiers
            keyboardModStr = [UIStrings getKeyboardModifierString:((NSNumber *)keyboardModifiers).unsignedIntegerValue];
            keyboardModStr = [keyboardModStr stringByAppendingString:@" "];
            keyboardModStrTool = [UIStrings getKeyboardModifierStringToolTip:((NSNumber *)keyboardModifiers).unsignedIntegerValue];
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
        
        NSString *trRaw = [NSString stringWithFormat:@"%@%@%@%@", levelStr, clickStr, keyboardModStr, triggerStr]; // Append buttonStr later depending on whether there are button preconds
        NSString *trToolRaw = [NSString stringWithFormat:@"%@%@%@%@%@", levelStr, clickStr, keyboardModStrTool, triggerStr, mainButtonStrTool];
        
        // Turn into attributedString and highlight button substrings
        tr = [[NSAttributedString alloc] initWithString:trRaw];
        trTool = [[NSAttributedString alloc] initWithString:trToolRaw];
//        tr = [tr attributedStringBySettingSecondaryButtonTextColorForSubstring:buttonStr];
//        trTool = [trTool attributedStringBySettingSecondaryLabelColorForSubstring:buttonStrTool];
        
    } else {
        NSLog(@"Trigger value: %@, class: %@", triggerGeneric, [triggerGeneric class]);
        @throw [NSException exceptionWithName:@"Invalid trigger value type" reason:@"The value for the trigger key is not a String and not a dictionary" userInfo:@{@"Trigger value": triggerGeneric}];
    }
    
    // Get keyboard modifier strings
    
    NSNumber *flags = (NSNumber *)rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyKeyboard];
    NSString *kbModRaw = [UIStrings getKeyboardModifierString:((NSNumber *)flags).unsignedIntegerValue];
    NSString *kbModTooltipRaw = [UIStrings getKeyboardModifierStringToolTip:((NSNumber *)flags).unsignedIntegerValue];
    NSString *kbMod = @"";
    NSString *kbModTool = @"";
    if (![kbModRaw isEqualToString:@""]) {
        kbMod = [kbModRaw stringByAppendingString:@" "]; // @"+ "
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
        buttonStrTool = [UIStrings getButtonStringToolTip:btn.intValue];
        levelStr = clickLevelToUIString[lvl];
        NSString *buttonModString = [NSString stringWithFormat:@"%@Click %@ + ", levelStr, buttonStr];
        NSString *buttonModStringTool = [NSString stringWithFormat:@"%@Click and Hold %@, then ", levelStr, buttonStrTool];
        [buttonModifierStrings addObject:buttonModString];
        [buttonModifierStringsTool addObject:buttonModStringTool];
    }
    NSString *btnMod = [buttonModifierStrings componentsJoinedByString:@""];
    NSString *btnModTool = [buttonModifierStringsTool componentsJoinedByString:@""];
    
    // Get effect string
    NSString *effectString = [NSString stringWithFormat:@" to use '%@'", effectNameForRowDict(rowDict)];
//    NSString *effectString = @""; // TODO: For debugging - undo this
    
    // Append buttonStr
    
    if (![btnMod isEqual:@""]) { // Only display main button string if there are button modifiers
        NSMutableAttributedString *trMutable = tr.mutableCopy;
        [trMutable appendAttributedString:[[NSAttributedString alloc] initWithString:mainButtonStr]];
        tr = [trMutable attributedStringBySettingSecondaryButtonTextColorForSubstring:mainButtonStr];
    }
    
    // Join all substrings to get result string
    NSMutableAttributedString *fullTriggerCellString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@", kbMod, btnMod]];
    NSMutableAttributedString *fullTriggerCellTooltipString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@", kbModTool, btnModTool]];
    [fullTriggerCellString appendAttributedString:tr];
    [fullTriggerCellTooltipString appendAttributedString:trTool];
    [fullTriggerCellTooltipString appendAttributedString:[[NSMutableAttributedString alloc] initWithString:effectString]];
    
    
    // Generate view and set string to view
    NSTableCellView *triggerCell = [self.tableView makeViewWithIdentifier:@"triggerCell" owner:nil];
    triggerCell.textField.attributedStringValue = fullTriggerCellString;
    triggerCell.textField.toolTip = fullTriggerCellTooltipString.string;
    return triggerCell;
}

@end
