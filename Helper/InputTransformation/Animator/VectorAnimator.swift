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
    typealias AnimatorCallback = (_ animationValueDelta: Vector, _ phase: MFAnimationCallbackPhase, _ subCurve: MFMomentumHint) -> ()
    typealias StopCallback = (_ lastPhase: MFAnimationPhase) -> ()
    typealias StartParamCalculationCallback = (_ valueLeft: Vector, _ isRunning: Bool, _ animationCurve: AnimationCurve?) -> MFAnimatorStartParams
    /// ^ When starting the animator, we usually want to get the value that the animator still wants to scroll (`animationValueLeft`), and add that to the new value. The specific logic can differ a lot though, so we can't just hardcode this into `Animator`
    ///     But to avoid race-conditions, we can't just externally execute this, so we to pass in a callback that can execute custom logic to get the start params right before the animator is started
    typealias MFAnimatorStartParams = Dictionary<String, Any>
    /// ^ 4 keys: "doStart", "duration", "vector", "curve"
    
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
        default:
            fatalError()
        }
    }
    
    /// Constants
    
    /// Vars - Init
    
    let displayLink: DisplayLink
    @Atomic var callback: UntypedAnimatorCallback?
    /// ^ This is constantly accessed by subclassHook() and constantly written to by startWithUntypedCallback(). Becuase Swift is stinky and not thread safe, the app will sometimes crash, when this property is read from and written to at the same time. So we're using @Atomic propery wrapper
    @objc var animationCurve: AnimationCurve? /// This class assumes that `animationCurve` passes through `(0, 0)` and `(1, 1)
                                              //    let threadLock = DispatchSemaphore.init(value: 1)
                                              /// ^ Using a queue instead of a lock to avoid deadlocks. Always use queues for mutual exclusion except if you know exactly what you're doing!

//    let animatorQueue: DispatchQueue /// Use the displayLink's queue instead to avoid deadlocks and such
    
    /// Init
    
    @objc override init() {
        
        self.displayLink = DisplayLink()
//        self.animatorQueue = DispatchQueue(label: "com.nuebling.mac-mouse-fix.animator", qos: .userInteractive , attributes: [], autoreleaseFrequency: .inherit, target: nil)
        
        super.init()
    }
    
    /// Vars - Start & stop
    
    var animationDurationRaw: CFTimeInterval = 0
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
        var result: Bool = false
        displayLink.dispatchQueue.sync {
            result = self.displayLink.isRunning_Unsafe()
        }
        return result
    }
    @objc var isRunning_Unsafe: Bool {
        /// ! Not Thread Safe. Use this if you're already executing on displayLink.dispatchQueue
        return displayLink.isRunning_Unsafe()
    }
    
    fileprivate var onStopCallback: (() -> ())?
    
    /// Vars - DisplayLink

    var isFirstDisplayLinkCallback = false
    var isFirstDisplayLinkCallback_AfterRunningStart = false
    var isLastDisplayLinkCallback = false
    
    var thisAnimationHasProducedDeltas = false /// Whether deltas have been fed into `self.callback` this animation
    
    var lastAnimationValue: Vector = Vector(x: 0, y: 0) /// animationValue when the displayLink was last called
    var lastAnimationTimeUnit: Double = 0.0
    private var lastSubCurve: MFHybridSubCurve = kMFHybridSubCurveNone
    
    var lastFrameTime: Double = -1 /// Time at which the displayLink was last called
    
    /// Vars -  Interface
    
    @objc var animationTimeLeft: Double {
        var result: Double = -1
        displayLink.dispatchQueue.sync {
            result = animationTimeLeft_Unsafe
        }
        return result
    }
    @objc var animationValueLeft: Vector {
        var result = Vector(x:-1, y:-1)
        displayLink.dispatchQueue.sync {
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
        
        displayLink.dispatchQueue.async {
            
            /// Reset lastAnimationValue
            ///     So we don't give the `params` callback old invalid animationValueLeft.
            ///     I think this is sort of redundant, because we're resetting animationValueLeft in `startWithUntypedCallback_Unsafe()` as well?
            
            let p: MFAnimatorStartParams = params(self.animationValueLeft_Unsafe, self.isRunning_Unsafe, self.animationCurve)
            
            self.lastAnimationValue = Vector(x: 0, y: 0)
            
            if let doStart = p["doStart"] as? Bool {
                if doStart == false {
                    return;
                }
            }
            
            let durationRaw = p["duration"] as! Double
            let vector = vectorFromNSValue(p["vector"] as! NSValue) as Vector
            let curve = p["curve"] as! AnimationCurve
            
            self.startWithUntypedCallback_Unsafe(durationRaw: durationRaw, value: vector, animationCurve: curve, callback: callback);
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
        
        /// Validate
        
        assert(!durationRaw.isNaN && durationRaw.isFinite)
        
        /// Store args
        
        self.callback = callback;
        self.animationCurve = animationCurve
        
        /// Get stuff
        
        let isRunningg = isRunning_Unsafe

        /// Update state
        
        if !isRunningg
            || isFirstDisplayLinkCallback {

            /// If isFirstDisplayLinkCallback == true that means that the displayLinkCallback hasn't run yet (since it sets it to false), so we don't wan to signal runningStart, yet
            
            isFirstDisplayLinkCallback = true
            isFirstDisplayLinkCallback_AfterRunningStart = false
            isLastDisplayLinkCallback = false
            
            thisAnimationHasProducedDeltas = false
            
        } else {
            
            /// Signal running Start
            isFirstDisplayLinkCallback_AfterRunningStart = true
        }
        
        /// Debug
        DDLogDebug("AnimationCallback start - isFirst: \(self.isFirstDisplayLinkCallback), isRunningStart: \(self.isFirstDisplayLinkCallback_AfterRunningStart)")
        
        /// Update the rest of the state
        
        if (isRunningg) {
            
            animationStartTime = lastFrameTime
            animationDuration = -1
            animationDurationRaw = durationRaw
            animationValueTotal = value
            
        } else {
            
            /// animationStartTime will be set in the displayLinkCallback
            animationStartTime = -1
            animationDuration = -1
            animationDurationRaw = durationRaw
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
        
        /// Debug
        
//        DDLogDebug("AnimationValueInterval at start: \(value)")
    }
    
    /// Stop
    
    @objc func stop() {
        displayLink.dispatchQueue.async {
            self.stop_Unsafe()
        }
    }
    
    @objc func stop_FromDisplayLinkedThread() {
        /// Trying to stop from displayLinkThread causes deadlock. So we need to wait until the displayLinkThread has finished its iteration and then stop ASAP.
        ///     The best way we found to stop ASAP is to simply enqueu async on the displayLink's dispatchQueue
        
        displayLink.dispatchQueue.async {
            self.stop_Unsafe()
        }
    }
    
    fileprivate func stop_Unsafe() {
        
        /// Debug
        DDLogDebug("STOPPING ANIMATOR")
        
        /// Do stuff
        displayLink.stop_Unsafe()
        
        isFirstDisplayLinkCallback = false
        isFirstDisplayLinkCallback_AfterRunningStart = false
        isLastDisplayLinkCallback = false
        
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
        
        assert(self.isRunning_Unsafe)
        
        onStop_Unsafe(callback: callback, doImmediatelyIfNotRunning: false)
    }
    
    @objc func onStop(callback: @escaping () -> ()) {
        
        displayLink.dispatchQueue.async {
            self.onStop_Unsafe(callback: callback, doImmediatelyIfNotRunning: false)
        }
    }
    
    fileprivate func onStop_Unsafe(callback: @escaping () -> (), doImmediatelyIfNotRunning: Bool) {
        /// Not thread safe. Use `onStop` unless you're already running on displayLink.dispatchQueue
        /// Do `callback` once the Animator stops or immediately if the animator isn't running and `waitTillNextStop` is false
        
        if (doImmediatelyIfNotRunning && !self.isRunning_Unsafe) {
            callback()
        } else {
            self.onStopCallback = callback
        }
    }
    
    /// DisplayLink callback
    /// This will be called whenever the display refreshes while the displayLink is running
    /// Its purpose is calling self.callback. Everything else it does is to figure out arguments for self.callback
    
    @objc func displayLinkCallback(_ timeInfo: DisplayLinkCallbackTimeInfo) {
        
        displayLink.dispatchQueue.sync { /// Use sync so this is actually executed on the high-priority display-linked thread
            
            /// Debug
            
            DDLogDebug("\nAnimation value total: (\(animationValueTotal.x), \(animationValueTotal.y)), left: (\(animationValueLeft_Unsafe.x), \(animationValueLeft_Unsafe.y))")
            
            DDLogDebug("AnimationCallback with state - isFirst: \(isFirstDisplayLinkCallback), isRunning: \(isFirstDisplayLinkCallback_AfterRunningStart)")
                        
            /// Guard nil
            
            guard let callback = self.callback else {
                fatalError("Invalid state - callback can't be nil during running animation")
            }
            guard let animationCurve = self.animationCurve else {
                fatalError("Invalid state - animationCurve can't be nil during running animation")
            }
            
            /// Get time when frame will be displayed
            var frameTime = timeInfo.outFrame
            
            if isFirstDisplayLinkCallback {
                
                /// Set animation start time
                
                /// Pull time of last frame out of butt
                lastFrameTime = frameTime - timeInfo.nominalTimeBetweenFrames
                
                /// Set animation start time to hypothetical last frame
                ///     This is so that the first timeDelta is the same size as all the others (instead of 0)
                animationStartTime = self.lastFrameTime
                
                /// Reset lastAnimationTimeUnit
                ///     Might be better to reset this somewhere else
                lastAnimationTimeUnit = -1
                
                /// Reset lastSubCurve
                ///     Might be better to reset this in start and/or stop
                lastSubCurve = kMFHybridSubCurveNone
            }
            
            if isFirstDisplayLinkCallback || isFirstDisplayLinkCallback_AfterRunningStart {
                
                /// Round duration to a multiple of timeBetweenFrames
                ///     This is so that the last timeDelta is the same size as all the others
                ///     Doing this in start() would be easier but leads to deadlocks
                
                self.animationDuration = TransformationUtility.roundUp(animationDurationRaw, toMultiple: displayLink.nominalTimeBetweenFrames())
            }
            
            /// Set phase to end
            ///     If the last callback was the last delta callback
            ///     We know that the delta is going to be (0,0) so most of the work below is redundant in this case
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
            
            var subCurve = kMFHybridSubCurveNone
            
            if let hybridCurve = animationCurve as? HybridCurve {
                
                let timeSinceAnimationStart = frameTime - animationStartTime
                
                let minBaseCurveTime = ScrollConfig().consecutiveScrollTickIntervalMax
                
                if timeSinceAnimationStart < minBaseCurveTime {
                    /// Lie and say the the first x ms of the animation are always base
                    ///     This is so that:
                    ///         - ... the first event is always sent with gestureScrolls instead of momentumScrolls in Scroll.m. Otherwise apps like Xcode won't react at all (they ignore the deltas in momentumScrolls).
                    ///         - ... to decrease the transitions into momentumScroll in Scroll.m. Due to Apple bug, this transition causes a stuttery jump in apps like Xcode
                    ///     TODO: (not that important)
                    ///         - This logic doesn't really belong into the Animator
                    ///         - Put minBaseCurveTime into ScrollConfig
                    ///     Values for `minBaseCurveTime`:
                    ///         - tested values between 100 and 300 ms and they all worked. Settled on 150 for now. Edit: Using consecutiveScrollTickIntervalMax (which is 160 ms)
                    
                    subCurve = kMFHybridSubCurveBase
                } else {
                    subCurve = hybridCurve.subCurve(at: animationTimeUnit)
                    /// Reset subCurve to base
                    ///     We only want to set the curve to drag if all of the pixels to be scrolled for the frame come from the DragCurve
                    if lastAnimationTimeUnit != -1 {
                        let lastSubCurve = hybridCurve.subCurve(at: lastAnimationTimeUnit)
                        if lastSubCurve == kMFHybridSubCurveBase {
                            subCurve = kMFHybridSubCurveBase
                        }
                    }
                }
            }
            
            var momentumHint: MFMomentumHint = kMFMomentumHintNone
            
            if subCurve == kMFHybridSubCurveBase {
                
                momentumHint = kMFMomentumHintGesture
                if (lastSubCurve == kMFHybridSubCurveDrag) {
                    momentumHint = kMFMomentumHintGestureFromMomentum
                }
                
            } else if subCurve == kMFHybridSubCurveDrag {
                
                momentumHint = kMFMomentumHintMomentum
                if (lastSubCurve == kMFHybridSubCurveBase) {
                    momentumHint = kMFMomentumHintMomentumFromGesture
                }
            }
            
            lastSubCurve = subCurve
            
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
            
            self.subclassHook(callback, animationValueDelta, animationTimeDelta, momentumHint)
            
            /// Update `last` time and value and phase
            
            self.lastFrameTime = frameTime
            self.lastAnimationValue = animationValue
            self.lastAnimationTimeUnit = animationTimeUnit
            
            /// Stop animation if phase is  `end`
            if isLastDisplayLinkCallback {
                self.stop_FromDisplayLinkedThread()
                return
            }
            
            /// Update isFirstCallback state
            isFirstDisplayLinkCallback = false
            isFirstDisplayLinkCallback_AfterRunningStart = false
        }
    }
    
    /// Subclass overridable
    
    func subclassHook(_ untypedCallback: Any, _ animationValueDelta: Vector, _ animationTimeDelta: CFTimeInterval, _ momentumHint: MFMomentumHint) {
        
        /// This is unused. Probably doesn't work properly. The override in `PixelatedVectorAnimator` is the relevant thing.
        
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
        let phase = VectorAnimator.callbackPhase(hasProducedDeltas: thisAnimationHasProducedDeltas, isLastCallback: isLastDisplayLinkCallback)
        callback(animationValueDelta, phase, momentumHint)
        
        /// Debug
        
        DDLogDebug("BaseAnimator callback - delta: \(animationValueDelta)")
        
        /// Update hasProducedDeltas
        
        thisAnimationHasProducedDeltas = true
    }
    
    /// Helper functions
        
}

