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
    
    var slope: Double { a }
    
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
