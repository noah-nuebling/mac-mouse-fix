//
// --------------------------------------------------------------------------
// Curve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa

typealias RawCurve = (Double) -> Double

@objc class CurveTools: NSObject {
    
    /// This stuff is taken from MMF Nuxt Website > animationCurveTransform.ts
    
    @objc class func transformCurve(_ curve: @escaping RawCurve, _ transform: @escaping (Double) -> Double) -> RawCurve {
        
        /// Returns a new curve which applies `transform` to the output of `curve`
        
        let transformed = { x in
            let a = curve(x)
            let result = transform(a)
            return result
        }
        
        return transformed
    }
    @objc class func combineCurves(_ curve1: @escaping RawCurve, _ curve2: @escaping RawCurve, transform: @escaping (Double, Double) -> Double) -> RawCurve {
        
        /// Returns a new curve which applies `transform` to the output of both `curve1` and `curve2`
        
        let transformed = { x in
            let a = curve1(x)
            let b = curve2(x)
            let result = transform(a, b)
            return result
        }
        
        return transformed
    }
}

@objc class Curve: NSObject {
    
    ///
    /// Main
    ///
    
    @objc func evaluate(at x: Double) -> Double {
        
        /// Notes:
        /// TouchAnimatorBase.swift expects this to pass through (0,0) and (1,1)
        
        if let rawCurve = rawCurve {
            let result = rawCurve(x)
            return result
        }
        
        fatalError()
    }
    
    ///
    /// init
    ///
    /// Notes:
    /// - At the time of writing, we mostly use subclasses of Curve, but for more lightweight, one-time uses, it should be nice to just use the closure init instead of defining a class.
    
    override init() {
        super.init()
    }
    
    var rawCurve: RawCurve? = nil
    init(rawCurve: @escaping RawCurve) {
        self.rawCurve = rawCurve
    }
    
    ///
    /// Debug
    ///
    
    @objc func stringTrace(startX x0: Double, endX x1: Double, nOfSamples: Int, bias: Double = 1.0) -> String {
        
        let trace = traceAsPoints(startX: x0, endX: x1, nOfSamples: nOfSamples, bias: 1.0)
        var traceStr: String = String()
        
        for p in trace {
            traceStr.append("(\(p.x),\(p.y))\n")
        }
        
        return traceStr
    }
    
    @objc func traceSpeed(startX x0: Double, endX x1: Double, nOfSamples: Int, bias: Double = 1.0) -> [[Double]] {
        /// Our AccelerationCurves is defined in terms of pointerSens(mouseSpeed)
        ///  But Apple's accelerationCurves are defined as pointerSpeed(mouseSpeed). This function let's us create a trace of that
        return traceAsPoints(startX: x0, endX: x1, nOfSamples: nOfSamples, bias: bias).map { p in
            let x = p.x
            let y = p.y * x
            return [x, y]
        }
    }
    
    @objc func trace(startX x0: Double, endX x1: Double, nOfSamples: Int, bias: Double = 1.0) -> [[Double]] {
        return traceAsPoints(startX: x0, endX: x1, nOfSamples: nOfSamples, bias: bias).map { p in [p.x, p.y] }
    }
    
    func traceAsPoints(startX x0: Double, endX x1: Double, nOfSamples: Int, bias: Double = 1.0) -> [P] {
        
        /// `bias` makes the algorithm take more samples at smaller x values. 1.0 is no bias.
        
        var trace: Array<P> = Array()
        
        let xInterval = Interval(x0, x1)
        
        for i in 0..<nOfSamples {
            let unitI = Math.scale(value: Double(i), from: Interval(location: 0, length: Double(nOfSamples-1)), to: .unitInterval)
            let biasedI = pow(Double(unitI), bias)
            let x = Math.scale(value: biasedI, from: .unitInterval, to: xInterval)
            let y = evaluate(at: x)
            
            trace.append(_P(x, y))
            
        }
        
        return trace;
    }
}

@objc extension Curve {
    
    ///
    /// AnimationCurve extension
    ///     We actually only need duration and distance for Hybrid animation curves not pure Bezier animation curves
    
//    @objc var duration: Double { fatalError() }
//    @objc var distance: Double { fatalError() }
    
}

@objc extension Curve {
    
    ///
    /// AccelerationCurve extension
    ///
    
//    @objc func createAccelerationTable(numberOfPoints: Int, endX x1: Double, accelIndex: Double) -> CFData { /// This is unused I think
//        let trace = self.trace(startX: 0, endX: x1, nOfSamples: numberOfPoints)
//        let traceNS = trace.map { p in
//            return [NSNumber(value: p[0]), NSNumber(value: p[1])]
//        }
//        let table = createAccelerationTableWithArray(traceNS, accelIndex)
//        return table.takeRetainedValue()
//    }
}
