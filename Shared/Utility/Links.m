//
// --------------------------------------------------------------------------
// Links.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Links.h"
#import "SharedUtility.h"
#import "Logging.h"

@implementation Links



+ (NSString *_Nullable)link:(MFLinkID)linkID {

    /// Note: [Apr 2025] Why is the result optional? I feel like we should just assert(false) and return "<Invalid MFLinkID>" or something
    
    NSString *currentLocale = NSBundle.mainBundle.preferredLocalizations.firstObject ?: @"";
    
    
    NSString *result = nil;
    {
        #define xxx(linkID_) else if ([linkID_ isEqual: linkID])
        if ((0)) {}
                
        /// `macmousefix:` links
        xxx(kMFLinkID_MMFLActivate) {
            result = @"macmousefix:activate";
        }
        
        /// General
        xxx(kMFLinkID_BuyMeAMilkshake) {
            result = redirectionServiceLink(@"buy-me-a-milkshake", nil, nil, @{ @"locale": currentLocale }); /// Note: We might want to move this link to GitHub Sponsors (https://github.com/sponsors/noah-nuebling) at some point.
        }
        
        /// Non-browser links
        ///     Don't use redirection service for these so the browser isn't opened.
        xxx(kMFLinkID_MacOSSettingsLoginItems) {
            /// Note: This is used on the 'is-disabled-toast' toast, which we only need to show on macOS 13 Ventura and later (Because it lets you disable background items from the system settings.)
            result = @"x-apple.systempreferences:com.apple.LoginItems-Settings.extension";
        }
        xxx(kMFLinkID_MacOSSettingsPrivacyAndSecurity) {
            /// Notes:
            /// - This is used on the accessibility sheet.
            /// - This link works on pre-Ventura *System Preferences* as well as Ventura-and-later *System Settings*. Evidence that this works pre-Ventura: This link shows up on a GitHub Gist which documents pre-Ventura System Preferences urls: https://gist.github.com/rmcdongit/f66ff91e0dad78d4d6346a75ded4b751
            result = @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
        }
        
        xxx(kMFLinkID_MailToNoah) {
            result = @"mailto:noah.n.public@gmail.com";
        }
        
        /// Main places
        xxx(kMFLinkID_Website) {
            result = @"https://macmousefix.com/"; /// No need for redirection-service since this has javascript to adapt its locale to the user's browser settings, and if we ever change the domain, we'll set up a redirect directly on the page.
        }
        xxx(kMFLinkID_GitHub) {
            result = redirectionServiceLink(@"mmf-github", nil, nil, @{ @"locale": currentLocale });
        }
        xxx(kMFLinkID_Acknowledgements) {
            result = redirectionServiceLink(@"mmf-acknowledgements", nil, nil, @{ @"locale": currentLocale }); /// https://github.com/noah-nuebling/mac-mouse-fix/blob/master/Acknowledgements.md
        }
        xxx(kMFLinkID_HelpTranslate) {
            result = redirectionServiceLink(@"mmf-localization-contribution", nil, nil, @{ @"locale": currentLocale }); /// [Jul 2025] I kinda wanna rename `mmf-localization-contribution` to `mmf-help-translate` but I'm not sure we've used it somewhere already.
        }
        
        /// Feedback
        xxx(kMFLinkID_Feedback) {
            result = redirectionServiceLink(@"mmf-feedback", nil, nil, @{ @"locale": currentLocale });
        }
        xxx(kMFLinkID_FeedbackBugReport) {
            result = redirectionServiceLink(@"mmf-feedback-bug-report", nil, nil, @{ @"locale": currentLocale }); ///  https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report
        }
        xxx(kMFLinkID_FeedbackFeatureRequest) {
            result = redirectionServiceLink(@"mmf-feedback-feature-request", nil, nil, @{ @"locale": currentLocale });
        }
        
        /// Help
        xxx(kMFLinkID_AuthorizeAccessibilityHelp) { /// This link is opened when clicking `Help` on the Accessibility Sheet. Update: [Oct 2025] Removed that link now. Reasoning: I haven't ever seen the bug since we installed the automatic fix in 2.2.2, and there haven't been any (on-topic) comments on the Guide since then. If there are problems, people can access help from elsewhere. See note `MMF - Discontinuing GitHub Discussions.md`.
            result = redirectionServiceLink(@"mmf-authorize-accessibility-help", nil, nil, @{ @"locale": currentLocale }); /// https://github.com/noah-nuebling/mac-mouse-fix/discussions/101
        }
        
        /// Guides
        xxx(kMFLinkID_GuidesAndCommunity) { /// Note: This link is found under `Help > View Guides or Ask the Community` and links to the GitHub Discussions page (as of Sep 2024) I'm not sure it makes sense to put this in the redirection-service, as it's very specific.
            result = redirectionServiceLink(@"mmf-guides-and-community", nil, nil, @{ @"locale": currentLocale });
        }
        xxx(kMFLinkID_Guides) {
            result = redirectionServiceLink(@"mmf-guides", nil, nil, @{ @"locale": currentLocale }); /// https://github.com/noah-nuebling/mac-mouse-fix/discussions/categories/guides
        }
        xxx(kMFLinkID_CapturedButtonsGuide) {
            result = redirectionServiceLink(@"mmf-captured-buttons-guide", nil, nil, @{ @"locale": currentLocale });
        }
        xxx(kMFLinkID_CapturedScrollWheelsGuide) {
            result = redirectionServiceLink(@"mmf-captured-scroll-wheels-guide", nil, nil, @{ @"locale": currentLocale });
        }
        xxx(kMFLinkID_VenturaEnablingGuide) {
            result = redirectionServiceLink(@"mmf-ventura-enabling-guide", nil, nil, @{ @"locale": currentLocale }); /// https://github.com/noah-nuebling/mac-mouse-fix/discussions/861
        }
        
        else {
            result = nil; /// [Jul 2025] Expected for the "Send Me an Email" link
        }
        
        #undef xxx
    }
    
    DDLogDebug(@"Links.m: Generated link: %@ -> %@", linkID, result);
    
    return result;
}

static NSString *redirectionServiceLink(NSString *_Nonnull target, NSString *_Nullable message, NSString *_Nullable pageTitle, NSDictionary *_Nullable otherQueryParamsDict) {
    
    /// Construct a link for our 'redirection service' website.
    ///
    /// `target` determines the destination of the redirect. Possible values are documented here: https://github.com/noah-nuebling/redirection-service
    /// `message` is shown in the browser window while redirecting. We usually use nil.
    /// `pageTitle` is shown inside the tab button while redirecting. We usually use nil. (The redirection service will fall back to `Mac Mouse Fix...` as of 05.09.2024)
    /// `otherQueryParams` is a dict of other url query params that apply to the given`target`.
    ///
    ///  Usage example:
    ///     ```
    ///     redirectionServiceLinkWithTarget(@"mailto-noah", @"One Second...", @"Redirecting...", @{
    ///         @"subject": @"Cool Beans",
    ///         @"body":    @"aaaaa",
    ///     }];
    ///     ```
    ///
    ///     ... which would construct the link:
    ///     ```
    ///     https://noah-nuebling.github.io/redirection-service/?message=One%20Second...&page-title=Redirecting...&target=mailto-noah&body=aaaaa&subject=Cool%20Beans
    ///     ```
    ///
    ///     (Note: We should actually use the redirection service for mailto-links, since that opens a browser window, instead of opening the mail app directly.)
    
    /// Guard target
    if (target == nil || target.length == 0) {
        assert(false);
        return nil;
    }
    BOOL targetContainsInvalidCharacters = [target rangeOfCharacterFromSet: NSCharacterSet.URLQueryAllowedCharacterSet.invertedSet].location != NSNotFound;
    if (targetContainsInvalidCharacters) {
        assert(false);
        return nil;
    }
    
    /// Define helper function
    __auto_type percentEscaped = ^NSString *(NSString *str){
        return [str stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]; /// We use a percent escape specifically for url-queries (Everything after `/?`)
    };
    
    /// Preprocess message
    message = message ?: @""; /// Map nil -> emptyString
    message = percentEscaped(message);
    
    /// Preprocess pageTitle
    pageTitle = pageTitle ?: @""; /// Map nil -> emptyString
    pageTitle = percentEscaped(pageTitle);
    
    /// Preprocess other query params
    
    NSMutableString *otherQueryParamsStr = [NSMutableString string];
    
    for (NSString *key in otherQueryParamsDict) {
        NSString *value = otherQueryParamsDict[key];
        
        /// Validate
        assert([key isKindOfClass:[NSString class]]);
        assert(key.length > 0);
        assert([value isKindOfClass:[NSString class]]);
        
        /// Escape
        NSString *keyEscaped = percentEscaped(key);
        NSString *valueEscaped = percentEscaped(value);
        
        /// Append to result
        [otherQueryParamsStr appendFormat:@"&%@=%@", keyEscaped, valueEscaped];
    }
    
    /// Construct result
    NSString *result = stringf(@"https://redirect.macmousefix.com?message=%@&page-title=%@&target=%@%@", message, pageTitle, target, otherQueryParamsStr); //stringf(@"https://noah-nuebling.github.io/redirection-service?message=%@&page-title=%@&target=%@%@", message, pageTitle, target, otherQueryParamsStr);
    
    /// Return
    return result;
}

@end
