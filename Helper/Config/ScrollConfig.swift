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

@objc class ScrollConfig: NSObject {
    /// This class has almost all instance properties
    /// You can request the config once, then store it.
    /// You'll receive an independent instance that you can override with custom values. This should be useful for implementing Modifications in Scroll.m
    ///     Everything in ScrollConfigResult is lazy so that you only pay for what you actually use
    
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
    
    // MARK: Class functions
    
    @objc static func currentConfig() -> ScrollConfig {
        return ScrollConfig()
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
    
    // MARK: General
    
    @objc lazy var smoothEnabled: Bool = true /* ScrollConfig.topLevel["smooth"] as! Bool */
    @objc lazy var disableAll: Bool = topLevel["disableAll"] as! Bool /// This is currently unused. Could be used as a killswitch for all scrolling Interception
    
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
    
    // MARK: Smooth scroll
    
    @objc var pxPerTickBase = 60 /* return smooth["pxPerStep"] as! Int */
    /// ^ 60 -> Max good-feeling value, 30 -> I like this one, 10 -> Min good feeling value
    
    @objc lazy private var pxPerTickEnd: Int = 160
    /// ^ 120 Works well without implicit hybrid curve acceleration
    ///     100 Works well with slight hybrid curve acceleration
    
    @objc lazy var msPerStep = 205 /* smooth["msPerStep"] as! Int */
    
    @objc lazy var baseCurve: Bezier = { () -> Bezier in
        /// Base curve used to construct a Hybrid AnimationCurve in Scroll.m. This curve is applied before switching to a DragCurve to simulate physically accurate deceleration
        /// Using a closure here instead of DerivedProperty.create_kvc(), because we know it will never change.
        typealias P = Bezier.Point
        
        let controlPoints: [P] = [P(x:0,y:0), P(x:0,y:0), P(x:1,y:1), P(x:1,y:1)] /// Straight line
//        let controlPoints: [P] = [P(x:0,y:0), P(x:0,y:0), P(x:0.9,y:0), P(x:1,y:1)] /// Testing
//        let controlPoints: [P] = [P(x:0,y:0), P(x:0,y:0), P(x:0.5,y:0.9), P(x:1,y:1)]
        /// ^ Ease out but the end slope is not 0. That way. The curve is mostly controlled by the Bezier, but the DragCurve rounds things out.
        ///     Might be placebo but I really like how this feels
        
//        let controlPoints: [P] = [P(x:0,y:0), P(x:0,y:0), P(x:0.6,y:0.9), P(x:1,y:1)]
        /// ^ For use with low friction to cut the tails a little on long swipes. Turn up the msPerStep when using this
        
        return Bezier(controlPoints: controlPoints, defaultEpsilon: 0.001) /// The default defaultEpsilon 0.08 makes the animations choppy
    }()
    
    @objc lazy var dragExponent = 0.7 /* smooth["frictionDepth"] as! Double */
    @objc lazy var dragCoefficient = 40 /* smooth["friction"] as! Double */
    /// ^       2.3: Value from MMF 1. Not sure why so much lower than the new values
    ///     20: Too floaty with dragExponent 1
    ///     40: Works well with dragExponent 1
    ///     60: Works well with dragExponent 0.7
    ///     1000: Stop immediately

    /**
        ^
        These values make the DragCurve behave like Apple's  inertial trackpad scrolling.
            We need to use these whenever we're sending momentumScroll events, because some apps will ignore the momentumscroll deltas and use their own algorithm (e.g. Xcode). The deltas we generate need to match what those apps are doing for consistent behaviour.
    
        I just checked the formulas on Desmos, and I don't get how this can work with 0.8 as the exponent? (But it does??) If the value is `< 1.0` that gives a completely different curve that speeds up over time, instead of slowing down.
    */
    
    @objc lazy var stopSpeed = 50
    /// ^ Used to construct Hybrid curve in Scroll.m
    ///     This is the speed (In px/s ?) at which the DragCurve part of the Hybrid curve stops scrolling
    ///     I feel like this maybe scales up and down with scroll speed as it currently is? (Shouldn't do that)
    
    @objc lazy var sendMomentumScrolls = true
    
    
    @objc let inertialDragExponent = 0.7
    @objc let inertialDragCoefficient = 30
    
    // MARK: Acceleration
    
    @objc lazy var useAppleAcceleration = false
    /// ^ Ignore MMF acceleration algorithm and use values provided by macOS
    
    @objc lazy var accelerationHump = -0.2
    /// ^ Between -1 and 1
    ///     Negative values make the curve continuous, and more predictable (might be placebo)
    
    @objc lazy var accelerationCurve = standardAccelerationCurve
    
    @objc lazy var standardAccelerationCurve: (() -> AccelerationBezier) =
    DerivedProperty.create_kvc(on:
                                self,
                               given: [
                                #keyPath(pxPerTickBase),
                                #keyPath(pxPerTickEnd),
                                #keyPath(consecutiveScrollTickIntervalMax),
                                #keyPath(consecutiveScrollTickInterval_AccelerationEnd),
                                #keyPath(accelerationHump)
                               ])
    { () -> AccelerationBezier in
        
        /// I'm not sure that using a derived property instead of just re-calculating the curve everytime is faster.
        ///     Edit: I tested it and using DerivedProperty seems slightly faster
        
        return ScrollConfig.accelerationCurveFromParams(pxPerTickBase:                                   self.pxPerTickBase,
                                                        pxPerTickEnd:                                    self.pxPerTickEnd,
                                                        consecutiveScrollTickIntervalMax:                self.consecutiveScrollTickIntervalMax,
                                                        consecutiveScrollTickInterval_AccelerationEnd:   self.consecutiveScrollTickInterval_AccelerationEnd,
                                                        accelerationHump:                                self.accelerationHump)
    }
    
    @objc lazy var preciseAccelerationCurve = { () -> AccelerationBezier in
        ScrollConfig.accelerationCurveFromParams(pxPerTickBase: 3, /// 2 is better than 3 but that leads to weird asswert failures in PixelatedAnimator that I can't be bothered to fix
                                                 pxPerTickEnd: 15,
                                                 consecutiveScrollTickIntervalMax: self.consecutiveScrollTickIntervalMax,
                                                 /// ^ We don't expect this to ever change so it's okay to just capture here
                                                 consecutiveScrollTickInterval_AccelerationEnd: self.consecutiveScrollTickInterval_AccelerationEnd,
                                                 accelerationHump: -0.2)
    }
    @objc lazy var quickAccelerationCurve = { () -> AccelerationBezier in
        ScrollConfig.accelerationCurveFromParams(pxPerTickBase: 50, /// 40 and 220 also works well
                                                 pxPerTickEnd: 200,
                                                 consecutiveScrollTickIntervalMax: self.consecutiveScrollTickIntervalMax,
                                                 consecutiveScrollTickInterval_AccelerationEnd: self.consecutiveScrollTickInterval_AccelerationEnd,
                                                 accelerationHump: -0.2)
    }
    
    // MARK: Keyboard modifiers
    
    /// Event flag masks
    @objc lazy var horizontalScrollModifierKeyMask = ScrollConfig.stringToEventFlagMask[mod["horizontalScrollModifierKey"] as! String] as! CGEventFlags
    @objc lazy var magnificationScrollModifierKeyMask = ScrollConfig.stringToEventFlagMask[mod["magnificationScrollModifierKey"] as! String] as! CGEventFlags
    
    /// Modifier enabled
    @objc lazy var horizontalScrollModifierKeyEnabled = mod["horizontalScrollModifierKeyEnabled"] as! Bool
    
    @objc lazy var magnificationScrollModifierKeyEnabled = mod["magnificationScrollModifierKeyEnabled"] as! Bool
    
    // MARK: - Helper functions
    
    fileprivate static func accelerationCurveFromParams(pxPerTickBase: Int, pxPerTickEnd: Int, consecutiveScrollTickIntervalMax: TimeInterval, consecutiveScrollTickInterval_AccelerationEnd: TimeInterval, accelerationHump: Double) -> AccelerationBezier {
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
         - `dip` controls how slope (sensitivity) increases around low scrollSpeeds. The name doesn't make sense but it's easy.
         I think this might be useful if  the basePxPerTick is very low. But for a larger basePxPerTick, it's probably fine to set it to 0
         - If the third controlPoint shouldn't be `(xMax, yMax)`. If it was, then the slope of the extrapolated curve after xMax would be affected `accelerationDip`.
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
        let x3: Double = (xMax-xMin)*0.9
        //        let y3: Double = (yMax-yMin)*0.9
        let y3: Double = yMax
        
        typealias P = Bezier.Point
        return AccelerationBezier.init(controlPoints:
                                        [P(x:xMin, y: yMin),
                                         P(x:x2, y: y2),
                                         P(x: x3, y: y3),
                                         P(x: xMax, y: yMax)])
    }
    
}

