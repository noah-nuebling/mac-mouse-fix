//
// --------------------------------------------------------------------------
// DeviceManager.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import Cocoa
import IOKit.hid

@objc(DeviceManager)
public class DeviceManager: NSObject {
    
    fileprivate static var _attachedDevices: [Device] = []
    fileprivate static var _manager: IOHIDManager?
    fileprivate static var _maxButtonNumberAmongDevices_IsCached = false
    fileprivate static var _maxButtonNumberAmongDevices: Int32 = 0
    fileprivate static var _eventTypesSupportedBySomeDevice_IsCached = false
    fileprivate static var _eventTypesSupportedBySomeDevice: MFEventType = 0
    
    @objc public static func eventTypesSupportedBySomeDevice() -> MFEventType {
        if _eventTypesSupportedBySomeDevice_IsCached {
            return _eventTypesSupportedBySomeDevice
        }
        var result: MFEventType = 0
        if _attachedDevices.count > 0 {
            result |= MFEventType(kMFEventType_ScrollWheel)
            result |= MFEventType(kMFEventType_Sensor)
            var maxButtons = 0
            for device in _attachedDevices {
                let n = Int(device.nOfButtons())
                if n > maxButtons { maxButtons = n }
            }
            let buttonLimit = min(maxButtons, Int(kMFMaxButtonNumber))
            for i in 0..<buttonLimit {
                if let cgBtn = CGMouseButton(rawValue: UInt32(i)) {
                    result |= MFEventType_Button(cgBtn)
                }
            }
        }
        _eventTypesSupportedBySomeDevice = result
        _eventTypesSupportedBySomeDevice_IsCached = true
        return result
    }
    
    @objc public static func devicesAreAttached() -> Bool {
        return _attachedDevices.count > 0
    }
    
    @objc(attachedDevices)
    public static func attachedDevices() -> [Device] {
        return _attachedDevices
    }
    
    @objc(__SWIFT_UNBRIDGED_attachedDevices)
    public static func __SWIFT_UNBRIDGED_attachedDevices() -> [Device] {
        return _attachedDevices
    }
    
    @objc(attachedDeviceWithIOHIDDevice:)
    public static func attachedDevice(with iohidDevice: IOHIDDevice) -> Device? {
        for device in _attachedDevices {
            if device.wrapsIOHIDDevice(iohidDevice) {
                return device
            }
        }
        return nil
    }
    
    @objc(load_Manual)
    public static func load_Manual() {
        setupDeviceMatchingAndRemovalCallbacks()
        _attachedDevices = []
    }
    
    @objc(deconfigureDevices)
    public static func deconfigureDevices() {
        #if IS_HELPER
        for device in _attachedDevices {
            if let dl = device.iohidDevice {
                PointerSpeed.deconfigureDevice(dl)
            }
        }
        #endif
    }
    
    @objc public static func someDeviceHasScrollWheel() -> Bool {
        return _attachedDevices.count > 0
    }
    
    @objc public static func someDeviceHasPointing() -> Bool {
        return _attachedDevices.count > 0
    }
    
    @objc public static func someDeviceHasUsableButtons() -> Bool {
        return maxButtonNumberAmongDevices() > 2
    }
    
    @objc(maxButtonNumberAmongDevices)
    public static func maxButtonNumberAmongDevices() -> Int32 {
        if _maxButtonNumberAmongDevices_IsCached {
            return _maxButtonNumberAmongDevices
        } else {
            var result: Int32 = 0
            for device in _attachedDevices {
                let b = Int32(device.nOfButtons())
                if b > result {
                    result = b
                }
            }
            _maxButtonNumberAmongDevices = result
            _maxButtonNumberAmongDevices_IsCached = true
            return result
        }
    }
    
    fileprivate static func setupDeviceMatchingAndRemovalCallbacks() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        _manager = manager
        
        let matchDict1: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse,
            kIOHIDTransportKey: kIOHIDTransportUSBValue
        ]
        let matchDict2: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse,
            kIOHIDTransportKey: kIOHIDTransportBluetoothValue
        ]
        let matchDict3: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse,
            kIOHIDTransportKey: "Bluetooth Low Energy"
        ]
        
        let matchArray = [matchDict1, matchDict2, matchDict3] as CFArray
        
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchArray)
        #if IS_HELPER
        IOHIDManagerScheduleWithRunLoop(manager, IOThread.runLoop(), CFRunLoopMode.commonModes.rawValue)
        #else
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        #endif
        
        IOHIDManagerRegisterDeviceMatchingCallback(manager, handleDeviceMatchingCallback, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, handleDeviceRemovalCallback, nil)
    }
}

// MARK: - Callbacks

private let handleDeviceMatchingCallback: IOHIDDeviceCallback = { context, result, sender, device in
    DDLogDebug("New matching IOHIDDevice: \(device)")
    
    if devicePassesFiltering(device) {
        let newDevice = Device.device(with: device)
        
        DeviceManager._attachedDevices.append(newDevice)
        DeviceManager._maxButtonNumberAmongDevices_IsCached = false
        DeviceManager._eventTypesSupportedBySomeDevice_IsCached = false
        
        #if IS_HELPER
        SwitchMaster.attachedDevicesChanged(DeviceManager._attachedDevices as NSArray)
        #endif
        
        DDLogDebug("Setting PointerSpeed for device: \(newDevice.description)")
        #if IS_HELPER
        PointerSpeed.setFor(device)
        #endif
        
        #if IS_HELPER
        LogitechActivator.shared.handleDeviceAttached(device)
        #endif
        
        DDLogInfo("New device added to attached devices:\n\(newDevice)")
    } else {
        DDLogInfo("New matching IOHIDDevice device didn't pass filtering")
    }
    
    DDLogDebug("\(debugInfo())")
}

private let handleDeviceRemovalCallback: IOHIDDeviceCallback = { context, result, sender, device in
    if let attachedDevice = DeviceManager.attachedDevice(with: device) {
        if let index = DeviceManager._attachedDevices.firstIndex(of: attachedDevice) {
            DeviceManager._attachedDevices.remove(at: index)
        }
        
        DeviceManager._maxButtonNumberAmongDevices_IsCached = false
        DeviceManager._eventTypesSupportedBySomeDevice_IsCached = false
        
        #if IS_HELPER
        SwitchMaster.attachedDevicesChanged(DeviceManager._attachedDevices as NSArray)
        #endif
        
        #if IS_HELPER
        LogitechActivator.shared.handleDeviceRemoved(device)
        Buttons.resetAll()
        Device.resetLogitechButtons()
        ModifiedDrag.deactivate()
        #endif
        
        DDLogInfo("Attached device was removed:\n\(attachedDevice)")
        DDLogDebug("Device Manager state after removal \(debugInfo())")
    } else {
        DDLogDebug("Device was removed but it wasn't attached to Mac Mouse Fix: \(device)")
    }
}

// MARK: - Helper Functions

fileprivate func devicePassesFiltering(_ device: IOHIDDevice) -> Bool {
    let deviceName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? ""
    let deviceVendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
    
    if deviceName == "Apple Internal Keyboard / Trackpad" {
        return false
    }
    if deviceVendorID?.intValue == 1452 { // Apple
        return false
    }
    return true
}

fileprivate func debugInfo() -> String {
    let relevantDevices = "Relevant devices:\n\(DeviceManager._attachedDevices)"
    let devices = IOHIDManagerCopyDevices(DeviceManager._manager!)
    let matchingDevices = "Matching devices: \(String(describing: devices))"
    
    return "\(relevantDevices)\n\(matchingDevices)\n"
}
