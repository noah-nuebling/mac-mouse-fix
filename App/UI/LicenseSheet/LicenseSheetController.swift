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
                        if success {
                            LicenseSheetController.remove() /// Dismiss sheet
                            LicenseToasts.showSuccessToast(licenseReason, isDifferent)
                        } else /** failed to activate */ {
                            LicenseToasts.showErrorToast(error, key)
                        }
                        
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
                        if success {
                            LicenseSheetController.remove() /// Dismiss sheet
                            LicenseToasts.showSuccessToast(licenseReason, isDifferent)
                        } else /** failed to activate */ {
                            LicenseToasts.showErrorToast(error, key)
                        }
                        
                        /// Wrap up
                        onComplete()
                    }
                }
            }
            
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
