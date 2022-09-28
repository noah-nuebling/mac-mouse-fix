//
// --------------------------------------------------------------------------
// CaptureNotifications.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
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
    
    NSMutableSet *uncapturedSet = beforeSet.mutableCopy;
    [uncapturedSet minusSet:afterSet];
    NSMutableSet *capturedSet = afterSet.mutableCopy;
    [capturedSet minusSet:beforeSet];
    
    /// Get count
    
    NSInteger uncapturedCount = uncapturedSet.count;
    NSInteger capturedCount = capturedSet.count;
    
    if (uncapturedCount > 0 || capturedCount > 0) {
        
        /// Sort buttons
        
        NSArray *uncapturedArray = [uncapturedSet sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"" ascending:YES]]];
        NSArray *capturedArray = [capturedSet sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"" ascending:YES]]];
        
        /// Create natural language string from button list
        
        NSString *uncapturedButtonString = buttonStringFromButtonNumberArray(uncapturedArray);
        NSString *capturedButtonString = buttonStringFromButtonNumberArray(capturedArray);
        
        /// Get array of strings
        ///     Only need these for adding bold to the button strings
        
        NSArray<NSString *> *uncapturedButtonStringArray = buttonStringArrayFromButtonNumberArray(uncapturedArray);
        NSArray<NSString *> *capturedButtonStringArray = buttonStringArrayFromButtonNumberArray(capturedArray);
        
        /// Define learn more string
        
        NSString *linkStringRaw = NSLocalizedString(@"capture-toast.link", @"First draft: Learn More");
        NSAttributedString *linkString = [linkStringRaw.attributed attributedStringByAddingLinkWithURL:[NSURL URLWithString:@"https://github.com/noah-nuebling/mac-mouse-fix/discussions/112"] forSubstring:linkStringRaw];
        
        /// Create string describing uncaptured and captured
        
        NSString *buttonStringCaptureRaw = stringf(NSLocalizedString(@"capture-toast.body.captured", @"Note: Value for this key is defined in Localizable.stringsdict, not Localizable.strings. || Note: The UI strings in .stringsdict have two lines. Only the first line is visible unless you start editing and then use the arrow keys to go to the second line. This is necessary to have linebreaks in .stringsdict since \n doesn't work. Use Option-Enter to insert these linebreaks."), capturedButtonString, capturedCount);
        
        NSString *buttonStringUncaptureRaw = stringf(NSLocalizedString(@"capture-toast.body.uncaptured", @"Note: Value for this key is defined in Localizable.stringsdict, not Localizable.strings"), uncapturedButtonString, uncapturedCount);
        
        NSAttributedString *buttonStringUncapture = buttonStringUncaptureRaw.attributed;
        NSAttributedString *buttonStringCapture = buttonStringCaptureRaw.attributed;
        
        /// Add bold
        for (NSString *buttonString in uncapturedButtonStringArray) {
            buttonStringUncapture = [buttonStringUncapture attributedStringByAddingBoldForSubstring:buttonString];
        }
        for (NSString *buttonString in capturedButtonStringArray) {
            buttonStringCapture = [buttonStringCapture attributedStringByAddingBoldForSubstring:buttonString];
        }
        
        /// Capitalize buttonStrings
        buttonStringUncapture = [buttonStringUncapture attributedStringByCapitalizingFirst];
        buttonStringCapture = [buttonStringCapture attributedStringByCapitalizingFirst];
        
        /// Build complete notification String
        NSAttributedString *notifString = @"".attributed;
        if (uncapturedCount > 0) {
            notifString = [buttonStringUncapture attributedStringByAppending:@"\n\n".attributed];
        }
        if (capturedCount > 0) {
            notifString = [[notifString attributedStringByAppending:buttonStringCapture] attributedStringByAppending:@"\n\n".attributed];
        }
        notifString = [notifString attributedStringByAppending:linkString];
        
        /// Trim
        notifString = [notifString attributedStringByTrimmingWhitespace];
        notifString = [notifString attributedStringByCapitalizingFirst];
        
        [ToastNotificationController attachNotificationWithMessage:notifString toWindow:MainAppState.shared.window forDuration:-1];
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
