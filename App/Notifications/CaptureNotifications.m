//
// --------------------------------------------------------------------------
// CaptureNotifications.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "CaptureNotifications.h"
#import "UIStrings.h"
#import "NSArray+Additions.h"
#import "NSAttributedString+Additions.h"
#import "MFNotificationController.h"
#import "AppDelegate.h"
#import "SharedUtility.h"

// TODO: Rename to `CaptureNotificationCreator` or `NotificationCreator` or something 
@implementation CaptureNotifications

/// Called by [RemapTableController - addRowWithHelperPayload:]
/// Creates notifications to inform the user about newly caputred / uncaptured buttons after the user added a new row to the remapsTable
+ (void)showButtonCaptureNotificationWithBeforeSet:(NSSet<NSNumber *> *)beforeSet afterSet:(NSSet<NSNumber *> *)afterSet {
    
    
    NSMutableSet *newlyUncapturedButtons = beforeSet.mutableCopy;
    [newlyUncapturedButtons minusSet:afterSet];
    NSMutableSet *newlyCapturedButtons = afterSet.mutableCopy;
    [newlyCapturedButtons minusSet:beforeSet];
    
    NSArray *uncapturedArray = [newlyUncapturedButtons sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"" ascending:YES]]];
    NSArray *capturedArray = [newlyCapturedButtons sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"" ascending:YES]]];
    
    NSString *uncapturedButtonString = buttonStringFromButtonArray(uncapturedArray);
    NSString *capturedButtonString = buttonStringFromButtonArray(capturedArray);
    
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
        NSString *buttonPluralString2 = capturedArray.count == 1 ? @"this button" : @"these buttons";
        
        linkString = stringf(@"I want to use %@ with other apps", buttonPluralString2);
        
        capString = [capturedButtonString stringByAppendingFormat:@" %@ been captured by Mac Mouse Fix.\nOther apps can't see %@ anymore. ", pluralString, buttonPluralString];
    }
    
    if (newlyUncapturedButtons.count > 0 || newlyCapturedButtons.count > 0) {
        
        NSString *notifString = [NSString stringWithFormat:@"%@%@\n\n%@", capString, uncapString, linkString];
//        NSString *notifString = [NSString stringWithFormat:@"%@%@", capString, uncapString];
        NSAttributedString *attrNotifString = [[NSAttributedString alloc] initWithString:notifString];
        // Add link to linkString
        attrNotifString = [attrNotifString attributedStringByAddingLinkWithURL:[NSURL URLWithString:@"https://placeholder.com/"] forSubstring:linkString];
        // Add bold for button string
        if ([attrNotifString.string rangeOfString:uncapturedButtonString].location != NSNotFound) {
            attrNotifString = [attrNotifString attributedStringByAddingBoldForSubstring:uncapturedButtonString];
        }
        if ([attrNotifString.string rangeOfString:capturedButtonString].location != NSNotFound) {
            attrNotifString = [attrNotifString attributedStringByAddingBoldForSubstring:capturedButtonString];
        }
        
        [MFNotificationController attachNotificationWithMessage:attrNotifString toWindow:AppDelegate.mainWindow forDuration:-1];
    }
}

static NSString *buttonStringFromButtonArray(NSArray<NSNumber *> *buttons) {

    NSArray *buttonStrings = [buttons map:^id _Nonnull(NSNumber * _Nonnull button) {
        return [UIStrings getButtonString:button.intValue];
    }];
    return [UIStrings naturalLanguageListFromStringArray:buttonStrings];
}

@end
