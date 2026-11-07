//
// --------------------------------------------------------------------------
// HelperState.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// This class holds global state. Use sparingly!

/// [Sep 2026] `readsAndWritesState()` checks not necessary since
///     - State is too simple to corrupt (only one var per thing, nothing has invariants)
///     - We're also calling out at the end of updates and stuff [Sep 2026]

import Foundation
import CoreGraphics

@objc class HelperState: NSObject {
    
    // MARK: Singleton & init
    @objc static let shared = HelperState()
    override init() {
        super.init()
        initUserIsActive()
        mfrun(IOThread.runLoop()) { /// [Sep 2026] Can't call non-deferred since it causes HelperState.shared -> HelperState.init -> HelperState.shared recursion which deadlocks or whatever. Been this way before [Sep 2026] 'No more dispatch queues' refactor, so should be fine.
            SwitchMaster_HelperStateChanged();
        }
    }
    
    // MARK: Fast user switching
    /// See Apple Docs at: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPMultipleUsers/Concepts/FastUserSwitching.html#//apple_ref/doc/uid/20002209-104219-BAJJIFCB

    private var _lock = os_unfair_lock()

    private var _userIsActive: Bool = true
    @objc private(set) var userIsActive: Bool {
        get {
            os_unfair_lock_lock(&_lock)
            defer { os_unfair_lock_unlock(&_lock) }
            return _userIsActive
        }
        set {
            os_unfair_lock_lock(&_lock)
            _userIsActive = newValue
            os_unfair_lock_unlock(&_lock)
        }
    }
    private func initUserIsActive() {
        
        /// Init userIsActive
        userIsActive = userIsActive_Uncached()
        
        /// Listen to user switches and update userIsActive
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: nil) { notification in
            mfrun(IOThread.runLoop()) {
                self.userIsActive = true
                mfassert(self.userIsActive_Uncached() == self.userIsActive)
                SwitchMaster_HelperStateChanged()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: nil) { notification in
            mfrun(IOThread.runLoop()) {
                self.userIsActive = false
                mfassert(self.userIsActive_Uncached() == self.userIsActive)
                SwitchMaster_HelperStateChanged()
            }
        }
        
    }
    
    private func userIsActive_Uncached() -> Bool { /// Load `userIsActive` value directly from system
        guard let d = CGSessionCopyCurrentDictionary() as NSDictionary? else { return false }
        guard let result = d.value(forKey: kCGSessionOnConsoleKey) as? Bool else { return false } /// [Mar 2025] why 'kCGSessionOnConsoleKey'? – that's weird... Here's an SO post that also mentions this: https://stackoverflow.com/a/8790102/10601702
        return result
    }
    
    // MARK: Active device
    /// Might be more appropriate to have this as part of DeviceManager
    
    private var _activeDevice: Device? = nil
    @objc private(set) var activeDevice: Device? {
        set {
            os_unfair_lock_lock(&_lock)
            _activeDevice = newValue
            os_unfair_lock_unlock(&_lock)
            SwitchMaster_HelperStateChanged()
        }
        get {
            os_unfair_lock_lock(&_lock)
            let dev = _activeDevice
            os_unfair_lock_unlock(&_lock)
            if dev != nil {
                return dev
            } else { /// Just return any attached device as a fallback
                return DeviceManager.attachedDevices().first
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
    @objc private func updateActiveDevice(IOHIDDevice: IOHIDDevice) {
        guard let device = DeviceManager.attachedDevice(with: IOHIDDevice) else { return }
        activeDevice = device
    }
}
