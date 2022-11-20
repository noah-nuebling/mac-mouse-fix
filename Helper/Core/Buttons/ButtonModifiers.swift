//
// --------------------------------------------------------------------------
// ButtonModifiers.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

/// Module for Buttons.swift

/// Threading:
///     This should only be used by Buttons.swift. Use buttons.swfits dispatchQueue to protect resources.

import Cocoa
import CocoaLumberjackSwift

struct ButtonStateKey: Hashable {
    
    /// Swift doesn't allow using tuples as Dictionary keys, so we have to do this instead

    let device: Device
    let button: ButtonNumber

    init(_ device: Device, _ button: ButtonNumber) {
        self.device = device
        self.button = button
    }
}

private struct ButtonState: Equatable {
    var device: Device
    var button: ButtonNumber
    var clickLevel: ClickLevel
    var isPressed: Bool
    var pressTime: CFTimeInterval
}

class ButtonModifiers: NSObject {

    private var state = Dictionary<ButtonStateKey, ButtonState>()
    
    func update(device: Device, button: ButtonNumber, clickLevel: ClickLevel, downNotUp mouseDown: Bool) {
        
        /// Debug
        DDLogDebug("buttonModifiers - update - lvl: \(clickLevel), mouseDown: \(mouseDown), btn: \(button), dev: \"\(device.name())\"")
        
        /// Update state
        if mouseDown {
            let key = ButtonStateKey(device, button)
            let oldState = state[key]
            let pressTime = mouseDown ? CACurrentMediaTime() : (oldState?.pressTime ?? 0) /// Not sure if necessary to ever keep old pressTime
            let newState = ButtonState(device: device,
                                       button: button,
                                       clickLevel: clickLevel,
                                       isPressed: mouseDown,
                                       pressTime: pressTime)
            
            state[key] = newState
            /// Validate
            assert(oldState != newState)
            
        } else {
            state.removeValue(forKey: ButtonStateKey(device, button))
        }
        
        /// Notify change
        Modifiers.handleButtonModifiersMightHaveChanged(with: device)
    }
    
    func kill(device: Device, button: ButtonNumber) {
        
        /// Debug
        DDLogDebug("buttonModifiers - kill - btn: \(button), dev: \"\(device.name())\"")
        
        state.removeValue(forKey: ButtonStateKey(device, button))
    }
    
    func getActiveButtonModifiersForDevice(device: Device) -> [[String: Int]] {
        
        let buttonStates = Array(state.values)
        
        let result: [[String: Int]] = buttonStates.filter { bs in
            let isActive = bs.isPressed && bs.clickLevel != 0
            let isRightDevice = bs.device == device /// Was accidentally comparing bs.device.uniqueID with device here and Swift didn't say anything?
            return isActive && isRightDevice
        }.sorted { bs1, bs2 in
            bs1.pressTime < bs2.pressTime
        }.map { bs in
            return [
                kMFButtonModificationPreconditionKeyButtonNumber: bs.button,
                kMFButtonModificationPreconditionKeyClickLevel: bs.clickLevel
            ]
        }
        
        /// Debug
        DDLogDebug("buttonModifiers - gotMods for dev: \"\(device.name())\": \(result)")
        
        /// Return
        return result
    }
    
//    func getAnyDeviceWithPressedButtons() -> Device? {
//        /// Get the first device we find that has any pressed buttons
//        
//        for device: Device in DeviceManager.attachedDevices() {
//            for bs: ButtonState in state.values {
//                if bs.device == device && bs.isPressed {
//                    return device
//                }
//            }
//        }
//        return nil
//    }
    
}
