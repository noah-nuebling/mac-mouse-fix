//
// --------------------------------------------------------------------------
// LicenseToasts.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

@objc class LicenseToasts: NSObject {
    
    @objc static func showDeactivationToast() {
        let messageRaw = MFLocalizedString("license-toast.deactivate", comment: "")
        let message = MarkdownParser.attributedString(withCoolMarkdown: messageRaw, fillOutBase: false)!
        ToastController.attachNotification(withMessage: message, forDuration: kMFToastDurationAutomatic)
    }
    
    @objc static func showSuccessToast(_ isActivation: Bool) {
    
        let message: String
        if isActivation {
            message = MFLocalizedString("license-toast.activate", comment: "")
        } else {
            message = MFLocalizedString("license-toast.already-active", comment: "")
        }
        
        ToastController.attachNotification(withMessage: MarkdownParser.attributedString(withCoolMarkdown: message, fillOutBase: false)!, /// Is it safe to force-unwrap this?
                                           forDuration: kMFToastDurationAutomatic)
    }
    
    @objc static func showErrorToast(_ error: NSError?, _ licenseTypeInfoOverride: MFLicenseTypeInfo?, _ licenseKey: String) {
        
        var message: String = ""
        
        if let override = licenseTypeInfoOverride {
            
            switch override {
            case is MFLicenseTypeInfoFreeCountry:
                message = MFLocalizedString("license-toast.free-country", comment: "")
            case is MFLicenseTypeInfoForce:
                message = "FORCE_LICENSED flag is active"
            default: /// Default case: I think this can only happen if we forget to update this switch-statement after adding a new override.
                assert(false)
                DDLogError("Mac Mouse Fix appears to be licensed due to an override, but the specific override is not known:\n\(override)")
                message = "This license could not be activated but Mac Mouse Fix appears to be licensed due to some special condition that I forgot to write a message for. (Please [report this](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report) as a bug. Thank you!)"
            }
            
        } else {
            
            /// Show server error
            
            if let error = error {
                
                if error.domain == NSURLErrorDomain {
                    /// Discussion of `license-toast.no-internet` UI string [Oct 2025]
                    ///     - This isn't about having 'no internet' (as the UI text previously implied)  it's about MMF not reaching the Gumroad server. IIRC this shows up for Chinese users where Gumroad is blocked, and I remember a bunch of support requests from users confused about this. I don't know how to test the Great Firewall, so we adjusted the UI text and mentioned 'firewalls' to work better for Chinese users.
                    message = MFLocalizedString("license-toast.no-internet", comment: "")
                } else if error.domain == MFLicenseErrorDomain {
                    
                    switch error.code as MFLicenseErrorCode {
                        
                    case kMFLicenseErrorCodeInvalidNumberOfActivations:
                        
                        let nOfActivations = (error.userInfo["nOfActivations"] as? Int) ?? -1
                        let maxActivations = (error.userInfo["maxActivations"] as? Int) ?? -1
                        let messageFormat = MFLocalizedString("license-toast.activation-overload", comment: "Note: \"%2$d\", \"%3$d\", and \"%1$@\" are so-called \"C Format Specifers\". They will be replaced by numbers or text when the program runs. Make sure to type the format specifiers exactly like in the English version so that the text-replacement-code works correctly.") /// We do the localizer hint with the c-format-specifier-explanation on this string since it's the most complicated one atm. I feel like if we do the explanation on a simpler string, localizers might miss details on this one. E.g. usage of `d` instead `@` in some specifiers.
                        message = String(format: messageFormat, (Links.link(kMFLinkID_MailToNoah) ?? ""), nOfActivations, maxActivations)
                        
                    case kMFLicenseErrorCodeServerResponseInvalid:
                        
                        /// Sidenote:
                        ///     We added this localizedStringKey on the master branch inside .strings files, while we already replaced all the .strings files with .xcstrings files on the feature-strings-catalog branch. -- Don't forget to port this string over, when you merge the master changes into feature-strings-catalog! (Last updated: Oct 2024)
                        ///         Update: [Apr 2025] Just merged master into feature-strings-catalog and ported this string over.
                        let messageFormat = MFLocalizedString("license-toast.server-response-invalid", comment: "")
                        message = String(format: messageFormat, Links.link(kMFLinkID_MailToNoah) ?? "")
                        
                        do {
                            /// Log extended debug info to the console.
                            ///     We're not showing this to the user, since it's verbose and confusing and the error is on Gumroad's end and should be resolved in time.
                            
                            /// Clean up debug info
                            ///     The HTTPHeaders in the urlResponse contain some perhaps-**sensitive information** which we wanna remove, before logging.
                            ///     (Specifically, there seems to be some 'session cookie' field that might be sensitive - although we're not consciously using any session-stuff in the code - we're just making one-off POST requests to the Gumroad API without authentication, so it's weird. But better to be safe about this stuff if I don't understand it I guess.)
                            var debugInfoDict = error.userInfo
                            if let urlResponse = debugInfoDict["urlResponse"] as? HTTPURLResponse {
                                debugInfoDict["urlResponse"] = (["url": (urlResponse.url ?? ""), "status": (urlResponse.statusCode)] as [String: Any])
                            }
                            /// Log debug info
                            var debugInfo: String = ""
                            dump(debugInfoDict, to:&debugInfo)
                            DDLogError("Received invalid Gumroad server response. Debug info:\n\n\(debugInfo)")
                        }
                        
                    case kMFLicenseErrorCodeGumroadServerResponseError:
                        
                        if let gumroadMessage = error.userInfo["message"] as? String {
                            
                            switch gumroadMessage {
                                /// Considerations that went into the `license-toast.unknown-key` UI  text: [Oct 2025]
                                ///     Design:
                                ///         - Only scenarios where this shows up: 1. User makes mistake while hand-copiing / copy-pasting wrong from the license key website/email. 2. User copied the key for another software, not MMF. 3. User just tries random entries.
                                ///         - Whitespace and linebreaks are being removed programmatically now, so we don't need to hint about that. (That used to be a common issue.)
                                ///         - Also see this Claude conversation: https://claude.ai/share/f47aced0-6330-461d-9c60-8b29f5315fd7
                                ///     Technical:
                                ///         - Putting quotes inside emphasis (which we used to do for `license-toast.unknown-key`) breaks markdown parsing of emphasis when `NSString+Steganography.m` is active. -> Therefore we're putting the quotes '**outside**' the emphasis.
                                ///             See `MarkdownParser.m` for minimal repro. [Oct 2025]
                                /// Architecture: [Apr 2025]
                                ///     `"message": "That license does not exist for the provided product."` is part of the error-response json from the Gumroad API.
                                ///     Maybe it would be better to create an MFDataClass for the Gumroad response, so all 'knowledge' about the Gumroad API response format is centralized in one place in our code.
                            case "That license does not exist for the provided product.":
                                let messageFormat = MFLocalizedString("license-toast.unknown-key", comment: "")
                                message = String(format: messageFormat, licenseKey)
                            default:
                                let messageFormat = MFLocalizedString("license-toast.gumroad-error", comment: "")
                                message = String(format: messageFormat, gumroadMessage)
                            }   
                        }
                        
                    default:
                        assert(false)
                        message = "" /// Note: Don't need error handling for this i guess because it will only happen if we forget to implement handling for one of our own MFLicenseError codes.
                    }
                    
                } else {
                    let messageFormat = MFLocalizedString("license-toast.unknown-error", comment: "")
                    message = String(format: messageFormat, error.description) /// Should we use `error.localizedDescription` `.localizedRecoveryOptions` or similar here?
                }
                
            } else {
                message = MFLocalizedString("license-toast.unknown-reason", comment: "")
                message = String(format: message, (Links.link(kMFLinkID_FeedbackBugReport) ?? ""))
            }
        }
        
        assert(message != "")
        
        /// Display Toast
        ///     Notes:
        ///     - Why are we using `self.view.window!` here, and `MainAppState.shared.window` in other places?
        ///         IIRC `MainAppState` is safer and works in more cases whereas self.view.window might be nil in more edge cases IIRC (e.g. when the LicenseSheet is just being loaded or sth? I don't know anymore.)
        ///         Update [Aug 2025] `self.view.window!` seems to have caused this crash report on Tahoe Beta 5: https://github.com/noah-nuebling/mac-mouse-fix/issues/1432#issuecomment-3157295471
        ///             > Swapped for `MainAppState.shared.window`. Now *all* uses of `[ToastNotificationController attachNotificationWithMessage:]` use `MainAppState.shared.window`. We could just build it into `[ToastNotificationController attachNotificationWithMessage:]`.
        ///        >>> Update: [Oct 2025] Moved this all into `ToastController` (Formerly ToastNotificationController) –– Can delete this discussion

        ToastController.attachNotification(withMessage: MarkdownParser.attributedString(withCoolMarkdown: message, fillOutBase: false)!,
                                           forDuration: kMFToastDurationAutomatic)
    }
    
}
