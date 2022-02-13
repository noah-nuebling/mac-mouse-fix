//
// --------------------------------------------------------------------------
// HybridCurve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa
import CocoaLumberjackSwift

// MARK: - LineHybrid

@objc class LineHybridCurve: HybridCurve {
    
    /// Base Curve
    
    var _baseCurve: Line = Line(a: 1, b: 0)
    override var baseCurve: AnimationCurve {
        get { _baseCurve }
        set { fatalError() }
    }
    
    @objc init(minDuration: Double, distance: Double, dragCoefficient: Double, dragExponent: Double, stopSpeed: Double) {
        
        /// Init super
        super.init()
        
        /// Validate
        assert(distance > 0)
        
        /// Get base curve exit speed
        let transitionSpeed = distance / minDuration
        
        /// Get drag curve
        dragCurve = getDragCurve(initialSpeed: transitionSpeed, stopSpeed: stopSpeed, coefficient: dragCoefficient, exponent: dragExponent)
        
        /// Find transition point
        let dragDistance = dragCurve!.distanceInterval.length
        var transitionDistance = distance - dragDistance
        
        /// Change dragCurve if transition distance is negative
        if transitionDistance < 0 {
            
            /// Get a dragCurve that exactly covers valueRange
            ///     Note that this means that the slope of the baseCurve is ignored. This might lead to weird feeling speed changes
            
            /// Warn
            DDLogWarn("DragCurve transition distance is negative. Ignoring Line.")
            assert(false) /// For debugging - remove later
            
            /// Get new curve
            dragCurve = DragCurve(coefficient: dragCoefficient, exponent: dragExponent, distance: distance, stopSpeed: stopSpeed)
            
            /// Set transition Distance to 0
            transitionDistance = 0
        }

        /// Get transition time
        let transitionTime = _baseCurve.evaluate(atY: transitionDistance / distance) * minDuration
        
        /// Store params
        
        self.baseTimeInterval = Interval(start: 0, end: transitionTime)
        self.baseDistanceInterval = Interval(start: 0, end: transitionDistance)
        
        self.dragCoefficient = dragCoefficient
        self.dragExponent = dragExponent
        self.stopSpeed = stopSpeed
    }
}

// MARK: - SimpleBezierHybrid

@objc class SimpleBezierHybridCurve: HybridCurve {
    /// This curve is intended to animate scrolling in a way that resembles the original MMF scrolling algorithm
    /// The first part of the curve  is driven by a BezierCurve, and the second half by a DragCurve.
    /// The drag curve is used to ensure physically accurate, natural-feeling deceleration.
    ///
    /// This is a 'Simple' Hybrid curve because it doesn't let you specify or retrieve the distance and duration of the whole curve, but only of the 'Base' curve. (The whole curve consists of the Base curve as well as the the Drag curve.)
    
    /// BaseCurve
    
    var _baseCurve: Bezier
    override var baseCurve: AnimationCurve {
        get { _baseCurve }
        set { _baseCurve = newValue as! Bezier }
    }
    
    /// Helper
    
    @objc func baseDistanceLeft(distanceLeft: Double) -> Double {
        var baseValueLeft = distanceLeft - dragValueRange
        if baseValueLeft < 0 { baseValueLeft = 0 }
        return baseValueLeft
    }
    
    /// Init
    
    @objc init(baseCurve: Bezier, baseTimeRange: Double, baseValueRange: Double, dragCoefficient: Double, dragExponent: Double, stopSpeed: Double) {
        
        /// baseCurve is assumed to pass through (0,0) and (1,1)
        /// The baseValueRange and baseTimeRange are for the Bezier (aka "base") curve.
        ///     A Drag curve will be appended to the the base curve for natural deceleration. This will increase the timeRange and valueRange of the Hybrid curve to be larger than `baseTimeRange` and `baseValueRange`.
        
        /// Init super
        ///     Cause swift is shtupid
        
        _baseCurve = InvalidBezier()
        super.init()
        
        /// Store params
        
        self.baseCurve = baseCurve
        self.baseTimeInterval = Interval(start: 0, end: baseTimeRange)
        self.baseDistanceInterval = Interval(start: 0, end: baseValueRange)
        
        self.dragCoefficient = dragCoefficient
        self.dragExponent = dragExponent
        self.stopSpeed = stopSpeed
        
        /// Get exit speed of baseCurve (== initial speed of dragCurve)
        
        let v0 = baseCurve.exitSlope! * distance / duration
        self.dragCurve = getDragCurve(initialSpeed: v0, stopSpeed: stopSpeed, coefficient: dragCoefficient, exponent: dragExponent)
        
    }
}


// MARK: - Base class

class HybridCurve: NSObject, AnimationCurve {
    /// A HybridCurve is an AnimationCurve where two different 'subcurves' control the animation. The second subcurve is is a DragCurve.
    /// This has the purpose of decelerating animations naturally, while still retaining complete control over the start of the animation.
    ///
    /// This class is supposed to be subclassed, not used directly.
    /// We're building these different subclasses for testing and interaction design. We'll likely only end up using one of them.
    ///
    /// Old notes on implementing the different subclasses: (Delete this eventually)
    /// Eventually I would like to try and implement a Hybrid Curve that does let you specify the distance range of the entire Hybrid curve. We'll have to figure some way to piece together the Base curve and the Hybrid curve such that
    /// - The transition between the two curves is smooth (speed doesn't change abruptly)
    /// - The overall curve covers a specified distance to be scrolled
    /// - The 'friction' of the drag curve is constant
    /// - The duration can change
    /// -> I can think of 2 solutions. A LinearDragHybridCurve (simpler) and a BezierDragHybridCurve (more complex) I thought about both and neither should be too hard.
    /// - For the LinearDragHybridCurve, approach like this:
    ///     - Get the single derivative that the linear curve has everywhere and plug that into the DragCurve and see what distance that would cover. Use this distance to determine where to attach the DragCurve to the LinearCurve.
    /// - For the BezierDragHybridCurve, don't forget this:
    ///     - The derivative dy/dy for a parametric curve is y'(t) / x'(t).
    ///     - Using this derivative, you can determine for any point on the Bezier, whether attaching a DragCurve here would put you over or under the desired overall distance. The end point of the Bezier will always put you *over* the desired distance. Sample the curve from end to start (in increments of 1/10 or so should be precise enough) and find the first point where attaching the DragCurve puts you *under* the desired overall distance. Then do bisection between two points to find that point that puts you *at* the desired overall distance.
    ///     - This sounds involved but should be plenty fast.
    /// For both Hybrid curves don't forget this:
    ///     It could be that the point to attach the DragCurve is in the past. In that case use some fallback like doing everything with the DragCurve such that it covers the desired distance by itself.

    /// Constants
    
    var bezierEpsilon: Double = 0.08
    
    /// Vars - init
    
    /// BaseCurve
    
    fileprivate var baseCurve: AnimationCurve { get{fatalError()} set{fatalError()} }
    
    @objc var baseTimeInterval: Interval = .unitInterval
    @objc var baseDistanceInterval: Interval = .unitInterval
    @objc var baseDuration: Double { baseTimeInterval.length }
    @objc var baseDistance: Double { baseDistanceInterval.length }
    
    /// DragCurve
    
    fileprivate var dragCoefficient: Double = -1
    fileprivate var dragExponent: Double = -1
    fileprivate var stopSpeed: Double = -1
    
    fileprivate var dragCurve: DragCurve?
    
    fileprivate var dragTimeRange: Double {
        guard let c = dragCurve else { return 0 }
        return c.timeInterval.length
    }
    fileprivate var dragValueRange: Double {
        guard let c = dragCurve else { return 0 }
        return c.distanceInterval.length
    }
    
    /// HybridCurve
    
    fileprivate var timeInterval: Interval { Interval(start: 0, end: baseDuration + dragTimeRange) }
    fileprivate var distanceInterval: Interval { Interval(start: 0, end: baseDistance + dragValueRange) }
    @objc var duration: Double { timeInterval.length }
    @objc var distance: Double { distanceInterval.length }
    
    /// Init
    
    override init() {
        
        /// Init super
        super.init()
        
        /// Crash if not subclass
        if type(of: self) == HybridCurve.self { fatalError() }
    }
    
    /// Init - Helper functions
    
    fileprivate func getDragCurve(initialSpeed: Double, stopSpeed: Double, coefficient: Double, exponent: Double) -> DragCurve? {
        
        /// Get dragCurve
        
        let result: DragCurve?
        
        if initialSpeed > stopSpeed {
            result = DragCurve(coefficient: coefficient, exponent: exponent, initialSpeed: initialSpeed, stopSpeed: stopSpeed)
        } else {
            DDLogDebug("baseExitSpeed > stopSpeed in HybridCurve init. Not creating dragCurve.")
            result = nil
        }
        
        /// Debug
        
        DDLogDebug("dragTime: \(dragTimeRange), dragValue: \(dragValueRange), time: \(duration), value: \(distance)")
        
        /// Return
        
        return result
    }
    
    
    /// Evaluate
    
    @objc func evaluate(at x: Double) -> Double {
        
        let result: Double
        
        if x <= baseDuration / duration {
            
            /// Evaluate baseCurve
            
            var baseCurveResult = baseCurve.evaluate(at: Math.scale(value: x, from: baseTimeIntervalUnit, to: .unitInterval))
            if baseCurveResult > 1 { baseCurveResult = 1 } /// The baseCurveResult is sometimes 1.00000000002 leading to assert failures in scaling code
            result = Math.scale(value: baseCurveResult, from: .unitInterval, to: baseDistanceIntervalUnit)
        } else {
            
            /// Evaluate DragCurve
            
            if let c = dragCurve  {
                let dragCurveResult = c.evaluate(at: Math.scale(value: x, from: dragTimeIntervalUnit, to: .unitInterval))
                result = Math.scale(value: dragCurveResult, from: .unitInterval, to: dragDistanceIntervalUnit)
            } else {
                DDLogWarn("Tried to evaluate HybridCurve at DragCurve but DragCurve doesn't exist. x: \(x), baseTimeRange/timeRange: \(baseDuration/duration)")
                result = x
            }
        }
        
        return result
    }
    
    /// Evaluate - helpers
    var baseTimeIntervalUnit: Interval { Interval(start: 0, end: baseDuration / duration) }
    var dragTimeIntervalUnit: Interval { Interval(start: baseDuration / duration, end: 1) }
    
    var baseDistanceIntervalUnit: Interval { Interval(start: 0, end: baseDistance / distance) }
    var dragDistanceIntervalUnit: Interval { Interval(start: baseDistance / distance, end: 1) }
}
