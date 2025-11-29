//
// --------------------------------------------------------------------------
// macOSConfiguration.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Sets settings to the system
/// UserDefaults doesn't allow writing to the global domain, that's why we need to use the `defaults` command-line-tool instead

/// Edit: Actually this won't work, because we have no way of telling the system to load from defaults. So the settings will only be applied when yuu restart the computer, making this not practical

/// Investigation of double clicks
/// - The only thing related to double clicks I could find so far in my local copy of IOKit is IOHIDEventProcessorFilter.cpp
///     IOHIDEventProcessorFilter does state machine stuff and handles double, triple, and long presses It seems to use the key kIOHIDKeyboardPressCountDoublePressTimeoutKey to determine the double click timeout However this key has "keyboard" in it's name suggesting that it doesn't work for mouse clicks.
/// - IOHIDEventService, IOHIDEventDriver and IOHIPointing don't seem to handle any clickLevel logic either
/// - Maybe there is some extra processing before the clickEvents are dispatched to userSpace. Maybe it has been redacted from IOKit source. Maybe it's in HIDSystem or HIDEventSystem or something, but I couldn't find anything
/// - Maybe the logic for determining doubleClicks is done by the windowServer in userSpace after it receives the IOHIDEvents from the kernel. This would be weird though.

import Cocoa

@objc class GlobalDefaults: NSObject {
    
    // MARK: Manage application of settings
    ///     - Apply settings when Mac Mouse Fix Helper starts / when settings change / whenever else it is appropriate
    ///     - Un-apply settings when Mac Mouse Fix Helper closes
    //      TODO: Implement this
    
    // MARK: Convenience
    
    @objc static func applyDoubleClickThreshold() {
        let newValue = NSNumber(value: GeneralConfig.doubleClickThreshold)
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
