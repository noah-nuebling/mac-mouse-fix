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
            if !cycleIsDead {
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
