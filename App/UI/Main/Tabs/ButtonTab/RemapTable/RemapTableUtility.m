//
// --------------------------------------------------------------------------
// RemapTableUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "RemapTableUtility.h"
#import "Constants.h"
#import "AppDelegate.h"
#import "SharedUtility.h"
#import "Mac_Mouse_Fix-Swift.h"

@implementation RemapTableUtility

#pragma mark - Row <-> Objects

+ (NSInteger)rowOfCell:(NSTableCellView *)cell inTableView:(NSTableView *)tv {
    
    /// Find row index of tableCell
    NSInteger result = -1;
    for (int i = 0; i < tv.numberOfRows; i++) {
        for (int j = 0; j < tv.numberOfColumns; j++) {
            NSTableCellView *c = [tv viewAtColumn:j row:i makeIfNecessary:NO];
            if ([c isEqual:cell]) {
                result = i;
                break;
            }
        }
    }
    
    return result;
}

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

+ (NSSet<NSNumber *> *)getCapturedButtonsAndExcludeButtonsThatAreOnlyCapturedByModifier:(BOOL)excludeButtonsThatAreOnlyCapturedByModifier {
    
    /// Discussion of `excludeButtonsThatAreCapturedByModifier` arg:
    /// - This arg makes it so we tell the user, that we consider a button as not captured, if that button is only captured while a modifier is held down.
    /// - We introduced this arg for use with capture notifications, but I don't think we should use it for capture notifications. Here's why:
    /// - Setting this arg to YES, makes it so we treat buttons the same as we treat the scrollwheel, when it comes to capture notifications: If the scrollwheel is not captured without holding any modifiers, but the scrollwheel **can** be captured by holding down a modifier - then we tell the user that the scrollwheel is **not** captured.
    /// - But for buttons, I think it makes more sense to set this special param to NO, which leads to the opposite behavior: If the button is not captured without holding any modifiers, but the button **can** be captured by holding down a modifier - then we tell the user that a button **is** captured.
    ///
    /// - Reasoning behind this different messaging to the user about scrollwheel capturing vs button capturing:
    ///     - Basically we want to be able to explain to the user: """Here's a clear and (relatively) simple way that you can see and configure whether a button/scrollwheel is captured or not. So if you want the button / scrollwheel to behave as if Mac Mouse Fix is not running, (which I assume to generally be the goal for users) - then you know just what to do!"""
    ///     - ... The simple explanation for buttons is: If a button shows up on the left side of the ActionTable, then it is captured. Otherwise it's not captured.
    ///     - ... The simple explanation for scrolling is: If smoothness, speed, and reverse is turned off, then the scrollwheel is not captured. Otherwise it is captured.
    ///     - Now we have this edgeCase where these simple explanations aren't entirely true: When the button/scrollwheel is captured, *but only so long as a modifier is held down*.
    ///         - To explain this edge case for the scrollwheel, we'd have to say: The simple rule holds true for the most part, with the exception that, if there are any keyboard modifiers at the bottom of the scrolling tab OR there are any Click and Scroll gestures on the ActionTable on the Buttons tab, then the scrollwheel is actually STILL captured while you hold down one of those keyboard modifiers or while you perform the Click and Scroll gesture by holding down a button. (This would be up-to-date as of MMF 3.0.2)
    ///         - To explain this edge case for buttons, we'd have to say: The simple rule holds true for the most part, with the exception that, in case all rows that contain the button - or that are inside the row-group of that button - have a modifier, (that can be a keyboard modifier or another button, used in a SteerMouse-style button chord), then the button is only captured while one of those keyboard modifiers or other mouse buttons is held down. (This would be up-to-date as of MMF 3.0.2)
    ///
    ///         -> So as we can see, these edge cases are wayyy to complicated to explain exactly
    ///         -> And users (as far as I understand) usually just want to know: "How do I make the middle button work normally", or "How do I use this alongside MOS, or another mouse app", and for those cases, understanding all the details really doesn't matter.
    ///
    ///         -> So for the captureToasts, we should just align with the simple explanation, and we should not try to align with the exact reality of when things are captured or uncaptured. (Which we could do by tapping into the SwitchMaster)
    ///             - Especially in the buttons case I think the simple explanation is ok, because worst case, we tell the user to do 'more' than is necessary to uncapture a button, which won't lead to any problems for the user (You could say it's just a little trick that they don't know)
    ///             - In the scrollwheel case, it's different, since in the worst case, we don't tell the user everything that is necessary to uncapture the scrollwheel in all scenarios, which could lead to problems.
    ///                 - Based on this, I think it does make sense to maybe extend the simple explanation from what was discussed above: Just include "remove the modifiers at the bottom of the scroll tab" in our simple explanation. Because those modifiers might lead to interference when using MOS or another mouse app.
    ///                 - However, I think it's okay if, in the simple explanation, we don't include telling the user to remove "Click and Scroll" gestures. from the ActionTable. I think for those users who run into that as a problem, the solution would likely be pretty obvious.
    ///                 -> Why do I think removing the button mods would be more obvious than removing the keyboard mods? Wellll, I think
    ///                     1. We're already explaining that rows on the ActionTable can be removed and how. And users can use this to remove the button mods for scrolling. On the other hand, we don't explain how to remove keyboard mods for scrolling (although it might be really obvious?)
    ///                     2. Click and Scroll gestures are (at the moment) unique to MMF, so it would be more obvious that MMF is causing the scroll-behavior change while holding down a mouse button. Which would then hopefully cause users to go to MMF and discover how to remove the Click and Scroll gesture.
    ///                     3. Click and Scroll Gestures tend to cause more obvious scroll-behavior changes, like opening Launchpad or zooming in Safari (which is the default behaviour under MMF 3.0.2). It's not like shift-horizontal scrolling, where you might not be sure if MMF or sth else is causing that. (and which is also part of the default behavior under MMF 3.0.2) -> I think, what's the default behavior matters here, because more people would probably be using the default behaviour, and those people who have changed the default behavor are probably more savvy (?) and at least they already know how to change the default behaviour (?) (This is very abstract, I should probably think of an example to see if this really holds up)
    
    /// Get the remap table data model
    NSArray *dataModel = MainAppState.shared.remapTableController.dataModel;
    
    /// Declare result
    NSMutableSet<NSNumber *> *capturedButtons = [NSMutableSet set];
    
    /// Go through all buttons
    for (int b = 1; b <= kMFMaxButtonNumber; b++) {

        /// Go through all preconds and corresponding modifications and check if button occurs anywhere
        for (NSDictionary *rowDict in dataModel) {
            
            /// Unpack the rowDict
            NSDictionary *modificationPrecondition = rowDict[kMFRemapsKeyModificationPrecondition];
            NSDictionary *trigger = rowDict[kMFRemapsKeyTrigger];
            
            /// The row captures the button, if
            ///     The button is a modifier in this row
            BOOL buttonIsModifier = [SharedUtility button:@(b) isPartOfModificationPrecondition:modificationPrecondition];
            if (buttonIsModifier) {
                goto addButton;
            }
            
            /// This row doesn't capture the button, if 
            ///     - The button is not a modifier in this row AND
            ///     - The row has any modifiers (other than the button)                                          (we only apply this rule, if excludeButtonsThatAreCapturedByModifier is true)
            BOOL triggerIsModified = ![modificationPrecondition isEqualToDictionary:@{}];
            if (triggerIsModified && excludeButtonsThatAreOnlyCapturedByModifier) {
                continue;
            }
            
            /// This row doesn't capture the button, if
            ///     - The button is not a modifier in this row AND
            ///     - The row does not have any modifiers (other than the button) AND                   (we only apply this rule, if excludeButtonsThatAreCapturedByModifier is true)
            ///     - The button is not a trigger in this row
            BOOL buttonIsTrigger = NO;
            if ([trigger isKindOfClass:NSDictionary.class]) { /// Trigger is type button
                buttonIsTrigger = [trigger[kMFButtonTriggerKeyButtonNumber] isEqual:@(b)];
            }
            if (!buttonIsTrigger) {
                continue;
            }
            
            /// The row does capture the button if
            ///     - The button is not a modifier in this row AND
            ///     - The row does not have any modifiers (other than the button) AND                   (we only apply this rule, if excludeButtonsThatAreCapturedByModifier is true)
            ///     - The button **is** a trigger in this row
            goto addButton;
        }
        
        /// If the for-loop runs through completely, then none of the rows captured the button
        goto dontAddButton;
        
        /// Either add the button or don't. Then move on to the next button
    addButton:
        [capturedButtons addObject:@(b)];
    dontAddButton:;
    }
    
    /// Return
    return capturedButtons;
}

@end
