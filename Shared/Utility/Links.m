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
    
    NSDictionary<NSString *, NSString *(^)(void)> *map = @{
            
            /// `macmousefix:...` links
            kMFLinkIDMMFActivate: ^{
                return @"macmousefix:activate";
            },
            
            /// General
            kMFLinkIDMacOSSettingsLoginItems: ^{
                return @"x-apple.systempreferences:com.apple.LoginItems-Settings.extension"; /// Don't use redirection service so the browser isn't opened.
            },
            kMFLinkIDMailToNoah: ^{
                return @"mailto:noah.n.public@gmail.com";
            },
            
            /// Feedback
            kMFLinkIDFeedbackBugReport: ^{
                return redirectionServiceLink(@"mmf-feedback-bug-report", nil, nil, @{ @"locale": NSLocale.currentLocale.localeIdentifier }); ///  https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report
            },
            
            /// Guides
            kMFLinkIDCapturedButtonsGuide: ^{
                return redirectionServiceLink(@"mmf-captured-buttons-guide", nil, nil, @{ @"locale": NSLocale.currentLocale.localeIdentifier });
            },
            kMFLinkIDCapturedScrollingGuide: ^{
                assert(false); /// We don't have a guide for scroll-capturing atm (01.09.2024) I think we probably don't need one unless people have frequent questions.
                return nil;
            },
            kMFLinkIDVenturaEnablingGuide: ^{
                return redirectionServiceLink(@"mmf-ventura-enabling-guide", nil, nil, @{ @"locale": NSLocale.currentLocale.localeIdentifier }); /// https://github.com/noah-nuebling/mac-mouse-fix/discussions/861
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
    /// `pageTitle` is shown inside the tab button while redirecting. We usually use nil. (The redirection service will fall back to `...` as of 30.08.2024)
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
    ///     https://noah-nuebling.github.io/redirection-service?message=One%20Second...&page-title=Redirecting...&target=mailto-noah&body=aaaaa&subject=Cool%20Beans
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
    NSString *result = stringf(@"https://noah-nuebling.github.io/redirection-service?message=%@&page-title=%@&target=%@%@", message, pageTitle, target, otherQueryParamsStr);
    
    /// Return
    return result;
}

@end
