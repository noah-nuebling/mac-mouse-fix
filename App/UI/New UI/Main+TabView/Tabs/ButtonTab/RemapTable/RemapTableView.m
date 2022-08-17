//
// --------------------------------------------------------------------------
// MFTableView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// Auto-adjust width like this: https://stackoverflow.com/questions/35657740/automatically-adjust-width-of-a-view-based-nstableview-based-on-content

#import "RemapTableView.h"
#import "Mac_Mouse_Fix-Swift.h"

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

- (void)didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
        
    BOOL isGroupRow = rowView.subviews.count == 1;
    
    if (!isGroupRow) {
        [(RemapTableCellView *)[rowView viewAtColumn:0] coolInitAsTriggerCell];
        [(RemapTableCellView *)[rowView viewAtColumn:1] coolInitAsEffectCell];
    }
}

- (void)coolDidLoad {
 
    /// This is called after the table has loaded all it's rows for the first time.
    ///     Edit: it seemingly won't have created the actual tableCellViews, yet though.
    
    /// Init height constraint
    _heightConstraint = [self.heightAnchor constraintEqualToConstant:self.intrinsicContentSize.height];
    _heightConstraint.priority = 1000;
    [_heightConstraint setActive:YES];
    
    /// Calculate width
    
    
    double tableWidth = 0;
    for (int r = 0; r < self.numberOfRows; r++) {
        
        double rowWidth = 0;
        
        for (int c = 0; c < self.numberOfColumns; c++) {
            NSTableCellView *v = [self viewAtColumn:c row:r makeIfNecessary:YES];
            rowWidth += v.fittingSize.width;
        }
        tableWidth = MAX(tableWidth, rowWidth);
    }
    
    /// Set width constraint
    
    NSLayoutConstraint *c = [self.widthAnchor constraintEqualToConstant:tableWidth];
    
    c.priority = 999;
    [c setActive:YES];
    
    NSLayoutConstraint *c2 = [self.widthAnchor constraintLessThanOrEqualToConstant:tableWidth];
    c2.priority = 1000;
    [c2 setActive:YES];
    
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

- (NSMenu *)menuForEvent:(NSEvent *)event {
    
    NSPoint clickedPoint = [self convertPoint:event.locationInWindow fromView:nil];
    NSInteger clickedRow = [self rowAtPoint:clickedPoint];
    
    if (clickedRow != -1) {
        if ([self.delegate tableView:self shouldSelectRow:clickedRow]) {
            /// Select clicked row
            NSIndexSet *idx = [NSIndexSet indexSetWithIndex:clickedRow];
            [self selectRowIndexes:idx byExtendingSelection:NO];
            /// Open menu
            return [super menuForEvent:event];
        }
    } else {
        
        /// Unselect currently selected row
        [self deselectAll:nil];
        
        /// Create add menu
        NSMenuItem *addItem = [[NSMenuItem alloc] init];
        addItem.title = @"Add";
        addItem.image = [NSImage imageNamed:@"plus.square"];
        addItem.target = self.delegate;
        addItem.action = @selector(addButtonAction);
        
        NSMenu *addMenu = [[NSMenu alloc] init];
        [addMenu addItem:addItem];
        
        /// Return add Menu
        return addMenu;
    }
    
    return nil;
}

- (void)mouseDown:(NSEvent *)event {
    
    /// We used to do fancy selection logic here in MMF2, but it's all simpler in MMF2 and handeled elsewhere. See`addRowWithHelperPayload:`
    ///     Other selection code like `tableView:shouldSelectRow:` should now also be obsolete, but it works so eh
    
//    NSPoint clickedPoint = [self convertPoint:event.locationInWindow fromView:nil];
//    NSInteger clickedRow = [self rowAtPoint:clickedPoint];
    
//    [super mouseDown:event];
}

- (void)updateSizeWithAnimation {
    
    [self setFrameSize:self.intrinsicContentSize]; /// THIS FIXES EVERYTHING I'M AN APE IN FRONT OF A TYPEWRITER
    
//    NSRect oldBounds = self.enclosingScrollView.contentView.bounds;
//    self.enclosingScrollView.contentView.bounds = NSMakeRect(oldBounds.origin.x, oldBounds.origin.y - rowHeight, oldBounds.size.width, oldBounds.size.height);
    
//    [((NSClipView *)self.enclosingScrollView.contentView) scroll
    
    /// Should be called by controller when adding / removing a row. We can't use didAddRow and didRemoveRow, because they are called all the time when views are being recycled and stuff

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
        context.duration = 0.25;
        _heightConstraint.animator.constant = self.intrinsicContentSize.height;

    }];

//    [self heightConstraint].constant = self.intrinsicContentSize.height;
    
    /// Debug
    
    DDLogDebug(@"UPDATE SIZE WITH ANIMATMION");
}

@end
