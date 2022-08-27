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
                            let message = NSAttributedString(coolMarkdown: "Your license has been **activated**!\n\nThanks for buying Mac Mouse Fix! :)")!
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
