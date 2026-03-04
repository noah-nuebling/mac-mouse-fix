//
// --------------------------------------------------------------------------
// NSView+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "NSView+Additions.h"
#import "NSArray+Additions.h"
#import "SharedUtility.h"

@implementation NSView (Additions)

#pragma mark - Frame conversion

- (CGRect)rectInQuartzScreenCoordinates {
    /// Not sure if this still works when self.isFlipped. Should test that.
    return [SharedUtility cocoaToQuartzScreenSpace: [self.window convertRectToScreen: self.rectInWindowCoordinates]];
}

- (CGRect)rectInScreenCoordinates {
    return [self.window convertRectToScreen: self.rectInWindowCoordinates];
}

- (CGRect)rectInWindowCoordinates {
    return [self convertRect: self.bounds toView: nil];
}

#pragma mark - Accessing related views

- (NSArray<NSView *> *)nestedSubviews { /// Might be more efficient to use an iterator (didn't measure if it would matter though) [Mar 2026]
    
    auto result = [NSMutableArray new];
    [result addObjectsFromArray: self.subviews];
    for (NSView *subview in self.subviews) [result addObjectsFromArray: [subview nestedSubviews]];
    return result;
    
    #if 0 /** Old implementation using `-map:` and `-flattenedArray` (Replaced [Mar 4 2026] */
        NSArray<NSView *> *subviews = self.subviews;
        NSArray<NSArray<NSView *> *> *recursiveSubviews = [subviews map:^id _Nonnull(NSView *mappedView) {
            return mappedView.nestedSubviews;
        }];
        NSArray<NSView *> *recursiveSubviewsFlat = recursiveSubviews.flattenedArray;
        return [self.subviews arrayByAddingObjectsFromArray:recursiveSubviewsFlat];
    #endif
    
}

- (NSArray *)nestedSubviewsWithIdentifier:(NSUserInterfaceItemIdentifier)identifier {
    return viewsWithIdentifier(identifier, self.nestedSubviews);
}

- (NSArray *)subviewsWithIdentifier:(NSString *)identifier {
    return viewsWithIdentifier(identifier, self.subviews);
}

NSArray *viewsWithIdentifier(NSUserInterfaceItemIdentifier identifier, NSArray *views) {
    auto result = [NSMutableArray new];
    for (NSView *v in views) if ([v.identifier isEqualToString: identifier]) [result addObject: v];
    return result;
}

@end
