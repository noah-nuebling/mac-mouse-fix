//
// --------------------------------------------------------------------------
// ButtonInputReceiver.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa
import ApplicationServices

@objc public enum MFEventPassThroughEvaluation: Int {
    case approval = 0 // kMFEventPassThroughApproval
    case refusal = 1  // kMFEventPassThroughRefusal
}

@objc public enum MFButtonInputType: Int {
    case buttonDown = 0 // kMFButtonInputTypeButtonDown
    case buttonUp = 1   // kMFButtonInputTypeButtonUp
}

@objc public enum MFActionTriggerType: Int {
    case none = -1 // kMFActionTriggerTypeNone
    case buttonDown = 0 // kMFActionTriggerTypeButtonDown
    case buttonUp = 1 // kMFActionTriggerTypeButtonUp
    case holdTimerExpired = 2 // kMFActionTriggerTypeHoldTimerExpired
    case levelTimerExpired = 3 // kMFActionTriggerTypeLevelTimerExpired
}

private let eventTapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
    
    // Re-enable on timeout
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        DDLogDebug("ButtonInputReceiver eventTap was disabled by \(type == .tapDisabledByTimeout ? "timeout. Re-enabling." : "user input.")")
        if type == .tapDisabledByTimeout {
            if let tap = ButtonInputReceiver.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }
    
    // Pass through left/right click and key events immediately so we don't interfere
    if type == .leftMouseDown || type == .leftMouseUp ||
       type == .rightMouseDown || type == .rightMouseUp ||
       type == .keyDown || type == .keyUp {
        return Unmanaged.passUnretained(event)
    }
    
    // Debug print
    if runningPreRelease() {
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber) + 1
        if buttonNumber != 1 && buttonNumber != 2 {
            if let nsEvent = NSEvent(cgEvent: event) {
                DDLogDebug("Received CG Button Input - \(nsEvent)")
            }
        }
    }
    
    // Main logic
    let buttonNumber = Int(event.getIntegerValueField(.mouseEventButtonNumber) + 1)
    var mouseDown = false
    
    if type == .otherMouseDown || type == .leftMouseDown || type == .rightMouseDown {
        mouseDown = true
    } else if type == .otherMouseUp || type == .leftMouseUp || type == .rightMouseUp {
        mouseDown = false
    } else {
        mouseDown = event.getIntegerValueField(.mouseEventPressure) != 0
    }
    
    // Filter buttons (left and right click are ignored)
    if buttonNumber == 1 || buttonNumber == 2 {
        return Unmanaged.passUnretained(event)
    }
    
    // Debug print
    if let nsEvent = NSEvent(cgEvent: event) {
        DDLogDebug("Input Receiver - Received event: \(nsEvent.description)")
    }
    
    // Get device
    let iohidDevice: IOHIDDevice? = CGEventGetSendingDevice(event)?.takeUnretainedValue()
    var device: Device? = nil
    if let dev = iohidDevice {
        device = DeviceManager.attachedDevice(with: dev)
    }
    
    if device == nil {
        device = HelperState.shared.activeDevice
    }
    
    if device == nil {
        #if IS_HELPER
        device = Device.strangeDevice()
        #else
        if iohidDevice == nil {
            if let nsEvent = NSEvent(cgEvent: event) {
                DDLogDebug("Input Receiver - Couldn't determine sending device for event. Letting the event pass through. Event description: \(nsEvent)")
            }
        } else if device == nil {
            if let nsEvent = NSEvent(cgEvent: event) {
                DDLogDebug("Input Receiver - Sending device is not among attached devices. Letting the event pass through. Event description: \(nsEvent)")
            }
        }
        return Unmanaged.passUnretained(event)
        #endif
    }
    
    DDLogDebug("Input Receiver - Device for CG Button Input - iohidDevice: \(String(describing: iohidDevice)), device: \(String(describing: device))")
    
    // Pass to buttonInput processor
    let eval = Buttons.handleInput(device: device!, button: NSNumber(value: buttonNumber), downNotUp: mouseDown, event: event)
    
    if eval == .refusal {
        return nil
    } else {
        DDLogDebug("... letting event pass through")
        return Unmanaged.passUnretained(event)
    }
}

@objc(ButtonInputReceiver)
public class ButtonInputReceiver: NSObject {
    
    fileprivate static var _eventTap: CFMachPort?
    @objc public static var eventTap: CFMachPort? {
        return _eventTap
    }
    
    @objc public static func load_Manual() {
        registerInputCallback()
    }
    
    @objc public static func start() {
        if let tap = _eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    @objc public static func stop() {
        if let tap = _eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }
    
    @objc public static func isRunning() -> Bool {
        if let tap = _eventTap {
            return CGEvent.tapIsEnabled(tap: tap)
        }
        return false
    }
    
    private static func registerInputCallback() {
        var mask: CGEventMask = 0
        let eventTypes: [CGEventType] = [
            .otherMouseDown, .otherMouseUp,
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .keyDown, .keyUp
        ]
        for type in eventTypes {
            let shift = UInt64(type.rawValue)
            mask |= (1 << shift)
        }
        
        _eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: nil
        )
        
        if _eventTap == nil {
            DDLogError("ButtonInputReceiver - Failed to create event tap! (Accessibility permissions might be missing)")
        } else {
            DDLogInfo("ButtonInputReceiver - Successfully created event tap: \(String(describing: _eventTap))")
            
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
    }
}
