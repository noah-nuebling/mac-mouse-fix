//
// --------------------------------------------------------------------------
// HybridCurve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation
import CocoaLumberjackSwift

@objc class HybridCurve: NSObject, AnimationCurve {
    /// This curve is intended to animate scrolling in a way that resembles the original MMF scrolling algorithm
    /// The first part of the curve  is driven by a BezierCurve, and the second half by a DragCurve.
    /// The drag curve is used to ensure physically accurate, natural-feeling deceleration.
    
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
