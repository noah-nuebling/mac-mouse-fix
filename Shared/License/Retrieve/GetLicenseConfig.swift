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
    
    @Atomic private static var inMemoryCache: MFLicenseConfig? = nil /// We should really be using a semaphore or mutex, but Swift async doesn't allow that (bc Swift is stinky). Using atomic should be ok. More on this below. (Oct 2024)
    private static func licenseConfigFromServer() async -> MFLicenseConfig? {
    
        /// Use in-memory cache
        ///     Explanation:
        ///         We wanna do offline validation. That means we want to avoid internet connections in our licensing code unless absolutely necessary.
        ///             We do this to protect user's privacy. Before, there was a potential for Gumroad, GitHub, or their infrastructure providers (like Microsoft Azure, or AWS) to possibly track MMF user's behavior due to the regular web-requests sent by Mac Mouse Fix.
        ///             See https://github.com/noah-nuebling/mac-mouse-fix/issues/976
        ///         There are two pieces of data that our licensing code retrieves where the source-of-truth is a server (Meaning we need to connect to the internet to get the real data):
        ///             Those two pieces of data are:`MFLicenseState` and `MFLicenseConfig`.
        ///         For the `MFLicenseState` we prevent internet connections by always asking the on-disk cache before asking the server, and that cache we validate using the licenseKey and an SHA-256 hash. That way we know that the data we get from the cache is pretty up-to-date and matches the stored licenseKey.
        ///         For the `MFLicenseConfig` we prevent internet connections by getting it only if needed. It's not needed at all on the code-path where the aforementioned offline validation succeeds and we end up using the `MFLicenseState` retrieved from the on-disk cache.
        ///             -> "Getting it only if needed" means that our code is structured so that any branch in our control-flow that needs the "MFLicenseConfig" gets it right in that branch instead of getting it from the parent scope/caller. However this means there are lots independent of branches of our control flow that request the MFLicenseConfig.
        ///             -> To prevent lots of back-to-back downloads of the MFLicenseConfig from the server from all those different control-flow branches, we do an `inMemoryCache` here. This makes it so that the `MFLicenseConfig` is only downloaded from the server *once* per app-start. All subsequent retrieveals of the MFLicenseConfig come from the `inMemoryCache` instead of the server.
        ///             -> Discussion:
        ///                 We couldn't do this kind of caching for the `MFLicenseState` since that might change while the app is running. E.g. when the user activates a new license, then the whole licenseState changes. I think the licenseState could even change under our feet if the user changes the license on another device, and then the licenseKey is synced to our device via iCloud.
        ///                 However, this in-memory cache should be totally acceptable for `MFLicenseConfig`, because we only expect the licenseConfig to change every couple of weeks at most, and I think it's never crucial for it to change while the app is running. It's still nice for it to have the chance to update every time the app is launched though. If we never update it, there might be problems in the long term. E.g. we might end up with a dead link when the user clicks on `Mac Mouse Fix > Buy Mac Mouse Fix...` if we ever move the checkout page.
        ///
        ///         What's the difference between the inMemoryCache and the normal cache?
        ///             The normal cache persists the licenseState on disk and is meant for when there is no way to reach the server, because the internet is down.
        ///             The inMemoryCache is deleted after the app is closed and is meant to prevent duplicate, back-to-back downloads of the licenseConfig from the server.
        ///
        ///         Thread safety of the `inMemoryCache`
        ///             (As of Oct 2024) Currently we're just making the `inMemoryCache` atomic to prevent some race conditions, but we still might download the licenseConfig multiple times in a row, if this function is called multiple times before the `inMemoryCache` is filled.
        ///                          This isn't catastrophic so we'll just leave it for now. To solve this race condition we'd ideally lock this whole function with a mutex or semaphore, but Swift doesn't seem to allow that in async contexts (bc it's stinky)
        ///                          The best way I know to solve this race condition would be using the Swift package `groue/Semaphore` which *would* let us use a semaphore in an async context.
        ///         Thread safety in general:
        ///             Aside from the `inMemoryCache`, the only other shared piece of state that `GetLicenseConfig.swift` deals with is `_licenseConfigDictCache` (that's the on-disk cache as opposed to the `inMemoryCache`). Its thread safety is discussed where it's declared.
        ///
        ///         Caveats:
        ///             If we ever accidentally retrieve the `MFLicenseConfig` on the 'golden path' where we successfully offline validate the `MFLicenseState`, then our offline validation wouldn't be entirely offline anymore.  To monitor this, we could observe the `"GetLicenseConfig inMemoryCache:..."` logs which are sent below.
        
        if let c = inMemoryCache {
            DDLogInfo("GetLicenseConfig inMemoryCache: Using inMemoryCache instead of retrieving the MFLicenseConfig from the server again.")
            return c
        }
        DDLogInfo("GetLicenseConfig inMemoryCache: Retrieving the MFLicenseConfig from the server...")
        
        /// Define constants
        ///     Note: Is it really the best choice to disable allll caching using the `NSURLRequest.CachePolicy`? I guess it might prevent errors and inconsistencies?
        let licenseConfigURL = URL(string: "\(kMFWebsiteRepoAddressRaw)/\(kMFLicenseInfoURLSub)")!
        let cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData
        let timeout = 10.0
        
        /// Perform request
        ///     Note: We used to use `URLSession.shared.download(...)` here but `URLSession.shared.data()` is better, since it returns the data directly instead of returning the url of a downloaded file. This should be more efficient. `.download` is more for large files and background downloads I think, not for a 2KB JSON file.
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
        
        /// Update caches
        self._licenseConfigDictCache = dict
        self.inMemoryCache = result
        
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
    
    /// Underlying on-disk cache
    
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