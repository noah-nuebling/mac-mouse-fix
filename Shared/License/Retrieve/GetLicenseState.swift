//
// --------------------------------------------------------------------------
// MFLicenseState.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import CocoaLumberjackSwift
import CryptoKit

@objc class GetLicenseState : NSObject {

    /// -> This class retrieves instances of the `MFLicenseState` dataclass
    
    static func get_Preliminary(_callingFunc: String = #function) -> MFLicenseState {
        
        /// This is a quick, preliminary way to get the licenseState, that's intended to render the UI immediately upon app-startup with probably-correct data.
        /// Note:
        ///     We set `enableOfflineValidation: false`when getting the cached licenseState so we don't have to retrieve the actual `licenseKey` and `deviceUID` here. I guess as an optimization? Or minimization of shared state to avoid race conditions? Not totally sure this makes sense.
        ///         This could lead to UI weirdness if we end up in a situation where the preliminary cache access always says the app .isLicensed but the subsequent validated cache access always says that  .isLicensed == false. We are trying to avoid this by deleting the cache after the offline validation fails. [Feb 2025]
        ///         To avoid such UI weirdness, the goal should be to keep the result of `get_Preliminary()` in sync with `get()` as much as feasible.
        
        let result = self.licenseStateFromCache(licenseKey: "", deviceUID: nil, enableOfflineValidation: false) ??
                     self.licenseStateFromFallback
        
        DDLogInfo("GetLicenseState.get_Preliminary(): \(result)\ncaller: \(_callingFunc)")
        
        return result
    }
    
    public static func get(_callingFunc: String = #function) async -> MFLicenseState {
        
        /// This function determines the current licenseState of the application.
        ///     To do this, it checks the `licenseServer`, `cache`, `fallback` values, and `special conditions`
        ///
        /// Discussion:
        ///     On offline validation:
        ///         This function supports offline validation! It will first try to retrieve the `MFLicenseState` from a cache - validating it against the licenseKey using a hash. Only if that fails will it make an internet connection to validate the license. (As of Oct 2024)
        ///         For a basic explanation of our offline-validation architecture, read `GetLicenseConfig.licenseConfigFromServer()`
    
        ///     On thread safety: [Oct 2024]
        ///         This function accesses the following shared state: 1. `SecureStorage` values 2. cached values (which are stored in `config.plist`).
        ///             > As long as `Config` and `SecureStorage` accesses are thread safe, I thinkk this function should be relatively thread-safe, too?  In that case, the only race-condition I can see is that we might unnecessarily hit the server multiple times if this function is called multiple times before the cache can be filled. But that wouldn't be catastrophic.
        ///          > Otherwise we might want to ensure that all this code is always running on the same thread/queue, (probably main thread would be fine) or if that's not possible - use locks. (Update: Locks can't be used in async contexts in Swift, but the Swift package `groue/Semaphore` - which we discussed elsewhere - might fix this.)
        ///          Update: [Feb 2025] We're now using @MainActor to run all the licensing code on the main thread. Why? – I think this might help prevent race conditions. However, while this code `await`s, the shared state could still change under us, so not sure how much it helps.
        
        var result: MFLicenseState?
        
        /// Check if the license key is valid
        
        checkLicenseKeyValidity: do {
            
            /// Get key
            ///     from secure storage
            
            guard let key = SecureStorage.get("License.key") as? String else {
                    
                /// No key found in secure storage
                
                /// Delete cache
                deleteLicenseStateFromCache(commitConfig: true) /// `<-` See docs in here for discussion.
                
                /// Return unlicensed
                ///     Note: Perhaps we should also do this if the licenseKey is an emptyString?
                result = MFLicenseState(isLicensed: false, freshness: kMFValueFreshnessFresh, licenseTypeInfo: MFLicenseTypeInfoNotLicensed())
                DDLogInfo("GetLicenseState: No license key was found in the secureStorage.\n(This is now just a log message. Would formerly return NSError with code kMFLicenseErrorCodeKeyNotFound)") /// This shouldn't be an error log as this is the normal case if the user hasn't entered a licenseKey e.g. during the trial period.
                break checkLicenseKeyValidity
            }
            
            /// 1. Ask cache
            let deviceUID = get_mac_address()
            if deviceUID == nil { DDLogWarn("GetLicenseState: Failed to get deviceUID for offline validation. (Offline validation should still work normally as long as we *always consistently* fail to retrieve the deviceUID on this device. (Because then we'll always consistently pass nil))") }
            result = self.licenseStateFromCache(licenseKey: key,
                                                deviceUID: deviceUID,
                                                enableOfflineValidation: true)
            
            if (result == nil) {
                
                /// 2. Ask server
                
                let licenseConfig = await GetLicenseConfig.get()
                
                var serverError: NSError?
                (result, serverError) = await licenseStateFromServer(key: key,
                                                                     incrementActivationCount: false, /// It's important that this is `false`! Otherwise we might accidentally increase the activationCount of the license more and more
                                                                     licenseConfig: licenseConfig)
            
                if let serverError = serverError {
                    DDLogInfo("GetLicenseState: LicenseServer API responded with error: \(serverError)")
                }
                
                if (result == nil) {
                
                    /// 3. Ask fallback
                
                    result = self.licenseStateFromFallback
                    DDLogInfo("GetLicenseState: Using hardcoded fallback: \(result ?? "<nil>")\n(This is now just a log message. Would formerly return NSError with code: kMFLicenseErrorCodeNoInternetAndNoCache")
                }
            
            }
            
        } /// end of checkLicenseKeyValidity
        
        /// Note: [Jan 2024] We could just update the cache right here instead of deleting cache in all these different places  (See deleteLicenseStateFromCache() docs)
        
        /// Unwrap
        guard var result = result
        else {
            fatalError("Something in our code is wrong. MFLicenseState is nil even though we should've assigned a hardcoded fallback value at the very least.")
        }
        
        /// Validate checkLicenseKeyValidity result
        assert(result.freshness != kMFValueFreshnessNone)
        if result.isLicensed { assert(!(result.licenseTypeInfo is MFLicenseTypeInfoNotLicensed)) }
        
        /// Implement special licenseTypes that don't require a valid license key
        ///     we also call these special licenseTypes "special conditions" or "overrides"
        if result.isLicensed == false {
            if let override = await licenseStateFromOverrides() {
                result = override
            }
        }
        
        /// Log
        DDLogInfo("GetLicenseState.get(): \(result)\ncaller: \(_callingFunc)")

        /// Return result
        return result
    }
    
    /// Server/cache/fallback/overrides interfaces
    
    public static func licenseStateFromOverrides() async -> MFLicenseState? {
        
        /// Old notes:
        ///     - (This note is totally outdated as of Oct 2024 ->) Instead of using a licenseReason, we could also pass that info through the error. That might be better since we'd have one less argument and the the errors can also contain dicts with custom info. Maybe you could think about the error as it's used currently as the "unlicensed reason" (Update: LicenseReason has been removed and merged into MFLicenseTypeInfo. Current system is nice. No need to merge everything into errors I think.)
        
        /// Implement `FORCE_LICENSED` flag
        ///     See License.swift comments for more info on compilation flags.
        
        #if FORCE_LICENSED
        return MFLicenseState(isLicensed: true, freshness: kMFValueFreshnessFresh, licenseTypeInfo: MFLicenseTypeInfoForce())
        #endif
        
        /// Implement freeCountries
        
        if let regionCode = LicenseUtility.currentRegionCode() { /// ChatGPT said currentRegionCode() might not be thread safe? I don't think we should worry about that, but not entirelyyy sure.
            let config = await GetLicenseConfig.get() /// This makes an internet connection - therefore we should probably check this 'override' after the others - to avoid any non-essential internet connections.
            let isFreeCountry = config.freeCountries.contains(regionCode)
            if isFreeCountry {
                return MFLicenseState(isLicensed: true, freshness: kMFValueFreshnessFresh, licenseTypeInfo: MFLicenseTypeInfoFreeCountry(regionCode: regionCode))
            }
        }
        
        /// Default case - no overrides
        return nil
    }
    
    private static let licenseStateFromFallback: MFLicenseState = MFLicenseState(isLicensed: false,
                                                                                 freshness: kMFValueFreshnessFallback,
                                                                                 licenseTypeInfo: MFLicenseTypeInfoNotLicensed())
    
    private static func getHashForOfflineCacheValidation(licenseState: Data, licenseKey: String, deviceUID: Data?) -> Data {
            
            /// Our offline validation mechanism for the `MFLicenseState` - which relies on this hashing function - ensures data-integrity and prevents easy tampering by users. All without making an internet connection.
            ///     Input values:
            ///     `licenseStateData`:
            ///         - Example when this is useful: This validation would render the cache invalid, if the user simply sets `licenseState.isLicensed == true` in the cached `MFLicenseState` - This prevents users from hacking the app into being licensed too easily
            ///     `licenseKey`:
            ///         - Example when this is useful: If the user changes their `licenseKey` on one device, it will get synced to their other devices via iCloud. But the cache is not synchronized. However, due to this cache validation, the cache will then become invalid, prompting the app to re-download the `MFLicenseState` from the server instead of continuing to use the old, stale `MFLicenseState` - This ensures data integrity.
            ///     `deviceUID`
            ///         - Example when this is useful: Even if a user shares their licenseKey alongside their config.plist (which contains the MFLicenseState cache as of now - Oct 2024) other users won't be able to activate the app by simply copying that data to their device, because the `deviceUID` is part of the hashed data.
            ///             -> On second thought I think this is pretty unnecessary. I don't think many users would do this. And I mean they could still just share the licenseKey without the config.plist and just activate it multiple times. But I guess this extra check doesn't hurt.
            ///         - Note: If, on some device, our method for retrieving a deviceUID fails, nil should be passed in here. As long as getting the `deviceUID` *always consistently* fails on a given device and we always pass in nil, then the offline validation should still work fine. The deviceUID is really not essential for the offline validation. Which hints that we might wanna think about removing it.
            ///
            /// Possible simplification / optimization:
            ///     Using `[NSObject -hash]`
            ///         This wouldn't work. E.g. an NSDictionary's `-hash` is just the number of keys it has. The hash does not depend on the dicts' contents.
            ///             iirc this is by design as the `-hash` should never change while an object is in a collection, so it's better to make the hash independent of the object's content, so that the content can be modified while the object is in a collection without changing the hash.
            ///             Also the default implementation of `-hash` uses the object's storage address iirc, and that wouldn't be stable across app launches, which is crucial here.
            ///     Combine hashes simply using the `^` bitwise operator?
            ///         This would probably work. We don't need the hashes to be cryptographically secure at all.
            
            var hashFunction = SHA256.init() /// SHA256 is totally overkill we just need someee simple hash to prevent tampering and ensure data integrity. It doesn't need to be cryptographically secure at all.
            hashFunction.update(data: licenseState)
            hashFunction.update(data: licenseKey.data(using: .utf8) ?? Data())
            hashFunction.update(data: deviceUID ?? Data())
            let hashDigest = hashFunction.finalize()
            let hashData = Data(hashDigest)
            
            return hashData
    }
    
    private static func deleteLicenseStateFromCache(commitConfig doCommitConfig: Bool) {
        
        /// We create an abstraction for this so we can easily regex for it
        ///
        /// Discussion: When to update the cache?  `[Jan 2025]`
        ///     Currently [Jan 2024] The licenseStateCache is intended as an offline substitute for the data that the server would send us about a license.
        ///         > We need it when 1. the licenseServer isn't accessible, 2. We we wanna do offline validation in order to minimize internet connections and enhance privacy.
        ///     Therefore we wanna update the cache:
        ///         1. When the server responds with a clear YES/NO to the question "is this license valid?"
        ///         2. When "is this license valid?" is determined during *preprocessing* of the data that we *wouid* send to the server. (E.g. if there is no licenseKey, we immediately know that the license isn't valid, and we don't ping the server.)
        ///         3. When offline validation fails - and therefore we know the cache has become invalid.
        ///         -> I think these are the only places where we get __ground truth__ data about the licenseState, and therefore, updating here should be enough to maintain the cache's integrity.
        ///
        ///     What is the practical problem if we don't delete the cache?
        ///         1. If `get()` fails, and we don't update the cache, then subsequent `get_Preliminary()` calls will keep returning that the app isLicensed. This results in the UI loading in a 'licensed' state and then immediately flashing to the 'unlicensed' state. That's janky.
        ///         2. Deleting cache after offline validation fails should make subsequent cache accesses a bit faster.
        ///         - Discussion: Alternatively we could also just validate *all* cache accesses (even the `get_Preliminary()` ones) to achieve consistent behavior.
        ///             - At least that would work as a replacement of the deleteLicenseStateFromCache() call upon offline validation failure
        ///             - Validating all cache accesses might also be better because then we don't gotta modify the config all over the place, which might produce race conditions?
        ///
        ///     - Architecture considerations: [Jan 2024]
        ///         We used to simply update the cache at the end of `get()` instead of 3 different places.
        ///         Should we go back to get()f?
        ///             Contra: New approach is more 'efficient' since we granularily decide what to cache, and therefore don't cache values that were just retrieved from the cache/fallback.
        ///                 Update: But couldn't we just check the licenseFreshness to get the same 'efficiency'/behavior? I guess if we considered a failed offline validation or missing LicenseKey as a 'fresh' value, then we could simply update the cache in case the licenseState `isFresh`. However, currently, the 'freshness' describes the origin of the data (server, cache, fallback). So we'd have to decouple these concepts somehow, I think? Or just override caches unless we just got a cached value – that might also work?
        ///             Contra: Granularity and explicitness helps us think about the different codepaths.
        ///             Pro: Does that 'effiency' matter? – Probably notj.
        ///             Pro: Much simpler code logic – All cache updates happen in get(). Cache just reflects latest value returned from get().
        ///             Pro: No risk to forget some place where we should update the cache to ensure integrity.
        ///             Steelmanning also caching override-MFLicenseStates:
        ///                 Caching override-MFLicenseStates like freeCountry might be sort of useful for extra robustness. E.g. if the app is licensed under a freeCountry license where that free country isn't included in the hardcoded fallback, and then the internet and the licenseConfig cache goes away, then the user can't use the app anymore. Whereas when we cache the override-MFLicenseStates, then that would serve as an extra failsafe making the app usable even if those other two things go away (I think at least - not entirely sure. Haven't thought this through.)
    
        removeFromConfig("License.licenseStateCache")
        removeFromConfig("License.licenseStateCacheHash")
        
        if doCommitConfig { commitConfig() }
    }
    
    private static func storeLicenseStateInCache(_ newValue: MFLicenseState, licenseKey: String, deviceUID: Data?) {
    
            /// Which fields of MFLicenseState to cache?
            ///     We're caching all the fields of the `MFLicenseState`. It's an offline substitute for the data we would receive from a license server.
            ///         It's unnecessary to cache the `MFLicenseState.freshness` value since that indicates the orgin of the data - server, cache, or fallback - and isn't really "part of the data" itself.
            ///         However, removing the value before caching requires extra lines of code, and doesn't have practical benefit, so we don't bother.
            
            #if false  /// Old approach – Archive into an xml string using MFEncode
                /// Archive the object
                ///     The archive is an xml string, (instead of the default: binary data) for bit better debuggability and perhaps being less ominous/intransparent for the users.
                let xmlData = MFEncode(newValue, requireSecureCoding: true, plistFormat: .xml) as Data?
                guard let xmlData = xmlData,
                      let xmlString = NSString(data: xmlData, encoding: NSUTF8StringEncoding)
                else {
                    DDLogError("GetLicenseState: MFLicenseState xmlString for caching came out as nil. Don't think this should ever happen.")
                    assert(false)
                    return
                }
            #endif
            
            /// Validate
            if !newValue.isLicensed { assert(false, "Use deleteLicenseStateFromCache() to set the cache to !isLicensed – So we can understand the control flow better.") }
            
            /// Convert MFDataClass object to plist dict
            let dict = newValue.asPlist(withRequireSecureCoding: true)
            
            /// Calculate hash
            ///     Note: [Jan 2025] Need to use `.xml` instead of `.binary`. to make the data (and with it the hash) deterministic. Not sure why. We might be relying on an implementation detail here.
            let (dictData, error) = MFCatch { try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0) }
            guard let dictData else {
                DDLogError("GetLicenseState: Caching: plist serialization of licenseState dict archive failed with error: \(error ?? "<nil>"). (Don't think this should ever happen.)")
                assert(false);
                return
            }
            let hash = self.getHashForOfflineCacheValidation(licenseState: dictData, licenseKey: licenseKey, deviceUID: deviceUID)
            
            /// Store data
            setConfig("License.licenseStateCache",      dict as NSDictionary)
            setConfig("License.licenseStateCacheHash",  hash as NSData)
            commitConfig()
    }
    
    private static func licenseStateFromCache(licenseKey: String, deviceUID: Data?, enableOfflineValidation: Bool) -> MFLicenseState? {
            
            /// Note: If the argument `enableOfflineValidation` is set to `false`, then all the other arguments are ignored - they only exist for the offlineValidation
            
            /// Get cached MFLicenseState archive
            guard let cachedDict = config("License.licenseStateCache") as? NSDictionary
            else {
                DDLogDebug("GetLicenseState: MFLicenseState dict could not be extracted from cache") /// Don't make this an error log because this is pretty expected if we simply haven't cached anything, yet
                return nil
            }
            
            if enableOfflineValidation {
                
                var success = true
                
                offlineValidation: do {
                   
                    /// Get cached hash
                    guard let cachedHash = config("License.licenseStateCacheHash") as? Data else {
                        DDLogDebug("GetLicenseState: Offline validation failed: licenseState hash not found in cache")
                        success = false
                        break offlineValidation
                    }
                
                    /// Calculate fresh hash
                    ///     for cached licenseState
                    let (dictData, error) = MFCatch { try PropertyListSerialization.data(fromPropertyList: cachedDict, format: .xml, options: 0) }
                    guard let dictData else {
                        DDLogError("GetLicenseState: Offline validation failed: plist serialization of dict archive failed. Error: \(error ?? "<nil>")")
                        success = false
                        break offlineValidation
                    }
                    let hash = self.getHashForOfflineCacheValidation(licenseState: dictData, licenseKey: licenseKey, deviceUID: deviceUID)
                    
                    /// Compare hashes
                    ///     If this fails, then at least one of the hashing input-values (licenseState, licenseKey and deviceUID) has changed since the cache was stored. (Or the cachedHash itself changed.)
                    if (hash != cachedHash) {
                        DDLogError("GetLicenseState: Offline validation failed: The hashes don't match.\nCached hash: \(cachedHash)\nFresh hash:  \(hash)")
                        success = false
                        break offlineValidation
                    }
                    
                    /// Success!
                    DDLogInfo("GetLicenseState: Offline validation succeeded.\nCached hash: \(cachedHash)\nFresh hash:  \(hash)")
                    
                } /// end of `offlineValidation:`
                
                if !success { /// Offline validation failed
                    
                    /// Delete cache
                    ///     (Because we know it's invalid)
                    deleteLicenseStateFromCache(commitConfig: true) /// `<-` Also see the discussion in here
                    
                    /// Return
                    return nil
                }
            }
            
            /// Unarchive
            ///     Note: (Nov 2024) Note that requireSecureCoding is turned on here.
            ///         -> This is somewhat slower and pretty unnecessary here I think since hackers would have to tamper with the (locally stored) cache to perform an 'object substitution' or 'nil insertion' attack. (Which are what secureCoding on MFDataClass protects against) And if they can modify local files, they already have full control over the system.)
            ///         -> I guess another possible benefit of the nil/type checks is if we change MFLicenseState in the future and we forget to handle that explicitly, then we would just return nil here in some cases instead of returning an invalid object that might crash the app because of unexpected type/nullability
            ///             ... But we should just introduce versioning to handle this properly. More on this in MFCoding.m > "On validation of decoded values"
            guard
                let cachedDict = cachedDict as? [String: NSObject], /// ([Feb 2025] We're first casting to NSDictionary and then to [String: NSObject], which is then Swift auto-bridged back to NSDictionary. Does that make sense?)
                let licenseState = MFLicenseState(plist: cachedDict, requireSecureCoding: true)
            else {
                DDLogError("GetLicenseState: Initializing MFLicenseState using cached dict failed.")
                return nil
            }
            
            /// Override freshness
            let result = MFLicenseState(isLicensed: licenseState.isLicensed,
                                        freshness: kMFValueFreshnessCached,     /// Note that we use all values from cache except for freshness
                                        licenseTypeInfo: licenseState.licenseTypeInfo)

            /// Return
            return result
    }

    public static func licenseStateFromServer(key: String, incrementActivationCount: Bool, licenseConfig: MFLicenseConfig) async -> (licenseState: MFLicenseState?, error: NSError?) {
    
        /// This function tries to retrieve the MFLicenseState from the known licenseServers.
        ///     If we don't receive clear information from any of the licenseServers about whether the license is valid or not, we return `nil`
        ///
        /// Test Licenses:
        ///     (Please don't use these test licenses. If you need a free one, just reach out to me! (However, sometimes I don't answer for a long time...) (You could also hack the source code now that you're already here, maybe take a look at the compilation flags) Thank you :))
        ///
        /// **Gumroad $**
        /// `E3309D7A-7270486C-BA426A87-813EB7B4`
        ///
        /// **Gumroad € (old)**
        /// ``
        ///
        /// **Gumroad $ Disabled**
        /// `0C720579-4ED54F18-ABE90A69-15DA6190`
        ///
        /// **Gumroad € (old) with suspicious activation count**
        /// `535BD2E5-8CF54E9A-8AD642E5-B5934AF8`
        ///
        /// **AWS**
        /// ...
        ///
        /// **AWS Hyperwork**
        /// ...
        
        /// Make sure we're only incrementing activation count from the main app
        ///     It's really bad if we accidentally increase it during normal use.
        if !runningMainApp() &&
            incrementActivationCount
        {
            fatalError();
        }
        
        enum LicenseValidityFromServer {
            case valid   ///  The server said that the license is valid
            case invalid ///  The server said that the license is invalid
            case unsure  ///  The server didn't say whether the license is valid or not.
        }
        
        var parsedServerResponse: (isValidKey: LicenseValidityFromServer, licenseTypeInfo: MFLicenseTypeInfo?, nOfActivations: Int?, error: NSError?)
        
        askServer: do {
            
            /// Ask the Gumroad license verification server
            
            /// Constants
            /// Notes:
            /// - `mmfinapp` was used during the MMF 3 Beta. It was using € which you can't change, so we had to create a new product in Gumroad `mmfinappusd`
            
            let gumroadAPIURL = "https://api.gumroad.com/v2"
            let productPermalinkOld = "mmfinapp"
            let productPermalink = "mmfinappusd"
            
            /// Talk to Gumroad
            var (serverResponseDict, communicationError, urlResponse) = await sendDictionaryBasedAPIRequest(requestURL: gumroadAPIURL.appending("/licenses/verify"),
                                                                                   args: ["product_permalink": productPermalink,
                                                                                          "license_key": key,
                                                                                          "increment_uses_count": incrementActivationCount ? "true" : "false"])
            /// Fallback to old euro product
            var usedOldEuroProduct = false
            if let message = serverResponseDict?["message"] as? NSString,
               message == "That license does not exist for the provided product." {
               
                /// Update flag
                usedOldEuroProduct = true
               
                /// Validate
                assert((serverResponseDict?["success"] as? Bool) == false)
                assert((urlResponse as? HTTPURLResponse)?.statusCode == 404)
                
                /// If license doesn't exist for new product, try old product
                (serverResponseDict, communicationError, urlResponse) = await sendDictionaryBasedAPIRequest(requestURL: gumroadAPIURL.appending("/licenses/verify"),
                                                                                   args: ["product_permalink": productPermalinkOld,
                                                                                          "license_key": key,
                                                                                          "increment_uses_count": incrementActivationCount ? "true" : "false"])
                
            }
            
            /// Guard:  Error
            ///     with the server communication
            if communicationError != nil {
                parsedServerResponse = (.unsure, nil, nil, communicationError)
                break askServer
            }
            
            /// Unwrap serverResponseDict
            guard let serverResponseDict = serverResponseDict else {
                fatalError("The serverResponseDict was nil even though the error was also nil. There's something wrong in our code.")
            }
            
            ///
            /// Parse server response
            ///
            
            /// Determine licenseType
            let licenseTypeInfo: MFLicenseTypeInfo = usedOldEuroProduct ? MFLicenseTypeInfoGumroadV0() : MFLicenseTypeInfoGumroadV1()
            
            /// Map server responses to error
            ///     The communication with the server was successful but the servers response indicates that something went wrong.
            var responseError: NSError? = nil
            if (serverResponseDict["success"] as? Bool) != true { /// We expect the Gumroad response to have a boolean field called "success" which tells us whether the license was successfully validated or something went wrong.
                responseError = NSError(domain: MFLicenseErrorDomain,
                                code: Int(kMFLicenseErrorCodeGumroadServerResponseError),
                                userInfo: serverResponseDict)
            }
            
            /// Determine if _server_ said whether the _key_ is valid
            ///     Explanation: The Gumroad license-verification API just gives us a boolean 'success' field. As I understand, `success: true` always means that the license is *definitively* valid.
            ///         However, `success: false` could mean different things. For example, as I understand `success` could be `false` in case we send them wrong parameters (the documentation suggests this) or in case there's an internal server error on Gumroads part (this is my speculation).
            ///         That's why, we check for status code `404` - it seems to be how the server tells us that the license in question is *definitively* invalid. I tested this, (In Oct 2024) and it returns status 404 in case of an unknown license *and* in case of a disabled license. And from what I can think of, those are all the possible ways that a license can be *definitely* invalid.
            ///             Sidenotes:
            ///             - The 404 code doesn't really semantically make sense to signify a disabled license - it normally stands for 'Not Found') - but that's how the Gumroad API seems to work.
            ///             - Actually, even the 404 code mighttt lead to false positives. To be even more granular, we could check for the specific messages that we know the servers sends when a license is unknown or disabled:
            ///                 - For *unknown* licenses the server sends the message: "That license does not exist for the provided product."
            ///                 - For *disabled* licensed, the server sends the message: "This license key has been disabled."
            ///                 ... But I won't change that now cause I'm too lazy to think this through and I think 404 will also work.
            ///             Update: The Gumroad docs say "You will receive a 404 response code with an error message if verification fails." - so checking 404 seems to be the way (Src: https://help.gumroad.com/article/76-license-keys.html)
            ///     Considerations:
            ///         Generally, we want to err on the side of `LicenseValidityFromServer.unsure`, and only use `LicenseValidityFromServer.invalid` when we're *absolutely* sure that the license is invalid.
            ///         That's because if we set the value to`.invalid` we consider the app *definitively*unlicensed and then lock it down immediately (in case the free days have been used up), which makes for a really annoying user experience if there's a false positive on `.invalid` due to an internal server error or something.
            ///         If instead, we have a false positive on `.unsure` then we just fall back to the cached value for whether the app is licensed or not, which should make for a much less disruptive user experience.
            ///         Actually, as I'm working on this, (Oct 9 2024) I got a [GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues/1136) from a user saying they regularly have their app locked down and they have to re-enter their license. (I think I also saw reports like this before.) Hopefully that stuff is fixed now.
            
            let serverSuccess: Bool? = serverResponseDict["success"] as? Bool
            var isValidKey: LicenseValidityFromServer
            if      (serverSuccess == true)     { isValidKey = .valid }
            else if (serverSuccess == nil)      { isValidKey = .unsure }
            else if (serverSuccess == false) {
                if (urlResponse as? HTTPURLResponse)?.statusCode == 404 { isValidKey = .invalid }
                else                                                    { isValidKey = .unsure }
            } else                              { fatalError("This cannot happen") }
            
            /// Gather nOfActivations from serverResponseDict
            let activations = serverResponseDict["uses"] as? Int
            
            /// Return parsed values
            parsedServerResponse = (isValidKey, licenseTypeInfo, activations, responseError)
            break askServer
        
        } /// End of askServer
        
        /// 'Post-processing' on the parsedServerResponse: Validate activation count
        if parsedServerResponse.isValidKey == .valid {
            let isSuspiciousActivationCount = (parsedServerResponse.nOfActivations ?? Int.max) > licenseConfig.maxActivations
            if isSuspiciousActivationCount {
                parsedServerResponse.error = NSError(domain: MFLicenseErrorDomain, code: Int(kMFLicenseErrorCodeInvalidNumberOfActivations), userInfo: ["nOfActivations": parsedServerResponse.nOfActivations ?? -1, "maxActivations": licenseConfig.maxActivations])
                parsedServerResponse.isValidKey = .invalid
            }
        }
        
        /// Assemble result
        let resultError = parsedServerResponse.error
        let result: MFLicenseState?
        switch parsedServerResponse.isValidKey {
        case .unsure:
            result = nil
        case .invalid:
            result = MFLicenseState(isLicensed: false, freshness: kMFValueFreshnessFresh, licenseTypeInfo: MFLicenseTypeInfoNotLicensed())
        case .valid:
            guard let licenseTypeInfo = parsedServerResponse.licenseTypeInfo else {
                fatalError("Something in our code is wrong. We determined the licenseKey to be valid but licenseTypeInfo is nil.")
            }
            result = MFLicenseState(isLicensed: true, freshness: kMFValueFreshnessFresh, licenseTypeInfo: licenseTypeInfo)
        }
        
        /// Update cache
        ///     See discussion in deleteLicenseStateFromCache()
        
        if      result?.isLicensed == nil {
            /// Don't update the cache if the server didn't give a clear yes/no about whether the license is valid.
        }
        else if result?.isLicensed == false {
            self.deleteLicenseStateFromCache(commitConfig: true)
        }
        else if result?.isLicensed == true {
            let deviceUID = get_mac_address() /// To understand this, also see the other place where we call `get_mac_address()` in this file [Feb 2025]
            if deviceUID == nil { DDLogWarn("GetLicenseState: Want to cache licenseState from the server, but getting device MAC address failed.") } /// Why are we logging this instead of returning an error? The returned errors are specifically to display feedback to the user on the LicenseSheet about the server's assessment of the licenseKey. Aside from this UI feedback, I think returning errors is overkill.
            self.storeLicenseStateInCache(result!, licenseKey: key, deviceUID: deviceUID)
        }
        else { fatalError() }
        
        /// Return
        return (result, resultError)
    }
}
