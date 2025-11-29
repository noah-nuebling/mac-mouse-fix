//
// --------------------------------------------------------------------------
// Hyperlink.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>
#import "Links.h"

@interface Hyperlink : NSTextField

+ (instancetype)hyperlinkWithTitle:(NSString *)title linkID:(MFLinkID)linkID alwaysTracking:(BOOL)alwaysTracking leftPadding:(int)leftPadding;

@end
