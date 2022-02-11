//
// --------------------------------------------------------------------------
// VectorAnimator.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Foundation
import CocoaLumberjackSwift
import CoreVideo
import QuartzCore

@objc class VectorAnimator: NSObject {

    /// Typedef
    
    typealias UntypedAnimatorCallback = Any
    typealias AnimatorCallback = (_ animationValueDelta: Vector, _ animationTimeDelta: Double, _ phase: MFAnimationPhase) -> ()
    typealias StopCallback = (_ lastPhase: MFAnimationPhase) -> ()
    typealias StartParamCalculationCallback = (_ valueLeft: Vector, _ isRunning: Bool, _ animationCurve: AnimationCurve?) -> MFAnimatorStartParams
    /// ^ When starting the animator, we usually want to get the value that the animator still wants to scroll (`animationValueLeft`), and add that to the new value. The specific logic can differ a lot though, so we can't just hardcode this into `Animator`
    ///     But to avoid race-conditions, we can't just externally execute this, so we to pass in a callback that can execute custom logic to get the start params right before the animator is started
    typealias MFAnimatorStartParams = Dictionary<String, Any>
    /// ^ 4 keys: "doStart", "duration", "vector", "curve"
    
    /// Constants
    
    //    let lockingTimeout: Double = 0.02 /* (1.0/60.0 + 2.0/60.0) / 2.0 */
    ///     Idk if I'm crazy but if I make this EITHER larger OR smaller than 0.02 (I tried 0.01 and 0.03) then scrolling becomes stuttery?
    ///     Edit: I'm using (1/60 + 2/60) / 2 == 0.025 now, also seems to work fine. No idea what's going on. Edit2: 0.02 still works better. This is probably a big coincidence that I"m seeing a pattern in.
    
    /// Vars - Init
    
    let displayLink: DisplayLink
    @Atomic var callback: UntypedAnimatorCallback?
    /// ^ This is constantly accessed by subclassHook() and constantly written to by startWithUntypedCallback(). Becuase Swift is stinky and not thread safe, the app will sometimes crash, when this property is read from and written to at the same time. So we're using @Atomic propery wrapper
    @objc var animationCurve: AnimationCurve? /// This class assumes that `animationCurve` passes through `(0, 0)` and `(1, 1)
                                              //    let threadLock = DispatchSemaphore.init(value: 1)
                                              /// ^ Using a queue instead of a lock to avoid deadlocks. Always use queues for mutual exclusion except if you know exactly what you're doing!
    let animatorQueue: DispatchQueue
    
    /// Init
    
    @objc override init() {
        
        self.displayLink = DisplayLink()
        self.animatorQueue = DispatchQueue(label: "com.nuebling.mac-mouse-fix.animator", qos: .userInteractive , attributes: [], autoreleaseFrequency: .inherit, target: nil)
        
        super.init()
    }
    
    /// Vars - Start & stop
    
    var animationDuration: CFTimeInterval = 0
    var animationStartTime: CFTimeInterval = 0
    var animationEndTime: CFTimeInterval { animationStartTime + animationDuration }
    var animationTimeInterval: Interval { Interval(location: animationStartTime, length: animationDuration) }
    
    var animationValueTotal: Vector = Vector(x: 0, y: 0)
    var animationValueIntervalX: Interval { Interval(start: 0, end: animationValueTotal.x) }
    var animationValueIntervalY: Interval { Interval(start: 0, end: animationValueTotal.y) }
    
    @objc var isRunning: Bool {
        var result: Bool = false
        self.animatorQueue.sync {
            result = self.isRunning_Sync
        }
        return result
    }
    @objc var isRunning_Sync: Bool {
        /// ! Only use this instead of isRunning() if you know you're already executing on self.queue
        /// We always want isRunning to be executed on self.queue. But if we call self.queue.sync() when we're already on self queue, that is an error
        return self.displayLink.isRunning()
    }
    
    fileprivate var onStopCallback: (() -> ())?
    
    /// Vars - DisplayLink
    
    var lastFrameTime: Double = -1 /// Time at which the displayLink was last called
    var lastAnimationValue: Vector = Vector(x: 0, y: 0) /// animationValue when the displayLink was last called
    var lastAnimationPhase: MFAnimationPhase = kMFAnimationPhaseNone
    var animationPhase: MFAnimationPhase = kMFAnimationPhaseNone
    
    /// Vars -  Interface
    ///     Accessing these directly is not thread safe. Only access them from self.animatorQueue
    //      TODO: Make these private since they are not thread safe
    
    @objc var animationTimeLeft: Double {
        let result = animationEndTime - lastFrameTime
        return result
    }
    @objc var animationValueLeft: Vector {
        let result = subtractedVectors(animationValueTotal, lastAnimationValue)
        return result
    }
    
    /// Other Interface
    
    @objc func linkToMainScreen() {
        /// Exposing this as a function and not just doing it automatically when the animation starts because I assume it's slow. Not sure where this assumption comes from.
        
        displayLink.linkToMainScreen()
    }
    
    /// Start
    
    @objc func start(params: @escaping StartParamCalculationCallback,
                     callback: @escaping AnimatorCallback) {
        
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
            
            /// Reset lastAnimationValue
            ///     So we don't give the `params` callback old invalid animationValueLeft.
            ///     I think this is sort of redundant, because we're resetting animationValueLeft in `startWithUntypedCallback_Unsafe()` as well?
            
            let p: MFAnimatorStartParams = params(self.animationValueLeft, self.isRunning_Sync, self.animationCurve)
            
            self.lastAnimationValue = Vector(x: 0, y: 0)
            
            if let doStart = p["doStart"] as? Bool {
                if doStart == false {
                    return;
                }
            }
            self.startWithUntypedCallback_Unsafe(durationRaw: p["duration"] as! Double, value: vectorFromValue(p["vector"] as! NSValue), animationCurve: p["curve"] as! AnimationCurve, callback: callback);
        }
    }
    
    internal func startWithUntypedCallback_Unsafe(durationRaw: CFTimeInterval,
                                                  value: Vector,
                                                  animationCurve: AnimationCurve,
                                                  callback: UntypedAnimatorCallback) {
        
        /// This function has `_Unsafe` in it's name because it doesn't execute on self.animatorQueue. Only call it form self.animatorQueue
        
        /// Should only be called by this and subclasses
        /// The use of 'Interval' in CFTimeInterval is kind of confusing, since its also used to spedify points in time (It's just a `Double`), and also it has nothing to do with our `Interval` class, which is much closer to an Interval in the Mathematical sense.
        /// Will be restarted if it's already running. No need to call stop before calling this.
        /// It's kind of unnecessary to be passing this a value interval, because we only use the length of it. Since the AnimatorCallback only receives valueDeltas each frame and no absolute values,  the location of the value interval doesn't matter.
        /// We need to make `callback` and UntypedAnimatorCallback instead of a normal AnimatorCallback, so we can change the type of `callback` to PixelatedAnimatorCallback in the subclass PixelatedAnimator. That's because Swift is stinky. UntypedAnimatorCallback is @escaping
        
        
        /// Store args
        
        self.callback = callback;
        self.animationCurve = animationCurve
        
        /// Get stuff
        
        let isRunningg = self.isRunning_Sync
        
        /// Validate
        
        if isRunningg {
            switch self.animationPhase {
            case kMFAnimationPhaseStart, kMFAnimationPhaseContinue, kMFAnimationPhaseRunningStart:
                break
            case kMFAnimationPhaseEnd, kMFAnimationPhaseStartAndEnd, kMFAnimationPhaseNone:
                assert(false)
            default: /// This should never happen
                fatalError();
            }
        } else {
            switch self.animationPhase {
            case kMFAnimationPhaseEnd, kMFAnimationPhaseStartAndEnd, kMFAnimationPhaseNone:
                break
            case kMFAnimationPhaseStart, kMFAnimationPhaseContinue, kMFAnimationPhaseRunningStart:
                assert(false)
            default: /// This should never happen
                fatalError()
            }
        }
        
        /// Update phases
        
        if (!isRunningg
            || self.animationPhase == kMFAnimationPhaseStart
            || self.animationPhase == kMFAnimationPhaseStartAndEnd) {
            
            /// If animation phase is still start that means that the displayLinkCallback() hasn't been used it, yet (it sets it to continue after using it)
            ///     We want the first time that self.callback is called by displayLinkCallback() during the animation to have phase start, so we're not setting phase to running start in this case, even if the Animator is already running (when !isRunning is true)
            
            /// Regarding the kMFAnimationPhaseStartAndEnd check: This shouldn't be necessary, because we call self.stop() in the displayLinkCallback if phase is `startAndEnd`, which will make self.isRunning false. But due to some weird race condition or something, it doesn't always work. Edit: I added locks to this class to prevent the race conditions whcih should make this unnecessary
            // TODO: Remove the `startAndEnd` check.

            self.animationPhase = kMFAnimationPhaseStart;
            self.lastAnimationPhase = kMFAnimationPhaseNone;
            
        } else {
            self.animationPhase = kMFAnimationPhaseRunningStart;
        }
        
        /// Round duration to a multiple of timeBetweenFrames
        
        let duration = TransformationUtility.roundUp(durationRaw, toMultiple: displayLink.nominalTimeBetweenFrames())
        
        /// Update the rest of the state
        
        if (isRunningg) {
            
            self.animationStartTime = lastFrameTime
            self.animationDuration = duration
            self.animationValueTotal = value
            
        } else {
            
            /// animationStartTime will be set in the displayLinkCallback
            self.animationStartTime = -1
            self.animationDuration = duration
            self.animationValueTotal = value
            
            /// Start displayLink
            self.displayLink.start(callback: { [unowned self] (timeInfo: DisplayLinkCallbackTimeInfo) -> () in
                let s = self
                s.displayLinkCallback(timeInfo)
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
        
        /// Debug
        
//        DDLogDebug("AnimationValueInterval at start: \(value)")
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
        
        assert(self.isRunning_Sync)
        
        onStop_Internal(callback: callback, doImmediatelyIfNotRunning: false)
    }
    
    @objc func onStop(callback: @escaping () -> ()) {
        
        self.animatorQueue.async {
            self.onStop_Internal(callback: callback, doImmediatelyIfNotRunning: false)
        }
    }
    
    fileprivate func onStop_Internal(callback: @escaping () -> (), doImmediatelyIfNotRunning: Bool) {
        /// Do `callback` once the Animator stops or immediately if the animator isn't running and `waitTillNextStop` is false
        
        if (doImmediatelyIfNotRunning && !self.isRunning_Sync) {
            callback()
        } else {
            self.onStopCallback = callback
        }
    }
    
    /// DisplayLink callback
    /// This will be called whenever the display refreshes while the displayLink is running
    /// Its purpose is calling self.callback. Everything else it does is to figure out arguments for self.callback
    
    @objc func displayLinkCallback(_ timeInfo: DisplayLinkCallbackTimeInfo) {
        
        self.animatorQueue.sync { /// Use sync so this is actually executed on the high-priority display-linked thread
            
            /// Debug
            
            DDLogDebug("\nAnimation value total: (\(animationValueTotal.x), \(animationValueTotal.y)), left: (\(animationValueLeft.x), \(animationValueLeft.y))")
            
            
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
            
            /// Get time when frame will be displayed
            var frameTime = timeInfo.outFrame
            
            /// Set animation start time
            if animationPhase == kMFAnimationPhaseStart {
                /// ^ I don't think we have to check for lastAnimationPhase
                ///     to make sure this is the first callback?
                
                /// Pull time of last frame out of butt
                self.lastFrameTime = frameTime - timeInfo.nominalTimeBetweenFrames
                
                /// Set animation start time to hypothetical last frame
                self.animationStartTime = self.lastFrameTime
            }
            
            /// Check if animation time is up
            
            let closeEnoughToEndTime = abs(frameTime - self.animationEndTime) < abs(frameTime+timeInfo.timeBetweenFrames - self.animationEndTime)
            let pastEndTime = self.animationEndTime <= frameTime
            
            if closeEnoughToEndTime || pastEndTime {
                /// Animation is ending
                self.animationPhase = kMFAnimationPhaseEnd
                frameTime = self.animationEndTime /// So we scroll exactly animationValueTotal
            }
            
            /// Get normalized time
            
            let animationTimeUnit: Double = Math.scale(value: frameTime, from: self.animationTimeInterval, to: .unitInterval)
            
            /// Get normalized animation value from animation curve
            
            let animationValueUnit: Double = animationCurve.evaluate(at: animationTimeUnit)
            
            /// Get actual animation value
            
            var animationValue = Vector(x: 0, y: 0)
            
            if animationValueTotal.x != 0 {
                animationValue.x = Math.scale(value: animationValueUnit, from: .unitInterval, to: animationValueIntervalX)
            }
            if animationValueTotal.y != 0 {
                animationValue.y = Math.scale(value: animationValueUnit, from: .unitInterval, to: animationValueIntervalY)
            }
            
            /// Get change since last frame aka `delta`
            
            let animationTimeDelta: CFTimeInterval = frameTime - self.lastFrameTime
            let animationValueDelta: Vector = subtractedVectors(animationValue, lastAnimationValue)
            
            /// Subclass hook.
            ///     PixelatedAnimator overrides this to do its thing
            
            self.subclassHook(callback, animationValueDelta, animationTimeDelta)
            
            /// Update `last` time and value and phase
            ///     \note  Should lastPhase be updated right after the callback is called? Experimentally moved it there. Move back if that breaks things
            ///         Edit: I checked and atm we only use lastAnimationPhase to set the startAndEnd phase. For that it shouldn't make a difference. But I do think it makes more sense to update it right after `callback` is called in general
            
            self.lastFrameTime = frameTime
            self.lastAnimationValue = animationValue
            
            /// Stop animation if phase is   `end`
            /// TODO: Why don't we use a defer statement to execute this like in the start functions?
            
            switch self.animationPhase {
            case kMFAnimationPhaseEnd, kMFAnimationPhaseStartAndEnd:
                
                self.stop_FromDisplayLinkedThread()
                
            default:
                break
                
            }
        }
    }
    
    /// Subclass overridable
    
    func subclassHook(_ untypedCallback: Any, _ animationValueDelta: Vector, _ animationTimeDelta: CFTimeInterval) {
        
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
        
        /// Debug
        
        DDLogDebug("BaseAnimator callback - delta: \(animationValueDelta)")
        
        /// Update `last` time and value and phase
        
        self.lastAnimationPhase = self.animationPhase
        
        /// Update phase to `continue` if phase is `start`
        ///     This has a copy in superclass. Update that it when you change this.
        
        switch self.animationPhase {
        case kMFAnimationPhaseStart, kMFAnimationPhaseRunningStart: self.animationPhase = kMFAnimationPhaseContinue
            default: break }
    }
    
    /// Helper functions
        
}

