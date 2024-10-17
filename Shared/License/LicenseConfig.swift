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
import CocoaLumberjackSwift

@objc class LicenseConfig: NSObject {
    
    /// Constants
    
    static var licenseConfigAddress: String {
        "\(kMFWebsiteRepoAddressRaw)/\(kMFLicenseInfoURLSub)"
    }
    
    /// Async init
    
    @objc static func get() async -> (LicenseConfig) {
        
        /// Download licenseConfig.json
        ///     Notes:
        ///     - We used to use `URLSession.shared.download(...)` here but `URLSession.shared.data()` is better, since it returns the data directly instead of returning the url of a downloaded file. This should be more efficient. `.download` is more for large files and background downloads I think, not for a 2KB JSON file.
        ///     - Is it really the best choice to disable allll caching? I guess it might prevent errors and inconsistencies?
        
        /// Define constants
        let cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData
        let timeout = 10.0
        
        do {
            
            /// Perform request
            let request = URLRequest(url: URL(string: licenseConfigAddress)!, cachePolicy: cachePolicy, timeoutInterval: timeout)
            let (serverData, urlResponse) = try await URLSession.shared.data(for: request)
            
            /// Parse result as JSON
            let dict = try JSONSerialization.jsonObject(with: serverData, options: [])
            guard let dict = dict as? [String: Any] else {
                throw NSError(
                    domain: MFLicenseConfigErrorDomain,
                    code: Int(kMFLicenseConfigErrorCodeInvalidDict),
                    userInfo: ["downloadedFrom": urlResponse.url ?? "<no url>", "serverResponse": String(data: serverData, encoding: .utf8) ?? "<not decodable as utf8 string>"]
                )
            }
            
            /// Try to extract instance from JSON 
            let instance = LicenseConfig()
            try instance.fillFromDict(dict)
            instance.freshness = kMFValueFreshnessFresh
            
            /// Update cache
            LicenseConfig.configCache = dict
            
            /// Return
            return instance
            
        } catch let e {
            /// Log
            DDLogInfo("Failed to get LicenseConfig from internet, using cache instead...\nError: \(e)")
        }
        
        /// Downloading failed, use cache instead
        return getCached()
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
        
        /// Use fallback file if no cache
                
        if !instance.isFilled {
            
            do {
                let url = Bundle.main.url(forResource: "fallback_licenseinfo_config", withExtension: "json")!
                let dict = try dictFromJSONFile(url)
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
    func propertyValuesForEqualityComparison() -> [any Hashable & Equatable] {
        
        ///    This function defines which properties we consider for equality-checking. Both the `isEqual()` and the `hash` methods are defined in terms of this.
        ///         This pattern is copied from the `MFDataClass` implementation. (Perhaps we should turn this into an MFDataClass?)
        ///
        ///     Notes:
        ///    - We don't check `freshness` because it describes the origin of the data (cache, server, etc) and, in a sense, isn't itself part of the data we're trying to represent.
        ///    - We don't check for `isFilled` because its an internal variable we use to manage when to use fallback or cache values, it's not part of the actual data we're trying to represent.
        ///    - All other properties should be checked - don't forget to update this when adding new properties!
    
        return [self.maxActivations,
                self.trialDays,
                self.price,
                self.payLink,
                self.quickPayLink,
                self.altPayLink,
                self.altQuickPayLink,
                self.altPayLinkCountries,
                self.freeCountries]
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        
        ///    - We override `isEqual()`.
        ///         In Swift we can still use `==` as it maps to `isEqual()` for `NSObject` subclasses.
        ///         Sidenotes:
        ///         - I also tried overriding `==` directly, but it didn't work for some reason.
        ///         - I accidentally overrode isEqual(to:) instead of isEqual() causing great confusion (it breaks the `==` operator in Swift.)
            
        /// Helper function
        ///     (ridiculous Swift hacks bc Swift stinky)
        func genericIsEqual<A: Equatable>(_ lhs: A, _ rhs: Any) -> Bool {
            return lhs == (rhs as? A)
        }
        
        /// Trivial cases
        guard let other = object as? LicenseConfig else { assert(false); return false }
        if self === other { return true } /// Check pointer-equality
        
        /// Get values to compare
        let selfList = self.propertyValuesForEqualityComparison()
        let otherList = other.propertyValuesForEqualityComparison()
        
        /// Check equality
        if selfList.count != otherList.count { assert(false); return false }
        for (v1, v2) in zip(selfList, otherList) {
            if !genericIsEqual(v1, v2) { return false }
        }
        
        /// Passed all tests!
        return true
    }
    
    override var hash: Int {
        var result: Int = 0
        for v in self.propertyValuesForEqualityComparison() {
            result ^= v.hashValue
        }
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

    private static func dictFromJSONFile(_ jsonURL: URL) throws -> [String: Any] {
        
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
