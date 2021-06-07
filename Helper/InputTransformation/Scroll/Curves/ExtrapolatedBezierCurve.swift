//
// --------------------------------------------------------------------------
// ExtrapolatedBezierCurve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa


/// With this class you can create a BezierCurve which is then linearly extrapolated before the first and after the last control point
/// https://en.wikipedia.org/wiki/Extrapolation#Linear
/// I think this will be really useful for defining acceleration curves
class ExtrapolatedBezierCurve: BezierCurve {

    var preLine: Line
    var postLine: Line
    
    override init(controlPoints: [BezierCurve.Point], defaultEpsilon: Double) {
        
        // Init lines so we can call super.init. This is the only reason the lines are var and not let. Swift is weird.
        // See here for an explanation of this problem: https://stackoverflow.com/questions/24021093/error-in-swift-class-property-not-initialized-at-super-init-call
        // See https://docs.swift.org/swift-book/LanguageGuide/Initialization.html -> Two-phase initialization for an explanation why this is necessary
        
        self.preLine = Line.init(a: 0, b: 0)
        self.postLine = preLine
        
        // Init super
        
        super.init(controlPoints: controlPoints, defaultEpsilon: defaultEpsilon)
        
        // Define lines
        
        /**
         Define preLine, such that it
         - Passes through the first control point
         - Has the same slope that the bezier curve does in its first control point
         Define postLine such that it
         - Passes through the last control point
         - Has the same slope that the bezier curve does in its last control point
         
         - The slope between the first 2 control points is equal to the slope of the BezierCurve in the first point. (src Wikipedia)
         - The slope between the  last 2 control points is equal to the slope of the BezierCurve in the last point.
         - Once the slope `a` is determined, we then find `b` such that the curve passes through some point c with this simple formula:
            y = ax + b -> b = y - ax -> b = c.y - a * c.x
         
         */
        
        // preLine
        
        // Get the 2 relevant control points
        let c1 = controlPoints[0]
        let c2 = controlPoints[1]
        
        // Find slope.
        let aPre = (c2.y - c1.y) / (c2.x - c2.y)
        
        // Find b such that the preLine passes through the first control point
        let bPre = c1.y - aPre * c1.x
        
        // Found preLine!
        self.preLine = Line.init(a: aPre, b: bPre)
        
        // postLine
        
        // Get control points
        let cn = controlPoints[self.n]
        let cnPlus1 = controlPoints[self.n+1]
        
        // Find slope
        let aPost = (cnPlus1.y - cn.y) / (cnPlus1.x - cn.x)
        
        // Find b
        let bPost = cnPlus1.y - aPost * cnPlus1.x
        
        // Found postLine!
        self.postLine = Line.init(a: aPost, b: bPost)
        
    }
    
    override func evaluate(at x: Double, epsilon: Double) -> Double {
        
        if self.xValueRange.contains(x) {
            return super.evaluate(at: x, epsilon: epsilon)
        } else if x < self.xValueRange.lower {
            return self.preLine.evaluate(at: x)
        } else {
            return self.postLine.evaluate(at: x)
        }
    }
    
}
