//
// --------------------------------------------------------------------------
// TouchAnimatorBase.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Don't use this directly. Use the subclass `TouchAnimator` For discussion see `TouchAnimator`.

import Foundation
import CoreVideo
import QuartzCore

@objc class TouchAnimatorBase: NSObject {
    
    /// Typedef
    
    typealias UntypedAnimatorCallback = Any
    typealias AnimatorCallback = (_ animationValueDelta: Vector, _ phase: MFAnimationCallbackPhase, _ subCurve: MFMomentumHint) -> ()
//    typealias StopCallback = (_ lastPhase: MFAnimationPhase) -> ()
    typealias StartParamCalculationCallback = (_ valueLeft: Vector, _ isRunning: Bool, _ animationCurve: Curve?, _ currentSpeed: Vector) -> MFAnimatorStartParams
    /// ^ When starting the animator, we usually want to get the value that the animator still wants to scroll (`animationValueLeft`), and add that to the new value. The specific logic can differ a lot though, so we can't just hardcode this into `Animator`
    ///     But to avoid race-conditions, we can't just externally execute this, so we to pass in a callback that can execute custom logic to get the start params right before the animator is started
    typealias MFAnimatorStartParams = NSDictionary ///`Dictionary<String, Any>` `<-` Using Swift dict was slow for interop with ObjC due to autobridging
    /// ^ 4 keys: "doStart", "duration", "vector", "curve"
    ///     I tried moving this to a custom dataStorage class instead of a dict for optimization, but that somehow made things even slower. Maybe I did it wrong. See commit d64517dd0f7e7cddf46b305c354665c2d3223888
    
    /// Conversion
    
    @objc static func callbackPhase(hasProducedDeltas: Bool, isLastCallback: Bool) -> MFAnimationCallbackPhase {
        
        assert(!(!hasProducedDeltas && isLastCallback))
        
        if isLastCallback {
            return kMFAnimationCallbackPhaseEnd
        } else if !hasProducedDeltas {
            return kMFAnimationCallbackPhaseStart
        } else {
            return kMFAnimationCallbackPhaseContinue
        }
        
    }
    
    @objc static func IOHIDPhase(animationCallbackPhase: MFAnimationCallbackPhase) -> IOHIDEventPhaseBits {
        
        switch animationCallbackPhase {
            
        case kMFAnimationCallbackPhaseStart:
            return IOHIDEventPhaseBits(kIOHIDEventPhaseBegan)
        case kMFAnimationCallbackPhaseContinue:
            return IOHIDEventPhaseBits(kIOHIDEventPhaseChanged)
        case kMFAnimationCallbackPhaseEnd:
            return IOHIDEventPhaseBits(kIOHIDEventPhaseEnded)
        case kMFAnimationCallbackPhaseCanceled:
            return IOHIDEventPhaseBits(kIOHIDEventPhaseCancelled)
        default:
            fatalError()
        }
    }
    
    /// Constants
    
    let maxAnimationDuration = 1.5 /*5.0*/ /// Explanation below. TODO: Move this into ScrollConfig.
    
    /// Vars - Init
    
    @objc let displayLink: DisplayLink
    /*@Atomic*/ var clientCallback: UntypedAnimatorCallback?
    /// ^ This is constantly accessed by subclassHook() and constantly written to by startWithUntypedCallback(). Becuase Swift is stinky and not thread safe, the app will sometimes crash, when this property is read from and written to at the same time. So we're using @Atomic propery wrapper
    ///  Edit: Atomic makes writing to this super slow we're locking everything with displayLink.queue now so it shouldn't be necessary. Disabling @Atomc now.
    
    @objc var animationCurve: Curve? /// This class assumes that `animationCurve` passes through `(0, 0)` and `(1, 1)
    
//    let threadLock = DispatchSemaphore.init(value: 1)
    /// ^ Using a queue instead of a lock to avoid deadlocks. Always use queues for mutual exclusion except if you know exactly what you're doing!
//    let animatorQueue: DispatchQueue /// Use the displayLink's queue instead to avoid deadlocks and such
    
    /// Init
    
    @objc override init() {
        
        self.displayLink = DisplayLink(optimizedFor: kMFDisplayLinkWorkTypeEventSending /*kMFDisplayLinkWorkTypeGraphicsRendering*/)
//        self.animatorQueue = DispatchQueue(label: "com.nuebling.mac-mouse-fix.animator", qos: .userInteractive , attributes: [], autoreleaseFrequency: .inherit, target: nil)
        
        super.init()
    }
    
    /// Vars - Start & stop
    
    var animationDurationRaw: CFTimeInterval? = 0
    var animationDurationRawInFrames: Int? = 0
    var animationDuration: CFTimeInterval = 0
    var animationStartTime: CFTimeInterval = 0
    var animationEndTime: CFTimeInterval { animationStartTime + animationDuration }
    var animationTimeInterval: Interval {
        assert(animationStartTime > 0 && animationDuration > 0) /// Debug
        return Interval(location: animationStartTime, length: animationDuration)
    }
    
    var animationValueTotal: Vector = Vector(x: 0, y: 0)
    var animationValueIntervalX: Interval { Interval(start: 0, end: animationValueTotal.x) }
    var animationValueIntervalY: Interval { Interval(start: 0, end: animationValueTotal.y) }
    
    @objc var isRunning: Bool {
        return displayLink.isRunning()
    }
    @objc var isRunning_Unsafe: Bool {
        /// ! Not Thread Safe. Use this if you're already executing on displayLink.dispatchQueue
        return displayLink.isRunning_Unsafe()
    }
    
    fileprivate var onStopCallback: (() -> ())?
    
    /// Vars - DisplayLink
    
    var isFirstDisplayLinkCallback_AfterColdStart = false
    var isFirstDisplayLinkCallback_AfterRunningStart = false
    var isLastDisplayLinkCallback = false
    
    var thisAnimationHasProducedDeltas = false /// Whether deltas have been fed into `self.callback` this animation
    
    var lastAnimationValue: Vector = Vector(x: 0, y: 0) /// animationValue when the displayLink was last called
    var lastAnimationTimeUnit: Double = 0.0
    private var lastMomentumHint: MFMomentumHint = kMFMomentumHintNone
    var lastAnimationSpeed: Vector = Vector(x: 0, y: 0)
    
    var lastFrameTime: Double = -1 /// Time at which the displayLink was last called
    
    /// Vars -  Interface
    
    @objc var getLastAnimationSpeed: Vector {
        /// Notes:
        /// - We're introducing this to be able to cancel the scrolling animator when the user changes the scrolling direction. (So that the user has control over stopping the animation)
        /// - We're passing lastAnimationSpeed into the StartParamCalculationCallback. It might point to an architectural error and slow things down if we need this separate getter.
        /// - The naming with `get` at the start is weird. We don't use that anywhere else.
        /// - TODO: Think about where this should be, if it should exist, and what it should be named. This is all kinda hacky and not-thought-through at this point.
        var result = Vector(x: 0, y: 0)
        displayLink.dispatchQueue.sync(flags: defaultDFs) {
            result = lastAnimationSpeed
        }
        return result
    }
    
    @objc var animationTimeLeft: Double {
        var result: Double = -1
        displayLink.dispatchQueue.sync(flags: defaultDFs) {
            result = animationTimeLeft_Unsafe
        }
        return result
    }
    @objc var animationValueLeft: Vector {
        var result = Vector(x:-1, y:-1)
        displayLink.dispatchQueue.sync(flags: defaultDFs) {
            result = animationValueLeft_Unsafe
        }
        return result
    }
    
    @objc var animationValueLeft_Unsafe: Vector {
        /// Only call this when you're already on the animatorQueue
        
        let result = subtractedVectors(animationValueTotal, lastAnimationValue)
        return result
    }
    
    @objc var animationTimeLeft_Unsafe: Double {
        /// Only call this when you're already on the animatorQueue
        
        let result = animationEndTime - lastFrameTime
        return result
    }
    
    /// Other Interface
    
    @objc func linkToMainScreen() {
        displayLink.linkToMainScreen()
    }
    @objc func linkToMainScreen_Unsafe() {
        /// Exposing this as a function and not just doing it automatically when the animation starts because I assume it's slow. Not sure where this assumption comes from.
        displayLink.linkToMainScreen_Unsafe()
    }
    
    /// Start
    
    @objc func start(params: @escaping StartParamCalculationCallback,
                     callback: @escaping AnimatorCallback) {
        
        /// Use the override of this function in TouchAnimator instead. We spent a lot of time updating the TouchAnimatorBase so that it 'should' work, even thought it's unused, but now we're stopping that and letting it become outdated compared to the start() method in TouchAnimator.
        fatalError()
        
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
        
        displayLink.dispatchQueue.async(flags: defaultDFs) {
            
            /// Reset lastAnimationValue
            ///     So we don't give the `params` callback old invalid animationValueLeft.
            ///     I think this is sort of redundant, because we're resetting animationValueLeft in `startWithUntypedCallback_Unsafe()` as well?
            
            let p: MFAnimatorStartParams = params(self.animationValueLeft_Unsafe, self.isRunning_Unsafe, self.animationCurve, self.lastAnimationSpeed)
            
            self.lastAnimationValue = Vector(x: 0, y: 0)
            
            if let doStart = p.object(forKey: "doStart") as? Bool {
                if doStart == false {
                    return;
                }
            }
            
            let durationRaw = p.object(forKey: "duration") as! Double?
            let durationRawInFrames = p.object(forKey: "durationInFrames") as! Int?
            let vector = vectorFromNSValue(p.object(forKey: "vector") as! NSValue) as Vector
            let curve = p.object(forKey: "curve") as! Curve
            
            self.startWithUntypedCallback_Unsafe(durationRaw: durationRaw, durationRawInFrames: durationRawInFrames, value: vector, animationCurve: curve, callback: callback);
        }
    }
    
    internal func startWithUntypedCallback_Unsafe(durationRaw: CFTimeInterval?,
                                                  durationRawInFrames: Int?,
                                                  value: Vector,
                                                  animationCurve: Curve,
                                                  callback: UntypedAnimatorCallback) {
        
        /// Notes:
        /// - This function has `_Unsafe` in it's name because it doesn't execute on self.animatorQueue. Only call it form self.animatorQueue
        /// - Should only be called by this and subclasses
        /// - The use of 'Interval' in CFTimeInterval is kind of confusing, since its also used to spedify points in time (It's just a `Double`), and also it has nothing to do with our `Interval` class, which is much closer to an Interval in the Mathematical sense.
        /// - Animator will be restarted if it's already running. No need to call stop before calling this.
        /// - It's kind of unnecessary to be passing this a value interval, because we only use the length of it. Since the AnimatorCallback only receives valueDeltas each frame and no absolute values,  the location of the value interval doesn't matter.
        /// - We need to make `callback` and UntypedAnimatorCallback instead of a normal AnimatorCallback, so we can change the type of `callback` to TouchAnimatorCallback in the subclass TouchAnimator. That's because Swift is stinky. UntypedAnimatorCallback is @escaping
        
        /// Validate
        
        assert((durationRaw == nil) != (durationRawInFrames == nil))
        if let durationRaw = durationRaw {
            assert(!durationRaw.isNaN && durationRaw.isFinite && durationRaw > 0)
        } else if let durationInFrames = durationRawInFrames {
            assert(durationInFrames > 0);
        }
        
        /// Store args
        
        self.clientCallback = callback;
        self.animationCurve = animationCurve
        
        /// Get stuff
        
        let isRunningg = isRunning_Unsafe
        
        /// Update state
        
        if !isRunningg
            || isFirstDisplayLinkCallback_AfterColdStart {
            
            /// If `isFirstDisplayLinkCallback_AfterColdStart` == true that means that the displayLinkCallback hasn't run yet (since it sets it to false), so we don't want to signal runningStart, yet
            
            isFirstDisplayLinkCallback_AfterColdStart = true
            isFirstDisplayLinkCallback_AfterRunningStart = false
            isLastDisplayLinkCallback = false
            
            thisAnimationHasProducedDeltas = false
            
            lastMomentumHint = kMFMomentumHintNone /// Not totally sure if makes sense?
            lastAnimationSpeed = Vector(x: 0.0, y: 0.0)
            
        } else {
            
            /// Signal running Start
            isFirstDisplayLinkCallback_AfterRunningStart = true
        }
        
        /// Debug
        DDLogDebug("AnimationCallback start - isFirst: \(self.isFirstDisplayLinkCallback_AfterColdStart), isRunningStart: \(self.isFirstDisplayLinkCallback_AfterRunningStart)")
        
        /// Update the rest of the state
        
        if (isRunningg) {
            
            animationStartTime = lastFrameTime
            animationDuration = -1
            animationDurationRaw = durationRaw
            animationDurationRawInFrames = durationRawInFrames
            animationValueTotal = value
            
        } else {
            
            /// animationStartTime will be set in the displayLinkCallback
            animationStartTime = -1
            animationDuration = -1
            animationDurationRaw = durationRaw
            animationDurationRawInFrames = durationRawInFrames
            animationValueTotal = value
            
            /// Start displayLink
            displayLink.start_Unsafe(callback: { [unowned self] (timeInfo: DisplayLinkCallbackTimeInfo) -> () in
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
    }
    
    /// Cancel
    
    @objc func cancel() {
        cancel(forAutoMomentumScroll: false)
    }
    
    @objc(cancel_forAutoMomentumScroll:) func cancel(forAutoMomentumScroll: Bool) {
        
        /// We're using the async call with flags because creating the dispatchworkitemflags for the normal one is somehow pretty slow.
        displayLink.dispatchQueue.async(flags: defaultDFs) {
            
            /// Get info
            /// Notes:
            ///   - Checking for isRunning would be obsolete if we just set `self.thisAnimationHasProducedDeltas = false` when stopping. But maybe that has other side effects that we don't want? Edit: Don't think this is true anymore
            ///   - Maybe we could just return if wasRunning is false. For performance. Don't think self.stop_Unsafe should do anything if wasRunning is false.
            let wasRunning = self.isRunning_Unsafe
            let hadProducedDeltas = self.thisAnimationHasProducedDeltas
            
            /// Debug
            DDLogDebug("TouchAnimator: cancel_forAutoMomentumScroll called. wasRunning: \(wasRunning), hadProducedDeltas: \(hadProducedDeltas), forAutoMomentumScroll: \(forAutoMomentumScroll), callback: \(String(describing: self.clientCallback)), lastMomentumHint: \(self.lastMomentumHint)")
            
            /// Stop displayLink
            self.stop_Unsafe()
            
            /// Call callback
            
            assert(!wasRunning || self.clientCallback is AnimatorCallback) /// Why did we use ? intead of ! in`self.clientCallback as? AnimatorCallback` below? Asserting here because I think that might have been a mistake, but I don't wanna cause crashes in production.
            if wasRunning, let callback = self.clientCallback as? AnimatorCallback {
                
                if hadProducedDeltas {
                    DDLogDebug("TouchAnimator: Sending cancel events")
                    callback(Vector(x: 0, y: 0), kMFAnimationCallbackPhaseCanceled, self.lastMomentumHint)
                } else {
                    if forAutoMomentumScroll {
                        
                        /// Notes:
                        ///   - If the animator is started and then immediately stopped, we usally just want to ignore that and just not call the callback (Why do we even want that? I guess performance, but when does this happen?). But for autoMomentumScroll in GestureScrollSimulator we DO want to send start and cancel events if started and then immediately stepped. Otherwise, app like Xcode might continue momentumScrolling.
                        ///   - Specifically, this is necessary when momentumScrolling is used by GestureScrollSimulator when it itself is used in Scroll.m when ending an animation and immediately suppressing momentumScroll. Feels like we're implementing some pretty specific high level behaviour in this very low level class. Maybe we need to restructure our abstractions.
                        ///   - Calling callback with start phase here might be totally unnecessary Edit: Nope is necessary to fix the Safari weirdness. (Edit: Which Safari weirdness? I think it had something to do with overscrolling, but not sure.)
                        ///   - Maybe we should spread out the start phase and canceled phase callbacks over time? Maybe call the canceled phase callback from the displayLinkCallback?? There an issue in Safari. When you scroll into the rubberband and then back Safari will add momentum. (Even though Safari normally never adds its own momentum I think). This momentum can't even be stopped by touching the trackpad, so idk what we could do about it.
                        ///     - Edit: Spacing the events out fixes it! We're just using a DispatchQueue, not the displaylink to do this. Might lead to raceconditions if the animator is restarted before the call. Don't think so though.
                        ///   - Not sure the delay should scale with frametime. I tested 2ms that's too low. 4ms works, so we chose 8ms to be safe (On a 60 hz screen)
                        ///
                        ///     Edit: Getting this new dispatchQueue everytime seems to be super slow, so we'll try to use the displayLink queue instead.
                        ///     Edit2: Nope I made a mistake, this is never even called in the configuration I was testing (it's only called for non-inertial gesture scrolling, which we're currently not using in the app anymore)
                        
                        DDLogDebug("TouchAnimator: Sending extra momentum cancel events even though momentumScrolling hasn't started")
                        
                        callback(Vector(x: 0, y: 0), kMFAnimationCallbackPhaseStart, self.lastMomentumHint)
                        let delay = 8.0/1000.0 /// self.displayLink.nominalTimeBetweenFrames() / 2.0
                        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay, flags: defaultDFs, execute: { /// Why aren't we just using our queue here?
                            callback(Vector(x: 0, y: 0), kMFAnimationCallbackPhaseCanceled, self.lastMomentumHint)
                        })
                    }
                }
            }
        }
    }
    
    /// Stop
    
    private func stop_FromDisplayLinkedThread() {
        /// Trying to stop from displayLinkThread causes deadlock. So we need to wait until the displayLinkThread has finished its iteration and then stop ASAP.
        ///     The best way we found to stop ASAP is to simply enqueu async on the displayLink's dispatchQueue
        
        displayLink.dispatchQueue.async(flags: defaultDFs) {
            self.stop_Unsafe()
        }
    }
    
    private func stop_Unsafe() {
        
        /// Debug
        DDLogDebug("AnimationCallback STOP")
        
        /// Reset speed
        /// Notes: Not totally sure this belongs here. But resetting in start() doesn't work with the current code because the speed needs to be reset before it's passed into StartParamCalculationCallback() - And that function is the first thing that is called inside start().
        lastAnimationSpeed = Vector(x: 0, y: 0)
        
        /// Do stuff
        displayLink.stop_Unsafe()
        
        isFirstDisplayLinkCallback_AfterColdStart = false
        isFirstDisplayLinkCallback_AfterRunningStart = false
        isLastDisplayLinkCallback = false
        
//        if self.onStopCallback != nil {
//            self.onStopCallback!()
//            self.onStopCallback = nil
//
//        }
    }

    /// TODO: Delete the onStopCallback stuff
    
//    @objc func onStop_SynchronouslyFromAnimationQueue(callback: @escaping () -> ()) {
//        /// The default `onStop(callback:)` dispatches to self.queue asynchronously.
//        /// It can be used from self.queue, but, if used from self.queue, the callback will only become active after all the other items in the queue are finished, which is not always what we want.
//        /// Use this function to synchronously install the onStop callback.
//        /// This function should only be called from self.queue
//
//        assert(self.isRunning_Unsafe)
//
//        onStop_Unsafe(callback: callback, doImmediatelyIfNotRunning: false)
//    }
//
//    @objc func onStop(callback: @escaping () -> ()) {
//
//        displayLink.dispatchQueue.async {
//            self.onStop_Unsafe(callback: callback, doImmediatelyIfNotRunning: false)
//        }
//    }
//
//    fileprivate func onStop_Unsafe(callback: @escaping () -> (), doImmediatelyIfNotRunning: Bool) {
//        /// Not thread safe. Use `onStop` unless you're already running on displayLink.dispatchQueue
//        /// Do `callback` once the Animator stops or immediately if the animator isn't running and `waitTillNextStop` is false
//
//        if (doImmediatelyIfNotRunning && !self.isRunning_Unsafe) {
//            callback()
//        } else {
//            self.onStopCallback = callback
//        }
//    }
    
    /// DisplayLink callback
    /// This will be called whenever the display refreshes while the displayLink is running
    /// Its purpose is calling self.callback. Everything else it does is to figure out arguments for self.callback
    
    @objc func displayLinkCallback(_ timeInfo: DisplayLinkCallbackTimeInfo) {
            
        /// Race conditions
        ///     We're trying to prevent callback calls after stopping in displayLink, but somehow this still happens. Edit: Might have fixed it by moving the queue dispatch into displayLink
        if !self.isRunning_Unsafe {
            return;
        }
        
        /// Debug
        
        if isFirstDisplayLinkCallback_AfterRunningStart || isFirstDisplayLinkCallback_AfterColdStart {
            DDLogDebug("inside-animator - start \(isFirstDisplayLinkCallback_AfterRunningStart ? "(running)" : "(cold)")")
        }
        
        DDLogDebug("\nAnimation value total: (\(animationValueTotal.x), \(animationValueTotal.y)), left: (\(animationValueLeft_Unsafe.x), \(animationValueLeft_Unsafe.y))")
        
        DDLogDebug("HNGG AnimationCallback with state - isFirstCold: \(isFirstDisplayLinkCallback_AfterColdStart), isFirstRunning: \(isFirstDisplayLinkCallback_AfterRunningStart)")
        
        /// Guard nil
        
        guard let callback = self.clientCallback else {
            fatalError("Invalid state - callback can't be nil during running animation")
        }
        guard let animationCurve = self.animationCurve else {
            fatalError("Invalid state - animationCurve can't be nil during running animation")
        }
        
        /// Get time when frame will be displayed
        var frameTime = timeInfo.outFrame
        
        if isFirstDisplayLinkCallback_AfterColdStart {
            
            /// Set animation start time
            
            /// Pull time of last frame time out of butt
            ///  Note: Why don't we use timeInfo.lastFrame/timeInfo.thisFrame here?
            lastFrameTime = frameTime - timeInfo.nominalTimeBetweenFrames
            
            /// Set animation start time to hypothetical last frame
            ///     This is so that the first timeDelta is the same size as all the others (instead of 0)
            animationStartTime = lastFrameTime
            
            /// Reset lastAnimationTimeUnit
            ///     Might be better to reset this somewhere else
            lastAnimationTimeUnit = -1
            
            /// Reset lastSubCurve
            ///     Might be better to reset this in start and/or stop
            //                lastSubCurve = kMFHybridSubCurveNone
        }
        
        if isFirstDisplayLinkCallback_AfterColdStart || isFirstDisplayLinkCallback_AfterRunningStart {
            
            /// Round duration to a multiple of timeBetweenFrames
            ///     This is so that the last timeDelta is the same size as all the others
            ///     Doing this in start() would be easier but leads to deadlocks
            
            if let animationDurationRaw = animationDurationRaw {
                self.animationDuration = ModificationUtility.roundUp(animationDurationRaw, toMultiple: displayLink.nominalTimeBetweenFrames())
            } else if let animationDurationRawInFrames = animationDurationRawInFrames {
                self.animationDuration = Double(animationDurationRawInFrames) * displayLink.nominalTimeBetweenFrames()
            } else {
                assert(false)
            }
            
            /// Validate
            assert(self.animationDuration >= 0)
            
            /// Limit animationDuration
            ///  Note: With fastScroll the animationDuration can become absurdly large - easily several hours. Especially on a free spinning wheel. So we limit the duration here.
            if animationDuration > maxAnimationDuration { animationDuration = maxAnimationDuration }
        }
        
        /// Set phase to end
        ///     If the last callback was the last delta callback
        ///     Note: We know that for this frame, we'll just send a 'stop' event, and the delta for this frame is going to be (0,0), so most of the work below is redundant in this case
        if self.lastFrameTime >= self.animationEndTime {
            isLastDisplayLinkCallback = true
        }
        
        /// Check if animation time is up
        
        let closerToEndTimeThanNextFrame = abs(frameTime - self.animationEndTime) < abs(frameTime+timeInfo.timeBetweenFrames - self.animationEndTime)
        let pastEndTime = animationEndTime <= frameTime
        
        if closerToEndTimeThanNextFrame || pastEndTime {
            /// This is probably the last delta callback -> make sure we scroll exactly animationValueTotal
            frameTime = animationEndTime /// This is so we scroll exactly animationValueTotal
        }
        
        /// Debug
        //            DDLogDebug("Time delta in-animator: \(frameTime - lastFrameTime) \nanimationEndTime: \(self.animationEndTime), frameTime: \(frameTime)\n animationStartTime \(self.animationStartTime), animationDuration: \(self.animationDuration)")
        
        /// Get normalized time
        let animationTimeUnit: Double = Math.scale(value: frameTime, from: animationTimeInterval, to: .unitInterval)
        
        /// Get normalized animation value from animation curve
        let animationValueUnit: Double = animationCurve.evaluate(at: animationTimeUnit)
        
        /// Get momentumHint
        
        var momentumHint: MFMomentumHint = kMFMomentumHintNone
        
        if let hybridCurve = animationCurve as? HybridCurve {
            
            /// Get subcurve
            var subCurve = hybridCurve.subCurve(at: animationTimeUnit)
            /// Set subCurve to base
            ///     We only want to set the curve to drag if all of the pixels to be scrolled for the frame come from the DragCurve
            if lastAnimationTimeUnit != -1 {
                let lastSubCurve = hybridCurve.subCurve(at: lastAnimationTimeUnit)
                /// ^ Can't use `lastSubCurve` instance prop because it would never change
                if lastSubCurve == kMFHybridSubCurveBase {
                    subCurve = kMFHybridSubCurveBase
                }
            }
            
            /// Do get momentumHint
            
            let timeSinceAnimationStart = frameTime - animationStartTime
            let minBaseCurveTime = ScrollConfig().consecutiveScrollTickIntervalMax
            
            /// DEBUG
//            minBaseCurveTime = 0.0
            
            
            if timeSinceAnimationStart < minBaseCurveTime {
                
                /// Make the first `minBaseCurveTime` seconds of the animation always kMFMomentumHintGesture
                ///     This is so that:
                ///         - ... the first event of the scroll is always sent with gestureScrolls instead of momentumScrolls in Scroll.m. Otherwise apps like Xcode won't react at all (they ignore the deltas in momentumScrolls).
                ///         - ... to decrease the transitions into momentumScroll in Scroll.m. Due to Apple bug, this transition causes a stuttery jump in apps like Xcode
                ///     `minBaseCurveTime`:
                ///         - tested values between 100 and 300 ms and they all worked. Settled on 150 for now. Edit: Using consecutiveScrollTickIntervalMax (which is 160 ms)
                ///         - Put minBaseCurveTime into ScrollConfig?
                
                momentumHint = kMFMomentumHintGesture
                
            } else {
                if subCurve == kMFHybridSubCurveBase {
                    momentumHint = kMFMomentumHintGesture
                } else if subCurve == kMFHybridSubCurveDrag {
                    momentumHint = kMFMomentumHintMomentum
                } else {
                    assert(false)
                }
            }
        }
        
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
        ///     TouchAnimator overrides this to do its thing
        
        subclassHook(callback, animationValueDelta, animationTimeDelta, momentumHint)
        
        /// Update `last` time and value and phase
        lastFrameTime = frameTime
        lastAnimationValue = animationValue
        lastAnimationTimeUnit = animationTimeUnit
        lastMomentumHint = momentumHint
        
        if (!isLastDisplayLinkCallback) { /// For the lastDisplayLinkCallback, the animationTimeDelta might be 0 (actually I think it's always 0), which would make the lastAnimationSpeed contain NaN. Which can sometimes bleed into the client callback for reasons I don't understand. Also if lastDisplayLinkCallback, the lastAnimationSpeed will be set to 0 in the stop() function anyways.
            lastAnimationSpeed = scaledVector(animationValueDelta, 1.0/animationTimeDelta)
        }
        
        /// Validate
        assert(!vectorHasNan(lastAnimationSpeed));
        
        /// Stop animation if phase is  `end`
        if isLastDisplayLinkCallback {
            stop_FromDisplayLinkedThread()
            return
        }
        
        /// Update isFirstCallback state
        ///     Why do we do this after stopping animation, and the update to `last` values before?
        isFirstDisplayLinkCallback_AfterColdStart = false
        isFirstDisplayLinkCallback_AfterRunningStart = false
    }
    
    /// Subclass overridable
    
    func subclassHook(_ untypedCallback: Any, _ animationValueDelta: Vector, _ animationTimeDelta: CFTimeInterval, _ momentumHint: MFMomentumHint) {
        
        /// This is unused. Probably doesn't work properly. The override in `TouchAnimator` is the relevant thing.
        
        /// Guard callback type
        
        guard let callback = untypedCallback as? AnimatorCallback else {
            fatalError("Invalid state - callback is not type AnimatorCallback")
        }
        
        /// Guard simulataneously start and end
        ///     There is similar code in subclass. Update that it when you change this.
        
        let isEndAndNoPrecedingDeltas =
            isLastDisplayLinkCallback
            && !thisAnimationHasProducedDeltas

        assert(!isEndAndNoPrecedingDeltas)
        
        /// Call the callback
        let phase = TouchAnimatorBase.callbackPhase(hasProducedDeltas: thisAnimationHasProducedDeltas, isLastCallback: isLastDisplayLinkCallback)
        callback(animationValueDelta, phase, momentumHint)
        
        /// Debug
        
        DDLogDebug("BaseAnimator callback - delta: \(animationValueDelta)")
        
        /// Update hasProducedDeltas
        
        thisAnimationHasProducedDeltas = true
    }
    
    /// Helper functions
        
}

