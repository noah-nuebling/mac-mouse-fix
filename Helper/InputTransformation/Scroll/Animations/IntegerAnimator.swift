//
// --------------------------------------------------------------------------
// IntegerAnimator.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// IntegerAnimator will behave just like Animator with these differences:
/// The animationValueDelta values it passes to it's AnimatorCallback are always integers instead of Doubles
/// To achieve this, the internally generated Double deltas are rounded using a subpixelator which always rounds to the next larger integer (a ceilPixelator)
///     Using ceil instead of normal rounding (roundPixelator) will always generate the first non-zero integer delta immediately on the first frame of animation. I hope that will make the animations this produces marginally more responsive.
/// Integer deltas which are zero won't be passed to the AnimatorCallback
/// Phases kMFAnimationPhaseStart, and kMFAnimationPhaseEnd will be sent to the AnimatorCallback with the first and last non-zero integer deltas respectively.


import Cocoa
import CocoaLumberjackSwift

class IntegerAnimator: Animator {
    
    /// Make stuff from superclass unavailable
    
    @available(*, unavailable)
    override func start(duration: CFTimeInterval, valueInterval: Interval, animationCurve: RealFunction, callback: @escaping Animator.AnimatorCallback) {
        fatalError();
    }
    
    /// Declare types and vars that superclass doesn't have
    
    typealias IntegerAnimatorCallback = (_ integerAnimationValueDelta: Int, _ animationTimeDelta: Double, _ phase: MFAnimationPhase) -> ()
    var integerCallback: IntegerAnimatorCallback?;
    
    var subPixelator: SubPixelator = SubPixelator.ceil();
    /// ^ This being a ceil subPixelator only makes sense because we're only using this through Scroll.m and that's only running this with positive value ranges. So the deltas are being rounded up, and we get a delta immediately as soon as the animations starts, which should make scrolling very small distances feel a little more responsive. If we were dealing with negative deltas, we'd want to round them down instead somehow. Or simply use a SubPixelator.round() which works in both directions.
    
    /// Declare new start function
    
    @objc func start(duration: CFTimeInterval,
                                valueInterval: Interval,
                                animationCurve: RealFunction,
                                integerCallback: @escaping IntegerAnimatorCallback) {
        
        self.startWithUntypedCallback(duration: duration, valueInterval: valueInterval, animationCurve: animationCurve, callback: integerCallback)
        
        if self.animationPhase == kMFAnimationPhaseStart {
            self.subPixelator.reset()
            
        }
    }
    
    /// Hook into superclasses displayLinkCallback()
    
    override func subclassHook(_ untypedCallback: Any, _ animationValueDelta: Double, _ animationTimeDelta: CFTimeInterval) {
        /// This hooks into displayLinkCallback() on Animator.swift. Look at that for context.
        
        /// Guard callback type
        
        guard let callback = untypedCallback as? IntegerAnimatorCallback else {
            fatalError("Invalid state - callback is not type IntegerAnimatorCallback")
        }
        
        /// Get subpixelated animationValueDelta
        
        let integerAnimationValueDelta = Int(self.subPixelator.intDelta(withDoubleDelta: animationValueDelta));
        
        if (integerAnimationValueDelta != 0) {
            /// Skip this frames callback and don't update animationPhase, if the integer value delta is 0
            
            /// Check if this was the last int delta
            
            let currentAnimationValueLeft = self.animationValueLeft + animationValueDelta;
            /// ^ We don't use self.animationValueLeft directly, because it's derived from self.lastAnimationValue which is only updated at the end of displayLinkCallback() after it calls subclassHook().
            let intAnimationValueLeft = subPixelator.peekIntDelta(withDoubleDelta: currentAnimationValueLeft);
            if intAnimationValueLeft == 0 {
                self.animationPhase = kMFAnimationPhaseEnd;
            }
            
            /// Update phase
            
            if (animationPhase == kMFAnimationPhaseEnd /// This is last event of the animation
                    && lastAnimationPhase == kMFAnimationPhaseNone) { /// This is also the first event of the animation
                animationPhase = kMFAnimationPhaseStartingEnd;
            }
            
            /// Debug
            
//            DDLogDebug("valueD, \(animationValueDelta), valueDInt: \(integerAnimationValueDelta), timeD: \(animationTimeDelta), phase: \(self.animationPhase)")
            
            /// Call callback
            
            callback(integerAnimationValueDelta, animationTimeDelta, self.animationPhase)
            
            /// Update phases
            /// We do the exact same thing in Animator. The only reason we've put this into the subclassHook instead of the displayLinkCallback() is because we don't want to do this in IntegerAnimator if integerAnimationValueDelta == 0 (see above)
            
            if self.animationPhase == kMFAnimationPhaseStart || self.animationPhase == kMFAnimationPhaseRunningStart {
                self.animationPhase = kMFAnimationPhaseContinue
            } else if self.animationPhase == kMFAnimationPhaseEnd {
                stop()
            }
        }
    }
    
}


/// Override displayLinkCallback()

//    @objc override func displayLinkCallback() {
//
//
//        guard let callback = self.callback as? IntegerAnimatorCallback else {
//            fatalError("Invalid state - callback can't be nil during running animation")
//        }
//        guard let animationCurve = self.animationCurve else {
//            fatalError("Invalid state - animationCurve can't be nil during running animation")
//        }
//
//        /// Get current animation time aka `now`
//
//        var now: CFTimeInterval = CACurrentMediaTime() /// Should maybe rename this to `animationTime`. It's not necessarily now when it's used.
//
//
//        /// Check if time is up
//        /// Check up here because we want to adjust `now` which is the basis for the following calculations
//
//        if now >= animationTimeInterval.end {
//            /// Animation is ending
//            animationPhase = kMFAnimationPhaseEnd
//            now = animationTimeInterval.end /// Set now back to a valid value so we don't scroll too far and our scale functions don't throw errors
//        }
//
//        /// Get normalized time and value
//
//        let animationTimeUnit: Double = Math.scale(value: now, from: animationTimeInterval, to: Interval.unitInterval()) /// From 0 to 1
//        let animationValueUnit: Double = animationCurve.evaluate(at: animationTimeUnit) /// From 0 to 1
//
//        /// Get actual animation value
//
//        let animationValue: Double = Math.scale(value: animationValueUnit, from: Interval.unitInterval(), to: animationValueInterval)
//
//        /// Get change since last frame aka `delta`
//
//        let animationTimeDelta: CFTimeInterval = now - lastAnimationTime
//        let animationValueDelta: Double = animationValue - lastAnimationValue
//
//
//        /// Update `last` values
//
//        self.lastAnimationTime = now
//        self.lastAnimationValue = animationValue
//
//
//
//
//        /// *******************************************************
//        /// v Only this is different from the superclass implementation
//
//
//
//        /// Get subpixelated animationValueDelta
//
//        let integerAnimationValueDelta = Int(self.subPixelator.intDelta(withDoubleDelta: animationValueDelta));
//
//        ///
//
//        if (integerAnimationValueDelta == 0) {
//            return
//        }
//
//        /// Check if this was the last int delta
//
//        let intAnimationValueLeft = subPixelator.peekIntDelta(withDoubleDelta: self.animationValueLeft);
//        /// ^ We can only use self.animationValueLeft, because self.lastAnimationValue was already updated above
//        if intAnimationValueLeft == 0 {
//            animationPhase = kMFAnimationPhaseEnd;
//        }
//
//
//
//        /// *******************************************************
//
//
//
//            /// Call the callback
//
//        callback(integerAnimationValueDelta, animationTimeDelta, animationPhase)
//
//        /// Update phases
//
//        if animationPhase == kMFAnimationPhaseStart {
//            animationPhase = kMFAnimationPhaseContinue
//        } else if animationPhase == kMFAnimationPhaseEnd {
//            stop()
//        }
//
//        /// Debug
//
//        DDLogDebug("timeU, \(animationTimeUnit), valueU: \(animationValueUnit)")
//    }
