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
/**
 Dismisses the more sheet currently attached to the main window.
 
 Use this method when you don't hold a reference to the instance of more sheet you want to dismiss.
 */
+ (void)endMoreSheetAttachedToMainWindow;
- (void)begin;
- (void)end;
@end

NS_ASSUME_NONNULL_END
