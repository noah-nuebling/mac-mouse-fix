//
// --------------------------------------------------------------------------
// Device.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import Cocoa
import IOKit.hid
import os.log

@objc(Device)
public class Device: NSObject {
    
    @objc public let iohidDevice: IOHIDDevice?
    
    fileprivate var _nOfButtons: Int = 0
    fileprivate var _isLogitechDiverted: Bool = false
    fileprivate var _supportsLogitechDPI: Bool = false
    fileprivate var _logitechBatteryPercentage: Int32 = -1
    fileprivate var _logitechBatteryStatus: Int32 = -1
    fileprivate var _logitechDPI: Int32 = -1
    
    @objc public var supportsLogitechHiResWheel: Bool = false
    @objc public var logitechHiResEnabled: Bool = false
    @objc public var supportsLogitechReportRate: Bool = false
    @objc public var logitechReportRate: UInt16 = 0
    
    fileprivate init(strange: ()) {
        self.iohidDevice = nil
        self._nOfButtons = 0
        super.init()
    }
    
    @objc(deviceWithRegistryID:)
    public static func device(withRegistryID registryID: UInt64) -> Device? {
        return Device(registryID: registryID)
    }
    
    @objc(initWithRegistryID:)
    public init?(registryID: UInt64) {
        let match = IORegistryEntryIDMatching(registryID)
        let port: mach_port_t
        if #available(macOS 12.0, *) {
            port = kIOMainPortDefault
        } else {
            port = kIOMasterPortDefault
        }
        let service = IOServiceGetMatchingService(port, match)
        if service == 0 {
            return nil
        }
        guard let dl = IOHIDDeviceCreate(kCFAllocatorDefault, service) else {
            return nil
        }
        
        self.iohidDevice = dl
        
        // Open device
        let ret = IOHIDDeviceOpen(dl, IOOptionBits(kIOHIDOptionsTypeNone))
        if ret != kIOReturnSuccess {
            DDLogError("Device: Error opening device. Code: \(String(format: "%x", ret))")
        }
        
        // Get max button number
        let matchDict = [kIOHIDElementUsagePageKey: kHIDPage_Button] as CFDictionary
        var maxButtonNumber = 0
        if let elements = IOHIDDeviceCopyMatchingElements(dl, matchDict, 0) as? [IOHIDElement] {
            for e in elements {
                let buttonNumber = IOHIDElementGetUsage(e)
                maxButtonNumber = max(maxButtonNumber, Int(buttonNumber))
            }
        }
        self._nOfButtons = maxButtonNumber
        
        super.init()
        
        #if IS_HELPER
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceScheduleWithRunLoop(dl, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceRegisterInputValueCallback(dl, handleInputCallback, selfPtr)
        #endif
    }
    
    @objc(deviceWithIOHIDDevice:)
    public static func device(with iohidDevice: IOHIDDevice) -> Device {
        return Device(iohidDevice: iohidDevice)
    }
    
    @objc(initWithIOHIDDevice:)
    public init(iohidDevice: IOHIDDevice) {
        self.iohidDevice = iohidDevice
        
        // Open device
        let ret = IOHIDDeviceOpen(iohidDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        if ret != kIOReturnSuccess {
            DDLogError("Device: Error opening device. Code: \(String(format: "%x", ret))")
        }
        
        // Get max button number
        let matchDict = [kIOHIDElementUsagePageKey: kHIDPage_Button] as CFDictionary
        var maxButtonNumber = 0
        if let elements = IOHIDDeviceCopyMatchingElements(iohidDevice, matchDict, 0) as? [IOHIDElement] {
            for e in elements {
                let buttonNumber = IOHIDElementGetUsage(e)
                maxButtonNumber = max(maxButtonNumber, Int(buttonNumber))
            }
        }
        self._nOfButtons = maxButtonNumber
        
        super.init()
        
        #if IS_HELPER
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceScheduleWithRunLoop(iohidDevice, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceRegisterInputValueCallback(iohidDevice, handleInputCallback, selfPtr)
        #endif
    }
    
    @objc(strange)
    public static func strange() -> Device {
        return StrangeDevice.shared
    }
    
    @objc(strangeDevice)
    public static func strangeDevice() -> Device {
        return strange()
    }
    
    @objc(uniqueID)
    public func uniqueID() -> NSNumber {
        guard let device = iohidDevice,
              let uid = IOHIDDeviceGetProperty(device, kIOHIDUniqueIDKey as CFString) as? NSNumber else {
            return 0
        }
        return uid
    }
    
    @objc(wrapsIOHIDDevice:)
    public func wrapsIOHIDDevice(_ otherIohidDevice: IOHIDDevice) -> Bool {
        guard let device = iohidDevice else { return false }
        let selfID = IOHIDDeviceGetProperty(device, kIOHIDUniqueIDKey as CFString) as? NSNumber
        let otherID = IOHIDDeviceGetProperty(otherIohidDevice, kIOHIDUniqueIDKey as CFString) as? NSNumber
        return selfID == otherID
    }
    
    @objc override public func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Device else { return false }
        if self === other { return true }
        
        guard let selfDL = self.iohidDevice, let otherDL = other.iohidDevice else {
            return false
        }
        
        return CFEqual(selfDL, otherDL)
    }
    
    @objc override public var hash: Int {
        return Int(bitPattern: Unmanaged.passUnretained(self).toOpaque())
    }
    
    @objc(name)
    public func name() -> String {
        guard let device = iohidDevice else { return "Strange Device" }
        return IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Strange Device"
    }
    
    @objc(manufacturer)
    public func manufacturer() -> String {
        guard let device = iohidDevice else { return "Unknown Manufacturer" }
        return IOHIDDeviceGetProperty(device, kIOHIDManufacturerKey as CFString) as? String ?? "Unknown Manufacturer"
    }
    
    @objc(nOfButtons)
    public func nOfButtons() -> Int {
        return _nOfButtons
    }
    
    @objc override public var description: String {
        guard let device = iohidDevice else {
            return "This device does not exist."
        }
        
        let product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? ""
        let manufacturer = IOHIDDeviceGetProperty(device, kIOHIDManufacturerKey as CFString) as? String ?? ""
        let usagePairs = IOHIDDeviceGetProperty(device, kIOHIDDeviceUsagePairsKey as CFString) as AnyObject? ?? "" as AnyObject
        let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as AnyObject? ?? 0 as AnyObject
        let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as AnyObject? ?? 0 as AnyObject
        
        return """
        Device Info:
            Product: \(product)
            Manufacturer: \(manufacturer)
            nOfButtons: \(nOfButtons())
            UsagePairs: \(usagePairs)
            ProductID: \(productID)
            VendorID: \(vendorID)
        """
    }
    
    // MARK: - Sibling matching properties
    
    @objc public var isLogitechDiverted: Bool {
        get {
            if _isLogitechDiverted {
                return true
            }
            if let device = iohidDevice {
                let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
                if vid?.intValue == 0x046D { // Logitech
                    for d in DeviceManager.attachedDevices() {
                        if isSiblingDevice(self, d) && d._isLogitechDiverted {
                            return true
                        }
                    }
                }
            }
            return false
        }
        set {
            if _isLogitechDiverted != newValue {
                _isLogitechDiverted = newValue
            }
            if let device = iohidDevice {
                let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
                if vid?.intValue == 0x046D { // Logitech
                    for d in DeviceManager.attachedDevices() {
                        if isSiblingDevice(self, d) && d._isLogitechDiverted != newValue {
                            d._isLogitechDiverted = newValue
                        }
                    }
                }
            }
            #if IS_HELPER
            PointerSpeed.setForAllDevices()
            #endif
        }
    }
    
    @objc public var supportsLogitechDPI: Bool {
        get {
            if _supportsLogitechDPI {
                return true
            }
            if let device = iohidDevice {
                let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
                if vid?.intValue == 0x046D { // Logitech
                    for d in DeviceManager.attachedDevices() {
                        if isSiblingDevice(self, d) && d._supportsLogitechDPI {
                            return true
                        }
                    }
                }
            }
            return false
        }
        set {
            if _supportsLogitechDPI != newValue {
                _supportsLogitechDPI = newValue
            }
            if let device = iohidDevice {
                let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
                if vid?.intValue == 0x046D { // Logitech
                    for d in DeviceManager.attachedDevices() {
                        if isSiblingDevice(self, d) && d._supportsLogitechDPI != newValue {
                            d._supportsLogitechDPI = newValue
                        }
                    }
                }
            }
            #if IS_HELPER
            PointerSpeed.setForAllDevices()
            #endif
        }
    }
    
    @objc public var logitechDPI: Int32 {
        get {
            if _logitechDPI != -1 {
                return _logitechDPI
            }
            if let device = iohidDevice {
                let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
                if vid?.intValue == 0x046D { // Logitech
                    for d in DeviceManager.attachedDevices() {
                        if isSiblingDevice(self, d) && d._logitechDPI != -1 {
                            return d._logitechDPI
                        }
                    }
                }
            }
            return -1
        }
        set {
            _logitechDPI = newValue
            if let device = iohidDevice {
                let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
                if vid?.intValue == 0x046D { // Logitech
                    for d in DeviceManager.attachedDevices() {
                        if isSiblingDevice(self, d) && d._logitechDPI != newValue {
                            d._logitechDPI = newValue
                        }
                    }
                }
            }
        }
    }
    
    @objc public var logitechBatteryPercentage: Int32 {
        get {
            if _logitechBatteryPercentage != -1 {
                return _logitechBatteryPercentage
            }
            if let device = iohidDevice {
                let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
                if vid?.intValue == 0x046D { // Logitech
                    for d in DeviceManager.attachedDevices() {
                        if isSiblingDevice(self, d) && d._logitechBatteryPercentage != -1 {
                            return d._logitechBatteryPercentage
                        }
                    }
                }
            }
            return -1
        }
        set {
            _logitechBatteryPercentage = newValue
            if let device = iohidDevice {
                let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
                if vid?.intValue == 0x046D { // Logitech
                    for d in DeviceManager.attachedDevices() {
                        if isSiblingDevice(self, d) && d._logitechBatteryPercentage != newValue {
                            d._logitechBatteryPercentage = newValue
                        }
                    }
                }
            }
        }
    }
    
    @objc public var logitechBatteryStatus: Int32 {
        get {
            if _logitechBatteryStatus != -1 {
                return _logitechBatteryStatus
            }
            if let device = iohidDevice {
                let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
                if vid?.intValue == 0x046D { // Logitech
                    for d in DeviceManager.attachedDevices() {
                        if isSiblingDevice(self, d) && d._logitechBatteryStatus != -1 {
                            return d._logitechBatteryStatus
                        }
                    }
                }
            }
            return -1
        }
        set {
            _logitechBatteryStatus = newValue
            if let device = iohidDevice {
                let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
                if vid?.intValue == 0x046D { // Logitech
                    for d in DeviceManager.attachedDevices() {
                        if isSiblingDevice(self, d) && d._logitechBatteryStatus != newValue {
                            d._logitechBatteryStatus = newValue
                        }
                    }
                }
            }
        }
    }
}

// MARK: - StrangeDevice Subclass

@objc(StrangeDevice)
public class StrangeDevice: Device {
    @objc public static let shared = StrangeDevice()
    
    private init() {
        super.init(strange: ())
    }
    
    @objc override public init(iohidDevice: IOHIDDevice) {
        fatalError("StrangeDevice cannot be initialized with IOHIDDevice")
    }
    
    @objc override public init?(registryID: UInt64) {
        fatalError("StrangeDevice cannot be initialized with registryID")
    }
    
    override public func uniqueID() -> NSNumber {
        return 0
    }
    
    override public func wrapsIOHIDDevice(_ otherIohidDevice: IOHIDDevice) -> Bool {
        return false
    }
    
    override public func name() -> String {
        return "Strange Device"
    }
    
    override public func manufacturer() -> String {
        return "Unknown Manufacturer"
    }
    
    override public func nOfButtons() -> Int {
        return 0
    }
    
    override public var description: String {
        return "This device does not exist."
    }
}

// MARK: - Helper Functions

fileprivate func isSiblingDevice(_ selfDevice: Device, _ otherDevice: Device) -> Bool {
    if selfDevice === otherDevice { return false }
    guard let selfDL = selfDevice.iohidDevice, let otherDL = otherDevice.iohidDevice else { return false }
    
    let selfVid = IOHIDDeviceGetProperty(selfDL, kIOHIDVendorIDKey as CFString) as? NSNumber
    let otherVid = IOHIDDeviceGetProperty(otherDL, kIOHIDVendorIDKey as CFString) as? NSNumber
    if selfVid == nil || otherVid == nil || selfVid!.intValue != otherVid!.intValue {
        return false
    }
    
    let selfPid = IOHIDDeviceGetProperty(selfDL, kIOHIDProductIDKey as CFString) as? NSNumber
    let otherPid = IOHIDDeviceGetProperty(otherDL, kIOHIDProductIDKey as CFString) as? NSNumber
    if selfPid == nil || otherPid == nil || selfPid! != otherPid! {
        return false
    }
    
    let selfName = IOHIDDeviceGetProperty(selfDL, kIOHIDProductKey as CFString) as? String
    let otherName = IOHIDDeviceGetProperty(otherDL, kIOHIDProductKey as CFString) as? String
    if selfName != nil && otherName != nil && selfName! == otherName! {
        return true
    }
    
    return false
}

// MARK: - Input Callbacks

#if IS_HELPER

fileprivate let logiValueToButton: [Int: MFMouseButtonNumber] = [
    83: MFMouseButtonNumber(4),
    86: MFMouseButtonNumber(5),
    196: MFMouseButtonNumber(6),
    1052927: MFMouseButtonNumber(6),
    82: MFMouseButtonNumber(7)
]
fileprivate var logiButtonsDown = Set<MFMouseButtonNumber>()

fileprivate func postVirtualButtonEvent(_ button: MFMouseButtonNumber, _ down: Bool) {
    let tapLoc = CGEventTapLocation.cghidEventTap
    guard let ourEvent = CGEvent(source: nil) else { return }
    let mouseLoc = ourEvent.location
    
    let eventType = SharedUtility.cgEventType(for: button, isMouseDown: down)
    let buttonCG = SharedUtility.cgMouseButton(from: button)
    
    guard let event = CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: mouseLoc, mouseButton: buttonCG) else { return }
    
    event.setIntegerValueField(CGEventField.mouseEventClickState, value: 1)
    
    if button.rawValue >= 4 {
        event.setIntegerValueField(CGEventField.mouseEventButtonNumber, value: Int64(button.rawValue - 1))
    }
    
    event.post(tap: tapLoc)
}

private let handleInputCallback: IOHIDValueCallback = { context, result, sender, value in
    guard let context = context else { return }
    let sendingDev = Unmanaged<Device>.fromOpaque(context).takeUnretainedValue()
    
    let elem = IOHIDValueGetElement(value)
    let usage = IOHIDElementGetUsage(elem)
    let usagePage = IOHIDElementGetUsagePage(elem)
    let integerValue = IOHIDValueGetIntegerValue(value)
    
    if usagePage == 65347 && !sendingDev.isLogitechDiverted {
        if integerValue == 0 {
            for button in logiButtonsDown {
                postVirtualButtonEvent(button, false)
            }
            logiButtonsDown.removeAll()
        } else {
            if let button = logiValueToButton[integerValue] {
                for pressedButton in logiButtonsDown {
                    if pressedButton != button {
                        postVirtualButtonEvent(pressedButton, false)
                        logiButtonsDown.remove(pressedButton)
                    }
                }
                if !logiButtonsDown.contains(button) {
                    logiButtonsDown.insert(button)
                    postVirtualButtonEvent(button, true)
                }
            }
        }
    }
    
    if usagePage == 9 && usage == 1 && integerValue != 0 {
        GestureScrollSimulator.stopMomentumScroll()
    }
    
    if usagePage == 9 && (usage == 4 || usage == 5) && integerValue != 0 {
        if let device = sendingDev.iohidDevice {
            let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
            if vid?.intValue == 0x046D {
                DDLogInfo("Device: Detected native side button press (usage: \(usage)) on Logitech device. Volatile config lost? Triggering immediate reactivation...")
                sendingDev.isLogitechDiverted = false
                DispatchQueue.main.async {
                    LogitechActivator.shared.reactivateDeviceWithIOHIDDevice(device)
                }
            }
        }
    }
}

#endif
