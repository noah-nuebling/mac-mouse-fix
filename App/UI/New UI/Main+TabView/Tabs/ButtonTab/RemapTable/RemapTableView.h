//
// --------------------------------------------------------------------------
// MFTableView.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RemapTableView : NSTableView

- (void)coolDidLoad;
- (void)updateSizeWithAnimation;

@end

NS_ASSUME_NONNULL_END
