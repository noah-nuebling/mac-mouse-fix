//
// --------------------------------------------------------------------------
// MFTableView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

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


- (NSLayoutConstraint *)heightConstraint {
    
    /// Can't find an init function that is called after the rows have been loaded , so we're using this instead.
    
    if (_heightConstraint ==  nil) {
        _heightConstraint = [self.heightAnchor constraintEqualToConstant:self.intrinsicContentSize.height];
        _heightConstraint.priority = 1000;
        [_heightConstraint setActive:YES];
    }
    
    return _heightConstraint;
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

    int rowHeight = 30;
    
    [self setFrameSize:self.intrinsicContentSize]; /// THIS FIXES EVERYTHING I'M AN APE IN FRONT OF A TYPEWRITER
    
//    NSRect oldBounds = self.enclosingScrollView.contentView.bounds;
//    self.enclosingScrollView.contentView.bounds = NSMakeRect(oldBounds.origin.x, oldBounds.origin.y - rowHeight, oldBounds.size.width, oldBounds.size.height);
    
//    [((NSClipView *)self.enclosingScrollView.contentView) scroll
    
    /// Should be called by controller when adding / removing a row. We can't use didAddRow and didRemoveRow, because they are called all the time when views are being recycled and stuff

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
        context.duration = 0.25;
//        context.duration = 2.0;
        [self heightConstraint].animator.constant = self.intrinsicContentSize.height;

    }];

//    [self heightConstraint].constant = self.intrinsicContentSize.height;
    
    /// Debug
    
    DDLogDebug(@"UPDATE SIZE WITH ANIMATMION");
}

@end
