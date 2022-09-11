//
// --------------------------------------------------------------------------
// LicenseSheetController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

import Cocoa

@objc class LicenseSheetController: NSViewController, NSTextFieldDelegate {

    /// Vars
    
    private static var openInstance: LicenseSheetController? = nil
    
    private var initialKey: String? = nil
    private var isProcessing = false
    
    /// IBActions & outlets
    
    @IBOutlet weak var licenseField: NSTextField!
    
    @IBOutlet weak var activateLicenseButton: NSButton!
    @IBAction func back(_ sender: Any) {
        LicenseSheetController.remove()
    }
    
    @IBAction func activateLicense(_ sender: Any) {
        
        /// Define onComplete actions
        
        /// Set flag
        ///     To prevent race conditions
        
        if isProcessing { return }
        isProcessing = true
        
        let onComplete = {
            self.isProcessing = false
            MainAppState.shared.aboutTabController?.updateUIToCurrentLicense() /// Would much more efficient to pass in the license here
            SharedMessagePort.sendMessage("terminate", withPayload: nil, expectingReply: false) /// Restart helper
        }
        
        /// Gather info
        
        let key = licenseField.stringValue
        
        let isEmpty = key.isEmpty
        let isDifferent = key != initialKey
        
        /// Validate
        
        if isEmpty {
            assert(isDifferent) /// Otherwise the button should be deactivated
        }
        
        /// Deactivate
        
        if isEmpty && isDifferent {
            
            /// Delete key
            SecureStorage.delete("License.key")
            
            /// Close sheet
            LicenseSheetController.remove()
            
            /// Show message
            let messageRaw = NSLocalizedString("license-toast.deactivate", comment: "First draft: Your license has been **deactivated**")
            let message = NSAttributedString(coolMarkdown: messageRaw)!
            ToastNotificationController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: -1)
            
            /// Wrap up
            onComplete()
            
            /// Return
            return
        }
        
        ///
        /// Server validation
        ///
        
        /// Display loading indicator
        
        /// Ask server
        /// Notes:
        /// - We could also use cached LicenseConfig, if we update it once on app start.
        /// - We're totally curcumventint License.swift. It was designed as mainly a wrapper around Gumroad.swift, but we're using Gumroad.swift directly. Not sure why, but it made sense while writing this.
        ///     -> Should mayebe overthink what the role of License.swift is.
        
        LicenseConfig.get { licenseConfig in
            
            if isDifferent {
                Gumroad.activateLicense(key, maxActivations: licenseConfig.maxActivations) { success, serverResponse, error, urlResponse in
                    
                    /// Store new licenseKey
                    if success {
                        SecureStorage.set("License.key", value: key)
                    }
                    
                    /// Dispatch to main because UI stuff needs to be controlled by main
                    DispatchQueue.main.async {
                        
                        /// Display user feedback
                        self.displayUserFeedback(success: success, error: error, key: key, userChangedKey: isDifferent)
                        
                        /// Wrap up
                        onComplete()
                    }
                }
            } else {
                Gumroad.checkLicense(key, maxActivations: licenseConfig.maxActivations) { success, serverResponse, error, urlResponse in
                    
                    DispatchQueue.main.async {
                        
                        /// Display user feedback
                        self.displayUserFeedback(success: success, error: error, key: key, userChangedKey: isDifferent)
                        
                        /// Wrap up
                        onComplete()
                    }
                }
            }
            
        }
    }
    
    /// Helper for activateLicense
    
    fileprivate func displayUserFeedback(success: Bool, error: NSError?, key: String, userChangedKey: Bool) {
        
        if success {
            
            /// Dismiss
            LicenseSheetController.remove()
            
            /// Show message
            let message: String
            if userChangedKey {
                message = NSLocalizedString("license-toast.activate", comment: "First draft: Your license has been **activated**! 🎉")
            } else {
                message = NSLocalizedString("license-toast.already-active", comment: "First draft: This license is **already activated**!")
            }
            ToastNotificationController.attachNotification(withMessage: NSAttributedString(coolMarkdown: message)!, to: MainAppState.shared.window!, forDuration: -1)
            
        } else /** failed to activate */{
            
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
                                let messageFormat = NSLocalizedString("license-toast.unknown-key", comment: "First draft: **'%@'** is not a known license key\nPlease try another one")
                                message = String(format: messageFormat, key)
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
            
            ToastNotificationController.attachNotification(withMessage: NSAttributedString(coolMarkdown: message)!, to: self.view.window!, forDuration: -1)
            
        }
    }
    
    /// licenseField delegate
    
    func controlTextDidChange(_ obj: Notification) {
        
        updateUIToLicenseField()
    }
    
    
    /// Helper for controlTextDidChange
    fileprivate func updateUIToLicenseField() {
        
        let key = licenseField.stringValue
        let isEmpty = key.isEmpty
        let isDifferent = key != initialKey
        
        activateLicenseButton.title = NSLocalizedString("license-button.activate", comment: "First draft: Activate License")
        activateLicenseButton.isEnabled = true
        activateLicenseButton.bezelColor = nil
        activateLicenseButton.keyEquivalent = "\r"
        
        if isEmpty {
            if !isDifferent {
                activateLicenseButton.isEnabled = false
            } else {
                activateLicenseButton.title = NSLocalizedString("license-button.deactivate", comment: "First draft: Deactivate License")
                activateLicenseButton.bezelColor = .systemRed
                activateLicenseButton.keyEquivalent = ""
            }
        }
    }
    
    /// Init
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// Load existing key into licenseField
        var key: String = ""
        if let k = SecureStorage.get("License.key") as! String? {
            key = k
        }
        licenseField.stringValue = key
        initialKey = key
        
        /// Update UI
        updateUIToLicenseField()
        
        /// Init isProcessing flag
        isProcessing = false
    }
    
    /// Interface
    
    @objc static func add() {
        
        if openInstance != nil { return }
        openInstance = LicenseSheetController()
        MainAppState.shared.tabViewController.presentAsSheet(openInstance!)
    }
    
    @objc static func remove() {
        
        MainAppState.shared.tabViewController.dismiss(openInstance!)
        openInstance = nil
    }
    
    /// Define errors
    
    private enum LicenseSheetError: Error {
    case noChange
    }
}
