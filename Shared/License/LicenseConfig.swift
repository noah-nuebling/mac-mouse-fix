//
// --------------------------------------------------------------------------
// LicenseConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Notes:
/// - This class retrieves instances of the MFLicenseConfig dataclass

import Cocoa
import CocoaLumberjackSwift

@objc class LicenseConfig : NSObject {
    
    /// Constants
    
    static var licenseConfigAddress: String {
        "\(kMFWebsiteRepoAddressRaw)/\(kMFLicenseInfoURLSub)"
    }
    
    /// Async init
    
    @objc static func get() async -> (MFLicenseConfig) {
        
        /// Download MFLicenseConfig.json
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
            
            /// Convert jsonData to dict
            guard let dict = try (JSONSerialization.jsonObject(with: serverData, options: []) as? NSDictionary) else { /// Sidenote: We used to cast to `NSMutableDictionary` here but that fails unless using the`.mutableContainers` option. Don't understand Swift casting.
                throw NSError(
                    domain: MFLicenseConfigErrorDomain,
                    code: Int(kMFLicenseConfigErrorCodeInvalidDict),
                    userInfo: ["downloadedFrom": urlResponse.url ?? "<no url>",
                               "statusCode": (urlResponse as? HTTPURLResponse)?.statusCode ?? "<no status code>",
                               "serverResponse": String(data: serverData, encoding: .utf8) ?? "<not decodable as utf8 string>"]
                )
            }
            
            /// Instantiate
            let result = try MFLicenseConfig(jsonDictionary: NSMutableDictionary(dictionary: dict), freshness: kMFValueFreshnessFresh, requireSecureCoding: true)
            
            /// Update cache
            self.configCache = dict
            
            /// Return
            return result
            
        } catch let e {
            /// Log
            DDLogInfo("Failed to get MFLicenseConfig from internet, using cache instead...\nError: \(e)")
        }
        
        /// Downloading failed, use cache instead
        return getCached()
    }
    
    /// Cached init
    
    @objc static func getCached() -> MFLicenseConfig {
        
        /// Declare
        var instance: MFLicenseConfig? = nil
        
        /// Fill from cache

        do {
            if let cachedDict = self.configCache, cachedDict.count > 0 {
                instance = try MFLicenseConfig(jsonDictionary: NSMutableDictionary(dictionary: cachedDict), freshness: kMFValueFreshnessCached, requireSecureCoding: true)
            } else {
                throw NSError(domain: "MFPlaceholderErrorDomain", code: 123456789, userInfo: ["message": "Couldn't load dict from config. (Probably because there is no dict in config)"])
            }
        } catch {
            DDLogError("Falling back to hardcoded because filling MFLicenseConfig instance from cache failed with error:\n\(error). ")
        }
        
        /// Use fallback file if no cache
                
        if instance == nil {
            
            do {
                let url = Bundle.main.url(forResource: "fallback_licenseinfo_config", withExtension: "json")! /// Do forced cast here because we need some fallback. If this fails somethings totally wrong, so we should crash
                let data = try Data(contentsOf: url, options: [])
                let dict = try JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
                instance = try MFLicenseConfig(jsonDictionary: NSMutableDictionary(dictionary: dict), freshness: kMFValueFreshnessFallback, requireSecureCoding: true)
            } catch {
                fatalError("Loading licenseConfig from fallback failed (this should never happen). Error: \(error)")
            }
        }
        
        
        
        /// Return
        return instance! /// Force unwrap because it can't be nil since we always fill the variable with the fallback values at least
    }
    
    /// Static vars / convenience
    ///     Note: See `TrialCounter.swift` for notes on UserDefaults.
    
    fileprivate static var configCache: NSDictionary? {
        
        /// Cache for the JSON config file we download from the website
        ///     We could store this as JSON data, JSON plaintext or `encodeWithCoder:` data. But storing it as a dict makes the config.plist the most readable, which is nicer for debuggability.
        ///         Howeverrrr, when storing it as plaintext, that might make hacks really easy when we do offline validation, because you could just increase the trialDays to 999? Should keep this in mind and make sure super easy hacks aren't possible.
        
        set {
            
            DDLogDebug("Store config cache")
            
            guard let newValue = newValue else {
                assert(false)
                DDLogError("Setting the licenseConfigCache to nil is undefined and does nothing.")
            }
            
            setConfig("License.configCache", newValue as NSObject)
            commitConfig()
        }
        get {
            
            DDLogDebug("Retrieve config cache")
            
            let cached = config("License.configCache")
            let result = cached as? NSDictionary
            return result
        }
    }
}
