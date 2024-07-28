//
// --------------------------------------------------------------------------
// LicenseConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// This class abstracts away licensing params like the trialDuration or the price. At the time of writing it loads them all from a GitHub repo. This allows us to easily change parameters like the price displayed in the app for all users.

/// The altPayLink, altQuickPayLink, and altPayLinkCountries params are meant to be used to provide an alternative payment method for users in China and Russia where Gumroad doesn't work properly at the moment. They are unused at the time of writing. The freeCountries parameter lists countries in which the app should be free. This is meant as a temporary solution until we implemented the alternative payment methods.

import Cocoa

@objc class LicenseConfig: NSObject {
    
    /// Constants
    
    static var licenseConfigAddress: String {
        "\(kMFWebsiteRepoAddressRaw)/\(kMFLicenseInfoURLSub)"
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
                    let dict = try dictFromJSON(url)
                    try instance.fillFromDict(dict)
                    LicenseConfig.configCache = dict
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
            let dict = LicenseConfig.configCache
            try instance.fillFromDict(dict)
            instance.freshness = kMFValueFreshnessCached
        } catch {
            DDLogError("Failed to fill LicenseConfig instance from cache with error \(error). Falling back to hardcoded.")
        }
        
        /// Use fallback if no cache
                
        if !instance.isFilled {
            
            do {
                let url = Bundle.main.url(forResource: "fallback_licenseinfo_config", withExtension: "json")!
                let dict = try dictFromJSON(url)
                try instance.fillFromDict(dict)
                instance.freshness = kMFValueFreshnessFallback
            } catch {
                fatalError()
            }
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

    private static func dictFromJSON(_ jsonURL: URL) throws -> [String: Any] {
        
        /// Extract dict from json url
        
        var dict: [String: Any]? = nil
        let data = try Data(contentsOf: jsonURL)
        dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        if dict == nil {
            throw NSError(domain: "Lazydomain", code: 0, userInfo: ["Couldn't extract dict from json at url": jsonURL])
        }
        
        /// Return
        return dict!
    }
    
    private func fillFromDict(_ config: [String: Any]?) throws {
        
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
        
        self.maxActivations = maxActivations
        self.trialDays = trialDays
        self.price = price
        self.payLink = payLink
        self.quickPayLink = quickPayLink
        self.altPayLink = altPayLink
        self.altQuickPayLink = altQuickPayLink
        self.altPayLinkCountries = altPayLinkCountries
        self.freeCountries = freeCountries
        
        self.isFilled = true
    }
}
