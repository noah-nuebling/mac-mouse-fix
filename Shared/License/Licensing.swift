//
// --------------------------------------------------------------------------
// Licensing.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

@objc class Licensing: NSObject {
    
    // MARK: Interface
    
    @objc static func runCheckAndDisplayUI(triggeredByUser: Bool) {
        
        /// Run check should be called when
        
        /// Get licensing state
        
        licensingState { licensing, error in
            
            if licensing.state == kMFLicensingStateLicensed || licensing.state == kMFLicensingStateCachedLicensed {
                 
                /// Do nothing if licensed
                return
                
            } else {
                
                /// Not licensed -> check trial
                if licensing.daysOfUse <= licensing.trialDays {
                    
                    /// Trial still active -> do nothing
                    ///     Note: Maybe display small reminder after half of trial is over?
                    
                } else {
                    
                    /// Trial has expired -> show UI
                    
                    if triggeredByUser {
                        
                        /// Display more complex UI
                        /// ...
                        assert(SharedUtility.runningMainApp())
                        
                        
                    } else {
                        
                        /// Not triggered by user -> the users workflow is disruped -> make it as short as possible
                        /// ...
                        assert(SharedUtility.runningHelper())
                        
                    }
                    
                }
                
            }
            
        }
    }
    
    @objc static func licensingState(completionHandler: @escaping (_ licensing: MFLicensingReturn, _ error: NSError?) -> ()) {
        
        /// Check license
        checkLicense { state, error in
            
            /// Write to cache
            ///     Might be cleaner to do this in `checkLicense`?
            if state == kMFLicensingStateLicensed {
                setConfig("License.isLicensedCache", true as NSObject)
                commitConfig()
            } else if state == kMFLicensingStateUnlicensed {
                setConfig("License.isLicensedCache", false as NSObject)
                commitConfig()
            }
            
            /// Check trial
            let daysOfUse = Trial.daysOfUse
            
            /// Check licenseConfig
            LicenseConfig.get { licenseConfig in
                
                /// Return
                let result = MFLicensingReturn(state: state, daysOfUse: Int32(daysOfUse), trialDays: Int32(licenseConfig.trialDays))
                
                completionHandler(result, error)
            }
        }
        
    }
    
    // MARK: Core
    
    fileprivate static func checkLicense(completionHandler: @escaping (MFLicensingState, NSError?) -> ()) {
        
        /// Get email and license from config file
        
        guard
            let key = config("License.key") as? String,
            let email = config("License.email") as? String
        else {
            
            /// Return unlicensed
            let error = NSError(domain: MFLicensingErrorDomain, code: Int(kMFLicensingErrorCodeEmailOrKeyNotFound))
            completionHandler(kMFLicensingStateUnlicensed, error)
            return
        }
        
        /// Ask gumroad to verify
        Gumroad.checkLicense(key, email: email) { isValidKeyAndEmail, serverResponse, error, urlResponse in
            
            if isValidKeyAndEmail {
                
                /// Is licensed!
                completionHandler(kMFLicensingStateLicensed, nil)
                return
            }
            
            /// Gumroad veryfication failed
            
            if let error = error,
               error.domain == NSURLErrorDomain {
                
                /// Failed due to internet issues -> try cache
                
                if let cache = config("License.isLicensedCache") as? Bool {
                    
                    /// Fall back to cache
                    completionHandler(cache ? kMFLicensingStateCachedLicensed : kMFLicensingStateCachedUnlicended, nil)
                    return
                    
                } else {
                    
                    /// There's no cache
                    let error = NSError(domain: MFLicensingErrorDomain, code: Int(kMFLicensingErrorCodeNoInternetAndNoCache))
                    completionHandler(kMFLicensingStateUnlicensed, error)
                    return
                }
            } else {
                
                /// Failed despite good internet connection -> Is actually unlicensed
                completionHandler(kMFLicensingStateUnlicensed, error) /// Pass through the error from Gumroad.swift
                return
            }
        }
    }
}
