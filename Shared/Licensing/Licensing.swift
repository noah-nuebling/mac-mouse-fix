//
// --------------------------------------------------------------------------
// Licensing.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa
import CocoaLumberjackSwift

@objc class Licensing: NSObject {
    
    //
    // MARK: Surface
    //
    
    /// Interface
    
    @objc static func activateLicense(_ key: String, email: String, completionHandler: @escaping (_ isValidKeyAndEmail: Bool, _ serverResponse: [String: Any]?, _ error: Error?, _ urlResponse: URLResponse?) -> ()) {
        
        _checkLicense(key, email: email, incrementUsageCount: true, completionHandler: completionHandler)
    }
    
    @objc static func checkLicense(_ key: String, email: String, completionHandler: @escaping (_ isValidKeyAndEmail: Bool, _ serverResponse: [String: Any]?, _ error: Error?, _ urlResponse: URLResponse?) -> ()) {
        
        _checkLicense(key, email: email, incrementUsageCount: false, completionHandler: completionHandler)
    }
    
    //
    // MARK: Core - lvl 2
    //
    
    /// Constants
    
    /// Define max activations
    ///     I want people to activate MMF on as many of their machines  as they'd like.
    ///     This is just so you can't just share one email address + license key combination on some forum and have everyone use that forever. This is probably totally unnecessary.
    private static let maxActivations = 100
    
    /// Functions
    
    private static func _checkLicense(_ key: String, email: String, incrementUsageCount: Bool, completionHandler: @escaping (_ isValidKeyAndEmail: Bool, _ serverResponse: [String: Any]?, _ error: Error?, _ urlResponse: URLResponse?) -> ()) {
        
        getLicenseInfo(key, incrementUsageCount: incrementUsageCount) { isValidKey, emailForKey, nOfActivations, serverResponse, error, urlResponse in
            
            /// Guard error
            
            if let error = error {
                completionHandler(false, serverResponse, error, urlResponse)
                return
            }
            
            /// Guard invalid key
            ///     Maybe also check what the URL response is somewhere? I just have no idea what the URL response should be.
            assert(isValidKey == (error == nil))
            
            /// Guard wrong email
            
            if email != emailForKey {
                
                let error = NSError(domain: MFLicensingErrorDomain, code: Int(kMFLicensingErrorCodeMismatchedEmails), userInfo: ["enteredEmail": email, "emailForKey": emailForKey ?? "<invalid>"])

                completionHandler(false, serverResponse, error, urlResponse)
                return
            }
            
            /// Guard too many activations
            
            guard let a = nOfActivations, a <= maxActivations else {
                
                let error = NSError(domain: MFLicensingErrorDomain, code: Int(kMFLicensingErrorCodeInvalidNumberOfActivations), userInfo: ["nOfActivations": nOfActivations ?? -1, "maxActivations": maxActivations])
                
                completionHandler(false, serverResponse, error, urlResponse)
                return
            }
            
            /// Success!
            completionHandler(true, serverResponse, error, urlResponse)
        }
    }
    
    //
    // MARK: Core - lvl 1
    //
    
    /// Constants
    
    private static let productPermalink = "mmfinapp"
    
    /// Functions
    
    private static func getLicenseInfo(_ key: String, incrementUsageCount: Bool, completionHandler: @escaping (_ isValidKey: Bool, _ forEmail: String?, _ nOfActivations: Int?, _ serverResponse: [String: Any]?, _ error: Error?, _ urlResponse: URLResponse?) -> ()) {
        
        
        sendGumroadAPIRequest(method: "/licenses/verify",
                              args: ["product_permalink": productPermalink, "license_key": key, "increment_uses_count": incrementUsageCount ? "true" : "false"],
                              completionHandler: { data, error, urlResponse in
            
            /// Guard error
            
            if error != nil {
                completionHandler(false, nil, nil, data, error, urlResponse)
                return
            }
            
            /// Gather info from response dict
            ///     None of these should be null but we're checking the extracted data one level above.
            ///     (So it's maybe a little unnecessary that we extract data at all at this level)
            ///     TODO: Maybe we should consider merging lvl 1 and lvl 2 since lvl 2 really only does the data validation)
            
            let isValidKey = data?["success"] as? Bool ?? false
            let activations = data?["uses"] as? Int
            var email: String? = nil
            if let purchase = data?["purchase"] as? [AnyHashable: Any],
               let e = purchase["email"] as? String {
                
                email = e
            }
            
            /// Call completions handler
            completionHandler(isValidKey, email, activations, data, error, urlResponse)
        })
    }
    
    private static func decrementUsageCount(key: String, accessToken: String, completionHandler: @escaping (_ serverResponse: [String: Any]?, _ error: Error?, _ urlResponse: URLResponse?) -> ()) {
        
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
    
    private static func sendGumroadAPIRequest(method: String, args: [String: Any], completionHandler: @escaping (_ serverResponse: [String: Any]?, _ error: Error?, _ urlResponse: URLResponse?) -> ()) {
        
        /// Note: The response data never contains the secret access token, so you can print the return values for debugging
        
        /// Create request
        
        let request = gumroadAPIRequest(method: method, args: args)
        
        
        /// Send request

        let task = URLSession.shared.dataTask(with: request) { data, urlResponse, error in
            
            /// Handle response
            
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
                    let error = NSError(domain: MFLicensingErrorDomain, code: Int(kMFLicensingErrorCodeGumroadServerResponseError), userInfo: dict)
                    completionHandler(dict, error, urlResponse)
                    return
                }
                
                /// Success!
                /// Call the callback!
                completionHandler(dict, error, urlResponse)
                
            } catch {
                
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
//  Src: https://stackoverflow.com/a/26365148/10601702

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
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        
        var allowed: CharacterSet = .urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}
