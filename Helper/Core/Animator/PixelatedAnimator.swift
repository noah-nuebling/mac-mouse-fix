//
// --------------------------------------------------------------------------
// PixelatedAnimator.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// (Copied from old non-vector PixelatedAnimator)
///
/// Only use PixelatedAnimator, not Animator superclass directly. Animator is untested and probably doesn't work
///
/// This class does different things. An attempt to summarize: "Based on some input deltas, this class creates smoothly animated output deltas that are that are usable for driving simulated trackpad events"
/// It is currently used:
/// 1. To smooth out pointer movement before plugging it into the GestureScrollSimulator. This prevents too slow / fast momentum scroll due to irregular timeBetweenEvents.
/// 2. To apply animation and find appropriate gesture phases when mapping scrollwheel input to gestureScrolling, dockSwipes, magnification, etc.
///
/// PixelatedAnimator will behave just like Animator with these differences:
/// The animationValueDelta values it passes to it's AnimatorCallback are always integers instead of Doubles
/// To achieve this, the internally generated Double deltas are rounded using a subpixelator which always rounds to the next larger integer (using biasedSubpixelator)
///     This is so we always generate a non-zero integer delta on the first frame of animation, which makes things more responsive when the deltas are single pixels (which they are when you use Apple Acceleration)
///
/// Callbacks wth phases kMFAnimationPhaseStart, and kMFAnimationPhaseContinue have non-zero deltas. Callbacks with kMFAnimationPhaseEnd have a delta of (0,0)
///     This behaviour will make this animator great for driving touch gesture simulations, where that kind of input is expected. (In gesture events, the end phase signals lifting your fingers off, so that's why it has a (0,0) delta)

import Cocoa
import CocoaLumberjackSwift

class PixelatedAnimator: Animator {

    /// Make stuff from superclass unavailable
    
        @available(*, unavailable)
        override func start(params: @escaping StartParamCalculationCallback, callback: @escaping AnimatorCallback) {
            fatalError();
        }
    
    /// Declare types and vars that superclass doesn't have
    
    typealias PixelatedAnimatorCallback = (_ integerAnimationValueDelta: Vector, _ phase: MFAnimationCallbackPhase, _ momentumHint: MFMomentumHint) -> ()
    var integerCallback: PixelatedAnimatorCallback?;
    //    var subPixelator: SubPixelator = SubPixelator.ceil();
    /// ^ This being a ceil subPixelator only makes sense because we're only using this through Scroll.m and that's only running this with positive value ranges. So the deltas are being rounded up, and we get a delta immediately as soon as the animations starts, which should make scrolling very small distances feel a little more responsive. If we were dealing with negative deltas, we'd want to round them down instead somehow. Or simply use a SubPixelator.round() which works the same in both directions.
    
    var subPixelator = VectorSubPixelator.biased()
    /// ^ This biased subpixelator should make SubpixelatedAnimator  also work negative value ranges. So it can also be properly used for for momentum scrolling in GestureScrollAnimator.m
    
    // MARK: Interface
    
    /// Other interface
    
    /// SubPixelator reset
    ///     You usually want to call this where you call linkToMainScreen()
    
    @objc func resetSubPixelator_Unsafe() {
        DDLogDebug("HNGG Resetting subpixelator")
        self.subPixelator.reset()
    }
    @objc func resetSubPixelator() {
        displayLink.dispatchQueue.async {
            self.resetSubPixelator_Unsafe()
        }
    }
    
    /// Declare new start function
    
    @objc func start(params: @escaping StartParamCalculationCallback,
                     integerCallback: @escaping PixelatedAnimatorCallback) {
        
        displayLink.dispatchQueue.async {
            
            /// Get startParams
            
            let p = params(self.animationValueLeft_Unsafe, self.isRunning_Unsafe, self.animationCurve)
            
            /// Reset animationValueLeft
            ///     Do this here since `animationValueLeft` is `animationValueTotal - lastAnimationValue`. A new `animationValueTotal` is contained in `p`, and we need to reset `lastAnimationValue` to make it usable.
            self.lastAnimationValue = Vector(x: 0, y: 0)
            
            /// Do nothing if doStart == false
            if let doStart = p["doStart"] as? Bool {
                if doStart == false {
                    return
                }
            }
            
            /// Validate
            assert(p["vector"] is NSValue)
            /// ^ This is always true for some reason. Make sure to actually pass a Vector in an NSValue! Edit: Randomly, this starting working on 29.05.22
            
            /// Start animator
            
            super.startWithUntypedCallback_Unsafe(durationRaw: p["duration"] as! Double, value: vectorFromNSValue(p["vector"] as! NSValue), animationCurve: p["curve"] as! Curve, callback: integerCallback)
            
            /// Debug
            
            let deltaLeftBefore = self.animationValueLeft_Unsafe;
            DDLogDebug("\nStarted PixelatedAnimator with deltaLeftDiff: \(subtractedVectors(self.animationValueLeft_Unsafe, deltaLeftBefore)), oldDeltaLeft: \(deltaLeftBefore), newDeltaLeft: \(self.animationValueLeft_Unsafe)")
            
        }
    }
    
    /// Debug vars
    
    internal var summedIntegerAnimationValueDelta: Vector = Vector(x: 0, y: 0);
    
    /// Hook into superclasses' displayLinkCallback()
    
    override func subclassHook(_ untypedCallback: Any, _ animationValueDelta: Vector, _ animationTimeDelta: CFTimeInterval, _ momentumHint: MFMomentumHint) {
        /// This hooks into displayLinkCallback() in Animator.swift. Look at that for context.
        
        /// Guard callback type
        
        guard let callback = untypedCallback as? PixelatedAnimatorCallback else {
            fatalError("Invalid state - callback is not type PixelatedAnimatorCallback")
        }
        
        /// Update phase to `end` if all valueLeft won't lead to another non-zero delta
        
        let currentAnimationValueLeft = animationValueLeft_Unsafe
        let intAnimationValueLeft = subPixelator.peekIntVector(withDouble: currentAnimationValueLeft);
        if isZeroVector(intAnimationValueLeft) {
            isLastDisplayLinkCallback = true /// After this we know the delta will be zero, so most of the work we do below is unnecessary
        }
        
        /// Get subpixelated animationValueDelta
        
        let integerAnimationValueDelta = subPixelator.intVector(withDouble: animationValueDelta)
        
        /// Skip this frames callback
        ///     and don't update animationPhase from `start` to `continue`
        ///     Also don't update lastAnimationPhase
        
        if (isZeroVector(integerAnimationValueDelta)
            && !isLastDisplayLinkCallback) {
            
            /// Log
            DDLogDebug("\nHNGG Skipped PixelatedAnimator callback due to 0 delta.")
            
        } else {
        
            /// Check if simultaneously start and end
            ///     There is similar code in superclass. Update that it when you change this.
            
            let isEndAndNoPrecedingDeltas =
                isLastDisplayLinkCallback
                && !thisAnimationHasProducedDeltas
            
            /// Call callback
            
            if (!isEndAndNoPrecedingDeltas) { /// Skip `end` phase callbacks if there have been no deltas.
                let phase = PixelatedAnimator.callbackPhase(hasProducedDeltas: thisAnimationHasProducedDeltas, isLastCallback: isLastDisplayLinkCallback)
                callback(integerAnimationValueDelta, phase, momentumHint)
            }
            
            /// Debug
            
            DDLogDebug("\nPixelatedAnimator callback with delta: \(integerAnimationValueDelta)")
            
            /// Update hasProducedDeltas
            /// 
            self.thisAnimationHasProducedDeltas = true
            
        } /// End `if (isZeroVector...`
    }
}
