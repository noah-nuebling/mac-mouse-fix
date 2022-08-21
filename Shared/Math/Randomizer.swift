//
// --------------------------------------------------------------------------
// Randomizer.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

class Randomizer: NSObject {
    
    static func select<T>(from items: [(_: T, weight: Double)]) -> T {
        
        let weightSum = items.reduce(0) { partialResult, item in
            return partialResult + item.weight
        }
        
        let r = Double.random(in: Range<Double>(uncheckedBounds: (lower: 0, upper: weightSum)))
        
        var w = 0.0
        for i in items {
            w += i.weight
            if w >= r {
                return i.0
            }
        }
        
        assert(false)
    }
}
