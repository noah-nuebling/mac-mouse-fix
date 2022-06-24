//
// --------------------------------------------------------------------------
// PointerConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// This class provides pointer related settings. Primarily used by `PointerSpeed.m`. `PointerSpeed.m` configures Apple's HID driver to have different mouse sensitivity and acceleration curve. The implementation of the Apple code can be found in `HIPointing.cpp`

/// Polling rate compensation notes:
///
/// Apples driver doesn't take into account polling rate. When it measures device speed for its acceleration algorithm, it actually just uses the raw delta from the device and calls it speed.
///     Problem is that at equivalent movement speed and CPI, a mouse with a 2x polling rate will only have 0.5x magnitude in its raw deltas. This means the acceleration curve won't kick in properly.
///     However we have come up with a mechanism to compensate for this, so that the acceleration curve behaves the same for all devices regardless of polling rate.
///
/// - Base everything around standard polling rate. Let's say 125, because that's what most of my Logitech mice have.
/// - Let's say current device has polling rate 250
/// - 1. Multiply sensitivity by 250/125 = 2
///     - Because If the polling rate is twice as high, then the report deltas will be half as big → make acc kick in properly by multiplying with 2. (Remember that the sensitivity is a multiplier on the raw device deltas before they are passed to the acceleration curve.)
/// - 2. Divide acc curve `f(x) = ax + (bx)^2` by 2.
///     → New coefficients are a' = a/2 and b' = b/sqrt(2)
///     - Because there are twice as many events at rate = 1000 compared to 500. So we need to divide the output delta by 2 to get the same overall distance
///
/// How to get polling rate:
///
/// - Measure time between callbacks for either CGEvents or IOHIDValues / IOHIDReports.
/// - Do some smart processing. Like throw away values that are too big / too far from the current estimated value. Or only take max values. Or only top 10 percent or something. Round to power/multiple of 2 because polling intervals are always multiples of 2 I think. maybe other smart stuff.
///
/// More thoughts:
///
/// Not sure it makes sense to expose this in the UI. Just do it automatically when not using "macOS" pointer speed


import Cocoa

class PointerConfig: NSObject {

    /// Get pointer settings from config
    
    @objc private static var config: NSDictionary {
        Config.configWithAppOverridesApplied()[kMFConfigKeyPointer] as! NSDictionary
    }
    
    /// Main
    
    // MARK: Polling rate compensation
    ///  See top of the file for explanation
    
    private static let basePollingRate = 125
    private static var actualPollingRate = 500
    private static var pollingRateFactor: Double {
        Double(actualPollingRate) / Double(basePollingRate)
    }
    
    // MARK: Sensitivity
    
    @objc static var sensitivity: Double {
        
        let sens = 1.3
        
        return sens * pollingRateFactor
    }
    
    // MARK: Acceleration
    
    private static var semanticAcceleration: SemanticAcceleration {
        return .medium
    }
    private static var useSystemAccelerationCurve: Bool {
        false
    }
    
    @objc static var systemAccelerationCurvePresetIndex: Double {
        
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
        
        var a = minSens
        var b = sqrt(maxSens-minSens) / (sqrt(2) * sqrt(capSpeed))
        a /= pollingRateFactor
        b /= sqrt(pollingRateFactor)
        
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
