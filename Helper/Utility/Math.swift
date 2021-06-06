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

//    /// Source https://blog.plover.com/math/choose.html
//    @objc class func choose(_ nArg: Int, _ k: Int) -> Int {
//        var n: Int = nArg
//        var r: Int = 1
//        
//        if k > n { return 0 }
//        
//        for d in 1...k {
//            r *= n
//            r /= d
//            n -= 1
//        }
//        return r;
//    }
    
    @objc class func choose(_ nArg: Int, _ k: Int) -> Int {
        /// Aka binomial coefficient
        /// Source https://blog.plover.com/math/choose.html
        
        var n: Int = nArg // Copying because we want to mutate it
        var r: Int = 1
        
        assert(n >= 0)
        assert(k >= 0)
        
        if k < 0 { return 0 }
        if n < k { return 0 }
        
        if k == 0 { return 1 }
        if k == n { return 1 }
        
        for d in 1...k {
            r *= n
            r /= d
            n -= 1
        }
        
//        print("n:\(nArg) choose k:\(k) = \(r)")
        
        return r;
    }
    
    @objc class func factorial(_ n: Int) -> Int {
        
        assert(n > 0)
        
        switch n {
        case 0:
            return 1
        default:
            return n * factorial(n-1)
        }
    }
    
    @objc class func scale(value: Double, fromRange sourceRange: ContinuousRange, toRange targetRange: ContinuousRange) -> Double {
        
        assert(sourceRange.contains(value))
        
        // Normalize value (between 0 and 1)
    
        let normalizedValue: Double = (value - sourceRange.lower) / sourceRange.length
        
        // Scale normalized value to targetRange
        
        return normalizedValue * targetRange.length + targetRange.lower
    }
}

@objc class ContinuousRange: NSObject {
    
    let location: Double
    let length: Double
    
    @objc var lower: Double {
        location
    }
    @objc var upper: Double {
        location + length
    }
    
    @objc class func normalRange() -> ContinuousRange {
        return self.init(lower: 0.0, upper: 1.0)
    }
    
    @objc required init(lower: Double, upper: Double) {
        self.location = lower
        self.length = upper - lower
    }
    
    @objc init(location: Double, length: Double) {
        self.location = location
        self.length = length
    }
    
    func contains(_ value: Double) -> Bool {
        return location <= value && value <= upper
    }
}

@objc class Line: NSObject {
    
    let a: Double
    let b: Double
    
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
    lhs = lhs ^ rhs
}

// MARK: Factorial operator
/// You can't use !, so I went with this, Because factorial sort of a mix of repeated multiplication (aka exponentiation) and subtraction

postfix operator **-
postfix func **- (rhs: Int) -> Int {
    return Math.factorial(rhs)
}
