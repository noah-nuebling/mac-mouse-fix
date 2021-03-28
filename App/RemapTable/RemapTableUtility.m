//
// --------------------------------------------------------------------------
// RemapTableUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "RemapTableUtility.h"
#import "Constants.h"

@implementation RemapTableUtility

+ (MFMouseButtonNumber)triggerButtonForRow:(NSUInteger)row tableViewDataModel:(NSArray *)dataModel {
    NSDictionary *rowDict = dataModel[row];
    
    id triggerGeneric = rowDict[kMFRemapsKeyTrigger];
    
    if ([triggerGeneric isKindOfClass:NSDictionary.class]) {
        NSDictionary *triggerDict = (NSDictionary *)triggerGeneric;
        return ((NSNumber *)triggerDict[kMFButtonTriggerKeyButtonNumber]).intValue;
    } else if ([triggerGeneric isKindOfClass:NSString.class]) {
        NSArray *buttonModArray = rowDict[kMFRemapsKeyModificationPrecondition][kMFModificationPreconditionKeyButtons];
        NSDictionary *lastButtonModDict = buttonModArray.lastObject;
        return ((NSNumber *)lastButtonModDict[kMFButtonModificationPreconditionKeyButtonNumber]).intValue;
    }
    
    assert(false);
    return -1;
}

+ (NSPopUpButton *)getPopUpButtonAtRow:(NSUInteger)popUpRow fromTableView:(NSTableView *)tv {
    NSInteger tableColumn = [tv columnWithIdentifier:@"effect"];
    NSPopUpButton *popUpButton = [tv viewAtColumn:tableColumn row:popUpRow makeIfNecessary:NO].subviews[0];
    
    if (![popUpButton isKindOfClass:NSPopUpButton.class]) {
        @throw [NSException exceptionWithName:@"RowDoesntContainPopupButtonException" reason:nil userInfo:nil];
    }
    
    return popUpButton;
}

@end
