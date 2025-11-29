//
// --------------------------------------------------------------------------
// TouchAnimator.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// (Copied from old non-vector TouchAnimator)
///
/// Only use TouchAnimator, not TouchAnimatorBase superclass directly. TouchAnimatorBase is untested and probably doesn't work right.
/// This is basically a wrapper around TouchAnimatorBase that subpixelates the output deltas. We thought it would be easier to first build the TouchAnimatorBase without the subpixelation and then add that complextity on after the fact. I think it clutters things up a lot though.

///     \Ideas for refactor: Merge TouchAnimator and TouchAnimatorBase. Maybe remove the subpixelators and just round in a way where you don't lose the rounding error. (e.g. rounding the pixel delta for this frame to determine what to actually scroll and only subtracting from the valueLeft what we actually scrolled... Not sure if that would have the same behavior as the current system though - might be a ton of work to get it to work right with all the touch simulation stuff that relies on very precisely setting the phases and deltas.)
///
/// This class does different things. An attempt to summarize: "Based on some input deltas, this class creates smoothly animated output deltas that are that are usable for driving simulated trackpad events"
/// It is currently used:
/// 1. To smooth out pointer movement before plugging it into the GestureScrollSimulator. This prevents too slow / fast momentum scroll due to irregular timeBetweenEvents.
/// 2. To apply animation and find appropriate gesture phases when mapping scrollwheel input to gestureScrolling, dockSwipes, magnification, etc.
///
/// TouchAnimator will behave just like TouchAnimatorBase with these differences:
/// The animationValueDelta values it passes to it's AnimatorCallback are always integers instead of Doubles
/// To achieve this, the internally generated Double deltas are rounded using a subpixelator which always rounds to the next larger integer (using biasedSubpixelator)
///     This is so we always generate a non-zero integer delta on the first frame of animation, which makes things more responsive when the deltas are single pixels (which they are when you use Apple Acceleration)
///
/// Callbacks wth phases kMFAnimationPhaseStart, and kMFAnimationPhaseContinue have non-zero deltas. Callbacks with kMFAnimationPhaseEnd have a delta of (0,0)
///     This behaviour will make this animator great for driving touch gesture simulations, where that kind of input is expected. (In gesture events, the end phase signals lifting your fingers off, so that's why it has a (0,0) delta)
///
/// Also has this cool momentumHint feature which lets us switch between gesture scrolls and momentum scrolls appropriately to allow for scroll bouncing and generally better behaviour.

import Cocoa

class TouchAnimator: TouchAnimatorBase {

    /// Make stuff from superclass unavailable
    
        @available(*, unavailable)
        override func start(params: @escaping StartParamCalculationCallback, callback: @escaping AnimatorCallback) {
            fatalError();
        }
    
    /// Declare types and vars that superclass doesn't have
    
    typealias TouchAnimatorCallback = (_ integerAnimationValueDelta: Vector, _ phase: MFAnimationCallbackPhase, _ momentumHint: MFMomentumHint) -> ()
    var integerCallback: TouchAnimatorCallback?;
    //    var subPixelator: SubPixelator = SubPixelator.ceil();
    /// ^ This being a ceil subPixelator only makes sense because we're only using this through Scroll.m and that's only running this with positive value ranges. So the deltas are being rounded up, and we get a delta immediately as soon as the animations starts, which should make scrolling very small distances feel a little more responsive. If we were dealing with negative deltas, we'd want to round them down instead somehow. Or simply use a SubPixelator.round() which works the same in both directions.
    
    var subPixelator = VectorSubPixelator.biased()
    /// ^ This biased subpixelator should make SubTouchAnimator  also work negative value ranges. So it can also be properly used for for momentum scrolling in GestureScrollAnimator.m
    
    
    // MARK: Other interface
    
    /// SubPixelator reset
    ///     You usually want to call this where you call linkToMainScreen()
    
    @objc func resetSubPixelator_Unsafe() {
        DDLogDebug("HNGG Resetting subpixelator")
        self.subPixelator.reset()
    }
    @objc func resetSubPixelator() {
        displayLink.dispatchQueue.async(flags: defaultDFs) {
            self.resetSubPixelator_Unsafe()
        }
    }
    
    // MARK: Declare new start function
    
    @objc func start(params: @escaping StartParamCalculationCallback,
                     integerCallback: @escaping TouchAnimatorCallback) {
        
        displayLink.dispatchQueue.async(flags: defaultDFs) {
            
            /// Get startParams
            
            let p = params(self.animationValueLeft_Unsafe, self.isRunning_Unsafe, self.animationCurve, self.lastAnimationSpeed)
            
            /// Reset animationValueLeft
            /// Notes:
            /// - Do this here since `animationValueLeft` is `animationValueTotal - lastAnimationValue`. A new `animationValueTotal` is contained in `p`, and we need to reset `lastAnimationValue` to make it usable. Edit: What? ... I think this is talking about why this is reset here and not inside startWithUntypedCallback() or the displayLinkCallback, where most other things are reset.
            /// - Why is this reset before the doStart check?
            
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
            
            super.startWithUntypedCallback_Unsafe(durationRaw: p["duration"] as! Double?, durationRawInFrames: p["durationInFrames"] as! Int?, value: vectorFromNSValue(p["vector"] as! NSValue), animationCurve: p["curve"] as! Curve, callback: integerCallback)
            
            /// Debug
            
            let deltaLeftBefore = self.animationValueLeft_Unsafe;
            DDLogDebug("\nStarted TouchAnimator with deltaLeftDiff: \(subtractedVectors(self.animationValueLeft_Unsafe, deltaLeftBefore)), oldDeltaLeft: \(deltaLeftBefore), newDeltaLeft: \(self.animationValueLeft_Unsafe)")
            
        }
    }
    
    /// Debug vars
    
    internal var summedIntegerAnimationValueDelta: Vector = Vector(x: 0, y: 0);
    
    // MARK: Hook into superclasses' displayLinkCallback()
    
    override func subclassHook(_ untypedCallback: Any, _ animationValueDelta: Vector, _ animationTimeDelta: CFTimeInterval, _ momentumHint: MFMomentumHint) {
        /// This hooks into displayLinkCallback() in Animator.swift. Look at that for context.
        
        /// Guard callback type
        
        guard let callback = untypedCallback as? TouchAnimatorCallback else {
            fatalError("Invalid state - callback is not type TouchAnimatorCallback")
        }
        
        /// Update phase to `end` if all valueLeft won't lead to another non-zero delta
        
        let currentAnimationValueLeft = animationValueLeft_Unsafe
        let intAnimationValueLeft = subPixelator.peekIntVector(withDoubleVector: currentAnimationValueLeft);
        if isZeroVector(intAnimationValueLeft) {
            isLastDisplayLinkCallback = true /// After this we know the delta will be zero, so most of the work we do below is unnecessary
        }
        
        /// Get subpixelated animationValueDelta
        
        let integerAnimationValueDelta = subPixelator.intVector(withDoubleVector: animationValueDelta)
        
        /// Skip this frames callback
        ///     and don't update animationPhase from `start` to `continue`
        ///     Also don't update lastAnimationPhase
        
        if (isZeroVector(integerAnimationValueDelta)
            && !isLastDisplayLinkCallback) {
            
            /// Log
            DDLogDebug("\nHNGG Skipped TouchAnimator callback due to 0 delta.")
            
        } else {
        
            /// Check if simultaneously start and end
            ///     There is similar code in superclass. Update that it when you change this.
            
            let isEndAndNoPrecedingDeltas =
                isLastDisplayLinkCallback
                && !thisAnimationHasProducedDeltas
            
            /// Call callback
            var phase = kMFAnimationCallbackPhaseNone
            if (!isEndAndNoPrecedingDeltas) { /// Skip `end` phase callbacks if there have been no deltas.
                phase = TouchAnimator.callbackPhase(hasProducedDeltas: thisAnimationHasProducedDeltas, isLastCallback: isLastDisplayLinkCallback)
                callback(integerAnimationValueDelta, phase, momentumHint)
            }
            
            /// Debug
            
            DDLogDebug("\nTouchAnimator callback with delta: \(integerAnimationValueDelta), phase: \(phase), momentumHint: \(momentumHint)")
            
            /// Update hasProducedDeltas
            /// 
            self.thisAnimationHasProducedDeltas = true
            
        } /// End `if (isZeroVector...`
    }
}
