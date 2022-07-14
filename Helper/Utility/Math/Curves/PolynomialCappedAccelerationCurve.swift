//
// --------------------------------------------------------------------------
// PolynomialCapAccelerationCurve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// After playing around with NaturalAccelerationCurve I found it too floaty.
/// The cubic polynomial curve `f(x) = (ax + (bx)^2 + (cx)^3 + (dx)^4) / x` that the Apple Driver generates when using parametric acceleration feels better / more predictable to me.
/// You can see how we configured the parameters for that curve in PointerConfig.swift. Basically we made it pass through two keyPoints `p0` and `p1` and had it curve down so the slope (aka derivative) reached 0 at the second keypoint. So we bascally had a cap and made it smoothly curve into the cap.
/// The problem is that there is only one fixed curvature that satisfies this and it's not very high. Now we want to try higher curvatures.
///     (We could've almost made it more curved using the Driver Curve, using `d`, but it's not possible, because `d^4` can't become negative, so it can't make the curve slop down, only up.)
//
/// So now we want to create polynomial functions of arbitrary degrees that smoothly curve into the cap. So we can increase the curvature by increasing the degree.
///
/// Method:
/// See: https://www.desmos.com/calculator/sdvkwmqnmk
/// We want all (non-constant) derivatives to be equal 0 at the cap point `p1`. Not totally sure why but that seems to generate the desired curve shape.
/// To achieve this we simply use a polynomial regression feed it `p0` `p1` and some extra points.
///     - The first extra points is `p3 = (p1.x + ε, p1.y)` This will force the first derivative to be 0 somewhere between `p1.x` and `p1.x + ε`. If we make ε small enough it's as good as having the derivative be 0 at exactly `p.x`.
///     - The second extra point is `p4 = (p1.x + 2ε, p1.y)`. This will force the second derivative to be 0 somewhere between `p1.x` and `p1.x + ε`
///     - The third extra point is `p5 = (p1.x + 3ε, p1.y)` and so on.
/// For a polynomial of degree n, we need n-1 extra points to ensure that all derivatives go through 0 at `p1.x`

/// Notes on failing regression
///     Using
/// `iOS-Polynomial-Regression` the results become wrong at a degree 4. But it works for degree 1, 2 and 3 which is probably all we need.
///  I also tried the code from this SO answer https://stackoverflow.com/a/45735875/10601702, under "Example conventional code for generic degree equation:" but it also doesn't work for degree 4.
///  I also found this CPP implementation from NASA https://github.com/nasa/polyfit  - it ALSO didn't work. Actually fails worse than the other methods
///  The only method I found that works is regression inside of Desmos or numpy.polyfit()

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
        
        /// Store params
        self.p0 = P(x: v0, y: s0)
        self.p1 = P(x: v1, y: s1)
        self.n = n
        
        /// Generate additional key points
        var q: [P] = []
        for i in 1..<n {
            q.append(P(x: p1.x + Double(i)*epsilon, y: p1.y))
        }
        
        /// Prep points for polynomial regression
        
        var xValues = [NSNumber]()
        var yValues = [NSNumber]()
        
        xValues.append(contentsOf: [NSNumber(value: p0.x), NSNumber(value: p1.x)])
        yValues.append(contentsOf: [NSNumber(value: p0.y), NSNumber(value: p1.y)])
        for p in q {
            xValues.append(NSNumber(value: p.x))
            yValues.append(NSNumber(value: p.y))
        }
        
        /// Use polynomial regression
//        let coeffsNS: NSMutableArray = PolynomialRegression.regression(withXValues: xValues, yValues: yValues, polynomialDegree: UInt(n))

        let coeffsNS: [NSNumber] = PolyFit.fitWith(x: xValues, y: yValues, polynomialDegree: Int32(n))
        /// Store coefficients
        self.coeffs = coeffsNS.map { nsNumber in nsNumber.doubleValue }
        
        /// Test
//        self.coeffs = [0.0334005, 10.2645, -2.19908, 0.209393, -0.00747675]
    }
    
    /// Evaluate
    override func evaluate(at x: Double) -> Double {
        
        let xClipped = SharedUtilitySwift.clip(x, betweenLow: p0.x, high: p1.x)
        
        var y = 0.0
        var exponent = 0.0
        for c in coeffs {
            y += c * pow(xClipped, exponent)
            exponent += 1.0
        }
        
        return y
    }
}
