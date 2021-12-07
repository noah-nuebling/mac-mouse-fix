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
    
    // TODO: I don't think this is needed. Remove
    
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
    
    // Constants
    
//    let lockingTimeout: Double = 0.02 /* (1.0/60.0 + 2.0/60.0) / 2.0 */
    ///     Idk if I'm crazy but if I make this EITHER larger OR smaller than 0.02 (I tried 0.01 and 0.03) then scrolling becomes stuttery?
    ///     Edit: I'm using (1/60 + 2/60) / 2 == 0.025 now, also seems to work fine. No idea what's going on. Edit2: 0.02 still works better. This is probably a big coincidence that I"m seeing a pattern in.
    
    // Vars - Init
    
    let displayLink: DisplayLink
    @Atomic var callback: UntypedAnimatorCallback?
    /// ^ This is constantly accessed by subclassHook() and constantly written to by startWithUntypedCallback(). Becuase Swift is stinky and not thread safe, the app will sometimes crash, when this property is read from and written to at the same time. So we're using @Atomic propery wrapper
    @objc var animationCurve: AnimationCurve? /// This class assumes that `animationCurve` passes through `(0, 0)` and `(1, 1)
//    let threadLock = DispatchSemaphore.init(value: 1)
        /// ^ Using a queue instead of a lock to avoid deadlocks. Always use queues for mutual exclusion except if you know exactly what you're doing!
    let animatorQueue: DispatchQueue
    
    // Init
    
    @objc override init() {
        
        self.displayLink = DisplayLink()
        self.animatorQueue = DispatchQueue(label: "com.nuebling.mac-mouse-fix.animator", qos: .userInteractive , attributes: [], autoreleaseFrequency: .inherit, target: nil)
        
        super.init()
    }
    
    // Vars - Start & stop
    
    var animationTimeInterval: Interval = .unitInterval /// Just initing so Swift doesn't complain. This value is unused
    var animationValueInterval: Interval = .unitInterval
    
    @objc var isRunning: Bool {
        var result: Bool = false
        self.animatorQueue.sync {
            result = self.isRunning_Internal
        }
        return result
    }
    @objc fileprivate var isRunning_Internal: Bool {
        /// We always want isRunning to be executed on self.queue. But if we call self.queue.sync() when we're already on self queue, that is an error
        ///     So use this functtion instead of isRunning() if you know you're already executing on self.queue
        return self.displayLink.isRunning()
    }
    
    fileprivate var onStopCallback: (() -> ())?
    
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
    
    internal func startWithUntypedCallback(duration: CFTimeInterval,
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
        /// Edit: We've since moved to using a dispatchQueue instead of a muctex lock. This should prevent many potential deadlock issues and be faster and the function is also asynchronous now, which I hope is a good thing
        
        /// Dispatch to queue
        ///     Dispatching sync, so that calling self.start() and then right after calling self.isRunning()  actually works....
        ///         Orrr we can also have self.isRunning() execute on self.queue. - we did that. Should be most robust solution
        ///         But actually, maybe it's faster to make start() use queue.sync after all. Because isRunning() is probably called a lot more.
        
        self.animatorQueue.async {
            self.startWithUntypedCallback_Unsafe(duration: duration, valueInterval: valueInterval, animationCurve: animationCurve, callback: callback)
        }
    }
    
    internal func startWithUntypedCallback_Unsafe(duration: CFTimeInterval,
                                                valueInterval: Interval,
                                                animationCurve: AnimationCurve,
                                                callback: UntypedAnimatorCallback) {
        
        /// This function has `_Unsafe` in it's name because it doesn't execute on self.animatorQueue. Only call it form self.animatorQueue
        
        /// Store args
        
        self.callback = callback;
        self.animationCurve = animationCurve
        
        /// Update phases
        
        if (!self.isRunning_Internal
            || self.animationPhase == kMFAnimationPhaseStart
            || self.animationPhase == kMFAnimationPhaseStartAndEnd) { /// This shouldn't be necessary, because we call self.stop() in the displayLinkCallback if phase is `startAndEnd`, which will make self.isRunning false. But due to some weird race condition or something, it doesn't always work. Edit: I added locks to this class to prevent the race conditions whcih should make this unnecessary - Remove the `startAndEnd` check.
                                                                      /// If animation phase is still start that means that the displayLinkCallback() hasn't used it, yet (it sets it to continue after using it)
                                                                      ///     We want the first time that selfcallback is called by displayLinkCallback() during the animation to have phase start, so we're not setting phase to running start in this case, even if the Animator is already running (when !isRunning is true)
            
            self.animationPhase = kMFAnimationPhaseStart;
            self.lastAnimationPhase = kMFAnimationPhaseNone;
        } else {
            self.animationPhase = kMFAnimationPhaseRunningStart;
        }
        
        /// Debug
        
        DDLogDebug("START ANIMATOR \(self.hash) with phase: \(self.animationPhase.rawValue)")
        
        /// Update the rest of the state
        
        if (self.isRunning_Internal) {
            /// I think it should make for smoother animations, if we don't se the lastAnimationTime to now when the displayLink is already running, but that's an experiment. I'm not sure. Edit: Not sure if it makes a difference but it's fine
            
            self.lastAnimationValue = self.animationValueInterval.start
            
            self.animationTimeInterval = Interval.init(location: self.lastAnimationTime, length: duration)
            self.animationValueInterval = valueInterval
            
            //                threadLock.signal()
            
        } else {
            
            let now: CFTimeInterval = CACurrentMediaTime()
            
            self.lastAnimationTime = now
            self.lastAnimationValue = self.animationValueInterval.start
            
            self.animationTimeInterval = Interval.init(location: now, length: duration)
            self.animationValueInterval = valueInterval
            
            //                threadLock.signal()
            
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
        self.animatorQueue.async {
            self.stop_Internal(fromDisplayLink: false)
        }
    }
    
    fileprivate func stop_FromDisplayLinkedThread() {
        /// Only call this when you're already running on the displayLinkCallback
        
        self.stop_Internal(fromDisplayLink: true)
    }
    
    fileprivate func stop_Internal(fromDisplayLink: Bool) {
        /// Don't call this directly, use `stop()` or `stop_FromDisplayLinkedThread()`
        
        /// Debug
        
        DDLogDebug("STOPPING ANIMATOR")
        
        /// Do stuff
        
        if (fromDisplayLink) {
            self.displayLink.stop()
        } else {
            self.displayLink.stop()
        }
        self.animationPhase = kMFAnimationPhaseNone
        if self.onStopCallback != nil {
            self.onStopCallback!()
            self.onStopCallback = nil
            
        }
    }
            
    @objc func onStop_SynchronouslyFromAnimationQueue(callback: @escaping () -> ()) {
        /// The default `onStop(callback:)` dispatches to self.queue asynchronously.
        /// It can be used from self.queue, but, if used from self.queue, the callback will only become active after all the other items in the queue are finished, which is not always what we want.
        /// Use this function to synchronously install the onStop callback.
        /// This function should only be called from self.queue
        
        assert(self.isRunning_Internal)
        
        onStop_Internal(callback: callback, doImmediatelyIfNotRunning: false)
    }
    
    @objc func onStop(callback: @escaping () -> ()) {
        
        self.animatorQueue.async {
            self.onStop_Internal(callback: callback, doImmediatelyIfNotRunning: false)
        }
    }
    
    fileprivate func onStop_Internal(callback: @escaping () -> (), doImmediatelyIfNotRunning: Bool) {
        /// Do `callback` once the Animator stops or immediately if the animator isn't running and `waitTillNextStop` is false
        
        if (doImmediatelyIfNotRunning && !self.isRunning_Internal) {
            callback()
        } else {
            self.onStopCallback = callback
        }
    }
    
    /// DisplayLink callback
    /// This will be called whenever the display refreshes while the displayLink is running
    /// Its purpose is calling self.callback. Everything else it does is to figure out arguments for self.callback
    
    @objc func displayLinkCallback() {
        /// I'm usually a fan of commenting even obvious things, to structure the code and make it easier to parse, but this is overkill. I think the comments make it less readable
        
        /// Lock
    
//        var timeoutResult: DispatchTimeoutResult = .timedOut
//        while (timeoutResult == .timedOut) {
//            timeoutResult = self.threadLock.wait(timeout: .now() + self.lockingTimeout)
//            if (timeoutResult == .timedOut) {
//                DDLogWarn("Timed out while trying to acquire lock to do displayLinkCallback.")
//            }
//        }
//        assert(timeoutResult == .success)
        
        self.animatorQueue.sync { /// Use sync so this is actually executed on the high-priority display-linked thread
            
            /// Debug
            
            DDLogDebug("DO ANIMATOR DISP LINK CALLBACK with (initial) phase: \(self.animationPhase.rawValue)")
            
            /// Guard stopped
            
            if (self.animationPhase == kMFAnimationPhaseNone) {
                DDLogWarn("Animator displayLinkCallback called after it has been stopped")
                return;
            }
            
            /// Guard nil
            
            guard let callback = self.callback else {
                fatalError("Invalid state - callback can't be nil during running animation")
            }
            guard let animationCurve = self.animationCurve else {
                fatalError("Invalid state - animationCurve can't be nil during running animation")
            }
            
            /// Get current animation time aka `now`
            
            var now: CFTimeInterval = CACurrentMediaTime() /// Should maybe rename this to `animationTime`. It's not necessarily now when it's used.
            
            if now >= self.animationTimeInterval.end {
                /// Animation is ending
                self.animationPhase = kMFAnimationPhaseEnd
                now = self.animationTimeInterval.end /// Set now back to a valid value so we don't scroll too far and our scale functions don't throw errors
            }
            
            /// Get normalized time
            
            let animationTimeUnit: Double = Math.scale(value: now, from: self.animationTimeInterval, to: .unitInterval) /// From 0 to 1
            
            /// Get normalized animation value from animation curve
            
            let animationValueUnit: Double = animationCurve.evaluate(at: animationTimeUnit) /// From 0 to 1
            
            /// Get actual animation value
            
            let animationValue: Double = Math.scale(value: animationValueUnit, from: .unitInterval, to: self.animationValueInterval)
            
            /// Get change since last frame aka `delta`
            
            let animationTimeDelta: CFTimeInterval = now - self.lastAnimationTime
            let animationValueDelta: Double = animationValue - self.lastAnimationValue
            
            /// Subclass hook.
            ///     PixelatedAnimator overrides this to do its thing
            
            self.subclassHook(callback, animationValueDelta, animationTimeDelta)
            
            /// Update `last` time and value and phase
            ///     \note  Should lastPhase be updated right after the callback is called? Experimentally moved it there. Move back if that breaks things
            ///         Edit: I checked and atm we only use lastAnimationPhase to set the startAndEnd phase. For that it shouldn't make a difference. But I do think it makes more sense to update it right after `callback` is called in general
            
            self.lastAnimationTime = now
            self.lastAnimationValue = animationValue
//            self.lastAnimationPhase = self.animationPhase
            
            /// Stop animation if phase is   `end`
            /// TODO: Why don't we use a defer statement to execute this like in the start functions?
            
            switch self.animationPhase {
            case kMFAnimationPhaseEnd, kMFAnimationPhaseStartAndEnd:
                
                self.stop_FromDisplayLinkedThread()
                
            default:
                /// Unlock
                ///     Make you don't accidentally return from this function prematurely, such that the lock isn't released
//                self.threadLock.signal()
                break
                
            }
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
        
        /// Update `last` time and value and phase
        
        self.lastAnimationPhase = self.animationPhase
        
        /// Update phase to `continue` if phase is `start`
        ///     This has a copy in superclass. Update that it when you change this.
        
        switch self.animationPhase {
        case kMFAnimationPhaseStart, kMFAnimationPhaseRunningStart: self.animationPhase = kMFAnimationPhaseContinue
        default: break }
    }
    
    /// Helper functions
    
//    func phaseIsEndingPhase() -> Bool {
//        switch self.animationPhase {
//        case kMFAnimationPhaseEnd, kMFAnimationPhaseStartAndEnd:
//            return true
//        default:
//            return false
//        }
//    }
    
}
