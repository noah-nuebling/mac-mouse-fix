//
// --------------------------------------------------------------------------
// DynamicSystemAnimator.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// This was originally planned as a TouchAnimator which drivers touch events and provides gesture phase infromation. But that's too hard to implement and we don't need it.
///     Now it's just a simple Animator meant to drive UI animations.
/// Basically does the same thing as CASpringAnimation. But under Ventura Beta, CASpringAnimation doesn't work anymore for animating window size.
/// So we're using this instead

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
///         TODO: Make stable (see t3ssel8r video)

import Foundation

@objc class DynamicSystemAnimator: NSObject {
    
    /// Types
    
    typealias UIAnimatorCallback = (_ value: Double) -> ()
    
    /// Storage
    
    let displayLink: DisplayLink
    let queue: DispatchQueue
    var stopCallback: (() -> ())?
    
    /// Params
    
    let k: Double
    let c: Double
    let m: Double
    
    let epsilon: Double
    
    /// State
    var target: Double
    var x0: Double /// Last displacement
    var x0_: Double /// Last velocity
    var x0__: Double /// Last acceleration
    var t0: CFTimeInterval /// Last step time
    
    var isFirstCallback: Bool
    
    var pixelator: VectorSubPixelator
    
    /// Initializers
    
    @objc convenience init(fromAnimation animation: CASpringAnimation, stopTolerance: Double) {
        
        let k = animation.stiffness
        let c = animation.damping
        let m = animation.mass
        
        self.init(stiffness: k, damping: c, mass: m, stopTolerance: stopTolerance)
    }
    
    @objc required init(stiffness k: Double, damping c: Double, mass m: Double, stopTolerance: Double) {
        /// Validate
        assert(stopTolerance > 0, "Will never stop if stopTolerance <= 0")
        /// Constants
        self.k = k
        self.c = c
        self.m = m
        epsilon = stopTolerance
        displayLink = DisplayLink()
        queue = displayLink.dispatchQueue
        pixelator = VectorSubPixelator.biased()
        stopCallback = nil
        /// State
        target = 0
        x0 = 0
        x0_ = 0
        x0__ = 0
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
            self.target = 0
            self.x0 = 0
            self.x0_ = 0
            self.x0__ = 0
            self.t0 = 0
            self.isFirstCallback = false
            self.pixelator.reset()
        }
    }
    
    @objc func start(distance: Double, callback: @escaping UIAnimatorCallback) {
        
        queue.async {
            
            /// Normalize displacement
            ///     So the values don't grow to infinity and overflow
            self.x0 += distance
            self.target = self.x0 /// x will go from target to 0
            
            /// Update state
            self.isFirstCallback = true
            
            /// Configure displayLink
            ///     I feel like this somehow makes the animation more stuttery?
//            self.displayLink.linkToMainScreen_Unsafe()
            
            /// Start displayLink
            self.displayLink.start_Unsafe { timeInfo in
                self.update(timeInfo, callback)
            }
        }
    }
    
    private func update(_ timeInfo: DisplayLinkCallbackTimeInfo, _ callback: UIAnimatorCallback) {
        
        /// Get current step time
        let t = timeInfo.outFrame
        /// Get previous step time
        if t0 <= 0 { t0 = t - timeInfo.timeBetweenFrames }
        /// Get step delta
        let dt = t - t0
  
        /// Update
        
        /// Euler
        ///     Formula from https://en.wikipedia.org/wiki/Semi-implicit_Euler_method, expanded a little so we can use `x_` instead of `x0_`when calculating x
        ///     This feels weird and too slow
//        let x__ =   -(c*x0_ + k*x0)/m
//        let x_  =   x0_ + dt * x__
//        let x   =   x0 + dt * (c*x_ + k*x0 + m*x0__ + c*x_)/c
        
        /// Heuristic
        let x__ =   -(c*x0_ + k*x0)/m
        let x_  =   x0_ + dt * x__
        let x   =   x0 + dt * x_
        
        /// Check end - based on distance to target & velocity
        let isEnd = x <= epsilon && x_ <= epsilon
        
        /// Call callback
        callback(target - x) /// Becaues x actually goes from target to 0
        
        /// Update globals
        t0 = t
        x0 = x
        x0_ = x_
        x0__ = x__
        isFirstCallback = false
        
        /// Stop
        if isEnd {
            stop_Unsafe()
            stopCallback?()
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
    
    //  MARK: Old stuff
    
//    @objc convenience init(speed f: Double, damping z: Double, initialResponser r: Double, stopTolerance: Double) {
//        /// This is the formula from the t3ssel8r video!
//        /// Edit: We've switched from the t3ssel8r implementation, because we want to emulate CASpringAnimation as closely as possible.
//        /// Damping >= 1 turns off vibrations
//        /// I'm pretty sure intitialResponse == 1 turns it off?
//
//        let c = z / (.pi * f)
//        let m = 1 / pow(2 * .pi * f, 2)
//        let k = (r * z) / (2 * .pi * f)
//
//        self.init(c: c, m: m, k: k, stopTolerance: stopTolerance)
//    }
}
