//
//  CAAnimation+Extensions.swift
//  tabTestStoryboards
//
//  Created by Noah Nübling on 03.08.22.
//

import Foundation
import QuartzCore

extension CABasicAnimation {
    
    convenience init(name: CAMediaTimingFunctionName, duration: CFTimeInterval) {
        self.init()
        let f = CAMediaTimingFunction(name: name)
        self.timingFunction = f
        
    }
    convenience init(points c1x: Double, _ c1y: Double, _ c2x: Double, c2y: Double, duration: CFTimeInterval) {
        self.init()
        let f = CAMediaTimingFunction(controlPoints: Float(c1x), Float(c1y), Float(c2x), Float(c2y))
        self.timingFunction = f
    }
    convenience init(curve: CAMediaTimingFunction, duration: CFTimeInterval) {
        self.init()
        self.timingFunction = curve
        self.duration = duration
    }
}

extension CASpringAnimation {
    
    convenience init(speed f: Double, damping z: Double, mass m: Double = 1, distance d: Double = 0, initialVelocity v0: Double = 0) {
        
        /// Like below but with `mass` and `distance` params. Not sure this works.
    
        let k = pow(2 * .pi * f, 2) * m * d
        let c = 2 * sqrt(k * m) * z
        
        self.init(stiffness: k, damping: c, mass: m, initialVelocity: v0)
    }
    
    convenience init(speed f: Double, damping z: Double, initialVelocity v0: Double = 0) {
        
        /// Dynamic-system-based animation
        /// Arguments:
        /// `speed` is the frequency at which the system will oscillate when underdamped
        /// `damping`
        ///     - `< 1` -> Underdamped -> will overshoot even at `initialVelocity = 0`
        ///     - `= 0` -> Critically damped -> No overshoot + minimum animation time
        ///     - `> 0` -> Overdamped -> No overshoot
        
        /// Sources:
        /// - https://medium.com/ios-os-x-development/demystifying-uikit-spring-animations-2bb868446773
        /// - https://www.youtube.com/watch?v=KPoeNZZ6H4s
    
        let mass = 1.0
        let stiffness = pow(2 * .pi * f, 2) * mass
        let damping = 4 * .pi * z * mass * f
        
        self.init(stiffness: stiffness, damping: damping, mass: mass, initialVelocity: v0)
    }

    convenience init(stiffness k: Double, damping c: Double, mass m: Double = 1, initialVelocity: Double = 0) {
        self.init()
        self.stiffness = k
        self.damping = c
        self.mass = m
        self.initialVelocity = initialVelocity
        self.duration = self.settlingDuration /// Increasing this seems to make a difference for window resizing animations
    }
}
