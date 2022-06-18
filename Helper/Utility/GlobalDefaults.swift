//
// --------------------------------------------------------------------------
// macOSConfiguration.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// Sets settings to the system
/// UserDefaults doesn't allow writing to the global domain, that's why we need to use the `defaults` command-line-tool instead

import Cocoa
import CocoaLumberjackSwift

@objc class GlobalDefaults: NSObject {
    
    // MARK: Manage application of settings
    ///     - Apply settings when Mac Mouse Fix Helper starts / when settings change / whenever else it is appropriate
    ///     - Un-apply settings when Mac Mouse Fix Helper closes
    
    // TODO: Implement application of settings
    
    // MARK: Convenience
    
    @objc static func applyDoubleClickThreshold() {
        let newValue = NSNumber(value: OtherConfig.doubleClickThreshold)
        write(value: newValue, atKey: "com.apple.mouse.doubleClickThreshold")
    }

    // MARK: Core
    
    private static let defaultsURL = URL(string: "file:///usr/bin/defaults")!
    
    @objc static func write(value: AnyObject, atKey key: String) {
        
        let args = ["write", ".GlobalPreferences", key, "\(value)"]
        let err: NSErrorPointer = NSErrorPointer(nil)
        let result = SharedUtility.launchCLT(defaultsURL, withArguments: args, error: err)
        
        if err != nil {
            DDLogError("Write to global result: \(result), error: \(String(describing: err))")
        }
            
    }
    @objc static func read(atKey key: String) -> String {
        
        let args = ["read", ".GlobalPreferences", key]
        let err: NSErrorPointer = NSErrorPointer(nil)
        let result = SharedUtility.launchCLT(defaultsURL, withArguments: args, error: err)
        
        if err != nil {
            DDLogError("Read from global result: \(result), error: \(String(describing: err))")
        }
        
        return result
    }
}
