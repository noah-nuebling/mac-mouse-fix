//
// --------------------------------------------------------------------------
// CheckBoxCell.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface CheckBoxCell : NSTableCellView

@property (nonatomic,strong) NSButton *checkbox;

@end

NS_ASSUME_NONNULL_END
