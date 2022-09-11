//
// --------------------------------------------------------------------------
// PolynomialCapAccelerationCurve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

/// After playing around with NaturalAccelerationCurve I found it too floaty.
/// The cubic polynomial curve `f(x) = (ax + (bx)^2 + (cx)^3 + (dx)^4) / x` that the Apple Driver generates when using parametric acceleration feels better / more predictable to me.
/// You can see how we configured the parameters for that curve in PointerConfig.swift. Basically we made it pass through two keyPoints `p0` and `p1` and had it curve down so the slope (aka derivative) reached 0 at the second keypoint. So we bascally had a cap and made it smoothly curve into the cap.
/// The problem is that there is only one fixed curvature that satisfies this and it's not very high. Now we want to try higher curvatures.
///     (We could've almost made it more curved using the Driver Curve, using 4th coefficient `d`, but it's not possible, because `d^4` can't become negative, so it can't make the curve slop down, only up. See IOQuarticFunction / IOHIDScrollFilter or whatever they were called for context)
//
/// So now we want to create polynomial functions of arbitrary degrees that smoothly curve into the cap. So we can increase the curvature by increasing the degree.
///
/// Method:
/// See: https://www.desmos.com/calculator/sdvkwmqnmk
/// We want all (non-constant) derivatives to be equal 0 at the cap point `p1`. Not totally sure why but that seems to generate the desired curve shape.
/// To achieve this we simply use a polynomial regression feed it `p0` `p1` and some extra points.
///     - The first extra points is `p3 = (p1.x + ε, p1.y)` This will force the first derivative to be 0 somewhere between `p1.x` and `p1.x + ε`. If we make ε small enough it's as good as having the derivative be 0 at exactly `p.x`.
///     - The second extra point is `p4 = (p1.x + 2ε, p1.y)`. This will force the second derivative to be 0 somewhere between `p1.x` and `p1.x + 2ε`
///     - The third extra point is `p5 = (p1.x + 3ε, p1.y)` and so on.
/// For a polynomial of degree n, we need n-1 extra points to ensure that all derivatives go through 0 at (circa) `p1.x`

/// Notes on failing regression with curvature >= 4
///     Using
/// `iOS-Polynomial-Regression` the results become wrong at a degree 4. But it works for degree 1, 2 and 3 which is probably all we need.
///  I also tried the code from this SO answer https://stackoverflow.com/a/45735875/10601702, under "Example conventional code for generic degree equation:" but it also doesn't work for degree 4.
///  I also found this CPP implementation from NASA https://github.com/nasa/polyfit  - it ALSO didn't work. Actually fails worse than the other methods, doesn't even work properly with degree 3.
///  The only method I found that works is regression inside of Desmos or numpy.polyfit(). I tried using numpy from Swift. there is a lib called NumPy-iOS which does exactly what we want but it doesn't support macOS. So I gave up on making degree >= 4 work.
///  -> However we tested degree 4 by calculating the coefficients using numpy and inserting them manually and it doesn't feel that great. Still good but it gets a little floaty / hard to predict at that point.
///
/// Note: For degree 1 or 2 you could just use the Apple Driver's built in Parametric curve function. So you don't really need this class.
///
///  TODO: Clean up all the different regression functions that don't work.

import Foundation

@objc class PolynomialCappedAccelerationCurve: AccelerationCurve {
    
    /// Constants
    let epsilon: Double = 10e-3
    
    /// Params
    let p0: P
    let p1: P
    let n: Int
    
    /// Coefficients
    let coeffs: [Double]
    
    /// Init
    required init(lowSpeed v0: Double, lowSens s0: Double, highSpeed v1: Double, highSens s1: Double, curvature n: Int) {
        
        /// See top of this file for explanation of parameters
        
        /// Store params
        self.p0 = P(v0, s0)
        self.p1 = P(v1, s1)
        self.n = n
        
        /// Generate additional key points
        var q: [P] = []
        for i in 1..<n {
            q.append(P(p1.x + Double(i)*epsilon, p1.y))
        }
        
        /// Prep points for polynomial regression
        var allPoints = [p0, p1]
        allPoints.append(contentsOf: q)
        
        var xValues = [NSNumber]()
        var yValues = [NSNumber]()
        
        for p in allPoints {
            xValues.append(NSNumber(value: p.x))
            yValues.append(NSNumber(value: p.y))
        }
        
        /// Use polynomial regression
        let coeffsNS = PolynomialRegression.regression(withXValues: xValues, yValues: yValues, polynomialDegree: UInt(n))

        /// Alternative methods for poly regression (None of them work better)
//        let coeffsNS: [NSNumber] = PolyFit.fitWith(x: xValues, y: yValues, polynomialDegree: Int32(n))
//        self.coeffs = fit(points: allPoints, polynomialDegree: n)
        
        /// Store coefficients
        self.coeffs = coeffsNS.map { nsNumber in nsNumber.doubleValue }
        
        /// Testing
//        self.coeffs = [0.0334005, 10.2645, -2.19908, 0.209393, -0.00747675]
    }
    
    /// Evaluate
    override func evaluate(at x: Double) -> Double {
        
        let xClipped = SharedUtilitySwift.clip(x, betweenLow: p0.x, high: p1.x)
        
        var y = 0.0
        var exponent = 0.0
        for c in coeffs {
            y += c*pow(xClipped, exponent)
            exponent += 1.0
        }
        
        return y
    }
    
    /// Trace
    func traceSpeed(nOfSamples: Int, allowSparseSampling: Bool = false) -> [[Double]] {
        /// Params
        let bias = 2.0
        let oversample = 2.0
        /// Build trace
        var trace: [[Double]] = []
        var coreTrace: [[Double]]
        if n == 1 && allowSparseSampling {
            /// n == 1 -> Straight line. We only need 2 points to describe it, not nOfSamples. But for some reason the acceleration becomes way too fast with very few points. (ca. 10 or fewer), so we sample 100 times. Doing this for optimization but doesn't make any tangible difference. The number of points in the acceleration table is not visible in the Activity Monitor CPU usage of `com.apple.AppleUserHIDDrivers` at all.
            coreTrace = super.traceSpeed(startX: p0.x, endX: p1.x, nOfSamples: 100, bias: 1.0)
        } else {
            coreTrace = super.traceSpeed(startX: p0.x, endX: p1.x, nOfSamples: nOfSamples, bias: bias)
        }
        trace.append(contentsOf: coreTrace)
        trace.append([p1.x*oversample, p1.y*(p1.x*oversample)])
        /// Return
        return trace
    }
}
