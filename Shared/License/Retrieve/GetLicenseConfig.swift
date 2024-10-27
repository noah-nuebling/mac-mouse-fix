//
// --------------------------------------------------------------------------
// GetLicenseConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import CocoaLumberjackSwift

@objc class GetLicenseConfig : NSObject {
    
    /// -> This class retrieves instances of the `MFLicenseConfig` dataclass
    
    /// Main interface
    @objc static func get() async -> MFLicenseConfig {
        
        let result = (await licenseConfigFromServer()) ?? licenseConfigCached() ?? licenseConfigFallback()
        return result
    }
    
    @objc static func getOffline() -> MFLicenseConfig {
    
        let result = licenseConfigCached() ?? licenseConfigFallback()
        return result
    }
    
    /// Server/cache/fallback interfaces
    
    private static func licenseConfigFromServer() async -> MFLicenseConfig? {
    
        /// Download MFLicenseConfig.json
        ///     Notes:
        ///     - We used to use `URLSession.shared.download(...)` here but `URLSession.shared.data()` is better, since it returns the data directly instead of returning the url of a downloaded file. This should be more efficient. `.download` is more for large files and background downloads I think, not for a 2KB JSON file.
        ///     - Is it really the best choice to disable allll caching? I guess it might prevent errors and inconsistencies?
        
        /// Define constants
        let licenseConfigURL = URL(string: "\(kMFWebsiteRepoAddressRaw)/\(kMFLicenseInfoURLSub)")!
        let cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData
        let timeout = 10.0
        
        /// Perform request
        let request = URLRequest(url: licenseConfigURL, cachePolicy: cachePolicy, timeoutInterval: timeout)
        let (requestResult, requestError) = await MFCatch { try await URLSession.shared.data(for: request) }
        guard let requestResult = requestResult else {
            DDLogInfo("Failed to get MFLicenseConfig from server. Request error: \(requestError ?? "<nil>")")
            return nil
        }
        let (serverData, urlResponse) = requestResult
        
        /// Convert jsonData to dict
        let (jsonObject, serializationError) = MFCatch { try JSONSerialization.jsonObject(with: serverData, options: []) }
        guard let dict = jsonObject as? NSDictionary else { /// Sidenote: We used to cast to `NSMutableDictionary` here but that fails unless using the`.mutableContainers` option. Don't understand Swift casting.
            DDLogInfo("Failed to get MFLicenseConfig from server. Serialization error: \(serializationError ?? "<nil>"). jsonObject: \(jsonObject ?? "<nil>"). URLResponse: \(urlResponse)")
            return nil
        }
        
        /// Instantiate
        let (result, instantiationError) = MFCatch { try MFLicenseConfig(jsonDictionary: NSMutableDictionary(dictionary: dict), freshness: kMFValueFreshnessFresh, requireSecureCoding: true) }
        guard let result = result else {
            DDLogInfo("Failed to get MFLicenseConfig from server. Instantiation error: \(instantiationError ?? "<nil>"). jsonDict: \(dict). URLResponse: \(urlResponse)")
            return nil
        }
        
        /// Update cache
        self._licenseConfigDictCache = dict
        
        /// Return
        return result
    }
    
    private static func licenseConfigCached() -> MFLicenseConfig? {
        
        /// Get underlying cache dict
        guard let cachedDict = self._licenseConfigDictCache, cachedDict.count > 0 else {
            DDLogInfo("Failed to get MFLicenseConfig dict from cache. (Probably because there is no cache entry or it's empty or it has the wrong type.)")
            return nil
        }
        
        /// Instantiate
        let (instance, error) = MFCatch { try MFLicenseConfig(jsonDictionary: NSMutableDictionary(dictionary: cachedDict), freshness: kMFValueFreshnessCached, requireSecureCoding: true) }
        guard let instance = instance else {
            DDLogInfo("Failed to get MFLicenseConfig from cache. Instantiating failed with error:\n\(error ?? "<nil>").")
            return nil
        }
        
        /// Return
        return instance
    }
    
    private static func licenseConfigFallback() -> MFLicenseConfig {
        
        do {
            let url = Bundle.main.url(forResource: "fallback_licenseinfo_config", withExtension: "json")! /// Do forced cast here because we need some fallback. If this fails somethings totally wrong, so we should crash
            let data = try Data(contentsOf: url, options: [])
            let dict = try JSONSerialization.jsonObject(with: data, options: []) as! NSDictionary
            let instance = try MFLicenseConfig(jsonDictionary: NSMutableDictionary(dictionary: dict), freshness: kMFValueFreshnessFallback, requireSecureCoding: true)
            return instance
        } catch {
            fatalError("Loading licenseConfig from fallback failed (this should never happen). Error:\n\(error)")
        }
    }
    
    /// Underlying cache
    
    private static var _licenseConfigDictCache: NSDictionary? {
        
        /// Cache for the JSON config file we download from the website
        ///     We could store this as JSON bits, JSON text or `encodeWithCoder:` bits. But storing it as a dict makes the config.plist the most readable, which is nicer for debuggability.
        ///         Howeverrrr, when storing it in a readable manner, that might make hacks really easy when we do offline validation, because you could just increase the trialDays to 999? Should keep this in mind and make sure it's not super easy to hack.
        
        /// On thread safety:
        ///     The config cache is shared mutable state, which might lead to a race condition!
        ///     I think if `config()` `setConfig()` and `commitConfig()` are threadsafe then this should be threadsafe as well?
        
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
