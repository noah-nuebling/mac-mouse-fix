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
    
    typealias AnimatorCallback = (_ animationValueDelta: Double, _ animationTimeDelta: Double, _ phase: MFAnimationPhase) -> ()
    
    // Vars - Init
    
    let displayLink: DisplayLink
    var callback: AnimatorCallback?
    var animationCurve: RealFunction? /// This class assumes that `animationCurve` passes through `(0, 0)` and `(1, 1)`
    
    // Init
    
    @objc override init() {
        
        self.displayLink = DisplayLink()
        
        super.init()
    }
    
    // Vars - Start & stop
    
    var animationTimeInterval: Interval = Interval.unitInterval() /// Just initing so Swift doesn't complain. This value is unused
    var animationValueInterval: Interval = Interval.unitInterval()
    
    var isRunning: Bool {
        self.displayLink.isRunning()
    }
    
    // Vars - DisplayLink
    
    var lastAnimationTime: Double = -1 /// Time at which the displayLink was last called
    var lastAnimationValue: Double = -1 /// animationValue when the displayLink was last called
    var animationPhase: MFAnimationPhase = kMFAnimationPhaseNone
    
    // Vars -  Interface
    
    @objc var animationTimeLeft: Double {
        return animationTimeInterval.length - lastAnimationTime
    }
    @objc var animationValueLeft: Double {
        return animationValueInterval.length - lastAnimationValue
    }
    
    // Other Interface
    
    @objc func linkToMainScreen() {
        /// Exposing this as a function and not just doing it automatically when the animation starts because I assume it's slow. Not sure where this assumption comes from.
        
        displayLink.linkToMainScreen()
    }
    
    // Start
    
    @objc func start(duration: CFTimeInterval,
                     valueInterval: Interval,
                     animationCurve: RealFunction,
                     callback: @escaping AnimatorCallback) {
        /// The use of 'Interval' in CFTimeInterval is kind of confusing, since its also used to spedify points in time (It's just a `Double`), and also it has nothing to do with our `Interval` class, which is much closer to an Interval in the Mathematical sense.
        /// Will be restarted if it's already running. No need to call stop before calling this.
        /// It's kind of unnecessary to be passing this a value interval, because we only use the length of it. Since the AnimatorCallback only receives valueDeltas each frame and no absolute values,  the location of the value interval doesn't matter.
        
        self.callback = callback
        self.animationCurve = animationCurve
        
        let now: CFTimeInterval = CACurrentMediaTime()
        
        self.animationTimeInterval = Interval.init(location: now, length: duration)
        self.animationValueInterval = valueInterval
        
        lastAnimationTime = now
        lastAnimationValue = animationValueInterval.start
        
        if (isRunning) {
            animationPhase = kMFAnimationPhaseRunningStart;
        } else {
            animationPhase = kMFAnimationPhaseStart;
            /// Start displayLink
            self.displayLink.start(callback: {
                self.displayLinkCallback()
            })
        }
    }
    
    /// Stop
    
    @objc func stop() {
        self.displayLink.stop()
    }
    
    /// DisplayLink callback
    /// This will be called whenever the display refreshes while the displayLink is running
    /// Its purpose is calling self.callback. Everything else it does is to figure out arguments for self.callback
    
    func displayLinkCallback() {
        /// I'm usually a fan of commenting even obvious things, to structure the code and make it easier to parse, but this is overkill. I think the comments make it less readable
        
        guard let callback = self.callback else {
            fatalError("Invalid state - callback can't be nil during running animation")
        }
        guard let animationCurve = self.animationCurve else {
            fatalError("Invalid state - animationCurve can't be nil during running animation")
        }
        
        /// Get current animation time aka `now`
        
        var now: CFTimeInterval = CACurrentMediaTime() /// Should maybe rename this to `animationTime`. It's not necessarily now when it's used.
        
        if now >= animationTimeInterval.end {
            /// Animation is ending
            animationPhase = kMFAnimationPhaseEnd
            now = animationTimeInterval.end /// Set now back to a valid value so we don't scroll too far and our scale functions don't throw errors
        }
        
        /// Get normalized time and value
        
        let animationTimeUnit: Double = Math.scale(value: now, from: animationTimeInterval, to: Interval.unitInterval()) /// From 0 to 1
        let animationValueUnit: Double = animationCurve.evaluate(at: animationTimeUnit) /// From 0 to 1
        
        /// Get actual animation value
        
        let animationValue: Double = Math.scale(value: animationValueUnit, from: Interval.unitInterval(), to: animationValueInterval)
        
        /// Get change since last frame aka `delta`
        
        let animationTimeDelta: CFTimeInterval = now - lastAnimationTime
        let animationValueDelta: Double = animationValue - lastAnimationValue
        
        /// Call the callback
        
        callback(animationValueDelta, animationTimeDelta, animationPhase)
        
        /// Update phases
        
        if animationPhase == kMFAnimationPhaseStart {
            animationPhase = kMFAnimationPhaseContinue
        } else if animationPhase == kMFAnimationPhaseEnd {
            displayLink.stop()
            animationPhase = kMFAnimationPhaseNone
        }
        
        /// Set `last` variables
        
        self.lastAnimationTime = now
        self.lastAnimationValue = animationValue
        
        /// Debug
        
//        print("timeU, \(animationTimeUnit), valueU: \(animationValueUnit)")
    }
    
}
