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
    
    // MARK: Sensitivity
    
    @objc static var sensitivity: Double {
        
        return 1.3 /// Testing - Remove this
        
        config["sensitivity"] as! Double
    }
    
    // MARK: Acceleration
    
    private static var semanticAcceleration: SemanticAcceleration {
        return .medium
    }
    private static var useSystemAcceleration: Bool {
        false
    }
    @objc static var useLinearAccelerationCurve: Bool {
        true
    }
    
    @objc static var accelerationPresetIndex: Double {
        
        switch semanticAcceleration {
        case .off:
            return 0.0
        case .low:
            return 0.5
        case .medium:
            return 1.0
        case .high:
            return 2.0
        case .system:
            return UserDefaults.standard.double(forKey: "com.apple.mouse.scaling")
        }
    }
    @objc static var linearAccelerationCurve: MFAppleAccelerationCurveParams {
        /// TODO: Test these values and find good ones
        
        let minSens: Double
        let maxSens: Double
        let capSpeed: Double
        
        switch semanticAcceleration {
        case .off:
            minSens = 1
            maxSens = 1
            capSpeed = 8.0
        case .low:
            minSens = 1
            maxSens = 10
            capSpeed = 8.0
        case .medium:
            minSens = 1
            maxSens = 25
            capSpeed = 8.0
        case .high:
            minSens = 1
            maxSens = 40
            capSpeed = 8.0
        case .system:
            fatalError()
        }
        
        return linearAccelerationCurve(minSens: minSens, maxSens: maxSens, capSpeed: capSpeed)
    }
    
    private static func linearAccelerationCurve(minSens: Double, maxSens: Double, capSpeed: Double) -> MFAppleAccelerationCurveParams {
        
        /// Create curve based on params:
        ///     - minSens: Minimum sensitivity. Applied at inputSpeed = 0
        ///     - maxSens: maximum sensitivity. Applied at inputSpeed = capSpeed
        ///     - capSpeed: The inputSpeed at which to cap sensitivity
        ///
        /// The curves' derivate describes the relationship sens(inputSpeed). It will be linear, which should make it easier to get a feel for the curve. Gamers prefer these curves for better aim (src: the Guide for "raw accel" for Windows)
        ///
        /// Figured this out based on https://www.desmos.com/calculator/wcjoiuioxf
        
        let a = minSens
        let b = sqrt(maxSens-minSens) / (sqrt(2) * sqrt(capSpeed))
        
        return MFAppleAccelerationCurveParams(linearGain: a,
                                              parabolicGain: b,
                                              cubicGain: 0.0, /// Make cubic and quartic equal zero so the derivative is linear
                                              quarticGain: 0.0,
                                              capSpeedLinear: capSpeed,
                                              capSpeedParabolicRoot: capSpeed*100) /// Make this absurdly high so it never activates
        
    }
    
    private enum SemanticAcceleration {
        case off
        case low
        case medium
        case high
        case system
    }
}
