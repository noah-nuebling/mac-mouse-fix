//
// --------------------------------------------------------------------------
// Animator.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation

@objc class Animator : NSObject{
    
    typealias AnimatorCallback = () -> ()
    
    // A
    
    var callback: AnimatorCallback
    var animationCurve: RealFunction
    
    init(callback: @escaping AnimatorCallback, animationCurve: RealFunction) {
        
        self.callback = callback
        self.animationCurve = animationCurve
        
        super.init()
    }
    
    // B
    
    var animationDuration: Double = 0
    var animationRange: ContinuousRange = ContinuousRange.normalRange()
    
}
