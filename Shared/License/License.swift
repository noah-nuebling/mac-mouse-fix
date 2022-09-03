//
// --------------------------------------------------------------------------
// License.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// This is a thin wrapper / collection of convenience functions around TrialCounter.swift and Gumroad.swift.
/// One of the more interesting things it does is It adds offline caching to Gumroad.swift and automatically gathers parameters for it.
/// It was meant to be an Interface for Gumroad.swift, so that Gumroad.swift wouldn't be used except by License.swift, but for the LicenseSheet it made sense to use Gumroad.swift directly, because we don't want any caching when activating the license.

import Cocoa

// MARK: - License.h extensions

extension MFLicenseReturn: Equatable {
    public static func == (lhs: MFLicenseReturn, rhs: MFLicenseReturn) -> Bool {
        /// Note:
        /// - We don't check for freshness because it makes sense.
        /// - We also don't check for trialIsOver directly, because it's derived from trialDays and daysOfUse
        lhs.state == rhs.state && lhs.daysOfUse == rhs.daysOfUse && lhs.trialDays == rhs.trialDays
    }
}

// MARK: - License definition

@objc class License: NSObject {
    
    // MARK: Interface
    
    @objc static func runCheckAndReact(licenseConfig: LicenseConfig, triggeredByUser: Bool) {
        /// This runs a check and then if necessary it:
        /// - ... shows some feedback about the licensing state to the user
        /// - ... locks down the helper
        
        
        /// Get licensing state
        
        licenseState(licenseConfig: licenseConfig) { license, error in
            
            if license.state == kMFLicenseStateLicensed {
                 
                /// Do nothing if licensed
                return
                
            } else {
                
                /// Not licensed -> check trial
                if license.trialIsActive.boolValue {
                    
                    /// Trial still active -> do nothing
                    ///     Note: Maybe display small reminder after half of trial is over?
                    
                } else {
                    
                    /// Trial has expired -> show UI
                    
                    if triggeredByUser {
                        
                        /// Display more complex UI
                        ///     This is unused so far
                        
                        /// Validate
                        assert(SharedUtility.runningMainApp())
                        
                        
                        
                    } else {
                        
                        /// Not triggered by user -> the users workflow is disruped -> make it as short as possible
                        
                        /// Validate
                        assert(SharedUtility.runningHelper())
                        
                        #if IS_HELPER
                        
                        /// Show trialNotification
                        DispatchQueue.main.async {
                            TrialNotificationController.shared.open(licenseConfig: licenseConfig, license: license, triggeredByUser: triggeredByUser)
                        }
                        
                        /// Lock helper
                        HelperState.lockDown()
                        
                        #endif
                        
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
        
        /// Get trial info
        let daysOfUse = TrialCounter.daysOfUse
        let trialDays = licenseConfig.trialDays
        let trialIsActive = daysOfUse <= trialDays
        let daysOfUseUI = SharedUtilitySwift.clip(daysOfUse, betweenLow: 1, high: trialDays)
        
        /// Return
        let result = MFLicenseReturn(state: state, freshness: kMFValueFreshnessCached, daysOfUse: Int32(daysOfUse), daysOfUseUI: Int32(daysOfUseUI), trialDays: Int32(trialDays), trialIsActive: ObjCBool(trialIsActive))
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
            
            /// Get trial info
            let daysOfUse = TrialCounter.daysOfUse
            let trialDays = licenseConfig.trialDays
            let trialIsActive = daysOfUse <= trialDays
            let daysOfUseUI = SharedUtilitySwift.clip(daysOfUse, betweenLow: 1, high: trialDays)
            
            /// Return
            let result = MFLicenseReturn(state: state, freshness: freshness, daysOfUse: Int32(daysOfUse), daysOfUseUI: Int32(daysOfUseUI), trialDays: Int32(trialDays), trialIsActive: ObjCBool(trialIsActive))
            completionHandler(result, error)
        }
        
    }
    
//    @objc static func activateLicense(license: String, licenseConfig: LicenseConfig, completionHandler: @escaping (_ success: Bool, _ error: NSError?) -> ()) {
//
//        Gumroad.activateLicense(license, email: "", maxActivations: licenseConfig.maxActivations) { isValidKey, serverResponse, error, urlResponse in
//
//            if isValidKey {
//                SecureStorage.set("License.key", value: license)
//            }
//
//            completionHandler(isValidKey, error)
//        }
//    }
//
//    @objc static func currentLicense() -> String? {
//        SecureStorage.get("License.key") as! String?
//    }
    
    // MARK: Core
    
    fileprivate static func checkLicense(licenseConfig: LicenseConfig, completionHandler: @escaping (MFLicenseState, MFValueFreshness, NSError?) -> ()) {
        
        /// Get email and license from config file
        
        guard
            let key = SecureStorage.get("License.key") as! String?
        else {
            
            /// Return unlicensed
            let error = NSError(domain: MFLicenseErrorDomain, code: Int(kMFLicenseErrorCodeKeyNotFound))
            completionHandler(kMFLicenseStateUnlicensed, kMFValueFreshnessFresh, error)
            return
        }
        
        /// Get maxActivations from licenseConfig
        
        let maxActivations = licenseConfig.maxActivations
        
        /// Ask gumroad to verify
        Gumroad.checkLicense(key, maxActivations: maxActivations) { isValidKey, serverResponse, error, urlResponse in
            
            if isValidKey {
                
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
