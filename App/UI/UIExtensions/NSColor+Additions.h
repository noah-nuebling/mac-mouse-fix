//
// --------------------------------------------------------------------------
// NSColor+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSView (ColorAdditions)

- (NSColor *)solidColorAtX:(NSInteger)x y:(NSInteger)y;

@end

@interface NSColor (Additions)

- (NSColor *)flippedColor;
- (NSColor *)solidColorWithBackground:(NSColor *)background;
- (NSColor *)solidColor;

@end

NS_ASSUME_NONNULL_END
