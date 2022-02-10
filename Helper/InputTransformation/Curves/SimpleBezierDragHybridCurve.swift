//
// --------------------------------------------------------------------------
// SimpleBezierDragHybridCurve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation
import CocoaLumberjackSwift

@objc class SimpleBezierDragHybridCurve: NSObject, AnimationCurve {
    /// This curve is intended to animate scrolling in a way that resembles the original MMF scrolling algorithm
    /// The first part of the curve  is driven by a BezierCurve, and the second half by a DragCurve.
    /// The drag curve is used to ensure physically accurate, natural-feeling deceleration.
    ///
    /// This is a 'Simple' Hybrid curve because it doesn't let you specify or retrieve the distance and duration of the whole curve, but only of the 'Base' curve. (The whole curve consists of the Base curve as well as the the Drag curve.)
    ///
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
    
    let bezierEpsilon: Double = 0.08
    
    /// Vars - init
        
    let baseCurve: Bezier
    
    let baseTimeInterval: Interval
    let baseValueInterval: Interval
    var baseTimeRange: Double { baseTimeInterval.length }
    var baseValueRange: Double { baseValueInterval.length }
    
    let dragCoefficient: Double
    let dragExponent: Double
    let stopSpeed: Double
    
    var dragCurve: DragCurve?
    
    /// Vars - Interface

    @objc var dragTimeRange: Double {
        guard let c = dragCurve else { return 0 }
        return c.timeInterval.length
    }
    @objc var dragValueRange: Double {
        guard let c = dragCurve else { return 0 }
        return c.distanceInterval.length
    }
    
    @objc var timeInterval: Interval { Interval(start: 0, end: baseTimeRange + dragTimeRange) }
    @objc var valueInterval: Interval { Interval(start: 0, end: baseValueRange + dragValueRange) }
    @objc var timeRange: Double { timeInterval.length }
    @objc var valueRange: Double { valueInterval.length }
    
    
    /// Init
    
    @objc init(baseCurve: Bezier, baseTimeRange: Double, baseValueRange: Double, dragCoefficient: Double, dragExponent: Double, stopSpeed: Double) {
        
        /// baseCurve is assumed to pass through (0,0) and (1,1)
        /// The baseValueRange and baseTimeRange are for the Bezier (aka "base") curve.
        ///     A Drag curve will be appended to the the base curve for natural deceleration. This will increase the timeRange and valueRange of the Hybrid curve to be larger than `baseTimeRange` and `baseValueRange`.
        
        /// Store params
        
        self.baseCurve = baseCurve
        self.baseTimeInterval = Interval(start: 0, end: baseTimeRange)
        self.baseValueInterval = Interval(start: 0, end: baseValueRange)
        
        self.dragCoefficient = dragCoefficient
        self.dragExponent = dragExponent
        self.stopSpeed = stopSpeed
        
        /// Get exit speed of baseCurve (== initial speed of dragCurve)
        
        let baseExitSpeed = baseCurve.exitSlope! * baseValueRange / baseTimeRange
        
        /// Get dragCurve
        
        if baseExitSpeed > stopSpeed {
            self.dragCurve = DragCurve(coefficient: dragCoefficient, exponent: dragExponent, initialSpeed: baseExitSpeed, stopSpeed: stopSpeed)
        } else {
            DDLogDebug("baseExitSpeed > stopSpeed in HybridCurve init. Not creating dragCurve.")
            self.dragCurve = nil
        }
        
        /// Init super
        
        super.init()
        
        /// Debug
        
        DDLogDebug("dragTime: \(dragTimeRange), dragValue: \(dragValueRange), time: \(timeRange), value: \(valueRange)")
        
    }
    
    
    /// Evaluate
    
    @objc func evaluate(at x: Double) -> Double {
        
        let result: Double
        
        if x <= baseTimeRange / timeRange {
            
            var baseCurveResult = baseCurve.evaluate(at: Math.scale(value: x, from: baseTimeIntervalUnit, to: .unitInterval))
            if baseCurveResult > 1 { baseCurveResult = 1 } /// The baseCurveResult is sometimes 1.00000000002 leading to assert failures in scaling code
            result = Math.scale(value: baseCurveResult, from: .unitInterval, to: baseValueIntervalUnit)
//            DDLogDebug("HybridCurve base eval: (\(x),   \(result))") /// Debug
        } else {
            if let c = dragCurve  {
                let dragCurveResult = c.evaluate(at: Math.scale(value: x, from: dragTimeIntervalUnit, to: .unitInterval))
                result = Math.scale(value: dragCurveResult, from: .unitInterval, to: dragValueIntervalUnit)
    //            DDLogDebug("HybridCurve drag eval: (\(x),   \(result))") /// Debug
            } else {
                DDLogWarn("Tried to evalueate HybridCurve at DragCurve but DragCurve doesn't exist. x: \(x), baseTimeRange/timeRange: \(baseTimeRange/timeRange)")
                result = x
            }
        }
        
        return result
    }
    
    /// Evaluate - helpers
    var baseTimeIntervalUnit: Interval { Interval(start: 0, end: baseTimeRange / timeRange) }
    var dragTimeIntervalUnit: Interval { Interval(start: baseTimeRange / timeRange, end: 1) }
    
    var baseValueIntervalUnit: Interval { Interval(start: 0, end: baseValueRange / valueRange) }
    var dragValueIntervalUnit: Interval { Interval(start: baseValueRange / valueRange, end: 1) }

    
}
