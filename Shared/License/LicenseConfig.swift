//
// --------------------------------------------------------------------------
// LicenseConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

/// This class abstracts away licensing params like the trialDuration or the price. At the time of writing it loads them all from a GitHub repo. This allows us to easily change parameters like the price displayed in the app for all users.

/// The altPayLink, altQuickPayLink, and altPayLinkCountries params are meant to be used to provide an alternative payment method for users in China and Russia where Gumroad doesn't work properly at the moment. They are unused at the time of writing. The freeCountries parameter lists countries in which the app should be free. This is meant as a temporary solution until we implemented the alternative payment methods.

import Cocoa
import CocoaLumberjackSwift

@objc class LicenseConfig: NSObject {
    
    /// Constants
    
    static var licenseConfigAddress: String {
        "\(kMFWebsiteRepoAddressRaw)/licenseinfo/config.json"
    }
    
    /// Async init
    
    @objc static func get(onComplete: @escaping (LicenseConfig) -> ()) {
        
        
        /// Create garbage instance
        
        let instance = LicenseConfig()
        
        /// Download licenseConfig.json
        
        let request = URLRequest(url: URL(string: licenseConfigAddress)!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10.0)
        
        let task = URLSession.shared.downloadTask(with: request) { url, urlResponse, error in
            
            /// Try to extract instance from downloaded data
            if let url = url {
                do {
                    try fillInstanceAndCacheFromJSON(instance, url)
                    instance.freshness = kMFValueFreshnessFresh
                    onComplete(instance)
                    return
                } catch { }
            }
            
            /// Log
            DDLogInfo("Failed to get LicenseConfig from internet, using cache instead...")
            
            /// Downloading failed, use cache instead
            onComplete(getCached())
        }
        
        task.resume()
    }
    
    /// Cached init
    
    @objc static func getCached() -> LicenseConfig {
        
        /// Get garbage
        
        let instance = LicenseConfig()
        
        /// Fill from cache

        do {
            try fillInstanceFromDict(instance, LicenseConfig.configCache)
            instance.freshness = kMFValueFreshnessCached
        } catch {
            DDLogError("Failed to fill LicenseConfig instance from cache with error \(error). Falling back to hardcoded.")
        }
        
        /// Fallback to hardcoded if no cache
        ///     Why not set these values in init? Should be safer and simpler.
        
        // TODO: Add altPaylink stuff here after we implement support for paddle or whatever
        
        if !instance.isFilled {
            instance.maxActivations = 25
            instance.trialDays = 30
            instance.price = 199
            instance.payLink = "https://noahnuebling.gumroad.com/l/mmfinapp"
            instance.quickPayLink = "https://noahnuebling.gumroad.com/l/mmfinapp?wanted=true"
            instance.altPayLink = ""
            instance.altQuickPayLink = ""
            instance.altPayLinkCountries = []
            instance.freeCountries = []
            
            instance.isFilled = true
            instance.freshness = kMFValueFreshnessFallback
        }
        
        /// Return
        return instance
    }
    
    /// Garbage Init
    
    override private init() {
        
        /// Don't use this directly! Use the static `get()` funcs instead
        /// Init to garbage
        maxActivations = -1
        trialDays = -1
        price = 99999999
        payLink = ""
        quickPayLink = ""
        altPayLink = ""
        altQuickPayLink = ""
        altPayLinkCountries = []
        freeCountries = []
        
        
        freshness = kMFValueFreshnessNone
        isFilled = false
    }
    
    /// Static vars / convenience
    ///     Note: See `TrialCounter.swift` for notes on UserDefaults.
    
    fileprivate static var configCache: [String: Any]? {
        
        /// Cache for the JSON config file we download from the website
        
        set {
            
            DDLogDebug("Store config cache")
            
            setConfig("License.configCache", newValue! as NSObject)
            commitConfig()
        }
        get {
            
            DDLogDebug("Retrieve config cache")
            
            return config("License.configCache") as? [String: Any]
        }
    }
    
    /// Equatability
    
    override func isEqual(to object: Any?) -> Bool {
        
        /// Notes:
        ///    - We don't check freshness and isFilled because it makes sense
        ///    - Overriding == directly doesn't work for some reason. Use isEqual to compare instead of == (unless == maps to isEqual anyways - not sure)
        
        let object = object as! LicenseConfig
        
        let result = self.maxActivations == object.maxActivations
                        && self.trialDays == object.trialDays
                        && self.price == object.price
                        && self.payLink == object.payLink
                        && self.quickPayLink == object.quickPayLink
                        && self.altPayLink == object.altPayLink
                        && self.altQuickPayLink == object.altQuickPayLink
                        && self.altPayLinkCountries == object.altPayLinkCountries
                        && self.freeCountries == object.freeCountries
                    
        return result
    }
    
    /// Base vars
    
    /// Define max activations
    ///     I want people to activate MMF on as many of their machines  as they'd like.
    ///     This is just so you can't just share one email address + license key combination on some forum and have everyone use that forever. This is probably totally unnecessary.
    @objc var maxActivations: Int
    @objc var trialDays: Int
    @objc var price: Int
    @objc var payLink: String
    @objc var quickPayLink: String
    @objc var altPayLink: String
    @objc var altQuickPayLink: String
    @objc var altPayLinkCountries: [String]
    @objc var freeCountries: [String]
    
    @objc var freshness: MFValueFreshness
    fileprivate var isFilled: Bool
    
    /// Derived vars
    
    @objc var formattedPrice: String {
        /// We're selling in $ because you can't include tax in price on Gumroad, and with $ ppl expect that more.
        "$\(Double(price)/100.0)"
    }
    
    /// Helper funcs

    private static func fillInstanceAndCacheFromJSON(_ instance: LicenseConfig, _ configURL: URL) throws {
        
        /// Extract dict from json url
        
        var config: [String: Any]? = nil
        let data = try Data(contentsOf: configURL)
        config = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        /// Fill instance from dict
        try fillInstanceFromDict(instance, config)
        
        /// Store dict in cache
        ///     If we successfully filled instance
        LicenseConfig.configCache = config
    }
    
    private static func fillInstanceFromDict(_ instance: LicenseConfig, _ config: [String: Any]?) throws {
        
        /// Get values from dict
        
        guard let maxActivations = config?["maxActivations"] as? Int,
              let trialDays = config?["trialDays"] as? Int,
              let price = config?["price"] as? Int,
              let payLink = config?["payLink"] as? String,
              let quickPayLink = config?["quickPayLink"] as? String,
              let altPayLink = config?["altPayLink"] as? String,
              let altQuickPayLink = config?["altQuickPayLink"] as? String,
              let altPayLinkCountries = config?["altPayLinkCountries"] as? [String],
              let freeCountries = config?["freeCountries"] as? [String]
        else {
            throw NSError(domain: MFLicenseConfigErrorDomain, code: Int(kMFLicenseConfigErrorCodeInvalidDict), userInfo: config)
        }
        
        /// Fill instance from dict values
        
        instance.maxActivations = maxActivations
        instance.trialDays = trialDays
        instance.price = price
        instance.payLink = payLink
        instance.quickPayLink = quickPayLink
        instance.altPayLink = altPayLink
        instance.altQuickPayLink = altQuickPayLink
        instance.altPayLinkCountries = altPayLinkCountries
        instance.freeCountries = freeCountries
        
        instance.isFilled = true
    }
}
