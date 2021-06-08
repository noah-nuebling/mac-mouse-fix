//
// --------------------------------------------------------------------------
// ScrollConfig.shared.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

@objc class ScrollConfig: NSObject {
    
    
    /// Contstants
    
    @objc var stringToEventFlagMask: NSDictionary = ["command" : CGEventFlags.maskCommand,
                                                     "control" : CGEventFlags.maskControl,
                                                     "option" : CGEventFlags.maskAlternate,
                                                     "shift" : CGEventFlags.maskShift]
    
    // Convenience functions for accessing top level dict and different sub-dicts

    @objc var topLevel: NSDictionary {
        MainConfigInterface.configWithAppOverridesApplied()[kMFConfigKeyScroll] as! NSDictionary
    }
    @objc var other: NSDictionary {
        topLevel["other"] as! NSDictionary
    }
    @objc var smooth: NSDictionary {
        topLevel["smoothParameters"] as! NSDictionary
    }
    @objc var mod: NSDictionary {
        topLevel["modifierKeys"] as! NSDictionary
    }

    // Interface

    // General

    @objc var smoothEnabled: Bool {
        topLevel["smooth"] as! Bool
    }
    @objc var scrollDirection: MFScrollDirection {
        MFScrollDirection(topLevel["direction"] as! Int32)
    }
    
    @objc var disableAll: Bool {
        topLevel["disableAll"] as! Bool; // This is currently unused. Could be used as a killswitch for all scrolling Interception
    }

    // Scroll ticks/swipes, fast scroll, and ticksPerSecond

    @objc var scrollSwipeThreshold_inTicks: Int { // If `_scrollSwipeThreshold_inTicks` consecutive ticks occur, they are deemed a scroll-swipe.
        other["scrollSwipeThreshold_inTicks"] as! Int; //
    }
    @objc var fastScrollThreshold_inSwipes: Int { // If `_fastScrollThreshold_inSwipes` consecutive swipes occur, fast scrolling is enabled.
        other["fastScrollThreshold_inSwipes"] as! Int
    }
    @objc var consecutiveScrollTickMaxInterval: TimeInterval { // If more than `_consecutiveScrollTickMaxIntervall` seconds passes between two scrollwheel ticks, then they aren't deemed consecutive.
        other["consecutiveScrollTickMaxIntervall"] as! Double; // == _msPerStep/1000 // oldval:0.0
    }
    @objc var consecutiveScrollSwipeMaxInterval: TimeInterval { // If more than `_consecutiveScrollSwipeMaxIntervall` seconds passes between two scrollwheel swipes, then they aren't deemed consecutive.
        other["consecutiveScrollSwipeMaxIntervall"] as! Double
    }
    @objc var fastScrollExponentialBase: Double { // How quickly fast scrolling gains speed.
        other["fastScrollExponentialBase"] as! Double; // 1.05 //1.125 //1.0625 // 1.0937
    }
    @objc var fastScrollFactor: Double {
        other["fastScrollFactor"] as! Double
    }
    @objc var ticksPerSecondSmoothingInputValueWeight: Double {
        0.5
    }
    @objc var ticksPerSecondSmoothingTrendWeight: Double {
        0.2
    }

    // Smooth scrolling params


    @objc var pxPerTickBase: Int {
        smooth["pxPerStep"] as! Int;
    }
    @objc var msPerStep: Int {
        smooth["msPerStep"] as! Int;
    }
    @objc var frictionCoefficient: Double {
        smooth["friction"] as! Double;
    }
    @objc var frictionDepth: Double {
        smooth["frictionDepth"] as! Double;
    }
    @objc var accelerationForScrollBuffer: Double { // TODO: Unused, remove
        smooth["acceleration"] as! Double;
    }
    @objc lazy var accelerationCurve: (() -> RealFunction) = DerivedProperty.create(on: self, given: [\Self.pxPerTickBase], compute: { () -> RealFunction in
        
        typealias P = BezierCurve.Point
        
        let controlPoints: [P] = [P(x:0,y:0), P(x:0,y:0), P(x:0.7,y:1), P(x:1,y:1)]
        
        let scrollTickSpeedInterval: Interval = Interval.init(start: 0.0, end: 50.0)
        let animationSpeedInterval: Interval = Interval.init(start: Double(self.pxPerTickBase), end: 300.0)
        
        return ExtrapolatedBezierCurve.init(controlPoints: controlPoints, xInterval: scrollTickSpeedInterval, yInterval: animationSpeedInterval)
    })
    
//    {
//
//        typealias P = BezierCurve.Point
//
//        let controlPoints: [P] = [P(x:0,y:0), P(x:0,y:0), P(x:0.7,y:1), P(x:1,y:1)]
//
//        let scrollTickSpeedInterval: Interval = Interval.init(start: 0.0, end: 50.0)
//        let animationSpeedInterval: Interval = Interval.init(start: Double(self.pxPerTickBase), end: 300.0)
//
//        return ExtrapolatedBezierCurve.init(controlPoints: controlPoints, xInterval: scrollTickSpeedInterval, yInterval: animationSpeedInterval)
//    }
    
    @objc var derivedAccelerationCurve: (() -> RealFunction)?

    @objc var nOfOnePixelScrollsMax: Int {
        smooth["onePixelScrollsLimit"] as! Int // After opl+1 frames of only scrolling 1 pixel, scrolling stops. Should probably change code to stop after opl frames.
    }


    // Keyboard modifiers

    // Event flag masks
    @objc var horizontalScrollModifierKeyMask: CGEventFlags {
        stringToEventFlagMask[mod["horizontalScrollModifierKey"] as! String] as! CGEventFlags
    }
    @objc var magnificationScrollModifierKeyMask: CGEventFlags {
        stringToEventFlagMask[mod["magnificationScrollModifierKey"] as! String] as! CGEventFlags
    }
    // Modifier enabled
    @objc var horizontalScrollModifierKeyEnabled: Bool {
        mod["horizontalScrollModifierKeyEnabled"] as! Bool
    }
    @objc var magnificationScrollModifierKeyEnabled: Bool {
        mod["magnificationScrollModifierKeyEnabled"] as! Bool
    }
    
    /// Init singleton instance
    
    @objc class var shared: ScrollConfig { ScrollConfig.init() }
    
}
