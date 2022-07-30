//
// --------------------------------------------------------------------------
// ClickCycle.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// Idea for modularizing button input processing
/// Currently unused and untested


/// Imports
import Cocoa

enum ClickCycleTriggerPhase: Int {
    case none = -1
    case press = 0
    case hold = 1
    case levelExpired = 2
    case release = 3
    case releaseFromHold = 4
    case cancel = 5
    case cancelFromHold = 6
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
    case active
    case inactive
    case zombified
}

/// Main class def
class ClickCycle: NSObject {
    
    /// Ivars
    
    var state: ClickCycleActivation = .inactive
    
    var clickLevel: Int = 0
    
    var downTimer = Timer()
    var upTimer = Timer()
    
    var lastDevice: Device? = nil
    var lastButton: ButtonNumber = -1
    
    var lastTriggerCallback: ClickCycleTriggerCallback = {_,_,_,_ in }
    
    /// Threading
    var queue: DispatchQueue = DispatchQueue(label: "com.nuebling.mac-mouse-fix.click-cycle", qos: .userInteractive, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    
    /// Init
    override init() {
        super.init()
        initState()
    }
    
    /// Resetting state
    
    private func initState() {
        state = .inactive
        clickLevel = 0
        downTimer.invalidate()
        upTimer.invalidate()
        lastDevice = nil
        lastButton = -1
        lastTriggerCallback = {_,_,_,_ in }
    }
    
    @objc func zombify() {
        queue.async { self.zombify_Unsafe() }
    }
    
    @objc func zombify_Unsafe() {
        /// Keep state but reset state after next mouse down
            
        state = .zombified
        downTimer.invalidate()
        upTimer.invalidate()
    }
    
    @objc func cancel() {
        queue.async {
            self.cancel_Unsafe()
        }
    }
    @objc func cancel_Unsafe() {
        if state == .active {
            let phase: ClickCycleTriggerPhase = (state == .zombified) ? .cancelFromHold : .cancel
            lastTriggerCallback(phase, self.clickLevel, self.lastDevice!, self.lastButton)
        }
        initState()
    }
    
    @objc func kill() {
        queue.async { self.kill_Unsafe() }
    }
    @objc func kill_Unsafe() {
        initState()
    }
    
    /// Main interface
    
    @objc func isActiveFor(device: NSNumber, button: NSNumber) -> Bool {
        var result: Bool = false
        queue.sync {
            result = self.lastDevice?.uniqueID() == device && self.lastButton == ButtonNumber(truncating: button)
        }
        return result
    }
    
    func handleClick(device: Device, button: ButtonNumber, downNotUp mouseDown: Bool, modifierCallback: @escaping ClickCycleModifierCallback, triggerCallback: @escaping ClickCycleTriggerCallback) {
        
        queue.async {
            
            /// Gather data
            let differentButton = self.lastDevice != device || self.lastButton != button
            let lonelyRelease = !mouseDown && (self.state != .active || differentButton)
            let zombifiedRelease = !mouseDown && (self.state == .zombified)
            
            /// Validate
            if self.state == .zombified {
                assert(!mouseDown)
            }
            
            /// Update cycle state
            if mouseDown {
                /// Cancel old click cycle if button changed
                if self.state == .active && differentButton { /// self.cancel() also checks for isActive, so might be redundant
                    self.cancel_Unsafe()
                }
                /// Start new clickCycle / update state
                self.state = .active
                if mouseDown {
                    self.clickLevel += 1
                }
            }
            
            ///
            /// modifierCallback
            ///
            
            if mouseDown {
                modifierCallback(.press, self.clickLevel, device, button)
            } else {
                let clickLevel = lonelyRelease ? 0 : self.clickLevel /// Not sure if makes difference
                modifierCallback(.release, clickLevel, device, button)
            }
            
            ///
            /// triggerCallback
            ///
            
            if lonelyRelease {
                return
            }
            
            /// Immediate callback
            let immediatePhase: ClickCycleTriggerPhase
            if mouseDown {
                immediatePhase = .press
            } else {
                immediatePhase = zombifiedRelease ? .releaseFromHold : .release
            }
            triggerCallback(immediatePhase, self.clickLevel, device, button)
            
            /// Abort and reset if zombified
            if zombifiedRelease {
                self.initState()
                return
            }
            
            /// Local var copies of global vars for blocks to copy (instead of reference) (Not sure if necessary)
            let clickLevel = self.clickLevel
            
            /// Start/reset timers
            if mouseDown {
                self.upTimer.invalidate()
                self.downTimer = CoolTimer.scheduledTimer(timeInterval: 0.25, repeats: false, block: { timer in
                    self.queue.async {
                        if self.state == .active {
                            triggerCallback(.hold, clickLevel, device, button)
                        }
                        self.zombify_Unsafe()
                    }
                })
            } else { /// mouseUp
                self.downTimer.invalidate()
                self.upTimer = CoolTimer.scheduledTimer(timeInterval: 0.26, repeats: false, block: { timer in
                    /// In ButtonTriggerGenerator we started upTimer on mouseDown. Not sure why.
                    self.queue.async {
                        if self.state == .active {
                            triggerCallback(.levelExpired, clickLevel, device, button)
                        }
                        self.initState()
                    }
                })
            }
            
            /// Update storage
            self.lastDevice = device
            self.lastButton = button
            self.lastTriggerCallback = triggerCallback
        }
    }
}
