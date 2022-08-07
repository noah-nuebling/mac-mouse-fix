//
// --------------------------------------------------------------------------
// CaptureNotifications.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "CaptureNotificationCreator.h"
#import "UIStrings.h"
#import "NSArray+Additions.h"
#import "NSAttributedString+Additions.h"
#import "ToastNotificationController.h"
#import "AppDelegate.h"
#import "SharedUtility.h"

@implementation CaptureNotificationCreator

/// Called by [RemapTableController - addRowWithHelperPayload:]
/// Creates notifications to inform the user about newly caputred / uncaptured buttons after the user added a new row to the remapsTable
+ (void)showButtonCaptureNotificationWithBeforeSet:(NSSet<NSNumber *> *)beforeSet afterSet:(NSSet<NSNumber *> *)afterSet {
    
    
    NSMutableSet *newlyUncapturedButtons = beforeSet.mutableCopy;
    [newlyUncapturedButtons minusSet:afterSet];
    NSMutableSet *newlyCapturedButtons = afterSet.mutableCopy;
    [newlyCapturedButtons minusSet:beforeSet];
    
    NSArray *uncapturedArray = [newlyUncapturedButtons sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"" ascending:YES]]];
    NSArray *capturedArray = [newlyCapturedButtons sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"" ascending:YES]]];
    
    NSString *uncapturedButtonString = buttonStringFromButtonNumberArray(uncapturedArray);
    NSString *capturedButtonString = buttonStringFromButtonNumberArray(capturedArray);
    
    NSArray<NSString *> *uncapturedButtonStringArray = buttonStringArrayFromButtonNumberArray(uncapturedArray); // Only need these for adding bold to the button strings
    NSArray<NSString *> *capturedButtonStringArray = buttonStringArrayFromButtonNumberArray(capturedArray);
    
    NSString *linkString = @"Learn More";
    
    NSString *uncapString = @"";
    if (newlyUncapturedButtons.count > 0) {
        NSString *uncapPluralString = uncapturedArray.count == 1 ? @"is" : @"are";
//        NSString *buttonPluralString = uncapturedArray.count == 1 ? @"it" : @"them";
        
        uncapString = [uncapturedButtonString stringByAppendingFormat:@" %@ no longer captured by Mac Mouse Fix.", uncapPluralString];
    }
    NSString *capString = @"";
    if (newlyCapturedButtons.count > 0) {
        NSString *pluralString = capturedArray.count == 1 ? @"has" : @"have";
        NSString *buttonPluralString = capturedArray.count == 1 ? @"it" : @"them";
//        NSString *buttonPluralString2 = capturedArray.count == 1 ? @"this button" : @"these buttons";
//        linkString = stringf(@"I want to use %@ with other apps", buttonPluralString2);
        
        capString = [capturedButtonString stringByAppendingFormat:@" %@ been captured by Mac Mouse Fix.\nOther apps can't see %@ anymore. ", pluralString, buttonPluralString];
    }
    
    if (newlyUncapturedButtons.count > 0 || newlyCapturedButtons.count > 0) {
        
        NSString *notifString = [NSString stringWithFormat:@"%@%@\n\n%@", capString, uncapString, linkString];
//        NSString *notifString = [NSString stringWithFormat:@"%@%@", capString, uncapString];
        NSAttributedString *attrNotifString = [[NSAttributedString alloc] initWithString:notifString];
        /// Add link to linkString
        attrNotifString = [attrNotifString attributedStringByAddingLinkWithURL:[NSURL URLWithString:@"https://github.com/noah-nuebling/mac-mouse-fix/discussions/112"] forSubstring:linkString];
        
        /// Add bold for button strings
        for (NSString *buttonString in [uncapturedButtonStringArray arrayByAddingObjectsFromArray:capturedButtonStringArray]) {
            attrNotifString = [attrNotifString attributedStringByAddingBoldForSubstring:buttonString];
        }
        
        [ToastNotificationController attachNotificationWithMessage:attrNotifString toWindow:AppDelegate.mainWindow forDuration:-1];
    }
}

static NSArray *buttonStringArrayFromButtonNumberArray(NSArray<NSNumber *> *buttons) {
    return [buttons map:^id _Nonnull(NSNumber * _Nonnull button) {
        return [UIStrings getButtonString:button.intValue];
    }];
}
static NSString *buttonStringFromButtonNumberArray(NSArray<NSNumber *> *buttons) {
    
    NSArray *buttonStrings = buttonStringArrayFromButtonNumberArray(buttons);
    return [UIStrings naturalLanguageListFromStringArray:buttonStrings];
}

@end
