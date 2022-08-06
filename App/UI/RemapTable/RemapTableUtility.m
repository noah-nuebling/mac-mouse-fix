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
#import "AppDelegate.h"
#import "SharedUtility.h"

@implementation RemapTableUtility

+ (MFMouseButtonNumber)triggerButtonForRow:(NSDictionary *)rowDict {
    
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
    NSView *cell = [tv viewAtColumn:tableColumn row:popUpRow makeIfNecessary:NO];
    NSPopUpButton *popUpButton = cell.subviews[0];
    
    if (![popUpButton isKindOfClass:NSPopUpButton.class]) {
        @throw [NSException exceptionWithName:@"RowDoesntContainPopupButtonException" reason:nil userInfo:nil];
    }
    
    return popUpButton;
}

#pragma mark - Group rows

/// This stuff is accessed by both RemapTableController and RemapTableTranslator, but nothing else.
/// Those two have tons of interplay and access to eachothers properties which no other part of the app needs access to.
/// I feel like they are screaming to be one class - it would allow us to make lots of properties and functions private - but I split them up because RemapsTableController was getting wayy too big.
/// If they were one class this stuff v would be part of that class.

+ (NSDictionary *)buttonGroupRowDict {
    
    return @{@"buttonGroupRow": @YES};
}

/// Use this when you want to mutate the base data model (self.dataModel) based on an index from the table.
/// self.groupedDataModel as well as the tableView have extra group rows which make the indexes of corresponding rows shifted compared to the base data model
/// We only want to mutate the base data model (`self.dataModel`). The groupedDataModel as well as the table are derived from it.
/// @param groupedModelIndex The index to convert. Function will crash if this param is the index of a group row.
+ (NSInteger)baseDataModelIndexFromGroupedDataModelIndex:(NSInteger)groupedModelIndex withGroupedDataModel:(NSArray *)groupedDataModel {
    
    int i = 0;
    int groupRowCtr = 0;
    
    while (true) {
        if ([groupedDataModel[i] isEqual:RemapTableUtility.buttonGroupRowDict]) {
            groupRowCtr++;
            
            NSAssert(i != groupedModelIndex, @"Invalid input: groupedModelIndex is index of a group row");
        }
        
        if (i == groupedModelIndex)
            break;
        
        i++;
    }
    
    return groupedModelIndex - groupRowCtr;
}

#pragma mark - Get captured buttons

+ (NSSet<NSNumber *> *)getCapturedButtons {
    
    NSArray *dataModel = AppDelegate.instance.remapTableController.dataModel;
    
    NSMutableSet<NSNumber *> *capturedButtons = [NSMutableSet set];
    
    for (int b = 1; b <= kMFMaxButtonNumber; b++) {
        
        /// Go through all preconds and corresponding modifications and check if button occurs anywhere
        for (NSDictionary *rowDict in dataModel) {
            
            NSDictionary *modificationPrecondition = rowDict[kMFRemapsKeyModificationPrecondition];
            NSDictionary *trigger = rowDict[kMFRemapsKeyTrigger];
            
            BOOL buttonIsTrigger = NO;
            if ([trigger isKindOfClass:NSDictionary.class]) { // Trigger is type button
                buttonIsTrigger = [trigger[kMFButtonTriggerKeyButtonNumber] isEqual:@(b)];
            }
            
            if (buttonIsTrigger) {
                [capturedButtons addObject:@(b)];
                goto nextButton;
            }
            if ([SharedUtility button:@(b) isPartOfModificationPrecondition:modificationPrecondition]) {
                [capturedButtons addObject:@(b)];
                goto nextButton;
            }
        }
    nextButton:;
    }
    return capturedButtons;
}

@end
