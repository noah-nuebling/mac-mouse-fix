//
// --------------------------------------------------------------------------
// PointerConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// This class provides pointer related settings. Primarily used by `PointerSpeed.m`. `PointerSpeed.m` configures Apple's HID driver to have different mouse sensitivity and acceleration curve. The implementation of the Apple driver that `PointerSpeed.m` configures can be found in `HIPointing.cpp` and in `IOHIDPointerScrollFilter.cpp`

/// **Polling rate compensation notes**
///
/// Edit: Polling rate is already accounted for in the newer macOS acceleration algorithm. See `IOHIDPointerAccelerator::accelerate`. But it's not done properly I think. (Judging from `IOKit source code (19.06.2021)`).  From my understanding, setting the `_rate` to the actual polling rate would only somewhat stabilize the acceleration when events are coming in slower or faster than the physical polling rate. But it wouldn't adjust the acceleration curve to be independent of polling rate.  Might still be have some benefits. Set via `kHIDPointerReportRateKey`
///
/// Apples driver doesn't take into account polling rate. When it measures device speed for its acceleration algorithm, it actually just uses the raw delta from the device and calls it speed. (Edit: This might not be the case for `IOHIDPointerScrollFilter.cpp`. See "More thoughts".)
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
/// - Measure time between callbacks for either CGEvents or IOHIDValues / IOHIDReports.
/// - Do some smart processing. Like throw away values that are too big / too far from the current estimated value. Or only take max values. Or only top 10 percent or something. Round to power/multiple of 2 because polling intervals are always multiples of 2 ms I think. maybe other smart stuff. Use the CGEvent's timestamp for accurate timing
///
/// More thoughts:
/// - Not sure it makes sense to expose this in the UI. Just do it automatically when not using "macOS" pointer speed.
/// - `IOHIDPointerScrollFilter.cpp` actually supports the key `kHIDPointerReportRateKey` but I'm not sure exactly how it is used or if it evens works and `HIPointing.cpp` doesn't support it at all. (Not sure if `HIPointing.cpp` is still used in any way or in which macOS version they switched to `IOHIDPointerScrollFilter.cpp`) It will be a problem if we compensate for reportRate even though it is already compensated for, but It don't think Apples compensation is working. In my system `kHIDPointerReportRateKey` is only set on the Trackpad driver not standard mouse drivers.


import Cocoa


class PointerConfig: NSObject {

    /// Reload from config dict
    @objc static func reload() {
        // TODO: Delete caches (if you use any)
    }
    
    /// Get pointer settings from config
    
    @objc private static var config: NSDictionary {
        Config.shared().configWithAppOverridesApplied[kMFConfigKeyPointer] as! NSDictionary
    }
    
    /// User settings
    
    private static var semanticSensitivity: SemanticSensitivity {
        return .test
    }
    private static var semanticAcceleration: SemanticAcceleration {
        return .test
    }
    
    private enum SemanticAcceleration {
        case test
        case off
        case low
        case medium
        case high
    }
    private enum SemanticSensitivity {
        case test
        case low
        case medium
        case high
    }
    
    /// Main
    
    // MARK: Polling rate compensation
    ///  See top of the file for explanation
    private static let basePollingRate = 125
    private static var actualPollingRate = 125
    private static var pollingRateRatio: Double {
        Double(actualPollingRate) / Double(basePollingRate)
    }
    
    // MARK: CPI compensation
    private static let baseCPI = 1000
    private static var actuaCPI = 1000
    private static var CPIRatio: Double {
        Double(actuaCPI) / Double(baseCPI)
    }
    
    // MARK: Sensitivity
    
    @objc static var CPIMultiplier: Double {
        
        let sens = 1.0
        /// ^ It's probably better to leave this at 1.0 and use our custom speed curve to control sensitivity instead. This is a factor on the mouse speed before it's passed to the acceleration algorithm. So the whole acceleration curve changes when you change this.  However that makes it perfect for compensating CPI.
        
        return sens * pollingRateRatio / CPIRatio
    }
    
    // MARK: Speed curve
    
    /// Constants
    @objc static var useParametricCurve: Bool = false /// Switch between table-based and parametric curve. Once parametric has been used you can't switch back until you detach the device.
    
    /// User defined params
    @objc static var u_speed: Double = 0.5
    @objc static var u_complexSettings: Bool = false /// Switch nbetwee using just `u_speed` or the fine-grained params below
    @objc static var u_minSens: Double = 1.0
    @objc static var u_maxSens: Double = 0.5
    @objc static var u_curvature: Double = 0.5
    @objc static var u_turnOffAcceleration: Bool = false
    @objc static var u_unacceleratedSens: Double = 1.0
    
    /// Generate curves
    @objc static var tableBasedCurve: [[Double]] {
        
        /// Debug - test mouse speed
//        let testCurve = TestAccelerationCurve(thresholdSpeed: 3.0, firstSens: 0.0, secondSens: 2.0)
//        let testTrace = testCurve.traceSpeed(startX: 0.0, endX: 20, nOfSamples: 1000, bias: 2.0)
//        return testTrace
        
        /// Declare curve params
        let v0: Double = 0.1
        let s0: Double
        let v1: Double = 10.0
        let s1: Double
        var n: Double
        
        /// Create userParams -> curveParams maps
        /// Simple settings maps
//        let lowSensMap = CombinedLinearCurve(yValues:    [1.25,  1.625,  2.0,    3.0,    4.0]) /// These are too fast
//        let highSensMap = CombinedLinearCurve(yValues:   [13.0,  18.0,   22.0,   30.0,   70.0])
//        let curveMap = CombinedLinearCurve(yValues:      [4.0,   3.0,    2.75,   2.58,    1.75])
        
        let lowSensMap = CombinedLinearCurve(yValues:    [0.5, 1.25, 1.875, 2.0,  3.0])
        let highSensMap = CombinedLinearCurve(yValues:   [7.0, 13.0, 18.0,  22.0, 30.0])
        let curveMap = CombinedLinearCurve(yValues:      [2.0, 2.25, 2.0,   2.75, 2.58])
        let speedMetaMap = CombinedLinearCurve(yValues: [0.0, 0.25, 0.40, 0.75, 1.0])
        /// Complex settings maps
        let lowSensMap2 = CombinedLinearCurve(yValues:    [0.5, 1.0, 2.0, 3.0, 4.0])
        let highSensMap2 = CombinedLinearCurve(yValues:   [6.0, 22.0, 70.0])
        let curveMap2 = CombinedLinearCurve(yValues:      [1.0, 2.0, 3.0])
        /// Unaccelerated map
        let lowSensMap3 = CombinedLinearCurve(yValues: [2.0, 3.0, 4.0])
        /// Meta map
        
        /// Get curve params from user params
        if !u_complexSettings { /// Simple settings
            let speed = speedMetaMap.evaluate(atX: u_speed)
            s0 = lowSensMap.evaluate(atX: speed)
            s1 = highSensMap.evaluate(atX: speed)
            n = curveMap.evaluate(atX: speed)
            if n > 3.0 { n = 3.0 }
        } else if u_turnOffAcceleration { /// No accel
            s0 = lowSensMap3.evaluate(atX: u_unacceleratedSens)
            s1 = s0
            n = 1.0
        } else { /// Complex settings
            s0 = lowSensMap2.evaluate(atX: u_minSens)
            s1 = highSensMap2.evaluate(atX: u_maxSens)
            n = curveMap2.evaluate(atX: u_curvature)
        }

        /// Sampling param
        let nSamp = 1000
        
        /// Create polynomialCurve
        // TODO: Move the degree interpolation into PolynomialCappedAccelerationCurve, and/or just use BezierCappeAccelerationCurve
        
        /// Assert
        assert(1 <= n && n <= 3) /// Larger curvature might be nice but our polynomial regression breaks for n > 3
        /// Get interpolation params
        let n0: Int = Int(floor(n))
        let n1: Int = Int(ceil(n))
        let nRatio: Double = n - Double(n0)
        
        /// Get trace
        var trace: [[Double]]
        if n0 != n1 {
            /// Get 2 traces and interpolate between them
            let curve0 = PolynomialCappedAccelerationCurve(lowSpeed: v0, lowSens: s0, highSpeed: v1, highSens: s1, curvature: n0)
            let curve1 = PolynomialCappedAccelerationCurve(lowSpeed: v0, lowSens: s0, highSpeed: v1, highSens: s1, curvature: n1)
            let trace0 = curve0.traceSpeed(nOfSamples: nSamp)
            let trace1 = curve1.traceSpeed(nOfSamples: nSamp)
            
            trace = zip(trace0, trace1).map { (p0, p1) in
                assert(p0[0] == p1[0])
                let x = p0[0]
                let y0 = p0[1]
                let y1 = p1[1]
                let y = (1-nRatio) * y0 + nRatio * y1
                return [x, y]
            }
            
        } else {
            /// Just get a single trace
            let curve = PolynomialCappedAccelerationCurve(lowSpeed: v0, lowSens: s0, highSpeed: v1, highSens: s1, curvature: n1)
            trace = curve.traceSpeed(nOfSamples: nSamp, allowSparseSampling: true)
        }
        
        /// Do Polling rate compensation
        trace = trace.map{ p in [p[0], p[1] / pollingRateRatio] }
        
        return trace
    }
    
    @objc static var parametricCurve: MFAppleAccelerationCurveParams {
        /// See "Gain Curve Math.tex" and PointerSpeed class for context
        
        let multiplier = 1.0
        
        /**
         Notes on highSpeed and lowSpeed:
            lowSpeed should be chosen so that lowSens is independent of other params (Not sure that's possible)
            highSpeed should be chosen so that it's the largest speed you can consiouscly input and differentiate from other speeds.
                - This seems to be 7.0.
                - When curvature is 1.0, it also makes sense to lower highSpeed to increase curvature even more. Then you can lower lowSens, while maintaining the same "mediumSens". But I feel that makes the curve less predictable somehow.
         */
        
        let lowSpeed = 0.2
        let highSpeed = 7.0
        
        var lowSens: Double
        var highSens: Double

        /**
         Notes on curvature:
            Larger Curvature:
                -> Bigger sens at medium speeds -> Less corrections and more comfort while tracking
                -> Smaller sens at small speeds -> Still able to make micromovements for selecting text
         */
        
        let curvature = 1.0
        let useSmoothCurvature = false
        
        /**
         Notes on sens:
            Larger Sens -> Less corrections while tracking
            4.5 largest sens that still allows comfortably selecting an 'I'
                (With curvature 1.0. Should be independent but at this point it's not)
            4.5 is stretching it a little. Even 3.5. is a little finicky.
         */
        
        switch semanticSensitivity {
        case .test:
            lowSens = 4.5 /*4.7*/
        case .low:
            lowSens = 2.0
        case .medium:
            lowSens = 3.0
        case .high:
            lowSens = 4.5
        }
        
        /**
         Notes on acc: (with curvature 1.0 and lowSens 4.5)
            Smaller Acc -> Less corrections while tracking
            10 -> Great accuracy, but little tedius
            13.5 -> Feels great. `3 * lowSens`.
            20 -> Veryyyy slightly less accuracy. Great comfort
            30 -> Starting to lose accuracy
         */
        
        switch semanticAcceleration {
        case .test:
            highSens = 20.0
        case .off:
            lowSens *= 2
            highSens = lowSens
        case .low:
            highSens = 15
        case .medium:
            highSens = 18
        case .high:
            highSens = 20
        }
        
        lowSens *= multiplier
        highSens *= multiplier

        return sensitivityBasedAccelCurve(lowSpeed: lowSpeed, lowSens: lowSens, highSpeed: highSpeed, highSens: highSens, curvature: curvature, useSmoothCurvature: useSmoothCurvature)
    }
    
    private static func sensitivityBasedAccelCurve(lowSpeed v_0: Double, lowSens s_0: Double, highSpeed v_1: Double, highSens s_1: Double, curvature c_unit: Double, useSmoothCurvature: Bool) -> MFAppleAccelerationCurveParams {
        
        // MARK: Notes on this
        
        /// This method can do everything we could want. All other accel curve generation functions should call this one.
        /// See `Gain Curve Math.tex` for more background
        
        // MARK: Notes on old versions (which were replaced by this one)
        
        /// Notes on `quartic` version of `lowSpeed` function
        ///     This here is an attempt to let the caller define a specific inputSpeed > 0 for which the sens = lowSens. While still making the curve as linear as possible
        ///         For the original function `sensitivityBasedAccelCurve(lowSens: Double, highSens: Double, highSpeed: Double, curvature: Double)` the low sens is always defined for inputSpeed 0. This is bad because you always move at a higher inputSpeed than 0 and so the perceived low sens changes when you change the high sens.
        ///     To achieve this we first define the points we want the curve to pass through, and then we use polynomial regression to find the coefficients
        ///         See https://www.desmos.com/calculator/v5ssuwpshx for the quartic regression
        ///     All the points are just on a straight line except for `p_1` which is capped at `p_1 >= 0`. (Otherwise the pointer moves backwards at very low speeds)
        ///     Why this doesn't work:
        ///         For the interesting cases, where the line is not straight, the curve slopes up for small x and back down for larger x. In these cases the fourth coefficient `d` is negative. However to bring the function from a normal polynomial into the shape of Apples acceleration curves `f(x) = ax + (bx)^2 + (cx)^3 + (dx)^4`, we need to take the fourth root of d. If d is negative this produces an imaginary number which the Apple driver can't process... :/.
        ///             I feel like there might be an equivalent curve where c is negative instead of d. But I have no idea how you would find that. Edit: I just played around with it and I think d has to be negative to fit the curve.
        
        /// Notes on `cubic` version of `lowSpeed` function
        /// Same idea as quartic. Since it's cubic we can't make the line as straight. But it also shouldn't produce imaginary coefficients.
        ///     See https://www.desmos.com/calculator/in835xa1lm
        
        /// Notes on `simpleLinearSensitivityBasedAccelCurve` curve.
        /// These names are getting out of hand.
        /// Idea: Reduce the number of parameters so it's easier for user to configure. Could have just 2 sliders to completely control the curve:
        ///     1. Slider: Sensitivity. The CPI compensation would be a 'secret' feature of this. Most users won't think about the CPI and just choose something that feels good. This slider changes the acceleration as well because it controls the pointerResolution on the driver. So it removes the need for a separate CPI compensation option.
        ///     2. Slider: Acceleration. This controls the slope of the linear sensitivity curve.
        ///     Notes:
        ///         The `lowSpeed` parameter from older curves is included in the sensitivity.
        ///         We simply disable the cap by setting it very high.
        ///    Discussion
        ///     - Speaking in terms of the old curve this means the highSens changes with the lowSens (aka sensitivity) but also the lowSens changes with the highSens. Making the lowSens and the highSens completely independent was the main goal of the `linearSensitivityBasedAccelCurve()` not sure if removing CPI compensation option or making lowSens and highSens settings independent will make for better user experience (don't have a mouse right now.)
        ///     - Also, no accel setting would naturally be support, by just setting slope to 0.
        /// See https://www.desmos.com/calculator/xoxabcofrr
        
        /// Validate
        assert(-1 <= c_unit && c_unit <= 1)
        
        /// Get params
        
        var c: Double
        
        let c_max =     root(s_0 - s_1, 3) / root(pow(v_0, 2) - 2 * v_1 * v_0 +     pow(v_1, 2), 3)
        let c_smooth =  root(s_0 - s_1, 3) / root(pow(v_0, 2) - 3 * v_1 * v_0 + 2 * pow(v_1, 2), 3)
        
        if useSmoothCurvature {
            c = c_smooth
        } else {
            c = c_max * c_unit
        }
        
        var b = sqrt( (s_0 - s_1 - pow(c, 3) * (pow(v_0, 2) - pow(v_1, 2))) / (v_0 - v_1) )
        var a = s_1 + v_1 * (v_0 * pow(c, 3) - (s_0-s_1)/(v_0-v_1))
        
        /// Validate
        
        assert(a >= 0, "Invalid sensitivity curve. Initial sensitivity is negative.")
        
        /// Polling rate compensation
        
        a /= pollingRateRatio
        b /= pow(pollingRateRatio, 1/2)
        c /= pow(pollingRateRatio, 1/3)
        
        /// Return
        return MFAppleAccelerationCurveParams(linearGain: a,
                                       parabolicGain: b,
                                       cubicGain: c,
                                       quarticGain: 0,
                                       capSpeedLinear: v_1,
                                       capSpeedParabolicRoot: v_1*1000)
        
        
        
    }
    
    private static func simpleSensitivityBasedAccelCurve(lowSpeed v_0: Double, lowSens s_0: Double, slope: Double, curvature: Double) -> MFAppleAccelerationCurveParams {
        
        /// Convenience wrapper. Probably super unnecessary.
        
        let line = Line(p: .init(x: v_0, y: s_0), slope: slope)
        let v_1 = 50.0 /// Pretty arbitrary. Making this very high makes cap at capSpeedLinear not set in.
        let s_1 = line.evaluate(at: v_1)
        
        return sensitivityBasedAccelCurve(lowSpeed: v_0, lowSens: s_0, highSpeed: v_1, highSens: s_1, curvature: curvature, useSmoothCurvature: false)
    }
    
    // MARK: - Master switch
    
    @objc static var useSystemSpeed: Bool {
        return false
    }
    @objc static var systemSensitivity: Double  = 1.0
    @objc static var systemAccelCurveIndex: Double {
        
        /// When `com.apple.mouse.scaling` is unset, `UserDefaults.standard.double` returns `0`, which represents nil.
        /// This will set pointer speed to minimum, instead of the hardcoded default `0.6875`.
        
        if UserDefaults.standard.object(forKey: "com.apple.mouse.scaling") != nil {
            return UserDefaults.standard.double(forKey: "com.apple.mouse.scaling")
        }
        else {
            return 0.6875
        }
    }
    @objc static var systemAccelCurves: NSArray = {
        /// By default, AppleUserHIDEventDriver instances don't have any "HIDAccelCurves" key (aka kHIDAccelParametricCurvesKey) in it's properties. When we set curves for the "HIDAccelCurves", the driver will use them though!
        /// However, we've found no way to remove keys from IORegistryEntries. (You can also set the curves on an AppleUserHIDEventDriver's IOHIDServiceClient, which has the same effect as setting it on the RegistryEntry, but there is no way to remove keys using the IOHIDServiceClient APIs either.) - so there is no easy way to go back to the systm's default acceleration curves.
        /// I have no idea where the AppleUserHIDEventDriver even gets it's curves from, when the "HIDAccelCurves" key isn't set. The source code (IOHIPointing.cpp or IOHIDPointerScrollFilter.cpp) says that there is a fallback to using lookup tables for the acceleration if no parametric curves are defined. But there is no key for the lookup table either! So I have no idea where the curves come from.
        /// IOHIDPointerScrollFilter.cpp also tries to load "user curves" using the key kIOHIDUserPointerAccelCurvesKey. But it that constant not defined anywhere public. I found a definition deep inside github but setting curves to that value doesn't do anything.
        /// However, instances of AppleUserHIDEventDriver driving **keyboards** do have the "HIDAccelCurves" key set for some godforsaken reason. You can see it in the IORegistry. Those same curves are defined in  `/System/Library/Extensions/IOHIDFamily.kext/Contents/PlugIns/IOHIDEventDriver.kext/Contents/Info.plist` I think that's where the IORegsitryEntry property is loaded from.
        /// Even though these curves are defined for keyboard drivers, they feel perfect when you set them for the "HIDAccelCurves" key on a mouse driver instance. Exactly like the default acceleration if you hadn't set "HIDAccelCurves" as far as I can tell.
        /// This is a really ugly solution, but it should work and I don't know what else to try.
        
        var result: NSArray
        
        let pathToPlist = "/System/Library/Extensions/IOHIDFamily.kext/Contents/PlugIns/IOHIDEventDriver.kext/Contents/Info.plist"
        let urlToPlist = URL(fileURLWithPath: pathToPlist)
        do {
            
            var plist: NSDictionary = try NSDictionary(contentsOf: urlToPlist, error: ())
            
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
    
    /// Helper
    ///     TODO: Put this in a utility class
    
    static let FixedOne:IOFixed = 0x00010000
    static func FloatToFixed(_ input: Double) -> IOFixed {
        return IOFixed(round(input * Double(FixedOne)))
    }
}
