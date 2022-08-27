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
    
    /// IBActions & outlets
    
    @IBOutlet weak var licenseField: NSTextField!
    
    @IBOutlet weak var activateLicenseButton: NSButton!
    @IBAction func back(_ sender: Any) {
        LicenseSheetController.remove()
    }
    @IBAction func activateLicense(_ sender: Any) {
        
        do {
            
            /// Get key
            
            let key = licenseField.stringValue
            
            ///
            /// Local validation
            ///
            
            let isEmpty = key.isEmpty
            let didChange = key != initialKey
            
            guard !isEmpty else {
                assert(false)
            }
            guard didChange else {
                throw LicenseSheetError.noChange
            }
            
            ///
            /// Server validation
            ///
            
            /// Display loading indicator
            
            /// Ask server
            ///     We could also use cached LicenseConfig, if we update it once on app start.
            
            LicenseConfig.get { licenseConfg in
                License.activateLicense(license: key, licenseConfig: licenseConfg) { success, error in
                    
                    DispatchQueue.main.async {
                        /// Dispatch to main because UI stuff needs to be controlled by main
                        
                        
                        if success {
                            
                            /// Dismiss
                            LicenseSheetController.remove()
                            
                            /// Show message
                            let message = NSAttributedString(string: "It workeddd")
                            ToastNotificationController.attachNotification(withMessage: message, to: MainAppState.shared.window!, forDuration: -1)
                            
                        } else /** failed to activate */{
                            
                            
                            /// Show message
                            let message = NSAttributedString(string: "Error – \(String(describing: error))")
                            ToastNotificationController.attachNotification(withMessage: message, to: self.view.window!, forDuration: -1)
                            
                        }
                    }
                }
            }
            
            
            

        } catch LicenseSheetError.noChange {
            
            /// Show user feedback
            ///     Just show success but don't do anything
            
            let message = NSAttributedString(string: "Dats already the key u dumbass")
            ToastNotificationController.attachNotification(withMessage: message, to: self.view.window!, forDuration: -1)
            
        } catch {
            assert(false)
        }
    }
    
    /// licenseField delegate
    
    func controlTextDidChange(_ obj: Notification) {
        
        let key = licenseField.stringValue
        activateLicenseButton.isEnabled = !key.isEmpty
    }
    
    /// Init
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// Load existing key into licenseField
        if let key = License.currentLicense() {
            licenseField.stringValue = key
            initialKey = key
        }
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
