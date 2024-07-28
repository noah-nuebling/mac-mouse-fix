//
// --------------------------------------------------------------------------
// ExtrapolatedBezierCurve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa


/// With this class you can create a BezierCurve which is then linearly extrapolated after the last control point, and set to the minimum value before the first controlPoint
/// https://en.wikipedia.org/wiki/Extrapolation#Linear
/// We use this to define acceleration curves
class AccelerationBezier: Bezier {

    var preLine: Line
    var postLine: Line
    
    override init(controlPoints: [P], defaultEpsilon: Double = 0.08) {
        
        /// Init lines so we can call super.init. This is the only reason the lines are var and not let. Swift is weird.
        /// See here for an explanation of this problem: https://stackoverflow.com/questions/24021093/error-in-swift-class-property-not-initialized-at-super-init-call
        /// See https://docs.swift.org/swift-book/LanguageGuide/Initialization.html -> Two-phase initialization for an explanation why this is necessary
        
        self.preLine = Line.init(a: 0, b: 0)
        self.postLine = preLine
        
        /// Init super
        
        super.init(controlPoints: controlPoints, defaultEpsilon: defaultEpsilon)
        
        /// Define lines
        
        /**
         Define preLine, such that it
         - Passes through the first control point
         - Has slope 0 and the same value that the bezier curve does in its first control point
         Define postLine such that it
         - Passes through the last control point
         - Has the same slope that the bezier curve does in its last control point
         
         - The slope between the first 2 control points is equal to the slope of the BezierCurve in the first point. (src Wikipedia)
         - The slope between the  last 2 control points is equal to the slope of the BezierCurve in the last point.
         - Once the slope `a` is determined, we then find `b` such that the curve passes through some point c with this simple formula:
            y = ax + b -> b = y - ax -> b = c.y - a * c.x
         
         */
        
        /// preLine
        
        /// Get the relevant control points
        let c1 = controlPoints[0]
        
        /// Find slope.
        let aPre = 0.0
        
        /// Find b such that the preLine passes through the first control point
        let bPre = c1.y
        
        /// Found preLine!
        self.preLine = Line.init(a: aPre, b: bPre)
        
        /// postLine
        
        /// Find slope
        let aPost = self.exitSlope
        
        /// Find b
        let cLast = controlPoints[self.n]
        let bPost = cLast.y - aPost * cLast.x
        
        /// Found postLine!
        self.postLine = Line.init(a: aPost, b: bPost)
        
    }
    
    override func evaluate(at x: Double, epsilon: Double) -> Double {
        
        let result: Double
        
        if self.xValueRange.contains(x) {
            result = super.evaluate(at: x, epsilon: epsilon)
        } else if x < self.xValueRange.lower {
            result = self.preLine.evaluate(at: x)
        } else {
            result = self.postLine.evaluate(at: x)
        }
        
        /// Debug
        
//        if result < 0 {
        if ((false)) {
            
            /// Result is sometimes negative for some reason. It should never be negative.
                
            let rangeStr: String
            if self.xValueRange.contains(x) {
                rangeStr = "within"
            } else if x < self.xValueRange.lower {
                rangeStr = "below"
            } else {
                rangeStr = "above"
            }
            
            DDLogDebug("Acc curve negative. Input: \(x), result: \(result), range: \(rangeStr)\n")
//            DDLogDebug("Curve traceee:\n\(super.trace(nOfSamples: 100))")
            /// ^ This causes dozens of different, extremely weird crashes when setting nOfSamples to large values like 100 or 1000. No idea what's going on.
            
//            super.evaluate(at: x, epsilon: epsilon) /// For debug stepping
            
        }
        
        return result
    }
    
}
