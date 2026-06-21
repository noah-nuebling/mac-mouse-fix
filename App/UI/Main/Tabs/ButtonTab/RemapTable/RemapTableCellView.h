//
// --------------------------------------------------------------------------
// RemapTableCellView.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>

@interface RemapTableCellView : NSTableCellView

- (void) coolInitAsTriggerCellWithColumnWidth: (double)columnWidth;
- (void) coolInitAsEffectCellWithColumnWidth: (double)columnWidth;

@end
