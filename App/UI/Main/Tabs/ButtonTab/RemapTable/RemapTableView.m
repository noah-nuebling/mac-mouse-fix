//
// --------------------------------------------------------------------------
// MFTableView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Auto-adjust width like this: https://stackoverflow.com/questions/35657740/automatically-adjust-width-of-a-view-based-nstableview-based-on-content

#import "RemapTableView.h"
#import "Mac_Mouse_Fix-Swift.h"

@interface RemapTableView ()

@property (weak) IBOutlet MFScrollView *scrollView;
@property (weak) IBOutlet NSLayoutConstraint *scrollViewMaxHeightConstraint;

@end

@implementation RemapTableView {
    NSLayoutConstraint *_heightConstraint;
}



- (instancetype)init {
    
    /// This is seemingly never called
    
    if (self = [super init]) {
        
        self.intercellSpacing = NSMakeSize(20,20);

    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    
    /// This is seemingly called before the view has loaded it's rows
    
    if (self = [super initWithCoder:coder]) {

        
        
    }
    return self;
}


- (void)coolDidLoad {
 
    /// This is called after the table has loaded all it's rows for the first time.
    ///     Edit: it seemingly won't have created the actual tableCellViews, yet though.
    
    /// Init size and height constraint
    ///     This shouldn't be necessary since we update the size when we switch to the button tab, but it's sometimes wrong and I think this might help.
//    [self updateSizeWithAnimation:NO tabContentView:nil];
    
    /// Set column widths
    [self updateColumnWidths];
    
}

- (void)didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
        
    BOOL isGroupRow = rowView.subviews.count == 1;
    
    if (!isGroupRow) {
        RemapTableCellView *leftCell = [rowView viewAtColumn:0];
        RemapTableCellView *rightCell = [rowView viewAtColumn:1];
        [leftCell coolInitAsTriggerCellWithColumnWidth:triggerColumWidth];
        [rightCell coolInitAsEffectCellWithColumnWidth:effectColumnWidth];
    }
}

/// (?) Need this to make keystroke capture field first responder
/// See https://stackoverflow.com/questions/29986224/editable-nstextfield-in-nstableview
///- (BOOL)validateProposedFirstResponder:(NSResponder *)responder forEvent:(NSEvent *)event {
///    return YES;
///}

///- (void)drawGridInClipRect:(NSRect)clipRect {
///    [NSColor.redColor setFill];
///    NSRectFill(clipRect);
///}

//- (NSMenu *)menuForEvent:(NSEvent *)event {
//    
//    NSPoint clickedPoint = [self convertPoint:event.locationInWindow fromView:nil];
//    NSInteger clickedRow = [self rowAtPoint:clickedPoint];
//    
//    if (clickedRow != -1) {
//        if ([self.delegate tableView:self shouldSelectRow:clickedRow]) {
//            /// Select clicked row
//            NSIndexSet *idx = [NSIndexSet indexSetWithIndex:clickedRow];
//            [self selectRowIndexes:idx byExtendingSelection:NO];
//            /// Open menu
//            return [super menuForEvent:event];
//        }
//    } else {
//        
//        /// Unselect currently selected row
//        [self deselectAll:nil];
//        
//        /// Create add menu
//        NSMenuItem *addItem = [[NSMenuItem alloc] init];
//        addItem.title = @"Add"; //// TODO:  Localize this
//        addItem.image =  [SFSymbolStrings imageWithSymbolName:@"plus.square"];
//        addItem.target = self.delegate;
//        addItem.action = @selector(addButtonAction);
//        
//        NSMenu *addMenu = [[NSMenu alloc] init];
//        [addMenu addItem:addItem];
//        
//        /// Return add Menu
//        return addMenu;
//    }
//    
//    return nil;
//}

- (void)mouseDown:(NSEvent *)event {
    
    /// We used to do fancy selection logic here in MMF2, but it's all simpler in MMF2 and handeled elsewhere. See`addRowWithHelperPayload:`
    ///     Other selection code like `tableView:shouldSelectRow:` should now also be obsolete, but it works so eh
    
//    NSPoint clickedPoint = [self convertPoint:event.locationInWindow fromView:nil];
//    NSInteger clickedRow = [self rowAtPoint:clickedPoint];
    
//    [super mouseDown:event];
}


double triggerColumWidth = -1;
double effectColumnWidth = -1;
NSMutableArray *columnConstraints = nil;

- (void)updateColumnWidths {
    
    /// Create columnConstraints array
    if (columnConstraints == nil) {
        columnConstraints = [NSMutableArray array];
    }
    
    /// Delete existing columnConstraints
    [self.enclosingScrollView removeConstraints:columnConstraints];
    [columnConstraints removeAllObjects];
    
    /// Define constant
    ///     Also see RemapTableCellView > columnPadding for context
    double columnPadding = 8.0;
    
    /// Calculate column widths
    
    for (int c = 0; c < self.numberOfColumns; c++) {
        
        /// Get columnWidth
        
        double columnWidth = 0;
        
        for (int r = 0; r < self.numberOfRows; r++) {
        
            NSTableCellView *v = [self viewAtColumn:c row:r makeIfNecessary:YES];
            columnWidth = MAX(columnWidth, v.fittingSize.width);
        }
        
        /// Weird hacky stuff
        ///     Makes the effectRow wider so the text in the buttons isn't as crammed.
        ///     Idk why or how any of this works
        columnWidth += 10;
        
        /// Set all tableCells equal columnWidth
        ///     Need to set priority 999 because some mysterious `UIView-Encapsulated-Layout-Width` constraints are being added by the tableView and break our constraints. It doesn't seem to make a difference so far though.
        for (int r = 0; r < self.numberOfRows; r++) {
            NSTableCellView *v = [self viewAtColumn:c row:r makeIfNecessary:YES];
            if ([v.identifier isEqual:@"buttonGroupCell"]) continue;
            NSLayoutConstraint *c = [v.widthAnchor constraintEqualToConstant:columnWidth];
            c.priority = 999;
            [c setActive:YES];
        }
        
        /// Store columnWidth
        if (c == 0) {
            triggerColumWidth = columnWidth;
        } else if (c == 1) {
            effectColumnWidth = columnWidth;
        } else {
            assert(false);
        }
    }
    
    /// Guard no width
    ///     If the table is loaded with no rows, then the effectColumnWidth will be almost 0 which breaks things
    ///     So we fallback to this
    ///     Note: It makes sense to just use frame.size since self has already been layed out at this point
    if (effectColumnWidth < 20) {
        effectColumnWidth = self.frame.size.width / 2.0;
    }
    
    /// Set min tableWidth based on content
    ///     Not sure if this is necessary since we really want the tableWidth to be determined by the rest of the layout.
    ///     If the triggerCells are superwide we just want them to wrap, not make the table super wide
    ///         I think we'll just set a minimum width in IB and then let it grow beyond that based on the addField hint.
    ///     You can only set this on the enclosing scrollView, not the tableView itself!. Even though they are just set to have the exact same size. Not sure why. Autolayout is weird.
    /// This doesn't work, the effectCell popupButtons' text can still be cut off.
    ///     Edit: Fixed it I think with [effectColumn setMinWidth:]
    
    double minTableWidth = effectColumnWidth * 2 + 4*columnPadding;
    
    NSLayoutConstraint *c = [self.enclosingScrollView.widthAnchor constraintGreaterThanOrEqualToConstant:minTableWidth];
    [c setActive:YES];
    NSLayoutConstraint *c2 = [self.enclosingScrollView.widthAnchor constraintEqualToConstant:minTableWidth];
    c2.priority = 999.0;
    [c2 setActive:YES];
    
    [columnConstraints addObject:c];
    [columnConstraints addObject:c2];
    
    /// Set effect column width
    /// Notes: Setting the column width higher does seem to make it wider but not linearly? And at some point it just stops growing?
//    [self sizeLastColumnToFit];
    NSTableColumn *effectColumn = self.tableColumns[1];
    [effectColumn setMinWidth:effectColumnWidth]; /// Don't don't I'm desparate. TF this works!! ... story of AppKit programming. Actually it just makes both colums equal sized. Weird. Edit; Also setting maxWidth it works!
    [effectColumn setMaxWidth:effectColumnWidth];
    
}

- (void)updateSizeWithAnimation {
    
    /// Should be called by controller when adding / removing a row. We can't use didAddRow and didRemoveRow, because they are called all the time when views are being recycled and stuff
    
    [self updateSizeWithAnimation:YES tabContentView:nil];
}

- (void)updateSizeWithAnimation:(BOOL)animate tabContentView:(NSView *_Nullable)tabContentView {
    
    /// Investigation on glitchy size when opening app directly into Buttons tab
    ///   - (Only happens when the tableView content is too large for the window to fit on screen, so when the maxHeightConstraint comes into play)
    ///   - This is called twice in a row, when the app opens into ButtonTab directly. because ButtonTabController.viewDidAppear() is called twice in a row (Is that an Apple bug?). Not totally sure if that's relevant. Both times, this method sets the same height and maxHeight constraints as far as I've seen. Yet still, the whole window first renders too small, with the bottom row of buttons squished, before becoming slightly too big to fit on the screen.
    ///   - Update: We set the vertical compression resistance on the button row and the buttons to 1000 and now the window ends up snapping to the correct size. But still shows up too small at first.
    
    ///
    /// Update scrollView maxHeight
    ///     So the window doesn't grow bigger than the screen
    /// Notes:
    /// - Not sure this scrollView height code belongs here but this way we have all the height code in one place.
    /// - Need to pass in tabContentView if this is called during a tabSwitch to get the correct `windowDiff`. That is the height difference between the actionTable and the window when both have been fully layed out and the tabSwitch animation has finished.
    /// - We only really need to update this when the screen size changes, but that would make the code more complicated, and performance doesn't really matter here.
    /// - Limiting to 500.0 is an aesthetic choice
    
    double scrollH = self.scrollView.frame.size.height;
    double windowH;
    if (tabContentView != nil) {
        windowH = [self.window frameRectForContentRect:tabContentView.frame].size.height;
    } else {
        windowH = self.window.frame.size.height;
    }
    double windowHDiff = windowH - scrollH;
    double screenH = self.window.screen.visibleFrame.size.height;
    double maxH = MIN(screenH - windowHDiff, /*500.0*/INFINITY);
    
    self.scrollViewMaxHeightConstraint.constant = maxH;
    
    ///
    /// Update table size
    ///
    
    /// Init self height constraint
    
    if (_heightConstraint == nil) {
        _heightConstraint = [self.heightAnchor constraintEqualToConstant:0];
        _heightConstraint.priority = 1000;
        [_heightConstraint setActive:YES];
    }
    
    /// Get newSize
    /// - `+ 1` to prevent overlap between scrollView border and tableView grid, which looks weird. Also doing that in [RemapTableView coolDidLoad]
    
    NSSize z = self.intrinsicContentSize;
    NSSize newSize = NSMakeSize(z.width, z.height + 1);
    
    /// Change content size
    
    [self setFrameSize:newSize]; /// THIS FIXES EVERYTHING I'M AN APE IN FRONT OF A TYPEWRITER

    if (animate) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
            context.duration = 0.25;
            _heightConstraint.animator.constant = newSize.height;
            
        }];
    } else {
        _heightConstraint.constant = newSize.height;
    }
}

@end
