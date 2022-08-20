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
    
    @objc static func checkLicense(_ key: String, incrementUsageCount: Bool, completionHandler: @escaping (_ isValid: Bool, _ error: Error?, _ serverResponse: [String: Any]?) -> ()) {
        
        /// Also see: https://stackoverflow.com/questions/26364914/http-request-in-swift-with-post-method
        
        /// Define strings
        let baseURL = "https://api.gumroad.com/v2/licenses/verify"
        let productPermalink = "mmfinapp"
        
        /// Create basic request
        var request = URLRequest(url: URL(string: baseURL)!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10.0)
        request.httpMethod = "POST"
        
        /// Set header fields
        ///     Probably unnecessary
        
        /// Make it use in-url params
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        /// Make it return a dict
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        /// Set message body
        
        /// Create query string
        ///     You can also do this using URLComponents API. but apparently it doesn't correctly escape '+' characters, so not using it.
        ///     Note: We're not escaping spaces and other weird characters here. This will break if we do! If so use https://stackoverflow.com/a/26365148/10601702
        let query = "product_permalink=\(productPermalink)&license_key=\(key)&increment_uses_count=\(incrementUsageCount ? "true" : "false")"
        
        /// set query string to request
        request.httpBody = query.data(using: .utf8)
        
        /// Send request

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            /// Handle response
            
            /// Guard null response
            
            guard
                let data = data,
                let _ = response,
                error == nil
            else {
                completionHandler(false, error, nil)
                return
            }
            
            do {
                
                /// Parse response as dict
                let dict: [String: Any] = try JSONSerialization.jsonObject(with: data) as! [String : Any]
                
                let success = dict["success"] as! Bool
                
                /// Call the callback!
                completionHandler(success, error, dict)
                
            } catch {
                
                /// Guard not convertible to dict
                completionHandler(false, error, nil) /// This is the `error` from the catch statement not the closure argument
            }
        }
        
        task.resume()
    }
}
