//
// --------------------------------------------------------------------------
// LicenseSheetController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
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
            MFMessagePort.sendMessage("terminate", withPayload: nil, waitForReply: false) /// Restart helper
        }
        
        /// Gather info
        
        let key = licenseField.stringValue
        
        let isEmpty = key.isEmpty
        let isDifferent = key != initialKey
        
        /// Validate
        
        if isEmpty {
            assert(isDifferent) /// Otherwise the button should be deactivated
        }
        
        /// Deactivate license
        
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
        /// - We're totally curcumventing License.swift. It was designed as mainly a wrapper around Gumroad.swift, but we're using Gumroad.swift directly. Not sure why, but it made sense while writing this.
        ///     -> Should mayebe overthink what the role of License.swift is.
        
        LicenseConfig.get { licenseConfig in
            
            if isDifferent {
                
                License.activateLicense(key: key, licenseConfig: licenseConfig) { isLicensed, freshness, licenseReason, error in
                    
                    /// By checking for valueFreshness we filter out the case where there's no internet but the cache still tells us it's licensed
                    ///     Note:
                    ///     The way things are currently set up this leads to weird behaviour when activating a license without internet in freeCountries: If the cache says it's licensed, users will get the no internet error, but if the cache says it's not licensed. Users will get the it's free in your country message. This is because the freeCountry overrides inside activateLicense only take effect if isLicensed is false. This is slightly weird but it's such a small edge case that I don't think it matters. Although it hints that it might be more logical to change the logic for applying the freeCountry overrides.
                    
                    let success = isLicensed && (freshness == kMFValueFreshnessFresh)
                    
                    /// Store new licenseKey
                    if success && licenseReason == kMFLicenseReasonValidLicense {
                        SecureStorage.set("License.key", value: key)
                    }
                    
                    /// Dispatch to main because UI stuff needs to be controlled by main
                    DispatchQueue.main.async {
                        
                        /// Display user feedback
                        self.displayUserFeedback(success: success, licenseReason: licenseReason, error: error, key: key, userChangedKey: isDifferent)
                        
                        /// Wrap up
                        onComplete()
                    }
                }
                
            } else {
                
                License.checkLicense(key: key, licenseConfig: licenseConfig) { isLicensed, freshness, licenseReason, error in
                    
                    /// Should we check for valueFreshness here?
                    let success = isLicensed
                    
                    DispatchQueue.main.async {
                        
                        /// Display user feedback
                        self.displayUserFeedback(success: success, licenseReason: licenseReason, error: error, key: key, userChangedKey: isDifferent)
                        
                        /// Wrap up
                        onComplete()
                    }
                }
            }
            
        }
    }
    
    /// Helper for activateLicense
    
    fileprivate func displayUserFeedback(success: Bool, licenseReason: MFLicenseReason, error: NSError?, key: String, userChangedKey: Bool) {
        
        if success {
            
            /// Dismiss
            LicenseSheetController.remove()
            
            /// Show message
            let message: String
            
            if licenseReason == kMFLicenseReasonValidLicense {
                
                if userChangedKey {
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

            ToastNotificationController.attachNotification(withMessage: NSAttributedString(coolMarkdown: message)!, to: MainAppState.shared.window!, forDuration: -1)
            
        } else /** failed to activate */ {
            
            /// Show message
            var message = ""
            
            if let error = error {
                
                if error.domain == NSURLErrorDomain {
                    
                    // TODO: Update this to be more detailed/accurate - say that it couldn't connect to Gumroad.com/AWS - Perhaps use NSError.localizedDescription, to provide reason why it couldn't connect.
                    
                    message = NSLocalizedString("license-toast.no-internet", comment: "First draft: **There is no connection to the internet**\n\nTry activating your license again when your computer is online.")
                    
                } else if error.domain == MFLicenseErrorDomain {
                    
                    switch Int32(error.code) {
                        
                    case kMFLicenseErrorCodeNoInternetAndNoCache:
                        
                        // TODO: Refactor this
                        /// This error is a wrapper around `NSURLErrorDomain` error. Just for the case that there is also no cache. Can probably refactor this to be handled together with other `NSURLErrorDomain` handling code.
                        /// I'm not sure this is really ever triggered - We used to not handle this case at all, and even if I delete the config and disconnect from the intenet (the config contains the cache), the `error.domain == NSURLErrorDomain` case is hit instead of this.
                        
                        message = NSLocalizedString("license-toast.no-cache", comment: "First draft: **There is no connection to the internet** ((({[and no cache]})))\n\nTry activating your license again when your computer is online.")
                        
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
                                message = String(format: messageFormat, key)
                            default:
                                let messageFormat = NSLocalizedString("license-toast.gumroad-error", comment: "First draft: **An error with the licensing server occured**\n\nIt says:\n\n%@")
                                message = String(format: messageFormat, gumroadMessage)
                            }
                        }
                    
                    case kMFLicenseErrorCodeKeyNotFound:
                        
                        /// Discussion:
                        /// - This error happens if __no key__ is passed into `License.activateLicense(key:,licenseConfig:)` and there's also no key inside SecureStorage. We always pass in a key before this here is called, so this should never happen.
                        ///     - The UI code around licensing has caused a few weird rare bugs though, so we want to make this extra safe and cover all cases. E.g. In [this bug](https://github.com/noah-nuebling/mac-mouse-fix/issues/817), clicking the 'Activate License' button apparently creates no user feedback. That's the main reason we added this case.
                        
                        assert(false);
                        
                        let messageFormat = NSLocalizedString("license-toast.internal-error.key-not-found", comment: "Activating your license failed due internal error **kMFLicenseErrorCodeKeyNotFound**.\n\nPlease write a **Bug Report** [here](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).")
                        message = String(format: messageFormat, Int32(error.code))
                        
                    default: 
                        
                        // TODO: Test this error message.
                        
                        let messageFormat = NSLocalizedString("license-toast.unhandled-license-error", comment: "Activating your license failed due to **License Error %d**.\n\nThis error message needs to be updated. Please write a **Bug Report** [here](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report).")
                        message = String(format: messageFormat, Int32(error.code))
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
        
        /// Trim whitespace
        licenseField.stringValue = (licenseField.stringValue as NSString).stringByTrimmingWhiteSpace() as String
        
        /// Update UI
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
        
        guard let tabViewController = MainAppState.shared.tabViewController else {
            assert(false) /// This assert fails sometimes when clicking the Activate License link on Gumroad while having the debugger attached.
            return
        }
        tabViewController.presentAsSheet(openInstance!)
    }
    
    @objc static func remove() {
        
        guard let tabViewController = MainAppState.shared.tabViewController else { assert(false); return }
        tabViewController.dismiss(openInstance!)
        
        openInstance = nil
    }
    
    /// Define errors
    
    private enum LicenseSheetError: Error {
    case noChange
    }
}
