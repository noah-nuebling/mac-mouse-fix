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
    
    let buffer: CircularBufferObjc<NSNumber>
    var filled: Int {
        buffer.filled()
    }
    
    /// Init
    
    init(n: Int) {
        
        assert(n >= 2, "n must be greate or equal 2. Otherwise there won't be any smoothing.")
        
        self.buffer = CircularBufferObjc.init(capacity: n);
    }
    
    /// Main
    
    func reset() {
        self.buffer.reset()
    }
    
    func smooth(value: Double) -> Double {
        
        assert(buffer.filled() > 0)
        buffer.add(NSNumber.init(value: value))
        
        let storedValues: [NSNumber] = buffer.content()
        let storedValuesAverage: Double = storedValues.reduce(0) { $0 + $1.doubleValue } / Double(storedValues.count)
        
        return storedValuesAverage
        
    }
    
    
}
