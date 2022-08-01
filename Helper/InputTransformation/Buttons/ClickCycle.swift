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

/// Behaviour


/// Imports
import Cocoa

enum ClickCycleTriggerPhase: Int {
    case none = -1
    case press = 0
    case hold = 1
    case levelExpired = 2
    case release = 3
    case releaseFromHold = 4
    case zombieRelease = 5
    case zombieReleaseFromHold = 6
};

enum ClickCycleModifierPhase: Int {
    case none = -1
    case press = 0
    case release = 1
}

/// Typedefs
typealias ButtonNumber = Int
typealias ClickLevel = Int
typealias ClickCycleTriggerCallback = (ClickCycleTriggerPhase, ClickLevel, Device, ButtonNumber) -> ()
typealias ClickCycleModifierCallback = (ClickCycleModifierPhase, ClickLevel, Device, ButtonNumber) -> ()

enum ClickCycleActivation {
    case alive
    case dead
}

/// Main class def
class ClickCycle: NSObject {
    
    /// Threading
    
    let buttonQueue: DispatchQueue
    
    /// Ivars
    
    var maxClickLevel = 99999
    
    var lastState: ClickCycleActivation = .dead
    
    var lastClickLevel: Int = 0
    var lastDevice: Device? = nil
    var lastButton: ButtonNumber = -1
    var lastWasDown: Bool = false
    
    var downTimer = Timer()
    var upTimer = Timer()
    
    var lastTriggerCallback: ClickCycleTriggerCallback = {_,_,_,_ in }
    
    typealias ZombieEntry = (device: Device, button: ButtonNumber, clickLevel: ClickLevel, fromHold: Bool)
    var zombifiedButtons: [ZombieEntry] = []
    
    /// Init
    required init(buttonQueue: DispatchQueue) {
        self.buttonQueue = buttonQueue
        super.init()
        initState()
    }
    
    /// Resetting state
    
    private func initState() {
        lastState = .dead
        lastClickLevel = 0
        lastDevice = nil
        lastButton = -1
        lastTriggerCallback = {_,_,_,_ in }
        DispatchQueue.main.async { /// timers have to be interacted with from mainThread. Does this threading make sense?
            self.downTimer.invalidate()
            self.upTimer.invalidate()
        }
    }
    
    func kill() {
        if self.lastState != .alive { return }
        if self.lastWasDown {
            self.zombifiedButtons.append((device: self.lastDevice!, button: self.lastButton, clickLevel: self.lastClickLevel, fromHold: !self.downTimer.isValid))
        }
        initState()
    }
    
    func forceKill() {
        /// Kill and then send release message immediately
        ///     TODO: Implement
        assert(false)
    }
    
    /// Main interface
    
    func isActiveFor(device: NSNumber, button: NSNumber) -> Bool {
        return self.lastDevice?.uniqueID() == device && self.lastButton == ButtonNumber(truncating: button)
    }
    
    func handleClick(device: Device, button: ButtonNumber, downNotUp mouseDown: Bool, maxClickLevel: Int, modifierCallback: @escaping ClickCycleModifierCallback, triggerCallback: @escaping ClickCycleTriggerCallback) {
        
        ///
        /// Update/gather state
        ///
        
        let buttonIsDifferent = self.lastDevice != device || self.lastButton != button
        
        let clickLevel: ClickLevel
        var state: ClickCycleActivation
        
        if mouseDown {
            /// Switch over to new clickCycle if button changes
            if self.lastState == .alive && buttonIsDifferent {
                self.kill()
            }
            /// Start new clickCycle / update state
            state = .alive
            clickLevel = Math.intCycle(x: self.lastClickLevel + 1, lower: 1, upper: maxClickLevel)
        } else {
            state = self.lastState
            clickLevel = self.lastClickLevel
        }
        
        /// Update global state
        ///     Updating this up here to avoid race conditions. We could alternatively lock everything with `buttonQueue`, and then update this at the end.
        ///     Then we could also use the global vars in here directly instead of making a local copy of the clickLevel and state.
        self.lastState = state
        self.lastDevice = device
        self.lastButton = button
        self.lastWasDown = mouseDown
        self.lastTriggerCallback = triggerCallback
        self.lastClickLevel = clickLevel
        
        ///
        /// Start/reset timers
        ///
        
        assert(Thread.isMainThread) /// With the current setup we're already running on main (which is necessary for staring timers), and dispatching to main causes race conditions, so we're just asserting
//        DispatchQueue.main.sync {
            if mouseDown {
                /// mouseDown
                self.upTimer.invalidate()
                self.downTimer = CoolTimer.scheduledTimer(timeInterval: 0.25, repeats: false, block: { timer in
                    self.buttonQueue.async {
                        if self.lastState == .alive {
                            triggerCallback(.hold, clickLevel, device, button)
                        }
                        self.kill()
                    }
                })
            } else {
                /// mouseUp
                ///     In ButtonTriggerGenerator we started upTimer on mouseDown with timeInterval 0.25. Not sure why.
                self.downTimer.invalidate()
                self.upTimer = CoolTimer.scheduledTimer(timeInterval: 0.21, repeats: false, block: { timer in
                    self.buttonQueue.async {
                        if self.lastState == .alive {
                            triggerCallback(.levelExpired, clickLevel, device, button)
                        }
                        self.kill()
                    }
                })
            }
//        }
        
        ///
        /// Handle zombification
        ///
        
        /// Find entry for current button
        let zombieEntry: ZombieEntry? = zombifiedButtons.first { $0.button == button }
        
        /// Validate 1
        let lonelyRelease = !mouseDown && (state == .dead || buttonIsDifferent)
        assert(lonelyRelease == (zombieEntry != nil)) /// This means: Release outside of the current clickCycle happens exactly if the released button is zombified
        
        /// Validate 2
        let duplicates: [[ZombieEntry]] = Array(Dictionary(grouping: zombifiedButtons, by: { $0.button }).values)
        for duplicateButtonArray in duplicates {
            assert(duplicateButtonArray.count == 1) /// This means: Each button occurs at most once in `zombifiedButtons`
        }
        
        /// Do stuff
        if let zombieEntry = zombieEntry {
            
            /// Send trigger callback
            let phase: ClickCycleTriggerPhase = zombieEntry.fromHold ? .zombieReleaseFromHold : .zombieRelease
            triggerCallback(phase, zombieEntry.clickLevel, zombieEntry.device, zombieEntry.button)
            
            /// Send modifier callback
            modifierCallback(.release, zombieEntry.clickLevel, zombieEntry.device, zombieEntry.button)
            
            /// Remove zombieEntry
            zombifiedButtons = zombifiedButtons.filter { $0 != zombieEntry }
            
            /// Return
            return
        }
        
        ///
        /// modifierCallback
        ///
        
        if mouseDown {
            modifierCallback(.press, clickLevel, device, button)
        } else {
            modifierCallback(.release, clickLevel, device, button)
        }
        
        ///
        /// triggerCallback
        ///
        
        if mouseDown {
            triggerCallback(.press, clickLevel, device, button)
        } else {
            triggerCallback(.release, clickLevel, device, button)
        }
        
    }
}
