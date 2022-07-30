//
// --------------------------------------------------------------------------
// Buttons.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

@objc class Buttons: NSObject {

    static let clickCycle = ClickCycle()
    static let modifiers = ButtonModifiers()
    
    @objc static func handleButtonInputWithButton(device: Device, button: NSNumber, downNotUp mouseDown: Bool) -> MFEventPassThroughEvaluation {
        
        /// Decide passthrough
        var passThroughEval: MFEventPassThroughEvaluation
        /// ...
        
        /// Dispatch through clickCycle
        clickCycle.handleClick(device: device, button: ButtonNumber(truncating: button), downNotUp: mouseDown) { phase, clickLevel, device, button in
            
            
            
            switch phase {
            case kMFClickCyclePhaseButtonDown:
                handleTrigger(trigger: kMFActionTriggerTypeButtonDown, clickLevel: clickLevel, device: device, button: button)
            case kMFClickCyclePhaseButtonUp:
                handleTrigger(trigger: kMFActionTriggerTypeButtonUp, clickLevel: clickLevel, device: device, button: button)
            case kMFClickCyclePhaseHoldTimerExpired:
                handleTrigger(trigger: kMFActionTriggerTypeHoldTimerExpired, clickLevel: clickLevel, device: device, button: button)
            case kMFClickCyclePhaseLevelTimerExpired:
                handleTrigger(trigger: kMFActionTriggerTypeLevelTimerExpired, clickLevel: clickLevel, device: device, button: button)
            case kMFClickCyclePhaseCanceled:
                handleTrigger(trigger: kMFActionTriggerTypeButtonUp, clickLevel: clickLevel, device: device, button: button) /// ???
//            case kMFClickCyclePhaseLonesomeButtonUp:
                
            default:
                fatalError()
            }
            
            /// Send triggers
            
            /// Update modifiers
            modifiers.handleClick(device: device, button: button, clickLevel: clickLevel, downNotUp: mouseDown)
            
        }
        
        return kMFEventPassThroughRefusal
    }
    
    private static func handleTrigger(trigger: MFActionTriggerType, clickLevel: ClickLevel, device: Device, button: ButtonNumber) {
        
        
    }
    
}
