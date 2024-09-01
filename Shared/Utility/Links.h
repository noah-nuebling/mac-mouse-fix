//
// --------------------------------------------------------------------------
// Links.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MFLinkID) {
    
    /// Note:
    ///     The names of these enum cases orient themselves after the redirection-service target names (See https://github.com/noah-nuebling/redirection-service/tree/main)
    ///     (We use the redirection-service to implement these unless there's a reason not to. For example for mailto:-links we don't want to have to open the browser to then open the redirection-service just to then open the Mail app.)
    
    /// General
    kMFLinkIDMacOSSettingsLoginItems,
    kMFLinkIDMailToNoah,
    
    /// Feedback
    kMFLinkIDFeedbackBugReport,
    
    /// Guides
    kMFLinkIDCapturedButtonsGuide,
    kMFLinkIDCapturedScrollingGuide,
    kMFLinkIDVenturaEnablingGuide,
    
};

@interface Links : NSObject

+ (NSString *_Nullable)link:(MFLinkID)linkID;

@end

NS_ASSUME_NONNULL_END
