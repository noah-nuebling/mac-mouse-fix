//
// --------------------------------------------------------------------------
// LicenseSheetController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa
import CocoaLumberjackSwift

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
            ToastNotificationController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: kMFToastDurationAutomatic)
            
            /// Wrap up
            onComplete()
            
            /// Return
            return
        }
        
        ///
        /// Server validation
        ///
        
        /// Display loading indicator
        ///     Note: Not necessary, the UI response is super fast
        
        /// Ask server
        /// Notes:
        /// - Instead of getting the licenseConfig every time, we could also use cached LicenseConfig, if we update it once on app start. The `URLSession` class that `LicenseConfig.get()` uses internally also has built-in caching. Maybe we should use that?
        
        Task.detached(priority: .userInitiated, operation: {
            
            let licenseConfig = await LicenseConfig.get()
            
            if isDifferent {
                
                let (state, error) = await License.activateLicense(key: key, licenseConfig: licenseConfig)
                let isLicensed = state.isLicensed
                let freshness = state.freshness
                let licenseTypeInfo = state.licenseTypeInfo
                    
                /// By checking for valueFreshness we filter out the case where there's no internet but the cache still tells us it's licensed
                ///     Note:
                ///     The way things are currently set up this leads to weird behaviour when activating a license without internet in freeCountries: If the cache says it's licensed, users will get the no internet error, but if the cache says it's not licensed. Users will get the it's free in your country message. This is because the freeCountry overrides inside activateLicense only take effect if isLicensed is false. This is slightly weird but it's such a small edge case that I don't think it matters. Although it hints that it might be more logical to change the logic for applying the freeCountry overrides.
                
                let success = isLicensed && (freshness == kMFValueFreshnessFresh)
                
                /// Store new licenseKey
                if success && MFLicenseTypeRequiresValidLicenseKey(licenseTypeInfo) {
                    SecureStorage.set("License.key", value: key)
                }
                
                /// Dispatch to main because UI stuff needs to be controlled by main
                DispatchQueue.main.async {
                    
                    /// Display user feedback
                    self.displayUserFeedback(success: success, licenseTypeInfo: licenseTypeInfo, error: error, key: key, userChangedKey: isDifferent)
                    
                    /// Wrap up
                    onComplete()
                }
                
            } else {
                
                let (state, error) = await License.checkLicense(key: key, licenseConfig: licenseConfig)
                let isLicensed = state.isLicensed
                let freshness = state.freshness
                let licenseTypeInfo = state.licenseTypeInfo
                    
                /// Should we check for valueFreshness here?
                let success = isLicensed
                
                DispatchQueue.main.async {
                    
                    /// Display user feedback
                    self.displayUserFeedback(success: success, licenseTypeInfo: licenseTypeInfo, error: error, key: key, userChangedKey: isDifferent)
                    
                    /// Wrap up
                    onComplete()
                }
            }
            
        })
    }
    
    /// Helper for activateLicense
    
    fileprivate func displayUserFeedback(success: Bool, licenseTypeInfo: MFLicenseTypeInfo, error: NSError?, key: String, userChangedKey: Bool) {
        
        if success {
            
            /// Dismiss
            LicenseSheetController.remove()
            
            /// Show message
            let message: String
            
            switch licenseTypeInfo {
            case is MFLicenseTypeInfoFreeCountry:
                message = NSLocalizedString("license-toast.free-country", comment: "First draft: This license __could not be activated__ but Mac Mouse Fix is currently __free in your country__!")
            case is MFLicenseTypeInfoForce:
                message = "FORCE_LICENSED flag is active"
            default:
            
                /// Validate:
                ///     license is one of the licenseTypes that requires entering a valid license key.
                if !MFLicenseTypeRequiresValidLicenseKey(licenseTypeInfo) {
                    DDLogError("Error: Will display default 'license has been activated' message but license has type that doesn't require valid license key (how can you 'activate' a license without a license key?) Type of the license: \(type(of: licenseTypeInfo))")
                    assert(false)
                }
            
                if userChangedKey {
                    message = NSLocalizedString("license-toast.activate", comment: "First draft: Your license has been **activated**! 🎉")
                } else {
                    message = NSLocalizedString("license-toast.already-active", comment: "First draft: This license is **already activated**!")
                }
            }

            ToastNotificationController.attachNotification(withMessage: NSAttributedString(coolMarkdown: message)!, to: MainAppState.shared.window!, forDuration: kMFToastDurationAutomatic)
            
        } else /** failed to activate */ {
            
            /// Show message
            var message = ""
            
            if let error = error {
                
                if error.domain == NSURLErrorDomain {
                    message = NSLocalizedString("license-toast.no-internet", comment: "First draft: **There is no connection to the internet**\n\nTry activating your license again when your computer is online.")
                } else if error.domain == MFLicenseErrorDomain {
                    
                    switch error.code as MFLicenseErrorCode {
                        
                    case kMFLicenseErrorCodeInvalidNumberOfActivations:
                        
                        let nOfActivations = (error.userInfo["nOfActivations"] as? Int) ?? -1
                        let maxActivations = (error.userInfo["maxActivations"] as? Int) ?? -1
                        let messageFormat = NSLocalizedString("license-toast.activation-overload", comment: "First draft: This license has been activated **%d** times. The maximum is **%d**.\n\nBecause of this, the license has been invalidated. This is to prevent piracy. If you have other reasons for activating the license this many times, please excuse the inconvenience.\n\nJust [reach out](mailto:noah.n.public@gmail.com) and I will provide you with a new license! Thanks for understanding.")
                        message = String(format: messageFormat, nOfActivations, maxActivations)
                    
                    case kMFLicenseErrorCodeServerResponseInvalid:
                        
                        /// Sidenote:
                        ///     We added this localizedStringKey on the master branch inside .strings files, while we already replaced all the .strings files with .xcstrings files on the feature-strings-catalog branch. -- Don't forget to port this string over, when you merge the master changes into feature-strings-catalog! (Last updated: Oct 2024)
                        let messageFormat = NSLocalizedString("license-toast.server-response-invalid", comment: "First draft: **There was an issue with the licensing server**\n\nPlease try again later.\n\nIf the issue persists, please reach out to me [here](mailto:noah.n.public@gmail.com).")
                        message = String(messageFormat)
                        
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
                            case "That license does not exist for the provided product.":
                                let messageFormat = NSLocalizedString("license-toast.unknown-key", comment: "First draft: **'%@'** is not a known license key\n\nPlease try a different key")
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
            
            /// Display Toast
            ///     Notes:
            ///     - Why are we using `self.view.window` here, and `MainAppState.shared.window` in other places? IIRC `MainAppState` is safer and works in more cases whereas self.view.window might be nil in more edge cases IIRC (e.g. when the LicenseSheet is just being loaded or sth? I don't know anymore.)
            ToastNotificationController.attachNotification(withMessage: NSAttributedString(coolMarkdown: message)!, to: self.view.window!, forDuration: kMFToastDurationAutomatic)
            
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
        if let k = SecureStorage.get("License.key") as? String {
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
