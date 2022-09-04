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
/// At the time of writing it is an interface for TrialCounter.swift, which is not used by anything else except by the inputModules which report being used through the `handleUse()` function

/// There are some Swift __Active Compilation Conditions__ you can set in the build settings for testing:
/// - `FORCE_EXPIRED` Makes all the trial days be used up
/// - `FORCE_NOT_EXPIRED` Makes the trial days be __not__ used up
/// - `FORCE_LICENSED` Makes the app accept any license key. (This is implemented in Gumroad.swift)
///
/// Note: It seems you need to __clean the build folder__ after changing the flags for them to take effect. (Under Ventura Beta)

/// # __ Problems with the current architecture__ surrounding License.swift
/// Currently, when we want to get the licensing state, we always use two functions in tandem: LicenseConfig.get() and License.licenseState() (which takes the licenseConfig as input). Each of the 2 functions get their info asynchronously from some server and we need to call them both in a nested async call to get the full state. Both modules also provide "cached" versions of these functions whose perk is that they return synchronously, so we can use them, when we need to quickly draw a UI that the user has requested. The problem is, that we call the async functions in several different places in the app where we could be reusing information, and also we need to do some manual "hey update yourself since the licensing has changed" calls to keep everything in sync. This also leads us to just reload the about tab whenever it is opened which is kind of unnecessary, and it still breaks when you have the about tab open while the trial expires.
///
/// So here's a __better idea__ for the architecture:
///     There is a currentLicenseState var held by License.swift. It's a reactive signal provider, and all the UI that depends on it simply subscribes to it. We init the currentLicenseState to the cache. We update it on app start and when we know it changed due the trial expiring or the user activating their license or something. This should more efficient and much cleaner and should behave better in edge cases. But right now it's not worth implementing because it won't make much of a practical difference to the user.

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
                        
                        /// Only compile if helper (Otherwise there are linker errors)
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
#if FORCE_EXPIRED
        let daysOfUse = licenseConfig.trialDays + 1
#elseif FORCE_NOT_EXPIRED
        let daysOfUse = 0
#else
        let daysOfUse = TrialCounter.daysOfUse
#endif
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
#if FORCE_EXPIRED
            let daysOfUse = licenseConfig.trialDays + 1
#elseif FORCE_NOT_EXPIRED
            let daysOfUse = 0
#else
            let daysOfUse = TrialCounter.daysOfUse
#endif
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
