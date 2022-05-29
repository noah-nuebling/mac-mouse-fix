//
// --------------------------------------------------------------------------
// ScrollConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa
import CocoaLumberjackSwift

@objc class ScrollConfig: NSObject, NSCopying /*, NSCoding*/ {
    
    
    
    /// This class has almost all instance properties
    /// You can request the config once, then store it.
    /// You'll receive an independent instance that you can override with custom values. This should be useful for implementing Modifications in Scroll.m
    ///     Everything in ScrollConfigResult is lazy so that you only pay for what you actually use
    
    // MARK: Class functions
    
    private(set) static var config = ScrollConfig() /// Singleton instance
    @objc static var copyOfConfig: ScrollConfig { config.copy() as! ScrollConfig }
    @objc static func deleteCache() { /// This should be called when the underlying config (which mirrors the config file) changes
        config = ScrollConfig() /// All the property values are cached in `currentConfig`, because the properties are lazy. Replacing with a fresh object deletes this implicit cache.
    }
    
    @objc static var linearCurve: Bezier = { () -> Bezier in
        
        typealias P = Bezier.Point
        let controlPoints: [P] = [P(x:0,y:0), P(x:0,y:0), P(x:1,y:1), P(x:1,y:1)]
        
        return Bezier(controlPoints: controlPoints, defaultEpsilon: 0.001) /// The default defaultEpsilon 0.08 makes the animations choppy
    }()
    
    @objc static var stringToEventFlagMask: NSDictionary = ["command" : CGEventFlags.maskCommand,
                                                            "control" : CGEventFlags.maskControl,
                                                            "option" : CGEventFlags.maskAlternate,
                                                            "shift" : CGEventFlags.maskShift]
    
    // MARK: Convenience functions
    ///     For accessing top level dict and different sub-dicts
    
    private var topLevel: NSDictionary {
        Config.configWithAppOverridesApplied()[kMFConfigKeyScroll] as! NSDictionary
    }
    private var other: NSDictionary {
        topLevel["other"] as! NSDictionary
    }
    private var smooth: NSDictionary {
        topLevel["smoothParameters"] as! NSDictionary
    }
    private var mod: NSDictionary {
        topLevel["modifierKeys"] as! NSDictionary
    }
    
    // MARK: General
    
    @objc lazy var smoothEnabled: Bool = true /* ScrollConfig.topLevel["smooth"] as! Bool */
    @objc lazy var disableAll: Bool = false /* topLevel["disableAll"] as! Bool */ /// This is currently unused. Could be used as a killswitch for all scrolling Interception
    
    // MARK: Invert Direction
    
    @objc func scrollInvert(event: CGEvent) -> MFScrollInversion {
        /// This can be used as a factor to invert things. kMFScrollInversionInverted is -1.
        
        if self.semanticScrollInvertUser == self.semanticScrollInvertSystem(event) {
            return kMFScrollInversionNonInverted
        } else {
            return kMFScrollInversionInverted
        }
    }
    lazy private var semanticScrollInvertUser: MFSemanticScrollInversion = kMFSemanticScrollInversionNormal /* MFSemanticScrollInversion(ScrollConfig.topLevel["naturalDirection"] as! UInt32) */
    private func semanticScrollInvertSystem(_ event: CGEvent) -> MFSemanticScrollInversion {
        
        /// Accessing userDefaults is actually surprisingly slow, so we're using NSEvent.isDirectionInvertedFromDevice instead... but NSEvent(cgEvent:) is slow as well...
        ///     .... So we're using our advanced knowledge of CGEventFields!!!
        
        
//            let isNatural = UserDefaults.standard.bool(forKey: "com.apple.swipescrolldirection") /// User defaults method
//            let isNatural = NSEvent(cgEvent: event)!.isDirectionInvertedFromDevice /// NSEvent method
        let isNatural = event.getIntegerValueField(CGEventField(rawValue: 137)!) != 0; /// CGEvent method
        
        return isNatural ? kMFSemanticScrollInversionNatural : kMFSemanticScrollInversionNormal
    }
    
    // MARK: Analysis
    
    @objc lazy var scrollSwipeThreshold_inTicks: Int = 2 /*other["scrollSwipeThreshold_inTicks"] as! Int;*/ /// If `scrollSwipeThreshold_inTicks` consecutive ticks occur, they are deemed a scroll-swipe.
    
    @objc lazy var fastScrollThreshold_inSwipes: Int = 4 /*other["fastScrollThreshold_inSwipes"] as! Int*/ /// On the `fastScrollThreshold_inSwipes`th consecutive swipe, fast scrolling kicks in
    
    @objc lazy var scrollSwipeMax_inTicks: Int = 9 /// Max number of ticks that we think can occur in a single swipe naturally (if the user isn't using a free-spinning scrollwheel). (See `consecutiveScrollSwipeCounter_ForFreeScrollWheel` definition for more info)
    
    @objc lazy var consecutiveScrollTickIntervalMax: TimeInterval = 160/1000
    /// ^ If more than `_consecutiveScrollTickIntervalMax` seconds passes between two scrollwheel ticks, then they aren't deemed consecutive.
    ///        other["consecutiveScrollTickIntervalMax"] as! Double;
    ///     msPerStep/1000 <- Good idea but we don't want this to depend on msPerStep
    
    @objc lazy var consecutiveScrollTickIntervalMin: TimeInterval = 15/1000
    /// ^ 15ms seemst to be smallest scrollTickInterval that you can naturally produce. But when performance drops, the scrollTickIntervals that we see can be much smaller sometimes.
    ///     This variable can be used to cap the observed scrollTickInterval to a reasonable value
    
    
    @objc lazy var consecutiveScrollSwipeMaxInterval: TimeInterval = 350/1000
    /// ^ If more than `_consecutiveScrollSwipeIntervalMax` seconds passes between two scrollwheel swipes, then they aren't deemed consecutive.
    ///        other["consecutiveScrollSwipeIntervalMax"] as! Double
    
    @objc lazy private var consecutiveScrollTickInterval_AccelerationEnd: TimeInterval = 15/1000
    /// ^ Used to define accelerationCurve. If the time interval between two ticks becomes less than `consecutiveScrollTickInterval_AccelerationEnd` seconds, then the accelerationCurve becomes managed by linear extension of the bezier instead of the bezier directly.
    
    @objc lazy var ticksPerSecond_DoubleExponentialSmoothing_InputValueWeight: Double = 0.5
    
    @objc lazy var ticksPerSecond_DoubleExponentialSmoothing_TrendWeight: Double = 0.2
    
    @objc lazy var ticksPerSecond_ExponentialSmoothing_InputValueWeight: Double = 0.5
    /// ^       1.0 -> Turns off smoothing. I like this the best
    ///     0.6 -> On larger swipes this counteracts acceleration and it's unsatisfying. Not sure if placebo
    ///     0.8 ->  Nice, light smoothing. Makes  scrolling slightly less direct. Not sure if placebo.
    ///     0.5 -> (Edit) I prefer smoother feel now in everything. 0.5 Makes short scroll swipes less accelerated which I like
    
    // MARK: Fast scroll
    
    @objc lazy var fastScrollExponentialBase = 1.35 /* other["fastScrollExponentialBase"] as! Double; */
    /// ^ How quickly fast scrolling gains speed.
    ///     Used to be 1.1 before scroll rework. Why so much higher now?
    
    
    @objc lazy var fastScrollFactor = 1.0 /*other["fastScrollFactor"] as! Double*/
    /// ^ With the introduction of fastScrollScale, this should always be 1.0
    
    @objc lazy var fastScrollScale = 0.3
    
    // MARK: Animation curve
    
    /// Define storage class for animationCurve params
    
    @objc class MFScrollAnimationCurveParameters: NSObject { /// Does this have to inherit from NSObject?
        
        /// baseCurve params
        @objc let msPerStep: Int
        @objc let baseCurve: Bezier?
        /// dragCurve params
        @objc let dragExponent: Double
        @objc let dragCoefficient: Double
        @objc let stopSpeed: Int
        /// Other params
        @objc let sendMomentumScrolls: Bool /// This will make Scroll.m send momentumScroll events (what the Apple Trackpad sends after lifting your fingers off) when scrolling is controlled by the dragCurve. Use this when the dragCurve closely mimicks the Apple Trackpad.
        
        /// Init
        required init(msPerStep: Int, baseCurve: Bezier?, dragExponent: Double, dragCoefficient: Double, stopSpeed: Int, sendMomentumScrolls: Bool) { /// Why can't Swift autogenerate this, absolut UNPROGRAMMIERBAR
            self.msPerStep = msPerStep
            self.baseCurve = baseCurve
            self.dragExponent = dragExponent
            self.dragCoefficient = dragCoefficient
            self.stopSpeed = stopSpeed
            self.sendMomentumScrolls = sendMomentumScrolls
        }
    }
    
    /// Define function that maps preset -> params
    
    @objc func animationCurveParams(forPreset preset: MFScrollAnimationCurvePreset) -> MFScrollAnimationCurveParameters {
        
        /// For the origin behind these presets see ScrollConfigTesting.md
        /// @note I just checked the formulas on Desmos, and I don't get how this can work with 0.7 as the exponent? (But it does??) If the value is `< 1.0` that gives a completely different curve that speeds up over time, instead of slowing down.
        
        switch preset {
            
        /// User selected
            
        case kMFScrollAnimationCurvePresetLowInertia:
            return MFScrollAnimationCurveParameters(msPerStep: 140, baseCurve: ScrollConfig.linearCurve, dragExponent: 1.0, dragCoefficient: 23, stopSpeed: 50, sendMomentumScrolls: false)
            
        case kMFScrollAnimationCurvePresetMediumInertia:
            return MFScrollAnimationCurveParameters(msPerStep: 180, baseCurve: ScrollConfig.linearCurve, dragExponent: 1.1, dragCoefficient: 10, stopSpeed: 50, sendMomentumScrolls: false)
            
        case kMFScrollAnimationCurvePresetHighInertia:
            /// Snappiest curve that can be used to send momentumScrolls.
            ///    If you make it snappier then it will cut off the build-in momentumScroll in apps like Xcode
            return MFScrollAnimationCurveParameters(msPerStep: 205, baseCurve: ScrollConfig.linearCurve, dragExponent: 0.7, dragCoefficient: 40, stopSpeed: 50, sendMomentumScrolls: true)
            
        /// Dynamically applied
            
        case kMFScrollAnimationCurvePresetTouchDriver:
            return MFScrollAnimationCurveParameters(msPerStep: 140, baseCurve: ScrollConfig.linearCurve, dragExponent: 1.0, dragCoefficient: 23, stopSpeed: 50, sendMomentumScrolls: false)
            
        case kMFScrollAnimationCurvePresetTouchDriverLinear:
            /// "Disable" the dragCurve by setting the dragCoefficient to an absurdly high number. This creates a linear curve. This is not elegant or efficient -> Maybe refactor this (have a bool `usePureBezier` or sth to disable the dragCurve)
            return MFScrollAnimationCurveParameters(msPerStep: 180, baseCurve: ScrollConfig.linearCurve, dragExponent: 1.0, dragCoefficient: 99999, stopSpeed: 99999, sendMomentumScrolls: false)
        
        case kMFScrollAnimationCurvePresetQuickScroll:
            /// Almost the same as `highInertia`
            return MFScrollAnimationCurveParameters(msPerStep: 220, baseCurve: ScrollConfig.linearCurve, dragExponent: 0.7, dragCoefficient: 30, stopSpeed: 1, sendMomentumScrolls: true)
            
        case kMFScrollAnimationCurvePresetPreciseScroll:
            /// Similar to `lowInertia`
            return MFScrollAnimationCurveParameters(msPerStep: 140, baseCurve: ScrollConfig.linearCurve, dragExponent: 1.0, dragCoefficient: 20, stopSpeed: 50, sendMomentumScrolls: false)
            
        /// Other
            
        case kMFScrollAnimationCurvePresetTrackpad:
            /// The dragCurve parameters emulate the trackpad as closely as possible. Use this in GestureSimulator.m. The baseCurve parameters as well as `sendMomentumScrolls` are irrelevant, since this is not used in Scroll.m. Not sure if this belongs here. Maybe we should just put these parameters into GestureScrollSimulator where they are used.
            return MFScrollAnimationCurveParameters(msPerStep: -1, baseCurve: nil, dragExponent: 0.7, dragCoefficient: 30, stopSpeed: 1, sendMomentumScrolls: true)
        
        default:
            fatalError()
        }
    }
    
    /// User setting
    
    private lazy var _animationCurvePreset = kMFScrollAnimationCurvePresetLowInertia
    @objc var animationCurvePreset: MFScrollAnimationCurvePreset {
        set {
            _animationCurvePreset = newValue
            self.animationCurveParams = self.animationCurveParams(forPreset: _animationCurvePreset)
        } get {
            return _animationCurvePreset
        }
    }
    
    @objc private(set) lazy var animationCurveParams = { self.animationCurveParams(forPreset: self.animationCurvePreset) }() /// Updates automatically do match `self.animationCurvePreset`
    
    
    // MARK: Acceleration
    
    /// User settings
    
    @objc lazy var useAppleAcceleration: Bool = false /// Ignore MMF acceleration algorithm and use values provided by macOS
    @objc lazy var scrollSensitivity: MFScrollSensitivity = kMFScrollSensitivityHigh
    @objc lazy var scrollAcceleration: MFScrollAcceleration = kMFScrollAccelerationMedium
    
    /// Stored property
    ///     This is used by Scroll.m to determine how to accelerate
    
    @objc lazy var accelerationCurve: AccelerationBezier = standardAccelerationCurve(withScreenSize: 1080) /// Initial value is unused I think
    
    /// Define function that maps userSettings -> accelerationCurve
    
    private func standardAccelerationCurve(forSensitivity sensitivity: MFScrollSensitivity, acceleration: MFScrollAcceleration, animationCurve: MFScrollAnimationCurvePreset, screenSize: Int) -> AccelerationBezier {
        /// `screenSize` should be the width/height of the screen you're scrolling on. Depending on if you're scrolling horizontally or vertically.
        
        
        ///
        /// Get pxPerTickStart
        ///
        
        let pxPerTickStart: Int
        
        switch sensitivity {
        case kMFScrollSensitivityLow:
            pxPerTickStart = 10
        case kMFScrollSensitivityMedium:
            pxPerTickStart = 30
        case kMFScrollSensitivityHigh:
            pxPerTickStart = 60
        default:
            fatalError()
        }
        
        ///
        /// Get pxPerTickEnd
        ///
        
        /// Get base pxPerTick
        
        let pxPerTickEndBase: Double
        
        switch acceleration {
        case kMFScrollAccelerationLow:
            pxPerTickEndBase = 90
        case kMFScrollAccelerationMedium:
            pxPerTickEndBase = 140
        case kMFScrollAccelerationHigh:
            pxPerTickEndBase = 180
        default:
            fatalError()
        }
        
        /// Get inertia factor
        
        let inertiaFactor: Double
        
        switch animationCurve {
        case kMFScrollAnimationCurvePresetLowInertia:
            inertiaFactor = 2/3
        case kMFScrollAnimationCurvePresetMediumInertia:
            inertiaFactor = 3/4
        case kMFScrollAnimationCurvePresetHighInertia:
            inertiaFactor = 1
        case kMFScrollAnimationCurvePresetTouchDriver:
            inertiaFactor = 2/3
        case kMFScrollAnimationCurvePresetTouchDriverLinear:
            inertiaFactor = 2/3
        default: /// The reason why the other MFScrollAnimationCurvePreset constants will never be passed in here is because quickScroll and preciseScroll define their own accelerationCurves. See Scroll.m for more.
            fatalError()
        }
        
        /// Get screenHeight summand
        let screenHeightSummand: Double
        
        let screenHeightFactor = Double(screenSize) / 1080.0
        
        if screenHeightFactor >= 1 {
            screenHeightSummand = 20*(screenHeightFactor - 1)
        } else {
            screenHeightSummand = -20*((1/screenHeightFactor) - 1)
        }
        
        /// Put it all together to get pxPerTickEnd
        let pxPerTickEnd = Int(pxPerTickEndBase * inertiaFactor + screenHeightSummand)
        
        /// Debug
        DDLogDebug("Dynamic pxPerTickEnd: \(pxPerTickEnd)")
        
        ///
        /// Get accelerationHump
        ///
        
        let accelerationHump = -0.0
        /// ^ Between -1 and 1
        ///     Negative values make the curve continuous, and more predictable (might be placebo)
        ///     Edit: I like 0.0 the best now. Feels more "direct" (Before I've liked -0.2)
        
        ///
        /// Generate curve from params
        ///
        
        return ScrollConfig.accelerationCurveFromParams(pxPerTickBase: pxPerTickStart,
                                                        pxPerTickEnd: pxPerTickEnd,
                                                        accelerationHump: accelerationHump,
                                                        consecutiveScrollTickIntervalMax: self.consecutiveScrollTickIntervalMax,
                                                        consecutiveScrollTickInterval_AccelerationEnd: self.consecutiveScrollTickInterval_AccelerationEnd)
        
    }
    
    /// Acceleration curve defnitions
    ///     These aren't used directly but instead they are dynamically loaded into `self.accelerationCurve` by Scroll.m on each first consecutive scroll tick.
    
    @objc func standardAccelerationCurve(withScreenSize screenSize: Int) -> AccelerationBezier {
        
        return self.standardAccelerationCurve(forSensitivity: self.scrollSensitivity,
                                              acceleration: self.scrollAcceleration,
                                              animationCurve: self.animationCurvePreset,
                                              screenSize: screenSize)
    }
    
    @objc lazy var preciseAccelerationCurve: AccelerationBezier = { () -> AccelerationBezier in
        ScrollConfig.accelerationCurveFromParams(pxPerTickBase: 3, /// 2 is better than 3 but that leads to weird asswert failures in PixelatedAnimator that I can't be bothered to fix
                                                 pxPerTickEnd: 15,
                                                 accelerationHump: -0.0,
                                                 consecutiveScrollTickIntervalMax: self.consecutiveScrollTickIntervalMax, /// We don't expect this to ever change so it's okay to just capture here
                                                 consecutiveScrollTickInterval_AccelerationEnd: self.consecutiveScrollTickInterval_AccelerationEnd)
    }()
    @objc lazy var quickAccelerationCurve: AccelerationBezier = { () -> AccelerationBezier in
        ScrollConfig.accelerationCurveFromParams(pxPerTickBase: 100,
                                                 pxPerTickEnd: 500,
                                                 accelerationHump: -0.0,
                                                 consecutiveScrollTickIntervalMax: self.consecutiveScrollTickIntervalMax,
                                                 consecutiveScrollTickInterval_AccelerationEnd: self.consecutiveScrollTickInterval_AccelerationEnd)
    }()
    
    // MARK: Keyboard modifiers
    
    /// Event flag masks
    @objc lazy var horizontalScrollModifierKeyMask = ScrollConfig.stringToEventFlagMask[mod["horizontalScrollModifierKey"] as! String] as! CGEventFlags
    @objc lazy var magnificationScrollModifierKeyMask = ScrollConfig.stringToEventFlagMask[mod["magnificationScrollModifierKey"] as! String] as! CGEventFlags
    
    /// Modifier enabled
    @objc lazy var horizontalScrollModifierKeyEnabled = mod["horizontalScrollModifierKeyEnabled"] as! Bool
    
    @objc lazy var magnificationScrollModifierKeyEnabled = mod["magnificationScrollModifierKeyEnabled"] as! Bool
    
    // MARK: - Helper functions
    
    fileprivate static func accelerationCurveFromParams(pxPerTickBase: Int, pxPerTickEnd: Int, accelerationHump: Double, consecutiveScrollTickIntervalMax: TimeInterval, consecutiveScrollTickInterval_AccelerationEnd: TimeInterval) -> AccelerationBezier {
        /**
         Define a curve describing the relationship between the scrollTickSpeed (in scrollTicks per second) (on the x-axis) and the pxPerTick (on the y axis).
         We'll call this function y(x).
         y(x) is composed of 3 other curves. The core of y(x) is a BezierCurve *b(x)*, which is defined on the interval (xMin, xMax).
         y(xMin) is called yMin and y(xMax) is called yMax
         There are two other components to y(x):
         - For `x < xMin`, we set y(x) to yMin
         - We do this so that the acceleration is turned off for tickSpeeds below xMin. Acceleration should only affect scrollTicks that feel 'consecutive' and not ones that feel like singular events unrelated to other scrollTicks. `self.consecutiveScrollTickIntervalMax` is (supposed to be) the maximum time between ticks where they feel consecutive. So we're using it to define xMin.
         - For `xMax < x`, we lineraly extrapolate b(x), such that the extrapolated line has the slope b'(xMax) and passes through (xMax, yMax)
         - We do this so the curve is defined and has reasonable values even when the user scrolls really fast
         (We use tick and step are interchangable here)
         
         HyperParameters:
         - `accelerationHump` controls how slope (sensitivity) increases around low scrollSpeeds. The name doesn't make sense but it's easy.
            I think this might be useful if  the basePxPerTick is very low. But for a larger basePxPerTick, it's probably fine to set it to 0 (Edit: Why though? - Maybe I was thinking about a positive acceleration hump to mimic the way that Apple acceleration works 🤢)
            - If `accelerationHump < 0`, that makes the transition between the preline and the Bezier smooth. (Makes the derivative continuous)
         - If the third controlPoint shouldn't be `(xMax, yMax)`. If it was, then the slope of the extrapolated curve after xMax would be affected by `accelerationHump`.
         */
        
        /// Define Curve
        
        let xMin: Double = 1 / Double(consecutiveScrollTickIntervalMax)
        let yMin: Double = Double(pxPerTickBase);
        
        let xMax: Double = 1 / consecutiveScrollTickInterval_AccelerationEnd
        let yMax: Double = Double(pxPerTickEnd)
        
        let x2: Double
        let y2: Double
        
        if (accelerationHump < 0) {
            x2 = -accelerationHump
            y2 = 0
        } else {
            x2 = 0
            y2 = accelerationHump
        }
        
        /// Flatten out the end of the curve to prevent ridiculous pxPerTick outputs when input (tickSpeed) is very high. tickSpeed can be extremely high despite smoothing, because our time measurements of when ticks occur are very imprecise
        ///     Edit: Turn off flattening by making x3 = xMax. Do this because currenlty `consecutiveScrollTickIntervalMin == consecutiveScrollTickInterval_AccelerationEnd`, and therefore the extrapolated curve after xMax will never be used anyways -> I think this feels much nicer!
        let x3: Double = xMax /*(xMax-xMin)*0.9 + xMin*/
        let y3: Double = yMax
        
        typealias P = Bezier.Point
        return AccelerationBezier(controlPoints:
                                    [P(x: xMin, y: yMin),
                                     P(x: x2, y: y2),
                                     P(x: x3, y: y3),
                                     P(x: xMax, y: yMax)])
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        
        return SharedUtilitySwift.shallowCopy(of: self)
    }
    
    
    
}

