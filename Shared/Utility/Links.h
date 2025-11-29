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
/// - Update: [Sep 2025] Why the heck don't we just use the strings used by the redirection service directly? Why this indirectIion?

typedef NSString * MFLinkID;

/// 'macmousefix:...' links
#define kMFLinkID_MMFLActivate    @"MMFLActivate"

/// General
#define kMFLinkID_BuyMeAMilkshake @"BuyMeAMilkshake"

/// Local links
#define kMFLinkID_MacOSSettingsLoginItems            @"MacOSSettingsLoginItems"
#define kMFLinkID_MacOSSettingsPrivacyAndSecurity    @"MacOSSettingsPrivacyAndSecurity"
#define kMFLinkID_MailToNoah                         @"MailToNoah"

/// Main places
#define kMFLinkID_Website                    @"Website"
#define kMFLinkID_GitHub                     @"GitHub"
#define kMFLinkID_Acknowledgements           @"Acknowledgements"
#define kMFLinkID_HelpTranslate              @"HelpTranslate"

/// Feedback
#define kMFLinkID_Feedback               @"Feedback"
#define kMFLinkID_FeedbackFeatureRequest @"FeedbackFeatureRequest"
#define kMFLinkID_FeedbackBugReport      @"FeedbackBugReport"

/// Help
#define kMFLinkID_AuthorizeAccessibilityHelp @"AuthorizeAccessibilityHelp"

/// Guides
#define kMFLinkID_GuidesAndCommunity        @"GuidesAndCommunity"
#define kMFLinkID_Guides                    @"Guides"
#define kMFLinkID_CapturedButtonsGuide      @"CapturedButtonsGuide"
#define kMFLinkID_CapturedScrollWheelsGuide @"CapturedScrollWheelsGuide"

#define kMFLinkID_VenturaEnablingGuide      @"VenturaEnablingGuide"


@interface Links : NSObject

///
/// Main interface
///
+ (NSString *_Nullable)link:(MFLinkID)linkID;

@end

#endif

NS_ASSUME_NONNULL_END
