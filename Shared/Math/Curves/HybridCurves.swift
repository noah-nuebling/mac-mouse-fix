//
// --------------------------------------------------------------------------
// HybridCurve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// A HybridCurve is an AnimationCurve where two different 'subcurves' control the animation. The second subcurve is is a DragCurve.
/// This has the purpose of decelerating animations naturally, while still retaining complete control over the start of the animation.

import Cocoa

// MARK: - BezierHybrid

@objc class BezierHybridCurve: HybridCurve {
    
    /// BezierHybrid is more powerful than LineHybrid and SimpleBezierHybrid has weird behaviour (can't control the distance)
    ///     You might want to use LineHybrid for performance, otherwise, use this.
    
    /// Base Curve
    
    var _baseCurve: Bezier = InvalidBezier()
    override var baseCurve: Curve {
        get { _baseCurve }
        set { fatalError() }
    }
    
    @objc init(baseCurve: Bezier, minDuration: Double, distance targetDistance: Double, dragCoefficient: Double, dragExponent: Double, stopSpeed: Double, distanceEpsilon: Double) {
        
        /// Not sure what to choose as the transitionPointEpsilon
        ///     It's an epsilon for the targetDistance
        
        /// Init super
        super.init()
        
        /// Validate
        ///     The baseCurve should always pass through (0.0, 0.0) and (1.0, 1.0) `minDuration` and `distance` are used to stretch the baseCurve along the x and y axis.
        
        assert(targetDistance > 0)
        assert(baseCurve.controlPoints.first == CGPoint(x: 0.0, y: 0.0))
        assert(baseCurve.controlPoints.last == CGPoint(x: 1.0, y: 1.0))
        
        /// Call core
        
        let transitionTime: Double
        let transitionDistance: Double
        let dragCurve: DragCurve?
        
        if baseCurve.isLine { /// Fallback to line logic if the Bezier is just a line - for optimization
            (transitionTime, transitionDistance, dragCurve) = LineHybridCurve._lineInit(minDuration: minDuration, distance: targetDistance, dragCoefficient: dragCoefficient, dragExponent: dragExponent, stopSpeed: stopSpeed)
        } else {
            (transitionTime, transitionDistance, dragCurve) = BezierHybridCurve._bezierInit(baseCurve: baseCurve, minDuration: minDuration, targetDistance: targetDistance, dragCoefficient: dragCoefficient, dragExponent: dragExponent, stopSpeed: stopSpeed, distanceEpsilon: distanceEpsilon)
        }
        
        /// Store params
        
        self._baseCurve = baseCurve
        self.baseTimeInterval = Interval(start: 0, end: transitionTime)
        self.baseDistanceInterval = Interval(start: 0, end: transitionDistance)
        
        self.dragCurve = dragCurve
        self.dragCoefficient = dragCoefficient
        self.dragExponent = dragExponent
        self.stopSpeed = stopSpeed
        
        /// Debug
        DDLogDebug(String(format: "Created BezierHybridCurve with - duration: %.3f, distance: %.3f", baseDuration/duration, baseDistance/distance))
    }
    
    /// Init - Helpers
    
    static func combinedDistance(transitionPoint t: Double, baseCurve: Bezier, baseDistance: Double, baseDuration: Double, dragExponent: Double, dragCoefficient: Double, stopSpeed: Double) -> Double {
        
        assert(0 <= t && t <= 1)
        
        let slopeAtT = baseCurve.derivativeDyOverDx(atT: t)
        let speedAtT = slopeAtT * baseDistance / baseDuration
        
        if speedAtT <= stopSpeed {
            
            DDLogWarn("Proposed transitionSpeed is lower than stopSpeed")
            
            let transitionDistance = baseCurve.sampleCurve(onAxis: Bezier.yAxis, atT: t) * baseDistance
            return transitionDistance
        }
        
        let dragCurve = DragCurve(coefficient: dragCoefficient, exponent: dragExponent, initialSpeed: speedAtT, stopSpeed: stopSpeed)
        let dragDistance = dragCurve.distanceInterval.length
        
        let transitionDistance = baseCurve.sampleCurve(onAxis: Bezier.yAxis, atT: t) * baseDistance
        
        let combinedDistance = transitionDistance + dragDistance
        
        return combinedDistance
    }
    
    static func _bezierInit(baseCurve: Bezier, minDuration: Double, targetDistance: Double, dragCoefficient: Double, dragExponent: Double, stopSpeed: Double, distanceEpsilon: Double) -> (transitionTime: Double, transitionDistance: Double, dragCurve: DragCurve?) {
        
        /// Validate
        /// Notes:
        /// - We're currently trying to experiment with speed smoothing in Scroll.m, and the defaultDefaultEpsilon (0.08) is wayy too inaccurate. Before I think we didn't test the 0.08 value, because we were always using straight lines as the baseCurve for the BezierHybridCurve before - and straight line Beziers get optimized into actual lines.
        assert(baseCurve.defaultEpsilon < Bezier.defaultDefaultEpsilon);
        
        /// Find transition point
        ///     We need to find a point on the BezierCurve where to attach the DragCurve, such that the combined curve covers a distance of `distance`
        ///     We can't solve this mathematically (at least I wouldn't know how) so we need to search for the point algorithmically
        ///     The algorithm will work something like this:
        ///         - Define function distance(attachmentPoint). We try to find the attachmentPoint t_a where distance(attachmentPoint = t_a) = targetDistance.
        ///         - We know that distance(attachmentPoint = lastPointOnBezier) >(=?) targetDistance, because the Bezier exactly covers targetDistance on it's own.
        ///         - We traverse the points on the Bezier from lastPointOnBezer (t == 1.0) to firstPointOnBezier (t == 0.0).  (Increments of 10 or less should work). Until we find a point t_n where `distance(attachmentPoint = t_n) < targetDistance`. Then we know that `t_a` is between `t_n` and `t_{n+1}`. Then we do bisection between `t_n` and `t_{n+1}` until we find a point that's within an epsilon of `t_a`.
        ///         - If we found the derivative of distance(attachmentPoint) we could use Newton's method instead of bisection, but bisection should be fast enough.
        ///             -> Maybe look into using that if there is a noticable performance impact.
        /// Edit: Why aren't we just using bisection for the whole thing, and instead doing this weird steps-of-0.1 search first? ... I think it might be because we want to find the **last** transition point on the baseCurve, in case there are several transition points where a transitionPoint is any point where can attach the dragCurve such that we reach the targetDistance.
        
        var transitionPointRange: Interval? = nil
        var transitionPoint: Double? = nil
        var dragCurve: DragCurve? = nil
        
        /// Find range where transitionPoint might be
        
        let n = 10
        var k0 = 0
#if !DEBUG
        k0 = 1 /// Optimization, see asserts inside the loop
#endif
        for k in k0...n {
            
            /// Get transition point to sample
            let t = Math.scale(value: Double(k), from: Interval(0, Double(n)), to: .reversedUnitInterval) /// t goes from 1.0 to 0.0 in increments of 1/n
            
            /// Get combined distance at transition point
            let combinedDistance = combinedDistance(transitionPoint: t, baseCurve: baseCurve, baseDistance: targetDistance, baseDuration: minDuration, dragExponent: dragExponent, dragCoefficient: dragCoefficient, stopSpeed: stopSpeed)
            
            /// Validate
            if k == 0 { assert(t == 1) }
            if k == 0 { assert(combinedDistance >= targetDistance) }
            
            /// Break
            if fabs(combinedDistance - targetDistance) < distanceEpsilon {
                transitionPoint = t
                break
            }
            if combinedDistance <= targetDistance {
                transitionPointRange = Interval(t, t+(1/Double(n)))
                break
            }
        }
        
        
        if let transitionPointRange = transitionPointRange {
            /// Use bisection to find exact transition point
            
            transitionPoint = Math.bisect(searchRange: transitionPointRange, targetOutput: targetDistance, epsilon: distanceEpsilon, function: { t in
                
                return combinedDistance(transitionPoint: t, baseCurve: baseCurve, baseDistance: targetDistance, baseDuration: minDuration, dragExponent: dragExponent, dragCoefficient: dragCoefficient, stopSpeed: stopSpeed)
            }) as? Double
        }
        
        if transitionPoint == nil {
            /// No transition point found
            
            /// Fallback: Get a dragCurve that exactly covers `targetDistance`
            ///     Note that this means that the slope of the baseCurve is ignored. This might lead to weird feeling speed changes
            
            /// Debug
            DDLogDebug("Coudn't find DragCurve transition point. Ignoring Bezier.")
            
            /// Get new curve
            dragCurve = DragCurve(coefficient: dragCoefficient, exponent: dragExponent, distance: targetDistance, stopSpeed: stopSpeed)
            
            /// Set transition point to 0
            ///     (That means the baseCurve is ignored)
            transitionPoint = 0.0
            
        } else {
            
            /// Get speed at transition point
            let transitionSpeed = baseCurve.derivativeDyOverDx(atT: transitionPoint!) * targetDistance / minDuration
            
            if transitionSpeed > stopSpeed {
            
                /// Get dragCurve at transition point
                ///     Note: We already calculated this before, inside `combinedDistance()`, so this is inefficient. But idk if it matters.
                dragCurve = DragCurve(coefficient: dragCoefficient, exponent: dragExponent, initialSpeed: transitionSpeed, stopSpeed: stopSpeed)
            } else {
                
                DDLogDebug("transitionPoint has been found but transitionSpeed is lower than stopSpeed. So the dragCurve can't cover any distance. This likely means that the baseCurve covers the whole distance on its own exactly.")
                
                assert(transitionPoint == 1)
                transitionPoint = 1
            }
            
        }
        
        /// Get transition time and distance
        guard let transitionPoint = transitionPoint else { fatalError() }
        
        let transitionTime = baseCurve.sampleCurve(onAxis: Bezier.xAxis, atT: transitionPoint) * minDuration
        let transitionDistance = baseCurve.sampleCurve(onAxis: Bezier.yAxis, atT: transitionPoint) * targetDistance
        
        /// Debug
        DDLogDebug("\ntransition time: \(transitionTime*1000), dist: \(transitionDistance), dragTime: \((dragCurve?.timeInterval.length ?? 0)*1000)")
        
        /// Return
        return (transitionTime: transitionTime, transitionDistance: transitionDistance, dragCurve: dragCurve)
    }
    
}

// MARK: - LineHybrid

@objc class LineHybridCurve: HybridCurve {
    
    /// Base Curve
    
    static let _baseCurve: Line = Line(a: 1, b: 0)
    override var baseCurve: Curve {
        get { LineHybridCurve._baseCurve }
        set { fatalError() }
    }
    
    /// Init
    
    @objc init(minDuration: Double, distance: Double, dragCoefficient: Double, dragExponent: Double, stopSpeed: Double) {
        
        /// Init super
        super.init()
        
        /// Validate
        assert(distance > 0)
        
        /// Get transitionTime and distance
        let (transitionTime, transitionDistance, dragCurve) = LineHybridCurve._lineInit(minDuration: minDuration, distance: distance, dragCoefficient: dragCoefficient, dragExponent: dragExponent, stopSpeed: stopSpeed)
        
        /// Store params
        
        self.baseTimeInterval = Interval(start: 0, end: transitionTime)
        self.baseDistanceInterval = Interval(start: 0, end: transitionDistance)
        
        self.dragCurve = dragCurve
        self.dragCoefficient = dragCoefficient
        self.dragExponent = dragExponent
        self.stopSpeed = stopSpeed
    }
    
    /// Init helper
        
    static func _lineInit(minDuration: Double, distance: Double, dragCoefficient: Double, dragExponent: Double, stopSpeed: Double) -> (transitionTime: Double, transitionDistance: Double, dragCurve: DragCurve?) {
        
        /// Get base curve exit speed
        let transitionSpeed = LineHybridCurve._baseCurve.slope * distance / minDuration
        
        /// Use straight line if stopSpeed is too low
        var dragCurve: DragCurve?
        if transitionSpeed <= stopSpeed {
            return (transitionTime: minDuration, transitionDistance: distance, dragCurve: nil)
        }
        
        /// Get dragCurve
        dragCurve = getDragCurve(initialSpeed: transitionSpeed, stopSpeed: stopSpeed, coefficient: dragCoefficient, exponent: dragExponent)
        
        /// Return straight line if getting dragCurve fails for some reason
        guard var dragCurve = dragCurve else {
            assert(false)
            return (transitionTime: minDuration, transitionDistance: distance, dragCurve: nil)
         }
        
        /// Find transition point
        let dragDistance = dragCurve.distanceInterval.length
        var transitionDistance = distance - dragDistance
        
        /// Change dragCurve if transition distance is negative
        if transitionDistance < 0 {
            
            /// Get a dragCurve that exactly covers valueRange
            ///     Note that this means that the slope of the baseCurve is ignored. This might lead to weird feeling speed changes
            
            /// Debug
            DDLogDebug("DragCurve transition distance is negative. Ignoring Line.")
            
            /// Get new curve
            dragCurve = DragCurve(coefficient: dragCoefficient, exponent: dragExponent, distance: distance, stopSpeed: stopSpeed)
            
            /// Set transition Distance to 0
            transitionDistance = 0.0
        }

        /// Get transition time
        let transitionTime = LineHybridCurve._baseCurve.evaluate(atY: transitionDistance / distance) * minDuration
        
        return (transitionTime: transitionTime, transitionDistance: transitionDistance, dragCurve: dragCurve)
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
    override var baseCurve: Curve {
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
        
        let v0 = baseCurve.exitSlope * distance / duration
        self.dragCurve = HybridCurve.getDragCurve(initialSpeed: v0, stopSpeed: stopSpeed, coefficient: dragCoefficient, exponent: dragExponent)
        
    }
}


// MARK: - Base class

class HybridCurve: Curve {
    /// This class is supposed to be subclassed, not used directly.

    /// Constants
//    var bezierEpsilon: Double = 0.01
    
    /// Vars - init
    
    /// BaseCurve
    
    @objc var baseCurve: Curve { get{fatalError()} set{fatalError()} }
    
    @objc var baseTimeInterval: Interval = .unitInterval
    @objc var baseDistanceInterval: Interval = .unitInterval
    @objc var baseDuration: Double { baseTimeInterval.length }
    @objc var baseDistance: Double { baseDistanceInterval.length }
    
    /// DragCurve
    
    fileprivate var dragCoefficient: Double = -1 /// Couldn't we access these through self.dragCurve somehow?
    fileprivate var dragExponent: Double = -1
    fileprivate var stopSpeed: Double = -1
    
    fileprivate var dragCurve: DragCurve?
    
    fileprivate var dragTimeRange: Double {
        guard let c = dragCurve else { return 0 }
        return c.timeInterval.length
    }
    @objc var dragValueRange: Double {
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
    
    fileprivate static func getDragCurve(initialSpeed: Double, stopSpeed: Double, coefficient: Double, exponent: Double) -> DragCurve? {
        
        /// Get dragCurve
        ///     This method does nothing except do some validation and then call the DragCurve initializer. Should probably delete.
        
        let result: DragCurve?
        
        /// Validate & create curve
        if initialSpeed > stopSpeed {
            result = DragCurve(coefficient: coefficient, exponent: exponent, initialSpeed: initialSpeed, stopSpeed: stopSpeed)
        } else {
            DDLogDebug("baseExitSpeed > stopSpeed in HybridCurve init. Not creating dragCurve.")
            result = nil
        }
        
        /// Debug
        
//        DDLogDebug("dragTime: \(dragTimeRange), dragValue: \(dragValueRange), time: \(duration), value: \(distance)")
        
        /// Return
        
        return result
    }
    
    /// Evaluate
    
    override func evaluate(at x: Double) -> Double {
        
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
    var baseTimeIntervalUnit: Interval      { Interval(start: 0, end: baseDuration / duration) }
    var baseDistanceIntervalUnit: Interval  { Interval(start: 0, end: baseDistance / distance) }
    
    var dragTimeIntervalUnit: Interval      { Interval(start: baseDuration / duration, end: 1) }
    var dragDistanceIntervalUnit: Interval  { Interval(start: baseDistance / distance, end: 1) }
    
    /// Other interface
    
    
    @objc func subCurve(at x: Double) -> MFHybridSubCurve {
        
        if x <= baseDuration / duration {
            return kMFHybridSubCurveBase
        } else {
            return kMFHybridSubCurveDrag
        }
        
    }
    
}
