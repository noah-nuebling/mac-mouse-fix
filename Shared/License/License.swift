//
// --------------------------------------------------------------------------
// License.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
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

extension MFLicenseAndTrialState: Equatable {
    public static func == (lhs: MFLicenseAndTrialState, rhs: MFLicenseAndTrialState) -> Bool {
        /// Note:
        /// - We don't check for freshness because it makes sense.
        /// - We also don't check for trialIsOver directly, because it's derived from trialDays and daysOfUse
        /// - Should we check for licenseReason equality here? I can't remember how this is used. Edit: This is used in AboutTabController to check whether to update the UI. So we need to check for licenseReason as well
        lhs.isLicensed.boolValue == rhs.isLicensed.boolValue && lhs.licenseReason == rhs.licenseReason && lhs.daysOfUse == rhs.daysOfUse && lhs.trialDays == rhs.trialDays
    }
}

// MARK: - Main class

@objc class License: NSObject {
    
    // MARK: Lvl 3
    
    @objc static func checkAndReact(licenseConfig: LicenseConfig, triggeredByUser: Bool) {
        
        /// This runs a check and then if necessary it:
        /// - ... shows some feedback about the licensing state to the user
        /// - ... locks down the helper
        
        /// Get licensing state
        
        checkLicenseAndTrial(licenseConfig: licenseConfig) { license, error in
            
            if license.isLicensed.boolValue {
                 
                /// Do nothing if licensed
                return
                
            } else {
                
                /// Not licensed -> check trial
                if license.trialIsActive.boolValue {
                    
                    /// Trial still active -> do nothing
                    //      TODO: Maybe display small reminder after half of trial is over?
                    
                } else {
                    
                    /// Trial has expired -> show UI
                    
                    if triggeredByUser {
                        
                        /// Display more complex UI
                        ///     This is unused so far
                        
                        /// Validate
                        assert(runningMainApp())
                        
                    } else {
                        
                        /// Not triggered by user -> the users workflow is disruped -> make it as short as possible
                        
                        /// Validate
                        assert(runningHelper())
                        
                        /// Only compile if helper (Otherwise there are linker errors)
                        #if IS_HELPER
                        
                        /// Show trialNotification
                        DispatchQueue.main.async {
                            TrialNotificationController.shared.open(licenseConfig: licenseConfig, license: license, triggeredByUser: triggeredByUser)
                        }
                        
                        /// Lock helper
                        SwitchMaster.shared.lockDown()
                        
                        #endif
                        
                    }
                    
                }
                
            }
            
        }
    }
    
    // MARK: Lvl 2
    
    /// These functions assemble info about the trial and the license.
    
    @objc static func checkLicenseAndTrialCached(licenseConfig: LicenseConfig) -> MFLicenseAndTrialState {
        
        /// This function only looks at the cache even if there is an internet connection. While this functions sister-function `checkLicenseAndTrial(licenseConfig:completionHandler:)` retrieves info from the cache only as a fallback if it can't get current info from the internet.
        /// In contrast to the sister function, this function is guaranteed to return immediately since it doesn't load stuff from the internet.
        /// We want this in some places where we need some info immediately to display UI to the user.
        /// The content of this function is largely copy pasted from `licenseState(licenseConfig:completionHandler:)` which is sort of ugly.
        
        /// Get cache
        ///     Note: Here, we fall back to false and don't throw errors if there is no cache, but in `licenseState(licenseConfig:)` we do throw an error. Does this have a reason?
        
        let isLicensed = self.isLicensedCache
        let licenseReason = self.licenseReasonCache
        
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
        
        /// Return assmbled license + trial info
        
        let result = MFLicenseAndTrialState(isLicensed: ObjCBool(isLicensed), freshness: kMFValueFreshnessCached, licenseReason: licenseReason, daysOfUse: Int32(daysOfUse), daysOfUseUI: Int32(daysOfUseUI), trialDays: Int32(trialDays), trialIsActive: ObjCBool(trialIsActive))
        return result
        
    }
    
    @objc static func checkLicenseAndTrial(licenseConfig: LicenseConfig, completionHandler: @escaping (_ license: MFLicenseAndTrialState, _ error: NSError?) -> ()) {
        
        /// At the time of writing, we only use licenseConfig to get the maxActivations.
        ///     Since we get licenseConfig via the internet this might be worth rethinking if it's necessary. We made a similar comment somewhere else but I forgot where.
        
        /// Check license
        checkLicense(licenseConfig: licenseConfig) { isLicensed, freshness, licenseReason, error in
            
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
            
            /// Return assmbled license + trial info
            
            let result = MFLicenseAndTrialState(isLicensed: ObjCBool(isLicensed), freshness: freshness, licenseReason: licenseReason, daysOfUse: Int32(daysOfUse), daysOfUseUI: Int32(daysOfUseUI), trialDays: Int32(trialDays), trialIsActive: ObjCBool(trialIsActive))
            
            completionHandler(result, error)
        }
        
    }
    
    // MARK: Lvl 1
    
    /// Wrapper for `_checkLicense` that sets incrementUsageCount to false and automatically retrieves the licenseKey from secure storage
    ///     Meant to be used by the rest of the app except LicenseSheet
    
    static func checkLicense(licenseConfig: LicenseConfig, completionHandler: @escaping (_ isLicensed: Bool, _ freshness: MFValueFreshness, _ licenseReason: MFLicenseReason, _ error: NSError?) -> ()) {
        
        /// Setting key to nil so it's retrieved from secureStorage
        _checkLicense(key: nil, licenseConfig: licenseConfig, incrementUsageCount: false, completionHandler: completionHandler)
    }

    /// Wrappers for `_checkLicense` that set incrementUsageCount to true / false.
    ///     Meant to be used by LicenseSheet
    
    static func checkLicense(key: String, licenseConfig: LicenseConfig, completionHandler: @escaping (_ isLicensed: Bool, _ freshness: MFValueFreshness, _ licenseReason: MFLicenseReason, _ error: NSError?) -> ()) {
        
        _checkLicense(key: key, licenseConfig: licenseConfig, incrementUsageCount: false, completionHandler: completionHandler)
    }
    
    static func activateLicense(key: String, licenseConfig: LicenseConfig, completionHandler: @escaping (_ isLicensed: Bool, _ freshness: MFValueFreshness, _ licenseReason: MFLicenseReason, _ error: NSError?) -> ()) {
        
        _checkLicense(key: key, licenseConfig: licenseConfig, incrementUsageCount: true, completionHandler: completionHandler)
    }
    
    // MARK: Lvl 0
    
    /// `_checkLicense` is a core function that has as many arguments and returns as much information about the license state as possible. The rest of this class is mostly wrappers for this function
    
    private static func _checkLicense(key keyArg: String?, licenseConfig: LicenseConfig, incrementUsageCount: Bool, completionHandler: @escaping (_ isLicensed: Bool, _ freshness: MFValueFreshness, _ licenseReason: MFLicenseReason, _ error: NSError?) -> ()) {
        
        /// Define wrap up workload
        ///     This is called once this function has decided whether the license is valid or not
        
        let wrapUp = { (isLicensed: Bool, freshness: MFValueFreshness, error: NSError?, licenseConfig: LicenseConfig, completionHandler: (_ isLicensed: Bool, _ freshness: MFValueFreshness, _ licenseReason: MFLicenseReason, _ error: NSError?) -> ()) -> () in
            
            /// Validate
            
            assert(freshness != kMFValueFreshnessNone)
            
            if freshness == kMFValueFreshnessFresh && isLicensed {
                assert(error == nil)
            }
            
            /// Create mutable copies of args so we can override them
            
            var isLicensed = isLicensed
            var freshness = freshness
            var error = error
            
            var licenseReason = kMFLicenseReasonUnknown
            
            if isLicensed {
                
                /// Get licenseReason from cache if value isn't fresh
                
                if freshness == kMFValueFreshnessFresh {
                    licenseReason = kMFLicenseReasonValidLicense
                } else if freshness == kMFValueFreshnessCached {
                    licenseReason = self.licenseReasonCache
                } else {
                    assert(false) /// Don't think this could ever happen, not totally sure though
                }
                
            } else { /// Unlicensed
                
                /// Init license reason
                
                licenseReason = kMFLicenseReasonNone
                
                /// Override isLicensed
                
                /// Notes:
                /// - Instead of using licenseReason, we could also pass that info through the error. That might be better since we'd have one less argument and the the errors can also contain dicts with custom info. Maybe you could think about the error as it's used currently as the "unlicensed reason"
                /// - We're wrapping the overrideWorkload in a closure just so that we can return out of it and prevent lots of nested if statements. Seems sort of ugly but I don't know how else to achieve this sort of controlFlow without goto statements.
                
                let overrideWorkload = {

                    /// Implement `FORCE_LICENSED` flag
                    ///     See License.swift comments for more info
                    
    #if FORCE_LICENSED
                    isLicensed = true
                    freshness = kMFValueFreshnessFresh
                    licenseReason = kMFLicenseReasonForce
                    return
    #endif
                    /// Implement freeCountries
                    var isFreeCountry = false
                    
                    if let code = LicenseUtility.currentRegionCode() {
                        isFreeCountry = licenseConfig.freeCountries.contains(code)
                    }
                    
                    if isFreeCountry {
                            
                        isLicensed = true
                        freshness = kMFValueFreshnessFresh
                        licenseReason = kMFLicenseReasonFreeCountry
                        
                        return
                    }
                }
                overrideWorkload()
            }
            
            /// Cache stuff
            self.isLicensedCache = isLicensed
            self.licenseReasonCache = licenseReason

            /// Call completionHandler
            completionHandler(isLicensed, freshness, licenseReason, error)
        }
        
        /// Get key
        ///     From secure storage if `keyArg` == nil
        
        var key: String
        
        if let keyArg = keyArg {
            key = keyArg
        } else {
            guard let keyStorage = SecureStorage.get("License.key") as! String? else {

                /// No key provided in function arg and no key found in secure storage
                
                /// Return unlicensed
                let error = NSError(domain: MFLicenseErrorDomain, code: Int(kMFLicenseErrorCodeKeyNotFound))
                wrapUp(false, kMFValueFreshnessFresh, error, licenseConfig, completionHandler)
                return
            }
            
            key = keyStorage
        }
        
        /// Ask gumroad to verify
        
        /// Start an async-context
        ///     Notes:
        ///     - We're using .detached because .init schedules on the current Actor according to the docs. We're not trying to use any Actors.
        ///     - The `priority:` really depends on where this is called from. Sometimes it should be`.userInitiated` and sometimes`.background`
        Task.detached(priority: .userInitiated, operation: {
            
            let (isValidKey, nOfActivations, serverResponse, error, urlResponse) = await Gumroad.getLicenseInfo(key, incrementUsageCount: incrementUsageCount)
                
            if isValidKey { /// Gumroad says the license is valid
                
                /// Validate activation count
                
                var validActivationCount = false
                if let a = nOfActivations, a <= licenseConfig.maxActivations {
                    validActivationCount = true
                }
                
                if !validActivationCount {
                    
                    let error = NSError(domain: MFLicenseErrorDomain, code: Int(kMFLicenseErrorCodeInvalidNumberOfActivations), userInfo: ["nOfActivations": nOfActivations ?? -1, "maxActivations": licenseConfig.maxActivations])
                    
                    wrapUp(false, kMFValueFreshnessFresh, error, licenseConfig, completionHandler)
                    return
                }
                
                
                /// Is licensed!
                
                wrapUp(true, kMFValueFreshnessFresh, nil, licenseConfig, completionHandler)
                return
                
            } else { /// Gumroad says key is not valid
                
                if let error = error,
                   error.domain == NSURLErrorDomain {
                    
                    /// Failed due to internet issues -> try cache
                    
                    if let isLicensedCache = config("License.isLicensedCache") as? Bool {
                        
                        /// Fall back to cache
                        wrapUp(isLicensedCache, kMFValueFreshnessCached, error, licenseConfig, completionHandler)
                        return
                        
                    } else {
                        
                        /// There's no cache
                        let error = NSError(domain: MFLicenseErrorDomain,
                                            code: Int(kMFLicenseErrorCodeNoInternetAndNoCache))
                        
                        wrapUp(false, kMFValueFreshnessFallback, error, licenseConfig, completionHandler)
                        return
                    }
                    
                } else {
                    
                    /// Failed despite good internet connection -> Is actually unlicensed
                    wrapUp(false, kMFValueFreshnessFresh, error, licenseConfig, completionHandler) /// Pass through the error from Gumroad.swift
                    return
                }
            }
        })
    }
    
    // MARK: Cache interface
    
    /// Not totally sure why we're caching these specific things. But it's the info we need to display the UI and so on properly
    
    private static var licenseReasonCache: MFLicenseReason {
        get {
            if let licenseReasonRaw = config("License.licenseReasonCache") as? UInt32 {
                return MFLicenseReason(licenseReasonRaw)
            } else {
                return kMFLicenseReasonUnknown
            }
        }
        set {
            let licenseReasonRaw = newValue.rawValue
            setConfig("License.licenseReasonCache", licenseReasonRaw as NSObject)
            commitConfig()
        }
    }
    private static var isLicensedCache: Bool {
        get {
            return config("License.isLicensedCache") as? Bool ?? false
        }
        set {
            setConfig("License.isLicensedCache", newValue as NSObject)
            commitConfig()
        }
    }
}

// MARK: Gumroad api wrapper

class Gumroad: NSObject {
    
    //
    // MARK: Lvl 1
    //
    
    /// Constants
    /// Notes:
    /// - `mmfinapp` was used during the MMF 3 Beta. It was using € which you can't change, so we had to create a new product in Gumroad `mmfinappusd`
    
    private static let gumroadAPIURL = "https://api.gumroad.com/v2"
    private static let productPermalinkOld = "mmfinapp"
    private static let productPermalink = "mmfinappusd"
    
    /// Functions
    
    static func getLicenseInfo(_ key: String, incrementUsageCount: Bool) async -> (isValidKey: Bool, nOfActivations: Int?, serverResponse: [String: Any]?, error: NSError?, urlResponse: URLResponse?) {
            
        var (serverResponse, error, urlResponse) = await sendDictionaryBasedAPIRequest(requestURL: gumroadAPIURL.appending("/licenses/verify"),
                                                                               args: ["product_permalink": productPermalink,
                                                                                      "license_key": key,
                                                                                      "increment_uses_count": incrementUsageCount ? "true" : "false"])
        
        if  let message = error?.userInfo["message"] as? NSString,
            message == "That license does not exist for the provided product." {
            
            /// If license doesn't exist for new product, try old product
            (serverResponse, error, urlResponse) = await sendDictionaryBasedAPIRequest(requestURL: gumroadAPIURL.appending("/licenses/verify"),
                                                                               args: ["product_permalink": productPermalinkOld,
                                                                                      "license_key": key,
                                                                                      "increment_uses_count": incrementUsageCount ? "true" : "false"])
        }
        
        /// Guard:  Error
        if error != nil {
            return (false, nil, serverResponse, error, urlResponse)
        }
        
        /// Unwrap serverResponse
        guard let serverResponse = serverResponse else {
            fatalError("The serverResponse was nil even though the error was also nil. There's something wrong in our code.")
        }
        
        /// Guard: Map non-success response to error
        ///         - Maybe we should map the server responses to errors at a higher level in the processing chain. With the goal to centralize the knowledge about how the Gumroad server response should be structured in one place in the code.
        guard
            let success = (serverResponse["success"] as? Bool), /// We expect the Gumroad response to have a boolean field called "success" which tells us whether the license was successfully validated or something went wrong.
            success == true
        else {
            let error = NSError(domain: MFLicenseErrorDomain,
                                code: Int(kMFLicenseErrorCodeGumroadServerResponseError),
                                userInfo: serverResponse)
            
            return (false, nil, serverResponse, error, urlResponse)
        }
        
        /// Gather info from response dict
        ///     None of these should be null but we're checking the extracted data one level above.
        ///     (So it's maybe a little unnecessary that we extract data at all at this level)
        ///     TODO: Maybe we should consider merging lvl 1 and lvl 2 since lvl 2 really only does the data validation)
        
        let isValidKey = serverResponse["success"] as? Bool ?? false
        let activations = serverResponse["uses"] as? Int
        
        /// Call completions handler
        return (isValidKey, activations, serverResponse, error, urlResponse)
    }
    
    private static func decrementUsageCount(key: String, accessToken: String, completionHandler: @escaping (_ serverResponse: [String: Any]?, _ error: NSError?, _ urlResponse: URLResponse?) -> ()) {
        
        /// Meant to free a use of the license when the user deactivates it
        /// We won't do this because we'd need to implement oauth and it's not that imporant
        ///    (If we wanted to do this, the API is `/licenses/decrement_uses_count`)
        
        fatalError()
    }
    
    //
    // MARK: Lvl 0
    //
    
    /// Functions
    
    private static func sendDictionaryBasedAPIRequest(requestURL: String, args: [String: Any]) async -> (serverResponse: [String: Any]?, error: NSError?, urlResponse: URLResponse?) {
        
        /// Overview:
        ///     Essentially, we send a json dict to a URL, and get a json dict back
        ///         (We also get an `error` back, if the request times out or something)
        ///         (We also get a `urlResponse` object back, which contains the HTTP status codes and stuff. Not sure if we use this) (as of Oct 2024)
        ///     We plan to use this to interact with the JSON-dict-based Gumroad APIs as well as our custom AWS APIs - which will also be JSON-dict based
        ///
        /// Discussion:
        ///     - The **Gumroad** server's response data never contains the secret access token, so you can print the return values for debugging
        ///         Update: (Oct 2024) What does this mean? We have no access token I'm aware of. What's the source for this? Also what about other sensitive data aside from an "access token" - e.g. the users license key? Are we sure there's not sensitive data in the server responses?
        ///             Also, this function is no longer Gumroad-specific - so what about the AWS API? (Which we will write ourselves)
        ///     - On **return values**:
        ///         - If and only if there's an error, the `error` field in the return tuple will be non-nil. The other return fields will be filled with as much info as possible, even in case of an error. (Last updated: Oct 2024)
        ///     - On our usage of **errors**:
        ///         - We return an `NSError` from this function
        ///             Why do we do that? (instead of returning a native Swift error)
        ///             1. We create our custom errors via  `NSError(domain:code:userInfo:)` which seems to be the easiest way to do that.
        ///             2. NSError is compatible with all our code (even objc, although the licensing code is all swift, so not sure how useful this is)
        ///             3. The swift APIs give us native swift errors, but the internet says, that *all* swift errors are convertible to NSError via `as NSError?` - so we should never lose information by just converting everything to NSError and having our functions return that.
        ///                 The source that the internet people cite is this Swift evolution proposal (which I don't really understand): https://github.com/swiftlang/swift-evolution/blob/main/proposals/0112-nserror-bridging.md
        
        ///
        /// 0. Define constants
        ///
        let cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData
        let timeout = 10.0
        let httpMethod = "POST"
        let headerFields = [ /// Not sure if necessary
            "Content-Type": "application/x-www-form-urlencoded", /// Make it use in-url params
            "Accept": "application/json", /// Make it return json
        ]
        
        ///
        /// 1. Create request
        ///
        
        /// Also see: https://stackoverflow.com/questions/26364914/http-request-in-swift-with-post-method
        
        /// Get urlObject
        ///     From urlString
        guard let requestURL_ = URL(string: requestURL) else {
            fatalError("Tried to create API request with unconvertible URL string: \(requestURL)")
        }
        /// Create query string from the args
        ///     Notes:
        ///     - You can also do this using the URLComponents API. but apparently it doesn't correctly escape '+' characters, so not using it that.
        ///     - .Since we're sending the args in the request body instead of as part of the URL, does it really make sense to convert it to a queryString first?
        let queryString = args.asQueryString()
        
        /// Create request
        var request = URLRequest(url: requestURL_, cachePolicy: cachePolicy, timeoutInterval: timeout)
        request.httpMethod = httpMethod
        request.allHTTPHeaderFields = headerFields
        request.httpBody = queryString.data(using: .utf8)
        
        ///
        /// 2. Get server response
        ///
        
        let (result, error_) = await MFCatch { try await URLSession.shared.data(for: request) }
        let (serverData, urlResponse) = result ?? (nil, nil)
        
        /// Guard: URL error
        ///     Note: We have special logic for displaying the `NSURLErrorDomain` errors, so we don't wrap this in a custom `MFLicenseErrorDomain` error.
        if let urlError = error_ {
            return (nil, (urlError as NSError?), urlResponse)
        }
        
        /// Guard: server response is nil
        ///     ... despite there being no URL error - Not sure this can ever happen
        ///     Notes:
        ///     - The urlResponse, which we return in the NSError's userInfo, contains some perhaps-sensitive data, but we're stripping that out before printing the error. For more info, see where the error is printed. (last updated: Oct 2024).
        guard
            var serverData = serverData,
            let urlResponse = urlResponse
        else {
            assert(false) /// I'm not sure this can actually happen.
            
            let error = NSError(domain: MFLicenseErrorDomain,
                                code: Int(kMFLicenseErrorCodeServerResponseInvalid),
                                userInfo: ["data": (serverData ?? "<nil>"),
                                           "urlResponse": (urlResponse ?? "<nil>"),
                                           "dataAsUTF8": (String(data: (serverData ?? Data()), encoding: .utf8) ?? "")])
            return (nil, error, urlResponse)
        }
        
        ///
        /// 3. Parse response as a JSON dict
        ///
        
        let (jsonObject, error__) = MFCatch { try JSONSerialization.jsonObject(with: serverData, options: []) }
        
        /// Guard: JSON serialization error
        ///     Notes:
        ///     - I've seen this error happen, see [this mail](message:<CAA7L-uPZUyVntBTXTeJJ0SOCpeHNPnEzYo2C3wqtdbFTG0e_7A@mail.gmail.com>)
        ///     - We thought about using `options: [.fragmentsAllowed]` to prevent the JSONSerialization error in some cases, but then the resulting Swift object wouldn't have the expected structure so we'd get further errors down the line. So it's best to just throw an error ASAP I think.
        ///     - If the `serverData` is not a UTF8 string, then it won't be added to NSError's userInfo here. JSON data could be UTF-8, UTF-16LE, UTF-16BE, UTF-32LE or UTF-32BE - JSONSerialization detects the encoding automatically, but Swift doesn't expose a simple way to do that. So we're just hoping that the string from the server is utf8 (last updated: Oct 2024)
        
        if let jsonError = error__ {
            
            assert(jsonObject == nil)
            assert(error__ != nil)
            
            let error = NSError(domain: MFLicenseErrorDomain,
                                code: Int(kMFLicenseErrorCodeServerResponseInvalid),
                                userInfo: ["data": serverData,
                                           "urlResponse": urlResponse,
                                           "dataAsUTF8": (String(data: serverData, encoding: .utf8) ?? ""),
                                           "jsonSerializationError": jsonError])
            return (nil, error, urlResponse)
        }
        assert(jsonObject != nil)
        assert(error__ == nil)
        
        /// Guard: JSON from server is a acually dict
        guard let jsonDict = jsonObject as? [String: Any] else {
            let error = NSError(domain: MFLicenseErrorDomain,
                                code: Int(kMFLicenseErrorCodeServerResponseInvalid),
                                userInfo: ["data": serverData,
                                           "urlResponse": urlResponse,
                                           "jsonSerializationResult": (jsonObject ?? "")])
            return (nil, error, urlResponse)
        }
        
        ///
        /// 4. Return JSON dict
        ///
        
        return (jsonDict, nil, urlResponse)
    }
}
    
// MARK: - URL handling helper stuff
///  Src: https://stackoverflow.com/a/26365148/10601702

extension Dictionary {
    func asQueryString() -> String {
        
        /// Turn the dictionary into a URL ?query-string
        ///     See https://en.wikipedia.org/wiki/Query_string
        ///     (Not including the leading `?` that usually comes between a URL and the query string.)
        
        let a: [String] = map { key, value in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
        
        let b: String = a.joined(separator: "&")
        
        return b
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" /// does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        
        var allowed: CharacterSet = .urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}
