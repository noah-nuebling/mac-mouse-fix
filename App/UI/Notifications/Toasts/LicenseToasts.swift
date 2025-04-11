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
        let messageRaw = NSLocalizedString("license-toast.deactivate", comment: "")
        let message = NSAttributedString(coolMarkdown: messageRaw)!
        ToastController.attachNotification(withMessage: message, to: MainAppState.shared.frontMostWindowOrSheet!, forDuration: kMFToastDurationAutomatic)
    }
    
    @objc static func showSuccessToast(_ isActivation: Bool) {
    
        let message: String
        if isActivation {
            message = NSLocalizedString("license-toast.activate", comment: "")
        } else {
            message = NSLocalizedString("license-toast.already-active", comment: "")
        }
        
        ToastController.attachNotification(withMessage: NSAttributedString(coolMarkdown: message)!,
                                           to: MainAppState.shared.frontMostWindowOrSheet!, /// Is it safe to force-unwrap this?
                                           forDuration: kMFToastDurationAutomatic)
    }
    
    @objc static func showErrorToast(_ error: NSError?, _ licenseTypeInfoOverride: MFLicenseTypeInfo?, _ licenseKey: String) {
        
        var message: String = ""
        
        if let override = licenseTypeInfoOverride {
            
            switch override {
            case is MFLicenseTypeInfoFreeCountry:
                message = NSLocalizedString("license-toast.free-country", comment: "")
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
                    message = NSLocalizedString("license-toast.no-internet", comment: "")
                } else if error.domain == MFLicenseErrorDomain {
                    
                    switch error.code as MFLicenseErrorCode {
                        
                    case kMFLicenseErrorCodeInvalidNumberOfActivations:
                        
                        let nOfActivations = (error.userInfo["nOfActivations"] as? Int) ?? -1
                        let maxActivations = (error.userInfo["maxActivations"] as? Int) ?? -1
                        let messageFormat = NSLocalizedString("license-toast.activation-overload", comment: "Note: \"%2$d\", \"%3$d\", and \"%1$@\" are so-called \"C Format Specifers\". They will be replaced by numbers or text when the program runs. Make sure to type the format specifiers exactly like in English so that the text-replacement-code works correctly.") /// We do the localizer hint with the c-format-specifier-explanation on this string since it's the most complicated one atm. I feel like if we do the explanation on a simpler string, localizers might miss details on this one. E.g. usage of `d` instead `@` in some specifiers.
                        message = String(format: messageFormat, (Links.link(kMFLinkIDMailToNoah) ?? ""), nOfActivations, maxActivations)
                        
                    case kMFLicenseErrorCodeServerResponseInvalid:
                        
                        /// Sidenote:
                        ///     We added this localizedStringKey on the master branch inside .strings files, while we already replaced all the .strings files with .xcstrings files on the feature-strings-catalog branch. -- Don't forget to port this string over, when you merge the master changes into feature-strings-catalog! (Last updated: Oct 2024)
                        ///         Update: [Apr 2025] Just merged master into feature-strings-catalog and ported this string over.
                        let messageFormat = NSLocalizedString("license-toast.server-response-invalid", comment: "")
                        message = String(format: messageFormat, Links.link(kMFLinkIDMailToNoah) ?? "")
                        
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
                                /// Discussion on `license-toast.unknown-key` text:
                                ///     The `license-toast.unknown-key` error message used to just say `**'%@'** is not a known license key\n\nPlease try a different key` which felt a little rude or unhelpful for people who misspelled the key, or accidentally pasted/entered a newline (which I sometimes received support requests about)
                                ///     So we added the tip to remove whitespace in the error message. But then, we also made it impossible to enter any whitespace into the licenseKey textfield to begin with, so giving the tip to remove whitespace is a little unnecessary now. But I already wrote this and it sounds friendlier than just saying 'check if you misspelled' - I think? Might change this later.
                                ///     Update: [Apr 2025] 'Sounding friendly' but actually just wasting ppl's time is not a good idea.
                                ///         TODO: Change this string
                                /// Architecture: [Apr 2025]
                                ///     `"message": "That license does not exist for the provided product."` is part of the error-response json from the Gumroad API.
                                ///     Maybe it would be better to create an MFDataClass for the Gumroad response, so all 'knowledge' about the Gumroad API response format is centralized in one place in our code.
                            case "That license does not exist for the provided product.":
                                let messageFormat = NSLocalizedString("license-toast.unknown-key", comment: "")
                                message = String(format: messageFormat, licenseKey)
                            default:
                                let messageFormat = NSLocalizedString("license-toast.gumroad-error", comment: "")
                                message = String(format: messageFormat, gumroadMessage)
                            }   
                        }
                        
                    default:
                        assert(false)
                        message = "" /// Note: Don't need error handling for this i guess because it will only happen if we forget to implement handling for one of our own MFLicenseError codes.
                    }
                    
                } else {
                    let messageFormat = NSLocalizedString("license-toast.unknown-error", comment: "")
                    message = String(format: messageFormat, error.description) /// Should we use `error.localizedDescription` `.localizedRecoveryOptions` or similar here?
                }
                
            } else {
                message = NSLocalizedString("license-toast.unknown-reason", comment: "")
                message = String(format: message, (Links.link(kMFLinkIDFeedbackBugReport) ?? ""))
            }
        }
        
        assert(message != "")
        
        /// Display Toast
        ///     Notes:
        ///     - Why are we using `self.view.window` here, and `MainAppState.shared.window` in other places? IIRC `MainAppState` is safer and works in more cases whereas self.view.window might be nil in more edge cases IIRC (e.g. when the LicenseSheet is just being loaded or sth? I don't know anymore.)
        ///     - Update: [Apr 2025] While merging master into feature-strings-catalog: Changed `.shared.window!` to `shared.frontMostWindowOrSheet!` across this file. Not sure if correct.
        ToastController.attachNotification(withMessage: NSAttributedString(coolMarkdown: message)!,
                                           to: MainAppState.shared.frontMostWindowOrSheet!, /// Note: (Oct 2024) Might not wanna force-unwrap this
                                           forDuration: kMFToastDurationAutomatic)
    }
    
}
