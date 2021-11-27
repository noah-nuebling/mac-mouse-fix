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
    
    /// Konstanz
    
    @objc static var stringToEventFlagMask: NSDictionary = ["command" : CGEventFlags.maskCommand,
                                                     "control" : CGEventFlags.maskControl,
                                                     "option" : CGEventFlags.maskAlternate,
                                                     "shift" : CGEventFlags.maskShift]
    
    // Convenience functions for accessing top level dict and different sub-dicts

    @objc private static var topLevel: NSDictionary {
        Config.configWithAppOverridesApplied()[kMFConfigKeyScroll] as! NSDictionary
    }
    @objc private static var other: NSDictionary {
        topLevel["other"] as! NSDictionary
    }
    @objc private static var smooth: NSDictionary {
        topLevel["smoothParameters"] as! NSDictionary
    }
    @objc private static var mod: NSDictionary {
        topLevel["modifierKeys"] as! NSDictionary
    }

    // Interface

    // General

    @objc static var smoothEnabled: Bool {
//        topLevel["smooth"] as! Bool
        return true;
    }
    @objc static var disableAll: Bool {
        topLevel["disableAll"] as! Bool; // This is currently unused. Could be used as a killswitch for all scrolling Interception
    }
    
    /// Scroll inversion
    
    @objc static var scrollInvert: MFScrollInversion {
        /// This can be used as a factor to invert things. kMFScrollInversionInverted is -1.
        
        if self.semanticScrollInvertUser == self.semanticScrollInvertSystem {
            return kMFScrollInversionNonInverted
        } else {
            return kMFScrollInversionInverted
        }
    }
    private static var semanticScrollInvertUser: MFSemanticScrollInversion {
//        MFSemanticScrollInversion(topLevel["naturalDirection"] as! UInt32)
        return kMFSemanticScrollInversionNormal
    }
    private static var semanticScrollInvertSystem: MFSemanticScrollInversion {
        /// Maybe we could use NSEvent.directionInvertedFromDevice instead of this.
        
        let defaults = UserDefaults.standard;
        
        let isNatural = defaults.bool(forKey: "com.apple.swipescrolldirection")
        
        return isNatural ? kMFSemanticScrollInversionNatural : kMFSemanticScrollInversionNormal
    }
    
    // Scroll ticks/swipes, fast scroll, and ticksPerSecond

    @objc static var scrollSwipeThreshold_inTicks: Int { /// If `scrollSwipeThreshold_inTicks` consecutive ticks occur, they are deemed a scroll-swipe.
        other["scrollSwipeThreshold_inTicks"] as! Int;
    }
    @objc static var fastScrollThreshold_inSwipes: Int { /// If `fastScrollThreshold_inSwipes` + 1 consecutive swipes occur, fast scrolling is enabled.
        other["fastScrollThreshold_inSwipes"] as! Int
    }
    @objc static var scrollSwipeMax_inTicks: Int { /// Max number of ticks that we think can occur in a single swipe naturally (if the user isn't using a free-spinning scrollwheel). (See `consecutiveScrollSwipeCounter_ForFreeScrollWheel` definition for more info)
        9;
    }
    @objc static var consecutiveScrollTickIntervalMax: TimeInterval { // If more than `_consecutiveScrollTickIntervalMax` seconds passes between two scrollwheel ticks, then they aren't deemed consecutive.
//        other["consecutiveScrollTickIntervalMax"] as! Double;
        // msPerStep/1000 <- Good idea but we don't want this to depend on msPerStep
        0.13
        
    }
    @objc static var consecutiveScrollSwipeMaxInterval: TimeInterval {
        // If more than `_consecutiveScrollSwipeIntervalMax` seconds passes between two scrollwheel swipes, then they aren't deemed consecutive.
        //        other["consecutiveScrollSwipeIntervalMax"] as! Double
        0.35
    }
    @objc static var consecutiveScrollTickInterval_AccelerationEnd: TimeInterval { // Used to define accelerationCurve. If the time interval between two ticks becomes less than `consecutiveScrollTickInterval_AccelerationEnd` seconds, then the accelerationCurve becomes managed by linear extension of the bezier instead of the bezier directly.
        0.02
    }
    @objc static var fastScrollExponentialBase: Double { // How quickly fast scrolling gains speed.
//        other["fastScrollExponentialBase"] as! Double;
        1.5 // 1.1
    }
    @objc static var fastScrollFactor: Double {
//        other["fastScrollFactor"] as! Double
        1.5
    }
    @objc static var ticksPerSecondSmoothingInputValueWeight: Double {
        0.5
    }
    @objc static var ticksPerSecondSmoothingTrendWeight: Double {
        0.2
    }

    // Smooth scrolling params

    @objc static var pxPerTickBase: Int {
//        return smooth["pxPerStep"] as! Int
        return 10;
    }
    @objc static var pxPerTickEnd: Int {
        return 120;
    }
    @objc static var msPerStep: Int {
//        smooth["msPerStep"] as! Int
        return 200
    }
    @objc static var accelerationHump: Double {
        /// Between -1 and 1
        return 0.0
    }
    @objc static var accelerationCurve: (() -> AnimationCurve) =
        DerivedProperty.create_kvc(on:
                                    ScrollConfig.self,
                                   given: [
                                    #keyPath(pxPerTickBase),
                                    #keyPath(pxPerTickEnd),
                                    #keyPath(msPerStep),
                                    #keyPath(consecutiveScrollTickIntervalMax),
                                    #keyPath(consecutiveScrollTickInterval_AccelerationEnd),
                                    #keyPath(accelerationHump)
                                   ])
    { () -> AnimationCurve in
        
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
        
        /// Get instance properties
        
        var pxPerTickBase =  ScrollConfig.self.pxPerTickBase
        var pxPerTickEnd = ScrollConfig.self.pxPerTickEnd;
        var msPerStep = ScrollConfig.self.msPerStep
        var consecutiveScrollTickIntervalMax = ScrollConfig.self.consecutiveScrollTickIntervalMax
        /// ^ This is currently 0.13
        let consecutiveScrollTickInterval_AccelerationEnd = ScrollConfig.self.consecutiveScrollTickInterval_AccelerationEnd
        var accelerationHump = ScrollConfig.self.accelerationHump
            
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
        
        
        // Flatten out the end of the curve to prevent ridiculous pxPerTick outputs when input (tickSpeed) is very high. tickSpeed can be extremely high despite smoothing, because our time measurements of when ticks occur are very imprecise
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
    @objc static var animationCurve: AnimationCurve = { () -> AnimationCurve in
        /// Using a closure here instead of DerivedProperty.create_kvc(), because we know it will never change.
        
        typealias P = Bezier.Point
        
//        let controlPoints: [P] = [P(x:0,y:0), P(x:0,y:0), P(x:0.3,y:1), P(x:1,y:1)]
//        let controlPoints: [P] = [P(x:0,y:0), P(x:0,y:0), P(x:1,y:1), P(x:1,y:1)]
        let controlPoints: [P] = [P(x:0,y:0), P(x:0,y:0), P(x:0.5,y:1), P(x:1,y:1)]
        
        return Bezier(controlPoints: controlPoints, defaultEpsilon: 0.001) /// The default defaultEpsilon 0.08 makes the animations choppy
    }()
    @objc static var dragCoefficient: Double {
        smooth["friction"] as! Double;
    }
    @objc static var dragExponent: Double {
        smooth["frictionDepth"] as! Double;
    }
    @objc static var accelerationForScrollBuffer: Double { // TODO: Unused, remove
        smooth["acceleration"] as! Double;
    }

    @objc static var nOfOnePixelScrollsMax: Int { // TODO: Probably unused. Consider removing
        smooth["onePixelScrollsLimit"] as! Int // After opl+1 frames of only scrolling 1 pixel, scrolling stops. Should probably change code to stop after opl frames.
    }

    // Keyboard modifiers

    // Event flag masks
    @objc static var horizontalScrollModifierKeyMask: CGEventFlags {
        stringToEventFlagMask[mod["horizontalScrollModifierKey"] as! String] as! CGEventFlags
    }
    @objc static var magnificationScrollModifierKeyMask: CGEventFlags {
        stringToEventFlagMask[mod["magnificationScrollModifierKey"] as! String] as! CGEventFlags
    }
    // Modifier enabled
    @objc static var horizontalScrollModifierKeyEnabled: Bool {
        mod["horizontalScrollModifierKeyEnabled"] as! Bool
    }
    @objc static var magnificationScrollModifierKeyEnabled: Bool {
        mod["magnificationScrollModifierKeyEnabled"] as! Bool
    }
    
}
