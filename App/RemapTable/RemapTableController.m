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
#import "RemapTableTranslator.h"
#import "NSView+Additions.h"
#import "MFKeystrokeCaptureTextView.h"
#import "RemapTableUtility.h"

@interface RemapTableController ()
@property NSTableView *tableView;
@end

@implementation RemapTableController

#pragma mark (Pseudo) Properties

@synthesize dataModel = _dataModel;

- (NSTableView *)tableView {
    return (NSTableView *)self.view;
}
- (void)setTableView:(NSTableView *)tableView {
    self.view = tableView;
}
- (NSScrollView *)scrollView {
    NSClipView *clipView = (NSClipView *)self.tableView.superview;
    NSScrollView *scrollView = (NSScrollView *)clipView.superview;
    return scrollView;
}
- (RemapTableTranslator *)dataSource {
    return self.tableView.dataSource;
}

#pragma mark Interact with config

- (void)loadDataModelFromConfig {
    [ConfigFileInterface_App loadConfigFromFile]; // Not sure if necessary
    self.dataModel = ConfigFileInterface_App.config[kMFConfigKeyRemaps];
}
- (void)writeDataModelToConfig {
    [ConfigFileInterface_App.config setObject:self.dataModel forKey:kMFConfigKeyRemaps];
    [ConfigFileInterface_App writeConfigToFileAndNotifyHelper];
}

/// Helper function for `handleEnterKeystrokeOptionSelected`
- (void)reloadDataWithTemporaryDataModel:(NSArray *)tempDataModel {
    
    NSArray *store = self.dataModel;
    self.dataModel = tempDataModel;
    [self.tableView reloadData];
    [self.tableView displayIfNeeded]; // Need to do this because reloadData is async
    self.dataModel = store;
}

- (IBAction)handleEnterKeystrokeOptionSelected:(id)sender {
    
    // Find table row for sender
    NSInteger rowOfSender = -1;
    
    NSMenuItem *item = (NSMenuItem *)sender;
    NSMenu *menu = item.menu;
    for (NSInteger row = 0; row < self.dataModel.count; row++) {
        NSTableCellView *cell = [self.tableView viewAtColumn:1 row:row makeIfNecessary:YES];
        NSPopUpButton *pb = cell.subviews[0];
        if ([pb.menu isEqual:menu]) {
            rowOfSender = row;
            break;
        }
    }
    assert(rowOfSender != -1);
    
    // Draw keystroke-capture-field
    NSArray *dataModelWithCaptureCell = (NSArray *)[SharedUtility deepCopyOf:self.dataModel];
    dataModelWithCaptureCell[rowOfSender][kMFRemapsKeyEffect] = @{
        @"drawKeyCaptureView": @YES
    };
    [self reloadDataWithTemporaryDataModel:dataModelWithCaptureCell];
    
    // ^ Changing the datamodel and redrawing the whole table to insert a temporary view for capturing keyboardShortcuts is a bit ugly I feel, but 'The tableView needs to own it's views' afaik so this is the only way.
    //      We need to make sure we never write this rowDict to file, because that's probably gonna crash the helper or lead to unexpected behaviour.
    //      Actually creating/inserting the captureView into the table is done in `getEffectCellWithRowDict:row:`
    
}

// Helper for functions below. Shouldn't need to call directly.
- (void)storeEffectsFromUIInDataModel {
    
    // Set each rows effect content to datamodel
    for (NSInteger row = 0; row < self.dataModel.count; row++) {
        // Get effect dicts
        NSTableCellView *cell = [self.tableView viewAtColumn:1 row:row makeIfNecessary:YES];
        if ([cell.identifier isEqual:@"effectCell"]) {
            NSPopUpButton *pb = cell.subviews[0];
            NSString *selectedTitle = pb.selectedItem.title;
            // Get effects table for row of sender
            NSArray *effectsTable = [RemapTableTranslator getEffectsTableForRemapsTableEntry:self.dataModel[row]];
            NSDictionary *effectsTableEntryForSelected = [RemapTableTranslator getEntryFromEffectsTable:effectsTable withUIString:selectedTitle];
            NSDictionary *effectDictForSelected = effectsTableEntryForSelected[@"dict"];
            // Write effect dict to data model
            self.dataModel[row][kMFRemapsKeyEffect] = effectDictForSelected;
        } else {
            assert(false);
        }
    }
}

/// Need this sometimes instead of `updateTableAndWriteToConfig:` when we update the table some other way (e.g. adding a row with an animation)
- (void)writeToConfig {
    [self storeEffectsFromUIInDataModel];
    
    // Write datamodel to file
    [self writeDataModelToConfig];
}

/// Called when user clicks chooses most effects
- (IBAction)updateTableAndWriteToConfig:(id _Nullable)sender {

    [self writeToConfig];

    // Reload tableView so that
    //  - Trigger-cell tooltips update to newly chosen effect
    //  - NSMenus update to remove keyboard shortcuts that are unselected
    //  It's super inefficient to update everything but computer fast (We should pass this a specific row to update)
    [self.tableView reloadData];
    
}

#pragma mark Lifecycle

- (void)awakeFromNib {
    // Force Autohiding scrollers - to keep layout consistent (doesn't work)
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.scrollerStyle = NSScrollerStyleOverlay;
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
    
    [RemapTableTranslator initializeWithTableView:self.tableView];
}

#pragma mark - IBActions

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

#pragma mark Interface functions

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
        pl[kMFRemapsKeyEffect] = [RemapTableTranslator getEffectsTableForRemapsTableEntry:pl][0][@"dict"];
        // Add new row to data model
        self.dataModel = [self.dataModel arrayByAddingObject:pl];
        // Sort data model
        [self sortDataModel];
        // Display new row with animation and highlight by selecting it
        NSUInteger insertedIndex = [self.dataModel indexOfObject:pl];
        toHighlightIndexSet = [NSIndexSet indexSetWithIndex:insertedIndex];
        [self.tableView insertRowsAtIndexes:toHighlightIndexSet withAnimation:NSTableViewAnimationSlideDown];
        // Write new row to file (to make behaviour appropriate when user doesn't choose any effect)
        [self writeToConfig];
    } else {
        toHighlightIndexSet = existingIndexes;
    }
    [self.tableView selectRowIndexes:toHighlightIndexSet byExtendingSelection:NO];
    [self.tableView scrollRowToVisible:toHighlightIndexSet.firstIndex];
    // Open the NSMenu on the newly created row's popup button
    NSUInteger openPopupRow = toHighlightIndexSet.firstIndex;
    NSTableView *tv = self.tableView;
    NSPopUpButton * popUpButton = [RemapTableUtility getPopUpButtonAtRow:openPopupRow fromTableView:tv];
    [popUpButton performSelector:@selector(performClick:) withObject:nil afterDelay:0.2];
    
    NSSet<NSNumber *> *capturedButtonsAfter = (NSSet *)[SharedMessagePort sendMessage:@"getCapturedButtons" withPayload:nil expectingReply:YES];
    [CaptureNotifications showButtonCaptureNotificationWithBeforeSet:capturedButtonsBefore afterSet:capturedButtonsAfter];
    
//    if ([capturedButtonsBefore isEqual:capturedButtonsAfter]) {
        // If they aren't equal then `showButtonCaptureNotificationWithBeforeSet:` will show a notification
        //      This notification will not be interactable if we also open the popup button menu.
//        [popUpButton performSelector:@selector(performClick:) withObject:nil afterDelay:0.2];
//    }

}

#pragma mark - TableView data source functions

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    // Get data for this row
    NSDictionary *rowDict = self.dataModel[row];
    // Create deep copy of row.
    //  `getTriggerCellWithRowDict` is written badly and needs to manipulate some values nested in rowDict.
    //  I we don't deep copy, the changes to rowDict will reflect into self.dataModel and be written to file causing corruption.
    //      (The fact that rowDict is NSDictionary not NSMutableDictionary doesn't help, cause the stuff being manipulated is nested)
    rowDict = (NSDictionary *)[SharedUtility deepCopyOf:rowDict];
    if ([tableColumn.identifier isEqualToString:@"trigger"]) { // The trigger column should display the trigger as well as the modification precondition
        return [RemapTableTranslator getTriggerCellWithRowDict:rowDict];
    } else if ([tableColumn.identifier isEqualToString:@"effect"]) {
        return [RemapTableTranslator getEffectCellWithRowDict:rowDict row:row];
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
    NSTableCellView *view = [RemapTableTranslator getTriggerCellWithRowDict:rowDict];
    // ^ These lines are copied from `tableView:viewForTableColumn:row:`. Should change this cause copied code is bad.
    NSTextField *textField = view.subviews[0];
    NSMutableAttributedString *string = textField.effectiveAttributedStringValue.mutableCopy;
    
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
