//
// --------------------------------------------------------------------------
// MoreSheet.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MoreSheet : NSWindowController
+ (MoreSheet *)instance;
- (void)begin;
- (void)end;
@end

NS_ASSUME_NONNULL_END
