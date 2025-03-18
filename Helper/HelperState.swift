//
// --------------------------------------------------------------------------
// HelperState.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// This class holds global state. Use sparingly!

import Foundation
import CoreGraphics

@objc class HelperState: NSObject {
    
    // MARK: Singleton & init
    @objc static let shared = HelperState()
    override init() {
        super.init()
        initUserIsActive()
        DispatchQueue.main.async { /// Need to do this to avoid strange Swift crashes when this is triggered from `SwitchMaster.load_Manual()`
            SwitchMaster.shared.helperStateChanged()
        }
    }
    
    // MARK: Fast user switching
    /// See Apple Docs at: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPMultipleUsers/Concepts/FastUserSwitching.html#//apple_ref/doc/uid/20002209-104219-BAJJIFCB
    
    var userIsActive: Bool = false
    func initUserIsActive() {
        
        /// Init userIsActive
        userIsActive = userIsActive_Manual()
        
        /// Listen to user switches and update userIsActive
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: nil) { notification in
            self.userIsActive = true
            assert(self.userIsActive_Manual() == self.userIsActive)
            SwitchMaster.shared.helperStateChanged()
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: nil) { notification in
            self.userIsActive = false
            assert(self.userIsActive_Manual() == self.userIsActive)
            SwitchMaster.shared.helperStateChanged()
        }
        
    }
    
    private func userIsActive_Manual() -> Bool {
        /// For debugging and stuff
        guard let d = CGSessionCopyCurrentDictionary() as NSDictionary? else { return false }
        guard let result = d.value(forKey: kCGSessionOnConsoleKey) as? Bool else { return false } /// [Mar 2025] why 'kCGSessionOnConsoleKey'? – that's weird... Here's an SO post that also mentions this: https://stackoverflow.com/a/8790102/10601702
        return result
    }
    
    // MARK: Active device
    /// Might be more appropriate to have this as part of DeviceManager
    
    private var _activeDevice: Device? = nil
    @objc var activeDevice: Device? {
        set {
            _activeDevice = newValue
            SwitchMaster.shared.helperStateChanged()
        }
        get {
            if _activeDevice != nil {
                return _activeDevice
            } else { /// Just return any attached device as a fallback
                /// NOTE: Swift let me do `attachedDevices.first` (even thought that's not defined on NSArray) without a compiler warning which did return a Device? but the as! Device? cast still crashed. Using `attachedDevices.firstObject` it doesn't crash.
                return DeviceManager.attachedDevices.firstObject as! Device?
            }
        }
    }
    
    @objc func updateActiveDevice(event: CGEvent) {
        guard let iohidDevice = CGEventGetSendingDevice(event)?.takeUnretainedValue() else { return }
        updateActiveDevice(IOHIDDevice: iohidDevice)
    }
    @objc func updateActiveDevice(eventSenderID: UInt64) {
        guard let iohidDevice = getSendingDeviceWithSenderID(eventSenderID)?.takeUnretainedValue() else { return }
        updateActiveDevice(IOHIDDevice: iohidDevice)
    }
    @objc func updateActiveDevice(IOHIDDevice: IOHIDDevice) {
        guard let device = DeviceManager.attachedDevice(with: IOHIDDevice) else { return }
        activeDevice = device
    }
}
