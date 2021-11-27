//
// --------------------------------------------------------------------------
// Math.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

@objc class Math: NSObject {
    
    @objc class func choose(_ nArg: Int, _ k: Int) -> Int {
        /// Aka binomial coefficient
        /// Source https://blog.plover.com/math/choose.html
        
        var n: Int = nArg // Copying because we want to mutate it
        var r: Int = 1
        
        assert(n >= 0)
        assert(k >= 0)
        
        if      k < 0 { return 0 }
        else if n < k { return 0 }
        
        if      k == 0 { return 1 }
        else if k == n { return 1 }
        
        for d in 1...k {
            r *= n
            r /= d
            n -= 1
        }
        
        return r;
    }
    
    @objc class func factorial(_ n: Int) -> Int {
        
        assert(n >= 0)
        
        switch n {
        case 0:
            return 1
        default:
            return n * factorial(n-1)
        }
    }
    
    @objc class func scale(value: Double, from originInterval: Interval, to targetInterval: Interval) -> Double {
        /// Should probably move this into Interval
        /// Works as expected on Intervals with different directions
        
        assert(originInterval.contains(value))
        
        // Normalize value between 0 and 1
    
        let unitValue: Double = abs(value - originInterval.start) / originInterval.length
        
        // Scale unitValue to targetRange
        
        return targetInterval.start + (unitValue * targetInterval.directedLength)
    }
}

@objc class Interval: NSObject {
    /// - Defines an Interval of real values
    /// - Defines only closed Intervals. We don't need open or half-open intervals
    /// - Also stores a direction, which Maths Intervals don't usually do, but it's real useful for us. If the caller want to ignore this they can use `lower` and `upper` instead of `start` and `end`
    /// - This is used a lot for BezierCurve and Animator, which means tons of these are instantiated every second while scrolling -> Might be worth looking into optimizing
    
    @objc override var description: String { "(\(start), \(end))" }
    
    @objc let start: Double
    @objc let end: Double
    
    @objc var direction: MFIntervalDirection {
        if start == end {
            return kMFIntervalDirectionNone
        } else if start < end {
            return kMFIntervalDirectionAscending
        } else {
            return kMFIntervalDirectionDescending
        }
    }
    
    @objc var location: Double { lower }
    @objc var length: Double { upper - lower }
    @objc var directedLength: Double { end - start }
    
    @objc var lower: Double { direction == kMFIntervalDirectionAscending ? start : end }
    @objc var upper: Double { direction == kMFIntervalDirectionAscending ? end : start }
    
    @objc static var unitInterval = Interval.init(start: 0, end: 1)
        /// Scale to this interval to normalize a value
        /// I use this a lot in performance-critical code. It might be good to only create the unitInterval only once instead of this. But maybe swift already optimizes that automatically.
    
    @objc required init(start: Double, end: Double) {
        
        self.start = start
        self.end = end
    }
    
    @objc convenience init(location: Double, length: Double) {
        self.init(lower: location, upper: location + length)
    }
    
    @objc convenience init(lower: Double, upper: Double) {
        assert(lower < upper)
        self.init(start: lower, end: upper)
    }
    
    @objc func contains(_ value: Double) -> Bool {
        return lower <= value && value <= upper
    }
    
    
}

@objc class Line: NSObject, AnimationCurve {
    
    let a: Double
    let b: Double
    
    var slope: Double { a }
    
    // Function looks like ax + b
    @objc init(a: Double, b: Double) {
        self.a = a
        self.b = b
    }
    
    @objc func evaluate(at x: Double) -> Double {
        return a * x + b
    }
}

// MARK: Exponent operator
/// I actually think `pow()` is more readable than this, so I probably won't use this

precedencegroup ExponentialPrecedence {
    higherThan: MultiplicationPrecedence
    associativity: right
}

infix operator ** : ExponentialPrecedence

func ** (lhs: Double, rhs: Double) -> Double {
    return pow(lhs, rhs)
}

infix operator **= : AssignmentPrecedence
func **= (lhs: inout Double, rhs: Double) {
    lhs = lhs ** rhs
}

// MARK: Factorial operator
/// You can't use ! as a postfix operator, so I went with this as a shorthand

func fac(_ n: Int) -> Int {
    return Math.factorial(n)
}
