//
// --------------------------------------------------------------------------
// BezierCappedAccelerationCurve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

/// This class generates a curve that looks like the `PolynomialCappedAccelerationCurve`, the difference being that we can arbitrarily increase the curvature because we're not limited by inaccurate PolynomialRegression methods.
///
/// __Notes we made when we came up with this__
/// Coordinates for Bezier that matches **quartic** PolynomialCappedAccelerationCurve()
///     (0.0, 5.0) (1.75, 20.0) (3.5, 20.0) (7.0, 20.0)
///     -> 1.75 and 3.5 are **quarters** of the way between 0.0 and 7.0
/// Coordinates for Bezier that matches **cubic** PolynomialCappedAccelerationCurve()
///     (0.0, 5.0) (2.5, 20.0) (4.5, 20.0) (7.0, 20.0)
///     -> 2.5 and 4.5 are **thirds** of the way between 0.0 and 7.0
///     -> If you set a point at each third, it matches even better: `(0.0, 5.0) (7/3 * 1, 20.0) (7/3 * 2, 20.0) (7/3 * 3, 20.0)
/// Coordinates for Bezier that matches **quadratic** PolynomialCappedAccelerationCurve()
///     (0.0, 5.0) (3.5, 20.0) (7.0, 20.0)
///     -> Matches absolutely PERFECTLY in Desmos
///     -> I think the reason why the others don't match absolutely absolutely perfectly might be because the polynomial regression in Desmos isn't 100% accurate (already better than anything I could find in any Swift/ObjC/Cpp library, but it just seems to be impossible for polynomial regression to be highly accurate at higher degrees)
///
/// -> Result:
///   - To match a PolynomialCappedAccelerationCurve() with degree (aka `curvature`) of `n`, place `n+1` Bezier points with
///     `{ (x, y) | i in 0...n, x = (maxX-minX)*(n/i), y = minY if i == 0 else maxY }`
///   - If you only use the first 3 and the last points, you will get a cubicBezier, which is 1. Overall very similar, 2. Has smoother curvature, since it's not as straight at the end 3. Should be more efficient to calculate (Don't know if that matters)
///
/// Edit:
/// __We found a nice way to represent non-integer curvatures by shifting the points around__
/// - For integer curvature n, there are n+1 points equidistant on the x-axis, for non integer curvature n+d, there are n+2 points, all of them equdistant except the last two which are closer together.
/// - I can't really describe how this works, but based on the mental image I have in my head of how this changes as you increase the curvature, I think this is extremely close or even equivalent to interpolating between two integer-curved curves (like in the old implementation `BezierCappedAccelerationCurve_old_interpolating` or in `PolynomialCappedAccelerationCurves`)
///
/// __Other thoughts__
/// - (Not sure if we already wrote about this somewhere else. Maybe somewhere in PointerConfig or so?) Maybe the reason why downward sloping acceleration curves feel so good is that when you move slowly it's far easier to adjust the speed slightly than when you're moving fast. When you're moving fast, slight variations in speed will not be consciously noticable to you. When you make the curve slope downward you in some sense `normalize` the curve relative to the users ability to consciously adjust the speed.
///     ... Not totally sure this makes sense. But either way downward sloping curves feel better and help accuracy for me.
///
///
/// __Resources__
/// - Desmos Project for PolynomialCapped curves: https://www.desmos.com/calculator/sdvkwmqnmk?lang=de
/// - Desmos Project for n-point Bezier curves: https://www.desmos.com/calculator/4cqrr3f05o?lang=de

import Foundation

class BezierCappedAccelerationCurve: AccelerationBezier {
    
    /// This class just adds an initializer for AccelerationBezier. Maybe it shouldn't be it's own class at all.
    ///     We made it its own class because that was necessary for the old implementation which you can find below.
    
    @objc init(xMin: Double, yMin: Double, xMax: Double, yMax: Double, curvature: Double, reduceToCubic: Bool = false, defaultEpsilon: Double = 0.08) {
        
        /// NOTES:
        /// Not sure the 0.08 default epsilon makes sense here
        
        assert(curvature >= 1)

        var points: [P] = []
        
        var i = 0
        while true {
            
            let isLast = Double(i) >= curvature
            
            if reduceToCubic {
                let isFirstThree = i <= 2
                if !isFirstThree && !isLast {
                    continue
                }
            }
            
            var x = Math.scale(value: Double(i)/curvature, from: .unitInterval, to: Interval(xMin, xMax), allowOutOfBounds: true)
            if x > xMax {
                assert(isLast)
                x = xMax
            }
            let y = i == 0 ? yMin : yMax
            
            points.append(_P(x, y))
            
            if isLast { break }
            
            i += 1
        }
        
        super.init(controlPoints: points, defaultEpsilon: defaultEpsilon)
    }
}



private class BezierCappedAccelerationCurve_old_interpolating: Curve {
  
    /// NOTES;
    /// - This is unused, has been replaced
    /// - See notes at the top for more.
    
    /// Storage
    let curve1: AccelerationBezier
    let curve2: AccelerationBezier?
    let ratio: Double /// Interpolation factor for how much of curve2 to use
    
    @objc init(xMin: Double, yMin: Double, xMax: Double, yMax: Double, curvature: Double, reduceToCubic: Bool = false, defaultEpsilon: Double = 0.08) {
        
        /// NOTE: Not sure the 0.08 default epsilon makes sense here
        
        assert(curvature >= 1)
        
        if curvature == 0.0 {
            /// Could reduce to a line in this case for optimization
        }
        
        if reduceToCubic {
            
            let x1 = Math.scale(value: 1/curvature, from: .unitInterval, to: Interval(xMin, xMax))
            var x2 = Math.scale(value: 2/curvature, from: .unitInterval, to: Interval(xMin, xMax))
            if x2 > xMax{ x2 = xMax }
            curve1 = AccelerationBezier(controlPoints: [_P(xMin, yMin), _P(x1, yMax), _P(x2, yMax), _P(xMax, yMax)])
            curve2 = nil
            ratio = 0.0
            
        } else {
            
            let lowerCurvature = Int(floor(curvature))
            let upperCurvature = Int(ceil(curvature))
            ratio = curvature - Double(lowerCurvature)
            
            var lowerPoints: [P] = []
            var upperPoints: [P]?
            
            for i in 0...lowerCurvature {
                let x = Math.scale(value: Double(i), from: Interval(0, Double(lowerCurvature)), to: Interval(xMin, xMax))
                let y = i == 0 ? yMin : yMax
                lowerPoints.append(P(x: x, y: y))
            }
            if lowerCurvature != upperCurvature {
                upperPoints = []
                for i in 0...upperCurvature {
                    let x = Math.scale(value: Double(i), from: Interval(0, Double(upperCurvature)), to: Interval(xMin, xMax))
                    let y = i == 0 ? yMin : yMax
                    upperPoints!.append(P(x: x, y: y))
                }
            }
            
            curve1 = AccelerationBezier(controlPoints: lowerPoints, defaultEpsilon: defaultEpsilon)
            
            if let upperPoints = upperPoints {
                curve2 = AccelerationBezier(controlPoints: upperPoints, defaultEpsilon: defaultEpsilon)
            } else {
                curve2 = nil
            }
        }
    }
    
    
    @objc override func evaluate(at x: Double) -> Double {
        
        var result = curve1.evaluate(at: x)
        if let curve2 = curve2 {
            let result2 = curve2.evaluate(at: x)
            result = Math.scale(value: ratio, from: .unitInterval, to: Interval(result, result2))
        }
        
        return result
    }
}
