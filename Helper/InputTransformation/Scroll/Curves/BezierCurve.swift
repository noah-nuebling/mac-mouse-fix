//
// --------------------------------------------------------------------------
// BezierCurve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

/*
 See the English and German Wiki pages on Bezier Curves:
    https://en.wikipedia.org/wiki/Bézier_curve#Derivative
 */

import Cocoa
import simd // Vector stuff
//import CocoaLumberjack // Doesn't work for some reason
import ReactiveCocoa
import ReactiveSwift

/// This class works similar to the AnimationCurve class I copied from WebKit
/// The difference is that this doesn't have fixed start and end controlPoints at (0,0) and (1,1), and the number of  control points isn't locked at 4
/// It's also likely muchhh slower than the Apple code, becuase in the Apple code they somehow transform the bezier curve into a polynomial which allows them to samlpe the curve value and derivative in a single line of c code.
/// We, on the other hand, use De-Casteljau's algorithm, which has nested for-loops and is probably in O(n^2)

/// For optimization, we usually only evaluate the x or the y values for our functions, even though they are formally defined to work on points. That's what the MFAxis parameters in some of these functions are for

/// # references
/// De-Casteljau's algorithm | German Wikipedia
/// https://en.wikipedia.org/wiki/De_Casteljau%27s_algorithm
/// Bezier Curves | Wikipedia (German page is really good, too)
/// https://en.wikipedia.org/wiki/Bézier_curve#Derivative
/// AnimationCurve.m | Apple Webkit
/// I can't find this on Google anymore but it's included with this Project

@objc class BezierCurve: NSObject {

    typealias Point = Vector;
    let xAxis = kMFAxisHorizontal
    let yAxis = kMFAxisVertical
    
    
    let controlPoints: [Point]
    
    let controlPointsX: [Double]
    let controlPointsY: [Double]
    
    func controlPoints(onAxis axis: MFAxis) -> [Double] {
        
        switch axis {
        case xAxis:
            return controlPointsX
        case yAxis:
            return controlPointsY
        default:
            assert(false, "Invalid axis")
        }
    }
    
    var degree: Int {
        controlPoints.count - 1
    }
    var n: Int { degree }
    
    var startPoint: Point {
        return controlPoints.first!
    }
    var endPoint: Point {
        return controlPoints.last!
    }
    
    let xValueRange: ContinuousRange
    
    @objc convenience init(controlNSPoints: [NSPoint]) {
        
        // Convert NSPonit based control points to Point based
        
        let controlPoints: [Point] = controlNSPoints.map { (pointNS) -> Point in
            var point: Point = Point.init()
            point.x = Double(pointNS.x)
            point.y = Double(pointNS.y)
            return point
        }
        
        // Call designated initializer
        
        self.init(controlPoints: controlPoints)
    }
    
    init(controlPoints: [Point]) {
        
        // Make sure that there are at least 2 points
        
        assert(controlPoints.count >= 2, "There need to be at least 2 controlPoints");
        
        // Fill self.controlPoints
        
        self.controlPoints = controlPoints
        
        // Fill self.controlPointsX and self.controlPointsY
        
        var controlPointsX: [Double] = []
        var controlPointsY: [Double] = []
        
        for point in controlPoints {
            controlPointsX.append(point.x)
            controlPointsY.append(point.y)
        }
        self.controlPointsX = controlPointsX
        self.controlPointsY = controlPointsY
        
        // Make sure that X values are monotonically increasing
        // This is not a general restriction on Bezier curves but makes a ton of sense for how we want to use them
        
        var previousXValue: Double = self.controlPointsX.first!
        for i in 1..<self.controlPointsX.count {
            let xValue: Double = self.controlPointsX[i]
            assert(previousXValue <= xValue)
            previousXValue = xValue
        }
        
        // Now we know what minX and maxX are!
        
        let startX = controlPointsX.first!
        let endX = controlPointsX.last!
        
        self.xValueRange = ContinuousRange.init(lower: startX, upper: endX)
        
        // Init super
        
        super.init()
    }
    
    /// Evaluate at t with De-Casteljau's algorithm
    /// - Parameters:
    ///   - axis: Axis which to sample
    ///   - t: Where to evaluate the curve. Valid values ranges from 0 to 1
    /// - Returns: The x or y value for the input t
    private func sampleCurve(onAxis axis: MFAxis, atT t: Double) -> Double {
        
        // Extract x or y values from controlPoints
        
        var points1D: [Double] = controlPoints(onAxis: axis)
        
        // Apply De-Casteljau's algorithm
        
        var pointsCount = points1D.count;
        
        while true {
            pointsCount -= 1
            for i in 0..<pointsCount {
                // Interpolate between the points at i and at i-1. Write the result into points at i
                points1D[i] = simd_mix(points1D[i], points1D[i+1], t)
            }
            if pointsCount == 1 { // We evaluated the point
                break
            }
        }
        
//        print("Sampling at t = \(t) -> \(points1D[0])")
        
//        assert(points1D.count == 1) // This assertion doesn't make sense, because we're always writing into the same array and it doesn't shrink in size
        return points1D[0]
        
    }
    
    private func bernsteinBasisPolynomial(_ i: Int, _ n: Int, _ t: Double) -> Double {
        
        assert((0...n).contains(i))
        
        let a: Double = Double(Math.choose(n, i))
        let b: Double = pow(t, Double(i))
        let c: Double = pow(1-t, Double(n-i))
        
        return a * b * c
    }
    
    
    /// Derivative according to German Wikipedia
    /// Doesn't work
    private func sampleDerivativeAlternative(on axis: MFAxis, at t: Double) -> Double {
        
        let points1D: [Double] = controlPoints(onAxis: axis)
        
        var sum: Double = 0
        
        for i in 0...n {
            
            sum += bernsteinBasisPolynomial(i, n, t) * points1D[i]
        }
        
        return sum
    }
    
    /// Derivative according to English Wikipedia
    private func sampleDerivative(on axis: MFAxis, at t: Double) -> Double {
        
        let points1D: [Double] = controlPoints(onAxis: axis)
        
        var sum: Double = 0
        
        for i in 0...n-1 {
            
            sum += bernsteinBasisPolynomial(i, n-1, t) * (points1D[i+1] - points1D[i])
        }
        
        return Double(n) * sum
    }
    
    
    
    /// This function is mostly copied from AnimationCurve.m by Apple
    private func solveForT(x: Double, epsilon: Double) -> Double {
        
        let initialGuess: Double = Math.scale(value: x, fromRange: self.xValueRange, toRange: ContinuousRange.normalRange())
        // ^ Our initial guess for t.
        // In Apples AnimationCurve.m this was set to x which is an informed guess that's just as good as this one. There, the xValueRange is implicitly 0...1
        
        // Try Newtons method
        // Newtons method finds an input for which the output is 0
        // So to use this for finding x, we need to shift the curve along the xAxis such the the desired x value is at 0
        // To achieve that, we subtract x from the sampleCurve() result. We don't need to apply this shifting to sampleDerivative(), because shifting won't affect the derivative
        
//        print("Finding t, given x = \(x)")
//        print("Initial guess for t: \(t)")
//        print("Trying Newtons method:")
        
        let maxNewtonIterations: Int = 8
        var t = initialGuess
        
        for _ in 1...maxNewtonIterations {
            
            let sampledXShifted = sampleCurve(onAxis: xAxis, atT: t) - x
            
//            print("sampled x: \(sampledXShifted + x) at t: \(t)")
            
            let error = abs(sampledXShifted)
            if error < epsilon {
//                print("Found t(x) using newtons method!")
                return t
            }
            let sampledDerivative = sampleDerivative(on: xAxis, at: t)
            
//            print("sampled dx: \(sampledDerivative) at t: \(t)")
            
            if abs(sampledDerivative) < 1e-6 {
//                print("Derivative too small - aborting newtons method")
                break
            }
            
            t = t - sampledXShifted / sampledDerivative
        }
        
//        print("Newtons method didn't work. Try bisection instead")
        
        // Try bisection method for reliability
        
        t = initialGuess
        
        var searchRange = ContinuousRange.normalRange()
        
        if t <= searchRange.lower {
            return searchRange.lower
        } else if searchRange.upper <= t {
            return searchRange.upper
        }
        
        while (searchRange.lower < searchRange.upper) {
            
            let sampledX = sampleCurve(onAxis: xAxis, atT: t)
            
            if fabs(sampledX - x) < epsilon {
//                print("Found t using bisection! t:\(t)")
                return t
            }
            if sampledX < x {
                searchRange = ContinuousRange.init(lower: t, upper: searchRange.upper)
            } else {
                searchRange = ContinuousRange.init(lower: searchRange.lower, upper: t)
            }
            t = Math.scale(value: 0.5, fromRange: ContinuousRange.normalRange(), toRange: searchRange)
        }
        
        
        // Failure
        
//        print("Bisection failed, too. Failed to solve for x = \(x). Resulting t = \(t)")  // TODO: Can't import CocoaLumberjack right now. Use that instead when possible
        
        return t
        
    }
    
    @objc public func evaluate(atX x: Double, epsilon: Double) -> Double {
        
//        print("Evaluating at x = \(x)")
        
        let t: Double = solveForT(x: x, epsilon: epsilon)
        let y: Double = sampleCurve(onAxis: yAxis, atT: t)
        
//        print("Evaluation complete: x:\(x) -> t:\(t) -> y:\(y)")
        
        return y
    }
    
}
