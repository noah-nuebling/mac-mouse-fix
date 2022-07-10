//
// --------------------------------------------------------------------------
// Line.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation


@objc class Line: NSObject, AnimationCurve {
    
    let a: Double
    let b: Double
    
    typealias P = CGPoint
    
    var slope: Double { a }
    
    @objc convenience init(p: P, slope a: Double) {
        let b = p.y - a*p.x
        self.init(a: a, b: b)
    }
    
    @objc convenience init(connecting p1: P, _ p2: P) {
        let a = (p2.y - p1.y) / (p2.x - p1.x)
        let b = p1.y - a * p1.x
        self.init(a: a, b: b)
    }
    
    /// Function looks like ax + b
    @objc init(a: Double, b: Double) {
        self.a = a
        self.b = b
    }
    
    @objc func evaluate(at x: Double) -> Double {
        return a * x + b
    }
    
    @objc func evaluate(atY y: Double) -> Double {
        return (y - b) / a
    }
}

@objc class InvalidLine: Line {
    
    init() {
        super.init(a: 0, b: 0)
    }
    override var slope: Double { fatalError() }
    
    @objc override func evaluate(at x: Double) -> Double {
        fatalError()
    }
    
    @objc override func evaluate(atY y: Double) -> Double {
        fatalError()
    }
}
