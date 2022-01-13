//
// --------------------------------------------------------------------------
// MFTableView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MFTableView.h"

@implementation MFTableView

// (?) Need this to make keystroke capture field first responder
// See https://stackoverflow.com/questions/29986224/editable-nstextfield-in-nstableview
//- (BOOL)validateProposedFirstResponder:(NSResponder *)responder forEvent:(NSEvent *)event {
//    return YES;
//}

//- (void)drawGridInClipRect:(NSRect)clipRect {
//    [NSColor.redColor setFill];
//    NSRectFill(clipRect);
//}

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
    
    NSPoint clickedPoint = [self convertPoint:event.locationInWindow fromView:nil];
    NSInteger clickedRow = [self rowAtPoint:clickedPoint];
    
    if (clickedRow != -1) {
        if (![self.delegate tableView:self shouldSelectRow:clickedRow]) {
            /// Unselect currently selected row
            [self deselectAll:nil];
        }
    }
    
    [super mouseDown:event];
}

@end
