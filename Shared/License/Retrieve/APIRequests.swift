//
// --------------------------------------------------------------------------
// APIRequests.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

func sendDictionaryBasedAPIRequest(requestURL: String, args: [String: Any]) async -> (serverResponseDict: [String: Any]?, communicationError: NSError?, urlResponse: URLResponse?) {
    
    /// Overview:
    ///     Essentially, we send a json dict to a URL, and get a json dict back
    ///         (We also get a `communicationError` back, if the request times out, or the servers response is in an invalid format or something)
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
        let serverData = serverData,
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
