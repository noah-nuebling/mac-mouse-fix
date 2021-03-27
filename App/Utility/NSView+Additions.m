//
// --------------------------------------------------------------------------
// NSView+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "NSView+Additions.h"
#import "NSArray+Additions.h"

@implementation NSView (Additions)

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
