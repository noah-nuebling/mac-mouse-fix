//
// --------------------------------------------------------------------------
// RemapTableController.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RemapTableController :  NSViewController <NSTableViewDelegate>
- (void)addRowWithHelperPayload:(NSDictionary *)payload;
@property NSArray *dataModel;
//      ^ Is actually an NSMutableArray I think. Take care not to accidentally corrupt this!
//      ^ Exposing this so RemapTableDataSource can use it. Might not be the cleanest solution.

- (IBAction)handleEnterKeystrokeOptionSelected:(id)sender;
- (IBAction)setConfigToUI:(id)sender;
@end

NS_ASSUME_NONNULL_END
