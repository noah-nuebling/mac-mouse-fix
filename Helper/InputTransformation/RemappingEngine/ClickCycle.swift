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

/// Typedefs
typealias ButtonNumber = Int
typealias ClickLevel = Int
typealias ClickCycleCallback = (ClickCyclePhase, ClickLevel, Device, ButtonNumber) -> ()

/// Main class def
class ClickCycle: NSObject {
    
    /// Ivars
    
    var isActive: Bool = false
    
    var clickLevel: Int = 0
    
    var downTimer = Timer()
    var upTimer = Timer()
    
    var lastDevice: Device? = nil
    var lastButton: ButtonNumber = -1
    
    var lastCallback: ClickCycleCallback = {_,_,_,_ in }
    
    /// Threading
    var queue: DispatchQueue = DispatchQueue(label: "com.nuebling.mac-mouse-fix.click-cycle", qos: .userInteractive, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    
    /// Init
    override init() {
        super.init()
        initState()
    }
    
    private func initState() {
        isActive = false
        clickLevel = 0
        downTimer.invalidate()
        upTimer.invalidate()
        lastDevice = nil
        lastButton = -1
        lastCallback = {_,_,_,_ in }
    }
    
    /// Interface
    
    @objc func handleClick(device: Device, button: ButtonNumber, downNotUp mouseDown: Bool, callback: @escaping ClickCycleCallback) {
        
        queue.async {
            
            let differentButton = self.lastDevice != device || self.lastButton != button
            
            if mouseDown {
                /// Cancel old click cycle
                if self.isActive && differentButton { /// self.cancel() also checks for isActive, so might be redundant
                    self.cancel_Unsafe()
                }
                /// Start new clickCycle / update state
                self.isActive = true
                if mouseDown {
                    self.clickLevel += 1
                }
                
            } else { /// if mouseUp
                /// Immediately return upon mouseUp outside of active clickCycle
                if !self.isActive || differentButton {
                    callback(kMFClickCyclePhaseLonesomeButtonUp, 0, device, button)
                    return
                }
            }
            
            /// Immediate callback
            let immediatePhase = mouseDown ? kMFClickCyclePhaseButtonDown : kMFClickCyclePhaseButtonUp
            callback(immediatePhase, self.clickLevel, device, button)
            
            /// Local var copies of global vars for blocks to copy (instead of reference) (Not sure if necessary)
            let clickLevel = self.clickLevel
            
            /// Start/reset timers
            if mouseDown {
                self.upTimer.invalidate()
                self.downTimer = CoolTimer.scheduledTimer(timeInterval: 0.25, repeats: false, block: { timer in
                    self.queue.async {
                        if self.isActive {
                            callback(kMFClickCyclePhaseHoldTimerExpired, clickLevel, device, button)
                        }
                        self.initState()
                    }
                })
            } else { /// mouseUp
                self.downTimer.invalidate()
                self.upTimer = CoolTimer.scheduledTimer(timeInterval: 0.25, repeats: false, block: { timer in
                    /// In ButtonTriggerGenerator we started upTimer on mouseDown. Not sure why.
                    self.queue.async {
                        if self.isActive {
                            callback(kMFClickCyclePhaseLevelTimerExpired, clickLevel, device, button)
                        }
                        self.initState()
                    }
                })
            }
            
            /// Update storage
            self.lastDevice = device
            self.lastButton = button
            self.lastCallback = callback
        }
    }
    @objc func cancel() {
        queue.async {
            self.cancel_Unsafe()
        }
    }
    @objc func cancel_Unsafe() {
        if isActive {
            lastCallback(kMFClickCyclePhaseCanceled, self.clickLevel, self.lastDevice!, self.lastButton)
        }
        initState()
    }
}
