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

@interface RemapTableController ()
@end

@implementation RemapTableController

// Table view data model

NSMutableArray *_remaps;

// Methods

- (void)loadRemapsFromConfig {
    [ConfigFileInterface_App loadConfigFromFile]; // Not sure if necessary
    _remaps = ConfigFileInterface_App.config[kMFConfigKeyRemaps];
}
- (void)writeRemapsToConfig {
    [ConfigFileInterface_App.config setObject:_remaps forKey:kMFConfigKeyRemaps];
    [ConfigFileInterface_App writeConfigToFileAndNotifyHelper];
}

- (void)viewDidLoad { // Not getting called for some reason -> I had to set the view outlet of the controller object in IB to the tableView
    // Set corner radius
    NSScrollView *scrollView = (NSScrollView *)self.view.superview.superview;
    scrollView.wantsLayer = TRUE;
//    scrollView.layer.cornerRadius = 5;
    // Load table data from config
    [self loadRemapsFromConfig];
    // Override table data for testing
    _remaps = @[
        @{
            kMFRemapsKeyModificationPrecondition: @{},
            kMFRemapsKeyTrigger: @{
                    kMFButtonTriggerKeyButtonNumber: @3,
                    kMFButtonTriggerKeyClickLevel: @2,
                    kMFButtonTriggerKeyDuration: kMFButtonTriggerDurationClick,
            },
            kMFRemapsKeyEffect: @[
                    @{
                        kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                        kMFActionDictKeyGenericVariant: @(kMFSHLaunchpad),
                    }
            ]
        },
        @{
            kMFRemapsKeyModificationPrecondition: @{
                    kMFModificationPreconditionKeyKeyboard: @(kCGEventFlagMaskCommand | kCGEventFlagMaskControl),
                    kMFModificationPreconditionKeyButtons: @[
                            @{
                                kMFButtonModificationPreconditionKeyButtonNumber: @(4),
                                kMFButtonModificationPreconditionKeyClickLevel: @(2),
                            },
                            @{
                                kMFButtonModificationPreconditionKeyButtonNumber: @(3),
                                kMFButtonModificationPreconditionKeyClickLevel: @(1),
                            },
                    ],
            },
            kMFRemapsKeyTrigger: kMFTriggerKeyDrag,
            kMFRemapsKeyEffect: @[
                    @{
                        kMFModifiedDragDictKeyType: kMFModifiedDragDictTypeThreeFingerSwipe,
                    }
            ]
        },
    ];
    _remaps = [NSArray doDeepMutateArray:_remaps];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _remaps.count;
}

static void getClickAndLevelStrings(NSDictionary *clickLevelToUIString, NSNumber *lvl, NSString **clickStr, NSString **levelStr) {
    *levelStr = clickLevelToUIString[lvl];
    if (!*levelStr) {
        *levelStr = [NSString stringWithFormat:@"%@", lvl];
    }
    // click // TODO: Refactor, so this just returns levelStr, because click string doesn't depend to level string anymore
    *clickStr = @"Click ";
}

static NSString *getButtonString(NSDictionary *buttonNumberToUIString, NSNumber *btn) {
    NSString *buttonStr = buttonNumberToUIString[btn];
    if (!buttonStr) {
        buttonStr = [NSString stringWithFormat:@"Button %@", btn];
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
static NSString *getKeyboardModifierTooltipString(NSNumber *flags) {
    NSString *kb = @"";
    if (flags) {
        CGEventFlags f = flags.longLongValue;
        kb = [NSString stringWithFormat:@"%@%@%@%@",
              (f & kCGEventFlagMaskControl ?    @"Control-" : @""),
              (f & kCGEventFlagMaskAlternate ?  @"Option-" : @""),
              (f & kCGEventFlagMaskShift ?      @"Shift-" : @""),
              (f & kCGEventFlagMaskCommand ?    @"Command-" : @"")];
    }
    if (kb.length > 0) {
        kb = [kb substringToIndex:kb.length-1]; // Delete trailing dash
        kb = [kb stringByAppendingString:@" "]; // Append trailing space
    }
    
    return kb;
}

- (NSTableCellView *)getTriggerTableCellWithRowDict:(NSMutableDictionary *)rowDict {
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
    NSDictionary *buttonNumberToUIString = @{
        @1: @"Primary Button",
        @2: @"Secondary Button",
        //            @3: @"middle button",
    };
    // Get trigger string from data
    NSString *tr = @"";
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
        NSString * buttonStr = getButtonString(buttonNumberToUIString, btn);
        if (btn.intValue < 1) {
            @throw [NSException exceptionWithName:@"Invalid button number" reason:@"Remaps contain invalid button number" userInfo:@{@"Trigger dict containing invalid value": trigger}];
        }
        // Form trigger string from substrings
        tr = [NSString stringWithFormat:@"%@%@%@%@", levelStr, clickStr, durationStr, buttonStr];
        
    } else if ([triggerGeneric isKindOfClass:NSString.class]) {
        // Trigger is drag or scroll
        // Get button strings or, if no button preconds exist, get keyboard modifier string
        NSString *levelStr = @"";
        NSString *clickStr = @"";
        NSString *buttonStr = @"";
        NSString *keyboardModStr = @"";
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
            buttonStr = getButtonString(buttonNumberToUIString, btn);
        } else if (keyboardModifiers) {
            // Extract keyboard modifiers
            keyboardModStr = getKeyboardModifierString(keyboardModifiers);
            rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyKeyboard] = nil;
        } else {
            @throw [NSException exceptionWithName:@"No precondition" reason:@"Modified drag or scroll has no preconditions" userInfo:@{@"Precond dict": (rowDict[kMFRemapsKeyModificationPrecondition])}];
        }
        // Get trigger string
        NSString *triggerStr;
        NSString *trigger = (NSString *)triggerGeneric;
        if ([trigger isEqualToString:kMFTriggerKeyDrag]) {
            // Trigger is drag
            triggerStr = @"and Drag ";
        } else if ([trigger isEqualToString:kMFTriggerKeyScroll]) {
            // Trigger is scroll
            triggerStr = @"and Scroll ";
        } else {
            @throw [NSException exceptionWithName:@"Unknown string trigger value" reason:@"The value for the string trigger key is unknown" userInfo:@{@"Trigger value": trigger}];
        }
        // Form full trigger string from substrings
        tr = [NSString stringWithFormat:@"%@%@%@%@%@", levelStr, clickStr, keyboardModStr, triggerStr, buttonStr];
        
    } else {
        NSLog(@"Trigger value: %@, class: %@", triggerGeneric, [triggerGeneric class]);
        @throw [NSException exceptionWithName:@"Invalid trigger value type" reason:@"The value for the trigger key is not a String and not a dictionary" userInfo:@{@"Trigger value": triggerGeneric}];
    }
    // Get keyboard modifier main string and tooltip string
    NSNumber *flags = (NSNumber *)rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyKeyboard];
    NSString *kbModRaw = getKeyboardModifierString(flags);
    NSString *kbModTooltipRaw = getKeyboardModifierTooltipString(flags);
    NSString *kbMod = @"";
    NSString *kbModTooltip = @"";
    if (![kbModRaw isEqualToString:@""]) {
        kbMod = [kbModRaw stringByAppendingString:@"+ "];
        kbModTooltip = [kbModTooltipRaw stringByAppendingString:@"+ "];
    }
    // Get button modifier string
    NSMutableArray *buttonPressSequence = rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyButtons];
    NSMutableArray *buttonModifierStrings = [NSMutableArray array];
    for (NSDictionary *buttonPress in buttonPressSequence) {
        NSNumber *btn = buttonPress[kMFButtonModificationPreconditionKeyButtonNumber];
        NSNumber *lvl = buttonPress[kMFButtonModificationPreconditionKeyClickLevel];
        NSString *levelStr;
        NSString *clickStr;
        NSString *buttonStr;
        buttonStr = getButtonString(buttonNumberToUIString, btn);
        getClickAndLevelStrings(clickLevelToUIString, lvl, &clickStr, &levelStr);
        NSString *buttonModString = [NSString stringWithFormat:@"%@%@%@ + ", levelStr, clickStr, buttonStr];
        [buttonModifierStrings addObject:buttonModString];
    }
    NSString *btnMod = [buttonModifierStrings componentsJoinedByString:@""];
    // Join all substrings to get result string
    NSString *fullTriggerCellString = [NSString stringWithFormat:@"%@%@%@", kbMod, btnMod, tr];
    NSString *fullTriggerCellTooltipString = [NSString stringWithFormat:@"%@%@%@", kbModTooltip, btnMod, tr];
    // Generate view and set string to view
    NSTableCellView *triggerCell = [((NSTableView *)self.view) makeViewWithIdentifier:@"triggerCell" owner:nil];
    triggerCell.textField.stringValue = fullTriggerCellString;
    triggerCell.textField.toolTip = fullTriggerCellTooltipString;
    return triggerCell;
}

- (NSTableCellView *)getEffectTableCellWithRowDict:(NSDictionary *)rowDict {
    
    // Get info about what kind of trigger we're dealing with
    BOOL isOneShotEffect = YES;
    
    if (isOneShotEffect) {
        // Define oneShot effects table
        NSArray *oneShotEffectsTable = @[
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
            @{@"noeffect": @"separator"},
            @{@"ui": @"Move left a Space", @"tool": @"Move one Space to the left", @"dict": @{
                      kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                      kMFActionDictKeyGenericVariant: @(kMFSHMoveLeftASpace)
            }},
            @{@"ui": @"Move right a Space", @"tool": @"Move one Space to the right", @"dict": @{
                      kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                      kMFActionDictKeyGenericVariant: @(kMFSHMoveRightASpace)
            }},
            @{@"noeffect": @"separator"},
            @{@"ui": @"Back", @"tool": @"Go back \nWorks like a horizontal three finger swipe on an Apple Trackpad if \"System Preferences\" → \"Trackpad\" → \"More Gestures\" → \"Swipe between pages\" is set to \"Swipe with three fingers\"", @"dict": @{
                      kMFActionDictKeyType: kMFActionDictTypeNavigationSwipe,
                      kMFActionDictKeyGenericVariant: kMFNavigationSwipeVariantLeft
            }},
            @{@"ui": @"Forward", @"tool": @"Go forward \nWorks like a horizontal three finger swipe on an Apple Trackpad if \"System Preferences\" → \"Trackpad\" → \"More Gestures\" → \"Swipe between pages\" is set to \"Swipe with three fingers\"", @"dict": @{
                      kMFActionDictKeyType: kMFActionDictTypeNavigationSwipe,
                      kMFActionDictKeyGenericVariant: kMFNavigationSwipeVariantRight
            }},
            @{@"noeffect": @"separator"},
            @{@"ui": @"Launchpad", @"tool": @"Open Launchpad", @"dict": @{
                      kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                      kMFActionDictKeyGenericVariant: @(kMFSHLaunchpad)
            }},
            @{@"noeffect": @"separator"},
            @{@"ui": @"Look Up", @"tool": @"Zoom in and out in Safari and other apps \nSimulates a two-finger double tap on an Apple Trackpad", @"dict": @{
                      kMFActionDictKeyType: kMFActionDictTypeSmartZoom,
            }},
            @{@"ui": @"Smart Zoom", @"tool": @"Look up words in the dictionary, Quick Look files in Finder, and more... \nWorks like Force Touch on an Apple Trackpad", @"dict": @{
                      kMFActionDictKeyType: kMFActionDictTypeSymbolicHotkey,
                      kMFActionDictKeyGenericVariant: @(kMFSHLookUp)
            }},
            @{@"ui": @"Open link in new tab", @"tool": @"Open Links in a new tab, paste text in the Terminal, and more... \nSimulates clicking the middle mouse button on a standard mouse", @"dict": @{
                      kMFActionDictKeyType: kMFActionDictTypeMouseButtonClicks,
                      kMFActionDictKeyMouseButtonClicksVariantButtonNumber: @3,
                      kMFActionDictKeyMouseButtonClicksVariantNumberOfClicks: @1,
            }},
        ];
        // Create table cell view
        NSTableCellView *triggerCell = [((NSTableView *)self.view) makeViewWithIdentifier:@"effectCell" owner:nil];
        // Get popup button
        NSPopUpButton *popupButton = triggerCell.subviews[0];
        // Delete existing menu items from IB
        [popupButton removeAllItems];
        // Iterate oneshot effects table and fill popupButton
        for (NSDictionary *effectDict in oneShotEffectsTable) {
            NSMenuItem *i;
            if ([effectDict[@"noeffect"] isEqualToString: @"separator"]) {
                i = NSMenuItem.separatorItem;
            } else {
                i = [[NSMenuItem alloc] initWithTitle:effectDict[@"ui"] action:@selector(popupButton:) keyEquivalent:@""];
                [i setToolTip:effectDict[@"tool"]];
                // Try fix disabled
                i.enabled = YES;
                i.target = self;
            }
            [popupButton.menu addItem:i];
        }
        return triggerCell;
    }
    return nil;
}

- (IBAction)popupButton:(NSButton *)sender {
    NSLog(@"Yay!");
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    // Generate table cell view for this row and column
    NSMutableDictionary *rowDict = _remaps[row];
    if ([tableColumn.identifier isEqualToString:@"trigger"]) { // The trigger column should display the trigger as well as the modification precondition
        return [self getTriggerTableCellWithRowDict:rowDict];
    } else if ([tableColumn.identifier isEqualToString:@"effect"]) {
        return [self getEffectTableCellWithRowDict:rowDict];
    } else {
        @throw [NSException exceptionWithName:@"Unknown column identifier" reason:@"TableView is requesting data for a column with an unknown identifier" userInfo:@{@"requested data for column": tableColumn}];
        return nil;
    }
}

@end
