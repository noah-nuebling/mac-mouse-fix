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
    
    NSString *currentLocale = NSBundle.mainBundle.preferredLocalizations.firstObject ?: @"";
    
    NSDictionary<NSString *, NSString *(^)(void)> *map = @{
            
            /// `macmousefix:` links
            kMFLinkIDMMFLActivate: ^{
                return @"macmousefix:activate";
            },
            
            /// General
            
            kMFLinkIDBuyMeAMilkshake: ^{
                return redirectionServiceLink(@"buy-me-a-milkshake", nil, nil, @{ @"locale": currentLocale }); /// Note: We might want to move this link to GitHub Sponsors (https://github.com/sponsors/noah-nuebling) at some point.
            },
            
            /// Non-browser links
            ///     Don't use redirection service for these so the browser isn't opened.
            kMFLinkIDMacOSSettingsLoginItems: ^{
                /// Note: This is used on the 'is-disabled-toast' toast, which we only need to show on macOS 13 Ventura and later (Because it lets you disable background items from the system settings.)
                return @"x-apple.systempreferences:com.apple.LoginItems-Settings.extension";
            },
            kMFLinkIDMacOSSettingsPrivacyAndSecurity: ^{
                /// Notes:
                /// - This is used on the accessibility sheet.
                /// - This link works on pre-Ventura *System Preferences* as well as Ventura-and-later *System Settings*. Evidence that this works pre-Ventura: This link shows up on a GitHub Gist which documents pre-Ventura System Preferences urls: https://gist.github.com/rmcdongit/f66ff91e0dad78d4d6346a75ded4b751
                return @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility";
            },
            
            kMFLinkIDMailToNoah: ^{
                return @"mailto:noah.n.public@gmail.com";
            },
            
            /// Main places
            kMFLinkIDWebsite: ^{
                return @"https://macmousefix.com/"; /// No need for redirection-service since this has javascript to adapt its locale to the user's browser settings, and if we ever change the domain, we'll set up a redirect directly on the page.
            },
            kMFLinkIDGitHub: ^{
                return redirectionServiceLink(@"mmf-github", nil, nil, @{ @"locale": currentLocale });
            },
            kMFLinkIDAcknowledgements: ^{
                return redirectionServiceLink(@"mmf-acknowledgements", nil, nil, @{ @"locale": currentLocale }); /// https://github.com/noah-nuebling/mac-mouse-fix/blob/master/Acknowledgements.md
            },
            kMFLinkIDLocalizationContribution: ^{
                return redirectionServiceLink(@"mmf-localization-contribution", nil, nil, @{ @"locale": currentLocale });
            },
            
            /// Feedback
            kMFLinkIDFeedbackBugReport: ^{
                return redirectionServiceLink(@"mmf-feedback-bug-report", nil, nil, @{ @"locale": currentLocale }); ///  https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report
            },
            kMFLinkIDFeedbackFeatureRequest: ^{
                return redirectionServiceLink(@"mmf-feedback-feature-request", nil, nil, @{ @"locale": currentLocale });
            },
            
            /// Help
            kMFLinkIDAuthorizeAccessibilityHelp: ^{ /// This link is opened when clicking `Help` on the Accessibility Sheet.
                return redirectionServiceLink(@"mmf-authorize-accessibility-help", nil, nil, @{ @"locale": currentLocale }); /// https://github.com/noah-nuebling/mac-mouse-fix/discussions/101
            },
            
            /// Guides
            kMFLinkIDGuidesAndCommunity: ^{ /// Note: This link is found under `Help > View Guides or Ask the Community` and links to the GitHub Discussions page (as of Sep 2024) I'm not sure it makes sense to put this in the redirection-service, as it's very specific.
                return redirectionServiceLink(@"mmf-guides-and-community", nil, nil, @{ @"locale": currentLocale });
            },
            kMFLinkIDGuides: ^{
                return redirectionServiceLink(@"mmf-guides", nil, nil, @{ @"locale": currentLocale }); /// https://github.com/noah-nuebling/mac-mouse-fix/discussions/categories/guides
            },
            kMFLinkIDCapturedButtonsGuide: ^{
                return redirectionServiceLink(@"mmf-captured-buttons-guide", nil, nil, @{ @"locale": currentLocale });
            },
            kMFLinkIDVenturaEnablingGuide: ^{
                return redirectionServiceLink(@"mmf-ventura-enabling-guide", nil, nil, @{ @"locale": currentLocale }); /// https://github.com/noah-nuebling/mac-mouse-fix/discussions/861
            },
            
            kMFLinkIDCapturedScrollingGuide: ^{
                assert(false); /// We don't have a guide for scroll-capturing atm (01.09.2024) I think we probably don't need one unless people have frequent questions.
                return nil;
            },
    };
    
    NSString *(^getter)(void) = map[linkID];
    NSString *result = getter ? getter() : nil;
    
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
    BOOL targetContainsInvalidCharacters = [target rangeOfCharacterFromSet:NSCharacterSet.URLQueryAllowedCharacterSet.invertedSet].location != NSNotFound;
    if (targetContainsInvalidCharacters) {
        assert(false);
        return nil;
    }
    
    /// Define helper function
    NSString *(^percentEscaped)(NSString *) = ^(NSString *str){
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
