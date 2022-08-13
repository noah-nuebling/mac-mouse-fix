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
#import "Config.h"
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
// TODO: ? Create constants for these keys
// There are also separatorTableEntry()s which become a separator in the popupbutton-menu generated from the effectsTable
// There are 3 different effectsTables for 3 different types of triggers
// Noah from future: an 'effectsTable' should probably be called an 'effectButtonMenuModel' or 'effectsMenuModel' or 'effectOptionsModel' or something else that's more descriptive and less close to 'remapsTable'

static NSDictionary *separatorEffectsTableEntry() {
    return @{@"isSeparator": @YES};
}
//static NSDictionary *hideableSeparatorEffectsTableEntry() {
//    return @{@"isSeparator": @YES, @"hideable": @YES}; /// This doesn't work ;/
//}
static NSArray *getScrollEffectsTable() {
    NSArray *scrollEffectsTable = @[
        @{@"ui": @"Zoom in or out", @"tool": @"Zoom in or out in Safari, Maps, and other apps \n \nWorks like Pinch to Zoom on an Apple Trackpad" , @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeZoom
        }},
        @{@"ui": @"Horizontal Scroll", @"tool": @"Scroll horizontally \nNavigate pages in Safari, delete messages in Mail, and more \n \nWorks like swiping horizontally with 2 fingers on an Apple Trackpad" , @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeHorizontalScroll
        }},
        @{@"ui": @"Rotate", @"hideable": @NO, @"tool": @"Rotate in Maps and other apps \n \nWorks like Twisting with 2 fingers on an Apple Trackpad", @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeRotate
        }},
        separatorEffectsTableEntry(),
        @{@"ui": @"Swift Scroll", @"tool": @"Scroll long distances with minimal effort", @"dict": @{
            kMFModifiedScrollDictKeyInputModificationType: kMFModifiedScrollInputModificationTypeQuickScroll
        }},
        @{@"ui": @"Precise Scroll", @"tool": @"Scroll small distances and use sensitive UI elements with precision.", @"dict": @{
            kMFModifiedScrollDictKeyInputModificationType: kMFModifiedScrollInputModificationTypePrecisionScroll
        }},
        separatorEffectsTableEntry(),
        @{@"ui": @"Desktop & Launchpad", @"tool": @"Scroll up for Launchpad and down to show the Desktop \n \nWorks like Pinching with 4 fingers on an Apple Trackpad", @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeFourFingerPinch
        }},
        @{@"ui": @"Move between Spaces", @"tool": @"Scroll up to move left a Space and down to move Right a Space \n \nWorks like Swiping horizontally with 3 fingers on an Apple Trackpad", @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeThreeFingerSwipeHorizontal
        }},
        separatorEffectsTableEntry(),
        @{@"ui": @"App Switcher", @"tool": @"Quickly switch between open apps \n \nWorks like holding Command (⌘) and then pressing Tab (⇥) on your keyboard", @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeCommandTab
        }},
        
    ];
    return scrollEffectsTable;
}
static NSArray *getDragEffectsTable() {
    NSArray *dragEffectsTable = @[
        @{@"ui": @"Mission Control & Spaces", @"tool": @"Move your mouse: \n - Up to show Mission Control \n - Down to show Application Windows \n - Left or Right to move between Spaces\n \nWorks like swiping with 3 fingers on an Apple Trackpad" , @"dict": @{
                  kMFModifiedDragDictKeyType: kMFModifiedDragTypeThreeFingerSwipe,
        }},
        @{@"ui": @"Scroll & Navigate", @"tool": @"Scroll freely by moving your mouse in any direction \n \nNavigate between pages in Safari, delete messages in Mail and more by moving your mouse left and right \n \nWorks like swiping with 2 fingers on an Apple Trackpad" , @"dict": @{
                  kMFModifiedDragDictKeyType: kMFModifiedDragTypeTwoFingerSwipe,
        }},
//        separatorEffectsTableEntry(),
//        @{
////          @"ui": [NSString stringWithFormat:@"%@ Click and Drag", [UIStrings getButtonString:3]],
//          @"ui": [NSString stringWithFormat:@"Middle Click and Drag"],
////          @"ui": [NSString stringWithFormat:@"%@ Drag", [UIStrings getButtonString:3]],
//          @"tool": [NSString stringWithFormat: @"Works like clicking and dragging %@\nUsed to orbit in some 3D software like Blender", [UIStrings getButtonStringToolTip:3]],
//          @"hideable": @YES,
//          @"dict": @{
//                  kMFModifiedDragDictKeyType: kMFModifiedDragTypeFakeDrag,
//                  kMFModifiedDragDictKeyFakeDragVariantButtonNumber: @3,
//        }},
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
        @{@"ui": @"App Exposé", @"tool": @"Show all windows of the active app", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHAppExpose)
        }},
//        separatorEffectsTableEntry(),
        @{@"ui": @"Desktop", @"tool": @"Show the desktop", @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHShowDesktop)
        }},
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
//        separatorEffectsTableEntry(),
        @{@"ui": stringf(@"Middle Click"),
          @"tool": [NSString stringWithFormat:@"Open links in a new tab, paste text in the Terminal, and more. \n \nWorks like clicking %@ on a standard mouse.", [UIStrings getButtonStringToolTip:3]],
          @"dict": @{
              kMFActionDictKeyType: kMFActionDictTypeMouseButtonClicks,
              kMFActionDictKeyMouseButtonClicksVariantButtonNumber: @3,
              kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks: @1,
          }
        },
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
        @{@"ui": @"Keyboard Shortcut...", @"tool": @"Type a keyboard shortcut, then use it from your mouse", @"keyCaptureEntry": @YES},
    ].mutableCopy;
    
    /// Insert button specific entry
    
    if (buttonNumber != 3) { /// We already have the "Open Link in New Tab" / "Middle Click" entry for button 3
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
        [oneShotEffectsTable insertObject:buttonClickEntry atIndex:10];
    }
    
    /// Insert entry for keyboard shortcut effect
    
    /// Get keycapture index
    NSIndexSet *keyCaptureIndexes = [oneShotEffectsTable indexesOfObjectsPassingTest:^BOOL(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [obj[@"keyCaptureEntry"] isEqual:@YES];
    }];
    assert(keyCaptureIndexes.count == 1);
    NSUInteger keyCaptureIndex = keyCaptureIndexes.firstIndex;
    
    /// Insert entry for keyboard shortcut effect or systemDefined effect
    
    BOOL isKeyShortcut = [effectDict[kMFActionDictKeyType] isEqual:kMFActionDictTypeKeyboardShortcut];
    BOOL isSystemEvent = [effectDict[kMFActionDictKeyType] isEqual:kMFActionDictTypeSystemDefinedEvent];
    
    if (isKeyShortcut || isSystemEvent) {
        
        /// Get index for new entry (right after keyCaptureEntry)
        NSUInteger shortcutIndex = keyCaptureIndex + 1;
        
        /// Get  strings
        
        NSAttributedString *shortcutString = getShortcutString(effectDict, isKeyShortcut);

        NSString *shortcutStringRaw = [shortcutString stringWithAttachmentDescriptions];
        
        /// Create and insert new entry
        [oneShotEffectsTable insertObject:@{
            @"uiAttributed": shortcutString,
            @"tool": stringf(@"Works like pressing '%@' on your keyboard", shortcutStringRaw),
            @"dict": effectDict,
            @"indentation": @1,
        } atIndex:shortcutIndex];
    }
    
    /// Insert hidden submenu for  apple specific keys
    
    int separator = -1;
    
    MFSystemDefinedEventType systemEventTypes[] =  {
        kMFSystemEventTypeBrightnessDown,
        kMFSystemEventTypeBrightnessUp,
        separator,
        kMFSystemEventTypeMediaBack,
        kMFSystemEventTypeMediaPlayPause,
        kMFSystemEventTypeMediaForward,
        separator,
        kMFSystemEventTypeVolumeMute,
        kMFSystemEventTypeVolumeDown,
        kMFSystemEventTypeVolumeUp
    };
    int count = sizeof(systemEventTypes) / sizeof(systemEventTypes[0]);
    
    NSMutableArray<NSDictionary *> *submenu = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        
        MFSystemDefinedEventType type = systemEventTypes[i];
        
        if (type == separator) {
            [submenu addObject:separatorEffectsTableEntry()];
        } else {
            NSDictionary *actionDict = @{
                kMFActionDictKeyType: kMFActionDictTypeSystemDefinedEvent,
                kMFActionDictKeySystemDefinedEventVariantType: @(type),
                kMFActionDictKeySystemDefinedEventVariantModifierFlags: @(0),
    };
    
            NSAttributedString *shortcutString = getShortcutString(actionDict, NO);
            NSString *shortcutStringRaw = [shortcutString stringWithAttachmentDescriptions];
            [submenu addObject:@{
                @"uiAttributed": shortcutString,
                @"tool": stringf(@"Works like pressing '%@' on an Apple keyboard", shortcutStringRaw),
                @"dict": actionDict
            }];
        }
    }
    
    [oneShotEffectsTable insertObject:@{
        @"ui": @" Exclusive Keys",
        @"tool": @"Choose keys that are only available on Apple keyboards.",
        @"alternate": @YES,
        @"submenu": submenu
    } atIndex:keyCaptureIndex+1];
    
    return oneShotEffectsTable;
}

/// Helper for getEffectsTable

static NSAttributedString *getShortcutString(NSDictionary *effectDict, BOOL isKeyShortcut) {
    
    if (isKeyShortcut) {
        
        CGKeyCode keyCode = ((NSNumber *)effectDict[kMFActionDictKeyKeyboardShortcutVariantKeycode]).unsignedShortValue;
        CGEventFlags flags = ((NSNumber *)effectDict[kMFActionDictKeyKeyboardShortcutVariantModifierFlags]).unsignedLongValue;
        
        return [UIStrings getStringForKeyCode:keyCode flags:flags];
        
    } else { /// Is systemEventShortcut
        
        MFSystemDefinedEventType type = ((NSNumber *)effectDict[kMFActionDictKeySystemDefinedEventVariantType]).unsignedIntValue;
        CGEventFlags flags = ((NSNumber *)effectDict[kMFActionDictKeySystemDefinedEventVariantModifierFlags]).unsignedLongValue;
        
        return [UIStrings getStringForSystemDefinedEvent:type flags:flags];
    }
}

/// Convenience functions for effects tables

/// We wanted to rename 'effects table' to 'effects menu model', but we only did it in a few places. Thats why this is named weird
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
//+ (NSDictionary *)getEntryFromEffectsTable:(NSArray *)effectsTable withUIString:(NSAttributedString *)uiString {
//    NSIndexSet *inds = [effectsTable indexesOfObjectsPassingTest:^BOOL(NSDictionary * _Nonnull tableEntry, NSUInteger idx, BOOL * _Nonnull stop) {
//        return [tableEntry[@"ui"] isEqual:uiString];
//    }];
//    NSAssert(inds.count == 1, @"");
//    NSDictionary *effectsTableEntry = effectsTable[inds.firstIndex];
//    return effectsTableEntry;
//}

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
            NSAssert(NO, @"Can't determine trigger type.");
        }
    }
    /// Get effects Table
    NSArray *effectsTable;
    if ([triggerType isEqualToString:@"button"]) {
        /// We determined that trigger value is a dict -> convert to dict
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
    if (effectDict) {
            NSDictionary *effectsMenuModelEntry = [RemapTableTranslator getEntryFromEffectTable:effectsTable withEffectDict:effectDict];
            name = effectsMenuModelEntry[@"ui"];
        if (name == nil) {
            name = [effectsMenuModelEntry[@"uiAttributed"] stringWithAttachmentDescriptions];
        }
    }
    return name;
}

+ (NSMenuItem * _Nullable)getPopUpButtonItemToSelectBasedOnRowDict:(NSPopUpButton * _Nonnull)button rowDict:(NSDictionary * _Nonnull)rowDict {
    
    int itemIndex = -1;
    
    NSArray *effectsTable = [RemapTableTranslator getEffectsTableForRemapsTableEntry: rowDict];
    
    int i = 0;
    while (true) {
        NSDictionary *effectTableEntry = effectsTable[i];
        if ([effectTableEntry[@"dict"] isEqual: rowDict[kMFRemapsKeyEffect]]) {
            itemIndex = i;
            break;
        };
        i++;
    }
    
    if (itemIndex != -1) {
        return [button itemAtIndex:i];
    } else {
        return nil;
    }
}

+ (NSDictionary * _Nullable)getEffectDictBasedOnSelectedItemInButton:(NSPopUpButton * _Nonnull)button rowDict:(NSDictionary * _Nonnull)rowDict {
    
    NSArray *effectsTable = [RemapTableTranslator getEffectsTableForRemapsTableEntry:rowDict];
    NSInteger selectedIndex = button.indexOfSelectedItem;
    
    return effectsTable[selectedIndex][@"dict"];
    
}

+ (NSMenuItem *)menuItemFromDataModel:(NSDictionary *)itemModel enclosingMenu:(NSMenu *)enclosingMenu {
    NSMenuItem *i;
    if ([itemModel[@"isSeparator"] isEqual: @YES]) {
        i = (NSMenuItem *)NSMenuItem.separatorItem;
    } else {
        i = [[NSMenuItem alloc] init];
        NSString *title = itemModel[@"ui"];
        if (title != nil) {
            i.title = title;
        } else {
            i.attributedTitle = itemModel[@"uiAttributed"];
        }
        i.action = @selector(updateTableAndWriteToConfig:);
        i.target = self.tableView.delegate;
        i.toolTip = itemModel[@"tool"];
        
        if ([itemModel[@"keyCaptureEntry"] isEqual:@YES]) {
            i.action = @selector(handleKeystrokeMenuItemSelected:);
        }
        if ([itemModel[@"alternate"] isEqual:@YES]) {
            i.alternate = YES;
            i.keyEquivalentModifierMask = NSEventModifierFlagOption;
        }
        if ([itemModel[@"hideable"] isEqual:@YES]) {
            NSMenuItem *h = [[NSMenuItem alloc] init];
            h.view = [[NSView alloc] initWithFrame:NSZeroRect];
            h.enabled = NO; /// Prevent the zero-height item from being selected by keyboard. This only works if `autoenablesItems == NO` on the PopUpButton
            [enclosingMenu addItem:h];
            i.alternate = YES;
            i.keyEquivalentModifierMask = NSEventModifierFlagOption;
        }
        if (itemModel[@"indentation"] != nil) {
            i.indentationLevel = ((NSNumber *)itemModel[@"indentation"]).unsignedIntegerValue;
        }
        if (itemModel[@"submenu"] != nil) {
            NSMenu *m = [[NSMenu alloc] init];
            for (NSDictionary *submenuItemModel in itemModel[@"submenu"]) {
                NSMenuItem *subI = [self menuItemFromDataModel:submenuItemModel enclosingMenu:m];
                subI.representedObject = submenuItemModel;
                subI.action = @selector(submenuItemClicked:);
                [m addItem:subI];
            }
            i.submenu = m;
            i.action = nil;
        }
    }
    return i;
}

/// \discussion We only need the `row` parameter to insert data into the datamodel, which we shouldn't be doing from this function to begin with
/// \discussion We need the `tableViewEnabled` parameter to enabled / disable contained popUpButtons depending on whether the table view is enabled
///         We used to use the function 'disableUI:' in App Delegate to recursively go over all controls and disable them. But disabling controls contained in the table view sometimes didn't work, when they weren't scrolled into view. (It worked when disableUI: was called in response to toggling the "Enabled Mac Mouse Fix" checkbox, but it didn't work when it was called in response to the app launching. I'm not sure why.)
///            For a clean solution, the tableView should reload it's content, whenever tableView.enabled changes, so that this function is called again. I don't think it does this (automatically) though. However, things still seem to work fine. I assume, that's because we're still doing the recursive enabling/disabling from AppDelegate - disableUI:, and both that function and this one work together in some way I don't understand to enable/disable everything properly.
+ (NSTableCellView *)getEffectCellWithRowDict:(NSDictionary *)rowDict row:(NSUInteger)row tableViewEnabled:(BOOL)tableViewEnabled {
    
    rowDict = rowDict.mutableCopy; /// Not sure if necessary
    NSArray *effectTable = [self getEffectsTableForRemapsTableEntry:rowDict];
    /// Create trigger cell and fill out popup button contained in it
    NSTableCellView *triggerCell = [self.tableView makeViewWithIdentifier:@"effectCell" owner:nil];
    
    NSDictionary *effectDict = rowDict[kMFRemapsKeyEffect];
    
    if ([effectDict[@"drawKeyCaptureView"] isEqual:@YES]) { // This is not a real effectDict, but instead an instruction to draw a key capture view
        
        /// Create captureField
        
        /// Get MFKeystrokeCaptureCell instance from IB
        NSTableCellView *keyCaptureCell = [self.tableView makeViewWithIdentifier:@"keyCaptureCell" owner:self];
        /// Get capture field
        KeyCaptureView *keyStrokeCaptureField = (KeyCaptureView *)[keyCaptureCell nestedSubviewsWithIdentifier:@"keyCaptureView"][0];
        
        [keyStrokeCaptureField setupWithCaptureHandler:^(CGKeyCode keyCode, MFSystemDefinedEventType type, CGEventFlags flags) {
            
            BOOL keyCodeValid = keyCode != USHRT_MAX;
            BOOL typeValid = type != UINT_MAX;
            
            assert(!(keyCodeValid && typeValid));
            assert(keyCodeValid || typeValid);
            
            NSDictionary *newEffectDict;
            
            if (keyCodeValid) {
                newEffectDict = @{
                kMFActionDictKeyType: kMFActionDictTypeKeyboardShortcut,
                kMFActionDictKeyKeyboardShortcutVariantKeycode: @(keyCode),
                kMFActionDictKeyKeyboardShortcutVariantModifierFlags: @(flags),
            };
            } else {
                newEffectDict = @{
                    kMFActionDictKeyType: kMFActionDictTypeSystemDefinedEvent,
                    kMFActionDictKeySystemDefinedEventVariantType: @(type),
                    kMFActionDictKeySystemDefinedEventVariantModifierFlags: @(flags),
                };
            }
            
            /// Insert new effectDict into dataModel and reload table
            ///  Manipulating the datamodel should probably be done by RemapTableController, not RemapTableTranslator, and definitely not in this method, but oh well.
            
            NSInteger rowBaseDataModel = [RemapTableUtility baseDataModelIndexFromGroupedDataModelIndex:row withGroupedDataModel:self.groupedDataModel];
            
            self.dataModel[rowBaseDataModel][kMFRemapsKeyEffect] = newEffectDict;
            [self.tableView reloadData];
            [self.controller updateTableAndWriteToConfig:nil];
            
        } cancelHandler:^{
            
            [self.tableView reloadData];
            /// Restore tableView to the ground truth dataModel
            ///  This used to restore original state if the capture field has been created through `reloadDataWithTemporaryDataModel:`
            
        }];
        
        triggerCell = keyCaptureCell;
        
    } else {
        /// Get popup button
        NSPopUpButton *popupButton = triggerCell.subviews[0];
        /// Delete existing menu items from IB
        [popupButton removeAllItems];
        /// Iterate effects table and fill popupButton
        for (NSDictionary *effectTableEntry in effectTable) {
            NSMenuItem *i = [self menuItemFromDataModel:effectTableEntry enclosingMenu:popupButton.menu];
            [popupButton.menu addItem:i];
        }
        
        /// Select popup button item corresponding to datamodel
        /// Get effectDict from datamodel
        NSMenuItem *itemToSelect = [self getPopUpButtonItemToSelectBasedOnRowDict:popupButton rowDict:rowDict];
        if (itemToSelect) {
            [popupButton selectItem:itemToSelect];
            popupButton.toolTip = itemToSelect.toolTip;
        }
        
        /// Disable popupbutton, if tableView is disabled
        popupButton.enabled = tableViewEnabled;
       
    }
    
    return triggerCell;
}

+ (NSTableCellView *)getTriggerCellWithRowDict:(NSDictionary *)rowDict {
    
    rowDict = rowDict.mutableCopy; /// This is necessary for some of this hacky mess to work –– However, this is not a deep copy, so the _dataModel is still changed when we change some nested object. Watch out!
    
    #pragma mark --- Get data ---
    
    id triggerGeneric = rowDict[kMFRemapsKeyTrigger];
    
    /// Get the trigger type
    
    NSString *triggerType; /// Either "_button", "_drag", or "_scroll"
    
    if ([triggerGeneric isKindOfClass:NSDictionary.class]) {
        
        triggerType = @"_button"; /// Using underscore to make clear that this is not a UI string
        
    } else if ([triggerGeneric isKindOfClass:NSString.class]) {
        
        NSString *trigger = (NSString *)triggerGeneric;
        if ([trigger isEqualToString:kMFTriggerDrag]) {
            triggerType = @"_drag";
        } else if ([trigger isEqualToString:kMFTriggerScroll]) {
            triggerType = @"_scroll";
        } else {
            @throw [NSException exceptionWithName:@"Unknown string trigger value" reason:@"The value for the string trigger key is unknown" userInfo:@{@"Trigger value": trigger}];
        }
    } else {
        DDLogInfo(@"Trigger value: %@, class: %@", triggerGeneric, [triggerGeneric class]);
        @throw [NSException exceptionWithName:@"Invalid trigger value type" reason:@"The value for the trigger key is not a String and not a dictionary" userInfo:@{@"Trigger value": triggerGeneric}];
    }
    
    /// Get additional info if buttonTrigger
    
    NSNumber *btn;
    NSNumber *lvl;
    NSString *dur;
    if ([triggerType isEqual: @"_button"]) {
        NSDictionary *trigger = (NSDictionary *)triggerGeneric;
        btn = trigger[kMFButtonTriggerKeyButtonNumber];
        lvl = trigger[kMFButtonTriggerKeyClickLevel];
        dur = trigger[kMFButtonTriggerKeyDuration];
    }
    
    /// Get additional info if drag or scroll trigger
    ///
    /// Extract last button press from button-modification-precondition. If it doesn't exist, extract kb mods
    ///   This info will be used to form the trigger string and will therefore be removed from the modificationPrecondition (That's what we mean by "extract")
    
    NSDictionary *lastButtonPress;
    NSNumber *keyboardModifiers;
    /// TODO: ^ rename these to `buttonForTriggerString` and `flagsForTriggerString` or something similar
    
    if ([triggerType isEqual: @"_drag"] || [triggerType isEqual: @"_scroll"]) {
        
        NSMutableArray *buttonPressSequence = ((NSArray *)rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyButtons]).mutableCopy;
        
        if (buttonPressSequence) {
            /// Extract last button
            lastButtonPress = buttonPressSequence.lastObject;
            [buttonPressSequence removeLastObject];
            rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyButtons] = buttonPressSequence;
        } else if (keyboardModifiers != nil) {
            /// Extract keyboard modifiers
            keyboardModifiers = rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyKeyboard];
            rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyKeyboard] = nil;
        } else {
            @throw [NSException exceptionWithName:@"No precondition" reason:@"Modified drag or scroll has no preconditions" userInfo:@{@"Precond dict": (rowDict[kMFRemapsKeyModificationPrecondition])}];
        }
    }
    
    #pragma mark --- Build strings ---

    /// Define Data-to-UI-String mappings
    NSDictionary *clickLevelToUIString = @{
        @1: @"",
        @2: @"Double ",
        @3: @"Triple ",
    };
    
    /// Get keyboard modifier strings
    
    NSNumber *flags = (NSNumber *)rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyKeyboard];
    NSString *kbModRaw = [UIStrings getKeyboardModifierString:((NSNumber *)flags).unsignedIntegerValue];
    NSString *kbModTooltipRaw = [UIStrings getKeyboardModifierStringToolTip:((NSNumber *)flags).unsignedIntegerValue];
    NSString *kbMod = @"";
    NSString *kbModTool = @"";
    if (![kbModRaw isEqualToString:@""]) {
        kbMod = [kbModRaw stringByAppendingString:@" "]; // @"+ "
        kbModTool = [kbModTooltipRaw stringByAppendingString:@", then "];
    }
    
    /// Get button modifier string
    
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
    
    /// Get main trigger string
    ///     (Naming is confusing since we call three different things the "trigger string")
    
    NSAttributedString *tr;
    NSAttributedString *trTool;
    NSString *mainButtonStr = @"";
    
    if ([triggerType isEqual: @"_button"]) {
        
        /// Generate substrings from data
        
        /// lvl
        NSString *levelStr = (NSString *)clickLevelToUIString[lvl];
        if (!levelStr) {
            levelStr = [NSString stringWithFormat:@"%@", lvl];
        }
        if (lvl.intValue < 1) { // 0 or smaller
            @throw [NSException exceptionWithName:@"Invalid click level" reason:@"Remaps contain invalid click level" userInfo:@{@"Trigger dict containing invalid value": triggerGeneric}];
        }
        /// dur
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
            @throw [NSException exceptionWithName:@"Invalid duration" reason:@"Remaps contain invalid duration" userInfo:@{@"Trigger dict containing invalid value": triggerGeneric}];
        }
        /// btn
        mainButtonStr = [UIStrings getButtonString:btn.intValue];
        NSString *mainButtonStrTool = [UIStrings getButtonStringToolTip:btn.intValue];
        if (btn.intValue < 1) {
            @throw [NSException exceptionWithName:@"Invalid button number" reason:@"Remaps contain invalid button number" userInfo:@{@"Trigger dict containing invalid value": triggerGeneric}];
        }
        
        /// Form trigger string from substrings
        
        NSString *trRaw = [NSString stringWithFormat:@"%@%@", levelStr, durationStr]; // Append buttonStr later depending on whether there are button preconds
        NSString *trToolRaw = [NSString stringWithFormat:@"%@%@%@", levelStr, durationStr, mainButtonStrTool];
        
        /// Turn into attributedString and highlight button substrings
        tr = [[NSAttributedString alloc] initWithString:trRaw];
        trTool = [[NSAttributedString alloc] initWithString:trToolRaw];
//        tr = [tr attributedStringBySettingSecondaryButtonTextColorForSubstring:buttonStr];
//        trTool = [trTool attributedStringBySettingSecondaryButtonTextColorForSubstring:buttonStrTool];
        
    } else if ([triggerType isEqual: @"_drag"] || [triggerType isEqual: @"_scroll"]) {
        /// We need part of the modification precondition to form the main trigger string here.
        ///  E.g. if our precondition for a modified drag is single click button 3, followed by double click button 4, we want the string to be "Click Middle Button + Double Click and Drag Button 4", where the "Click Middle Button + " substring follows the format of a regular modification precondition string (we compute those further down) but the "Double Click and Drag Button 4" substring, which is also called the "trigger string" follows a different format which we compute here.
        /// Get button strings from last button precond, or, if no button preconds exist, get keyboard modifier string
        NSString *levelStr = @"";
        NSString *clickStr = @"";
        mainButtonStr = @"";
        NSString *keyboardModStr = @"";
        NSString *mainButtonStrTool = @"";
        NSString *keyboardModStrTool = @"";
        
        if (lastButtonPress) {
            /// Generate Level, click, and button strings based on last button press from sequence
            NSNumber *btn = lastButtonPress[kMFButtonModificationPreconditionKeyButtonNumber];
            NSNumber *lvl = lastButtonPress[kMFButtonModificationPreconditionKeyClickLevel];
            levelStr = clickLevelToUIString[lvl];
            clickStr = @"Click and ";
            mainButtonStr = [UIStrings getButtonString:btn.intValue];
            mainButtonStrTool = [UIStrings getButtonStringToolTip:btn.intValue];
        } else if (keyboardModifiers != nil) {
            /// Get keyboard mod string
            keyboardModStr = [UIStrings getKeyboardModifierString:((NSNumber *)keyboardModifiers).unsignedIntegerValue];
            keyboardModStr = [keyboardModStr stringByAppendingString:@" and "];
            keyboardModStrTool = [UIStrings getKeyboardModifierStringToolTip:((NSNumber *)keyboardModifiers).unsignedIntegerValue];
        } else assert(false);
        
        /// Get trigger string
        NSString *triggerStr;
        if ([triggerType isEqual: @"_drag"]) {
            triggerStr = @"Drag ";
        } else if ([triggerType isEqual: @"_scroll"]) {
            triggerStr = @"Scroll ";
        } else assert(false);
        
        /// Form full trigger cell string from substrings
        
        NSString *trRaw = [NSString stringWithFormat:@"%@%@%@%@", levelStr, clickStr, keyboardModStr, triggerStr]; /// Append buttonStr later depending on whether there are button preconds
        NSString *trToolRaw = [NSString stringWithFormat:@"%@%@%@%@%@", levelStr, clickStr, keyboardModStrTool, triggerStr, mainButtonStrTool];
        
        /// Turn into attributedString
        tr = [[NSAttributedString alloc] initWithString:trRaw];
        trTool = [[NSAttributedString alloc] initWithString:trToolRaw];
        
        /// highlight button substrings
//        tr = [tr attributedStringBySettingSecondaryButtonTextColorForSubstring:buttonStr];
//        trTool = [trTool attributedStringBySettingSecondaryLabelColorForSubstring:buttonStrTool];
        
        /// De-emphasize click string
        ///     Looks weird when you have "Double _Click and_ Drag"
//        tr = [tr attributedStringBySettingSecondaryButtonTextColorForSubstring: clickStr]; /// `attributedStringBySettingSecondaryButtonTextColorForSubstring` is specifically intended for buttons, which is not what we're using it for here
        
        /// Slightly emphasize trigger string
        tr = [tr attributedStringByAddingSemiBoldForSubstring:triggerStr];
        tr = [tr attributedStringBySettingSemiBoldColorForSubstring:triggerStr];
        
    } else assert(false);
    
    /// Get effect string
    NSString *effectString = [NSString stringWithFormat:@" to use '%@'", effectNameForRowDict(rowDict)];
    
    /// Append buttonStr
    if (![btnMod isEqual:@""]) { /// Only display main button string in case there are button modifiers
        NSMutableAttributedString *trMutable = tr.mutableCopy;
        [trMutable appendAttributedString:[[NSAttributedString alloc] initWithString:mainButtonStr]];
        tr = [trMutable attributedStringBySettingSecondaryButtonTextColorForSubstring:mainButtonStr];
    }
    
    /// Join all substrings to get result string
    NSMutableAttributedString *fullTriggerCellString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@", kbMod, btnMod]];
    NSMutableAttributedString *fullTriggerCellTooltipString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@", kbModTool, btnModTool]];
    [fullTriggerCellString appendAttributedString:tr];
    [fullTriggerCellTooltipString appendAttributedString:trTool];
    [fullTriggerCellTooltipString appendAttributedString:[[NSMutableAttributedString alloc] initWithString:effectString]];
    
    #pragma mark --- Create view ---
    
    /// Generate view and set string to view
    NSTableCellView *triggerCell = [self.tableView makeViewWithIdentifier:@"triggerCell" owner:nil];
    triggerCell.textField.attributedStringValue = fullTriggerCellString;
    triggerCell.textField.toolTip = fullTriggerCellTooltipString.string;
    return triggerCell;
    
}

@end
