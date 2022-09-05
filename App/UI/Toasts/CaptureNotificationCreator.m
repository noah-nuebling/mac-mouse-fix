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
#import "Mac_Mouse_Fix-Swift.h"

@implementation CaptureNotificationCreator

/// Called by [RemapTableController - addRowWithHelperPayload:]
/// Creates notifications to inform the user about newly caputred / uncaptured buttons after the user added a new row to the remapsTable
+ (void)showButtonCaptureNotificationWithBeforeSet:(NSSet<NSNumber *> *)beforeSet afterSet:(NSSet<NSNumber *> *)afterSet {
    
    
    /// Get captured and uncaptured buttons
    
    NSMutableSet *newlyUncapturedButtons = beforeSet.mutableCopy;
    [newlyUncapturedButtons minusSet:afterSet];
    NSMutableSet *newlyCapturedButtons = afterSet.mutableCopy;
    [newlyCapturedButtons minusSet:beforeSet];
    
    /// Sort buttons
    
    NSArray *uncapturedArray = [newlyUncapturedButtons sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"" ascending:YES]]];
    NSArray *capturedArray = [newlyCapturedButtons sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"" ascending:YES]]];
    
    /// Get count
    
    NSInteger uncapturedCount = uncapturedArray.count;
    NSInteger capturedCount = capturedArray.count;
    
    /// Create natural language string from button list
    
    NSString *uncapturedButtonString = buttonStringFromButtonNumberArray(uncapturedArray);
    NSString *capturedButtonString = buttonStringFromButtonNumberArray(capturedArray);
    
    /// Get array of strings
    ///     Only need these for adding bold to the button strings
    
    NSArray<NSString *> *uncapturedButtonStringArray = buttonStringArrayFromButtonNumberArray(uncapturedArray);
    NSArray<NSString *> *capturedButtonStringArray = buttonStringArrayFromButtonNumberArray(capturedArray);
    
    /// Define learn more string
    
    NSString *linkString = NSLocalizedString(@"capture-toast.link", @"First draft: Learn More");
    
    /// Create string describing uncaptured and captured
    
    NSString *buttonString = stringf(NSLocalizedString(@"capture-toast.body", @"Note: Value for this key is defined in Localizable.stringsdict, not Localizable.strings"), capturedButtonString, capturedCount, uncapturedButtonString, uncapturedCount);
    
    if (uncapturedCount > 0 || capturedCount > 0) {
        
        /// Build complete notification String
        NSString *notifString = stringf(@"%@\n\n%@", buttonString, linkString);
        NSAttributedString *attrNotifString = [[NSAttributedString alloc] initWithString:notifString];
        
        /// Add link
        attrNotifString = [attrNotifString attributedStringByAddingLinkWithURL:[NSURL URLWithString:@"https://github.com/noah-nuebling/mac-mouse-fix/discussions/112"] forSubstring:linkString];
        
        /// Add bold
        for (NSString *buttonString in [uncapturedButtonStringArray arrayByAddingObjectsFromArray:capturedButtonStringArray]) {
            attrNotifString = [attrNotifString attributedStringByAddingBoldForSubstring:buttonString];
        }
        
        /// Trim & Capitalize
        attrNotifString = [attrNotifString attributedStringByTrimmingWhitespace];
        attrNotifString = [attrNotifString attributedStringByCapitalizingFirst];
        
        [ToastNotificationController attachNotificationWithMessage:attrNotifString toWindow:MainAppState.shared.window forDuration:-1];
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
