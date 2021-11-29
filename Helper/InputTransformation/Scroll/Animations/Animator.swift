//
// --------------------------------------------------------------------------
// Animator.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation
import CocoaLumberjackSwift

@objc protocol Animator {
    
    typealias UntypedAnimatorCallback = Any
    typealias AnimatorCallback = (_ animationValueDelta: Double, _ animationTimeDelta: Double, _ phase: MFAnimationPhase) -> ()
    typealias PixelatedAnimatorCallback =
    (_ integerAnimationValueDelta: Int, _ animationTimeDelta: Double, _ phase: MFAnimationPhase) -> ()
    typealias StopCallback = (_ lastPhase: MFAnimationPhase) -> ()
    
    @objc var animationTimeLeft: Double { get }
    @objc var animationValueLeft: Double { get }
    
    @objc func start(duration: CFTimeInterval,
                     valueInterval: Interval,
                     animationCurve: AnimationCurve,
                     callback: @escaping AnimatorCallback)
    
    
}

@objc class BaseAnimator: NSObject, Animator {
    

    // Vars - Init
    
    let displayLink: DisplayLink
    @Atomic var callback: UntypedAnimatorCallback?
    /// ^ This is constantly accessed by subclassHook() and constantly written to by startWithUntypedCallback(). Becuase Swift is stinky and not thread safe, the app will sometimes crash, when this property is read from and written to at the same time. So we're using @Atomic propery wrapper
    var animationCurve: AnimationCurve? /// This class assumes that `animationCurve` passes through `(0, 0)` and `(1, 1)
    let threadLock = DispatchSemaphore.init(value: 1)
    
    // Init
    
    @objc override init() {
        
        self.displayLink = DisplayLink()
        
        super.init()
    }
    
    // Vars - Start & stop
    
    var animationTimeInterval: Interval = .unitInterval /// Just initing so Swift doesn't complain. This value is unused
    var animationValueInterval: Interval = .unitInterval
    
    @objc var isRunning: Bool {
        self.displayLink.isRunning()
    }
    
    // Vars - DisplayLink
    
    var lastAnimationTime: Double = -1 /// Time at which the displayLink was last called
    var lastAnimationValue: Double = -1 /// animationValue when the displayLink was last called
    var lastAnimationPhase: MFAnimationPhase = kMFAnimationPhaseNone
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
                     animationCurve: AnimationCurve,
                     callback: @escaping AnimatorCallback) {
        
        self.startWithUntypedCallback(duration: duration, valueInterval: valueInterval, animationCurve: animationCurve, callback: callback);
    }
    
    @objc internal func startWithUntypedCallback(duration: CFTimeInterval,
                                                 valueInterval: Interval,
                                                 animationCurve: AnimationCurve,
                                                 callback: UntypedAnimatorCallback) {
        
        /// Should only be called by this and subclasses
        /// The use of 'Interval' in CFTimeInterval is kind of confusing, since its also used to spedify points in time (It's just a `Double`), and also it has nothing to do with our `Interval` class, which is much closer to an Interval in the Mathematical sense.
        /// Will be restarted if it's already running. No need to call stop before calling this.
        /// It's kind of unnecessary to be passing this a value interval, because we only use the length of it. Since the AnimatorCallback only receives valueDeltas each frame and no absolute values,  the location of the value interval doesn't matter.
        /// We need to make `callback` and UntypedAnimatorCallback instead of a normal AnimatorCallback, so we can change the type of `callback` to PixelatedAnimatorCallback in the subclass PixelatedAnimator. That's because Swift is stinky. UntypedAnimatorCallback is @escaping
        
        /// Lock
        ///     Otherwise there will be race conditions with this function and the displayLinkCallback() both manipulating the animationPhase (and I think other values, too) at the same time.
        ///     Generally queues are advised over locks, but since the docs of CVDisplayLink say the displayLinkCallback is executed on a special high-priority thread, I thought it might be better to use a thread lock instead of a dispatchQueue,
        ///         so we ensure that the displayLinkCallback really is executing on that high-priority thread.
        ///     To be exact, we're using a semaphore not a thread lock but it works the exact same
        
        defer {
            self.threadLock.signal()
        }
        let timeOutResult = self.threadLock.wait(timeout: DispatchTime.now() + 0.02)

        assert(timeOutResult == DispatchTimeoutResult.success)
        
        /// Store args
        
        self.callback = callback;
        self.animationCurve = animationCurve
        
        /// Update phases
        
        if (!self.isRunning
            || self.animationPhase == kMFAnimationPhaseStart
            || self.animationPhase == kMFAnimationPhaseStartAndEnd) { /// This shouldn't be necessary, because we call self.stop() in the displayLinkCallback if phase is `startAndEnd`, which will make self.isRunning false. But due to some weird race condition or something, it doesn't always work. Edit: I added locks to this class to prevent the race conditions whcih should make this unnecessary - Remove the `startAndEnd` check.
            /// If animation phase is still start that means that the displayLinkCallback() hasn't used it, yet (it sets it to continue after using it)
            ///     We want the first time that selfcallback is called by displayLinkCallback() during the animation to have phase start, so we're not setting phase to running start in this case, even if the Animator is already running (when !isRunning is true)
            
            animationPhase = kMFAnimationPhaseStart;
            lastAnimationPhase = kMFAnimationPhaseNone;
        } else {
            animationPhase = kMFAnimationPhaseRunningStart;
        }
        
        /// Debug
        
        DDLogDebug("START ANIMATOR \(self.hash) with phase: \(animationPhase.rawValue)")
        
        /// Update the rest of the state
        
        if (isRunning) {
            /// I think it should make for smoother animations, if we don't se the lastAnimationTime to now when the displayLink is already running, but that's an experiment. I'm not sure. Edit: Not sure if it makes a difference but it's fine
            
            lastAnimationValue = animationValueInterval.start
            
            self.animationTimeInterval = Interval.init(location: lastAnimationTime, length: duration)
            self.animationValueInterval = valueInterval
            
        } else {
            
            let now: CFTimeInterval = CACurrentMediaTime()
            
            lastAnimationTime = now
            lastAnimationValue = animationValueInterval.start
            
            self.animationTimeInterval = Interval.init(location: now, length: duration)
            self.animationValueInterval = valueInterval
            
            /// Start displayLink
            self.displayLink.start(callback: { [unowned self] () -> () in
                let s = self
                s.displayLinkCallback()
                /**
                 - `displayLinkCallback()` gives EXC_BAD_ACCESS once a minute when scrolling. How is that even possible? It's just a function. Debugger says that everything else is available on self, just not this function. Maybe it's because it's not marked @objc?
                    - Edit: Marking it @objc weirdly fixes the issue. Edit2: Nope, now it appeared again.
                 - SO about a similar problem: https://stackoverflow.com/questions/14744378/arc-exc-bad-access-when-calling-a-method-from-inside-a-block-inside-a-delegate
                 - I think the reason might be that we were storing the block in `DisplayLink.m` with `_callback = callback` instead of `self.callback = callback`. That might prevent the block from being copied which blocks should normally be when stored as properties or something. See:
                    - https://www.google.com/search?client=safari&rls=en&q=objc+copy+property&ie=UTF-8&oe=UTF-8
                    - Actually, using `self.callback` shouldn't make a difference. See:
                        - https://stackoverflow.com/questions/10453261/under-arc-are-blocks-automatically-copied-when-assigned-to-an-ivar-directly
                        - But it seems to work so far.
                 */
            })
        }
    }
    
    /// Stop
    
    @objc func stop() {
        
        /// Lock
        
        let timeOutResult = self.threadLock.wait(timeout: DispatchTime.now() + 0.02)
        defer {
            self.threadLock.signal()
        }

        assert(timeOutResult == DispatchTimeoutResult.success)
        
        /// Debug
        
        DDLogDebug("STOPPING ANIMATOR")
        
        /// Do stuff
        
        displayLink.stop()
        animationPhase = kMFAnimationPhaseNone
    }
    
    /// DisplayLink callback
    /// This will be called whenever the display refreshes while the displayLink is running
    /// Its purpose is calling self.callback. Everything else it does is to figure out arguments for self.callback
    
    @objc func displayLinkCallback() {
        /// I'm usually a fan of commenting even obvious things, to structure the code and make it easier to parse, but this is overkill. I think the comments make it less readable
        
        /// Lock
    
        let lockingTimeout = 0.02
        let threadLockingTimeOutResult = self.threadLock.wait(timeout: DispatchTime.now() + lockingTimeout)
        if threadLockingTimeOutResult == DispatchTimeoutResult.timedOut {
            DDLogWarn("It took longer than \(lockingTimeout) seconds to acquire the threadLock in displayLinkCallback()")
        }
        
        /// Debug
        
//        DDLogDebug("DO DISP LINK with (initial) phase: \(self.animationPhase.rawValue)")
        
        /// Guard nil
        
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
        
        /// Get normalized time
        
        let animationTimeUnit: Double = Math.scale(value: now, from: animationTimeInterval, to: .unitInterval) /// From 0 to 1
        
        /// Get normalized animation value from animation curve
        
        let animationValueUnit: Double = animationCurve.evaluate(at: animationTimeUnit) /// From 0 to 1
        
        /// Get actual animation value
        
        let animationValue: Double = Math.scale(value: animationValueUnit, from: .unitInterval, to: animationValueInterval)
        
        /// Get change since last frame aka `delta`
        
        let animationTimeDelta: CFTimeInterval = now - lastAnimationTime
        let animationValueDelta: Double = animationValue - lastAnimationValue
        
        /// Subclass hook.
        ///     PixelatedAnimator overrides this to do its thing
        
        subclassHook(callback, animationValueDelta, animationTimeDelta)
        
        /// Update `last` time and value and phase
        
        self.lastAnimationTime = now
        self.lastAnimationValue = animationValue
        self.lastAnimationPhase = self.animationPhase
        
        /// Stop animation if phase is   `end`
        /// TODO: Why don't we use a defer statement to execute this like in the start functions?
        
        switch self.animationPhase {
        case kMFAnimationPhaseEnd, kMFAnimationPhaseStartAndEnd:
            
            /// Need to make sure that this functions' threadLock has been released before we call self.stop(). self.stop() will try to acquire the lock,  leading to a deadlock if this function still holds the lock.
            ///     If we unlock the thread before the enclosing switch statement there'll still be race conditions (I think - limited testing)
            self.threadLock.signal()
            self.stop()
            
        default:
            /// Unlock
            ///     Make you don't accidentally return from this function prematurely, such that the lock isn't released
            self.threadLock.signal()
        }
    }
    
    /// Subclass overridable
    
    func subclassHook(_ untypedCallback: Any, _ animationValueDelta: Double, _ animationTimeDelta: CFTimeInterval) {
        
        /// Guard callback type
        
        guard let callback = untypedCallback as? AnimatorCallback else {
            fatalError("Invalid state - callback is not type AnimatorCallback")
        }
        
        /// Update phase to `startAndEnd` if appropriate
        ///     -> Check if this event was first _and_  last event of animation
        ///     This has a copy in superclass. Update that it when you change this.
        ///     We want to do this after all other changes to the animationPhase and before the callback() call. Since the PixelatedAnimator subclassHook() changes the animationPhase before it calls the callback(), we need a copy of the below code in both subclassHooks()
        ///     This duplicated code make things pretty confusing but, to avoid it we'd have to create like 3 different subclassHooks, which would be even more confusing.
        
        if (animationPhase == kMFAnimationPhaseEnd /// This is last event of the animation
                && lastAnimationPhase == kMFAnimationPhaseNone) { /// This is also the first event of the animation
            animationPhase = kMFAnimationPhaseStartAndEnd;
        }
        
        /// Call the callback
        
        callback(animationValueDelta, animationTimeDelta, animationPhase)
        
        /// Update phase to `continue` if phase is `start`
        ///     This has a copy in superclass. Update that it when you change this.
        
        switch self.animationPhase {
        case kMFAnimationPhaseStart, kMFAnimationPhaseRunningStart: self.animationPhase = kMFAnimationPhaseContinue
        default: break }
    }
    
    /// Helper functions
    
    func phaseIsEndingPhase() -> Bool {
        switch self.animationPhase {
        case kMFAnimationPhaseEnd, kMFAnimationPhaseStartAndEnd:
            return true
        default:
            return false
        }
    }
    
}
