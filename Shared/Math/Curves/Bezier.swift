//
// --------------------------------------------------------------------------
// BezierCurve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/*
 See the English and German Wiki pages on Bezier Curves:
    https://en.wikipedia.org/wiki/Bézier_curve#Derivative
 */

import Cocoa
import simd /// Vector stuff
//import ReactiveCocoa
//import ReactiveSwift

/// This class works similar to the AnimationCurve class (Since renamed to `CubicUnitBezier`) I copied from WebKit
/// The difference is that this doesn't have fixed start and end controlPoints at (0,0) and (1,1), and the number of  control points isn't locked at 4. I don't need this extra functionality but it was way to fun to implement.
///
/// It's also likely muchhh slower than the Apple code, because in the Apple code they somehow transform the bezier curve into a polynomial which allows them to samlpe the curve value and derivative in a single line of c code.
/// We, on the other hand, use De-Casteljau's algorithm, which has nested for-loops and is probably in O(n*2) (Where n is the number of controlPoints describing the curve)
/// Edit: Actually, from my (superficial) testing using the Apple Time Profiler, this seems to be faster than AnimationCurve.m! Not sure how that's possible'
/// Edit2: Using simple time profiling with CACurrentMediatime(), the Swift implementation is 50 - 200 times slower than the Objc implementation. That's closer to what I expected.
///     I tested on the same curve, with a 0.001 epsilon on my Early 2015 MBP
///     BezierCurve.swift usually took around 0.0001s (= 100 microseconds = 0.1 ms) to get y(x), while AnimationCurve.m usually took around 0.000001s (= 1 microsecond = 0.001 ms)
///     -> 60 fps is 16.66 ms per frame so the Swift implemenation should be fast enough
/// Edit3: Did some more optimitzations by implementing formulas for the polynomial form of the Bezier Curve and precalculating the coefficients, very similar to how the Apple code does it. Now it's super fast to evaluate!
///     With the new algorithms Swift is only around 5 times slower than ObjC.
///         (Another thing that affected these results is that before I was building for Debug and for these tests I was building for release. - that made Swift a lot faster while barely affecting C IIRC - Edit: Yep, when running an unoptimized DEBUG build, Swift is still around 40 times slower than C)
///     Swift now takes around 0.01 ms to evaluate testing with a 0.08 epsilon, which is very important becuase 0.1 ms was way to slow (irony). I officially overengineered this lol.

/// For optimization, we usually only evaluate the x or the y values for our functions, even though these functions are formally defined to work on points. That's what the MFAxis parameters in some of these functions are for

/// It would be quite a bit nicer to have this be a struct instead of a class because of value semantics and less weird rules around initializing. But alas Swift structs aresn't compatible with Objc

/// # references
/// De-Casteljau's algorithm | German Wikipedia
///     https://en.wikipedia.org/wiki/De_Casteljau%27s_algorithm
/// AnimationCurve.m | Apple Webkit
///     I can't find this on Google anymore but it's included with this Project
///     Edit: I since renamed it to CubicUnitBezier
/// Visual editor for higher order Bezier Curves | Desmos
///     https://www.desmos.com/calculator/xlpbe9bgll
///     https://www.desmos.com/calculator/jbhmbwqnf3
///      ^ edited to only have 5 control point, not 10
/// Article on how to implement cubic bezier curves more efficiently for games
///     http://devmag.org.za/2011/04/05/bzier-curves-a-tutorial/
/// Paper which containts info on how to differentiate the De Casteljau formula
///     https://www.clear.rice.edu/comp360/lectures/old/BezText.pdf

@objc class Bezier: Curve, NSCopying {

    static let xAxis = kMFAxisHorizontal
    static let yAxis = kMFAxisVertical
    let xAxis = Bezier.xAxis
    let yAxis = Bezier.yAxis
    
    /// Control points
    
    let controlPoints: [P]
    let controlPointsX: [Double]
    let controlPointsY: [Double]
    func controlPoints(_ axis: MFAxis) -> [Double] { /// Would be more elegant to use a dict or an enum (enums do that in Swift I think?)
        if axis == xAxis { return controlPointsX }
        else if axis == yAxis { return controlPointsY }
        assert(false, "Invalid axis")
        return [] // This will never happen. Just to silence compiler
    }
    
    /// Polynomial coefficients
    
    var polynomialCoefficients: [P] /// Needs to be var to fill it based on other instance properties in initializer bc Swift is weird
    var polynomialCoefficientsX: [Double]
    var polynomialCoefficientsY: [Double]
    func polynomialCoefficients(_ axis: MFAxis) -> [Double] {
        if axis == xAxis { return polynomialCoefficientsX }
        else if axis == yAxis { return polynomialCoefficientsY }
        assert(false, "Invalid axis")
        return []
    }
    
    /// Other
    
    let isLine: Bool /// When the Bezier is really just a line we can do some optimzations.
    let lineRepresentation: Line?
    
    let maxDegreeForPolynomialApproach: Int = 20
    /// ^ Wikipedia says that "high order curves may lack numeric stability" in polynomial form, and to use Casteljau instead if that happens. Not sure where exactly we should make the cutoff
    
    static let defaultDefaultEpsilon = 0.08 /// Default value for `defaultEpsilon`
    var defaultEpsilon: Double /// Epsilon to be used when none is specified in evaluate(at:) call. This is only a var instead of let because of the debugging function `getMinEpsilon`. If we refactor we shouldn't need it for that either. Should change this.
    
    var degree: Int {
        controlPoints.count - 1
    }
    var n: Int { degree }
    
    var startPoint: P {
        return controlPoints.first!
    }
    var endPoint: P {
        return controlPoints.last!
    }
    
    let xValueRange: Interval
    
    // MARK: Init
    
    /// Helper functions for Init functions

    private class func convertNSPointsToPoints(_ controlNSPoints: [NSPoint]) -> [P] {
        /// Helper function for objc  init functions
        /// Unused - remove
        
        return controlNSPoints.map { (pointNS) -> P in
            var point: P = P.init()
            point.x = Double(pointNS.x)
            point.y = Double(pointNS.y)
            return point
        }
    }
    
    @objc class func cubicUnitPoints(_ px: Double, _ py: Double, _ qx: Double, _ qy: Double) -> [[Double]] {
        return [[0.0, 0.0], [px, py], [qx, qy], [1.0, 1.0]]
    }
    
    private class func convertPointArraysToPoints(_ controlPointsAsArrays: [[Double]]) -> [P] {
        /// Helper function for objc  init functions
        
        return controlPointsAsArrays.map { (pointArray: [Double]) -> P in
            var point: P = P.init()
            point.x = Double(pointArray[0])
            point.y = Double(pointArray[1])
            return point
        }
    }
    
    /// Objc compatible wrappers for the Swift init functions
    
    @objc convenience init(controlPoints controlPointsArr: [[Double]],
                           defaultEpsilon: Double = defaultDefaultEpsilon,
                           xInterval: Interval = .unitInterval,
                           yInterval: Interval = .unitInterval) {
        /// `controlPointsAsArrays` is expected to have this structure: `[[x,y],[x,y],[x,y],...]`
        
        let controlPoints: [P] = Bezier.convertPointArraysToPoints(controlPointsArr)
        self.init(controlPoints: controlPoints, defaultEpsilon: defaultEpsilon, xInterval: xInterval, yInterval: yInterval)
    }
    @objc convenience init(controlPoints controlPointsArr: [[Double]], defaultEpsilon: Double = defaultDefaultEpsilon) {
        let controlPoints: [P] = Bezier.convertPointArraysToPoints(controlPointsArr)
        self.init(controlPoints: controlPoints, defaultEpsilon: defaultEpsilon)
    }
    
    /// Swift init
    
    convenience init(controlPoints: [P],
                     defaultEpsilon: Double = defaultDefaultEpsilon,
                     xInterval: Interval,
                     yInterval: Interval) {
        /**
        This convenience initializer scales the controlPoints' x values to xInterval and the y values to yInterval before creating a curve
         More specifically scales the x values of all controlpoints from the interval spanning from the first to the last controlpoints' x values, and does the same for y values.
         */
        
        assert(controlPoints.count >= 2, "There need to be at least 2 controlPoints") // Code duplication, but idk how to avoid it here
        
        let pFirst = controlPoints.first!
        let pLast = controlPoints.last!
        
        let xIntervalOrigin = Interval.init(start: pFirst.x, end: pLast.x) // Should we use Interval.init(lower:upper) instead, to make sure the x values are ascending?
        let yIntervalOrigin = Interval.init(start: pFirst.y, end: pLast.y)
        
        let pointsInTargetInterval: [P] = controlPoints.map { (point: P) -> P in
            let x = Math.scale(value: point.x, from: xIntervalOrigin, to: xInterval)
            let y = Math.scale(value: point.y, from: yIntervalOrigin, to: yInterval)
            
            return _P(x, y)
        }
        
        self.init(controlPoints: pointsInTargetInterval, defaultEpsilon: defaultEpsilon)
        
    }
    
    init(controlPoints controlPointsArg: [P], defaultEpsilon: Double = defaultDefaultEpsilon) {
        
        /**
         Core init
         - You should make sure you only pass in control points describing curves where
            - 1. The x values of the first and last point are the two extreme (minimal and maximal) x values among all control points x values
            - 2. The curves x values are monotonically increasing / decreasing along the y axis, so that there are no x coordinates for which there are several points on the curve
                - This actually implies 1.
                - There is a proper mathsy name for this but I forgot
                - If it's not the case, it won't necessarily throw an error, but things might behave unpredicably.
         */
        
        /// Set defaultEpsilon
        
        self.defaultEpsilon = defaultEpsilon
        
        /// Remove consective duplicate points
        /// - For optimization. Not sure if significant.
        /// - I'm also not totally sure if the duplicate control points really have no effect at all. I think having two controlPoints in the same point might  give that point more "weight" in where the curve lies.
        
        var controlPoints: [P] = []
        var lastPoint: P? = nil
        for p in controlPointsArg {
            
            var isSame = false
            if let lastPoint = lastPoint {
                isSame = p.x == lastPoint.x && p.y == lastPoint.y
            }
            if isSame { continue }
            
            controlPoints.append(p)
            lastPoint = p
        }
        
        /// Make sure that there are at least 2 points
        assert(controlPoints.count >= 2, "There need to be at least 2 controlPoints");
        
        /// Fill isLine and lineRepresentation
        ///     isLine lets us do some optimizations
        
        isLine = controlPoints.count == 2
        if isLine {
            lineRepresentation = Line(connecting: controlPoints[0], controlPoints[1])
        } else {
            lineRepresentation = nil
        }
        
        /// Fill self.controlPoints
        
        self.controlPoints = controlPoints
        
        /// Fill self.controlPointsX and self.controlPointsY
        
        var controlPointsX: [Double] = []
        var controlPointsY: [Double] = []
        
        for point in controlPoints {
            controlPointsX.append(point.x)
            controlPointsY.append(point.y)
        }
        
        self.controlPointsX = controlPointsX
        self.controlPointsY = controlPointsY
        
        /// Get x values of the start and end points!
        
        let startX = controlPointsX.first!
        let endX = controlPointsX.last!
        
        /// Get x value range
        /// This (and other parts of the code which rely on `xValueRange`) assumes that the curves extreme x values are startX and endX
        /// You should only pass in curves where that's the case
        
        self.xValueRange = Interval.init(lower: startX, upper: endX)
        
        /// Set polynomialCoefficients to anything so we can call super.init()
        /// Only after we called super init, can we access instance properties, which we want to use for calculating the real polynomialCoefficients
        
        self.polynomialCoefficients = []
        self.polynomialCoefficientsX = []
        self.polynomialCoefficientsY = []
        
        /// Init super
        
        super.init()
        
        /// Precalculate coefficients of the polynomial form of the Bezier Curve
        /// Formula according to English Wikipedia
        
        let Ps: [P] = self.controlPoints /// To make maths formulas more readable
        
        /// Fill out the polynomialCoefficient arrays with placeholder values, so we can simply go
        ///   `array[i] = v`, later, instead of having to use `array.append(v)`
        ///   This is super ugly but there doesn't seem to be a better way in swift
        ///     Ideally we'd just allocate space for n+1 elements in the array instead of this but that doesn't seem to be possible in Swift
        
        let placeholderPoint = _P(-1, -1)
        let placeholderPointArray: [P] = [P](repeating: placeholderPoint, count: n+1)
        let placeholderDoubleArray: [Double] = [Double](repeating: -1.0, count: n+1)
        
        self.polynomialCoefficients = placeholderPointArray
        self.polynomialCoefficientsX = placeholderDoubleArray
        self.polynomialCoefficientsY = placeholderDoubleArray
        
        for j in 0...n {
            
            /// Get product
            
            var product: Int = 1
            if 0 <= j-1 { /// Otherwise the range can be be 0...-1 which, just means "skip this" in Maths, but Swift doesn't like it
                for m in 0...j-1 {
                    product *= n-m
                }
            }
            
            /// Get sum
            
            var sumX: Double = 0
            var sumY: Double = 0
            
            for i in 0...j {
                let a: Double = pow(-1, Double(i+j)) / Double(fac(i) * fac(j-i))
                sumX += a * Ps[i].x
                sumY += a * Ps[i].y
            }
            
            /// Put it all together
            
            let xCoefficient: Double = Double(product) * sumX
            let yCoefficient: Double = Double(product) * sumY
            
            /// Fill instance properties
            
            self.polynomialCoefficientsX[j] = xCoefficient
            self.polynomialCoefficientsY[j] = yCoefficient
            self.polynomialCoefficients[j] = P.init(x: xCoefficient, y: yCoefficient)
        }
    }
    
    /// Invalid init
    ///     For InvalidBezier
    
    fileprivate init(forInvalid: Bool) {
        if !forInvalid { fatalError() }
        
        defaultEpsilon = 0.0
        controlPoints = []
        controlPointsX = []
        controlPointsY = []
        polynomialCoefficients = []
        polynomialCoefficientsX = []
        polynomialCoefficientsY = []
        xValueRange = Interval(0.0, 0.0)
        isLine = false
        lineRepresentation = nil
        
        super.init()
    }
    
    /// Copying init
    ///     For copying
    
    private init(copiedFrom other: Bezier, withZone zone: NSZone?) {
        
        defaultEpsilon = other.defaultEpsilon
        controlPoints = other.controlPoints
        controlPointsX = other.controlPointsX
        controlPointsY = other.controlPointsY
        polynomialCoefficients = other.polynomialCoefficients
        polynomialCoefficientsX = other.polynomialCoefficientsX
        polynomialCoefficientsY = other.polynomialCoefficientsY
        xValueRange = other.xValueRange.copy(with: zone) as! Interval
        isLine = other.isLine
        lineRepresentation = other.lineRepresentation?.copy() as! Line? /// I hope this copy function works. Do we even needt to copy? I don't think Line is mutable does that matter?
        
        super.init()
    }
    
    /// Copying
    
    func copy(with zone: NSZone? = nil) -> Any {
        return Bezier(copiedFrom: self, withZone: zone)
    }
    
    // MARK: Sampling the curve
    
    /// - Parameters:
    ///   - axis: Axis which to sample. Either `xAxis` or `yAxis`
    ///   - t: Where to evaluate the curve. Valid values ranges from 0 to 1
    /// - Returns: The x or y value for the input t
    public func sampleCurve(onAxis axis: MFAxis, atT t: Double) -> Double {
        /// The polynomial approach should be very fast but apparentaly becomes "numerically unstable" for larger control point counts. (src. Wikipedia)
        ///     So for a larger degree we use the slower Casteljau algorithm instead
        
        if degree <= maxDegreeForPolynomialApproach {
            return sampleCurvePolynomial(axis, t)
        } else {
            return sampleCurveCasteljau(axis, t)
        }
    }
    
    fileprivate func sampleCurvePolynomial(_ axis: MFAxis, _ t: Double) -> Double {
        
        let C: [Double] = self.polynomialCoefficients(axis)
        
        var sum: Double = 0
        
        /// Applying Horners Rule for optimization
        /// Horners Rule: https://www.math10.com/en/algebra/horner.html
        /// Original Formula: https://wikimedia.org/api/rest_v1/media/math/render/svg/1263b2329c8a60a78a433731dfd88b55d6a37eb0
        for j in (1...n).reversed() {
            sum += C[j]
            sum *= t
        }
        sum += C[0]
        
        return sum
    }
    
    fileprivate func sampleCurveCasteljau(_ axis: MFAxis, _ t: Double) -> Double {
        /// Evaluate at t with De-Casteljau's algorithm. I thonk it's in O(n!) or something?
        
        /// Extract x or y values from controlPoints
        
        var points1D: [Double] = controlPoints(axis)
        
        /// Apply De-Casteljau's algorithm
        
        var pointsCount = points1D.count;
        
        while true {
            pointsCount -= 1
            for i in 0..<pointsCount {
                /// Interpolate between the points at i and at i-1. Write the result into points at i
                points1D[i] = simd_mix(points1D[i], points1D[i+1], t)
            }
            if pointsCount == 1 { /// We evaluated the point
                break
            }
        }
        
        return points1D[0]
    }
    
    // MARK: Derivative
    
    private func sampleDerivative(on axis: MFAxis, at t: Double) -> Double {
        /// See sampleCurve(onAxis:atT:) for context
        /// The explicit algorithm is even slower than Casteljau's algorithm, but it should work the same and couldn't be bothered to implement Casteljau here, too.
        
        if degree <= maxDegreeForPolynomialApproach {
            return sampleDerivativePolynomial(axis, t)
        } else {
            return sampleDerivativeExplicit(axis, t)
        }
        
    }
    
    private func sampleDerivativePolynomial(_ axis: MFAxis, _ t: Double) -> Double {
        
        let C: [Double] = self.polynomialCoefficients(axis)
        
        var sum: Double = 0
        
        /// We take the derivative of the original formula and get
        ///     ```
        ///     B'(t) = sum_{j=1}^{n} t^{j-1} * j * C_j
        ///     ```
        ///     To optimize, we then we apply Horners rule and arrive at the algorithm below
        ///     Also see: original formula: https://wikimedia.org/api/rest_v1/media/math/render/svg/1263b2329c8a60a78a433731dfd88b55d6a37eb0
        
        for j in (2...n).reversed() {
            sum += C[j] * Double(j)
            sum *= t
        }
        sum += C[1]
        
        return sum
        
    }
    
    private func sampleDerivativeExplicit(_ axis: MFAxis, _ t: Double) -> Double {
        /// Implemented according to the explicit derivative formula found on English Wikipedia
        
        let points1D: [Double] = controlPoints(axis)
        
        var sum: Double = 0
        
        for i in 0...n-1 {
            
            sum += bernsteinBasisPolynomial(i, n-1, t) * (points1D[i+1] - points1D[i])
        }
        
        return Double(n) * sum
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
        /// It's a numerical inverse finder. It basically finds the parameter t for a function value x through educated guesses
        
        let initialGuess: Double = Math.scale(value: x, from: self.xValueRange, to: .unitInterval)
        /// ^ Our initial guess for t.
        /// In Apples AnimationCurve.m this was set to x which is an informed guess. We extended the same logic to a general case. (In the Apple implementation, the xValueRange is implicitly 0...1)
        
        /// Try Newtons method
        /// Newtons method finds an input for which the output is 0
        /// So to use this for finding x, we need to shift the curve along the xAxis such the the desired x value is at 0
        /// To achieve that, we subtract x from the sampleCurve() result. We don't need to apply this shifting to sampleDerivative(), because shifting along the xAxis won't affect the derivative with respect to x. (If this sound weird remember the function parameter is t and the output is a point (x,y))
        
        let maxNewtonIterations: Int = 8
        var t = initialGuess
        
        for _ in 1...maxNewtonIterations {
            
            let sampledXShifted = sampleCurve(onAxis: xAxis, atT: t) - x
            
            let error = abs(sampledXShifted)
            if error < epsilon {
                return t
            }
            
            let sampledDerivative = sampleDerivative(on: xAxis, at: t)
            
            if abs(sampledDerivative) < 1e-6 { /// 1e-6 comes from the WebKit implementation I found.
                break
            }
            
            t = t - sampledXShifted / sampledDerivative
            
            /// v In some scenarios, t will be joltet way outside the valid range of [0,1]. If that happens, newtons method will then sometimes find another t where sampleX = x, but with t outside [0,1]. To prevent this, we force t to be inside [0,1] here. Not sure if this has other bad sideeffects.
            
            if (t > 1) {t = 1}
            else if (t < 0) {t = 0}
        }
        
        print("Couldn't solve for t using Newton's method. Using bisection instead") /// Debug
        
        /// Try bisection method for reliability
        
        let tBisect = Math.bisect(searchRange: .unitInterval, targetOutput: x, epsilon: epsilon) { input in sampleCurve(onAxis: xAxis, atT: input) }
        
        if let tBisect = tBisect as? Double {
            return tBisect
        }
        
        /// Failure
        
        print("Bisection failed, too. Failed to solve for x = \(x). Resulting t = \(t)")  // TODO: Can't import CocoaLumberjack right now. Use that instead when possible
        
        return t
        
    }
    
    // MARK: Evaluate
    /// Get y(x)
    
    override func evaluate(at x: Double) -> Double {
        self.evaluate(at: x, epsilon: self.defaultEpsilon)
    }
    
    @objc func evaluate(at x: Double, epsilon: Double) -> Double {
        
        if isLine {
            return lineRepresentation!.evaluate(at: x)
        } else {
            let t: Double = solveForT(x: x, epsilon: epsilon)
            let y: Double = sampleCurve(onAxis: yAxis, atT: t)
            
            return y
        }
    }
    
    // MARK: Derivative dy/dx
    
    @objc func derivativeDyOverDx(atT t: Double) -> Double {
        
        assert(controlPoints.count > 1)
        
        if isLine {
            
            return lineRepresentation!.slope
            
        } else {
            
            /// Our sampleDerivative() function doesn't work for t == 0 and t == 1
            
            if t == 0 {
                return entrySlope
            }
            if t == 1 {
                return exitSlope
            }
            
            /// All parametric functions have this derivative
            let dyDt = sampleDerivative(on: yAxis, at: t)
            let dxDt = sampleDerivative(on: xAxis, at: t)
            
            return dyDt / dxDt
        }
    }
    
    // MARK: Other Interface
    
    var exitSlope: Double {
        
        assert(controlPoints.count > 1)
        
        if isLine {
            
            return lineRepresentation!.slope
            
        } else {
            /// Get last control point
            let cLast = controlPoints[self.n]
            /// Find first controlPoint before cLast that is different from cLast
            var cPrevIndex: Int = self.n-1;
            var cPrev: P = controlPoints[cPrevIndex];
            while (cPrev.x == cLast.x && cPrev.y == cLast.y) { /// Loop while cPrev == cLast
                cPrevIndex -= 1
                cPrev = controlPoints[cPrevIndex]
            }
            
            /// Find slope
            let slope = (cLast.y - cPrev.y) / (cLast.x - cPrev.x)
            
            return slope
        }
    }
    
    var entrySlope: Double {
        
        assert(controlPoints.count > 1)
        
        if isLine {
            
            return lineRepresentation!.slope
            
        } else {
            
            /// Get first control point
            let cFirst = controlPoints[0]
            /// Find first controlPoint after cFirst that is different from cFirst
            var cNextIndex: Int = 1;
            var cNext: P = controlPoints[cNextIndex];
            while cFirst.x == cNext.x && cFirst.y == cNext.y { /// Loop while cFirst == cNext
                cNextIndex += 1
                cNext = controlPoints[cNextIndex]
            }
            
            /// Find slope
            let slope = (cNext.y - cFirst.y) / (cNext.x - cFirst.x)
            
            return slope
        }
    }

    
    // MARK: Debug
    
    @objc func getMinEpsilon(forResolution resolution: Int, startEpsilon: Double, epsilonEpsilon: Double) -> Double {
        
        /// This is very inefficient, only meant for debugging
        /// Not totally sure if this works. It's sort of confusing and the results are weird and I had a a headache when I wrote this.
        
        if !runningPreRelease() {
            DDLogWarn("getMinEpsilon called in a non-prerelease. This is very slow.")
        }
        
        /// Define helper function
        
        let checkMonotony = { (points: [P]) -> Bool in
            
            var lastY = -Double.infinity
            
            for p in points {
                if p.y <= lastY {
                    return false
                }
                lastY = p.y
            }
            
            return true
        }
        
        /// Set epsilon to startEpsilon and store og
        
        let ogEpsilon = defaultEpsilon
        defaultEpsilon = startEpsilon
        
        /// Find upper / lower bound
        
        var upper: Double = Double.infinity
        var lower: Double = -Double.infinity
        
        let trace = self.traceAsPoints(startX: xValueRange.lower, endX: xValueRange.upper, nOfSamples: resolution) /// We only need to trace xValues here
        let isMonotonous = checkMonotony(trace)
        
        var previous: Double
        
        if isMonotonous {
            previous = defaultEpsilon
            defaultEpsilon *= 2.0
        } else {
            previous = defaultEpsilon
            defaultEpsilon /= 2.0
        }
        
        let wasMonotonous = isMonotonous
        
        while true {
            
            let trace = self.traceAsPoints(startX: xValueRange.lower, endX: xValueRange.upper, nOfSamples: resolution) /// We only need to trace xValues here
            let isMonotonous = checkMonotony(trace)
            
            if wasMonotonous {
                
                if isMonotonous {
                    previous = defaultEpsilon
                    defaultEpsilon *= 2.0
                } else {
                    lower = previous
                    upper = defaultEpsilon
                    break
                }
                
                if defaultEpsilon == .infinity {
                    return .infinity
                }
                
            } else {
                
                if !isMonotonous {
                    previous = defaultEpsilon
                    defaultEpsilon /= 2.0
                } else {
                    upper = previous
                    lower = defaultEpsilon
                    break
                }
                
                if defaultEpsilon == 0.0 {
                    return 0.0
                }

            }
            
        }
        
        /// Bisection
        /// Not using our standard bisection function because the output of the function we want to bisect is just the isMonotonous boolean, and we want to find the input for which this boolean flips. With normal bisection we want to find an input such that the output value is within an epsilon of some target value. I don't know how you could map the task at hand to normal bisection.
        
        var result: Double = -1.0
        var distanceToLast = Double.infinity
        
        while true {
            
            let middle = Math.scale(value: 0.5, from: .unitInterval, to: Interval(lower, upper))
            distanceToLast = upper - middle
            if abs(distanceToLast) < epsilonEpsilon {
                result = middle
                break
            }
            defaultEpsilon = middle
            let trace = traceAsPoints(startX: xValueRange.lower, endX: xValueRange.upper, nOfSamples: resolution, bias: 0.0)
            let isMonotonous = checkMonotony(trace)
            
            if isMonotonous {
                lower = middle
            } else {
                upper = middle
            }
        }
        
        /// Restore epsilon & return
        defaultEpsilon = ogEpsilon
        return result
    }
}

@objc class InvalidBezier: Bezier {
    
    init() {
        /// Is this 'invalid' stuff really a good architecture? We're allocating all this stuff for nothing.
        super.init(forInvalid: true)
    }
    
    override func evaluate(at x: Double) -> Double {
        fatalError()
    }
}
