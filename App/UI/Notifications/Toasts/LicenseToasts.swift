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
    
    @objc static func showSuccessToast(_ licenseReason: MFLicenseReason, _ userDidChangeLicenseKey: Bool) {
        
        /// Show message
        let message: String
        
        if licenseReason == kMFLicenseReasonValidLicense {
            
            if userDidChangeLicenseKey {
                message = NSLocalizedString("license-toast.activate", comment: "")
            } else {
                message = NSLocalizedString("license-toast.already-active", comment: "")
            }
            
        } else if licenseReason == kMFLicenseReasonFreeCountry {
            message = NSLocalizedString("license-toast.free-country", comment: "")
        } else if licenseReason == kMFLicenseReasonForce {
            message = "FORCE_LICENSED flag is active"
        } else {
            fatalError()
        }
        
        ToastController.attachNotification(withMessage: NSAttributedString(coolMarkdown: message)!, to: MainAppState.shared.frontMostWindowOrSheet!, forDuration: kMFToastDurationAutomatic)
    }
    
    @objc static func showErrorToast(_ error: NSError?, _ licenseKey: String) {
        
        /// Show message
        var message = ""
        
        if let error = error {
            
            if error.domain == NSURLErrorDomain {
                message = NSLocalizedString("license-toast.no-internet", comment: "")
            } else if error.domain == MFLicenseErrorDomain {
                
                switch Int32(error.code) {
                    
                case kMFLicenseErrorCodeInvalidNumberOfActivations:
                    
                    let nOfActivations = error.userInfo["nOfActivations"] as! Int
                    let maxActivations = error.userInfo["maxActivations"] as! Int
                    let messageFormat = NSLocalizedString("license-toast.activation-overload", comment: "Note: \"%2$d\", \"%3$d\", and \"%1$@\" are so-called \"C Format Specifers\". They will be replaced by numbers or text when the program runs. Make sure to type the format specifiers exactly like in English so that the text-replacement-code works correctly.") /// We do the localizer hint with the c-format-specifier-explanation on this string since it's the most complicated one atm. I feel like if we do the explanation on a simpler string, localizers might miss details on this one. E.g. usage of `d` instead `@` in some specifiers.
                    message = String(format: messageFormat, (Links.link(kMFLinkIDMailToNoah) ?? ""), nOfActivations, maxActivations)
                    
                case kMFLicenseErrorCodeGumroadServerResponseError:
                    
                    if let gumroadMessage = error.userInfo["message"] as! String? {
                        
                        switch gumroadMessage {
                        /// Discussion:
                        ///     The `license-toast.unknown-key` error message used to just say `**'%@'** is not a known license key\n\nPlease try a different key` which felt a little rude or unhelpful for people who misspelled the key, or accidentally pasted/entered a newline (which I sometimes received support requests about)
                        ///     So we added the tip to remove whitespace in the error message. But then, we also made it impossible to enter any whitespace into the licenseKey textfield to begin with, so giving the tip to remove whitespace is a little unnecessary now. But I already wrote this and it sounds friendlier than just saying 'check if you misspelled' - I think? Might change this later.
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
                }
                
            } else {
                let messageFormat = NSLocalizedString("license-toast.unknown-error", comment: "")
                message = String(format: messageFormat, error.description)
            }
            
        } else {
            message = NSLocalizedString("license-toast.unknown-reason", comment: "")
            message = String(format: message, (Links.link(kMFLinkIDFeedbackBugReport) ?? ""))
        }
        
        assert(message != "")
        
        ToastController.attachNotification(withMessage: NSAttributedString(coolMarkdown: message)!, to: MainAppState.shared.frontMostWindowOrSheet!, forDuration: kMFToastDurationAutomatic)
    }
    
}
