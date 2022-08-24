//
// --------------------------------------------------------------------------
// License.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

// MARK: - License.h extensions

extension MFLicenseReturn: Equatable {
    public static func == (lhs: MFLicenseReturn, rhs: MFLicenseReturn) -> Bool {
        /// Note: We don't check for freshness because it makes sense.
        lhs.state == rhs.state && lhs.daysOfUse == rhs.daysOfUse && lhs.trialDays == rhs.trialDays
    }
}

// MARK: - License definition

@objc class License: NSObject {
    
    // MARK: Interface
    
    @objc static func runCheckAndDisplayUI(licenseConfig: LicenseConfig, triggeredByUser: Bool) {
        
        /// Get licensing state
        
        licenseState(licenseConfig: licenseConfig) { license, error in
            
            if license.state == kMFLicenseStateLicensed {
                 
                /// Do nothing if licensed
                return
                
            } else {
                
                /// Not licensed -> check trial
                if license.daysOfUse <= license.trialDays {
                    
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
    
    @objc static func cachedLicenseState(licenseConfig: LicenseConfig) -> MFLicenseReturn {
        
        /// Get cache
        ///     Note: Here, we fall back to false and don't throw errors if there is no cache, but in `licenseState(licenseConfig:)` we do throw an error. Does this have a reason?
        let cache = config("License.isLicensedCache") as? Bool ?? false
        let state = cache ? kMFLicenseStateLicensed : kMFLicenseStateUnlicensed
        
        /// Return
        let result = MFLicenseReturn(state: state, freshness: kMFValueFreshnessCached, daysOfUse: Int32(Trial.daysOfUse), trialDays: Int32(licenseConfig.trialDays))
        return result
        
    }
    
    @objc static func licenseState(licenseConfig: LicenseConfig, completionHandler: @escaping (_ license: MFLicenseReturn, _ error: NSError?) -> ()) {
        
        /// At the time of writing, we only use licenseConfig to get the maxActivations.
        ///     Since we get licenseConfig via the internet this might be worth rethinking if it's necessary. We made a similar comment somewhere else but I forgot where.
        
        /// Check license
        checkLicense(licenseConfig: licenseConfig) { state, freshness, error in
            
            /// Write to cache
            ///     Might be cleaner to do this in `checkLicense`?
            if state == kMFLicenseStateLicensed {
                setConfig("License.isLicensedCache", true as NSObject)
                commitConfig()
            } else if state == kMFLicenseStateUnlicensed {
                setConfig("License.isLicensedCache", false as NSObject)
                commitConfig()
            }
                
            /// Return
            let result = MFLicenseReturn(state: state, freshness: freshness, daysOfUse: Int32(Trial.daysOfUse), trialDays: Int32(licenseConfig.trialDays))
            completionHandler(result, error)
        }
        
    }
    
    // MARK: Core
    
    fileprivate static func checkLicense(licenseConfig: LicenseConfig, completionHandler: @escaping (MFLicenseState, MFValueFreshness, NSError?) -> ()) {
        
        /// Get email and license from config file
        
        guard
            let key = config("License.key") as? String,
            let email = config("License.email") as? String
        else {
            
            /// Return unlicensed
            let error = NSError(domain: MFLicenseErrorDomain, code: Int(kMFLicenseErrorCodeEmailOrKeyNotFound))
            completionHandler(kMFLicenseStateUnlicensed, kMFValueFreshnessFresh, error)
            return
        }
        
        /// Get maxActivations from licenseConfig
        
        let maxActivations = licenseConfig.maxActivations
        
        /// Ask gumroad to verify
        Gumroad.checkLicense(key, email: email, maxActivations: maxActivations) { isValidKeyAndEmail, serverResponse, error, urlResponse in
            
            if isValidKeyAndEmail {
                
                /// Is licensed!
                completionHandler(kMFLicenseStateLicensed, kMFValueFreshnessFresh, nil)
                return
            }
            
            /// Gumroad veryfication failed
            
            if let error = error,
               error.domain == NSURLErrorDomain {
                
                /// Failed due to internet issues -> try cache
                
                if let cache = config("License.isLicensedCache") as? Bool {
                    
                    /// Fall back to cache
                    completionHandler(cache ? kMFLicenseStateLicensed : kMFLicenseStateUnlicensed, kMFValueFreshnessCached, nil)
                    return
                    
                } else {
                    
                    /// There's no cache
                    let error = NSError(domain: MFLicenseErrorDomain, code: Int(kMFLicenseErrorCodeNoInternetAndNoCache))
                    completionHandler(kMFLicenseStateUnlicensed, kMFValueFreshnessFallback, error)
                    return
                }
            } else {
                
                /// Failed despite good internet connection -> Is actually unlicensed
                completionHandler(kMFLicenseStateUnlicensed, kMFValueFreshnessFresh, error) /// Pass through the error from Gumroad.swift
                return
            }
        }
    }
}
