//
// --------------------------------------------------------------------------
// RemapTableController.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// Were exposing most of this just so RemapTableTranslator can use it. Might not be the cleanest solution.

@interface RemapTableController :  NSViewController <NSTableViewDelegate>


///
/// Interaction with `RemapTableTranslator`
///     `dataModel` Is actually an NSMutableArray I think. Take care not to accidentally corrupt this!
@property NSArray *dataModel;
@property (readonly) NSArray *groupedDataModel;

- (void)addRowWithHelperPayload:(NSDictionary *)payload;
- (IBAction)handleKeystrokeMenuItemSelected:(id)sender;
- (IBAction)updateTableAndWriteToConfig:(id _Nullable)sender;

///
/// Interation with `ButtonTabController`
///
- (void)reloadAll;

@end

NS_ASSUME_NONNULL_END
