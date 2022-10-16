//
// --------------------------------------------------------------------------
// License.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

import Cocoa
import CocoaLumberjackSwift

@objc class Gumroad: NSObject {
    
    //
    // MARK: Surface
    //
    
    /// Interface
    ///     Use License.swift instead of using this directly
    
//    @objc static func activateLicense(_ key: String, maxActivations: Int, completionHandler: @escaping (_ isValidKey: Bool, _ serverResponse: [String: Any]?, _ error: NSError?, _ urlResponse: URLResponse?) -> ()) {
//
//        _checkLicense(key, maxActivations: maxActivations, incrementUsageCount: true, completionHandler: completionHandler)
//    }
//
//    @objc static func checkLicense(_ key: String, maxActivations: Int, completionHandler: @escaping (_ isValidKey: Bool, _ serverResponse: [String: Any]?, _ error: NSError?, _ urlResponse: URLResponse?) -> ()) {
//
//        _checkLicense(key, maxActivations: maxActivations, incrementUsageCount: false, completionHandler: completionHandler)
//    }
    
    //
    // MARK: Core - lvl 2
    //
    
    static func checkLicense(_ key: String, incrementUsageCount: Bool = false, completionHandler: @escaping (_ isValidKey: Bool, _ nOfActivations: Int?, _ serverResponse: [String: Any]?, _ error: NSError?, _ urlResponse: URLResponse?) -> ()) {
        
        getLicenseInfo(key, incrementUsageCount: incrementUsageCount) { isValidKey, nOfActivations, serverResponse, error, urlResponse in
            
            /// Guard error
            
            if let error = error {
                completionHandler(false, nOfActivations, serverResponse, error, urlResponse)
                return
            }
            
            /// Guard invalid key
            ///     Maybe also check what the URL response is somewhere? I just have no idea what the URL response should be.
            assert(isValidKey == (error == nil))
            
            /// Success!
            completionHandler(true, nOfActivations, serverResponse, error, urlResponse)
        }
    }
    
    //
    // MARK: Core - lvl 1
    //
    
    /// Constants
    
    private static let productPermalink = "mmfinapp"
    
    /// Functions
    
    private static func getLicenseInfo(_ key: String, incrementUsageCount: Bool, completionHandler: @escaping (_ isValidKey: Bool, _ nOfActivations: Int?, _ serverResponse: [String: Any]?, _ error: NSError?, _ urlResponse: URLResponse?) -> ()) {
        
        
        sendGumroadAPIRequest(method: "/licenses/verify",
                              args: ["product_permalink": productPermalink,
                                     "license_key": key,
                                     "increment_uses_count": incrementUsageCount ? "true" : "false"],
                              completionHandler: { data, error, urlResponse in
            
            
            /// Implement `FORCE_LICENSED` flag
            ///     See License.swift comments for more info
            ///     Why aren't we implementing this inside of License.swift? I think we should try to make Gumroad.swift a pure and simple wrapper around the Gumroad API without this extra logic. This is going to be annoying when we need to implement the alternative payment method for China and Russia.
                        
#if FORCE_LICENSED
            completionHandler(true, "fake@email.com", 1, ["info": "this license is considered valid due to the FORCE_LICENSED flag"], nil, nil)
            return
#endif
            
            /// Guard error
            
            if error != nil {
                completionHandler(false, nil, data, error, urlResponse)
                return
            }
            
            /// Gather info from response dict
            ///     None of these should be null but we're checking the extracted data one level above.
            ///     (So it's maybe a little unnecessary that we extract data at all at this level)
            ///     TODO: Maybe we should consider merging lvl 1 and lvl 2 since lvl 2 really only does the data validation)
            
            let isValidKey = data?["success"] as? Bool ?? false
            let activations = data?["uses"] as? Int
            
            /// Call completions handler
            completionHandler(isValidKey, activations, data, error, urlResponse)
        })
    }
    
    private static func decrementUsageCount(key: String, accessToken: String, completionHandler: @escaping (_ serverResponse: [String: Any]?, _ error: NSError?, _ urlResponse: URLResponse?) -> ()) {
        
        /// Meant to free a use of the license when the user deactivates it
        /// We won't do this because we'd need to implement oauth and it's not that imporant
        
        fatalError()
        
        sendGumroadAPIRequest(method: "/licenses/decrement_uses_count",
                              args: ["access_token": accessToken, "product_permalink": productPermalink,"license_key": key],
                              completionHandler: completionHandler)
    }
    
    //
    // MARK: Core - lvl 0
    //
    
    /// Constants
    
    private static let gumroadAPIURL = "https://api.gumroad.com/v2"
    
    /// Functions
    
    private static func sendGumroadAPIRequest(method: String, args: [String: Any], completionHandler: @escaping (_ serverResponse: [String: Any]?, _ error: NSError?, _ urlResponse: URLResponse?) -> ()) {
        
        /// Note: The response data never contains the secret access token, so you can print the return values for debugging
        
        /// Create request
        
        let request = gumroadAPIRequest(method: method, args: args)
        
        
        /// Send request

        let task = URLSession.shared.dataTask(with: request) { data, urlResponse, error in
            
            /// Handle response
            
            /// Cast to NSError
            ///     I think if the error is not an NSError, it just becomes nil instead.
            ///     Maybe we should handle that case. Note: If you do handle it, don't forget the do catch below.
            let error = error as NSError?
            
            /// Guard null response
            
            guard
                let data = data,
                let urlResponse = urlResponse,
                error == nil
            else {
                completionHandler(nil, error, urlResponse)
                return
            }
            
            do {
                /// Parse response as dict
                let dict: [String: Any] = try JSONSerialization.jsonObject(with: data) as! [String : Any]
                
                /// Map non-success response to error
                guard let s = dict["success"], s is Bool, s as! Bool == true else {
                    let error = NSError(domain: MFLicenseErrorDomain, code: Int(kMFLicenseErrorCodeGumroadServerResponseError), userInfo: dict)
                    completionHandler(dict, error, urlResponse)
                    return
                }
                
                /// Success!
                /// Call the callback!
                completionHandler(dict, error, urlResponse)
                
            } catch {
                
                /// Cast to NSError
                let error = error as NSError?
                
                /// Guard not convertible to dict
                completionHandler(nil, error, urlResponse) /// This is the `error` from the catch statement not the closure argument
            }
        }
        
        task.resume()
    }
    
    private static func gumroadAPIRequest(method: String, args: [String: Any]) -> URLRequest {
        
        /// Also see: https://stackoverflow.com/questions/26364914/http-request-in-swift-with-post-method
        
        /// Create basic request
        let requestURL = gumroadAPIURL.appending(method)
        var request = URLRequest(url: URL(string: requestURL)!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10.0)
        request.httpMethod = "POST"
        
        /// Set header fields
        ///     Probably unnecessary
        
        /// Make it use in-url params
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        /// Make it return a dict
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        /// Set message body
        
        /// Create query string from dict and set to request
        ///     You can also do this using URLComponents API. but apparently it doesn't correctly escape '+' characters, so not using it that.
        request.httpBody = args.percentEncoded()
        
        /// Return
        
        return request
    }
}

// MARK: URL handling helper stuff
///  Src: https://stackoverflow.com/a/26365148/10601702

extension Dictionary {
    func percentEncoded() -> Data? {
        map { key, value in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
        .data(using: .utf8)
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
