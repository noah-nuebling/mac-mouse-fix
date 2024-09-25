//
// --------------------------------------------------------------------------
// Links.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "SharedUtility.h"

NS_ASSUME_NONNULL_BEGIN

#ifndef LINKS_H
#define LINKS_H

///
/// MFLinkID enum
///
/// Notes:
/// - The names of these enum cases orient themselves after the redirection-service target names (See https://github.com/noah-nuebling/redirection-service/tree/main)
///     (We use the redirection-service to implement these unless there's a reason not to. For example for mailto:-links we don't want to have to open the browser to then open the redirection-service just to then open the Mail app.)
/// - We made this a string enum instead of regular int enum to be able to use these from IB. This prevents us from using these enums in c switch-statements. Not sure if worth it.

typedef NSString * MFLinkID;

/// 'macmousefix:...' links
#define kMFLinkIDMMFLActivate @"MMFLActivate"

/// General
#define kMFLinkIDBuyMeAMilkshake @"BuyMeAMilkshake"

/// Local links
#define kMFLinkIDMacOSSettingsLoginItems @"MacOSSettingsLoginItems"
#define kMFLinkIDMacOSSettingsPrivacyAndSecurity @"MacOSSettingsPrivacyAndSecurity"
#define kMFLinkIDMailToNoah @"MailToNoah"

/// Main places
#define kMFLinkIDWebsite @"Website"
#define kMFLinkIDGitHub @"GitHub"
#define kMFLinkIDAcknowledgements @"Acknowledgements"
#define kMFLinkIDLocalizationContribution @"LocalizationContribution"

/// Feedback
#define kMFLinkIDFeedbackFeatureRequest @"FeedbackFeatureRequest"
#define kMFLinkIDFeedbackBugReport @"FeedbackBugReport"

/// Help
#define kMFLinkIDAuthorizeAccessibilityHelp @"AuthorizeAccessibilityHelp"

/// Guides
#define kMFLinkIDGuidesAndCommunity @"GuidesAndCommunity"
#define kMFLinkIDGuides @"Guides"
#define kMFLinkIDCapturedButtonsGuide @"CapturedButtonsGuide"
#define kMFLinkIDCapturedScrollingGuide @"CapturedScrollingGuide"

#define kMFLinkIDVenturaEnablingGuide @"VenturaEnablingGuide"


@interface Links : NSObject

///
/// Main interface
///
+ (NSString *_Nullable)link:(MFLinkID)linkID;

@end

#endif

NS_ASSUME_NONNULL_END
