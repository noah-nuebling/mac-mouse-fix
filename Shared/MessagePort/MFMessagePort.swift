//
// --------------------------------------------------------------------------
// MFMessagePort.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import Cocoa
import IOKit.hid

fileprivate let kMFBundleIDApp = "com.nuebling.mac-mouse-fix"
fileprivate let kMFBundleIDHelper = "com.nuebling.mac-mouse-fix.helper"
fileprivate let kMFMessageKeyMessage = "message"
fileprivate let kMFMessageKeyPayload = "payload"
fileprivate let kMFHelperName = "Mac Mouse Fix Helper"

#if IS_HELPER
fileprivate func currentLogitechDevice() -> Device? {
    if let dev = HelperState.shared.activeDevice {
        if let deviceDL = dev.iohidDevice {
            let vid = IOHIDDeviceGetProperty(deviceDL, kIOHIDVendorIDKey as CFString) as? NSNumber
            if vid?.intValue == 0x046D {
                return dev
            }
        }
    }
    for attachedDevice in DeviceManager.attachedDevices() {
        if let deviceDL = attachedDevice.iohidDevice {
            let vid = IOHIDDeviceGetProperty(deviceDL, kIOHIDVendorIDKey as CFString) as? NSNumber
            if vid?.intValue == 0x046D {
                return attachedDevice
            }
        }
    }
    return nil
}
#endif

private let invalidationCallback: CFMessagePortInvalidationCallBack = { port, info in
    DDLogInfo("Remote MessagePort invalidated in \(runningHelper() ? "Helper" : "MainApp")")
}

private let didReceiveMessageCallback: CFMessagePortCallBack = { port, messageID, data, info in
    assert(runningMainApp() || runningHelper())
    
    guard let dataRef = data else { return nil }
    let dataSwift = dataRef as Data
    
    let decoded: Any?
    do {
        if #available(macOS 10.13, *) {
            decoded = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSString.self, NSNumber.self, NSSet.self, NSArray.self, NSURL.self], from: dataSwift)
        } else {
            decoded = NSKeyedUnarchiver.unarchiveObject(with: dataSwift)
        }
    } catch {
        DDLogError("MFMessagePort: Failed to decode message data: \(error)")
        return nil
    }
    
    guard let messageDict = decoded as? [String: Any],
          let message = messageDict[kMFMessageKeyMessage] as? String else {
        return nil
    }
    
    let payload = messageDict[kMFMessageKeyPayload]
    
    DDLogInfo("Received Message: \(message) with payload: \(String(describing: payload))")
    
    var response: Any? = nil
    
    if message == "getEnvAndArgs" {
        response = [
            "env": ProcessInfo.processInfo.environment,
            "args": ProcessInfo.processInfo.arguments
        ]
    } else if message == "isDarkMode" {
        let aqua = NSAppearance.Name.aqua
        let darkAqua = NSAppearance.Name.darkAqua
        if let best = NSAppearance.current.bestMatch(from: [aqua, darkAqua]) {
            response = (best == darkAqua)
        } else {
            response = false
        }
    } else {
        #if IS_MAIN_APP
        if message == "addModeFeedback" {
            if let tabController = MainAppState.shared.buttonTabController, let payloadDict = payload as? NSDictionary {
                tabController.handleAddModeFeedback(payload: payloadDict)
            }
        } else if message == "keyCaptureModeFeedback" {
            KeyCaptureView.handleKeyCaptureModeFeedback(withPayload: payload as? [AnyHashable : Any] ?? [:], isSystemDefinedEvent: false)
        } else if message == "keyCaptureModeFeedbackWithSystemEvent" {
            KeyCaptureView.handleKeyCaptureModeFeedback(withPayload: payload as? [AnyHashable : Any] ?? [:], isSystemDefinedEvent: true)
        } else if message == "helperEnabledWithNoAccessibility" {
            if let payloadObj = payload as? NSObject {
                let isStrange = MessagePortUtility.shared.checkHelperStrangenessReact(payload: payloadObj)
                if !isStrange {
                    AuthorizeAccessibilityView.add()
                }
            }
        } else if message == "helperEnabled" {
            if let payloadObj = payload as? NSObject {
                let isStrange = MessagePortUtility.shared.checkHelperStrangenessReact(payload: payloadObj)
                if !isStrange {
                    NSApp.activate(ignoringOtherApps: true)
                    AuthorizeAccessibilityView.remove()
                    EnabledState.shared.reactToDidBecomeEnabled()
                }
            }
        } else if message == "helperDisabled" {
            EnabledState.shared.reactToDidBecomeDisabled()
        } else if message == "configFileChanged" {
            Config.loadFileAndUpdateStates()
        } else if message == "showNextToastOrSheetWithSection" {
            if let sectionStr = payload as? String {
                let moreToasts = ToastAndSheetTests.showNextTest(section: sectionStr)
                response = moreToasts
            }
        } else if message == "didShowAllToastsAndSheets" {
            response = ToastAndSheetTests.didShowAllToastsAndSheets()
        } else if message == "showCaptureToast" {
            if let payloadDict = payload as? [String: Any],
               let before = payloadDict["before"] as? Set<NSNumber>,
               let after = payloadDict["after"] as? Set<NSNumber> {
                ToastAndSheetTests.showCaptureToast(before: before, after: after)
            }
        } else {
            DDLogInfo("Unknown message received in App: \(message)")
        }
        #endif
        
        #if IS_HELPER
        if message == "configFileChanged" {
            Config.loadFileAndUpdateStates()
        } else if message == "terminate" {
            NSApp.terminate(nil)
        } else if message == "checkAccessibility" {
            response = AccessibilityCheck.checkAccessibilityAndUpdateSystemSettings()
        } else if message == "enableAddMode" {
            response = Remap.enableAddMode()
        } else if message == "disableAddMode" {
            response = Remap.disableAddMode()
        } else if message == "enableKeyCaptureMode" {
            KeyCaptureMode.enable()
        } else if message == "disableKeyCaptureMode" {
            KeyCaptureMode.disable()
        } else if message == "getActiveDeviceInfo" {
            if let dev = HelperState.shared.activeDevice {
                response = [
                    "name": dev.name(),
                    "manufacturer": dev.manufacturer(),
                    "nOfButtons": dev.nOfButtons()
                ]
            }
        } else if message == "queryLogitechInfo" {
            if let dev = currentLogitechDevice() {
                let devId = dev.uniqueID()
                let lastQueryTime = MFMessagePort.lastQueryTimes[devId] ?? 0.0
                let now = ProcessInfo.processInfo.systemUptime
                if now - lastQueryTime > 10.0 {
                    LogitechActivator.shared.queryBatteryAndDPIForDevice(dev)
                    MFMessagePort.lastQueryTimes[devId] = now
                }
                response = [
                    "isLogitech": true,
                    "batteryPercentage": dev.logitechBatteryPercentage,
                    "batteryStatus": dev.logitechBatteryStatus,
                    "dpi": dev.logitechDPI
                ]
            } else {
                response = [
                    "isLogitech": false
                ]
            }
        } else if message == "getLogitechState" {
            if let dev = currentLogitechDevice(), let deviceDL = dev.iohidDevice {
                var state = LogitechSmartShiftState()
                var caps = LogitechDPICapabilities()
                let gotSmartShift = LogitechActivator.shared.getSmartShiftState(&state, forDevice: deviceDL)
                let gotDPI = LogitechActivator.shared.getDPICapabilities(&caps, forDevice: deviceDL)
                
                response = [
                    "supportsSmartShift": gotSmartShift,
                    "supportsTunableTorque": gotSmartShift && state.supportsTunableTorque.boolValue,
                    "supportsDPI": gotDPI,
                    "wheelMode": state.wheelMode,
                    "autoShift": state.autoShift,
                    "threshold": state.threshold,
                    "torque": state.torque,
                    "currentDpi": caps.currentDpi,
                    "minDpi": caps.minDpi,
                    "maxDpi": caps.maxDpi,
                    "step": caps.step
                ]
            } else {
                response = [
                    "supportsSmartShift": false,
                    "supportsTunableTorque": false,
                    "supportsDPI": false
                ]
            }
        } else if message == "setLogitechSmartShift" {
            if let dev = currentLogitechDevice(), let deviceDL = dev.iohidDevice, let args = payload as? [String: Any] {
                var state = LogitechSmartShiftState()
                state.wheelMode = args["wheelMode"] as? UInt8 ?? 0
                state.autoShift = args["autoShift"] as? UInt8 ?? 0
                state.threshold = args["threshold"] as? UInt8 ?? 0
                state.torque = args["torque"] as? UInt8 ?? 0
                response = LogitechActivator.shared.setSmartShiftState(state, forDevice: deviceDL)
            } else {
                response = false
            }
        } else if message == "setLogitechDPI" {
            if let dev = currentLogitechDevice(), let deviceDL = dev.iohidDevice, let dpiNum = payload as? NSNumber {
                response = LogitechActivator.shared.setDpi(dpiNum.uint16Value, forDevice: deviceDL)
            } else {
                response = false
            }
        } else if message == "getLogitechHiResState" {
            if let dev = currentLogitechDevice(), let deviceDL = dev.iohidDevice {
                var state = LogitechHiResWheelState()
                let got = LogitechActivator.shared.getHiResWheelState(&state, forDevice: deviceDL)
                if got {
                    dev.supportsLogitechHiResWheel = state.supported.boolValue
                    dev.logitechHiResEnabled = state.hiResEnabled.boolValue
                }
                response = [
                    "supported": got && state.supported.boolValue,
                    "hiResEnabled": state.hiResEnabled.boolValue,
                    "multiplier": state.multiplier,
                    "hasRatchetSwitch": state.hasRatchetSwitch.boolValue
                ]
            } else {
                response = ["supported": false]
            }
        } else if message == "setLogitechHiResMode" {
            if let dev = currentLogitechDevice(), let deviceDL = dev.iohidDevice, let enabledNum = payload as? NSNumber {
                let enabled = enabledNum.boolValue
                let success = LogitechActivator.shared.setHiResWheelMode(enabled, forDevice: deviceDL)
                if success {
                    dev.logitechHiResEnabled = enabled
                }
                response = success
            } else {
                response = false
            }
        } else if message == "setLogitechScrollDirection" {
            if let dev = currentLogitechDevice(), let deviceDL = dev.iohidDevice, let invertedNum = payload as? NSNumber {
                let inverted = invertedNum.boolValue
                response = LogitechActivator.shared.setFirmwareScrollDirection(inverted, forDevice: deviceDL)
            } else {
                response = false
            }
        } else if message == "getLogitechReportRate" {
            if let dev = currentLogitechDevice(), let deviceDL = dev.iohidDevice {
                var info = LogitechReportRateInfo()
                let got = LogitechActivator.shared.getReportRateInfo(&info, forDevice: deviceDL)
                if got {
                    dev.supportsLogitechReportRate = (info.rateCount > 0)
                    if info.currentRate > 0 {
                        var hz: UInt16 = 0
                        switch info.currentRate {
                        case 1: hz = 125
                        case 2: hz = 250
                        case 3: hz = 500
                        case 4: hz = 1000
                        case 5: hz = 2000
                        case 6: hz = 4000
                        case 8: hz = 8000
                        default: break
                        }
                        dev.logitechReportRate = hz
                    }
                    var ratesArray: [NSNumber] = []
                    withUnsafePointer(to: info.rates) { ptr in
                        let rawPtr = UnsafeRawPointer(ptr)
                        let typedPtr = rawPtr.bindMemory(to: UInt16.self, capacity: Int(info.rateCount))
                        for i in 0..<Int(info.rateCount) {
                            ratesArray.append(NSNumber(value: typedPtr[i]))
                        }
                    }
                    response = [
                        "supported": info.rateCount > 0,
                        "currentRate": info.currentRate,
                        "currentRateHz": dev.logitechReportRate,
                        "rates": ratesArray
                    ]
                } else {
                    response = ["supported": false]
                }
            } else {
                response = ["supported": false]
            }
        } else if message == "setLogitechReportRate" {
            if let dev = currentLogitechDevice(), let deviceDL = dev.iohidDevice, let rateNum = payload as? NSNumber {
                response = LogitechActivator.shared.setReportRate(rateNum.uint8Value, forDevice: deviceDL)
            } else {
                response = false
            }
        } else if message == "updateActiveDeviceWithEventSenderID" {
            if let senderNum = payload as? NSNumber {
                HelperState.shared.updateActiveDevice(eventSenderID: senderNum.uint64Value)
            }
        } else if message == "getBundleVersion" {
            response = Locator.bundleVersion()
        } else {
            DDLogInfo("Unknown message received in Helper: \(message)")
        }
        #endif
    }
    
    if let resp = response {
        let responseData: Data
        do {
            if #available(macOS 10.13, *) {
                responseData = try NSKeyedArchiver.archivedData(withRootObject: resp, requiringSecureCoding: false)
            } else {
                responseData = NSKeyedArchiver.archivedData(withRootObject: resp)
            }
            return Unmanaged.passRetained(responseData as CFData)
        } catch {
            DDLogError("MFMessagePort: Failed to encode response data: \(error)")
            return nil
        }
    } else {
        return nil
    }
}

@objc(MFMessagePort)
public class MFMessagePort: NSObject {
    fileprivate static var sLocalListeningPort: CFMessagePort?
    fileprivate static var lastQueryTimes: [NSNumber: TimeInterval] = [:]
    
    @objc(invalidateLocalPort)
    public static func invalidateLocalPort() {
        if let port = sLocalListeningPort {
            DDLogInfo("MFMessagePort: Invalidating local message port to release ownership.")
            CFMessagePortInvalidate(port)
            sLocalListeningPort = nil
        }
    }
    
    @objc(load_Manual)
    public static func load_Manual() {
        assert(runningMainApp() || runningHelper())
        DDLogInfo("Initializing MessagePort...")
        
        let messagePortName = runningMainApp() ? kMFBundleIDApp : kMFBundleIDHelper
        
        var localPort: CFMessagePort? = nil
        let maxRetries = 10
        for retry in 0..<maxRetries {
            localPort = CFMessagePortCreateLocal(kCFAllocatorDefault, messagePortName as CFString, didReceiveMessageCallback, nil, nil)
            if localPort != nil {
                sLocalListeningPort = localPort
                break
            }
            if runningHelper() {
                DDLogWarn("Failed to create local message port, retrying in 100ms... (attempt \(retry + 1)/\(maxRetries))")
                Thread.sleep(forTimeInterval: 0.1)
            } else {
                break
            }
        }
        
        DDLogInfo("Created localPort: \(String(describing: localPort))")
        
        guard let port = localPort else {
            if runningMainApp() {
                DDLogInfo("Failed to create a local message port. It will probably work anyway for some reason")
            } else {
                DDLogError("Failed to create a local message port after retries. This might be because there is another instance of \(kMFHelperName) already running. Exiting.")
                exit(0)
            }
            return
        }
        
        let runLoopSource = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, CFRunLoopMode.commonModes)
    }
    
    @objc(sendMessage:withPayload:toRemotePort:waitForReply:)
    public static func sendMessage(_ message: String, withPayload payload: NSObject?, toRemotePort remotePortName: String, waitForReply: Bool) -> NSObject? {
        let remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, remotePortName as CFString)
        if remotePort == nil {
            DDLogInfo("Can't send message '\(message)', because there is no CFMessagePort")
            return nil
        }
        
        CFMessagePortSetInvalidationCallBack(remotePort, invalidationCallback)
        
        var messageDict: [String: Any] = [
            kMFMessageKeyMessage: message
        ]
        if let pay = payload {
            messageDict[kMFMessageKeyPayload] = pay
        }
        
        DDLogInfo("Sending message: \(message) with payload: \(String(describing: payload)) from bundle: \(String(describing: Bundle.main.bundleIdentifier)) via message port")
        
        let messageID: Int32 = 0x420666
        let messageData: Data
        do {
            if #available(macOS 10.13, *) {
                messageData = try NSKeyedArchiver.archivedData(withRootObject: messageDict, requiringSecureCoding: false)
            } else {
                messageData = NSKeyedArchiver.archivedData(withRootObject: messageDict)
            }
        } catch {
            DDLogError("MFMessagePort: Failed to serialize messageDict: \(error)")
            return nil
        }
        
        var sendTimeout: CFTimeInterval = 0.0
        var receiveTimeout: CFTimeInterval = 0.0
        var replyMode: CFString? = nil
        var responseData: Unmanaged<CFData>? = nil
        
        if waitForReply {
            sendTimeout = 0.0
            receiveTimeout = 1.0
            replyMode = CFRunLoopMode.defaultMode.rawValue
        }
        
        let status = CFMessagePortSendRequest(remotePort, messageID, messageData as CFData, sendTimeout, receiveTimeout, replyMode, &responseData)
        
        if status != 0 {
            DDLogError("Non-zero CFMessagePortSendRequest return: \(CFMessagePortSendRequest_ErrorCode_ToString(status))")
            return nil
        }
        
        var response: NSObject? = nil
        if let respUnmanaged = responseData, waitForReply {
            let respData = respUnmanaged.takeRetainedValue() as Data
            do {
                if #available(macOS 10.13, *) {
                    response = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSString.self, NSNumber.self, NSSet.self, NSArray.self, NSURL.self], from: respData) as? NSObject
                } else {
                    response = NSKeyedUnarchiver.unarchiveObject(with: respData) as? NSObject
                }
            } catch {
                DDLogError("MFMessagePort: Failed to deserialize response: \(error)")
            }
        }
        
        return response
    }
    
    @objc(sendMessage:withPayload:waitForReply:)
    public static func sendMessage(_ message: String, withPayload payload: NSObject?, waitForReply replyExpected: Bool) -> NSObject? {
        assert(runningMainApp() || runningHelper())
        let remotePortName = runningMainApp() ? kMFBundleIDHelper : kMFBundleIDApp
        return sendMessage(message, withPayload: payload, toRemotePort: remotePortName, waitForReply: replyExpected)
    }
}

fileprivate func CFMessagePortSendRequest_ErrorCode_ToString(_ errorCode: Int32) -> String {
    switch errorCode {
    case kCFMessagePortSuccess: return "Success"
    case kCFMessagePortSendTimeout: return "SendTimeout"
    case kCFMessagePortReceiveTimeout: return "ReceiveTimeout"
    case kCFMessagePortIsInvalid: return "IsInvalid"
    case kCFMessagePortTransportError: return "TransportError"
    case kCFMessagePortBecameInvalidError: return "BecameInvalidError"
    default: return "(\(errorCode))"
    }
}
