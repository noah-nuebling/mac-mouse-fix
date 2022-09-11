//
// --------------------------------------------------------------------------
// Hyperlink.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>


@interface Hyperlink : NSTextField

+ (instancetype)hyperlinkWithTitle:(NSString *)title url:(NSString *)href alwaysTracking:(BOOL)alwaysTracking leftPadding:(int)leftPadding;

@end
