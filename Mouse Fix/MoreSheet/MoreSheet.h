//
//  MoreSheet.h
//  Mouse Fix
//
//  Created by Noah Nübling on 31.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
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
