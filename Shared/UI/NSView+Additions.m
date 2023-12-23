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
    
    return [SharedUtility cocoaToQuartzScreenSpace:[self.window convertRectToScreen:self.rectInWindowCoordinates]];
}

- (CGRect)rectInScreenCoordinates {
    return [self.window convertRectToScreen:self.rectInWindowCoordinates];
}

- (CGRect)rectInWindowCoordinates {
    return [self convertRect:self.bounds toView:nil];
}

#pragma mark - Accessing related views

- (NSArray<NSView *> *)nestedSubviews {
    
    NSArray<NSView *> *subviews = self.subviews;
    NSArray<NSArray<NSView *> *> *recursiveSubviews = [subviews map:^id _Nonnull(NSView *mappedView) {
        return mappedView.nestedSubviews;
    }];
    NSArray<NSView *> *recursiveSubviewsFlat = recursiveSubviews.flattenedArray;
    return [self.subviews arrayByAddingObjectsFromArray:recursiveSubviewsFlat];
}

- (NSArray *)nestedSubviewsWithIdentifier:(NSUserInterfaceItemIdentifier)identifier {
    
    return viewsWithIdentifier(identifier, self.nestedSubviews);
}

- (NSArray *)subviewsWithIdentifier:(NSString *)identifier {
    
    return viewsWithIdentifier(identifier, self.subviews);
}

NSArray *viewsWithIdentifier(NSUserInterfaceItemIdentifier identifier, NSArray *viewArray) {
    
    NSMutableArray *outViews = [[NSMutableArray alloc] init];
    for (NSView *v in viewArray) {
        if ([v.identifier isEqualToString:identifier]) {
            [outViews addObject:v];
        }
    }
    return outViews;
}

@end
