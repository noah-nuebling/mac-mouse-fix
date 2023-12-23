//
// --------------------------------------------------------------------------
// NSView+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSView (Additions)

- (CGRect)rectInQuartzScreenCoordinates;
- (CGRect)rectInScreenCoordinates;
- (CGRect)rectInWindowCoordinates;

/// v Are these still used in MMF 3?

- (NSArray<NSView *> *)subviewsWithIdentifier:(NSString *)identifier;
- (NSArray<NSView *> *)nestedSubviews;
- (NSArray<NSView *> *)nestedSubviewsWithIdentifier:(NSUserInterfaceItemIdentifier)identifier;

@end

NS_ASSUME_NONNULL_END
