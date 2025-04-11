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
            LicenseToasts.showDeactivationToast()
            
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
        
        /// - [x] MERGE TODO: [Apr 9 2025]  Backport feature-strings-catalog changes from LicenseToasts.swift showSuccessToast() and showErrorToast() into this func (displayUserFeedback()). Delete LicenseToasts.swift implementations.
        /// - [x] MERGE TODO: Refactor displayUserFeedback() and extract functionality into LicenseToasts.swift (So that ToastAndSheetTests works.)
        ///
        /// MERGE TODO: We kinda blindly deleted all the 'First draft:' comments from the master branch. Except for:
        ///     - license-toast.activation-overload – because that string only existed on the master
        ///     -> Meaning, if we changed any strings after they master and feature-strings-catalog diverted, those changes would be lost
        ///         -> MERGE TODO: Check if any strings changed on master except for license-toast.activation-overload (Not sure how.)
        ///
        /// Also address all the other 'MERGE TODO:'s. 

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
            
            LicenseToasts.showSuccessToast(isActivation)
            
        } else /** server failed to validate license */ {
            
            LicenseToasts.showErrorToast(error,licenseTypeInfoOverride, key)
            
        }
    }
    
    /// licenseField delegate
    
    func controlTextDidChange(_ obj: Notification) {
        
        /// Trim whitespace
        licenseField.stringValue = (licenseField.stringValue as NSString).stringByRemovingAllWhiteSpace() as String
        
        /// Update UI
        updateUIToLicenseField()
    }
    
    
    /// Helper for controlTextDidChange
    fileprivate func updateUIToLicenseField() {
        
        let key = licenseField.stringValue
        let isEmpty = key.isEmpty
        let isDifferent = key != initialKey
        
        activateLicenseButton.title = NSLocalizedString("license-button.activate", comment: "")
        activateLicenseButton.isEnabled = true
        activateLicenseButton.bezelColor = nil
        activateLicenseButton.keyEquivalent = "\r"
        
        if isEmpty {
            if !isDifferent {
                activateLicenseButton.isEnabled = false
            } else {
                activateLicenseButton.title = NSLocalizedString("license-button.deactivate", comment: "")
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
