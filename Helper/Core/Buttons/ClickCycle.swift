//
// --------------------------------------------------------------------------
// ClickCycle.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Module for Buttons.swift

/// Terminology & explanations:
///     This class is called `ClickCycle`, but when we talk about the abstract concept of a `clickCycle` that denotes a series of button pressed and button released inputs by the user that the user perceives as being part of one continuous action. Maybe a better name would've been `clickGesture` or something.
///     So a clickCycle always starts on buttonPressed input, where that input is the first in a series of consecutive clicks. And where a series of consecutive clicks of length 2 would generally be called a double click. A click cycle can end (aka be killed) in different ways. See the code for more details.
///
///     The `ClickCycle` class is used to track an abstract clickCycle and analyze it. Perhaps most importantly, it tracks state transitions not only to button pressed and button released states but also to more abstract states: `button held down` and `level expired`. Then it can notify the client of these state transitions and the client can do cool stuff with that.

/// Thread safety:
/// - Edit: IIRC we're just not implementing the dispatchQueue stuff properly because race conditions are incredibly rare and when they happen stuff is robust and doesn't break badly.
/// - All calls to this are expected to come from the dispatchQueue owned by Buttons.swift `buttonsQueue`. It will also protect its timer callbacks using `buttonQueue`.
/// - So when using this:
///     1. Make sure that you're running on buttonsQueue when calling, otherwise there might be race conditions
///     2. The `modifierCallback` and `triggerCallback` are already protected when they arrive in `Buttons.swift`



/// Imports
import Cocoa
import CocoaLumberjackSwift

/// Typedefs
enum ClickCycleTriggerPhase: Int {
    case none = -1
    case press = 0
    case hold = 1
    case levelExpired = 2
    case release = 3
    case releaseFromHold = 4
};

enum ClickCycleModifierPhase: Int {
    case none = -1
    case press = 0
    case release = 1
}

typealias ButtonNumber = Int
typealias ClickLevel = Int
typealias UnconditionalReleaseCallback = (() -> ())
typealias ClickCycleTriggerCallback = (ClickCycleTriggerPhase, ClickLevel, Device, ButtonNumber, inout [UnconditionalReleaseCallback]) -> ()
typealias ClickCycleModifierCallback = (ClickCycleModifierPhase, ClickLevel, Device, ButtonNumber) -> ()

fileprivate enum ButtonPressState {
    case down
    case up
    case held
}
fileprivate struct ClickCycleState: Hashable {
    var device: Device
    var button: ButtonNumber
    var pressState: ButtonPressState
    var clickLevel: ClickLevel
//    var isAlive: Bool { clickLevel > 0 }
    var downTimer = Timer()
    var upTimer = Timer()
}
typealias ReleaseCallbackKey = ButtonNumber

/// Main class def
class ClickCycle: NSObject {
    
    /// Threading
    let buttonQueue: DispatchQueue
    
    /// Config
    var maxClickLevel = 99999
    
    /// State
    fileprivate var state: ClickCycleState? = nil
    func kill() {
        DDLogDebug("triggerCallback - kill")
        state?.downTimer.invalidate()
        state?.upTimer.invalidate()
        state = nil
    }
    func forceKill() {
        /// Kill and then send release message immediately
        ///     TODO: Implement
        assert(false)
    }
    
    /// Release callbacks
    ///     Clients can register a callback that will *always* be triggered when a button is released, even if the release event doesn't belong to the active click cycle
    fileprivate var releaseCallbacks: [ReleaseCallbackKey: [UnconditionalReleaseCallback]] = [:]
    public func waitingForRelease(device: Device, button: ButtonNumber) -> Bool {
        return releaseCallbacks[button] != nil
    }
    
    /// Init
    required init(buttonQueue: DispatchQueue) {
        self.buttonQueue = buttonQueue
        super.init()
        
        kill()
    }
    
    /// Main interface
    
    func isActiveFor(device: NSNumber, button: NSNumber) -> Bool { /// Think this is unused now that we moved ButtonModifiers away from using Device
        guard let state = state else { return false }
        return state.device.uniqueID() == device && state.button == ButtonNumber(truncating: button)
    }
    func isActiveFor(button: NSNumber) -> Bool {
        guard let state = state else { return false }
        return state.button == ButtonNumber(truncating: button)
    }
    
    func handleClick(device: Device, button: ButtonNumber, downNotUp mouseDown: Bool, maxClickLevel: Int, triggerCallback: @escaping ClickCycleTriggerCallback) {
        
        ///
        /// Call unconditionalReleaseCallbacks
        ///
        
        if !mouseDown {
            if let callbacks = releaseCallbacks[button] {
                for c in callbacks { c() }
                releaseCallbacks.removeValue(forKey: button)
                
            }
        }
        
        ///
        /// Update state
        ///
        
        if mouseDown {
            
            /// Gather state
            let cycleIsDead = (state == nil)
            var buttonIsDifferent = false
            if !cycleIsDead { /// Note (Sep 2024): I think only calculating buttonIsDifferent when !cycleIsDead is an optimization, but not sure.
                buttonIsDifferent = button != state!.button || device != state!.device
            }
            
            /// Restart cycle
            if cycleIsDead || buttonIsDifferent {
                kill()
                state = ClickCycleState(device: device, button: button, pressState: .down, clickLevel: 0)
            }
            
            /// Update cycle
            state!.clickLevel = Math.intCycle(x: state!.clickLevel + 1, lower: 1, upper: maxClickLevel)
        }
        
        /// Guard: NOT release outside of clickCycle it belongs to
        let lonelyRelease = !mouseDown && (state == nil || state!.device != device || state!.button != button)
        
        if !lonelyRelease {
            
            
            /// Check: release after being held for an extended time
            let releaseFromHold = !mouseDown && state?.pressState == .held
            
            ///
            /// triggerCallback
            ///
            
            if mouseDown {
                var c: [UnconditionalReleaseCallback] = []
                triggerCallback(.press, state!.clickLevel, device, button, &c)
                if !c.isEmpty {
                    releaseCallbacks[button, default: []].append(contentsOf: c)
                }
            } else { /// mouseUp
                let trigger: ClickCycleTriggerPhase = releaseFromHold ? .releaseFromHold : .release
                callTriggerCallback(triggerCallback, trigger, state!.clickLevel, device, button)
            }
            
            /// Kill after releaseFromHold
            if releaseFromHold {
                kill()
                return
            }
        
            /// Check active clickCycle
            ///     (triggerCallback could've killed it)
            ///     \note: Sometimes there are raceconditions, and the state only becomes nil after this statement. That's why we simply use `state?` below instead of `state!`
            
            if state == nil { return }
            
            ///
            /// Start/reset timers
            ///
            /// Consider using DispatchSourceTimer instead
            /// We need to start timers from main. Async dispatching to main caused race conditions.
            /// Edit: Asserting Thread.isMainThread now since we're think it's a good idea for all input (clicks, drags, and scrolls) to be handled synchronously / on the the same thread - ideally the main thread so things are also synced with the NSTimers. (Could also use another mechanism instead of NSTimers?). Handling things on different threads leads to inconsistent triggering of gestures when the computer is slow.
            /// Update (Sep 2024): are we sure we can't simply use NSTimer on another thread than the main thread? I'd like to move all the input handling over to a single thread as much as possible. I think this would be much nicer both to avoid race conditions and crashes and to ensure we're always handling the users inputs in the order they performed them (When using click and drag while the computer is slow, the order that the clicks and mouse-moves are handled is sometimes wrong I think.)
            
            /// ---
            /// Sep 2024 I just saw a crash in the console:
            /// Thread 5 Crashed::  Dispatch queue: com.nuebling.mac-mouse-fix.buttons
            /// ```
            /// Mac Mouse Fix Helper                     0x104873850 Swift runtime failure: Unexpectedly found nil while unwrapping an Optional value + 0 [inlined]
            /// Mac Mouse Fix Helper                     0x104873850 closure #1 in closure #1 in closure #1 in ClickCycle.handleClick(device:button:downNotUp:maxClickLevel:triggerCallback:) + 528
            /// Mac Mouse Fix Helper                     0x104871d44 thunk for @escaping @callee_guaranteed @Sendable () -> () + 28
            /// ```
            /// Discussion: (last updated: Sep 2024)
            /// - The helper build number was 22854 which matches with the 3.0.3 release.
            /// - I assume this was due to the forceful optional unwrapping of `self.state!` failing in the `scheduledTimer` callbacks below.
            ///     - We set `self.state` to nil regularly whenever we call `self.kill()`, however this should also invalidate the timers, which should prevent them from firing and executing the code that crashed, so I think there must be a race condition or other error.
            ///         Thoughts on where the error could come from:
            ///             - `self.kill()` is invoked by all the other input handling code (modified drag, modified scroll, and keyboardModifier handling I think), I believe that not all of those run on the main thread.
            ///             1. This might lead to a race condition
            ///                 -> Explanation: The timer callback might be fired shortly before kill() sets `state` to nil and invalidates the timers.
            ///             2. This might lead to the NSTimers not being invalidated properly
            ///                 (NSTimer docs say that timers need to be invalidated from the same thread on which they are started, and I don't think we're always doing that)
            ///             - Sidenote: I think we wrote the ClickCycle file basically just not trying to make it thread safe, since for other parts of the app we meticulously made everything thread safe using DispatchQueues, but then that lead to months of debugging deadlocks and stuff like that. So with ClickCycle I just thought
            ///                    'what if I don't use locks to make this thread safe and instead I just try to make it still work fine in case there are race conditions - also, race conditions should be rare anyways, since user input is generally spaced out in time.'
            ///                    IIRC I used this approach for Mac Mouse Fix 1 and 2, since I didn't even know what 'thread safe' meant at that point. And it has also worked quite well for ClickCycle so far, with this being the first crash I see - but using force unwrapping (the ! operator) on `state!` is sort of a mistake under that design philosophy, since it crashes when there's a race condition instead of smoothly recovering.
            ///         Solution ideas:
            ///            1. Move all input processing to a single, dedicated thread (I want to do this anyways.)
            ///                 - My understanding of the current threading situation: (Sep 2024) we process buttonInputs partially on the mainThread and partially on the 'buttonQueue', other inputProcessing modules such as the modifiedDrag also interact with this module by triggering `ClickCycle.kill()`. modifiedDrag runs on the `GlobalEventTapThread`, but then also dispatches to a special `_drag.queue`, which I don't currently understand the purpose of. So it's really a bit all-over-the-place, and the `NSTimer.invalidate()` method inside `ClickCycle.kill()` is probably not always being called from the same thread, which could cause problems according to the docs.
            ///            2. Remove all force unwrapping `!` from ClickCycle and instead do nil checks and then smoothly recover if state == nil.
            ///
            /// TODO: @crash fix this. 
            ///
            
            assert(Thread.isMainThread)
            
            SharedUtilitySwift.doOnMain {
                
                if mouseDown {
                    /// mouseDown
                    state?.upTimer.invalidate()
                    state?.downTimer = CoolTimer.scheduledTimer(timeInterval: 0.25, repeats: false, block: { timer in
                        self.buttonQueue.async {
                            /// Callback
                            var c: [UnconditionalReleaseCallback] = []
                            triggerCallback(.hold, self.state!.clickLevel, device, button, &c)
                            if !c.isEmpty {
                                self.releaseCallbacks[button, default: []].append(contentsOf: c)
                            }
                            /// Update state
                            self.state?.pressState = .held
                            self.state?.upTimer.invalidate()
                        }
                    })
                    /// Not sure whether to start started upTimer on mouseDown or up
                    state?.upTimer = CoolTimer.scheduledTimer(timeInterval: 0.26, repeats: false, block: { timer in
                        self.buttonQueue.async {
                            if self.state == nil { return } /// Guard race conditions. Not totally sure why this happens.
                            self.callTriggerCallback(triggerCallback, ClickCycleTriggerPhase.levelExpired, self.state!.clickLevel, device, button)
                            self.kill()
                        }
                    })
                } else {
                    /// mouseUp
                    state?.downTimer.invalidate()
                }
            }
            
        }
    }
    
    /// Helper
    
    private func callTriggerCallback(_ triggerCallback: ClickCycleTriggerCallback, _ trigger: ClickCycleTriggerPhase, _ clickLevel: ClickLevel, _ device: Device, _ button: ButtonNumber) {
        /// Convenience function - Calls triggerCallback and ignores the last `releaseCallback` argument
        var garbage: [UnconditionalReleaseCallback] = []
        triggerCallback(trigger, clickLevel, device, button, &garbage)
        assert(garbage.isEmpty)
    }
}
