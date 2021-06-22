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
//        config["sensitivity"] as! Double
        10.0 /// Testing
    }
    
    @objc static var acceleration: Double {
//        config["acceleration"] as! Double
        0.5 /// Testing
    }
    
}
