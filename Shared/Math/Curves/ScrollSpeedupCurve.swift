//
// --------------------------------------------------------------------------
// ScrollSpeedupCurve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// See: https://www.desmos.com/calculator/cdd0jlgnqt for an explanation

import Foundation

@objc class ScrollSpeedupCurve: Curve {
    
    let a: Double
    let b: Double
    let c: Double
    let t: Double
    let p: Double
    
    init(swipeThreshold t: Int, initialSpeedup p: Double, exponentialSpeedup c: Double) {
        
        assert(t > 0 && p >= 1.0)
        
        self.b = 1.1
        self.a = (p - 1.0) / (pow(b, c) - 1)
        self.c = c
        
        self.t = Double(t)
        self.p = p
        
        super.init()
    }
    
    override func evaluate(at x: Double) -> Double {
        if x < t {
            return 1.0
        } else {
            return a * pow(b, (x-t) * c) + 1 - a
        }
    }
}
