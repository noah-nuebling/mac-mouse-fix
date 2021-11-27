//
// --------------------------------------------------------------------------
// Curve.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

@objc protocol AnimationCurve {
    
    @objc func evaluate(at x: Double) -> Double
    /// ^ Animator.swift expects this to pass through (0,0) and (1,1)
}
