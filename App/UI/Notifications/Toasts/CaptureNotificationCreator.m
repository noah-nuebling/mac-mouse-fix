//
// --------------------------------------------------------------------------
// CaptureNotifications.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
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
    
    if (capturedCount + uncapturedCount >= 1) {
        
        /// NOTES: On why we only display the notification when the count == 1:
        ///   - At the time of writing, the `> 1` case only happens on first app startup and when restoring defaults. In those cases the information in the capture notification is imo overwhelming and not really relevant.
        ///   - I think the whole reason for the capture notifications is so people understand that you can't just delete the "Click" action to make clicking the button work as normal, you have to delete "all" the bindings instead. I feel like with the new easier deletion and addition of actions to the actionsTable and with the default settings  not even using the middle button this is not that important to teach the user anymore. But I feel like especially in those cases where several buttons are captured / uncaptured at the same time the mindset of the user is not such that they have a good chance of learning this concept in those situations.
        ///   - Alternatively we could also:
        ///     - Turn off the capture notifications entirely
        ///     - Make the `> 1` case display "Some buttons on your mouse have been captured" instead of listing all the buttons that have been captured / uncaptured individually.
        ///
        /// Edit: Undid this now because this means that after restoring defaults, if the restore happens to only add one captured button an alert is displayed, but if it captures more, then no alert is displayed. This is weird and inconsistent. I also tried simplifying the notifications by just saying "Some Buttons have been captured" instead of listing all the captured and uncaptured ones separately, but being more vague about what exactly happens makes things more confusing and bad I think, even if it's shorter. See the reverted commit d6f386ad6bbad29188a9bc3782dbb1c836c1bd48 for that code.
        /// New solution idea: Disable capture notifications specifically on app startup and when restoring defaults, instead of trying to disable them here. -> DONE
        
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
        NSAttributedString *linkString = [linkStringRaw.attributed attributedStringByAddingHyperlink:[NSURL URLWithString:@"https://github.com/noah-nuebling/mac-mouse-fix/discussions/112"] forSubstring:linkStringRaw];
        
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
        
        /// Build notification body string
        ///
        NSAttributedString *body = @"".attributed;
        
        if (capturedCount > 0) { /// Need to check for 0 despite trimming whitespace because it doesn't trim linebreaks (See `\n\n`). Maybe we should make it trim linebreaks instead?
            body = [[body attributedStringByAppending:buttonStringCapture] attributedStringByAppending:@"\n\n".attributed];
        }
        if (uncapturedCount > 0) {
            body = [[body attributedStringByAppending:buttonStringUncapture] attributedStringByAppending:@"\n\n".attributed];
        }
        body = [body attributedStringByAppending:linkString];
        
        /// Trim
        body = [body attributedStringByTrimmingWhitespace];
        
        /// Show notification
        [ToastNotificationController attachNotificationWithMessage:body toWindow:MainAppState.shared.window forDuration:kMFToastDurationAutomatic];
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
