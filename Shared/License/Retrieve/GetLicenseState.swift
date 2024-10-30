//
// --------------------------------------------------------------------------
// MFLicenseState.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import CocoaLumberjackSwift

@objc class GetLicenseState : NSObject {

    /// -> This class retrieves instances of the `MFLicenseConfig` dataclass
    
    static func checkLicenseOffline() -> MFLicenseState {
        let result = self.licenseStateFromCache() ?? self.licenseStateFromFallback
        return result
    }
    
    public static func checkLicense() async -> MFLicenseState {
        
        /// This function determines the current licenseState of the application.
        ///     To do this, it checks the `licenseServer`, `cache`, `fallback` values, and `special conditions`
        ///
        /// Discussion:
        ///     On offline validation:
        ///         For a basic explanation of our offline-validation plan, read `GetLicenseConfig.licenseConfigFromServer()`
        ///         This function will try to avoid internet connections if possible to enable totally offline operation of the app under standard conditions.
        ///             - For the return value (`MFLicenseState`): this function will look at the `cache` first, (using SHA-256 hashing for validation) and only if that fails will it ask the `licenseServer` and then the other sources.
        ///             - As discussed elsewhere, throughout the app, we only retrieve the `MFLicenseConfig` if necessary to minimize internet connections. In this function, if the offline retrieval & validation of the `MFLicenseStates` succeeds, then this function does not need the `MFLicenseConfig` at all - therefore it's totally offline in that case (as of Oct 2024)
    
        ///     On thread safety: (Oct 2024) This function accesses the following shared state: `SecureStorage` values and cached values (which are stored in `config.plist`).
        ///         > As long as `Config` and `SecureStorage` accesses are thread safe, I thinkk this function should be thread-safe, too? (Not entirely sure.)
        ///      > Otherwise we might want to ensure that License.swift is always accessed from the same thread/queue, (probably main thread would be fine) or if that's not possible - use locks. (Update: Locks can't be used in async contexts in Swift, but the Swift package `groue/Semaphore` - which we discussed elsewhere - might fix this.)
        
        var result: MFLicenseState?
        var serverError: NSError?
        
        /// Check if the license key is valid
        
        checkLicenseKeyValidity: do {
            
            /// Get key
            ///     from secure storage
            
            guard let key = SecureStorage.get("License.key") as? String else {
                    
                /// No key found in secure storage
                
                /// Return unlicensed
                ///     Note: Perhaps we should also do this if the licenseKey is an emptyString?
                result = MFLicenseState(isLicensed: false, freshness: kMFValueFreshnessFresh, licenseTypeInfo: MFLicenseTypeInfoNotLicensed())
                DDLogInfo("GetLicenseState: No license key was found in the secureStorage.\n(This is now just a log message. Would formerly return NSError with code kMFLicenseErrorCodeKeyNotFound)")
                break checkLicenseKeyValidity
            }
            
            /// Gather licenseConfig
            let licenseConfig = await GetLicenseConfig.get()
            
            /// Ask licenseServer(s)
            (result, serverError) = await licenseStateFromServer(key: key, incrementUsageCount: false, licenseConfig: licenseConfig)
        
            /// Log errors
            if let error = serverError {
                DDLogInfo("GetLicenseState: LicenseServer API responded with error: \(error)")
            }
            
            /// Fall back to cache / hardcoded
            ///     In case the server did not say whether the key is valid or not
            result = result ?? self.licenseStateFromCache() ?? self.licenseStateFromFallback
            
            /// Log fallback
            if result?.freshness != kMFValueFreshnessFresh {
                DDLogInfo("GetLicenseState: Using cached/hardcoded licenseState:\(result ?? "<nil>")\n(This is now just a log message. Would formerly return NSError with code: kMFLicenseErrorCodeNoInternetAndNoCache")
            }
            
        } /// end of checkLicenseKeyValidity
        
        /// Unwrap the MFLicenseState
        guard var result = result
        else {
            fatalError("Something in our code is wrong. MFLicenseState is nil even though we should've assigned a hardcoded fallback value at the very least.")
        }
        
        /// Validate checkLicenseKeyValidity result
        assert(result.freshness != kMFValueFreshnessNone)
        if result.isLicensed { assert(!(result.licenseTypeInfo is MFLicenseTypeInfoNotLicensed)) }
        if result.isLicensed &&
           result.freshness == kMFValueFreshnessFresh { assert(serverError == nil) }
        
        /// Implement special licenseTypes that don't require a valid license key
        ///     we also call these special licenseTypes "special conditions" or "overrides"
        if result.isLicensed == false {
            if let override = await licenseStateFromOverrides() {
                result = override
            }
        }

        /// Return result
        return result
    }
    
    /// Server/cache/fallback/overrides interfaces
    
    public static func licenseStateFromOverrides() async -> MFLicenseState? {
        
        /// Old notes:
        ///     - (This note is totally outdated as of Oct 2024 ->) Instead of using a licenseReason, we could also pass that info through the error. That might be better since we'd have one less argument and the the errors can also contain dicts with custom info. Maybe you could think about the error as it's used currently as the "unlicensed reason"
        
        /// Implement `FORCE_LICENSED` flag
        ///     See License.swift comments for more info
        
        #if FORCE_LICENSED
        return MFLicenseState(isLicensed: true, freshness: kMFValueFreshnessFresh, licenseTypeInfo: MFLicenseTypeInfoForce())
        #endif
        
        /// Implement freeCountries
        
        if let regionCode = LicenseUtility.currentRegionCode() { /// ChatGPT said currentRegionCode() might not be thread safe? I don't think we should worry about that, but not entirelyyy sure.
            let config = await GetLicenseConfig.get() /// This makes an internet connection - therefore we should probably check this "override" after the others - to avoid any non-essential internet connections.
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
    
    private static func storeLicenseStateInCache(_ newValue: MFLicenseState) {
    
            /// Note:
            ///     We're caching all the fields of the `MFLicenseState` (since that all depends on the licenseServer's evaluation, which might not always be available, requiring us to fall back to cached values)
            ///         It's unnecessary to cache the `MFLicenseState.freshness` value since that indicates the orgin of the data - server, cache, or fallback - and isn't really "part of the data" itself.
            ///         However, removing the value before caching requires extra lines of code, and doesn't have practical benefit, so we don't bother.
            
            /// Archive object
            ///     (Oct 2024) The archive is pure data.
            ///         It would be more transparent / introspectable / debuggable if we created a dictionary (or a human readable string)
            ///         -> ... and inserted that into the configDict so that way you could clearly see the structure of the archive even just reading config.plist (which the archive will be stored inside of.)
            ///         -> Update: We extended MFDataClass to encode / decode itself from a dictionary with all the same security checks that our secure decoding currently has (nil validation and type validation)
            ///             ... But this approach won't work here because we have an MFDataClass nested in another MFDataClass.
            ///         -> Also, I guess it's not that bad for the MFLicenseState cache to be obscure because we want it to be reasonably annoying to hack it such that the app thinks it's licensed even though it's not.
            let (cacheData, error) = MFCatch { try NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) }
            guard let cacheData = cacheData else {
                DDLogError("Archiving MFLicenseState for caching failed with error: \(error.debugDescription). Don't think this should ever happen.")
                assert(false)
                return
            }
            
            /// Store data
            setConfig("License.licenseStateCache", cacheData as NSObject)
            commitConfig()
    }
    
    private static func licenseStateFromCache() -> MFLicenseState? {
            
            /// Get data
            guard let cacheData = config("License.licenseStateCache") as? Data else {
                DDLogDebug("No licenseStateCache Data found")
                return nil
            }
            
            /// Unarchive
            ///     Note: (Oct 2024: Note that coder.requiresSecureCoding is turned on here implicitly.
            ///         -> This is somewhat slower and pretty unnecessary here I think since hackers would have to tamper with the (locally stored) cache to perform an 'object substitution' or 'nil insertion' attack. And if they can modify local files, they already have full control over the system.)
            ///         -> I guess another possible benefit of the nil/type checks is if we change MFLicenseState in the future and we forget to handle that explicitly, then we would just return nil here in some cases instead of returning an invalid object that might crash the app because of unexpected type/nullability
            let (licenseState, decodingError) = MFCatch { try NSKeyedUnarchiver.unarchivedObject(ofClass: MFLicenseState.self, from: cacheData) }
            guard let licenseState = licenseState,
                  let licenseState = licenseState else { /// Unwrap twice because double-optional
                DDLogDebug("Failed to decode licenseStateCache data. Error: \(decodingError.debugDescription)")
                return nil
            }
            
            /// Override freshness
            let result = MFLicenseState(isLicensed: licenseState.isLicensed,
                                        freshness: kMFValueFreshnessCached,     /// Note that we use all values from cache except for freshness
                                        licenseTypeInfo: licenseState.licenseTypeInfo)

            /// Return
            return result
    }

    public static func licenseStateFromServer(key: String, incrementUsageCount: Bool, licenseConfig: MFLicenseConfig) async -> (licenseState: MFLicenseState?, error: NSError?) {
    
        /// This function tries to retrieve the MFLicenseState from the known licenseServers.
        ///     If we don't receive clear information from any of the licenseServers about whether the license is valid or not, we return `nil`
        ///
        /// Test Licenses:
        ///     (Please don't use these test licenses. If you need a free one, just reach out to me. Thank you.)
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
                                                                                          "increment_uses_count": incrementUsageCount ? "true" : "false"])
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
                                                                                          "increment_uses_count": incrementUsageCount ? "true" : "false"])
                
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
        ///     Notes:
        ///     - The cache exists to substitute server values when the licenseServer isn't accessible. (Update: Or when we don't want to talk to the licenseServer and instead we wanna do offline validation in order to minimize internet connections and enhance privacy.)
        ///     - If isLicensed is false, the MFLicenseState doesn't really hold any interesting info, so perhaps we could just delete the cache in that case, instead of caching all the uninteresting values? Then we'd fallback to the hardcoded fallback values which will also make the app unlicensed - so the behavior should be the same.
        ///     - We used to fill the cache at the end of `checkLicense()`. Discussion: That's sort of unnecessary since we end up caching values that just came out of the cache/fallback. However, caching override-MFLicenseStates like the freeCountry one might be sort of useful for extra robustness. E.g. if the app is licensed under a freeCountry license where that freeCountry isn't included in the hardcoded fallback, and then the internet and the licenseConfig cache goes away, then the user can't use the app anymore. Whereas when we cache the override-MFLicenseStates here, then that would serve as an extra failsafe making the app usable even if those other two things go away (I think at least - not entirely sure.)
        if let result = result {
            self.storeLicenseStateInCache(result)
        }
        
        /// Return
        return (result, resultError)
    }
}
