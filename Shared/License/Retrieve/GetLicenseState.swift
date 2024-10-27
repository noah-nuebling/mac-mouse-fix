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
        let result = self.licenseStateCache ?? self.licenseStateFallback
        return result
    }
    
    static func checkLicense(licenseConfig: MFLicenseConfig) async -> (licenseState: MFLicenseState, error: NSError?) {
    
        /// Wrappers for `_checkLicense` that sets incrementUsageCount to false and automatically retrieves the licenseKey from secure storage
        ///     Meant to be used by the rest of the app except LicenseSheet
        
        /// Setting key to nil so it's retrieved from secureStorage
        return await _checkLicense(key: nil, licenseConfig: licenseConfig, incrementUsageCount: false)
    }
    
    /// Wrappers for `_checkLicense` that set incrementUsageCount to true / false.
    ///     Meant to be used by LicenseSheet
    
    static func checkLicense(key: String, licenseConfig: MFLicenseConfig) async -> (licenseState: MFLicenseState, error: NSError?) {
        
        return await _checkLicense(key: key, licenseConfig: licenseConfig, incrementUsageCount: false)
    }
    
    static func activateLicense(key: String, licenseConfig: MFLicenseConfig) async -> (licenseState: MFLicenseState, error: NSError?) {
        
        return await _checkLicense(key: key, licenseConfig: licenseConfig, incrementUsageCount: true)
    }
    
    private static func _checkLicense(key keyArg: String?, licenseConfig: MFLicenseConfig, incrementUsageCount: Bool) async -> (licenseState: MFLicenseState, error: NSError?) {
        
        /// This function determines the current licenseState of the application.
        ///     To do this, it checks the licenseServer, cache, fallback values, and special conditions
        
        /// Discussion:
        /// - On thread safety: (Oct 2024) This function accesses the following shared state: `SecureStorage` values and cached values (which are stored in `config.plist`).
        ///     > As long as `Config` and `SecureStorage` accesses are thread safe, I thinkk this function should be thread-safe, too? (Not entirely sure.)
        ///     > Otherwise we might want to ensure that License.swift is always accessed from the same thread/queue, (probably main thread would be fine )or if that's not possible - use locks.
        
        var result: MFLicenseState?
        var resultError: NSError?
        
        ///
        /// Check if the license key is valid
        ///
        
        checkLicenseKeyValidity: do {
            
            /// Get key
            ///     From arg or from secure storage
            
            guard let key = keyArg ?? (SecureStorage.get("License.key") as? String) else {
                    
                /// No key provided in function arg and no key found in secure storage
                
                /// Return unlicensed
                ///     Notes:
                ///     - Perhaps we should also do this if the licenseKey is an emptyString?
                ///     - Does it really make sense to return an error here? We don't display any errors to the user based on this, since on the licenseSheet, the user is always going to enter a licenseKey before getting feedback about licensing issues I think, so maybe we should treat this as an 'internal error' and not return an NSError.
                result = MFLicenseState(isLicensed: false, freshness: kMFValueFreshnessFresh, licenseTypeInfo: MFLicenseTypeInfoNotLicensed())
                resultError = NSError(domain: MFLicenseErrorDomain, code: Int(kMFLicenseErrorCodeKeyNotFound))
                break checkLicenseKeyValidity
            }
            
            /// Ask licenseServer(s)
            (result, resultError) = await askLicenseServers(key: key, incrementUsageCount: incrementUsageCount, licenseConfig: licenseConfig)
            
            /// Fall back to cache
            ///     In case the server did not say whether the key is valid or not
            if result == nil {
                result = self.licenseStateCache
            }
            
            /// Fall back to hardcoded
            if result == nil {
                resultError = NSError(domain: MFLicenseErrorDomain,
                                      code: Int(kMFLicenseErrorCodeNoInternetAndNoCache)) /// Not sure this error is useful, especially since it overrides the serverError, which might prevent useful feedback from being displayed to the user. Alsooo, `kMFValueFreshnessFallback` already carries the same information as this error doesn't it? Update: The problem of overriding the serverError doesn't occur in practise because the app always checks the server and fills the cache on startup - before the user opens the licenseSheet where they might see license-related error messages. (As of Oct 19 - I think once we introduce offline validation this might not be true anymore.)
                result = self.licenseStateFallback
            }
            
        } /// end of checkLicenseKeyValidity
        
        /// Unwrap the result
        guard var result = result else {
            fatalError("Something in our code is wrong. MFLicenseState is nil even though we should've assigned a hardcoded fallback value at the very least.")
        }
        
        /// Validate checkLicenseKeyValidity result
        assert(result.freshness != kMFValueFreshnessNone)
        if result.isLicensed { assert(!(result.licenseTypeInfo is MFLicenseTypeInfoNotLicensed)) }
        if result.isLicensed &&
           (result.freshness == kMFValueFreshnessFresh) { assert(resultError == nil) }
        
        /// Implement other `MFLicenseReason`s
        ///     Aside from `ValidLicense`
        ///     Note: Instead of using a licenseReason, we could also pass that info through the error. That might be better since we'd have one less argument and the the errors can also contain dicts with custom info. Maybe you could think about the error as it's used currently as the "unlicensed reason"
        if result.isLicensed == false {
            
            overrideLicenseState: do {

                /// Implement `kMFLicenseReasonForce`
                ///     See License.swift comments for more info
#if FORCE_LICENSED
                result = MFLicenseState(isLicensed: true, freshness: kMFValueFreshnessFresh, licenseTypeInfo: MFLIcenseTypeInfoForce())
                break overrideLicenseState
#endif
                /// Implement `kMFLicenseReasonFreeCountry`
                if let regionCode = LicenseUtility.currentRegionCode() { /// ChatGPT said currentRegionCode() might not be thread safe? I don't think we should worry about that, but not entirelyyy sure.
                    let isFreeCountry = licenseConfig.freeCountries.contains(regionCode)
                    if isFreeCountry {
                        result = MFLicenseState(isLicensed: true, freshness: kMFValueFreshnessFresh, licenseTypeInfo: MFLicenseTypeInfoFreeCountry(regionCode: regionCode))
                        break overrideLicenseState
                    }
                }
            }
        }
        
        /// Cache result
        ///     Note:
        ///     - Doesn't really make sense that we cache *after* the license-value-overrides - The cache exists to substitute server values when the licenseServer isn't accessible.
        ///     - Also doesn't make sense to cache values we retrieved from the cache / from the fallback
        ///     - Also, if isLicensed is false, the MFLicenseState doesn't really hold any interesting info, so perhaps we could just delete the cache in that case, instead of caching all the uninteresting values?
        self.licenseStateCache = result

        /// Return result
        return (result, resultError)
    }
    
    /// Server/cache/fallback interfaces
    
    private static let licenseStateFallback: MFLicenseState = MFLicenseState(isLicensed: false,
                                                                             freshness: kMFValueFreshnessFallback,
                                                                             licenseTypeInfo: MFLicenseTypeInfoNotLicensed())
    
    private static var licenseStateCache: MFLicenseState? {
        
        set {
            /// Note:
            ///     We're caching all the fields of the `MFLicenseState` (since that all depends on the licenseServer's evaluation, which might not always be available, requiring us to fall back to cached values)
            ///         It's unnecessary to cache the `MFLicenseState.freshness` value since that indicates the orgin of the data - server, cache, or fallback - and isn't really "part of the data" itself.
            ///         However, removing the value before caching requires extra lines of code, and doesn't have practical benefit, so we don't bother.
            
            /// Validate input
            guard let newValue = newValue else {
                DDLogError("Setting the cache to nil is undefined behavior")
                assert(false);
                return
            }
            
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
        get {
            
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
    }

    private static func askLicenseServers(key: String, incrementUsageCount: Bool, licenseConfig: MFLicenseConfig) async -> (licenseState: MFLicenseState?, error: NSError?) {
    
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
            ///             Update: The Gumroad docs also say "You will receive a 404 response code with an error message if verification fails." - so checking 404 seems to be the way (Src: https://help.gumroad.com/article/76-license-keys.html)
            ///     Considerations:
            ///         Generally, we want to err on the side of `LicenseValidityFromServer.unsure`, and only use `LicenseValidityFromServer.invalid` when we're *absolutely* sure that the license is invalid.
            ///         That's because if we set the value to`.invalid` we consider the app *definitively*unlicensed and then lock it down immediately (in case the free days have been used up), which makes for a really annoying user experience if there's a false positive on `.invalid` due to an internal server error or something.
            ///         If instead, we have a false positive on `.unsure` then we just fall back to the cached value for whether the app is licensed or not, which should make for a much less disruptive user experience.
            ///         Actually, as I'm working on this, (Oct 9 2024) I got a [GitHub Issue](https://github.com/noah-nuebling/mac-mouse-fix/issues/1136) from a user saying they regularly have their app locked down and they have to re-enter their license. (I think I also saw reports like this before.) Hopefully that stuff will be fixed now!
            
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
        
        /// Return
        return (result, resultError)
    }
}
