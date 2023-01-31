//
// --------------------------------------------------------------------------
// RemapTableDataSource.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
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
#import "Mac_Mouse_Fix-Swift.h"

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
/// ^ Effects tables are one-to-one mappings between UI stirngs and effect dicts. The effect dicts encode the exact effect in a way the helper can read
/// They are used to generate the popup button menus and relate between the data model (which contains effectDicts) and the UI (which contains UI stirngs)
/// Effects tables are arrays of dictionaries called effect table entries. Table entries currently support the folling keys:
///  "ui" - The main UI string of the effect. This will be the title of the popupbutton-menu-item for the effect
///  "tool" - Tooltip of the popupbutton-menu-item
///  "dict" - The effect dict
///  "alternate" - If set to @YES, this entry will revealed by pressing a modifier key in the popupbutton menu
/// TODO: ? Create constants for these keys
/// There are also separatorTableEntry()s which become a separator in the popupbutton-menu generated from the effectsTable
/// There are 3 different effectsTables for 3 different types of triggers
/// Noah from future: an 'effectsTable' should probably be called an 'effectButtonMenuModel' or 'effectsMenuModel' or 'effectOptionsModel' or something else that's more descriptive and less close to 'remapsTable'

static NSDictionary *separatorEffectsTableEntry() {
    return @{@"isSeparator": @YES};
}
//static NSDictionary *hideableSeparatorEffectsTableEntry() {
//    return @{@"isSeparator": @YES, @"hideable": @YES}; /// This doesn't work ;/
//}
static NSArray *getScrollEffectsTable() {
    NSArray *scrollEffectsTable = @[
        @{@"ui": NSLocalizedString(@"scroll-effect.4-pinch", @"First draft: Desktop & Launchpad") , @"tool": NSLocalizedString(@"scroll-effect.4-pinch.hint", @"First draft: Scroll up for Launchpad and down to show the Desktop\n \nWorks like Pinching with 4 fingers on an Apple Trackpad"), @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeFourFingerPinch
        }},
        @{@"ui": NSLocalizedString(@"scroll-effect.spaces", @"First draft: Move Between Spaces"), @"tool": NSLocalizedString(@"scroll-effect.spaces.hint", @"First draft: Scroll up to move left a Space and down to move right a Space\n \nWorks like swiping horizontally with 3 fingers on an Apple Trackpad"), @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeThreeFingerSwipeHorizontal
        }}, /// Removed this in 3.0.0 Beta 6 but MAK1023 wanted it back https://github.com/noah-nuebling/mac-mouse-fix/discussions/495. Should remove this once Click and Drag for Spaces & Mission Control is an adequate replacement for MAK1023.
        separatorEffectsTableEntry(),
        @{@"ui": NSLocalizedString(@"scroll-effect.zoom", @"First draft: Zoom In or Out"), @"tool": NSLocalizedString(@"scroll-effect.zoom.hint", @"First draft: Zoom in or out in Safari, Maps and other apps\n \nWorks like pinching to zoom on an Apple trackpad") , @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeZoom
        }},
        @{@"ui": NSLocalizedString(@"scroll-effect.horizontal", @"First draft: Horizontal Scroll"), @"tool": NSLocalizedString(@"scroll-effect.horizontal.hint", @"First draft: Scroll left and right, navigate between pages in Safari, delete messages in Mail and more\n \nWorks like swiping horizontally with 2 fingers on an Apple Trackpad"), @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeHorizontalScroll
        }},
        @{@"ui": NSLocalizedString(@"scroll-effect.rotate", @"First draft: Rotate"), @"hideable": @NO, @"tool": NSLocalizedString(@"scroll-effect.rotate.hint", @"First draft: Rotate content in Apple Maps and other apps\n \nWorks like twisting with 2 fingers on an Apple Trackpad"), @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeRotate
        }}, /// We only have this option so the menu layout looks better. I can't really think of a usecase
        separatorEffectsTableEntry(),
        @{@"ui": NSLocalizedString(@"scroll-effect.swift", @"First draft: Swift Scroll"), @"tool": NSLocalizedString(@"scroll-effect.swift.hint", @"Scroll long distances with minimal effort"), @"dict": @{
            kMFModifiedScrollDictKeyInputModificationType: kMFModifiedScrollInputModificationTypeQuickScroll
        }},
        @{@"ui": NSLocalizedString(@"scroll-effect.precise", @"First draft: Precise Scroll"), @"tool": NSLocalizedString(@"scroll-effect.precise.hint", @"First draft: Scroll small distances and use sensitive UI elements with precision"), @"dict": @{
            kMFModifiedScrollDictKeyInputModificationType: kMFModifiedScrollInputModificationTypePrecisionScroll
        }},
//        separatorEffectsTableEntry(),
//        @{@"ui": NSLocalizedString(@"scroll-effect.app-switcher", @"First draft: App Switcher"), @"tool": NSLocalizedString(@"scroll-effect.app-switcher.hint", @"First draft: Quickly switch between open apps\n \nWorks like holding Command (⌘) and then pressing Tab (⇥) on your keyboard"), @"dict": @{
//            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeCommandTab
//        }},
        
    ];
    return scrollEffectsTable;
}
static NSArray *getDragEffectsTable() {
    NSArray *dragEffectsTable = @[
        @{@"ui": NSLocalizedString(@"drag-effect.dock-swipe", @"First draft: Spaces & Mission Control"), @"tool": NSLocalizedString(@"drag-effect.dock-swipe.hint", @"First draft: Move your mouse:\n - Up to show Mission Control\n - Down to show Application Windows\n - Left or Right to move between Spaces\n \nWorks like swiping with 3 fingers on an Apple Trackpad") , @"dict": @{
                  kMFModifiedDragDictKeyType: kMFModifiedDragTypeThreeFingerSwipe,
        }},
        @{@"ui": NSLocalizedString(@"drag-effect.scroll-swipe", @"First draft: Scroll & Navigate"), @"tool": NSLocalizedString(@"drag-effect.scroll-swipe.hint", @"First draft: Scroll freely by moving your mouse in any direction\n \nAlso Navigate between pages in Safari, delete messages in Mail and more by moving your mouse left and right\n \nWorks like swiping with 2 fingers on an Apple Trackpad") , @"dict": @{
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
    
//    MFMouseButtonNumber buttonNumber = ((NSNumber *)rowDict[kMFRemapsKeyTrigger][kMFButtonTriggerKeyButtonNumber]).unsignedIntValue;
    
    NSDictionary *effectDict = rowDict[kMFRemapsKeyEffect];
    
    NSMutableArray *oneShotEffectsTable = @[
        @{@"ui": NSLocalizedString(@"effect.look-up", @"First draft: Look Up & Quick Look"), @"tool": NSLocalizedString(@"effect.look-up.hint", @"First draft: Look up words in the Dictionary, Quick Look files in Finder, and more.\n \nWorks like a Force click on an Apple Trackpad."), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHLookUp)
        }},
        @{@"ui": NSLocalizedString(@"effect.smart-zoom", @"First draft: Smart Zoom"), @"tool": NSLocalizedString(@"effect.smart-zoom.hint", @"First draft: Zoom in or out in Safari and other apps.\n \nWorks like a two-finger double tap on an Apple Trackpad."), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSmartZoom,
        }},
        @{@"ui": NSLocalizedString(@"effect.middle-click", @"First draft: Middle Click"),
          @"tool": stringf(NSLocalizedString(@"effect.middle-click.hint", @"First draft: Open links in a new tab, paste text in the Terminal, and more.\n \nWorks like clicking %@ on a standard mouse."), [UIStrings getButtonStringToolTip:3]),
          @"dict": @{
              kMFActionDictKeyType: kMFActionDictTypeMouseButtonClicks,
              kMFActionDictKeyMouseButtonClicksVariantButtonNumber: @3,
              kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks: @1,
          }
        },
        separatorEffectsTableEntry(),
        @{@"ui": NSLocalizedString(@"effect.back", @"First draft: Back"), @"tool": NSLocalizedString(@"effect.back.hint", @"First draft: Go back one page in Safari and other apps"), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeNavigationSwipe,
                  kMFActionDictKeyGenericVariant: kMFNavigationSwipeVariantLeft
        }},
        @{@"ui": NSLocalizedString(@"effect.forward", @"First draft: Forward"), @"tool": NSLocalizedString(@"effect.forward.hint", @"First draft: Go forward one page in Safari and other apps"), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeNavigationSwipe,
                  kMFActionDictKeyGenericVariant: kMFNavigationSwipeVariantRight
        }},
        separatorEffectsTableEntry(),
        @{@"ui": NSLocalizedString(@"effect.mission-control", @"First draft: Mission Control"), @"tool": NSLocalizedString(@"effect.mission-control.hint", @"First draft: Show Mission Control"), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHMissionControl)
        }}, /// I removed actions that are redundant to the Click and Drag for Spaces & Mission Control feature in 3.0.0 Beta 6 but  people complained https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue+label%3A%223.0.0+Beta+6+Removed+Actions%22
        @{@"ui": NSLocalizedString(@"effect.app-expose", @"First draft: Application Windows"), @"tool": NSLocalizedString(@"effect.app-expose.hint", @"First draft: Show all windows of the active app"), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHAppExpose)
        }},
        @{@"ui": NSLocalizedString(@"effect.desktop", @"First draft: Show Desktop"), @"tool": NSLocalizedString(@"effect.desktop.hint", @"First draft: Show the desktop"), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHShowDesktop)
        }},
        separatorEffectsTableEntry(),
        @{@"ui": NSLocalizedString(@"effect.launchpad", @"First draft: Launchpad"), @"tool": NSLocalizedString(@"effect.launchpad.hint", @"First draft: Open Launchpad"), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHLaunchpad)
        }},
        separatorEffectsTableEntry(),
        @{@"ui": NSLocalizedString(@"effect.left-space", @"First draft: Move Left a Space"), @"tool": NSLocalizedString(@"effect.left-space.hint", @"First draft: Move one Space to the left"), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHMoveLeftASpace)
        }},
        @{@"ui": NSLocalizedString(@"effect.right-space", @"First draft: Move Right a Space"), @"tool": NSLocalizedString(@"effect.right-space.hint", @"First draft: Move one Space to the right"), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHMoveRightASpace)
        }},
        separatorEffectsTableEntry(),
        @{@"ui": NSLocalizedString(@"effect.record-shortcut", @"First draft: Keyboard Shortcut..."), @"tool": NSLocalizedString(@"effect.record-shortcut.hint", @"First draft: Type a keyboard shortcut, then use it from your mouse"), @"keyCaptureEntry": @YES},
    ].mutableCopy;
    
    /// Insert button specific entry
    ///     Disabling this for now because I don't want to translate it and noone uses it.
    
//    if (buttonNumber != 3) { /// We already have the "Open Link in New Tab" / "Middle Click" entry for button 3
//        NSDictionary *buttonClickEntry = @{
//            @"ui": [NSString stringWithFormat:@"%@ Click", [UIStrings getButtonString:buttonNumber]],
//            @"tool": [NSString stringWithFormat:@"Simulate Clicking %@", [UIStrings getButtonStringToolTip:buttonNumber]],
//            @"hideable": @NO,
//            @"alternate": @YES,
//            @"dict": @{
//                    kMFActionDictKeyType: kMFActionDictTypeMouseButtonClicks,
//                    kMFActionDictKeyMouseButtonClicksVariantButtonNumber: @(buttonNumber),
//                    kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks: @1,
//            }
//        };
//        [oneShotEffectsTable insertObject:buttonClickEntry atIndex:10];
//    }
    
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
            @"tool": stringf(NSLocalizedString(@"effect.shortcut.hint", @"First draft: Works like pressing '%@' on your keyboard"), shortcutStringRaw),
            @"dict": effectDict,
            @"indentation": @1,
        } atIndex:shortcutIndex];
    }
    
    /// Insert hidden submenu for  apple specific keys
    
    int separator = -1;
    
    MFSystemDefinedEventType systemEventTypes[] = {
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
                @"tool": stringf(NSLocalizedString(@"effect.apple-shortcut.hint", @"First draft: Works like pressing '%@' on an Apple keyboard"), shortcutStringRaw),
                @"dict": actionDict
            }];
        }
    }
    
    [oneShotEffectsTable insertObject:@{
        @"ui": NSLocalizedString(@"effect.apple-keys-submenu", @"First draft:  Exclusive Keys"),
        @"tool": NSLocalizedString(@"effect.apple-keys-submenu.hint", @"First draft: Choose keys that are only available on Apple keyboards"),
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
        
        return [UIStrings getStringForKeyCode:keyCode flags:flags font:[NSFont systemFontOfSize:NSFont.systemFontSize]];
        
    } else { /// Is systemEventShortcut
        
        MFSystemDefinedEventType type = ((NSNumber *)effectDict[kMFActionDictKeySystemDefinedEventVariantType]).unsignedIntValue;
        CGEventFlags flags = ((NSNumber *)effectDict[kMFActionDictKeySystemDefinedEventVariantModifierFlags]).unsignedLongValue;
        
        return [UIStrings getStringForSystemDefinedEvent:type flags:flags font:[NSFont systemFontOfSize:NSFont.systemFontSize]];
    }
}

/// Convenience functions for effects tables

/// We wanted to rename 'effects table' to 'effects menu model', but we only did it in a few places. Thats why this is named weird
+ (NSDictionary * _Nullable)getEntryFromEffectTable:(NSArray *)effectTable withEffectDict:(NSDictionary *)effectDict {
    
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
    
    /// Get info about what kind of trigger we're dealing with
    NSString *triggerType = @""; /// Options "oneShot", "drag", "scroll"
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
//        NSDictionary *buttonTriggerDict = (NSDictionary *)triggerValue;
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

+ (NSMenuItem *)menuItemFromDataModel:(NSDictionary *)itemModel enclosingMenu:(NSMenu *)enclosingMenu tableCell:(NSTableCellView *)tableCell {
    
    RemapTableMenuItem *i;
    
    if ([itemModel[@"isSeparator"] isEqual: @YES]) {
        
        i = (RemapTableMenuItem *)RemapTableMenuItem.separatorItem;
        
        /// IDEA: Add a "bigSeparator" for 2 level grouping and easier visual parsing
        
    } else {
        
        i = [[RemapTableMenuItem alloc] init];
        
        NSString *title = itemModel[@"ui"];
        if (title != nil) {
            i.title = title;
        } else {
            i.attributedTitle = itemModel[@"uiAttributed"];
        }
        i.action = @selector(updateTableAndWriteToConfig:);
        i.target = self.tableView.delegate;
        i.toolTip = itemModel[@"tool"];
        i.host = tableCell;
        
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
                NSMenuItem *subI = [self menuItemFromDataModel:submenuItemModel enclosingMenu:m tableCell:tableCell];
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

#pragma mark - Create Effect View

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
    
    if ([effectDict[@"drawKeyCaptureView"] isEqual:@YES]) { /// This is not a real effectDict, but instead an instruction to draw a key capture view
        
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
            NSMenuItem *i = [self menuItemFromDataModel:effectTableEntry enclosingMenu:popupButton.menu tableCell:triggerCell];
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
        ///     TODO: This shouldn't be necessary in MMF3. Remove code for disabling the tableView
        popupButton.enabled = tableViewEnabled;
       
    }
    
    return triggerCell;
}

#pragma mark - Create Trigger View


+ (NSTableCellView *)getTriggerCellWithRowDict:(NSDictionary *)rowDict row:(NSInteger)row {
    
    /// Create mutable copy
    /// Necessary for some of this hacky mess to work –– However, this is not a deep copy, so the `_dataModel` is still changed when we change some nested object. Watch out!
    
    /// With the MMF3 localization rewrite we removed tooltips from the trigger cells. Commit 87ffe81ebb6b0b231d4d204848def15742fd40cb is the last with the old logic + tooltips.
    
    rowDict = rowDict.mutableCopy;
    
    #pragma mark --- Get data ---
    
    id triggerGeneric = rowDict[kMFRemapsKeyTrigger];
    
    /// Get the trigger type
    
    NSString *triggerType; /// Either `_button`, `_drag`, or `_scroll`
    
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
    
    /// Get additional trigger info
        
    NSNumber *btn;
    NSNumber *lvl;
    NSString *dur; /// Only used for button trigger
    BOOL flagsOnlyPrecond = NO;
    
    if ([triggerType isEqual: @"_button"]) {
        
        NSDictionary *trigger = (NSDictionary *)triggerGeneric;
        btn = trigger[kMFButtonTriggerKeyButtonNumber];
        lvl = trigger[kMFButtonTriggerKeyClickLevel];
        dur = trigger[kMFButtonTriggerKeyDuration];
        
    } else if ([triggerType isEqual: @"_drag"] || [triggerType isEqual: @"_scroll"]) {
        
        /// Extract last button press from button-modification-precondition. If it doesn't exist, extract kb mods
        ///   This info will be used to form the trigger string and will therefore be removed from the modificationPrecondition
        
        NSMutableArray *buttonPressSequence = ((NSArray *)rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyButtons]).mutableCopy;
        
        if (buttonPressSequence) {
            
            /// Extract last button
            btn = buttonPressSequence.lastObject[kMFButtonModificationPreconditionKeyButtonNumber];
            lvl = buttonPressSequence.lastObject[kMFButtonModificationPreconditionKeyClickLevel];
            
            /// Remove last button from precondition
            [buttonPressSequence removeLastObject];
            rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyButtons] = buttonPressSequence;
            
        } else if (rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyKeyboard] != nil) {
            
            /// There are no button preconds but there are keyboard modifier preconds - we can deal with it
            flagsOnlyPrecond = YES;
            
        } else {
            @throw [NSException exceptionWithName:@"No precondition" reason:@"Modified drag or scroll has no preconditions" userInfo:@{@"Precond dict": (rowDict[kMFRemapsKeyModificationPrecondition])}];
        }
        
    } else {
        assert(false);
    }
    
    #pragma mark --- Build strings ---
    
    /// Build main trigger string
    ///     (Naming is confusing since we call three different things the "trigger string")
    
    NSAttributedString *tr = nil;
    
    if ([triggerType isEqual: @"_button"]) {
            
        ///
        /// Button trigger
        ///
        
        /// Declare map
        
        NSDictionary *map = @{
            @[@(1), @"click"]:  NSLocalizedString(@"trigger.click.1",   @"First draft: Click %@ || Note: %@ will be a button name || Example where %@ is 'Button 5': ⌥⌘ Double Click Button 4 + Click Button 5 || Note: Most of the substrings that are used to build the Action Table Trigger Strings (this is one of those substrings) are capitalized in English because it's common to use 'title case' there. In your language, 'title case' might not be a thing, and so you might not want to capitalize these strings. The first letter of the trigger string will be programmatically capitalized in any language."),
            
            @[@(2), @"click"]:  NSLocalizedString(@"trigger.click.2",   @"First draft: Double Click %@"),
            @[@(3), @"click"]:  NSLocalizedString(@"trigger.click.3",   @"First draft: Triple Click %@"),
            @[@(1), @"hold"]:   NSLocalizedString(@"trigger.hold.1",    @"First draft: Hold %@"),
            @[@(2), @"hold"]:   NSLocalizedString(@"trigger.hold.2",    @"First draft: Double Click and Hold %@"),
            @[@(3), @"hold"]:   NSLocalizedString(@"trigger.hold.3",    @"First draft: Triple Click and Hold %@"),
        };
        
        /// Get string
        
        tr = [map[@[lvl, dur]] attributed]; /// Append buttonStr later depending on whether there are button preconds
        
        /// Validate
        
        if (!tr) {
            @throw [NSException exceptionWithName:@"Couldn't generate trigger string" reason:@"" userInfo:@{@"Trigger dict containing invalid value": triggerGeneric}];
        }
        
    } else if ([triggerType isEqual: @"_drag"] || [triggerType isEqual: @"_scroll"]) {
        
        ///
        /// Drag or scroll trigger
        ///
        
        /// TODO: Comment below is obsolete. Remove.
        /// We need part of the modification precondition to form the main trigger string here.
        ///  E.g. if our precondition for a modified drag is single click button 3, followed by double click button 4, we want the string to be "Click Middle Button + Double Click and Drag Button 4", where the "Click Middle Button + " substring follows the format of a regular modification precondition string (we compute those further down) but the "Double Click and Drag Button 4" substring, which is also called the "trigger string" follows a different format which we compute here.
        /// Get button strings from last button precond, or, if no button preconds exist, get keyboard modifier string
        
        
        /// Define maps
        
        NSDictionary *map = @{
            @[@(1), @"_drag"]:      NSLocalizedString(@"trigger.drag.1",    @"First draft: Click and Drag %@ || Note: %@ will be a button name || example where %@ is 'Button 5': ⌥⌘ Triple Click Button 4 + Click and Drag Button 5"),
            @[@(2), @"_drag"]:      NSLocalizedString(@"trigger.drag.2",    @"First draft: Double Click and Drag %@"),
            @[@(3), @"_drag"]:      NSLocalizedString(@"trigger.drag.3",    @"First draft: Triple Click and Drag %@"),
            @[@(1), @"_scroll"]:    NSLocalizedString(@"trigger.scroll.1",  @"First draft: Click and Scroll %@"),
            @[@(2), @"_scroll"]:    NSLocalizedString(@"trigger.scroll.2",  @"First draft: Double Click and Scroll %@"),
            @[@(3), @"_scroll"]:    NSLocalizedString(@"trigger.scroll.3",  @"First draft: Triple Click and Scroll %@"),
        };
        
        NSDictionary *onlyFlagsMap = @{
            @"_drag":   NSLocalizedString(@"trigger.drag.flags", @"First draft: and Drag || Note: This will be used for Drag Actions that only need keyboard modifiers to be activated - not mouse buttons || Example: ⌥⌘ and Drag"),
            @"_scroll": NSLocalizedString(@"trigger.scroll.flags", @"First draft: and Scroll || Example: ⌥⌘ and Scroll"),
        };
        
        /// Use maps
        
        NSString *tr_;
        
        if (btn != nil) {
            tr_ = map[@[lvl, triggerType]];
        } else {
            assert(flagsOnlyPrecond); /// If there are no buttons we need at least keyboard modifiers in the precondition
            tr_ = onlyFlagsMap[triggerType];
        }
        
        /// Make attributed
        
        tr = tr_.attributed;
        
        /// Slighly emphasize `Drag` and `Scroll` for better legibility
        
        NSString *dragParticle =    NSLocalizedString(@"trigger.drag-particle",  @"First draft: Drag || Note: This substring will be emphasized in drag trigger strings like 'Double Click and Drag %@'");
        NSString *scrollParticle =  NSLocalizedString(@"trigger.scroll-particle", @"First draft: Scroll || Note: This substring will be emphasized in scroll trigger strings like 'Triple Click and Scroll %@'");
        
        tr = [tr attributedStringByAddingSemiBoldForSubstring:dragParticle];
        tr = [tr attributedStringByAddingSemiBoldForSubstring:scrollParticle];
        tr = [tr attributedStringBySettingSemiBoldColorForSubstring:dragParticle];
        tr = [tr attributedStringBySettingSemiBoldColorForSubstring:scrollParticle];
    }
    
    /// Validate
    
    NSAssert(tr != nil && ![tr.string isEqual:@""], @"Trigger string is empty. This is probably because there are missing translations. Translate strings starting with `trigger.` to fix this.");
    
    ///
    /// Build button modifier string
    ///

    NSString *btnMod;
    
    NSMutableArray *buttonPressSequence = rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyButtons];
    NSMutableArray *buttonModifierStrings = [NSMutableArray array];
    
    for (NSDictionary *buttonPress in buttonPressSequence) {
        NSNumber *btn = buttonPress[kMFButtonModificationPreconditionKeyButtonNumber];
        NSNumber *lvl = buttonPress[kMFButtonModificationPreconditionKeyClickLevel];
        NSString *buttonStr;
        buttonStr = [UIStrings getButtonString:btn.intValue];
        
        NSString *buttonModString;
        if (lvl.intValue == 1) {
            buttonModString = stringf(NSLocalizedString(@"button-modifier.1", @"First draft: Click %@ + || Note: %@ will be a button name || Example where %@ is 'Button 4': Click Button 4 + Double Click and Drag Button 5"), buttonStr);
        } else if (lvl.intValue == 2) {
            buttonModString = stringf(NSLocalizedString(@"button-modifier.2", @"First draft: Double Click %@ + "), buttonStr);
        } else if (lvl.intValue == 3) {
            buttonModString = stringf(NSLocalizedString(@"button-modifier.3", @"First draft: Triple Click %@ + "), buttonStr);
        } else {
            @throw [NSException exceptionWithName:@"Invalid click level" reason:@"Modification precondition contains undisplayable click level" userInfo:@{@"Trigger dict containing invalid value": triggerGeneric}];
        }
        buttonModString = buttonModString.firstCapitalized; /// Capitalize each button mod string.
        [buttonModifierStrings addObject:buttonModString];
    }
    if (buttonModifierStrings.count > 0) {
        btnMod = [buttonModifierStrings componentsJoinedByString:@""];
    } else {
        btnMod = @"";
    }
    
    
    ///
    /// Build keyboad modifier string
    ///
    
    NSNumber *flags = rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyKeyboard];
    NSString *kbMod = [UIStrings getKeyboardModifierString:flags.unsignedIntegerValue];
    
    ///
    /// Post processing on the substrings
    ///
    
    if (![btnMod isEqual:@""]) {
        
        /// Display main button – only if there *are* button modifiers
        
        NSAttributedString *mainButton = [UIStrings getButtonString:btn.intValue].attributed;
        mainButton = [mainButton attributedStringByAddingColor:NSColor.secondaryLabelColor forRange:NULL];
        tr = [NSAttributedString attributedStringWithAttributedFormat:tr args:@[mainButton]];
        
    } else {
        
        /// If there are no button modifiers, just remove the `%@` format string
        
        tr = [NSAttributedString attributedStringWithAttributedFormat:tr args:@[@"".attributed]];
    }
    
    
    /// Capitalize trigger string
    ///     (The button mod string is already capitalized further up)
    ///     Need to trim whitespace because if the main button isn't displayed, there's a space at the start in German.
    ///     Hopefully this capitalization stuff is universal and doesn't break in some languages. It makes things look much better in German and English.
    
    tr = [tr attributedStringByTrimmingWhitespace];
    tr = [tr attributedStringByCapitalizingFirst];
    
    ///
    /// Join all substrings to get result
    ///
    
    NSAttributedString *fullTriggerCellString = [NSAttributedString attributedStringWithAttributedFormat:@"%@ %@ %@".attributed args:@[kbMod.attributed, btnMod.attributed, tr]];
    
    /// Clean up string
    fullTriggerCellString = [fullTriggerCellString attributedStringByTrimmingWhitespace];
    
    #pragma mark --- Create view ---
    
    /// Create view
    RemapTableCellView *triggerCell = [self.tableView makeViewWithIdentifier:@"triggerCell" owner:nil];

    /// Do cool custom stuff
    ///     We have to do this 
//    [triggerCell coolInit];
    
    /// Set string
    triggerCell.textField.attributedStringValue = fullTriggerCellString;
    triggerCell.textField.toolTip = nil;
    
    /// Hook up delete button
    RemapTableButton *deleteButton = (RemapTableButton *)[triggerCell subviewsWithIdentifier:@"deleteButton"][0];
    deleteButton.host = triggerCell; /// Hope this doesn't cause retain cycles
    deleteButton.action = @selector(inRowRemoveButtonAction:);
    deleteButton.target = self.controller;
    
    /// Override image on older macOS
    ///  Explanation: Try to fix weird margins / dimensions under older macOS versions. So far nothing works.
    ///  Note: Also see where we override plusIconView.image in ButtonTabController
    if (@available(macOS 11.0, *)) { } else {
        
        NSImage *plusImage = [NSImage imageNamed:NSImageNameRemoveTemplate];
        plusImage.size = NSMakeSize(plusImage.size.width + 6.0, plusImage.size.height);
        deleteButton.image = plusImage;
        
//        for (NSLayoutConstraint *c in deleteButton.constraints) {
//            if (c.firstAttribute == NSLayoutAttributeWidth) {
//                c.constant = 20; /// In IB it's set to 15 at time of writing
//                break;
//            }
//        }
    }

    /// Return view!
    return triggerCell;
    
}

@end
