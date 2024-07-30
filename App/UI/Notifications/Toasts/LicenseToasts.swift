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
        let messageRaw = NSLocalizedString("license-toast.deactivate", comment: "First draft: Your license has been **deactivated**")
        let message = NSAttributedString(coolMarkdown: messageRaw)!
        ToastController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: kMFToastDurationAutomatic)
    }
    
    @objc static func showSuccessToast(_ licenseReason: MFLicenseReason, _ userDidChangeLicenseKey: Bool) {
        
        /// Show message
        let message: String
        
        if licenseReason == kMFLicenseReasonValidLicense {
            
            if userDidChangeLicenseKey {
                message = NSLocalizedString("license-toast.activate", comment: "First draft: Your license has been **activated**! 🎉")
            } else {
                message = NSLocalizedString("license-toast.already-active", comment: "First draft: This license is **already activated**!")
            }
            
        } else if licenseReason == kMFLicenseReasonFreeCountry {
            message = NSLocalizedString("license-toast.free-country", comment: "First draft: This license __could not be activated__ but Mac Mouse Fix is currently __free in your country__!")
        } else if licenseReason == kMFLicenseReasonForce {
            message = "FORCE_LICENSED flag is active"
        } else {
            fatalError()
        }
        
        ToastController.attachNotification(withMessage: NSAttributedString(coolMarkdown: message)!, to: MainAppState.shared.window!, forDuration: kMFToastDurationAutomatic)
    }
    
    @objc static func showErrorToast(_ error: NSError?, _ licenseKey: String) {
        
        /// Show message
        var message = ""
        
        if let error = error {
            
            if error.domain == NSURLErrorDomain {
                message = NSLocalizedString("license-toast.no-internet", comment: "First draft: **There is no connection to the internet**\n\nTry activating your license again when your computer is online.")
            } else if error.domain == MFLicenseErrorDomain {
                
                switch Int32(error.code) {
                    
                case kMFLicenseErrorCodeInvalidNumberOfActivations:
                    
                    let nOfActivations = error.userInfo["nOfActivations"] as! Int
                    let maxActivations = error.userInfo["maxActivations"] as! Int
                    let messageFormat = NSLocalizedString("license-toast.activation-overload", comment: "First draft: This license has been activated **%d** times. The maximum is **%d**.\n\nBecause of this, the license has been invalidated. This is to prevent piracy. If you have other reasons for activating the license this many times, please excuse the inconvenience.\n\nJust [reach out](mailto:noah.n.public@gmail.com) and I will provide you with a new license! Thanks for understanding.")
                    message = String(format: messageFormat, nOfActivations, maxActivations)
                    
                case kMFLicenseErrorCodeGumroadServerResponseError:
                    
                    if let gumroadMessage = error.userInfo["message"] as! String? {
                        
                        switch gumroadMessage {
                        case "That license does not exist for the provided product.":
                            let messageFormat = NSLocalizedString("license-toast.unknown-key", comment: "First draft: **'%@'** is not a known license key\n\nPlease try a different key")
                            message = String(format: messageFormat, licenseKey)
                        default:
                            let messageFormat = NSLocalizedString("license-toast.gumroad-error", comment: "First draft: **An error with the licensing server occured**\n\nIt says:\n\n%@")
                            message = String(format: messageFormat, gumroadMessage)
                        }
                    }
                    
                default:
                    assert(false)
                }
                
            } else {
                let messageFormat = NSLocalizedString("license-toast.unknown-error", comment: "First draft: **An unknown error occurred:**\n\n%@")
                message = String(format: messageFormat, error.description)
            }
            
        } else {
            message = NSLocalizedString("license-toast.unknown-reason", comment: "First draft: Activating your license failed for **unknown reasons**\n\nPlease write a **Bug Report** [here](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report)")
        }
        
        assert(message != "")
        
        ToastController.attachNotification(withMessage: NSAttributedString(coolMarkdown: message)!, to: MainAppState.shared.window!, forDuration: kMFToastDurationAutomatic)
    }
    
}
