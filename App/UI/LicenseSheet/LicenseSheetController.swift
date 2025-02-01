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
    @Atomic private var isProcessing = false /// Not sure atomic is necessary
    
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
            MainAppState.shared.aboutTabController?.updateUIToCurrentLicense() /// This might be sorta inefficient. Could we optimize by only calling this in certain cases or passing in our MFLicenseState?
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
        
        /// Start an async context
        /// Notes
        /// - @MainActor so all licensing code runs on the mainthread.
        
        Task.detached(priority: .userInitiated, operation: { @MainActor in
            
            /// Get licenseConfig
            /// Notes:
            /// - Instead of getting the licenseConfig every time, we could also use cached LicenseConfig, if we update it once on app start. The `URLSession` class that `LicenseConfig.get()` uses internally also has built-in caching. Maybe we should use that?
            ///     Update: (Oct 2024) GetLicenseConfig.get() now internally uses `inMemoryCache`. See implementation for more.
            let licenseConfig = await GetLicenseConfig.get()
            
            /// Determine if this is a licenseKey *activation* or just a *check*
            ///     We activate if this is a a fresh licenseKey, different from the key that was already activated and stored. Meaning that the user changed the licenseKey in the textbox before they clicked "Activate License"
            let isActivation = isDifferent
            
            /// Ask licenseServer
            ///     Note: (Nov 2024) If the licenseServer responds with a clear "yes"/"no" to the question "is this licenseValid", then the cache will get overriden with the server's response, which I think is desirable? (So we don't keep using old cached values after activating a new license.)
            let (state, serverError) = await GetLicenseState.licenseStateFromServer(key: key,
                                                                                    incrementActivationCount: isActivation, /// Increasing the activationCount (aka usageCount) is the main difference between activating and checking a license
                                                                                    licenseConfig: licenseConfig)
            /// Determine success
            /// Notes:
            ///     (The following note is outdated as of Oct 2024 because we're now directly using the lower-level function to talk the licenseServer, instead of using the higher-level function that applies freeCountry overrides and stuff.)
            ///     - By checking for valueFreshness we filter out the case where there's no internet but the cache still tells us it's licensed
            ///         The way things are currently set up this leads to weird behaviour when activating a license without internet in freeCountries: If the cache says it's licensed, users will get the no internet error, but if the cache says it's not licensed. Users will get the it's free in your country message. This is because the freeCountry overrides inside activateLicense only take effect if isLicensed is false. This is slightly weird but it's such a small edge case that I don't think it matters. Although it hints that it might be more logical to change the logic for applying the freeCountry overrides.
            let isValidLicense = state?.isLicensed ?? false
            
            /// Store new licenseKey
            if isActivation && isValidLicense {
                
                /// Validate
                if !MFLicenseTypeRequiresValidLicenseKey(state?.licenseTypeInfo) {
                    DDLogError("Error: Will store licenseKey but license has type that doesn't appear to require valid license key. (Doesn't make sense) License state: \(state ?? "<nil>")")
                    assert(false)
                }
                
                /// Store
                SecureStorage.set("License.key", value: key)
            }
            /// Get licenseState override
            ///     Explanation: Even if the server says the license is not valid, there might be special conditions that render the app activated regardless - and we wanna tell the user about this.
            let licenseStateOverride = isValidLicense ? nil : await GetLicenseState.licenseStateFromOverrides()
        
            /// Validate
            if let override = licenseStateOverride {
                assert(override.isLicensed == true)
            }
            
            /// Dispatch to mainThread because UI stuff needs to be controlled by main
            DispatchQueue.main.async {
            
                /// Display user feedback
                self.displayUserFeedback(isValidLicense: isValidLicense,
                                         licenseTypeInfo: state?.licenseTypeInfo,
                                         licenseTypeInfoOverride: licenseStateOverride?.licenseTypeInfo,
                                         error: serverError,
                                         key: key,
                                         isActivation: isActivation)
                
                /// Wrap up
                onComplete()
            }
            
        })
    }
    
    /// Helper for activateLicense
    
    fileprivate func displayUserFeedback(isValidLicense: Bool, licenseTypeInfo: MFLicenseTypeInfo?, licenseTypeInfoOverride: MFLicenseTypeInfo?, error: NSError?, key: String, isActivation: Bool) {
        
        /// Validate
        if (isValidLicense) {
            assert(licenseTypeInfo != nil)
        }
        
        if isValidLicense /** server says the license is valid */ {
            
            /// Dismiss
            LicenseSheetController.remove()
            
            /// Validate:
            ///     license is one of the licenseTypes that requires entering a valid license key.
            if !MFLicenseTypeRequiresValidLicenseKey(licenseTypeInfo) {
                DDLogError("Error: Will display default 'license has been activated' message but license has type that doesn't require valid license key (how can you 'activate' a license without a license key?) Type of the license: \(type(of: licenseTypeInfo))")
                assert(false)
            }
            
            let message: String
            if isActivation {
                message = NSLocalizedString("license-toast.activate", comment: "First draft: Your license has been **activated**! 🎉")
            } else {
                message = NSLocalizedString("license-toast.already-active", comment: "First draft: This license is **already activated**!")
            }

            ToastNotificationController.attachNotification(withMessage: NSAttributedString(coolMarkdown: message)!,
                                                           to: MainAppState.shared.window!, /// Is it safe to force-unwrap this?
                                                           forDuration: kMFToastDurationAutomatic)
            
        } else /** server failed to validate license */ {
            
            /// Show message
            var message: String = ""
            
            if let override = licenseTypeInfoOverride {
                
                switch override {
                case is MFLicenseTypeInfoFreeCountry:
                    message = NSLocalizedString("license-toast.free-country", comment: "First draft: This license __could not be activated__ but Mac Mouse Fix is currently __free in your country__!")
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
                        message = "" /// Note: Don't need error handling for this i guess because it will only happen if we forget to implement handling for one of our own MFLicenseError codes.
                    }
                    
                } else {
                    let messageFormat = NSLocalizedString("license-toast.unknown-error", comment: "First draft: **An unknown error occurred:**\n\n%@")
                    message = String(format: messageFormat, error.description) /// Should we use `error.localizedDescription` `.localizedRecoveryOptions` or similar here?
                }
                
            } else {
                message = NSLocalizedString("license-toast.unknown-reason", comment: "First draft: Activating your license failed for **unknown reasons**\n\nPlease write a **Bug Report** [here](https://noah-nuebling.github.io/mac-mouse-fix-feedback-assistant/?type=bug-report)")
            }
            }
            
            assert(message != "")
            
            /// Display Toast
            ///     Notes:
            ///     - Why are we using `self.view.window` here, and `MainAppState.shared.window` in other places? IIRC `MainAppState` is safer and works in more cases whereas self.view.window might be nil in more edge cases IIRC (e.g. when the LicenseSheet is just being loaded or sth? I don't know anymore.)
            ToastNotificationController.attachNotification(withMessage: NSAttributedString(coolMarkdown: message)!,
                                                           to: self.view.window!, /// Note: (Oct 2024) Might not wanna force-unwrap this
                                                           forDuration: kMFToastDurationAutomatic)
            
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
        
        /// Note:
        ///     (Oct 2024) This is the only thing that updates `self.initialKey`. After activating a new key, this needs to be called, otherwise things break.
        ///         TODO: Check if this is always called after activating a new key.
        
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
        
        guard let tabViewController = MainAppState.shared.tabViewController else { assert(false); return } /// [Jan 2025] Just saw this assert(false) with a debugger attached, but didn't investigate further. Didn't see it after, so seems to be very rare.
        tabViewController.dismiss(openInstance!)
        
        openInstance = nil
    }
    
    /// Define errors
    
//    private enum LicenseSheetError: Error {
//    case noChange
//    }
}
