//
// --------------------------------------------------------------------------
// LicenseSheetController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
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
        
        /// Set flag
        ///     To prevent race conditions
        
        if isProcessing { return }
        isProcessing = true
        
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
            let message = NSAttributedString(coolMarkdown: "Your license has been **deactivated**.")!
            ToastNotificationController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: -1)
            
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
                Gumroad.activateLicense(key, email: "", maxActivations: licenseConfig.maxActivations) { success, serverResponse, error, urlResponse in
                    
                    /// Dispatch to main because UI stuff needs to be controlled by main
                    DispatchQueue.main.async {
                        
                        /// Display user feedback
                        self.displayUserFeedback(success: success, error: error, key: key, userChangedKey: isDifferent)
                        
                        /// Reset isProcessing flag
                        self.isProcessing = false
                    }
                    
                    if success {
                        SecureStorage.set("License.key", value: key)
                    }
                }
            } else {
                Gumroad.checkLicense(key, email: "", maxActivations: licenseConfig.maxActivations) { success, serverResponse, error, urlResponse in
                    
                    DispatchQueue.main.async {
                        
                        /// Display user feedback
                        self.displayUserFeedback(success: success, error: error, key: key, userChangedKey: isDifferent)
                        
                        /// Reset isProcessing flag
                        self.isProcessing = false
                    }
                }
            }
            
        }
    }
    
    /// Helper for activateLicense
    
    fileprivate func displayUserFeedback(success: Bool, error: NSError?, key: String, userChangedKey: Bool) {
        /// Dispatch to main because UI stuff needs to be controlled by main
        
        
        if success {
            
            /// Dismiss
            LicenseSheetController.remove()
            
            /// Show message
            let message: NSAttributedString
            if userChangedKey {
                message = NSAttributedString(coolMarkdown: "Your license has been **activated**!\n\nThanks for buying Mac Mouse Fix! :)")!
            } else {
                message = NSAttributedString(coolMarkdown: "This license is **already activated**!\n\nHope you're enjoying Mac Mouse Fix! :)")!
            }
            ToastNotificationController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: -1)
            
        } else /** failed to activate */{
            
            /// Show message
            var message: NSAttributedString = NSAttributedString(string: "")
            
            if let error = error {
                
                if error.domain == NSURLErrorDomain {
                    message = NSAttributedString(coolMarkdown: "**There is no connection to the internet**\n\nTry activating your license again when your computer is online.")!
                } else if error.domain == MFLicenseErrorDomain {
                    
                    switch Int32(error.code) {
                        
                    case kMFLicenseErrorCodeInvalidNumberOfActivations:
                        
                        let nOfActivations = error.userInfo["nOfActivations"] as! Int
                        let maxActivations = error.userInfo["maxActivations"] as! Int
                        message = NSAttributedString(coolMarkdown: "This license has been activated **\(nOfActivations)** times. The maximum is **\(maxActivations)**.\n\nBecause of this, the license has been invalidated. This is to prevent piracy. If you have other reasons for activating the license this many times, please excuse the inconvenience.\n\nJust [reach out](mailto:noah.n.public@gmail.com) and I will provide you with a new license. Thanks for understanding.")!
                        
                    case kMFLicenseErrorCodeGumroadServerResponseError:
                        
                        if let gumroadMessage = error.userInfo["message"] as! String? {
                            
                            switch gumroadMessage {
                            case "That license does not exist for the provided product.":
                                message = NSAttributedString(coolMarkdown: "The license key **'\(key)'** is unknown.\n\nPlease try another license key.")!
                            default:
                                message = NSAttributedString(coolMarkdown: "**An error with the licensing server occured**\n\nIt says:\n\n\(gumroadMessage)")!
                            }
                        }
                        
                    default:
                        assert(false)
                    }
                    
                } else {
                    message = NSAttributedString(string: "**An Unknown Error occurred**\n\nIt says:\n\n\(error.description)")
                }
                
            } else {
                
                message = NSAttributedString(string: "Activating your license failed for **unknown reasons**!\n\nPlease write a **Bug Report** [here](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).")
                
            }
            
            assert(message.string != "")
            
            ToastNotificationController.attachNotification(withMessage: message, to: self.view.window!, forDuration: -1)
            
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
        
        activateLicenseButton.title = "Activate License"
        activateLicenseButton.isEnabled = true
        activateLicenseButton.bezelColor = nil
        activateLicenseButton.keyEquivalent = "\r"
        
        if isEmpty {
            if !isDifferent {
                activateLicenseButton.isEnabled = false
            } else {
                activateLicenseButton.title = "Deactivate License"
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
        
        openInstance = LicenseSheetController()
        MainAppState.shared.tabViewController.presentAsSheet(openInstance!)
    }
    
    @objc static func remove() {
        
        MainAppState.shared.tabViewController.dismiss(openInstance!)
    }
    
    /// Define errors
    
    private enum LicenseSheetError: Error {
    case noChange
    }
}
