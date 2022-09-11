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
    
    @objc static var activeDevice: Device? = nil
    
    @objc static func updateActiveDevice(event: CGEvent) {
        guard let iohidDevice = CGEventGetSendingDevice(event)?.takeUnretainedValue() else { return }
        updateActiveDevice(IOHIDDevice: iohidDevice)
    }
    @objc static func updateActiveDevice(IOHIDDevice: IOHIDDevice) {
        guard let device = DeviceManager.attachedDevice(with: IOHIDDevice) else { return }
        activeDevice = device
    }
    
    @objc static var isLockedDown = false /// Don't write to this directly, use lockDown() instead
    @objc static func lockDown() {
        
        /// Set flag
        isLockedDown = true
        
        /// Notify input processing modules
        ///     Note: We don't need to lock down `ModifiedDrag.m`, because it only does anything when a modification becomes active. And we turn off all modifications via TransformationManager.m.
        TransformationManager.reload()
        ScrollConfig.reload() /// Not sure if necessary
    }
}
