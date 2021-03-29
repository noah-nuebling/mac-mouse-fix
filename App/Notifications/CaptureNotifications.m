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

// TODO: Rename to `CaptureNotificationCreator` or `NotificationCreator` or something 
@implementation CaptureNotifications

/// Called by [RemapTableController - addRowWithHelperPayload:]
/// Creates notifications to inform the user about newly caputred / uncaptured buttons after the user added a new row to the remapsTable
+ (void)showButtonCaptureNotificationWithBeforeSet:(NSSet<NSNumber *> *)beforeSet afterSet:(NSSet<NSNumber *> *)afterSet {
    
    // ^ We don't like capture notifications after all. Also they didn't work in app welcome flow (after granting accessibility access)
    
    NSMutableSet *newlyUncapturedButtons = beforeSet.mutableCopy;
    [newlyUncapturedButtons minusSet:afterSet];
    NSMutableSet *newlyCapturedButtons = afterSet.mutableCopy;
    [newlyCapturedButtons minusSet:beforeSet];
    
    NSArray *uncapturedArray = [newlyUncapturedButtons sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"" ascending:YES]]];
    NSArray *capturedArray = [newlyCapturedButtons sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"" ascending:YES]]];
    
    NSString *uncapturedButtonString = buttonStringFromButtonArray(uncapturedArray);
    NSString *capturedButtonString = buttonStringFromButtonArray(capturedArray);
    
    NSString *uncapPluralString = @"";
    if (uncapturedArray.count > 0) {
        uncapPluralString = uncapturedArray.count == 1 ? @"is" : @"are";
    }
    NSString *capPluralString  = @"";
    if (capturedArray.count > 0) {
        capPluralString = capturedArray.count == 1 ? @"has" : @"have";
    }
    
    
    NSString *uncapString = @"";
    if (newlyUncapturedButtons.count > 0) {
        uncapString = [uncapturedButtonString stringByAppendingFormat:@" %@ no longer captured by Mac Mouse Fix. ", uncapPluralString];
    }
    NSString *capString = @"";
    if (newlyCapturedButtons.count > 0) {
        capString = [capturedButtonString stringByAppendingFormat:@" %@ been captured by Mac Mouse Fix. ", capPluralString];
    }
    
    if (newlyUncapturedButtons.count > 0 || newlyCapturedButtons.count > 0) {
        NSString *notifString = [NSString stringWithFormat:@"%@%@\nLearn More", capString, uncapString];
//        NSString *notifString = [NSString stringWithFormat:@"%@%@", capString, uncapString];
        NSAttributedString *attrNotifString = [[NSAttributedString alloc] initWithString:notifString];
        attrNotifString = [attrNotifString attributedStringByAddingLinkWithURL:[NSURL URLWithString:@"https://placeholder.com/"] forSubstring:@"Learn More"];
        
        [MFNotificationController attachNotificationWithMessage:attrNotifString toWindow:AppDelegate.mainWindow forDuration:5.0];
    }
}

static NSString *buttonStringFromButtonArray(NSArray<NSNumber *> *buttons) {

    NSArray *buttonStrings = [buttons map:^id _Nonnull(NSNumber * _Nonnull button) {
        return [UIStrings getButtonString:button.intValue];
    }];
    return [UIStrings naturalLanguageListFromStringArray:buttonStrings];
}

@end
