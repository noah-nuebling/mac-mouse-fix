
//
//  CombinedLinearFunction.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 12/27/21.
//

import Foundation
import Cocoa

struct P {
    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
    let x: Double;
    let y: Double;
}

struct CombinedLinearFunction {

    let points: [P]
    
    let minX: Double
    let maxX: Double
    let minY: Double
    let maxY: Double
    
    init(yValues: [Double]) {
        /// Create points automatically just from yValues. x values will be equidistant between 0 and 1. This should be useful for defining NSSliders.
        
        /// Create points
        var points: [P] = [];
        
        for i in 0..<yValues.count {
            let x = Double(i) / Double(yValues.count-1)
            let y = yValues[i]
            points.append(P(x,y))
        }
        
        /// Init with points
        self.init(points: points)
    }
    
    init(points: [P]) {
        
        /// Validate
        assert(points.count >= 2)
        
        /// Collect extreme values
        /// Also assert that X values are ascending
        
        let _minX = points.first!.x
        var _maxX = -Double.infinity
        var _minY = Double.infinity
        var _maxY = -Double.infinity
        
        for p in points {
            assert(p.x > _maxX)
            _maxX = p.x
            if p.y < _minY { _minY = p.y }
            if p.y > _maxY { _maxY = p.y }
        }
        
        self.minX = _minX
        self.maxX = _maxX
        self.minY = _minY
        self.maxY = _maxY
        
        /// Store points
        self.points = points
    }
    
    func evaluate(atX x: Double) -> Double {
        
        /// Validate
        
        assert(minX <= x && x <= maxX)
        
        /// Do calculations
            
        /// Find two points that x lies between
        
        var p1: P? = nil
        var p2: P? = nil
        for i in 0..<points.count {
            if x < points[i].x {
                p1 = points[i-1]
                p2 = points[i]
                break;
            }
        }
        if p1 == nil {
            if x == points.last!.x {
                p1 = points[points.count-2]
                p2 = points[points.count-1]
            }
        }
        
        guard let p1 = p1 else { fatalError() }
        guard let p2 = p2 else { fatalError() }

        /// Get y
        
        let unitX = (x - p1.x) / (p2.x - p1.x)
        let y = unitX * (p2.y - p1.y) + p1.y
        
        return y
    }
    
    func evaluate(atY y: Double) -> Double {
        
        /// Validate
        
        assert(minY <= y && y <= maxY)
        
        /// Do calculations
        
        /// Find two points that y lies between
        ///     This is ambiguous if the curve goes up and down
        
        var p1: P? = nil
        var p2: P? = nil
        for i in 0..<points.count-1 {
            if points[i].y <= y && y <= points[i+1].y {
                p1 = points[i]
                p2 = points[i+1]
                break
            }
        }
        
        guard let p1 = p1 else { fatalError() }
        guard let p2 = p2 else { fatalError() }
        
        /// Get x
        
        let unitY = (y - p1.y) / (p2.y - p1.y)
        let x = unitY * (p2.x - p1.x) + p1.x
        
        return x
    }
    
}
