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

@implementation Links



+ (NSString *_Nullable)link:(MFLinkID)linkID {
    
    NSString *result = nil;
    
    switch (linkID) {
            
        case kMFLinkIDMailToNoah:
            result = @"mailto:noah.n.public@gmail.com"; /// Don't use redirection service so the browser isn't opened.
            break;
            
        case kMFLinkIDCapturedButtonsGuide:
            result = [Links redirectionServiceLinkWithTarget:@"mmf-captured-buttons-guide" params:@{ @"locale": NSLocale.currentLocale.localeIdentifier }];
            break;
        
        case kMFLinkIDCapturedScrollingGuide:
            assert(false); /// We don't have a guide for scroll-capturing atm (01.09.2024) I think we probably don't need one unless people have frequent questions.
            result = nil;
            break;
            
        case kMFLinkIDVenturaEnablingGuide:
            result = [Links redirectionServiceLinkWithTarget:@"mmf-ventura-enabling-guide" params:@{ @"locale": NSLocale.currentLocale.localeIdentifier }]; /// https://github.com/noah-nuebling/mac-mouse-fix/discussions/861
            break;
            
        default:
            break;
    }
    
    return result;
}

+ (NSString *)redirectionServiceLinkWithTarget:(NSString *_Nonnull)target params:(NSDictionary *_Nullable)params {
    return [Links redirectionServiceLinkWithTarget:target message:nil pageTitle:nil params:params];
}

+ (NSString *)redirectionServiceLinkWithTarget:(NSString *_Nonnull)target message:(NSString *_Nullable)message pageTitle:(NSString *_Nullable)pageTitle params:(NSDictionary *_Nullable)otherQueryParamsDict {
    
    /// Construct a link for our 'redirection service' website.
    ///
    /// `target` determines the destination of the redirect. Possible values are documented here: https://github.com/noah-nuebling/redirection-service
    /// `message` is shown in the browser window while redirecting. We usually use nil.
    /// `pageTitle` is shown inside the tab button while redirecting. We usually use nil. (The redirection service will fall back to `...` as of 30.08.2024)
    /// `otherQueryParams` is a dict of other url query params that apply to the given`target`.
    ///
    ///  Usage example:
    ///     ```
    ///     [Links redirectionServiceLinkWithTarget:@"mailto-noah" message:@"One Second..." pageTitle:@"Redirecting..." params:@{
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
        return [str stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
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
        assert([value isKindOfClass:[NSString class]]);
        
        /// Encode
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
