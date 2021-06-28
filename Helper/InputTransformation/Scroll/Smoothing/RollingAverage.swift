//
// --------------------------------------------------------------------------
// RollingAverage.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

class RollingAverage: NSObject, Smoother {
    
    /// Static vars
    
    let circularBuffer: CircularBuffer<NSNumber>
    var filled: Int {
        circularBuffer.filled()
    }
    
    /// Init
    
    @objc init(capacity: Int) {
        
        assert(capacity > 1, "`capacity` must be greater than 1. Otherwise there won't be any smoothing.")
        
        self.circularBuffer = CircularBuffer.init(capacity: capacity);
    }
    
    /// Main
    
    @objc func reset() {
        self.circularBuffer.reset()
    }
    
    @objc func smooth(value: Double) -> Double {
        
        assert(circularBuffer.filled() > 0)
        circularBuffer.add(NSNumber.init(value: value))
        
        let storedValues: [NSNumber] = circularBuffer.content()
        let storedValuesAverage: Double = storedValues.reduce(0) { $0 + $1.doubleValue } / Double(storedValues.count)
        
        return storedValuesAverage
        
    }
    
    
}
