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
    scrollView.layer.cornerRadius = 5;
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
                        kMFActionDictKeySingleVariant: @(kMFSHLaunchpad),
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
    // click
    *clickStr = @"Click ";
    if (![*levelStr isEqualToString:@""]) {
        *clickStr = @"click ";
    }
}

static NSString *getButtonString(NSDictionary *buttonNumberToUIString, NSNumber *btn) {
    NSString *buttonStr = buttonNumberToUIString[btn];
    if (!buttonStr) {
        buttonStr = [NSString stringWithFormat:@"button %@", btn];
    }
    return buttonStr;
}

static NSString *getKeyboardModifierString(NSNumber *flags) {
    NSString *kb = @"";
    if (flags) {
        CGEventFlags f = flags.longLongValue;
        kb = [NSString stringWithFormat:@"%@%@%@%@",
              (f & kCGEventFlagMaskControl ?    @"^" : @""),
              (f & kCGEventFlagMaskAlternate ?  @"⌥" : @""),
              (f & kCGEventFlagMaskShift ?      @"⇧" : @""),
              (f & kCGEventFlagMaskCommand ?    @"⌘" : @"")];
    }
    return kb;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    // Generate table cell view for this row and column
    NSMutableDictionary *rowDict = _remaps[row];
    if ([tableColumn.identifier isEqualToString:@"trigger"]) { // The trigger column should display the trigger as well as the modification precondition
        // Get trigger string
        // Define Data-to-UI-String mappings
        NSDictionary *clickLevelToUIString = @{
            @1: @"",
            @2: @"Double ",
            @3: @"Triple ",
        };
        NSDictionary *durationToUIString = @{
            kMFButtonTriggerDurationClick: @"",
            kMFButtonTriggerDurationHold: @"and hold ",
        };
        NSDictionary *buttonNumberToUIString = @{
            @1: @"primary button",
            @2: @"secondary button",
            @3: @"middle button",
        };
        // Get trigger string from data
        NSString *tr = @"";
        id triggerGeneric = rowDict[kMFRemapsKeyTrigger];
        if ([triggerGeneric isKindOfClass:NSDictionary.class]) {
            // Trigger is button input
            // Get relevant values from trigger dict
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
            // Get button strings or keyboard modifier string of no button preconds exist
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
                @throw [NSException exceptionWithName:@"No precondition" reason:@"Modified drag or scroll has no precondition(s)" userInfo:@{@"Precond dict": (rowDict[kMFRemapsKeyModificationPrecondition])}];
            }
            // Get trigger string
            NSString *triggerStr;
            NSString *trigger = (NSString *)triggerGeneric;
            if ([trigger isEqualToString:kMFTriggerKeyDrag]) {
                // Trigger is drag
                triggerStr = @"and drag ";
            } else if ([trigger isEqualToString:kMFTriggerKeyScroll]) {
                // Trigger is scroll
                triggerStr = @"and scroll ";
            } else {
                @throw [NSException exceptionWithName:@"Unknown string trigger value" reason:@"The value for the string trigger key is unknown" userInfo:@{@"Trigger value": trigger}];
            }
            // Form trigger string from substrings
            tr = [NSString stringWithFormat:@"%@%@%@%@%@", levelStr, clickStr, keyboardModStr, triggerStr, buttonStr];
            
        } else {
            NSLog(@"Trigger value: %@, class: %@", triggerGeneric, [triggerGeneric class]);
            @throw [NSException exceptionWithName:@"Invalid trigger value type" reason:@"The value for the trigger key is not a String and not a dictionary" userInfo:@{@"Trigger value": triggerGeneric}];
        }
        
        // Get keyboard modifier string
        NSNumber *flags = (NSNumber *)rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyKeyboard];
        NSString *kbModRaw = getKeyboardModifierString(flags);
        NSString *kbMod = @"";
        if (![kbModRaw isEqualToString:@""]) {
            kbMod = [kbModRaw stringByAppendingString:@" + "];
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
        NSString *fullTriggerString = [NSString stringWithFormat:@"%@%@%@", kbMod, btnMod, tr];
        
        // Generate view and set string to view
        NSTableCellView *triggerCell = [((NSTableView *)self.view) makeViewWithIdentifier:@"triggerCell" owner:nil];
        triggerCell.textField.stringValue = fullTriggerString;
        triggerCell.textField.toolTip = fullTriggerString;
        
        return triggerCell;
        
    } else if ([tableColumn.identifier isEqualToString:@"effect"]) {
        NSTableCellView *triggerCell = [((NSTableView *)self.view) makeViewWithIdentifier:@"effectCell" owner:nil];
        return triggerCell;
    } else {
        @throw [NSException exceptionWithName:@"Unknown column identifier" reason:@"TableView is requesting data for a column with an unknown identifier" userInfo:@{@"requested data for column": tableColumn}];
        return nil;
    }
}

@end
