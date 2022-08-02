//
// --------------------------------------------------------------------------
// DynamicSystemAnimator.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// This is neat but not really useful and has race conditions when you usie it for smoothing in ModifieDragOutputTwoFingerSwipe
///
/// Initial notes
/// Idea for **dynamic-system-based animations**
/// I really want to implement dynamic system-based-animations, becuase it sounds really cool and super fun to implement. (Also it might make some feel a little nicer / simplify our code while producing similar results - but not enough to really warrant spending time on it right now - but goddamn I really wanna do it!)
///     I was inspired by this **amazing** video by t3ssel8r: https://www.youtube.com/watch?v=KPoeNZZ6H4s
///     For the implementation, this document should be really useful, too: https://www.uml.edu/docs/Second-Theory_tcm18-190098.pdf
///
///     \note :
///         If I understand correctly, spring animations are a subset of 2nd order dynamic system animations - just to help your intuition.
///
///     \discussion:
///         We're already using differential equations for the animation with the `Drag` animation curve.
///         But when looking at the differential equations governing Drag curves, we see that the force that's acting on the object is a function of the current speed. This makes it hard to specify a distance that the curve should scroll overall. However, that's the main constraint we have right now when using the animator in Scroll.m - the scroll distance.
///         The way we solve this is to first scroll at a constant speed and then switch to the Drag equation at a dynamically chosen point in time, such that the overall scrolled distance between the constant-scrolling and the drag-scrolling is the one we specified beforehand (This is done in `HybridCurves.swift`)
///         Now, looking at 2nd order dynamic systems, they are also described by differential equations, and they produce similarly smooth and natural feeling movement to a Drag equation. But in contrast to a drag system, in the dynamic system, the force that's acting on the object is (/can be?) a function of the distance to the desired location. So we wouldn't have to do all this complicated switching from a constant scrolling speed to the Drag equation, because the dynamic system is defined from the ground up in terms of how far it should move. This makes it much more elegant for the constraints we want to put on the system!! (which is mainly scrolling distance)
///
///         The only advantage of the current `HybridCurve` approach that I can think of, is that having a constant scrolling speed at the start of the animation actually makes the animation speed stay totally constant if the user is moving the scrollwheel at a constant speed. This should make things feel more smooth and responsive. I don't know how you could replicate this property in the dynamic-system-based scrolling.
///
///         Conclusion (for now): Using this from the start would've simplified things, but it'll likely be slightly worse than the current implementation and bringing it up to par when it comes to threadsafety might be hard and tedious (Or maybe we only need to calculate the params for the start function on the queue? That's an obvious thing I can't think of). But it was fun to implement and play around with the silly spring animations. April fools update?
///
///         TODO: ^ Give the caller of the start function the ability to execute on the dispatch queue like in Animator.swift

import Foundation

@objc class DynamicSystemAnimator: NSObject {
    
    /// Storage
    
    let displayLink: DisplayLink
    let queue: DispatchQueue
    
    /// Params
    
    let k1: Double
    let k2: Double
    let k3: Double
    
    let epsilon: Double
    
    /// State
    
    var x: Vector /// Target
    var x0: Vector /// Last input
    
    var y0: Vector /// Last displacement
    var y0_: Vector /// Last velocity
    var y0__: Vector /// Last acceleration
    var t0: CFTimeInterval /// Last step time
    
    var isFirstCallback: Bool
    
    var pixelator: VectorSubPixelator
    
    /// Initializers
    
    @objc convenience init(speed f: Double, damping z: Double, initialResponser r: Double, stopTolerance: Double) {
        /// Damping >= 1 turns off vibrations
        
        let k1 = z / (.pi * f)
        let k2 = 1 / pow(2 * .pi * f, 2)
        let k3 = (r * z) / (2 * .pi * f)
        
        self.init(k1: k1, k2: k2, k3: k3, stopTolerance: stopTolerance)
    }
    
    @objc required init(k1: Double, k2: Double, k3: Double, stopTolerance: Double) {
        /// Validate
        assert(stopTolerance > 0, "Will never stop if stopTolerance <= 0")
        /// Constants
        self.k1 = k1
        self.k2 = k2
        self.k3 = k3
        epsilon = stopTolerance
        displayLink = DisplayLink()
        queue = displayLink.dispatchQueue
        pixelator = VectorSubPixelator.biased()
        /// State
        let z = Vector(x: 0, y: 0)
        x = z
        x0 = z
        y0 = z
        y0_ = z
        y0__ = z
        t0 = 0
        isFirstCallback = false
        pixelator.reset()
        /// Init super
        super.init()
        /// Reset state
        resetState()
    }
    
    /// Main interface
    
    @objc func resetState() {
        queue.async {
            let z = Vector(x: 0, y: 0)
            self.x = z
            self.x0 = z
            self.y0 = z
            self.y0_ = z
            self.y0__ = z
            self.t0 = 0
            self.isFirstCallback = false
            self.pixelator.reset()
        }
    }
    
    @objc func start(distance: Vector, callback: @escaping PixelatedAnimator.PixelatedAnimatorCallback) {
        
        queue.async {
            
            /// Normalize displacement
            ///     So the values don't grow to infinity and overflow
            self.y0 = subtractedVectors(self.y0, self.x)
            self.x0 = subtractedVectors(self.x0, self.x)
            self.x = Vector(x: 0, y: 0)
            
            /// Update target
            self.x = distance
            
            /// Update state
            self.isFirstCallback = true
            
            /// Start displayLink
            self.displayLink.start_Unsafe { timeInfo in self.queue.sync { self.update(timeInfo, callback) } }
        }
    }
    
    private func update(_ timeInfo: DisplayLinkCallbackTimeInfo, _ callback: PixelatedAnimator.PixelatedAnimatorCallback) {
        
        /// Get change in input value
        let x_ = subtractedVectors(x, x0)
        
        /// Get current step time
        let t = timeInfo.outFrame
        /// Get previous step time
        if t0 <= 0 { t0 = t - timeInfo.timeBetweenFrames }
        /// Get step delta
        let dt = t - t0
        
        /// Get new displacement
        let y = addedVectors(y0, scaledVector(y0_, dt))
        /// Get new acceleration
        let a1 = addedVectors(x, scaledVector(x_, k3))
        let a2 = addedVectors(y, scaledVector(y0_, k1))
        let y__ = scaledVector(subtractedVectors(a1, a2), 1/k2)
        /// Get new speed
        let y_ = addedVectors(y0_, scaledVector(y__, dt))
        
        /// Check end - based on distance to target & velocity
        var isEnd = (magnitudeOfVector(subtractedVectors(y, x)) <= epsilon && magnitudeOfVector(y_) <= epsilon)
        
        /// Get displacement delta
        var dy = subtractedVectors(y, y0)
        
        /// Subpixelate
        dy = pixelator.intVector(withDouble: dy)
        /// Check end again based on pixelation
        if !isEnd {
            let futureDy = pixelator.peekIntVector(withDouble: subtractedVectors(x, y))
            isEnd = isZeroVector(dy) && isZeroVector(futureDy)
        }
        
        /// Call callback
        if isEnd {
            callback(Vector(x: 0, y: 0), kMFAnimationCallbackPhaseEnd, kMFMomentumHintNone)
        } else if magnitudeOfVector(dy) > 0 {
            if isFirstCallback {
                callback(dy, kMFAnimationCallbackPhaseStart, kMFMomentumHintNone)
            } else {
                callback(dy, kMFAnimationCallbackPhaseContinue, kMFMomentumHintNone)
            }
        }
        
        /// Update globals
        t0 = t
        y0 = y
        y0_ = y_
        x0 = x
        isFirstCallback = false
        
        /// Stop
        if isEnd {
            stop_Unsafe()
        }
    }
    
    @objc func stop_Unsafe() {
        displayLink.stop_Unsafe()
        resetState()
    }
    
    @objc func stop() {
        queue.sync {
            stop_Unsafe()
        }
    }
    
    @objc func resetSubPixelator() {
        self.pixelator.reset()
    }
    @objc func linkToMainScreen() {
        self.displayLink.linkToMainScreen()
    }
    @objc func isRunning() -> Bool {
        return self.displayLink.isRunning()
    }
}
