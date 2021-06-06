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
///
/// It's also likely muchhh slower than the Apple code, because in the Apple code they somehow transform the bezier curve into a polynomial which allows them to samlpe the curve value and derivative in a single line of c code.
/// We, on the other hand, use De-Casteljau's algorithm, which has nested for-loops and is probably in O(n^2) (Where n is the number of controlPoints describing the curve)
/// Edit: Actually, from my (superficial) testing using the Apple Time Profiler, this seems to be faster than AnimationCurve.m! Not sure how that's possible'
/// Edit2: Using simple time profiling with CACurrentMediatime(), the Swift implementation is 50 - 200 times slower than the Objc implementation. That's closer to what I expected.
///     I tested on the same curve, with a 0.001 epsilon on my Early 2015 MBP
///     BezierCurve.swift usually took around 0.0001s (= 100 microseconds = 0.1 ms) to get y(x), while AnimationCurve.m usually took around 0.000001s (= 1 microsecond = 0.001 ms)
///     -> 60 fps is 16.66 ms per frame so the Swift implemenation should be fast enough

/// For optimization, we usually only evaluate the x or the y values for our functions, even though these functions are formally defined to work on points. That's what the MFAxis parameters in some of these functions are for

/// It would be quite a bit nicer to have this be a struct instead of a class because of value semantics and less weird rules around initializing. But alas Swift structs aresn't compatible with Objc

/// # references
/// De-Casteljau's algorithm | German Wikipedia
///     https://en.wikipedia.org/wiki/De_Casteljau%27s_algorithm
/// Bezier Curves | Wikipedia (German page is really good, too)
///     https://en.wikipedia.org/wiki/Bézier_curve#Derivative
/// AnimationCurve.m | Apple Webkit
///     I can't find this on Google anymore but it's included with this Project
/// Visual editor for higher order Bezier Curves | Desmos
///     https://www.desmos.com/calculator/xlpbe9bgll
///     https://www.desmos.com/calculator/jbhmbwqnf3 <- edited to only have 5 control point, not 10
/// Article on how to implement cubic bezier curves more efficiently
///     http://devmag.org.za/2011/04/05/bzier-curves-a-tutorial/

@objc class BezierCurve: NSObject, Curve {

    typealias Point = Vector;
    let xAxis = kMFAxisHorizontal
    let yAxis = kMFAxisVertical
    
    let controlPoints: [Point]
    
    let controlPointsX: [Double]
    let controlPointsY: [Double]
    
    var P: [Point] { controlPoints }
    
    /// Helper function to initializer the controlPointsX and controlPointsY properties.
    fileprivate func controlPoints(onAxis axis: MFAxis) -> [Double] {
        
        switch axis {
        case xAxis:
            return controlPointsX
        case yAxis:
            return controlPointsY
        default:
            assert(false, "Invalid axis")
        }
        
        return [-1.0]; // This will never happen. Just to silence compiler.
    }
    
    let maxPolynomialDegree: Int = 20
    /// ^ Wikipedia says that "high order curves may lack numeric stability" in polynomial form, and to use Casteljau instead if that happens. Not sure where exactly we should make the cutoff
    
    var polynomialCoefficients: [Point]
    
    let defaultEpsilon: Double // Epsilon to be used when none is specified in evaluate(at:) call // Have to make this var to prevent compiler errors in init. Not sure why
    
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
    
    
    // MARK: Init
    
    /// Helper function for objc  init functions
    fileprivate class func convertNSPointsToPoints(_ controlNSPoints: [NSPoint]) -> [BezierCurve.Point] {
        return controlNSPoints.map { (pointNS) -> Point in
            var point: Point = Point.init()
            point.x = Double(pointNS.x)
            point.y = Double(pointNS.y)
            return point
        }
    }
    
    // Objc compatible wrappers for the Swift init functions
    
    @objc convenience init(controlNSPoints: [NSPoint]) {
        let controlPoints: [Point] = BezierCurve.convertNSPointsToPoints(controlNSPoints)
        self.init(controlPoints: controlPoints)
    }
    
    @objc convenience init(controlNSPoints: [NSPoint], defaultEpsilon: Double) {
        let controlPoints: [Point] = BezierCurve.convertNSPointsToPoints(controlNSPoints)
        self.init(controlPoints: controlPoints, defaultEpsilon: defaultEpsilon)
    }
    
    // Swift init functions
    
    ///  Sets defaultEpsilon to a default value
    convenience init(controlPoints: [Point]) {
        self.init(controlPoints: controlPoints, defaultEpsilon: 0.001)
    }
    
    /// You should make sure you only pass in control points describing curves where
    /// 1. The x values of the first and last point are the two extreme (minimal and maximal) x values among all control points x values
    /// 2. The curves x values are monotonically increasing / decreasing along the y axis, so that there are no x coordinates for which there are several points on the curve
    ///     - This actually implies the first point
    ///     - There is a proper mathsy name for this but I forgot
    /// If it's not the case, it won't necessarily throw an error, but things might behave unpredicably.
    init(controlPoints: [Point], defaultEpsilon: Double) {
        
        // Make sure that there are at least 2 points
        
        assert(controlPoints.count >= 2, "There need to be at least 2 controlPoints");
        
        // Set defaultEpsilon
        
        self.defaultEpsilon = defaultEpsilon
        
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
        
        // Get x values of the start and end points!
        
        let startX = controlPointsX.first!
        let endX = controlPointsX.last!
        
        // Get x value range
        // This assumes that the curves extreme x values are startX and endX which is not necessarily the case
        // You should only pass in curves where that's the case
        
        self.xValueRange = ContinuousRange.init(lower: startX, upper: endX)
        
        // Set polynomialCoefficients to anything so we can call super.init()
        // After we called super init, we can access 
        
        self.polynomialCoefficients = []
        
        // Init super
        
        super.init()
        
        // Precalculate coefficients of the polynomial form
        // Formula according to Wikipedia
        
        for j in 0...n {
            for i in 0...j {
                
                let a: Double = (-1 ** Double((i+j))) / Double(fac(i) * fac(j-i))
            }
        }
    }
    
    // MARK: Sample curve
    
    /// - Parameters:
    ///   - axis: Axis which to sample
    ///   - t: Where to evaluate the curve. Valid values ranges from 0 to 1
    /// - Returns: The x or y value for the input t
    private func sampleCurve(onAxis axis: MFAxis, atT t: Double) -> Double {
        
        if (degree > maxPolynomialDegree) {
            return sampleCurveCasteljau(axis, t)
        } else {
            return sampleCurvePolynomial(axis, t)
        }
    }
    
    fileprivate func sampleCurvePolynomial(_ axis: MFAxis, _ t: Double) -> Double {
        return 0
    }
    
    /// Source: English Wikipedia on Bezier Curves
    /// This should be even slower than Casteljau
    fileprivate func sampleCurveExplicit(onAxis axis: MFAxis, atT t: Double) -> Double {
        
        // Extract x or y values from controlPoints
        
        let P: [Double] = controlPoints(onAxis: axis)
        
        // Calculate using explicit formula
        
        var sum: Double = 0
        
        for i: Int in 0...n {
            sum += bernsteinBasisPolynomial(i, n, t) * P[i]
        }
        
        return sum
        
    }
    
    /// Evaluate at t with De-Casteljau's algorithm. I thonk it's in O(n!).
    fileprivate func sampleCurveCasteljau(_ axis: MFAxis, _ t: Double) -> Double {
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
        
        return points1D[0]
    }
    
    // MARK: Derivative
    
    private func sampleDerivative(on axis: MFAxis, at t: Double) -> Double {
        
        if (degree > maxPolynomialDegree) {
            return sampleDerivativeExplicit(axis, t)
        } else {
            return sampleDerivativePolynomial(axis, t)
        }
        
    }
    
    private func sampleDerivativePolynomial(_ axis: MFAxis, _ t: Double) -> Double {
        return 0
    }
    
    /// Implemented according to the explicit derivative formula found on English Wikipedia
    private func sampleDerivativeExplicit(_ axis: MFAxis, _ t: Double) -> Double {
        
        let points1D: [Double] = controlPoints(onAxis: axis)
        
        var sum: Double = 0
        
        for i in 0...n-1 {
            
            sum += bernsteinBasisPolynomial(i, n-1, t) * (points1D[i+1] - points1D[i]) // Maybe we
        }
        
        return Double(n) * sum
    }
    
    /// Derivative according to German Wikipedia
    /// Doesn't work
    private func sampleDerivativeExplicitAlternative(on axis: MFAxis, at t: Double) -> Double {
        
        let points1D: [Double] = controlPoints(onAxis: axis)
        
        var sum: Double = 0
        
        for i in 0...n {
            
            sum += bernsteinBasisPolynomial(i, n, t) * points1D[i]
        }
        
        return sum
    }
    
    // MARK: Bernstein Basis Polynomial
    
    private func bernsteinBasisPolynomial(_ i: Int, _ n: Int, _ t: Double) -> Double {
        /// Helper function for eplicit definitions
        
        assert((0...n).contains(i))
        
        let a: Double = Double(Math.choose(n, i))
        let b: Double = pow(t, Double(i))
        let c: Double = pow(1-t, Double(n-i))
        
        return a * b * c
    }
    
    
    // MARK: Get t(x)
    
    private func solveForT(x: Double, epsilon: Double) -> Double {
        /// This function is mostly copied from AnimationCurve.m by Apple
        /// It's a numerical inverse finder. Finds the parameter t for a function value x through educated guesses
        
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
            
//            print("Sampling took: \(sampleTime) sampled x: \(sampledXShifted + x) at t: \(t)")
            
            let error = abs(sampledXShifted)
            if error < epsilon {
//                print("Found t(x) using newtons method!")
                return t
            }
            
            let sampledDerivative = sampleDerivative(on: xAxis, at: t)
            
//            print("Derivative sampling took: \(derivativeTime), sampled dx: \(sampledDerivative) at t: \(t)")
            
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
    
    // MARK: Evaluate
    /// Get y(x)
    
    @objc func evaluate(at x: Double) -> Double {
        self.evaluate(at: x, epsilon: self.defaultEpsilon)
    }
    
    @objc func evaluate(at x: Double, epsilon: Double) -> Double {
        
//        print("Evaluating at x = \(x)")
        
        let t: Double = solveForT(x: x, epsilon: epsilon)
        let y: Double = sampleCurve(onAxis: yAxis, atT: t)
        
//        print("Evaluation complete: x:\(x) -> t:\(t) -> y:\(y)")
        
        return y
    }
    
}
