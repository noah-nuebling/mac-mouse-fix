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

typedef enum {
    
    /// Simple input types
    kMFCapturedInputTypeButtons,
    kMFCapturedInputTypeScroll,
    
    /// Input types for when the user has a horizontal scroll input on their mouse, and so therefore we want to treat horizontal and vertical scroll separately in the UI.
    ///     This is currently unused
    kMFCapturedInputTypeHorizontalScroll,
    kMFCapturedInputTypeVerticalScroll,
    kMFCapturedInputTypeHorizontalAndVerticalScroll,
} MFCapturedInputType;

#define hintSeparatorSize 4.0

+ (void)showScrollWheelCaptureNotification:(BOOL)hasBeenCaptured {
    
    /// Create toast body
    NSAttributedString *body = createSimpleNotificationBody(hasBeenCaptured, kMFCapturedInputTypeScroll);
    
    /// Show notification
    [ToastNotificationController attachNotificationWithMessage:body toWindow:MainAppState.shared.window forDuration:kMFToastDurationAutomatic];
}

+ (void)showButtonCaptureNotificationWithBeforeSet:(NSSet<NSNumber *> *)beforeSet afterSet:(NSSet<NSNumber *> *)afterSet {
    
    /// Called by [RemapTableController - addRowWithHelperPayload:]
    /// Creates notifications to inform the user about newly caputred / uncaptured buttons after the user added a new row to the remapsTable
    
    /// Get captured and uncaptured buttons
    
    NSMutableSet *uncapturedSet = beforeSet.mutableCopy;
    [uncapturedSet minusSet:afterSet];
    NSMutableSet *capturedSet = afterSet.mutableCopy;
    [capturedSet minusSet:beforeSet];
    
    if (capturedSet.count + uncapturedSet.count >= 1) {
        
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
        
        /// Convert button numbers to strings
        NSArray<NSString *> *uncapturedButtonStringArray = buttonStringArrayFromButtonNumberArray(uncapturedArray);
        NSArray<NSString *> *capturedButtonStringArray = buttonStringArrayFromButtonNumberArray(capturedArray);
        
        /// Create toast body
        NSAttributedString * body = createButtonsNotificationBody(capturedButtonStringArray, uncapturedButtonStringArray);
        
        /// Show notification
        [ToastNotificationController attachNotificationWithMessage:body toWindow:MainAppState.shared.window forDuration:kMFToastDurationAutomatic];
    }
}

static NSAttributedString *createSimpleNotificationBody(BOOL didGetCaptured, MFCapturedInputType inputType) {
    
    /// Validate
    assert(inputType != kMFCapturedInputTypeButtons); /// For this case, use the dedicated function
    
    /// Get raw strings
    NSString *rawBody;
    NSString *rawHint;
    if (didGetCaptured) {
        rawBody = getLocalizedString(inputType, @"captured.body");
        rawHint = getLocalizedString(inputType, @"captured.hint");
    } else {
        rawBody = getLocalizedString(inputType, @"uncaptured.body");
        rawHint = getLocalizedString(inputType, @"uncaptured.hint");
    }
    
    /// Validate
    assert(rawBody.length > 0);
    
    /// Get learn more string
    NSAttributedString *learnMoreString = [NSAttributedString attributedStringWithCoolMarkdown:getLocalizedString(inputType, @"link")];
    
    /// Apply markdown to rawBody
    NSAttributedString *body = [NSAttributedString attributedStringWithCoolMarkdown:rawBody];
    
    if (rawHint.length > 0) {
        
        /// Style hint
        NSAttributedString *hint = [NSAttributedString attributedStringWithCoolMarkdown:rawHint];
        hint = [hint attributedStringByAddingHintStyle];
        
        /// Attach hint
        NSAttributedString *separator = [@"\n\n".attributed attributedStringBySettingFontSize:hintSeparatorSize];
        body = [[body attributedStringByAppending:separator] attributedStringByAppending:hint];
    }
    
    /// Attach learnMore string
    NSAttributedString *separator = @"\n\n".attributed;
    body = [[body attributedStringByAppending:separator] attributedStringByAppending:learnMoreString];
    
    /// Return
    return body;
}

static NSAttributedString *createButtonsNotificationBody(NSArray<NSString *> *capturedItemArray, NSArray<NSString *> *uncapturedItemArray) {
    
    /// Create body
    NSAttributedString *body = @"".attributed;
    
    /// Extract captured/uncaptured count
    NSInteger capturedCount = capturedItemArray.count;
    NSInteger uncapturedCount = uncapturedItemArray.count;
    
    /// Add markdown emphasis to items
    NSString *(^addMDEmphasis)(NSString *) = ^NSString *(NSString *item) {
        return [[@"**" stringByAppendingString:item] stringByAppendingString:@"**"];
    };
    capturedItemArray = [capturedItemArray map:addMDEmphasis];
    uncapturedItemArray = [uncapturedItemArray map:addMDEmphasis];
    
    /// Create natural language list of items
    NSString *capturedItemEnumeration = [UIStrings naturalLanguageListFromStringArray:capturedItemArray];
    NSString *uncapturedItemEnumeration = [UIStrings naturalLanguageListFromStringArray:uncapturedItemArray];
    
    /// Get raw strings
    NSString *capturedBodyRaw = stringf(getLocalizedString(kMFCapturedInputTypeButtons, @"captured.body"), capturedItemEnumeration, capturedCount);
    NSString *uncapturedBodyRaw = stringf(getLocalizedString(kMFCapturedInputTypeButtons, @"uncaptured.body"), uncapturedItemEnumeration, uncapturedCount);
    NSString *capturedHintRaw = stringf(getLocalizedString(kMFCapturedInputTypeButtons, @"captured.hint"), capturedCount);
    NSString *uncapturedHintRaw = stringf(getLocalizedString(kMFCapturedInputTypeButtons, @"uncaptured.hint"), uncapturedCount);
    
    /// Validate
    assert(capturedBodyRaw.length > 0 && uncapturedBodyRaw.length > 0);
    
    /// Handle hint being @"(null)"
    ///     Explanation: If we try to format an NSLocalizedString with an integer that is not defined in the .stringsdict, then the result is @"(null)". We sometimes want to do this for testing purposes.
    if ([capturedHintRaw isEqual:@"(null)"]) {
        capturedHintRaw = @"";
    }
    if ([uncapturedHintRaw isEqual:@"(null)"]) {
        uncapturedHintRaw = @"";
    }
    
    /// Apply Markdown
    NSAttributedString *capturedBody = [NSAttributedString attributedStringWithCoolMarkdown:capturedBodyRaw];
    NSAttributedString *uncapturedBody = [NSAttributedString attributedStringWithCoolMarkdown:uncapturedBodyRaw];
    NSAttributedString *capturedHint = [NSAttributedString attributedStringWithCoolMarkdown:capturedHintRaw];
    NSAttributedString *uncapturedHint = [NSAttributedString attributedStringWithCoolMarkdown:uncapturedHintRaw];
    
    /// Style the hints
    capturedHint = [capturedHint attributedStringByAddingHintStyle];
    uncapturedHint = [uncapturedHint attributedStringByAddingHintStyle];
    
    /// Capitalize the two bodys
    ///     Note: That's because the start of the body might be the natural language list, which is not capitalized.
    capturedBody = [capturedBody attributedStringByCapitalizingFirst];
    uncapturedBody = [uncapturedBody attributedStringByCapitalizingFirst];
    
    /// Attach bodys to combined body
    /// Note:
    /// - We also add a double linebreak ('\n\n') after each of the two description strings.
    /// - But first we check for `capturedCount > 0` before attaching to body. We wouldn't have to do this if the trimming we do afterwards trimmed linebreaks. But it doesn't. Maybe we should make it trim linebreaks?
    
    if (capturedCount > 0) {
        body = [body attributedStringByAppending:capturedBody];
        if (capturedHint.length > 0) {
            NSAttributedString *hintSeparator = [@"\n\n".attributed attributedStringBySettingFontSize:hintSeparatorSize];
            body = [[body attributedStringByAppending:hintSeparator] attributedStringByAppending:capturedHint];
        }
        NSAttributedString *mainSeparator = @"\n\n".attributed;
        body = [body attributedStringByAppending:mainSeparator];
    }
    if (uncapturedCount > 0) {
        body = [body attributedStringByAppending:uncapturedBody];
        if (uncapturedHint.length > 0) {
            NSAttributedString *hintSeparator = [@"\n\n".attributed attributedStringBySettingFontSize:hintSeparatorSize];
            body = [[body attributedStringByAppending:hintSeparator] attributedStringByAppending:uncapturedHint];
        }
        NSAttributedString *mainSeparator = @"\n\n".attributed;
        body = [body attributedStringByAppending:mainSeparator];
    }
        
    /// Get learn more string
    NSAttributedString *learnMoreString = [NSAttributedString attributedStringWithCoolMarkdown:getLocalizedString(kMFCapturedInputTypeButtons, @"link")];
    
    /// Attach learnMore string to body
    body = [body attributedStringByAppending:learnMoreString];
    
    /// Trim
    body = [body attributedStringByTrimmingWhitespace];
    
    /// Return
    return body;
}

static NSString *getLocalizedString(MFCapturedInputType inputType, NSString *simpleKey) {
    
    /// Discussion:
    ///
    /// - The return type of this might be an object of the private "NSLocalizedString" class, which holds different plural versions of the same string. In that case, you first need to apply `stringf()` to it to get a normal NSString.
    ///
    /// - We put a lot of consideration into the original phrasing of "Button 4 is now captured by Mac Mouse Fix\nOther apps can't see it anymore.":
    ///     - See this ChatGPT conversation: https://chatgpt.com/share/4922a5e2-0669-412d-82c6-9d1397058409
    ///     - we choose "is now" over "has been" to make clear it's an ongoing state, where any input from Button 4 is intercepted by MMF.
    ///     - We choose "captured" or "intercepted". The core idea we want to convey is 'interception', but "intercept" sounds really aggressive and sci-fi to me, and 'capture' was the best alternative I could find. We could also use 'manage', but I feel like that's more abstract. 'controlled' also more abstract and also aggressive-sounding.
    ///     - With "Other apps can't see it anymore", we want to convey that the normal functions that a button might perform, (like opening links in a new tab) will not work anymore, but also that other mouse drivers won't be able to affect the functionality of the button anymore. We chose the phrase of "seeing" the button since it seems non-technical and relatively clear, and can be expressed in a very short phrase.
    ///     - We chose "it" instead of "the button" to make things as short as possible.
    ///     -> It was originally a priority to make the second line "Other apps can't see it anymore." very short, otherwise the first line seemed like it's not emphasized enough, and it felt hard to parse the notification at a glance. However, since we now made the font of the second line smaller and greyed out, I think we can now affort to make the second line phrase a bit longer and more descriptive.
    ///
    /// - Hint string brainstorming:
    ///     - Original: Other apps can't see it anymore.
    ///     - Alternatives:
    ///         - Other apps can't see this button anymore.
    ///         - Other apps can now handle scrolling input.
    ///         - Other apps can't manage scrolling input anymore.
    ///         - The button now works as if Mac Mouse Fix was disabled.
    ///         - Scrolling now works as if Mac Mouse Fix was disabled.
    ///         German:
    ///         - Andere Apps können jetzt die Scroll-Eingabe handhaben.
    ///         - Scrollen funktioniert jetzt, als wäre Mac Mouse Fix ausgeschaltet.
    
    /// Define simple key -> localizedString map
    NSDictionary *map;
    if (inputType == kMFCapturedInputTypeButtons) {
        map = @{
            
            @"captured.body": NSLocalizedString(@"capture-toast.buttons.captured.body", @"Note: Value for this key is defined in Localizable.stringsdict, not Localizable.strings. || Note: The core idea that we want to convey here is that, from now on, the button is being 'intercepted' by Mac Mouse Fix. We used the word 'capture' instead of 'intercept' since it sounds friendlier in English. In your language, you might want to use something closer to 'intercept'."),
            @"captured.hint": NSLocalizedString(@"capture-toast.buttons.captured.hint", @"Note: Value for this key is defined in Localizable.stringsdict, not Localizable.strings"),
            
            @"uncaptured.body": NSLocalizedString(@"capture-toast.buttons.uncaptured.body", @"Note: Value for this key is defined in Localizable.stringsdict, not Localizable.strings"),
            @"uncaptured.hint": NSLocalizedString(@"capture-toast.buttons.uncaptured.hint", @"Note: Value for this key is defined in Localizable.stringsdict, not Localizable.strings"),
            
            @"link": NSLocalizedString(@"capture-toast.buttons.link", @"First draft: [Learn More](https://github.com/noah-nuebling/mac-mouse-fix/discussions/112)"),
        };
    } else if (inputType == kMFCapturedInputTypeScroll) {
        map = @{
            
            @"captured.body": NSLocalizedString(@"capture-toast.scroll.captured.body", @"First draft: **Scrolling** is now captured by Mac Mouse Fix."),
            @"captured.hint": NSLocalizedString(@"capture-toast.scroll.captured.hint", @"First draft: "),
            
            @"uncaptured.body": NSLocalizedString(@"capture-toast.scroll.uncaptured.body", @"First draft: **Scrolling** is no longer captured by Mac Mouse Fix."),
            @"uncaptured.hint": NSLocalizedString(@"capture-toast.scroll.uncaptured.hint", @"First draft: Scrolling now works as if Mac Mouse Fix was disabled."),
            
            @"link": NSLocalizedString(@"capture-toast.scroll.link", @"First draft: [Learn More](https://github.com/noah-nuebling/mac-mouse-fix/discussions/112)"),
        };
    } else {
        assert(false); /// We haven't implemented the other inputTypes, yet.
        return @"";
    }
    
    /// Get value from the map
    NSString *result = map[simpleKey];
    
    /// Validate
    assert(result != nil);
    
    /// Return
    return result;
    
}

static NSArray *buttonStringArrayFromButtonNumberArray(NSArray<NSNumber *> *buttons) {
    return [buttons map:^id _Nonnull(NSNumber * _Nonnull button) {
        return [UIStrings getButtonString:button.intValue];
    }];
}
//static NSString *buttonStringFromButtonNumberArray(NSArray<NSNumber *> *buttons) {
//    NSArray *buttonStrings = buttonStringArrayFromButtonNumberArray(buttons);
//    return [UIStrings naturalLanguageListFromStringArray:buttonStrings];
//}

@end
