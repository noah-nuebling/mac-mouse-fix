//
// --------------------------------------------------------------------------
// ButtonModifiers.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

struct ButtonStateKey: Hashable {
    
    /// Swift doesn't allow using tuples as Dictionary keys, so we have to do this instead

    let device: Device
    let button: ButtonNumber

    init(_ device: Device, _ button: ButtonNumber) {
        self.device = device
        self.button = button
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.device)
        hasher.combine(self.button)
    }

    static func ==(lhs: ButtonStateKey, rhs: ButtonStateKey) -> Bool {
        return lhs.device == rhs.device && lhs.button == rhs.button
    }
}

private struct ButtonState: Equatable {
    var device: Device
    var button: ButtonNumber
    var clickLevel: ClickLevel
    var isPressed: Bool
    var pressTime: CFTimeInterval
//    var isZombified: Bool
}

class ButtonModifiers: NSObject {

    private var state = Dictionary<ButtonStateKey, ButtonState>()
    
    @objc func update(device: Device, button: ButtonNumber, clickLevel: ClickLevel, downNotUp mouseDown: Bool) {
        
        let key = ButtonStateKey(device, button)
        let oldState = state[key]
        let pressTime = mouseDown ? CACurrentMediaTime() : (oldState?.pressTime ?? 0) /// Not sure if necessary to ever keep old pressTime
        let newState = ButtonState(device: device,
                                   button: button,
                                   clickLevel: clickLevel,
                                   isPressed: mouseDown,
                                   pressTime: pressTime)
        
        assert(oldState != newState)
        
        state[key] = newState
        ModifierManager.handleButtonModifiersMightHaveChanged(with: device)
    }
    
    @objc func kill(device: Device, button: ButtonNumber) {
        update(device: device, button: button, clickLevel: -1, downNotUp: false)
    }
    
    @objc func getActiveButtonModifiersForDevice(devIDPtr: UnsafeMutablePointer<NSNumber?>) -> [[String: Int]] {
        /// Objc compatibility wrapper
        
        var devID = devIDPtr.pointee
        let result = getActiveButtonModifiersForDevice(devID: &devID)
        devIDPtr.pointee = devID
        return result
    }
    
    func getActiveButtonModifiersForDevice(devID: inout NSNumber?) -> [[String: Int]] {
        /// When passing in nil for the devID, this function will try to find a device with pressed buttons and use that. It will also write that device to the `devID` argument
        
        /// get device
        if devID == nil {
            devID = getAnyDeviceWithPressedButtons()?.uniqueID()
        }
        
        /// Get result
        let buttonStates = state.values
        let result: [[String: Int]] = buttonStates.filter { bs in
            let isActive = bs.isPressed && bs.clickLevel != 0
            let isRightDevice = bs.device.uniqueID() == devID
            return isActive && isRightDevice
        }.sorted { bs1, bs2 in
            bs1.pressTime < bs2.pressTime
        }.map { bs in
            return [
                kMFButtonModificationPreconditionKeyButtonNumber: bs.button,
                kMFButtonModificationPreconditionKeyClickLevel: bs.clickLevel
            ]
        }
        
        /// Return
        return result
    }
    
    func getAnyDeviceWithPressedButtons() -> Device? {
        /// Get the first device we find that has any pressed buttons
        
        for device: Device in DeviceManager.attachedDevices() {
            for bs: ButtonState in state.values {
                if bs.device == device && bs.isPressed {
                    return device
                }
            }
        }
        return nil
    }
    
}
