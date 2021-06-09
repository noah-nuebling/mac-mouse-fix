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
    
    typealias AnimatorCallback = (_ animationValue: Double, _ animationValueDelta: Double, _ phase: MFAnimationPhase) -> ()
    
    // Vars - Init
    
    var displayLink: DisplayLink
    var callback: AnimatorCallback
    var animationCurve: RealFunction /// This class assumes that `animationCurve` passes through `(0, 0)` and `(1, 1)`
    
    // Init
    
    init(callback: @escaping AnimatorCallback, animationCurve: RealFunction) {
        
        self.displayLink = DisplayLink.init()
        self.callback = callback
        self.animationCurve = animationCurve
        
        super.init()
        
        self.displayLink = DisplayLink.init(callback: { self.displayLinkCallback() })
    }
    
    // Vars - Start
    
    var animationTimeInterval: Interval = Interval.unitInterval()
    var animationValueInterval: Interval = Interval.unitInterval()
    
    // Vars - DisplayLink
    
    var lastAnimationTime: Double = -1 /// Time at which the displayLink was last called
    var lastAnimationValue: Double = -1 /// animationValue when the displayLink was last called
    var animationPhase: MFAnimationPhase = kMFAnimationPhaseNone
    
    // Vars -  Interface
    
    var animationTimeLeft: Double {
        return animationTimeInterval.length - lastAnimationTime
    }
    var animationValueLeft: Double {
        return animationValueInterval.length - lastAnimationValue
    }
    
    // Start
    
    func startAnimation(duration: CFTimeInterval, valueInterval: Interval) {
        /// The use of 'Interval' in CFTimeInterval is kind of confusing, since its also used to spedify points in time (It's just a `Double`), and also it has nothing to do with our `Interval` class, which is much closer to an Interval in the Mathematical sense.
        
        let now: CFTimeInterval = CACurrentMediaTime()
        
        self.animationTimeInterval = Interval.init(location: now, length: duration)
        self.animationValueInterval = valueInterval
        
        lastAnimationTime = now
        lastAnimationValue = animationValueInterval.start
        
        animationPhase = kMFAnimationPhaseBegin
        
        self.displayLink.start()
    }
    
    /// DisplayLink callback
    /// This will be called whenever the display refreshes while the displayLink is running
    /// Its purpose is calling self.callback. Everything else it does is to figure out arguments for self.callback
    
    func displayLinkCallback() {
        /// I'm usually a fan of commenting even obvious things, to structure the code and make it easier to parse, but this is overkill. I think the comments make it less readable
        
        /// Get current animation time aka `now`
        
        var now: CFTimeInterval = CACurrentMediaTime() /// Should maybe rename this to `animationTime`. It's not necessarily now when it's used.
        
        if now >= animationTimeInterval.end {
            /// Animation is ending
            animationPhase = kMFAnimationPhaseEnd
            now = animationTimeInterval.end /// Set now back to a valid value so we don't scroll too far and our scale functions don't throw errors
        }
        
        /// Get normalized time and value
        
        let animationTimeUnit: Double = Math.scale(value: now, from: animationTimeInterval, to: Interval.unitInterval()) /// From 0 to 1
        let animationValueUnit: Double = self.animationCurve.evaluate(at: animationTimeUnit) /// From 0 to 1
        
        /// Get actual animation value
        
        let animationValue = Math.scale(value: animationValueUnit, from: Interval.unitInterval(), to: animationValueInterval)
        
        /// Get change since last frame aka `delta`
        
        let animationTimeDelta: CFTimeInterval = now - lastAnimationTime
        let animationValueDelta: Double = animationValue - lastAnimationValue
        
        /// Call the callback
        
        self.callback(animationValueDelta, animationTimeDelta, animationPhase)
        
        /// Update phases
        
        if animationPhase == kMFAnimationPhaseBegin {
            animationPhase = kMFAnimationPhaseContinue
        } else if animationPhase == kMFAnimationPhaseEnd {
            displayLink.stop()
            animationPhase = kMFAnimationPhaseNone
        }
        
        /// Set `last` variables
        
        self.lastAnimationTime = now
        self.lastAnimationValue = animationValue
    }
    
}
