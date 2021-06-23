//
// --------------------------------------------------------------------------
// PointerConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

class PointerConfig: NSObject {

    /// Get pointer settings from config
    
    @objc private static var config: NSDictionary {
        Config.configWithAppOverridesApplied()[kMFConfigKeyPointer] as! NSDictionary
    }
    
    /// Main
    
    @objc static var sensitivity: Double {
        
        return 1.3 /// Testing - Remove this
        
        config["sensitivity"] as! Double
    }
    @objc static var acceleration: Double {
        
        return 0.5 /// Testing - Remove this
        
        if useSystemAcceleration {
            return UserDefaults.standard.double(forKey: "com.apple.mouse.scaling")
        } else {
            return config["acceleration"] as! Double
        }
    }
    @objc private static var useSystemAcceleration: Bool {
        config["useSystemAcceleration"] as! Bool
    }
}
