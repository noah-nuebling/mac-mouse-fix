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
        /// MERGE TODO: [Apr 2025] Fill this back in

    }
    
    @objc static func showErrorToast(_ error: NSError?, _ licenseKey: String) {
        /// MERGE TODO: [Apr 2025] Fill this back in
    }
    
}
