//
// --------------------------------------------------------------------------
// RemapTableUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "Constants.h"


NS_ASSUME_NONNULL_BEGIN

@interface RemapTableUtility : NSObject

+ (NSInteger)rowOfCell:(NSTableCellView *)cell inTableView:(NSTableView *)tv;
+ (MFMouseButtonNumber)triggerButtonForRow:(NSDictionary *)rowDict;
+ (NSPopUpButton *)getPopUpButtonAtRow:(NSUInteger)popUpRow fromTableView:(NSTableView *)tv;
+ (NSDictionary *)buttonGroupRowDict;
+ (NSInteger)baseDataModelIndexFromGroupedDataModelIndex:(NSInteger)groupedModelIndex withGroupedDataModel:(NSArray *)groupedDataModel;
+ (NSSet<NSNumber *> *)getCapturedButtonsAndExcludeButtonsThatAreOnlyCapturedByModifier:(BOOL)excludeButtonsThatAreOnlyCapturedByModifier;
@end

NS_ASSUME_NONNULL_END
