//
// --------------------------------------------------------------------------
// ClickCycle.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// Module for Buttons.swift

/// Thread safety:
///     All calls to this are expected to come from the dispatchQueue owned by Buttons.swift `buttonsQueue`. It will also protect its timer callbacks using `buttonQueue`.
///     So when using this:
///         1. Make sure that you're running on buttonsQueue when calling, otherwise there might be race conditions
///         2. The `modifierCallback` and `triggerCallback` are already protected when they arrive in `Buttons.swift`



/// Imports
import Cocoa
import CocoaLumberjackSwift

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

/// Typedefs
typealias ButtonNumber = Int
typealias ClickLevel = Int
typealias UnconditionalReleaseCallback = (() -> ())
typealias ClickCycleTriggerCallback = (ClickCycleTriggerPhase, ClickLevel, Device, ButtonNumber, inout UnconditionalReleaseCallback?) -> ()
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
    var isAlive: Bool { clickLevel > 0 }
    var downTimer = Timer()
    var upTimer = Timer()
}
typealias ReleaseCallbackKey = ButtonStateKey

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
    ///     Clients can register a callback that will *always* be triggered on release, even if the buttton in question doesn't belong to the current click cycle
    fileprivate var releaseCallbacks: [ReleaseCallbackKey: UnconditionalReleaseCallback] = [:]
    public func waitingForRelease(device: Device, button: ButtonNumber) -> Bool {
        return releaseCallbacks[.init(device, button)] != nil
    }
    
    /// Init
    required init(buttonQueue: DispatchQueue) {
        self.buttonQueue = buttonQueue
        super.init()
        
        kill()
    }
    
    /// Main interface
    
    func isActiveFor(device: NSNumber, button: NSNumber) -> Bool {
        guard let state = state else { return false }
        return state.device.uniqueID() == device && state.button == ButtonNumber(truncating: button)
    }
    
    func handleClick(device: Device, button: ButtonNumber, downNotUp mouseDown: Bool, maxClickLevel: Int, modifierCallback: @escaping ClickCycleModifierCallback, triggerCallback: @escaping ClickCycleTriggerCallback) {
        
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
        
        ///
        /// unconditionalReleaseCallback
        ///
        
        if !mouseDown {
            let key = ReleaseCallbackKey(device, button)
            if let callback = releaseCallbacks[key] {
                callback()
                releaseCallbacks.removeValue(forKey: key)
                
            }
        }
        ///
        /// modifierCallback
        ///
        
        if mouseDown {
            modifierCallback(.press, state!.clickLevel, device, button)
        } else {
            modifierCallback(.release, -1, device, button)
        }
        
        let lonelyRelease = !mouseDown && (state == nil || state!.device != device || state!.button != button) /// Release outside of clickCycle it belongs to
        
        if !lonelyRelease {
            
            ///
            /// triggerCallback
            ///
            
            let releaseFromHold = !mouseDown && state?.pressState == .held
            if mouseDown {
                var releaseCallback: UnconditionalReleaseCallback? = nil
                triggerCallback(.press, state!.clickLevel, device, button, &releaseCallback)
                if let c = releaseCallback { releaseCallbacks[.init(device, button)] = c }
            } else {
                let trigger: ClickCycleTriggerPhase = releaseFromHold ? .releaseFromHold : .release
                callTriggerCallback(triggerCallback, trigger, state!.clickLevel, device, button)
            }
            
            ///
            /// Kill after releaseFromHold
            ///
            if releaseFromHold {
                kill()
                return
            }
        
            /// Check active clickCycle
            ///     (triggerCallback could've killed it)
            
            if state == nil {
                return
            }
            
            ///
            /// Start/reset timers
            ///
            /// Consider using DispatchSourceTimer instead
            
            assert(Thread.isMainThread) /// With the current setup we're already running on main (which is necessary for staring timers), and dispatching to main causes race conditions, so we're just asserting.
            if mouseDown {
                /// mouseDown
                state!.upTimer.invalidate()
                state!.downTimer = CoolTimer.scheduledTimer(timeInterval: 0.25, repeats: false, block: { timer in
                    self.buttonQueue.async {
                        /// Callback
                        var releaseCallback: UnconditionalReleaseCallback? = nil
                        triggerCallback(.hold, self.state!.clickLevel, device, button, &releaseCallback)
                        if let c = releaseCallback {
                            self.releaseCallbacks[.init(device, button)] = c
                        }
                        /// Update state
                        self.state?.pressState = .held
                        self.state?.upTimer.invalidate()
                    }
                })
                /// Not sure whether to start started upTimer on mouseDown or up
                state!.upTimer = CoolTimer.scheduledTimer(timeInterval: 0.26, repeats: false, block: { timer in
                    self.buttonQueue.async {
                        if self.state == nil { return } /// Guard race conditions. Not totally sure why this happens.
                        self.callTriggerCallback(triggerCallback, ClickCycleTriggerPhase.levelExpired, self.state!.clickLevel, device, button)
                        self.kill()
                    }
                })
            } else {
                /// mouseUp
                state!.downTimer.invalidate()
            }
        }
    }
    
    /// Helper
    
    private func callTriggerCallback(_ triggerCallback: ClickCycleTriggerCallback, _ trigger: ClickCycleTriggerPhase, _ clickLevel: ClickLevel, _ device: Device, _ button: ButtonNumber) {
        /// Convenience function - Calls triggerCallback and ignores the last `releaseCallback` argument
        var garbage: UnconditionalReleaseCallback? = nil
        triggerCallback(trigger, clickLevel, device, button, &garbage)
        assert(garbage == nil)
    }
}
