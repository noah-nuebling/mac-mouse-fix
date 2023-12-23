//
// --------------------------------------------------------------------------
// RollingAverage.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa

class RollingAverage: NSObject, Smoother {
    
    /// Vars
    
    let circularBuffer: CircularBuffer<NSNumber>
    var filled: Int {
        circularBuffer.filled()
    }
    let initialValues: [Double]
    
    /// Init

    @objc convenience init(capacity: Int) {
        self.init(capacity: capacity, initialValues: []);
    }
    
    @objc init(capacity: Int, initialValues: [Double]) {
        
//        assert(capacity > 1, "`capacity` must be greater than 1. Otherwise there won't be any smoothing.")
        assert(initialValues.count <= capacity);
        
        self.circularBuffer = CircularBuffer.init(capacity: capacity);
        self.initialValues = initialValues
        
        super.init()
        
        self.applyInitialValues()
    }
    
    /// Main
    
    @objc func reset() {
        self.circularBuffer.reset()
        self.applyInitialValues()
    }
    
    @objc func smooth(value: Double) -> Double {
        
        circularBuffer.add(NSNumber(value: value))
        
        let storedValues: [NSNumber] = circularBuffer.content()
        var storedValuesAverage: Double = 0;
        for storedValue in storedValues { /// I used `reduce` for the avg but its extremely slow for some reason
            storedValuesAverage += storedValue.doubleValue;
        }
        storedValuesAverage /= Double(storedValues.count)
        
        return storedValuesAverage
        
    }
    
    /// Helpers
    
    fileprivate func applyInitialValues() {
        for v in self.initialValues {
            _ = self.smooth(value: v)
        }
    }
    
    
}
