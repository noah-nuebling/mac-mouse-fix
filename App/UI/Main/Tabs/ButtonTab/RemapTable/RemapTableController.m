//
// --------------------------------------------------------------------------
// RemapTableController.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "RemapTableController.h"
#import "Config.h"
#import "Constants.h"
#import "Utility_App.h"
#import "NSArray+Additions.h"
#import "SharedUtility.h"
//#import "AddWindowController.h"
#import <Cocoa/Cocoa.h>
#import "SharedUtility.h"
#import "NSAttributedString+Additions.h"
#import "NSTextField+Additions.h"
#import "UIStrings.h"
#import "MFMessagePort.h"
#import "CaptureToasts.h"
#import "RemapTableTranslator.h"
#import "NSView+Additions.h"
#import "KeyCaptureView.h"
#import "RemapTableUtility.h"
#import "ButtonGroupRowView.h"
#import "Mac_Mouse_Fix-Swift.h"
#import "NSColor+Additions.h"
#import "MFSegmentedControl.h"
#import "Mac_Mouse_Fix-Swift.h"

@interface RemapTableController ()
@property NSTableView *tableView;
@property (weak) IBOutlet MFSegmentedControl *addRemoveControl; /// TODO: Remove addRemoveControl

@end

@implementation RemapTableController

#pragma mark (Pseudo) Properties

@synthesize dataModel = _dataModel, groupedDataModel = _groupedDataModel;

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
    [Config.shared loadConfigFromFileAndRepair]; /// Not sure if necessary. Other than this, the only caller of `loadConfigFromFileAndRepair` is `handleConfigFileChange`. Edit: Think this is unnecessary. Remove.
    self.dataModel = Config.shared.config[kMFConfigKeyRemaps];
}
- (void)writeDataModelToConfig {
    
    DDLogDebug(@"TRM remap table store remaps"); /// Currently looks like this is never called? That can't be true.
    
    setConfig(kMFConfigKeyRemaps, self.dataModel);
    commitConfig();
}

/// Helper function for `handleEnterKeystrokeOptionSelected`
- (void)reloadDataWithTemporaryDataModel:(NSArray *)tempDataModel {
    
    NSArray *store = self.dataModel;
    self.dataModel = tempDataModel;
    [self.tableView reloadData];
    [self.tableView displayIfNeeded]; /// Force data to reload immediately
    if (@available(macOS 10.14, *)) { } else {
        /// Use layout to force data reload under 10.13
        ///     For some reason, under 10.13, `displayIfNeeded` doesn't do anything
        self.tableView.needsLayout = YES;
        [self.tableView layoutSubtreeIfNeeded];
    }
    self.dataModel = store;
}

#pragma mark React to user input

- (IBAction)handleKeystrokeMenuItemSelected:(id)sender {
    
    /// Find table row for sender
    NSInteger rowOfSender = -1;
    
    NSMenuItem *item = (NSMenuItem *)sender;
    NSMenu *menu = item.menu;
    for (NSInteger row = 0; row < self.groupedDataModel.count; row++) {
        NSTableCellView *cell = [self.tableView viewAtColumn:1 row:row makeIfNecessary:YES]; // Not sure if makeIfNecessary is appropriate here
        NSPopUpButton *pb = cell.subviews[0];
        if ([pb.menu isEqual:menu]) {
            rowOfSender = row;
            break;
        }
    }
    
    assert(rowOfSender != -1);
    
    /// Convert rowOfSender to base data model index
    rowOfSender = [RemapTableUtility baseDataModelIndexFromGroupedDataModelIndex:rowOfSender withGroupedDataModel:self.groupedDataModel];
    
    /// Draw keystroke-capture-field
    NSArray *dataModelWithCaptureCell = (NSArray *)[SharedUtility deepCopyOf:self.dataModel];
    dataModelWithCaptureCell[rowOfSender][kMFRemapsKeyEffect] = @{
        @"drawKeyCaptureView": @YES
    };
    [self reloadDataWithTemporaryDataModel:dataModelWithCaptureCell];
    
    /// ^ Changing the datamodel and redrawing the whole table to insert a temporary view for capturing keyboardShortcuts is a bit ugly I feel, but 'The tableView needs to own it's views' afaik so this is the only way.
    ///      We need to make sure we never write this rowDict to file, because that's probably gonna crash the helper or lead to unexpected behaviour.
    ///      Actually creating/inserting the captureView into the table is done in `getEffectCellWithRowDict:row:`
    
}

/// Helper for functions below. Shouldn't need to call directly.
- (void)storeEffectsFromUIInDataModel {
    
    /// Set each rows effect content to datamodel
    NSInteger row = 0; /// Index for trueDataModel
    for (NSInteger rowGrouped = 0; rowGrouped < self.groupedDataModel.count; rowGrouped++) { /// rowGrouped is index for groupedDataModel
        
        if ([self.groupedDataModel[rowGrouped] isEqual:RemapTableUtility.buttonGroupRowDict]) {
            continue;
        }
        
        /// Get effect dicts
        /// Note: We're passing in `self.dataModel[row]` which still contains the old effect. (We're trying to update the datamodel with the new effect). This doesn't really make sense. Does it break anything?
        NSTableCellView *cell = [self.tableView viewAtColumn:1 row:rowGrouped makeIfNecessary:YES];
        if ([cell.identifier isEqual:@"effectCell"]) {
            NSPopUpButton *pb = cell.subviews[0];
            NSDictionary *effectDictForSelected = [RemapTableTranslator getEffectDictBasedOnSelectedItemInButton:pb rowDict:self.dataModel[row]];
            /// Write effect dict to data model
            self.dataModel[row][kMFRemapsKeyEffect] = effectDictForSelected;
        } else {
            assert(false);
        }
        
        row++;
    }
}

/// Need this sometimes instead of `updateTableAndWriteToConfig:` when we update the table some other way (e.g. adding a row with an animation)
- (void)writeToConfig {
    [self storeEffectsFromUIInDataModel];
    
    /// Write datamodel to file
    [self writeDataModelToConfig];
}

- (IBAction)updateTableAndWriteToConfig:(id _Nullable)sender {
    /// Called when user clicks chooses most effects

    /// Reload tableView so that
    ///  - Trigger-cell tooltips update to newly chosen effect
    ///  - NSMenus update to remove keyboard shortcuts that are unselected
    ///  It's super inefficient to update everything but computer fast (We should pass this a specific row to update)
    /// Note: Shouldn't we first update UI and then write the UI to config? Not sure it matters
    [self writeToConfig];
    
    if ([sender isKindOfClass:RemapTableMenuItem.class]) {
        NSTableCellView *host = ((RemapTableMenuItem *)sender).host;
        NSInteger row = [RemapTableUtility rowOfCell:host inTableView:self.tableView];
        [self.tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)]]; /// Some docs recommended `setNeedsDisplayInRect:` but this seems more robust
    } else {
        [self.tableView reloadData];
    }
    
}

- (IBAction)submenuItemClicked:(NSMenuItem * _Nonnull)item {
    
    /// Find root menu
    
    NSMenuItem *rootItem = item;
    while (true) {
        NSMenuItem *nextRoot = rootItem.parentItem;
        if (nextRoot == nil) {
            break;
        }
        rootItem = nextRoot;
    }
    NSMenu *rootMenu = rootItem.menu;
    
    /// Find row that contains popupButton which has rootMenu (row which contains `item` / row which was clicked)
    
    NSInteger clickedRow = -1;
    
    for (int row = 0; row < self.tableView.numberOfRows; row++) {
        NSTableCellView *effectCell = [self.tableView viewAtColumn:1 row:row makeIfNecessary:YES]; /// Why is makeIfNecessary == YES?
        NSPopUpButton *pb = effectCell.subviews[0];
        NSMenu *m = pb.menu;
        
        if ([m isEqual: rootMenu]) {
            /// Clicked row found!
            clickedRow = row;
            break;
        }
    }
    
    /// Validate
    
    if (clickedRow == -1) {
        DDLogError(@"Couldn't find clickedRow in submenu item IBAction");
        return;
        /// TODO: Maybe handle this better? Crash the app so it doesn't corrupt data or sth?
    }
    
    /// Convert clicked index to base dataModel
    
    NSInteger clickedRowInBaseDataModel = [RemapTableUtility baseDataModelIndexFromGroupedDataModelIndex:clickedRow withGroupedDataModel:self.groupedDataModel];
    
    /// Set action dict from item model to dataModel
    
    NSDictionary *itemModel = item.representedObject;
    self.dataModel[clickedRowInBaseDataModel][kMFRemapsKeyEffect] = itemModel[@"dict"];
    
    /// Commit change
    [self writeDataModelToConfig];
    
    /// Reload table
    [self.tableView reloadData];
    
}

#pragma mark Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        /// Store self so other objects can access
        assert(MainAppState.shared.remapTableController == nil); /// Should only be instantiated once.
        MainAppState.shared.remapTableController = self;
    }
    return self;
}

- (void)awakeFromNib {
    /// Force Autohiding scrollers - to keep layout consistent (doesn't work)
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.scrollerStyle = NSScrollerStyleOverlay;
}

- (void)viewDidLoad {
    /// Not getting called for some reason -> I had to set the view outlet of the controller object in IB to the tableView.
    
    DDLogDebug(@"RemapTableView did load.");
    
    /// Set rounded corners and appropriate border
    
    NSScrollView * scrollView = self.scrollView;
    
    /// Get corner radius
    ///     The cornerRadius of the Action Table should be equal to cornerRadius of surrounding NSBox
    ///     Ideally we would access the cornerradius of the NSBox directly, but I don't know how
    
    CGFloat cr = 5.0;
    
    if (@available(macOS 11.0, *)) { } else {
        cr = 4.0;
    }
    
    /// Shrink Action Table pre-Mojave
    ///     Otherwise it spills out of the surrounding NSBox. Not sure why
    
    if (@available(macOS 10.14, *)) { } else {
        scrollView.frame = NSInsetRect(scrollView.frame, 2, 2);
    }
    
    scrollView.borderType = NSNoBorder;
    scrollView.wantsLayer = YES;
    scrollView.layer.masksToBounds = YES;
    scrollView.layer.borderWidth = 1.0;
    scrollView.layer.cornerRadius = cr;
    
    scrollView.automaticallyAdjustsContentInsets = NO;
    scrollView.contentInsets = NSEdgeInsetsMake(1, 1, 1, 1); /// Insets so the content doesn't overlap with the border
    
    updateBorderColor(self, YES);
    
    /// Callback on darkmode toggle
    /// In MMF3, the table doesn't overlap with the box border anymore. So we don't need to remove transparency. So we don't need to update the color manually when darkmode toggles. So we don't need this functions.
    ///     TODO: Remove keyValue observation! Not setBorderColor() though
    
    if (@available(macOS 10.14, *)) {
        [self observeValueForKeyPath:@"effectiveAppearance" ofObject:NSApp change:nil context:nil];
        [NSApp addObserver:self forKeyPath:@"effectiveAppearance" options:NSKeyValueObservingOptionNew context:nil];
    }
    
    [RemapTableTranslator initializeWithTableView:self.tableView];
    
    /// Initialize sorting
    [self initSorting];
    
    /// Load table data from config
    [self loadDataModelFromConfig];
    /// Do first sorting (Not sure where sorting and reloading is appropriate but this seems fine)
    [self sortDataModel];
    [self.tableView reloadData];
    
    /// Let the table do further init
    [(RemapTableView *)self.tableView coolDidLoad];
    
    /// Init addRemoveControl state
    [self updateAddRemoveControl];
}

static void updateBorderColor(RemapTableController *object, BOOL isInitialAppearance) {
    
    /// We want the border to be non-transparent because it looks weird. The only way to achieve this is to hardcode the colors.
    /// Also see ButtonTabController > updateColors() for more explanations
    /// Note: NSColor.separatorColor doesn't update properly when tolggling darkmode even though it's a system color. So that's another plus
    /// Update: These hardcoded solid colors don't work properly with desktop tinting. We'll use .separatorColor instead and make the table 1 px shorter to prevent the border from overlapping with the grid and looking weird. The overlap will still happen when you scroll but that's okay
    

        
        /// Check darkmode
    BOOL isDarkMode = NO;
    if (@available(macOS 10.14, *)) {
        isDarkMode = NSApp.effectiveAppearance.name == NSAppearanceNameDarkAqua;
    }
    
    
    /// Set to random color
    ///     Attempt to get border color  to render properly after darkmode switch. Doesn't work.
    
    object.scrollView.layer.borderColor = NSColor.blueColor.CGColor;
    
    /// Update borderColor
    /// Notes:
    /// - This is really just .separatorColor without transparency
    /// - This is copied from ButtonTabController > updateColors()
    
    if (isInitialAppearance) {
        
        /// v New system colors approach
        
        if (@available(macOS 10.14, *)) {
            object.scrollView.layer.borderColor = NSColor.separatorColor.CGColor;
        } else {
            object.scrollView.layer.borderColor = NSColor.gridColor.CGColor;
        }
        
    } else {
        
        /// v Old hardcoded colors approach
        ///     separatorColor breaks after darkmode switch (just disappears) (under Ventura 13.0, and earlier versions, too) so we fallback to this
        
        if (isDarkMode) {
            object.scrollView.layer.borderColor = [NSColor colorWithRed:57.0/255.0 green:57.0/255.0 blue:57.0/255.0 alpha:1.0].CGColor;
        } else {
            object.scrollView.layer.borderColor = [NSColor colorWithRed:227.0/255.0 green:227.0/255.0 blue:227.0/255.0 alpha:1.0].CGColor;
        }
        
    }
    

    
    ///
//    object.scrollView.layer.borderColor = NSColor.separatorColor.CGColor;
    
    
    /// Test
    ///     Doesn't seem to change anything
    object.scrollView.needsDisplay = true;
}

- (void)reloadAll {
    
    /// Used when resetting to default or when setting the initial remaps on first app start
    /// Similar to what we do in `- viewDidLoad`
        
    /// Capture notifs
//    NSSet<NSNumber *> *capturedButtonsBefore = [RemapTableUtility getCapturedButtons];
    
    /// Get old rows
    NSIndexSet *allRowsOld = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.groupedDataModel.count)];
    
    /// Refresh dataModel
    [self loadDataModelFromConfig];
    [self sortDataModel];
    
    /// Replace all rows
    /// - Using fade animation on removal makes the groupRow color black during the animation. So we turned animation off.
    /// - Since we don't animate we could also just call `reloadTable` instead of this.
    NSIndexSet *allRows = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.groupedDataModel.count)];
    [self.tableView removeRowsAtIndexes:allRowsOld withAnimation:NSTableViewAnimationEffectNone];
    [self.tableView insertRowsAtIndexes:allRows withAnimation:NSTableViewAnimationEffectNone];
    
    /// Update tableView size
    [(RemapTableView *)self.tableView updateSizeWithAnimation];
    
    /// Capture notifs
    ///     These are too long and obnoxious and not really helpful in this situation.
//    NSSet *capturedButtonsAfter = [RemapTableUtility getCapturedButtons];
//    [CaptureToasts showButtonCaptureToastWithBeforeSet:capturedButtonsBefore afterSet:capturedButtonsAfter];
}

#pragma mark - Delegate & Controller
/// Other methods from NSTableViewDelegate and NSTableViewConroller protocols

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self updateAddRemoveControl];
}

- (void)updateAddRemoveControl {
    if (self.tableView.selectedRow == -1) {
        /// No row selected
        [self.addRemoveControl setEnabled:NO forSegment:1];
    } else {
        [self.addRemoveControl setEnabled:YES forSegment:1];
    }
}

//- (NSArray<NSTableViewRowAction *> *)tableView:(NSTableView *)tableView rowActionsForRow:(NSInteger)row edge:(NSTableRowActionEdge)edge {
//        
//    /// Define swipe actions
//    
//    return nil;
//    
//    if ((NO)) {
//        
//        NSMutableArray *result = [NSMutableArray array];
//        
//        if (edge == NSTableRowActionEdgeTrailing) {
//            
//            NSTableViewRowAction *deleteAction = [NSTableViewRowAction rowActionWithStyle:NSTableViewRowActionStyleDestructive title:@"Delete" handler:^(NSTableViewRowAction * _Nonnull action, NSInteger row) {
//                [self removeRow:row];
//            }];
//            if (@available(macOS 11.0, *)) {
//                deleteAction.image = [NSImage imageWithSystemSymbolName:@"trash.fill" accessibilityDescription:@"Delete"];
//            }
//            
//            [result addObject:deleteAction];
//        }
//        
//        return result;
//    }
//}

#pragma mark - Observer

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    
    NSAppearance *newAppearance = change[@"new"];
    
    if ([keyPath isEqual:@"effectiveAppearance"]) {
        
        static NSAppearanceName initialAppearance = @"";
        static BOOL effectiveAppearanceIsInitialized = NO; /// Prevent table reload when appearance is initially set
        
        if (!effectiveAppearanceIsInitialized) { /// Could also check if change == nil here
            
            effectiveAppearanceIsInitialized = YES;
            initialAppearance = self.tableView.effectiveAppearance.name;
            
        } else {
            
            BOOL isInitialAppearance = [initialAppearance isEqual:newAppearance.name];
            updateBorderColor(self, isInitialAppearance);
            
            [self.tableView updateLayer];
            [self.tableView reloadData];
            /// ^ The only reason we do this is currently because the sfsymbols for the function keys should be different weight for darkmode and lightmode. Reloading the whole table is pretty inefficient, but it's fast enough.
        }
    }
    
}

#pragma mark - IBActions

- (IBAction)addRemoveControl:(NSSegmentedControl *)sender { /// TODO: Remove the addRemove controll stuff
    if (sender.selectedSegment == 0) {
        [self addButtonAction];
    } else {
        /// Get selected table row index
        if (self.tableView.selectedRowIndexes.count == 0) return;
        assert(self.tableView.selectedRowIndexes.count == 1);
        NSUInteger selectedRow = self.tableView.selectedRowIndexes.firstIndex;
        /// Remove selected row
        [self removeRow:selectedRow];
    }
}

- (IBAction)inRowRemoveButtonAction:(RemapTableButton *)sender {
    
    /// `tableView.clickedRow` worked on righ-click menus, but for the inline buttons it doesn't seem to.
    
    /// Get tableCell
    NSInteger result = [RemapTableUtility rowOfCell:sender.host inTableView:self.tableView];
    
    /// Delete ref from button
    ///     Maybe against retain cycles? Not sure if problem.
    sender.host = nil;
    
    /// Remove row
    if (result != -1) {
        [self coolRemoveRow:result];
    }
}

- (void)coolRemoveRow:(NSInteger)row {
    [self removeRow:row];
    [(RemapTableView *)self.tableView updateSizeWithAnimation];
}

- (void)removeRow:(NSInteger)rowToRemove {
    /// `rowToRemove` is relative to actual table / groupedDataModel. Not baseDataModel
    
    /// Capture notifs
    NSSet<NSNumber *> *capturedButtonsBefore = [RemapTableUtility getCapturedButtonsAndExcludeButtonsThatAreOnlyCapturedByModifier:NO];
    
    /// Get base data model index corresponding to selected table index
    NSUInteger dataModelRowToRemove = [RemapTableUtility baseDataModelIndexFromGroupedDataModelIndex:rowToRemove withGroupedDataModel:self.groupedDataModel];
    
    /// Save rowDict to be removed for later
    NSDictionary *removedRowDict = self.dataModel[dataModelRowToRemove];
    
    /// Remove object from data model at selected index, and write to file
    NSMutableArray *mutableDataModel = self.dataModel.mutableCopy;
    [mutableDataModel removeObjectAtIndex:dataModelRowToRemove];
    self.dataModel = (NSArray *)mutableDataModel;
    [self writeDataModelToConfig];
    [self loadDataModelFromConfig]; /// Not sure if necessary
    
    /// Remove rows from table with animation
    
    NSMutableIndexSet *rowsToRemoveWithAnimation = [[NSMutableIndexSet alloc] initWithIndex:rowToRemove];
    
    /// Check if a buttonGroupRow should be with animation removed, too
    MFMouseButtonNumber removedRowTriggerButton = [RemapTableUtility triggerButtonForRow:removedRowDict];
    BOOL buttonIsStillTriggerInDataModel = NO;
    for (NSDictionary *rowDict in self.dataModel) {
        if ([RemapTableUtility triggerButtonForRow:rowDict] == removedRowTriggerButton) {
            buttonIsStillTriggerInDataModel = YES;
            break;
        }
    }
    if (!buttonIsStillTriggerInDataModel) { /// Yes, we want to remove a group row, too
        [rowsToRemoveWithAnimation addIndex:rowToRemove-1];
    }
    
    /// Do remove rows with animation
    [self.tableView removeRowsAtIndexes:rowsToRemoveWithAnimation withAnimation:/*NSTableViewAnimationEffectNone*/NSTableViewAnimationSlideUp];
    
    /// Capture notifs
    NSSet *capturedButtonsAfter = [RemapTableUtility getCapturedButtonsAndExcludeButtonsThatAreOnlyCapturedByModifier:NO];
    [CaptureToasts showButtonCaptureToastWithBeforeSet:capturedButtonsBefore afterSet:capturedButtonsAfter];
}

- (void)addButtonAction {
///    [AddWindowController begin];
}

#pragma mark AddMode Interface

- (void)addRowWithHelperPayload:(NSDictionary *)payload {
    
    /// Capture notifs
    NSSet<NSNumber *> *capturedButtonsBefore = [RemapTableUtility getCapturedButtonsAndExcludeButtonsThatAreOnlyCapturedByModifier:NO];
    
    /// Make tableView key, so it's not greyed out
    [self.tableView.window makeFirstResponder:self.tableView];
    
    NSMutableDictionary *rowDictToAdd = payload.mutableCopy;
    /// ((Check if payload is valid tableEntry))
    
    /// Check if already in table
    NSIndexSet *existingIndexes = [self.groupedDataModel indexesOfObjectsPassingTest:^BOOL(NSDictionary * _Nonnull tableEntry, NSUInteger idx, BOOL * _Nonnull stop) {
        BOOL triggerMatches = [tableEntry[kMFRemapsKeyTrigger] isEqualTo:rowDictToAdd[kMFRemapsKeyTrigger]];
        BOOL modificationPreconditionMatches = [tableEntry[kMFRemapsKeyModificationPrecondition] isEqualTo:rowDictToAdd[kMFRemapsKeyModificationPrecondition]];
        return triggerMatches && modificationPreconditionMatches;
    }];
    NSAssert(existingIndexes.count <= 1, @"Duplicate remap triggers found in table");
    NSIndexSet *toHighlightIndexSet;
    if (existingIndexes.count == 0) {
        /// Fill out effect in payload with first effect from effects table (to make behaviour appropriate when user doesn't choose any effect)
        ///      We could also consider removing the tableEntry, if the user just dismisses the popup menu without choosing an effect, instead of this.
        rowDictToAdd[kMFRemapsKeyEffect] = [RemapTableTranslator getEffectsTableForRemapsTableEntry:rowDictToAdd][0][@"dict"];
        /// Add new row to data model
        self.dataModel = [self.dataModel arrayByAddingObject:rowDictToAdd];
        /// Sort data model
        [self sortDataModel];
        
        /// Display new row with animation and highlight by selecting it
        NSUInteger insertedIndex = [self.groupedDataModel indexOfObject:rowDictToAdd];
        NSMutableIndexSet *toInsertWithAnimationIndexSet = [NSMutableIndexSet indexSetWithIndex:insertedIndex];
        toHighlightIndexSet = [NSIndexSet indexSetWithIndex:insertedIndex];
        
        /// Check if there are new group row we'd like to insert with animation, too
        BOOL buttonIsNewlyTriggerInDataModel = YES;
        MFMouseButtonNumber triggerButtonForAddedRow = [RemapTableUtility triggerButtonForRow:rowDictToAdd];
        for (NSDictionary *rowDict in self.dataModel) {
            if ([rowDict isEqual:rowDictToAdd]) continue;
            MFMouseButtonNumber triggerButton = [RemapTableUtility triggerButtonForRow:rowDict];
            if (triggerButton == triggerButtonForAddedRow) {
                buttonIsNewlyTriggerInDataModel = NO;
                break;
            }
        }
        if (buttonIsNewlyTriggerInDataModel) { /// There is a group row to add with animation
            [toInsertWithAnimationIndexSet addIndex:insertedIndex-1];
        }
        
        /// Do insert with animation
        [self.tableView insertRowsAtIndexes:toInsertWithAnimationIndexSet withAnimation:/*NSTableViewAnimationEffectNone*/NSTableViewAnimationSlideDown];
        
        /// Update table size
        [(RemapTableView *)self.tableView updateSizeWithAnimation];
        
        /// Write new row to file (to make behaviour appropriate when user doesn't choose any effect)
        [self writeToConfig];
    } else {
        toHighlightIndexSet = existingIndexes;
    }
    
    /// Scroll to visible and select
    ///     Scrolling to visible sometimes doesn't work when the table is at maxSize
    
    [self.tableView selectRowIndexes:toHighlightIndexSet byExtendingSelection:NO];
    [self.tableView scrollRowToVisible:toHighlightIndexSet.firstIndex];
    
    /// Unselect rows when user clicks anywhere else
    static id _clickMonitor = nil;
    _clickMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        [self.tableView deselectAll:nil];
        if (_clickMonitor != nil) {
            [NSEvent removeMonitor:_clickMonitor];
            _clickMonitor = nil;
        }
        return event;
    }];
    
    /// Open the NSMenu on the newly created row's popup button
    NSUInteger openPopupRow = toHighlightIndexSet.firstIndex;
    NSTableView *tv = self.tableView;
    NSPopUpButton * popUpButton = [RemapTableUtility getPopUpButtonAtRow:openPopupRow fromTableView:tv];
    double delay = existingIndexes.count == 1 ? 0.0 : 0.2;
    [popUpButton performSelector:@selector(performClick:) withObject:nil afterDelay:delay];
    
    /// Capture notifs
    /// 
    NSSet<NSNumber *> *capturedButtonsAfter = [RemapTableUtility getCapturedButtonsAndExcludeButtonsThatAreOnlyCapturedByModifier:NO];
    [CaptureToasts showButtonCaptureToastWithBeforeSet:capturedButtonsBefore afterSet:capturedButtonsAfter];
    
//    if ([capturedButtonsBefore isEqual:capturedButtonsAfter]) {
        // If they aren't equal then `showButtonCaptureToastWithBeforeSet:` will show a notification
        //      This notification will not be interactable if we also open the popup button menu.
//        [popUpButton performSelector:@selector(performClick:) withObject:nil afterDelay:0.2];
//    }
}

#pragma mark - Data source

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    
    /// Get data for this row
    NSDictionary *rowDict = self.groupedDataModel[row];
    
    /// Create deep copy of row.
    ///  `getTriggerCellWithRowDict` is written badly and needs to manipulate some values nested in rowDict.
    ///  I we don't deep copy, the changes to rowDict will reflect into self.dataModel and be written to file causing corruption.
    ///      (The fact that rowDict is NSDictionary not NSMutableDictionary doesn't help, cause the stuff being manipulated is nested)
    rowDict = (NSDictionary *)[SharedUtility deepCopyOf:rowDict];
    
    if ([rowDict isEqual:RemapTableUtility.buttonGroupRowDict]) {
        
        ///
        /// Group row
        ///
        
        /// Hack: If we link the textField to the buttonGroupCell via the .textField property, the tableView will override our text styling, so we're linking to it via the nextKeyView prop
        /// Hack: We're adding 2 spaces in front of the Button string to make it position correclty
        
        MFMouseButtonNumber groupButtonNumber = [RemapTableUtility triggerButtonForRow:self.groupedDataModel[row+1]];
        NSTableCellView *buttonGroupCell = [self.tableView makeViewWithIdentifier:@"buttonGroupCell" owner:self];
        NSTextField *groupTextField = (NSTextField *)buttonGroupCell.nextKeyView;
        groupTextField.stringValue = stringf(@"  %@", [UIStrings getButtonString:groupButtonNumber context:kMFButtonStringUsageContextActionTableGroupRow].firstCapitalized);
        
        if (@available(macOS 11.0, *)) { } else {
            
            /// Fix groupRow text being too far left pre-Big Sur
            
            /// Old MMF 2 non-autolalyout fix
//            NSRect f = groupTextField.frame;
//            groupTextField.frame = NSMakeRect(f.origin.x + 6.0, f.origin.y, f.size.width - 6.0, f.size.height);
            
            /// New MMF 3 autolayout fix
            ///     It would probably be smarter to create and IBOutlet to the leading constraint instead of searching for it like this
            
            for (NSLayoutConstraint *c in groupTextField.superview.constraints) {
                if (c.firstAttribute == NSLayoutAttributeLeading || c.secondAttribute == NSLayoutAttributeLeading) {
                    c.constant += 8; /// This is set to -6 in IB I think
                    break;
                }
            }
        }
        
        return buttonGroupCell;
        
    } else if ([tableColumn.identifier isEqualToString:@"trigger"]) {
        
        ///
        /// Trigger cell
        ///
        
        /// The trigger column should display the trigger as well as the modification precondition
        return [RemapTableTranslator getTriggerCellWithRowDict:rowDict row:row];
        
    } else if ([tableColumn.identifier isEqualToString:@"effect"]) {
        
        ///
        /// Effect cell
        ///
        
        return [RemapTableTranslator getEffectCellWithRowDict:rowDict row:row tableViewEnabled:tableView.enabled];
        
    } else {
        
        @throw [NSException exceptionWithName:@"Unknown column identifier" reason:@"TableView is requesting data for a column with an unknown identifier" userInfo:@{@"requested data for column": tableColumn}];
        return nil;
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.groupedDataModel.count;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    
    /// Calculate trigger cell text height
    NSDictionary *rowDict = self.groupedDataModel[row];
    
    /// Case 1 - group row
    if ([rowDict isEqual:RemapTableUtility.buttonGroupRowDict]) {
        NSTableCellView *buttonGroupCell = [self.tableView makeViewWithIdentifier:@"buttonGroupCell" owner:self];
        return buttonGroupCell.frame.size.height;
    } else { /// Case 2 - normal row
        /// \discussion Getting height has proven very difficult because there are errors in the methods for calculating textField size or attributedString size.
        ///     An alternative to consider is to just force layout of the view and then measure that. (Like is done in the rewritten UI a lot.)
        ///     03.08.2022 This is still broken. When entering `Button 4 + Click and Scroll Button 3` the end of the line is cut off.
        ///     TODO: ^ Test method from [Utility_App actualTextViewWidth]
        ///         ... But we're dealing with an NSTextField not an NSTextView?
        ///     TODO: Implement auto row height!. That should fix all our worries. See https://developer.apple.com/forums/thread/126767.
        
        rowDict = (NSDictionary *)[SharedUtility deepCopyOf:rowDict];
        NSTableCellView *view = [RemapTableTranslator getTriggerCellWithRowDict:rowDict row:row];
        /// ^ These lines are copied from `tableView:viewForTableColumn:row:`. Should change this cause copied code is bad. Edit: This doesn't seem to be true anymore. I can't see copied text.
        NSTextField *textField = view.textField;
        NSMutableAttributedString *string = textField.effectiveAttributedStringValue.mutableCopy;
        
        CGFloat fieldWidth = textField.bounds.size.width; /// 326 for some reason, in IB it's 323
//        CGFloat fieldWdth = [Utility_App actualTextFieldWidth:textField]; /// So far this doesn't seem to make a difference to just calling `.bounds.size.width`
        CGFloat textHeight = [string heightAtWidth:fieldWidth];
        
        /// Get top and bottom margins around text from IB template
        NSTableCellView *templateView = [self.tableView makeViewWithIdentifier:@"triggerCell" owner:nil];
        NSTextField *templateTextField = templateView.subviews[0];
        CGFloat templateViewHeight = templateView.bounds.size.height;
        CGFloat templateTextFieldHeight = templateTextField.bounds.size.height;
        double vMargin = templateViewHeight - templateTextFieldHeight;
        
        /// Add margins and text height to get result
        CGFloat result = textHeight + vMargin;
        if (result == templateViewHeight) {
            return result;
        } else {
            DDLogDebug(@"Height of row %ld is non-standard - Template: %f, Actual: %f", (long)row, templateViewHeight, result);
            return result;
        }
    }
}

#pragma mark - Sorting the table

- (void)sortDataModel {
    self.dataModel = [self sortedDataModel:self.dataModel];
}

- (NSArray *)sortedDataModel:(NSArray *)dataModel {
    return [dataModel sortedArrayUsingDescriptors:self.tableView.sortDescriptors];
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
        /// Extract last element from button modification precondition and use that
        /// (This is why we need it mutable)
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
        
        /// Create mutable deep copies so we don't mess table up accidentally
        NSMutableDictionary *tableEntryMutable1 = (NSMutableDictionary *)[SharedUtility deepMutableCopyOf:tableEntry1];
        NSMutableDictionary *tableEntryMutable2 = (NSMutableDictionary *)[SharedUtility deepMutableCopyOf:tableEntry2];
        
        /// Get trigger info (button and level, duration, type)
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
        
        /// 1. Sort by button
        ///  Need to sort by button on top level to make button group rows work
        if (btn1 > btn2) {
            return NSOrderedDescending;
        } else if (btn1 < btn2) {
            return NSOrderedAscending;
        }
        
        /// Get modification precondition info
        NSDictionary *preconds1 = tableEntryMutable1[kMFRemapsKeyModificationPrecondition];
        NSDictionary *preconds2 = tableEntryMutable2[kMFRemapsKeyModificationPrecondition];
        
        /// 2.1 Sort by button precond
        NSArray *buttonSequence1 = preconds1[kMFModificationPreconditionKeyButtons];
        NSArray *buttonSequence2 = preconds2[kMFModificationPreconditionKeyButtons];
        uint64_t iterMax = MIN(buttonSequence1.count, buttonSequence2.count);
        DDLogInfo(@"DEBUG - buttonSequence1: %@, buttonSequence2: %@, iterMax: %@", buttonSequence1, buttonSequence2, @(iterMax));
        
        /// ^ We sometimes get a "index 0 beyond bounds for empty array" error for the `buttonSequence1[i]` instruction. Seemingly at random.
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
        /// If len is different, but everything up until iterMax is equal, take the shorter one
        if (buttonSequence1.count > buttonSequence2.count) {
            return NSOrderedDescending;
        } else if (buttonSequence1.count < buttonSequence2.count) {
            return NSOrderedAscending;
        }
        /// 2.2 Sort by keyboard precond
        NSNumber *modifierFlags1 = preconds1[kMFModificationPreconditionKeyKeyboard];
        NSNumber *modifierFlags2 = preconds2[kMFModificationPreconditionKeyKeyboard];
        if (modifierFlags1.integerValue > modifierFlags2.integerValue) {
            return NSOrderedDescending;
        } else if (modifierFlags1.integerValue < modifierFlags2.integerValue) {
            return NSOrderedAscending;
        }
        
        /// 1.1. Sort by trigger type (drag, scroll, button)
        NSArray *orderedTypes = @[@"button", @"scroll", @"drag"];
        NSUInteger typeIndex1 = [orderedTypes indexOfObject:type1];
        NSUInteger typeIndex2 = [orderedTypes indexOfObject:type2];
        if (typeIndex1 > typeIndex2) {
            return NSOrderedDescending;
        } else if (typeIndex1 < typeIndex2) {
            return NSOrderedAscending;
        }
        /// 1.2 Sort by click level
        if (lvl1 > lvl2) {
            return NSOrderedDescending;
        } else if (lvl1 < lvl2) {
            return NSOrderedAscending;
        }
        /// 1.3 Sort by duration
        NSArray *orderedDurations = @[kMFButtonTriggerDurationClick, kMFButtonTriggerDurationHold];
        NSUInteger durationIndex1 = [orderedDurations indexOfObject:dur1];
        NSUInteger durationIndex2 = [orderedDurations indexOfObject:dur2];
        if (durationIndex1 > durationIndex2) {
            return NSOrderedDescending;
        } else if (durationIndex1 < durationIndex2) {
            return NSOrderedAscending;
        }
        
        /// Can't order
        assert(false);
        return NSOrderedSame;
    }];
    [self.tableView setSortDescriptors:@[sd]];
}

#pragma mark - Group rows

NSArray *baseDataModel_FromLastGroupedDataModelAccess;
NSArray *groupedDataModel_FromLastGroupedDataModelAccess;

/// This applies `dataModelByInsertingButtonGroupRowsIntoDataModel:` to `self.dataModel` and returns the result. It also caches the result. and only recalculates when self.dataModel has changed since the last invocation.
- (NSArray *)groupedDataModel
{

//    [SharedUtility printInvocationCountWithId:@"groupedDataModel access count"];

    BOOL baseDataModelHasChanged = NO;
    if (baseDataModel_FromLastGroupedDataModelAccess == nil)
        baseDataModelHasChanged = YES;
    else if (![baseDataModel_FromLastGroupedDataModelAccess isEqual:self.dataModel])
        baseDataModelHasChanged = YES;

    if (baseDataModelHasChanged) {
        baseDataModel_FromLastGroupedDataModelAccess = (NSArray *)[SharedUtility deepCopyOf:self.dataModel];
        NSArray *newGroupedDataModel = [self dataModelByInsertingButtonGroupRowsIntoDataModel:self.dataModel];
        groupedDataModel_FromLastGroupedDataModelAccess = newGroupedDataModel;

        return newGroupedDataModel;
    } else {
        return groupedDataModel_FromLastGroupedDataModelAccess;
    }
}


/// Return a grouped dataModel with group row entries for each button
/// "dataModel" needs to be sorted by button for this to work. Otherwise crash.
- (NSArray *)dataModelByInsertingButtonGroupRowsIntoDataModel:(NSArray *)dataModel {
    
//    [SharedUtility printInvocationCountWithId:@"groupedDataModel recalc count"];
    
    NSMutableArray *groupedDataModel = dataModel.mutableCopy;
    
    MFMouseButtonNumber currentButton = -1;
    int r = 0;
    int insertedCount = 0;
    BOOL firstHasBeenOmitted = YES; // Set to no to omit first group row
    for (NSDictionary *rowDict in dataModel) {
        MFMouseButtonNumber rowButton = [RemapTableUtility triggerButtonForRow:rowDict];
        if ((int)rowButton > (int)currentButton) {
            currentButton = rowButton;
            if (!firstHasBeenOmitted) {
                firstHasBeenOmitted = YES;
            } else {
                // Insert group row into groupedDataModel
                [groupedDataModel insertObject:RemapTableUtility.buttonGroupRowDict atIndex:r+insertedCount];
                insertedCount++;
            }
            
        } else if ((int)rowButton < (int)currentButton) {
            // The datamodel isn't sorted by Button
            @throw [NSException exceptionWithName:@"DataModelNotSortedByButtonException" reason:nil userInfo:@{@"dataModel": dataModel}];
        }
        r++;
    }
    
    return groupedDataModel;
}
- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    
    NSDictionary *rowDict = self.groupedDataModel[row];
    
    if ([rowDict isEqual:RemapTableUtility.buttonGroupRowDict]) {

        return [ButtonGroupRowView new];
    }
    
    return nil;

//    return [self.tableView rowViewAtRow:row makeIfNecessary:YES];
    /// This line is involved in some weird `EXC_BAD_ACCESS (code=2` crash.
    /// The crash occurs seemingly at random when switching back and forth between different effects
    /// There seems to be an infinte loop in the stacktrace. Maybe.
    /// Crash doesn't seem to occur when returning `[NSTableRowView new]` or `nil` instead
}

/// Helper function for determining if a row is a group row

static BOOL isGroupRow(NSArray *groupedDataModel, NSInteger row) {
    return [groupedDataModel[row] isEqual:RemapTableUtility.buttonGroupRowDict];
}
/// Tell the tableView which rows are groupRows
- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row {
    return isGroupRow(self.groupedDataModel, row);
}
/// Disable selection of groupRows. This prevents users from deleting group rows which leads to problems.
- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    return !isGroupRow(self.groupedDataModel, row) && self.tableView.isEnabled;
}

/// The tableview will apply its own style to the NSTableCellViews' textField property in group rows.
/// This is an attempt at customizing the text style of group rows to our own liking but it didn't work.
/// The solution was to set the text field to a property other than `textField` so the tableView can't find the text field and override its style.
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    
    if (isGroupRow(self.groupedDataModel, row)) { /// Try to make groupRow text black. Doesn't work. The function is never called.
        NSTableCellView *cellView = cell;
        cellView.textField.textColor = NSColor.labelColor;
    }
    
}

@end
