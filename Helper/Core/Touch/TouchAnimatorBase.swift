//
// --------------------------------------------------------------------------
// TouchAnimatorBase.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/**
    Historical:
    - `TouchAnimatorBase` is not usable, you have to use subclass `TouchAnimator`. Originally, I thought it would be a good idea to get a base version working and then build the more complicated `SubPixelator` stuff as a subclass, but I think it was stupid, and the baseclass ended up being unused and eventually not usable on its own at all [Oct 2026]
    - Before `IOThread` / 'No more dispatch queues' refactor, the animator's start method was passed a closure (`StartParamCalculationCallback`) that ran on the animator's dispatch queue, so the logic for calculating the params could safely read the animator's state (`animationValueLeft`) without races. [Oct 2026]

    Comments from subclass. (Putting all discussion in one place [Oct 2026])
        (Copied from old non-vector TouchAnimator)

        Only use TouchAnimator, not TouchAnimatorBase superclass directly. TouchAnimatorBase is untested and probably doesn't work right.
        This is basically a wrapper around TouchAnimatorBase that subpixelates the output deltas. We thought it would be easier to first build the TouchAnimatorBase without the subpixelation and then add that complextity on after the fact. I think it clutters things up a lot though.

            \Ideas for refactor: Merge TouchAnimator and TouchAnimatorBase. Maybe remove the subpixelators and just round in a way where you don't lose the rounding error. (e.g. rounding the pixel delta for this frame to determine what to actually scroll and only subtracting from the valueLeft what we actually scrolled... Not sure if that would have the same behavior as the current system though - might be a ton of work to get it to work right with all the touch simulation stuff that relies on very precisely setting the phases and deltas.)

        This class does different things. An attempt to summarize: "Based on some input deltas, this class creates smoothly animated output deltas that are that are usable for driving simulated trackpad events"
        It is currently used:
        1. To smooth out pointer movement before plugging it into the GestureScrollSimulator. This prevents too slow / fast momentum scroll due to irregular timeBetweenEvents.
        2. To apply animation and find appropriate gesture phases when mapping scrollwheel input to gestureScrolling, dockSwipes, magnification, etc.

        TouchAnimator will behave just like TouchAnimatorBase with these differences:
        The animationValueDelta values it passes to it's AnimatorCallback are always integers instead of Doubles
        To achieve this, the internally generated Double deltas are rounded using a subpixelator which always rounds to the next larger integer (using biasedSubpixelator)
            This is so we always generate a non-zero integer delta on the first frame of animation, which makes things more responsive when the deltas are single pixels (which they are when you use Apple Acceleration)

        Callbacks wth phases kMFAnimationPhaseStart, and kMFAnimationPhaseContinue have non-zero deltas. Callbacks with kMFAnimationPhaseEnd have a delta of (0,0)
            This behaviour will make this animator great for driving touch gesture simulations, where that kind of input is expected. (In gesture events, the end phase signals lifting your fingers off, so that's why it has a (0,0) delta)

        Also has this cool momentumHint feature which lets us switch between gesture scrolls and momentum scrolls appropriately to allow for scroll bouncing and generally better behaviour.

*/

import Foundation
import CoreVideo
import QuartzCore

@objc class TouchAnimatorBase: NSObject {
    
    /// Typedef
    
    typealias UntypedAnimatorCallback = Any
    typealias AnimatorCallback = (_ animationValueDelta: Vector, _ phase: MFAnimationCallbackPhase, _ subCurve: MFMomentumHint) -> ()
    
    /// Conversion
    
    internal static func callbackPhase(hasProducedDeltas: Bool, isLastCallback: Bool) -> MFAnimationCallbackPhase {

        if      !isLastCallback && !hasProducedDeltas { return kMFAnimationCallbackPhaseStart }
        else if !isLastCallback && hasProducedDeltas  { return kMFAnimationCallbackPhaseContinue }
        else if isLastCallback && hasProducedDeltas   { return kMFAnimationCallbackPhaseEnd }
        else if isLastCallback && !hasProducedDeltas  { return kMFAnimationCallbackPhaseStoppedBeforeStart }
        else                                          { fatalError() }
    }

    @objc static func IOHIDPhase(animationCallbackPhase: MFAnimationCallbackPhase) -> IOHIDEventPhaseBits {

        switch animationCallbackPhase {
        case kMFAnimationCallbackPhaseNone:               return IOHIDEventPhaseBits(kIOHIDEventPhaseUndefined);
        case kMFAnimationCallbackPhaseStart:              return IOHIDEventPhaseBits(kIOHIDEventPhaseBegan)
        case kMFAnimationCallbackPhaseContinue:           return IOHIDEventPhaseBits(kIOHIDEventPhaseChanged)
        case kMFAnimationCallbackPhaseEnd:                return IOHIDEventPhaseBits(kIOHIDEventPhaseEnded)
        case kMFAnimationCallbackPhaseCanceled:           return IOHIDEventPhaseBits(kIOHIDEventPhaseEnded)     /// `Canceled` maps to `Ended`. Real trackpad never sends `kIOHIDEventPhaseCancelled`, except when resting fingers and then lifting them off without beginning a scroll, which we're not interested in simulating. [Jul 2025]
        default:                                          fatalError()
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
    
    //let threadLock = DispatchSemaphore.init(value: 1)
    /// ^ Using a queue instead of a lock to avoid deadlocks. Always use queues for mutual exclusion except if you know exactly what you're doing!
    //let animatorQueue: DispatchQueue /// Use the displayLink's queue instead to avoid deadlocks and such

    let readWriteTracker = MFReadWriteTracker()

    /// Init

    @available(*, unavailable)
    @objc override init() { fatalError("init() unavailable") }

    @objc init(phaseShift: VBLPhase, runLoop: CFRunLoop, name: String) {
        self.displayLink = DisplayLink(phaseShift: phaseShift, runLoop: runLoop, name: name)
        super.init()
    }

    /// Vars - Start & stop
    
    internal var animationDurationRaw: CFTimeInterval = 0
    internal var animationDurationRawInFrames: Int = 0
    internal var animationDuration: CFTimeInterval = 0
    internal var animationStartTime: CFTimeInterval = 0
    internal var animationEndTime: CFTimeInterval { animationStartTime + animationDuration }
    internal var animationTimeInterval: Interval {
        assert(animationStartTime > 0 && animationDuration > 0) /// Debug
        return Interval(location: animationStartTime, length: animationDuration)
    }
    
    internal var animationValueTotal: Vector = Vector(x: 0, y: 0)
    internal var animationValueIntervalX: Interval { Interval(start: 0, end: animationValueTotal.x) }
    internal var animationValueIntervalY: Interval { Interval(start: 0, end: animationValueTotal.y) }

    @objc var isRunning: Bool {
        readsState_Begin(readWriteTracker); defer { readsState_End(readWriteTracker) } /// [Sep 2026] Use readsState not readsAndWritesState since `displayLink.isRunning()` only readsState currently.
        return displayLink.isRunning()
    }

    /// Vars - DisplayLink
    
    internal var isFirstDisplayLinkCallback_AfterColdStart = false
    internal var isFirstDisplayLinkCallback_AfterRunningStart = false
    internal var isLastDisplayLinkCallback = false

    internal var thisAnimationHasProducedDeltas = false /// Whether deltas have been fed into `self.callback` this animation

    internal var lastAnimationValue: Vector = Vector(x: 0, y: 0) /// animationValue when the displayLink was last called
    internal var lastAnimationTimeUnit: Double = 0.0
    internal var lastMomentumHint: MFMomentumHint = kMFMomentumHintNone
    internal var _lastAnimationSpeed: Vector = Vector(x: 0, y: 0)

    internal var lastFrameTime: Double = -1 /// Time at which the displayLink was last called

    /// Vars -  Interface

    @objc var lastAnimationSpeed: Vector {
        assertRunLoop(displayLink.runLoop())
        readsState_Begin(readWriteTracker); defer { readsState_End(readWriteTracker) }
        return _lastAnimationSpeed
    }
    
    @objc var animationValueLeft: Vector {
        assertRunLoop(displayLink.runLoop())
        readsState_Begin(readWriteTracker); defer { readsState_End(readWriteTracker) }
        return subtractedVectors(animationValueTotal, lastAnimationValue)
    }

    /// Other Interface
    
    @objc func linkToMainScreen() {
        /// Exposing this as a function and not just doing it automatically when the animation starts because I assume it's slow. Not sure where this assumption comes from.

        assertRunLoop(displayLink.runLoop())
        readsAndWritesState_Begin(readWriteTracker); defer { readsAndWritesState_End(readWriteTracker) }
        displayLink.linkToMainScreen()
    }
    
    /// Start
    
    internal func startWithUntypedCallback(durationRaw: CFTimeInterval,
                                           durationRawInFrames: Int,
                                           value: Vector,
                                           animationCurve: Curve,
                                           callback: UntypedAnimatorCallback) {

        /// No need for `assertRunLoop` and `readsAndWritesState_Begin` since this is effectively a private helper (only called by subclasses' override) [Sep 2026]

        /// Notes:
        /// - Should only be called by this and subclasses
        /// - The use of 'Interval' in CFTimeInterval is kind of confusing, since its also used to spedify points in time (It's just a `Double`), and also it has nothing to do with our `Interval` class, which is much closer to an Interval in the Mathematical sense.
        /// - Animator will be restarted if it's already running. No need to call stop before calling this.
        /// - It's kind of unnecessary to be passing this a value interval, because we only use the length of it. Since the AnimatorCallback only receives valueDeltas each frame and no absolute values,  the location of the value interval doesn't matter.
        /// - We need to make `callback` and UntypedAnimatorCallback instead of a normal AnimatorCallback, so we can change the type of `callback` to TouchAnimatorCallback in the subclass TouchAnimator. That's because Swift is stinky. UntypedAnimatorCallback is @escaping

        /// Reset animationValueLeft
        /// Notes:
        /// - Do this here since `animationValueLeft` is `animationValueTotal - lastAnimationValue`. A new `animationValueTotal` is contained in `p`, and we need to reset `lastAnimationValue` to make it usable. Edit: What? ... I think this is talking about why this is reset here and not inside startWithUntypedCallback() or the displayLinkCallback, where most other things are reset.
        ///     [Oct 2026] Don't understand this. Removed `StartParamCalculationCallback` and `p` (dict that client used to pass params) no longer exists.
        self.lastAnimationValue = Vector(x: 0, y: 0)

        /// Validate
        assert((durationRaw <= 0) != (durationRawInFrames <= 0))
        if durationRawInFrames <= 0 { assert(!durationRaw.isNaN && durationRaw.isFinite) }

        /// Store args
        
        self.clientCallback = callback;
        self.animationCurve = animationCurve
        
        /// Get stuff
        
        allowNestedReadOrWrite_Begin(from: .readsAndWritesState, readWriteTracker)
        let isRunningg = isRunning
        allowNestedReadOrWrite_End(from: .readsAndWritesState, readWriteTracker)
        
        /// Update state
        
        if !isRunningg
            || isFirstDisplayLinkCallback_AfterColdStart {
            
            /// If `isFirstDisplayLinkCallback_AfterColdStart` == true that means that the displayLinkCallback hasn't run yet (since it sets it to false), so we don't want to signal runningStart, yet
            
            isFirstDisplayLinkCallback_AfterColdStart = true
            isFirstDisplayLinkCallback_AfterRunningStart = false
            isLastDisplayLinkCallback = false
            
            thisAnimationHasProducedDeltas = false
            
            lastMomentumHint = kMFMomentumHintNone /// Not totally sure if makes sense?
            _lastAnimationSpeed = Vector(x: 0.0, y: 0.0)

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
            displayLink.start(callback: { [unowned self] (timeInfo: DisplayLinkCallbackTimeInfo) -> () in
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
        
        assertRunLoop(displayLink.runLoop());
        readsAndWritesState_Begin(readWriteTracker); defer { readsAndWritesState_End(readWriteTracker) }

        /// Get info
        /// Notes:
        ///   - Checking for isRunning would be obsolete if we just set `self.thisAnimationHasProducedDeltas = false` when stopping. But maybe that has other side effects that we don't want? Edit: Don't think this is true anymore
        ///   - Maybe we could just return if wasRunning is false. For performance. Don't think self.stop should do anything if wasRunning is false.
        allowNestedReadOrWrite_Begin(from: .readsAndWritesState, readWriteTracker)
        let wasRunning = self.isRunning
        allowNestedReadOrWrite_End(from: .readsAndWritesState, readWriteTracker)
        let hadProducedDeltas = self.thisAnimationHasProducedDeltas

        /// Debug
        DDLogDebug("TouchAnimator: cancel_forAutoMomentumScroll called. wasRunning: \(wasRunning), hadProducedDeltas: \(hadProducedDeltas), callback: \(String(describing: self.clientCallback)), lastMomentumHint: \(self.lastMomentumHint)")

        /// Stop displayLink
        self.stop()

        /// Guard
        assert(!wasRunning || self.clientCallback is AnimatorCallback) /// Why did we use ? intead of ! in`self.clientCallback as? AnimatorCallback` below? Asserting here because I think that might have been a mistake, but I don't wanna cause crashes in production.
        guard wasRunning, let callback = self.clientCallback as? AnimatorCallback else { return }

        /// Call callback
        let phase = hadProducedDeltas ? kMFAnimationCallbackPhaseCanceled : kMFAnimationCallbackPhaseStoppedBeforeStart;
        DDLogDebug("TouchAnimator: Sending cancel event (\(phase)")
        allowNestedReadOrWrite_Begin(from: .readsAndWritesState, readWriteTracker); /// [Sep 2026] Allow this since it happens at the end of `cancel()`
        callback(Vector(x: 0, y: 0), phase, self.lastMomentumHint)
        allowNestedReadOrWrite_End(from: .readsAndWritesState, readWriteTracker)
    }
    
    /// Stop
    private func stop() {

        /// Debug
        DDLogDebug("AnimationCallback STOP")
        
        /// Reset speed
        /// Notes: Not totally sure this belongs here. But resetting in start() doesn't work with the current code because the speed needs to be reset before it's passed into StartParamCalculationCallback() - And that function is the first thing that is called inside start().
        ///     [Oct 2026] Removed StartParamCalculationCallback. Don't understand this. Probably doesn't apply anymore. (Update: Opus 5.5. says it is necessary)
        _lastAnimationSpeed = Vector(x: 0, y: 0)

        /// Do stuff
        displayLink.stop()
        
        isFirstDisplayLinkCallback_AfterColdStart = false
        isFirstDisplayLinkCallback_AfterRunningStart = false
        isLastDisplayLinkCallback = false
    }

    /// DisplayLink callback
    /// This will be called whenever the display refreshes while the displayLink is running
    /// Its purpose is calling self.callback. Everything else it does is to figure out arguments for self.callback
    
    private func displayLinkCallback(_ timeInfo: DisplayLinkCallbackTimeInfo) {

        assertRunLoop(displayLink.runLoop()); /// Guaranteed, just a sanitfy check/documentation, I guess [Sep 2026]
        readsAndWritesState_Begin(readWriteTracker); defer { readsAndWritesState_End(readWriteTracker) }

        /// Race conditions
        ///     We're trying to prevent callback calls after stopping in displayLink, but somehow this still happens. Edit: Might have fixed it by moving the queue dispatch into displayLink
        allowNestedReadOrWrite_Begin(from: .readsAndWritesState, readWriteTracker)
        let isRunning = self.isRunning
        allowNestedReadOrWrite_End(from: .readsAndWritesState, readWriteTracker)
        if !isRunning {
            return;
        }
        
        /// Debug
        
        if isFirstDisplayLinkCallback_AfterRunningStart || isFirstDisplayLinkCallback_AfterColdStart {
            DDLogDebug("inside-animator - start \(isFirstDisplayLinkCallback_AfterRunningStart ? "(running)" : "(cold)")")
        }
        
        allowNestedReadOrWrite_Begin(from: .readsAndWritesState, readWriteTracker)
        DDLogDebug("Animation value total: (\(animationValueTotal.x), \(animationValueTotal.y)), left: (\(animationValueLeft.x), \(animationValueLeft.y))")
        allowNestedReadOrWrite_End(from: .readsAndWritesState, readWriteTracker)
        
        DDLogDebug("HNGG AnimationCallback with state - isFirstCold: \(isFirstDisplayLinkCallback_AfterColdStart), isFirstRunning: \(isFirstDisplayLinkCallback_AfterRunningStart)")
        
        /// Guard nil
        
        guard let callback = self.clientCallback else {
            fatalError("Invalid state - callback can't be nil during running animation")
        }
        guard let animationCurve = self.animationCurve else {
            fatalError("Invalid state - animationCurve can't be nil during running animation")
        }
        
        /// Get time when frame will be displayed
        var frameTime = timeInfo.nextFrame

        if isFirstDisplayLinkCallback_AfterColdStart {
            
            /// Set animation start time
            
            /// Pull time of last frame time out of butt
            lastFrameTime = frameTime - timeInfo.timeBetweenFrames

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
            
            if animationDurationRaw > 0 {
                self.animationDuration = ModificationUtility.roundUp(animationDurationRaw, toMultiple: timeInfo.timeBetweenFrames)
            } else if animationDurationRawInFrames > 0 {
                self.animationDuration = Double(animationDurationRawInFrames) * timeInfo.timeBetweenFrames
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
            //minBaseCurveTime = 0.0

            
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
            _lastAnimationSpeed = scaledVector(animationValueDelta, 1.0/animationTimeDelta)
        }
        
        /// Validate
        assert(!vectorHasNan(_lastAnimationSpeed));

        /// Stop animation if phase is  `end`
        if isLastDisplayLinkCallback {
            stop()
            return
        }
        
        /// Update isFirstCallback state
        ///     Why do we do this after stopping animation, and the update to `last` values before?
        isFirstDisplayLinkCallback_AfterColdStart = false
        isFirstDisplayLinkCallback_AfterRunningStart = false

    }
    
    /// Subclass overridable
    
    internal func subclassHook(_ untypedCallback: Any, _ animationValueDelta: Vector, _ animationTimeDelta: CFTimeInterval, _ momentumHint: MFMomentumHint) {
        /// Override in subclass [Sep 2026]
        fatalError();
    }

}

