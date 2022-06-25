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
import CocoaLumberjackSwift

class PointerConfig: NSObject {

    /// Get pointer settings from config
    
    @objc private static var config: NSDictionary {
        Config.configWithAppOverridesApplied()[kMFConfigKeyPointer] as! NSDictionary
    }
    
    /// Main
    
    // MARK: Polling rate compensation
    ///  See top of the file for explanation
    
    private static let basePollingRate = 125
    private static var actualPollingRate = 90
    private static var pollingRateFactor: Double {
        Double(actualPollingRate) / Double(basePollingRate)
    }
    
    // MARK: Sensitivity (CPI compensation)
    
    @objc static var sensitivity: Double {
        
        let sens = 1.0
        
        return sens * pollingRateFactor
    }
    
    // MARK: Acceleration curve
    
    private static var semanticAcceleration: SemanticAcceleration {
        return .test
    }
    @objc static var useSystemAcceleration: Bool {
        return false
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
        case .test:
            return UserDefaults.standard.double(forKey: "com.apple.mouse.scaling")
        case .system:
            return UserDefaults.standard.double(forKey: "com.apple.mouse.scaling")
        }
    }
    
    @objc static var customAccelerationCurve: MFAppleAccelerationCurveParams {
        /// See Gain Curve Math.tex and PointerSpeed class for context
        
        let lowSens: Double
        let highSens: Double
        let highSpeed: Double
        let curvature: Double
        
        switch semanticAcceleration {
        case .test:
            lowSens = 0.6
            highSens = 9
            highSpeed = 7.0
            curvature = 0.0
            //----------
//            minSens = 1.0 /* 0.5 */
//            maxSens = 8
//            capSpeed = 3.0
            //----------
//            minSens = 1
//            maxSens = 80.0
//            capSpeed = 30.0
        case .off:
            lowSens = 1
            highSens = 1
            highSpeed = 8.0
            curvature = 1.0
        case .low:
            lowSens = 1
            highSens = 10
            highSpeed = 8.0
            curvature = 1.0
        case .medium:
            lowSens = 1
            highSens = 25
            highSpeed = 8.0
            curvature = 1.0
        case .high:
            lowSens = 1
            highSens = 40
            highSpeed = 8.0
            curvature = 1.0
        case .system:
            fatalError()
        }
        
        return sensitivityBasedAccelerationCurve(lowSens: lowSens, highSens: highSens, highSpeed: highSpeed, curvature: curvature)
    }
    
    private static func sensitivityBasedAccelerationCurve(lowSens: Double, highSens: Double, highSpeed: Double, curvature: Double) -> MFAppleAccelerationCurveParams {
        
        /// See `Gain Curve Maths.tex` for background
        
        assert(-1 <= curvature && curvature <= 1)
        
        var a: Double = lowSens
        let cCap = Math.nthroot(value: a-highSens, 3)/pow(highSpeed, 2/3)
        var c: Double = curvature * cCap
        var b: Double = sqrt(-a + pow(c, 3) * -pow(highSpeed, 2) + highSens)/sqrt(highSpeed)
        
        a /= pollingRateFactor
        b /= pow(pollingRateFactor, 1/2)
        c /= pow(pollingRateFactor, 1/3)
        
        return MFAppleAccelerationCurveParams(linearGain: a,
                                              parabolicGain: b,
                                              cubicGain: c,
                                              quarticGain: 0.0,
                                              capSpeedLinear: highSpeed,
                                              capSpeedParabolicRoot: highSpeed*100) /// Make this absurdly high so it never activates
        
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
        case test
        case system
    }
    
    @objc static var defaultAccelCurves: NSArray = {
        /// By default AppleUserHIDEventDriver instances don't have any "HIDAccelCurves" key (aka kHIDAccelParametricCurvesKey) in it's properties. When we set curves for the "HIDAccelCurves", the driver will use them though!
        /// However, we've found no way to remove keys from IORegistryEntries. (You can also set the curves on an AppleUserHIDEventDriver IOHIDServiceClient, which has the same effect as setting it on the RegistryEntry, but there is no way to remove keys in the IOHIDServiceClient APIs either.) - so there is no easy way to go back to the systm's default acceleration curves.
        /// I have no idea where the AppleUserHIDEventDriver even gets it's curves from when the "HIDAccelCurves" key isn't set. The source code (IOHIPointing.cpp or IOHIDPointerScrollFilter.cpp) says that there is a fallback to using lookup tables for the acceleration if no parametric curves are defined. But there is no key for the lookup table either! So I have no idea where the curves come from
        /// IOHIDPointerScrollFilter.cpp also tries to load "user curves" using the key kIOHIDUserPointerAccelCurvesKey. But it's not defined anywhere public. I found a definition deep inside github but setting curves to that value doesn't do anything.
        /// However, instances of AppleUserHIDEventDriver driving **keyboards** do have the "HIDAccelCurves" key set for some godforsaken reason. Those same curves are defined in  `/System/Library/Extensions/IOHIDFamily.kext/Contents/PlugIns/IOHIDEventDriver.kext/Contents/Info.plist` I think that's where they are loaded from.
        /// Even though these curves are defined on the keyboard driver, they feel perfect when you set them for the "HIDAccelCurves" key on a mouse driver instance. Exactly like the default acceleration if you hadn't set "HIDAccelCurves" as far as I can tell.
        /// This is a really ugly solution, but it's the best I can come up with.
        
        var result: NSArray
        
        let pathToPlist = "/System/Library/Extensions/IOHIDFamily.kext/Contents/PlugIns/IOHIDEventDriver.kext/Contents/Info.plist"
        let urlToPlist = URL(fileURLWithPath: pathToPlist)
        do {
            
            var plist: NSDictionary = [:]
            if #available(macOS 10.13, *) {
                plist = try NSDictionary(contentsOf: urlToPlist, error: ())
            } else {
                guard let _plist = NSDictionary(contentsOf: urlToPlist) else {
                    throw NSError()
                }
                plist = _plist
            }
            
            guard let _result = plist.value(forKeyPath: "IOKitPersonalities.HID Keyboard Driver.HIDAccelCurves") as? NSArray else {
                throw NSError()
            }
            result = _result
        }
        catch {
            
            DDLogWarn("Failed to load default pointer accel curves from library. Falling back to hardcoded curves.")
            
            /// Fallback to hardcoded
            ///     Copied this by hand. Might've made a mistake.
            result = [
                [ /// Item 0
                    kHIDAccelIndexKey: FloatToFixed(0.0),
                    kHIDAccelGainLinearKey: FloatToFixed(1.0),
                    kHIDAccelGainParabolicKey: FloatToFixed(0.0),
                    kHIDAccelGainCubicKey: FloatToFixed(0.0),
                    kHIDAccelGainQuarticKey: FloatToFixed(0.0),
                    kHIDAccelTangentSpeedLinearKey: FloatToFixed(8.0),
                    kHIDAccelTangentSpeedParabolicRootKey: FloatToFixed(0.0),
                ],
                [ /// Item 1
                    kHIDAccelGainCubicKey: 5243,
                    kHIDAccelGainLinearKey: 60293,
                    kHIDAccelGainParabolicKey: 26214,
                    kHIDAccelIndexKey: 8192,
                    kHIDAccelTangentSpeedLinearKey: 537395,
                    kHIDAccelTangentSpeedParabolicRootKey: 1245184,
                ],
                [ /// Item 2
                    kHIDAccelGainCubicKey: 6554,
                    kHIDAccelGainLinearKey: 60948,
                    kHIDAccelGainParabolicKey: 36045,
                    kHIDAccelIndexKey: 32768,
                    kHIDAccelTangentSpeedLinearKey: 543949,
                    kHIDAccelTangentSpeedParabolicRootKey: 1179648,
                ],
                [ /// Item 3
                    kHIDAccelGainCubicKey: 7864,
                    kHIDAccelGainLinearKey: 61604,
                    kHIDAccelGainParabolicKey: 46531,
                    kHIDAccelIndexKey: 45056,
                    kHIDAccelTangentSpeedLinearKey: 550502,
                    kHIDAccelTangentSpeedParabolicRootKey: 1114112,
                ],
                [ /// Item 4
                    kHIDAccelGainCubicKey: 9830,
                    kHIDAccelGainLinearKey: 62259,
                    kHIDAccelGainParabolicKey: 57672,
                    kHIDAccelIndexKey: 57344,
                    kHIDAccelTangentSpeedLinearKey: 557056,
                    kHIDAccelTangentSpeedParabolicRootKey: 1048576,
                ],
                [ /// Item 5
                    kHIDAccelGainCubicKey: 11796,
                    kHIDAccelGainLinearKey: 62915,
                    kHIDAccelGainParabolicKey: 69468,
                    kHIDAccelIndexKey: 65536,
                    kHIDAccelTangentSpeedLinearKey: 563610,
                    kHIDAccelTangentSpeedParabolicRootKey: 983040,
                ],
                [ /// Item 6
                    kHIDAccelGainCubicKey: 14418,
                    kHIDAccelGainLinearKey: 63570,
                    kHIDAccelGainParabolicKey: 81920,
                    kHIDAccelIndexKey: 98304,
                    kHIDAccelTangentSpeedLinearKey: 570163,
                    kHIDAccelTangentSpeedParabolicRootKey: 917504,
                ],
                [ /// Item 7
                    kHIDAccelGainCubicKey: 17695,
                    kHIDAccelGainLinearKey: 64225,
                    kHIDAccelGainParabolicKey: 95027,
                    kHIDAccelIndexKey: 131072,
                    kHIDAccelTangentSpeedLinearKey: 576717,
                    kHIDAccelTangentSpeedParabolicRootKey: 851968,
                ],
                [ /// Item 8
                    kHIDAccelGainCubicKey: 21627,
                    kHIDAccelGainLinearKey: 64881,
                    kHIDAccelGainParabolicKey: 108790,
                    kHIDAccelIndexKey: 163840,
                    kHIDAccelTangentSpeedLinearKey: 583270,
                    kHIDAccelTangentSpeedParabolicRootKey: 786432,
                ],
                [ /// Item 9
                    kHIDAccelGainCubicKey: 26214,
                    kHIDAccelGainLinearKey: 65536,
                    kHIDAccelGainParabolicKey: 123208,
                    kHIDAccelIndexKey: 196608,
                    kHIDAccelTangentSpeedLinearKey: 589824,
                    kHIDAccelTangentSpeedParabolicRootKey: 786432,
                ],
            ]
        }
        return result
    }()
    
    static let FixedOne:IOFixed = 0x00010000
    static func FloatToFixed(_ input: Double) -> IOFixed {
        return IOFixed(round(input * Double(FixedOne)))
    }
}
