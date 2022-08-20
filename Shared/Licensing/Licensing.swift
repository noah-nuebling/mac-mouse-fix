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
            
            
            /// Return
            let result = MFLicensingReturn(state: state, currentDayOfTrial: -1, trialDays: -1)
            completionHandler(result, error)
        }
        
    }
    
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
