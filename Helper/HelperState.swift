//
// --------------------------------------------------------------------------
// HelperState.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

/// This class holds global state. Use sparingly!

import Foundation

@objc class HelperState: NSObject {
    
    // MARK: Active device
    /// Might be more appropriate to have this as part of DeviceManager
    
    private static var _activeDevice: Device? = nil
    @objc static var activeDevice: Device? {
        set {
            _activeDevice = newValue
        }
        get {
            if _activeDevice != nil {
                return _activeDevice
            } else { /// Just return any attached device as a fallback
                return DeviceManager.attachedDevices.first as! Device?
            }
        }
    }
    
    @objc static func updateActiveDevice(event: CGEvent) {
        guard let iohidDevice = CGEventGetSendingDevice(event)?.takeUnretainedValue() else { return }
        updateActiveDevice(IOHIDDevice: iohidDevice)
    }
    @objc static func updateActiveDevice(eventSenderID: UInt64) {
        guard let iohidDevice = getSendingDeviceWithSenderID(eventSenderID)?.takeUnretainedValue() else { return }
        updateActiveDevice(IOHIDDevice: iohidDevice)
    }
    @objc static func updateActiveDevice(IOHIDDevice: IOHIDDevice) {
        guard let device = DeviceManager.attachedDevice(with: IOHIDDevice) else { return }
        activeDevice = device
    }
    
    // MARK: Lockdown state
    
    @objc static var isLockedDown = false /// Don't write to this directly, use lockDown() instead
    @objc static func lockDown() {
        
        /// Set flag
        isLockedDown = true
        
        /// Notify input processing modules
        ///     Note: We don't need to lock down `ModifiedDrag.m`, because it only does anything when a modification becomes active. And we turn off all modifications via Remap.m.
        Remap.reload()
        ScrollConfig.reload() /// Not sure if necessary
    }
}
