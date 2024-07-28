//
// --------------------------------------------------------------------------
// Math.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa

@objc class Math: NSObject {
    
    @objc class func intCycle(x: Int, lower: Int, upper: Int) -> Int {
        return Int(cycle(x: Double(x), lower: Double(lower), upper: Double(upper)))
    }
    
    @objc class func cycle(x: Double, lower: Double, upper: Double) -> Double {
        /// Generalization of modulo.
        ///     `cycle(x: a, lower: 0, upper: n) = mod(a, n+1)`
        
        /// Validate
        assert(lower <= upper)
        
        /// Calculate
        
        if lower == upper { return lower }
        
        var x = x
        let stride = upper - lower
        
        while upper < x {
            x -= stride
        }
        while x < lower {
            x += stride
        }
        return x
    }
    
    @objc class func bisect(searchRange: Interval, targetOutput: Double, epsilon: Double, function: (Double) -> Double) -> NSNumber? {
        /// This only works if 'function' is monotonically increasing (I think)
        /// (Returning NSNumber so we can make it nullable. the value is double)
        
        /// Validate
        
        assert(searchRange.upper - searchRange.lower > 0)
        assert(epsilon > 0)
        
        /// Algorithm
        
        let validationFrequency = 10 /// Validate after every 10 iterations
        var iterationCounter = 0
        
        var t = Math.scale(value: 0.5, from: .unitInterval, to: searchRange)
        var searchRange = searchRange
        
        while searchRange.lower != searchRange.upper { /// I don't think this condition can be false. Copied from WebKit CubicBezier code.
            
            let sampledOutput = function(t)
            
            if fabs(targetOutput - sampledOutput) < epsilon {
                return t as NSNumber
            }
            
            if sampledOutput < targetOutput {
                searchRange = Interval(t, searchRange.upper)
            } else {
                searchRange = Interval(searchRange.lower, t)
            }
            
            /// Validate
            iterationCounter += 1
            if iterationCounter % validationFrequency == 0 {
                
                let lowerOutput: Double
                let upperOutput: Double
                
                if sampledOutput < targetOutput {
                    lowerOutput = sampledOutput
                    upperOutput = function(searchRange.upper)
                } else {
                    lowerOutput = function(searchRange.lower)
                    upperOutput = sampledOutput
                }
                
                let targetTooSmall = targetOutput < lowerOutput
                let targetTooLarge = upperOutput < targetOutput
                let outputIsFindable = !targetTooSmall && !targetTooLarge
                if (!outputIsFindable) {
                    let closestFoundInput = (targetTooSmall ? searchRange.lower : searchRange.upper)
                    let closestFoundOutput = (targetTooSmall ? lowerOutput : upperOutput)
                    assert(false)
                    DDLogError("Bisection failed. This likely means that the function you're trying to bisect is not monotonically increasing. targetOutput: \(targetOutput), found output: \(closestFoundOutput)")
                    return closestFoundInput as NSNumber
                }
            }
            
            t = Math.scale(value: 0.5, from: .unitInterval, to: searchRange)
        }
        
        return nil /// I don't think this can happen
    }
    
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
    
    @objc class func scale(value: Double, from originInterval: Interval, to targetInterval: Interval, allowOutOfBounds: Bool = false) -> Double {
        
        /// Notes:
        /// - Should probably move this into Interval
        /// - Works as expected on Intervals with different directions
        /// - We fixed bugs with intervals in different directions (which never seemed to play a role before) in commit daa3c4da21aac240e367ef73949d1f307d422f36. TODO: Check if this caused any performance regressions when scrolling or dragging.
        
        
        /// Validate out of bounds
        if !allowOutOfBounds {
            assert(originInterval.contains(value))
        }
        
        /// Check weird numbers
        ///  Note: From my testing, if we plug in `.greatestFiniteMagnitude` aka `DBL_MAX`, then the calculations will produce NaN, which is bad.
        assert(!value.isNaN 
               && !value.isInfinite 
               && value.magnitude != .greatestFiniteMagnitude)
        
        /// Check invalid interval
        ///  Note: The length of the targetInterval may be 0
        assert(originInterval.length > 0)
        
        /// Scale value from originInterval to unitInterval [0, 1]
        var unitValue: Double = (value - originInterval.lower) / originInterval.length
        
        /// Flip
        /// Notes:
        /// - Mirror unitValue at 0.5 on the number line
        if directionsAreOpposite(originInterval.direction, targetInterval.direction) {
            unitValue = unitValue - 2*(unitValue - 0.5)
        }
        
        /// Scale unitValue to targetInterval
        let result = targetInterval.lower + (unitValue * targetInterval.length)
        
        /// Validate
        /// Notes:
        /// - We're doing similar validation inside Interval
        /// - It's not too bad if this is -inf or +inf I think
        assert(!result.isNaN)
        
        /// Return
        return result
    }
    
    @objc class func nthroot(value: Double, _ n: Double) -> Double {
        /// Src: https://stackoverflow.com/a/37028926/10601702
        
        var res: Double
        if (value < 0 && abs(n.truncatingRemainder(dividingBy: 2)) == 1) {
            res = -pow(-value, 1/n)
        } else {
            res = pow(value, 1/n)
        }
        return res
    }
}

@objc class Interval: NSObject, NSCopying {
    /// - Defines an Interval of real values
    /// - Defines only closed Intervals. We don't need open or half-open intervals
    /// - Also stores a direction, which Maths Intervals don't usually do, but it's real useful for us. If the caller want to ignore this they can use `lower` and `upper` instead of `start` and `end`
    /// - This is used a lot for BezierCurve and Animator, which means tons of these are instantiated every second while scrolling -> Might be worth looking into optimizing
    ///     - Edit: We made everything lazy for optimization. Don't know if it makes any difference.
    ///     - Edit 2: creating instances of this takes up a lot of CPU. I tried moving to a pure swift class that doesn't inherit from NSObject but somehow it became even slower. See message for commit 4b48286745730435dc2384ecdc8c43547aaec2e5.
    
    @objc override var description: String { "(\(start), \(end))" }
    
    @objc let start: Double
    @objc let end: Double
    
    @objc lazy var direction: MFIntervalDirection = {
        if start == end {
            return kMFIntervalDirectionNone
        } else if start < end {
            return kMFIntervalDirectionAscending
        } else {
            return kMFIntervalDirectionDescending
        }
    }()
    
    @objc lazy var location: Double = { lower }()
    @objc lazy var length: Double = { upper - lower }()
    @objc lazy var directedLength: Double = { end - start }()
    
    @objc lazy var lower: Double = { direction == kMFIntervalDirectionAscending ? start : end }()
    @objc lazy var upper: Double = { direction == kMFIntervalDirectionAscending ? end : start }()
    
    @objc static let reversedUnitInterval = Interval.init(start: 1, end: 0)
    @objc static let unitInterval = Interval.init(start: 0, end: 1)
    /// ^ Scale to this interval to normalize a value
    
    @objc required init(start: Double, end: Double) {
        
        assert(!start.isNaN && !end.isNaN && start.isFinite && end.isFinite)
        
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
    @objc convenience init(_ a: Double, _ b: Double) {
        self.init(start: a, end: b)
    }
    
    @objc func copy(with zone: NSZone? = nil) -> Any {
        return Interval(start: self.start, end: self.end)
    }
    
    @objc func contains(_ value: Double) -> Bool {
        return lower <= value && value <= upper
    }
}

// MARK: - Shorthands

// MARK: nthroot

func root(_ value: Double, _ n: Double) -> Double {
    return Math.nthroot(value: value, n)
}

// MARK: xor
/// This is just an alias for != so maybe we should remove this.

extension Bool {
    static func ^ (left: Bool, right: Bool) -> Bool {
        return left != right
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
