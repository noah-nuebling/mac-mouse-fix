//
// --------------------------------------------------------------------------
// RemapTableDataSource.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
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
    
    /// NOTES:
    ///     If you change effects tables, update the config version in **default_config.plist**. Otherwise there might be crash-loops after upgrading/downgrading.
    
    NSArray *scrollEffectsTable = @[
        @{@"ui": NSLocalizedString(@"scroll-effect.4-pinch", @"") , @"tool": NSLocalizedString(@"scroll-effect.4-pinch.hint", @""), @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeFourFingerPinch
        }},
        @{@"ui": NSLocalizedString(@"scroll-effect.spaces", @""), @"tool": NSLocalizedString(@"scroll-effect.spaces.hint", @""), @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeThreeFingerSwipeHorizontal
        }}, /// Removed this in 3.0.0 Beta 6 but MAK1023 wanted it back https://github.com/noah-nuebling/mac-mouse-fix/discussions/495. Should remove this once Click and Drag for Spaces & Mission Control is an adequate replacement for MAK1023.
        separatorEffectsTableEntry(),
        @{@"ui": NSLocalizedString(@"scroll-effect.zoom", @""), @"tool": NSLocalizedString(@"scroll-effect.zoom.hint", @"") , @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeZoom
        }},
        @{@"ui": NSLocalizedString(@"scroll-effect.horizontal", @""), @"tool": NSLocalizedString(@"scroll-effect.horizontal.hint", @""), @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeHorizontalScroll
        }},
        @{@"ui": NSLocalizedString(@"scroll-effect.rotate", @""), @"hideable": @NO, @"tool": NSLocalizedString(@"scroll-effect.rotate.hint", @""), @"dict": @{
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeRotate
        }}, /// We only have this option so the menu layout looks better. I can't really think of a usecase
        separatorEffectsTableEntry(),
        @{@"ui": NSLocalizedString(@"scroll-effect.swift", @""), @"tool": NSLocalizedString(@"scroll-effect.swift.hint", @""), @"dict": @{
            kMFModifiedScrollDictKeyInputModificationType: kMFModifiedScrollInputModificationTypeQuickScroll
        }},
        @{@"ui": NSLocalizedString(@"scroll-effect.precise", @""), @"tool": NSLocalizedString(@"scroll-effect.precise.hint", @""), @"dict": @{
            kMFModifiedScrollDictKeyInputModificationType: kMFModifiedScrollInputModificationTypePrecisionScroll
        }},
//        separatorEffectsTableEntry(),
//        @{@"ui": NSLocalizedString(@"scroll-effect.app-switcher", @""), @"tool": NSLocalizedString(@"scroll-effect.app-switcher.hint", @""), @"dict": @{
//            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeCommandTab
//        }},
        
    ];
    return scrollEffectsTable;
}
static NSArray *getDragEffectsTable() {
    NSArray *dragEffectsTable = @[
        @{@"ui": NSLocalizedString(@"drag-effect.dock-swipe", @""), @"tool": NSLocalizedString(@"drag-effect.dock-swipe.hint", @"") , @"dict": @{
                  kMFModifiedDragDictKeyType: kMFModifiedDragTypeThreeFingerSwipe,
        }},
        @{@"ui": NSLocalizedString(@"drag-effect.scroll-swipe", @""), @"tool": NSLocalizedString(@"drag-effect.scroll-swipe.hint", @"") , @"dict": @{
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
    
    NSDictionary *selectedEffect = rowDict[kMFRemapsKeyEffect];
    
    NSMutableArray *oneShotEffectsTable = @[
        @{@"ui": NSLocalizedString(@"effect.look-up", @""), @"tool": NSLocalizedString(@"effect.look-up.hint", @"Note: 'Force click' looks a bit weirdly capitalized but it's exactly how Apple spells it on their support website."), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHLookUp)
        }},
        @{@"ui": NSLocalizedString(@"effect.smart-zoom", @""), @"tool": NSLocalizedString(@"effect.smart-zoom.hint", @""), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSmartZoom,
        }},
        @{@"ui": NSLocalizedString(@"effect.click.primary", @""),
          @"tool": NSLocalizedString(@"effect.click.primary.hint", @""),
          @"hideable": @YES,
          @"dict": @{
              kMFActionDictKeyType: kMFActionDictTypeMouseButtonClicks,
              kMFActionDictKeyMouseButtonClicksVariantButtonNumber: @1,
              kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks: @1,
          }
        },
        @{@"ui": NSLocalizedString(@"effect.click.secondary", @""),
          @"tool": NSLocalizedString(@"effect.click.secondary.hint", @""),
          @"hideable": @YES,
          @"dict": @{
              kMFActionDictKeyType: kMFActionDictTypeMouseButtonClicks,
              kMFActionDictKeyMouseButtonClicksVariantButtonNumber: @2,
              kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks: @1,
          }
        },
        @{@"ui": NSLocalizedString(@"effect.click.middle", @""),
          @"tool": NSLocalizedString(@"effect.click.middle.hint", @""),
          @"dict": @{
              kMFActionDictKeyType: kMFActionDictTypeMouseButtonClicks,
              kMFActionDictKeyMouseButtonClicksVariantButtonNumber: @3,
              kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks: @1,
          }
        },
        separatorEffectsTableEntry(),
        @{@"ui": NSLocalizedString(@"effect.back", @""), @"tool": NSLocalizedString(@"effect.back.hint", @""), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeNavigationSwipe,
                  kMFActionDictKeyGenericVariant: kMFNavigationSwipeVariantLeft
        }},
        @{@"ui": NSLocalizedString(@"effect.forward", @""), @"tool": NSLocalizedString(@"effect.forward.hint", @""), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeNavigationSwipe,
                  kMFActionDictKeyGenericVariant: kMFNavigationSwipeVariantRight
        }},
        separatorEffectsTableEntry(),
        @{@"ui": NSLocalizedString(@"effect.mission-control", @""), @"tool": NSLocalizedString(@"effect.mission-control.hint", @""), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHMissionControl)
        }}, /// I removed actions that are redundant to the Click and Drag for Spaces & Mission Control feature in 3.0.0 Beta 6 but  people complained https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue+label%3A%223.0.0+Beta+6+Removed+Actions%22
        @{@"ui": NSLocalizedString(@"effect.app-expose", @"Note: Under macOS Sonoma, this feature is called 'App Exposé' in trackpad settings, but 'Application Windows' in Keyboard Shortcut settings, and other places I found. I also saw 'Show all windows of the front app' and 'Show all open windows for the current app' in Apple's documentation. I went with 'Application Windows' because it's short and 'Exposé' felt like like an outdated term."), @"tool": NSLocalizedString(@"effect.app-expose.hint", @""), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHAppExpose)
        }},
        @{@"ui": NSLocalizedString(@"effect.desktop", @""), @"tool": NSLocalizedString(@"effect.desktop.hint", @""), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHShowDesktop)
        }},
        separatorEffectsTableEntry(),
        @{@"ui": NSLocalizedString(@"effect.launchpad", @""), @"tool": NSLocalizedString(@"effect.launchpad.hint", @""), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHLaunchpad)
        }},
        separatorEffectsTableEntry(),
        @{@"ui": NSLocalizedString(@"effect.left-space", @""), @"tool": NSLocalizedString(@"effect.left-space.hint", @""), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHMoveLeftASpace)
        }},
        @{@"ui": NSLocalizedString(@"effect.right-space", @""), @"tool": NSLocalizedString(@"effect.right-space.hint", @""), @"dict": @{
                  kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                  kMFActionDictKeyGenericVariant: @(kMFSHMoveRightASpace)
        }},
        separatorEffectsTableEntry(),
        @{@"ui": NSLocalizedString(@"effect.record-shortcut", @""), @"tool": NSLocalizedString(@"effect.record-shortcut.hint", @""), @"keyCaptureEntry": @YES},
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
    
    /// Make selected entry non-hidden
    for (int i = 0; i < oneShotEffectsTable.count; i++) {
        
        NSDictionary *entry = oneShotEffectsTable[i];
        
        if ([entry[@"dict"] isEqual:selectedEffect]) {
            NSMutableDictionary *newEntry = entry.mutableCopy;
            newEntry[@"hideable"] = @"NO";
            newEntry[@"alternate"] = @"NO";
            oneShotEffectsTable[i] = newEntry;
        }
    }
    
    /// Insert entry for keyboard shortcut effect
    
    /// Get keycapture index
    NSIndexSet *keyCaptureIndexes = [oneShotEffectsTable indexesOfObjectsPassingTest:^BOOL(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [obj[@"keyCaptureEntry"] isEqual:@YES];
    }];
    assert(keyCaptureIndexes.count == 1);
    NSUInteger keyCaptureIndex = keyCaptureIndexes.firstIndex;
    
    /// Insert entry for keyboard shortcut effect or systemDefined effect
    
    BOOL isKeyShortcut = [selectedEffect[kMFActionDictKeyType] isEqual:kMFActionDictTypeKeyboardShortcut];
    BOOL isSystemEvent = [selectedEffect[kMFActionDictKeyType] isEqual:kMFActionDictTypeSystemDefinedEvent];
    
    if (isKeyShortcut || isSystemEvent) {
        
        /// Get index for new entry (right after keyCaptureEntry)
        NSUInteger shortcutIndex = keyCaptureIndex + 1;
        
        /// Get  strings
        
        NSAttributedString *shortcutString = getShortcutString(selectedEffect, isKeyShortcut);

        NSString *shortcutStringRaw = [shortcutString stringWithAttachmentDescriptions];
        
        /// Create and insert new entry
        [oneShotEffectsTable insertObject:@{
            @"uiAttributed": shortcutString,
            @"tool": stringf(NSLocalizedString(@"effect.shortcut.hint", @""), shortcutStringRaw),
            @"dict": selectedEffect,
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
                @"tool": stringf(NSLocalizedString(@"effect.apple-shortcut.hint", @""), shortcutStringRaw),
                @"dict": actionDict
            }];
        }
    }
    
    [oneShotEffectsTable insertObject:@{
        @"ui": NSLocalizedString(@"effect.apple-keys-submenu", @"Note: This is the title for a hidden submenu that lets you remap your buttons to keyboard keys that only appear on Apple Keyboards such as the 'Brightness Up' or 'Do Not Disturb' keys. "),
        @"tool": NSLocalizedString(@"effect.apple-keys-submenu.hint", @""),
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
        
    /// Datamodel -> Button state
    
    NSDictionary *targetEffect = rowDict[kMFRemapsKeyEffect];
    NSArray *effectPickerModel = [RemapTableTranslator getEffectsTableForRemapsTableEntry:rowDict];
    
    int resultUIIndex = -1;
    
    int uiIndex = 0;
    int modelIndex = 0;
    
    while (true) {
        NSDictionary *effect = effectPickerModel[modelIndex];
        if ([effect[@"hideable"] isEqual:@YES]) {
            uiIndex += 1;
        }
        if ([effect[@"dict"] isEqual:targetEffect]) {
            resultUIIndex = uiIndex;
            break;
        };
        uiIndex += 1;
        modelIndex += 1;
    }
    
    if (resultUIIndex != -1) {
        return [button itemAtIndex:resultUIIndex];
    } else {
        return nil;
    }
}

+ (NSDictionary * _Nullable)getEffectDictBasedOnSelectedItemInButton:(NSPopUpButton * _Nonnull)button rowDict:(NSDictionary * _Nonnull)rowDict {
    
    /// Button state -> Datamodel
    
    NSArray *effectsTable = [RemapTableTranslator getEffectsTableForRemapsTableEntry:rowDict];
    NSInteger targetUIIndex = button.indexOfSelectedItem;
    
    int uiIndex = 0;
    int modelIndex = 0;
    
    while (true) {
        
        NSDictionary *effect = effectsTable[modelIndex];
        if ([effect[@"hideable"] isEqual:@YES]) {
            uiIndex += 1;
        }
         
        if (uiIndex == targetUIIndex) {
            break;
        }
        if (uiIndex > targetUIIndex) {
            assert(false);
            break;
        }
        
        uiIndex += 1;
        modelIndex += 1;
    }
    
    
    
    return effectsTable[modelIndex][@"dict"];
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
        assert(i.accessibilityHelp == nil); /// Most UI elements publish their tooltips as accessibilityHelp automatically, but NSMenuItems don't do that by default, so we do it manually. We do this mainly so that the tooltip string is associated with its NSMenuItem in a way that is visible to accessibility API, which lets us link the menuItem to the tooltip string when creating localizationScreenshots.
        i.accessibilityHelp = i.toolTip;
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
            @[@(1), @"click"]:  NSLocalizedString(@"trigger.substring.click.1",   @"Note: \"%@\" will be a button name (or nothing, if the button name can be inferred from context) || Example where %@ is \"Button 5\": ⌥⌘ Double Click Button 4 + Click Button 5"), /// || NOTE: This 'substring' will be combined with other substrings to form the 'Action Table Trigger Strings' which show up on the left side of the Action Table || NOTE 2: '%@' will be replaced by a mouse button name (or by nothing, if the button name can be inferred from context.) || EXAMPLE of an Action Table Trigger String, which is composed of this and other substrings, where '%@' in this substring was replaced by 'Button 5': ⌥⌘ Double Click Button 4 + Click Button 5 || NOTE 3: Most of the substrings that are used to build the Action Table Trigger Strings (this is one of those substrings) are capitalized in English because it's common to use 'Title Case' there. In your language, 'Title Case' might not be a thing, and so you might not want to capitalize these substrings. The first letter of the Action Table Trigger String will be programmatically capitalized in any language."),
            
            @[@(2), @"click"]:  NSLocalizedString(@"trigger.substring.click.2",   @""), ///|| NOTE: You might not want to capitalize this and other strings whose key starts with 'trigger.substring.' We only capitalize these strings in English because we use 'Title Case' there, which is not common in most languages aside from English. For more info, see the comments on 'trigger.substring.click.1'"),
            @[@(3), @"click"]:  NSLocalizedString(@"trigger.substring.click.3",   @""),
            @[@(1), @"hold"]:   NSLocalizedString(@"trigger.substring.hold.1",    @"Remember: All these strings that start with \"trigger.substring.[...]\" should be all-lowercase in most languages. For an explanation, see the comment for the key \"trigger.substring.button-modifier.2\""),
            @[@(2), @"hold"]:   NSLocalizedString(@"trigger.substring.hold.2",    @""),
            @[@(3), @"hold"]:   NSLocalizedString(@"trigger.substring.hold.3",    @""),
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
        
        /// Note:
        /// - 26.08.2024: The 'Action Table Trigger String' and 'substring' and 'Title Case' concepts and the consequences for how the substrings should be captialized are a bit hard to explain to localizers.
        ///             And I saw the Brazilian, French and Vietnamese localizers all captialize the substrings, even though none of those languages have something akin to 'Title Case'.
        ///             Today, we added `.substring.` in the keys and and added very extensive comments to hopefully help with that.
        
        /// TODO: Comment below is obsolete. Remove.
        /// We need part of the modification precondition to form the main trigger string here.
        ///  E.g. if our precondition for a modified drag is single click button 3, followed by double click button 4, we want the string to be "Click Middle Button + Double Click and Drag Button 4", where the "Click Middle Button + " substring follows the format of a regular modification precondition string (we compute those further down) but the "Double Click and Drag Button 4" substring, which is also called the "trigger string" follows a different format which we compute here.
        /// Get button strings from last button precond, or, if no button preconds exist, get keyboard modifier string
        
        
        /// Define maps
        
        NSDictionary *map = @{
            @[@(1), @"_drag"]:      NSLocalizedString(@"trigger.substring.drag.1",    @""), /// (Removed the note because it's redundant with other notes. ) /// Note: %@ will be replaced by a mouse button name (or by nothing if it can be inferred from context) || Example where %@ is 'Button 5': ⌥⌘ Triple Click Button 4 + Click and Drag Button 5"),
            @[@(2), @"_drag"]:      NSLocalizedString(@"trigger.substring.drag.2",    @""),
            @[@(3), @"_drag"]:      NSLocalizedString(@"trigger.substring.drag.3",    @""),
            @[@(1), @"_scroll"]:    NSLocalizedString(@"trigger.substring.scroll.1",  @""),
            @[@(2), @"_scroll"]:    NSLocalizedString(@"trigger.substring.scroll.2",  @""),
            @[@(3), @"_scroll"]:    NSLocalizedString(@"trigger.substring.scroll.3",  @""),
        };
        
        NSDictionary *onlyFlagsMap = @{
            @"_drag":   NSLocalizedString(@"trigger.substring.drag.flags", @"Note: This will be used for Drag Actions that only need keyboard modifiers to be activated - not mouse buttons || Example: ⌥⌘ and Drag"),
            @"_scroll": NSLocalizedString(@"trigger.substring.scroll.flags", @"Example: ⌥⌘ and Scroll"),
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
        ///     Notes:
        ///     - 26.08.2024: I saw the French and Brazillian loclizers not capitalize and spell the drag-particles exactly as they are in the trigger.substring.[...] strings.
        ///                 So we added more extensive comments and added `.z.` in the key so that translators see the drag-particles *after* the trigger.substring.[...] strings - hopefully making it more understandable how the particles affect the substrings.
        
        NSString *dragParticle =    NSLocalizedString(@"trigger.z.drag-particle",  @"Note: This word will be emphasized in strings such as \"Double Click and Drag %@\". For the emphasis to work, make sure that spelling and capitalization matches *exactly* with how this word is used in strings whose keys begin with \"trigger.substring.drag.[...]\". If this this is not possible in your language, please let me know so I can adjust the code. Thank you."); // || Note: This word will be emphasized in 'Action Table Trigger Strings' such as 'Double Click and Drag %@'. For the emphasis to work, make sure that spelling and capitalization matches *exactly* with how this word is used in strings whose keys begin with 'trigger.substring.drag.[...]'");
        NSString *scrollParticle =  NSLocalizedString(@"trigger.z.scroll-particle", @"Note: This word will be emphasized in strings such as \"Click and Scroll %@\". For the emphasis to work, make sure that spelling and capitalization matches *exactly* with how this word is used in the strings whose keys begin with \"trigger.substring.scroll.[...]\"");
        
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
        buttonStr = [UIStrings getButtonString:btn.intValue context:kMFButtonStringUsageContextActionTableTriggerSubstring];
        
        NSString *buttonModString;
        if (lvl.intValue == 1) {
            buttonModString = stringf(NSLocalizedString(@"trigger.substring.button-modifier.1", @"Note: %@ will be a button name || Example where %@ is 'Button 4': Click Button 4 + Double Click and Drag Button 5"), buttonStr);
        } else if (lvl.intValue == 2) {
            /// Notes:
            ///     - We put the detailed localizer hints for the "trigger.substring.[...]" strings here because:
            ///         - It shows up close to the top of the "trigger.substrings.[...]" in the .xcstrings file, when sorting alphabetically.
            ///         - If we put the explanation on the very first of the "trigger.substrings" ("trigger.substring.button-modifier.1"), then we'd have multiple "|| Note:" sections in the same string comment - I think this increases chances of localizers missing the notes.
            ///     - Our examples of the German strings are slightly wrong - we altered them to better be able to drive home the point that not even the first word of the string should be capitalized.
            buttonModString = stringf(NSLocalizedString(@"trigger.substring.button-modifier.2", @"Note: All the \"trigger.substring.[...]\" strings should be lowercase unless there's a specific reason to capitalize them. In English, that reason is that we're using \"Title Case\", but this isn't common in other languages. For example, in German, the substring \"Double Click %@ +\" should be localized as \"doppelklicke %@ +\" and \"Click and Drag %@\" as \"klicke %@ und ziehe\". Notice that not even the first word is capitalized in German. That's because these substrings are joined programmatically to create a combined string. The substrings start with a lowercase letter, to avoid random capitalization in the middle of the combined string. The first word of the combined string will be capitalized programmatically. Therefore, unless your language has special capitalization rules (such as \"Title Case\" in English), these substrings should probably be all-lowercase, just like German. (Or, if you use a non-standard way to capitalize I think that's also ok, as long as it's reasonably consistent) I know this is a bit complicated, but I hope it's still understandable! If anything's unclear, please let me know and I'll try to explain it and improve these comments. Thank you."), buttonStr);
        } else if (lvl.intValue == 3) {
            buttonModString = stringf(NSLocalizedString(@"trigger.substring.button-modifier.3", @""), buttonStr);
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
        
        NSAttributedString *mainButton = [UIStrings getButtonString:btn.intValue context:kMFButtonStringUsageContextActionTableTriggerSubstring].attributed;
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
