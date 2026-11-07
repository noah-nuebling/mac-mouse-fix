//
// --------------------------------------------------------------------------
// TouchAnimator.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/**
    See TouchAnimatorBase.swift
*/

import Cocoa

class TouchAnimator: TouchAnimatorBase {

    
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
    @objc func resetSubPixelator() {
        assertRunLoop(displayLink.runLoop());
        readsAndWritesState_Begin(readWriteTracker); defer { readsAndWritesState_End(readWriteTracker) }
        DDLogDebug("HNGG Resetting subpixelator")
        self.subPixelator.reset()
    }
    
    // MARK: Declare new start function
    
    @objc func start(duration: Double, durationInFrames: Int, vector: Vector, curve: Curve, integerCallback: @escaping TouchAnimatorCallback) {
        assertRunLoop(displayLink.runLoop());
        readsAndWritesState_Begin(readWriteTracker); defer { readsAndWritesState_End(readWriteTracker) }

        /// Debug
        var deltaLeftBefore = Vector(x: 0, y: 0)
        if (runningDebugMode()) {
            allowNestedReadOrWrite_Begin(from: .readsAndWritesState, readWriteTracker)
            deltaLeftBefore = self.animationValueLeft;
            allowNestedReadOrWrite_End(from: .readsAndWritesState, readWriteTracker)
        }

        /// Start animator
        super.startWithUntypedCallback(durationRaw: duration, durationRawInFrames: durationInFrames, value: vector, animationCurve: curve, callback: integerCallback)

        /// Debug
        if (runningDebugMode()) {
            allowNestedReadOrWrite_Begin(from: .readsAndWritesState, readWriteTracker)
            DDLogDebug("Started TouchAnimator with deltaLeftDiff: \(subtractedVectors(self.animationValueLeft, deltaLeftBefore)), oldDeltaLeft: \(deltaLeftBefore), newDeltaLeft: \(self.animationValueLeft)")
            allowNestedReadOrWrite_End(from: .readsAndWritesState, readWriteTracker)
        }
    }

    /// Debug vars
    
    internal var summedIntegerAnimationValueDelta: Vector = Vector(x: 0, y: 0);
    
    // MARK: Hook into superclasses' displayLinkCallback()
    
    override internal func subclassHook(_ untypedCallback: Any, _ animationValueDelta: Vector, _ animationTimeDelta: CFTimeInterval, _ momentumHint: MFMomentumHint) {
        /// This hooks into displayLinkCallback() in the superclass. Look at that for context.

        /// Guard callback type
        
        guard let callback = untypedCallback as? TouchAnimatorCallback else {
            fatalError("Invalid state - callback is not type TouchAnimatorCallback")
        }
        
        /// Update phase to `end` if all valueLeft won't lead to another non-zero delta
        
        allowNestedReadOrWrite_Begin(from: .readsAndWritesState, readWriteTracker)
        let currentAnimationValueLeft = animationValueLeft
        allowNestedReadOrWrite_End(from: .readsAndWritesState, readWriteTracker)
        
        let intAnimationValueLeft = subPixelator.peekIntVector(withDoubleVector: currentAnimationValueLeft);
        if isZeroVector(intAnimationValueLeft) {
            isLastDisplayLinkCallback = true /// After this we know the delta will be zero, so most of the work we do below is unnecessary
        }
        
        /// Get subpixelated animationValueDelta
        
        let integerAnimationValueDelta = subPixelator.intVector(withDoubleVector: animationValueDelta)
        
        /// Skip this frames callback
        ///     and don't update animationPhase from `start` to `continue`
        ///     Also don't update lastAnimationPhase
        
        if (isZeroVector(integerAnimationValueDelta) && !isLastDisplayLinkCallback) {

            /// Log
            DDLogDebug("HNGG Skipped TouchAnimator callback due to 0 delta.")
            
        } else {
            
            /// Call callback
            let phase = TouchAnimator.callbackPhase(hasProducedDeltas: thisAnimationHasProducedDeltas, isLastCallback: isLastDisplayLinkCallback)
            callback(integerAnimationValueDelta, phase, momentumHint)
            
            /// Debug
            DDLogDebug("TouchAnimator callback with delta: \(integerAnimationValueDelta), phase: \(phase), momentumHint: \(momentumHint)")
            
            /// Update hasProducedDeltas
            self.thisAnimationHasProducedDeltas = true
            
        } /// End `if (isZeroVector...`
    }
}
