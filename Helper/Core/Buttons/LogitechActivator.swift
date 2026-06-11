//
// --------------------------------------------------------------------------
// LogitechActivator.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import IOKit.hid
import Cocoa
import os.log
import UserNotifications

let kHIDPP_Short: UInt8 = 0x10
let kHIDPP_Long: UInt8 = 0x11
let kFeat_ReprogV4: UInt16 = 0x1B04
let kFeat_SmartShift1: UInt16 = 0x2110
let kFeat_SmartShift2: UInt16 = 0x2111
let kFeat_AdjustableDpi: UInt16 = 0x2201
let kFeat_ExtendedDpi: UInt16 = 0x2202

// Divert flags: bit 0 = divert, bit 1 = divert_valid
let kDivertFlags: UInt8 = 0x03

private let kNativeTIDs: [UInt16] = [0x0001, 0x0002, 0x0003, 0x0004, 0x0005]
private let kNativeSideButtonTIDs: [UInt16] = [0x0004, 0x0005]
private let kNativeSideButtonCIDs: [UInt16] = [0x0053, 0x0056]

enum HIDPPError: Error {
    case timeout
    case ioError(IOReturn)
    case deviceError(UInt8)
    case invalidResponse
    case notFound
}

actor HIDPPMessenger {
    let device: IOHIDDevice
    let writeDevice: IOHIDDevice
    var deviceIndex: UInt8 = 0xFF
    
    private var currentRequestId: Int = 0
    private var activeContinuation: CheckedContinuation<[UInt8], Error>?
    private var activeFeature: UInt8 = 0
    private var activeFunction: UInt8 = 0
    private var activeDeviceIndex: UInt8 = 0xFF
    
    private var currentTask: Task<[UInt8], Error>?
    
    init(device: IOHIDDevice, writeDevice: IOHIDDevice) {
        self.device = device
        self.writeDevice = writeDevice
    }
    
    func setDeviceIndex(_ index: UInt8) {
        self.deviceIndex = index
    }
    
    func sendAndWait(feature: UInt8, function: UInt8, params: [UInt8], timeout: TimeInterval = 1.0) async throws -> [UInt8] {
        let task = Task { [currentTask] in
            _ = try? await currentTask?.value
            return try await self.performSendAndWait(feature: feature, function: function, params: params, timeout: timeout)
        }
        self.currentTask = task
        return try await task.value
    }
    
    private func performSendAndWait(feature: UInt8, function: UInt8, params: [UInt8], timeout: TimeInterval) async throws -> [UInt8] {
        var pkt = [UInt8](repeating: 0, count: 20)
        pkt[0] = kHIDPP_Long
        pkt[1] = self.deviceIndex
        pkt[2] = feature
        pkt[3] = (function << 4) | 0x0E // Function index in upper nibble, software ID 0x0E in lower nibble
        for i in 0..<params.count {
            if 4 + i < 20 {
                pkt[4 + i] = params[i]
            }
        }
        
        self.currentRequestId += 1
        let reqId = self.currentRequestId
        self.activeFeature = feature
        self.activeFunction = function
        self.activeDeviceIndex = self.deviceIndex
        
        return try await withCheckedThrowingContinuation { continuation in
            self.activeContinuation = continuation
            
            let ret = IOHIDDeviceSetReport(self.writeDevice, kIOHIDReportTypeOutput, CFIndex(pkt[0]), pkt, pkt.count)
            if ret != kIOReturnSuccess {
                self.activeContinuation = nil
                continuation.resume(throwing: HIDPPError.ioError(ret))
                return
            }
            
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard let self = self else { return }
                await self.handleTimeout(for: reqId, continuation: continuation)
            }
        }
    }
    
    private func handleTimeout(for reqId: Int, continuation: CheckedContinuation<[UInt8], Error>) {
        if self.currentRequestId == reqId, let cont = self.activeContinuation {
            self.activeContinuation = nil
            cont.resume(throwing: HIDPPError.timeout)
        }
    }
    
    func handleReport(_ report: [UInt8]) {
        guard report.count >= 4 else { return }
        guard report[0] == kHIDPP_Short || report[0] == kHIDPP_Long else { return }
        
        var isResponse = false
        var isError = false
        
        if report[1] == self.activeDeviceIndex {
            if report[2] == 0xFF || report[2] == 0x8F { // Error (0xFF for HID++ 2.0, 0x8F for HID++ 1.0)
                if report.count >= 6 &&
                   report[3] == self.activeFeature &&
                   (report[4] & 0x0F) == 0x0E &&
                   (report[4] & 0xF0) == (self.activeFunction << 4) {
                    isResponse = true
                    isError = true
                }
            } else { // Normal
                if report[2] == self.activeFeature &&
                   (report[3] & 0x0F) == 0x0E &&
                   (report[3] & 0xF0) == (self.activeFunction << 4) {
                    isResponse = true
                }
            }
        }
        
        if isResponse {
            if let continuation = self.activeContinuation {
                self.activeContinuation = nil
                if isError {
                    let errorCode = report.count >= 6 ? report[5] : 0
                    continuation.resume(throwing: HIDPPError.deviceError(errorCode))
                } else {
                    continuation.resume(returning: report)
                }
            }
        }
    }
}

class DeviceState {
    let device: IOHIDDevice
    let writeDevice: IOHIDDevice
    var deviceIndex: UInt8 = 0xFF
    
    var pressedCIDs = [UInt16](repeating: 0, count: 32)
    var pressedCount: Int = 0
    
    var featWirelessStatus: UInt8 = 0
    var featReprogV4: UInt8 = 0
    var featSmartShift: UInt8 = 0
    var featAdjustableDpi: UInt8 = 0  // 0x2201
    var featExtendedDpi: UInt8 = 0    // 0x2202
    var featHiResWheel: UInt8 = 0     // 0x2121
    var featReportRate: UInt8 = 0     // 0x8060
    var featReportRateExt: UInt8 = 0  // 0x8061
    var lastErrorCode: UInt8 = 0
    var lastNotifiedBatteryLevel: Int = 0
    var lastBatteryQueryTime: TimeInterval = 0
    var isSmartShiftEnhanced: Bool = false
    var featBattery: UInt8 = 0
    var isBattery1004: Bool = false
    
    var cidMap = [UInt16](repeating: 0, count: 24)
    var cidCount: Int = 0
    
    let reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 20)
    let messenger: HIDPPMessenger
    
    init(device: IOHIDDevice, writeDevice: IOHIDDevice) {
        self.device = device
        self.writeDevice = writeDevice
        self.messenger = HIDPPMessenger(device: device, writeDevice: writeDevice)
    }
    
    deinit {
        reportBuffer.deallocate()
    }
}

@objc(LogitechCIDActivator)
public class LogitechActivator: NSObject {
    @objc public static let shared = LogitechActivator()
    private let logger = OSLog(subsystem: "com.nuebling.mac-mouse-fix.helper", category: "LogitechActivator")
    

    
    private let stateLock = NSLock()
    private var states: [IOHIDDevice: DeviceState] = [:]
    private var isActivatingOrReactivating = false
    private var lastReactivateTime: TimeInterval = 0
    
    private var reactivateTimer: Timer?
    
    private override init() {
        super.init()
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        DispatchQueue.main.async {
            self.reactivateTimer = Timer.scheduledTimer(
                timeInterval: 5.0,
                target: self,
                selector: #selector(self.periodicCheck),
                userInfo: nil,
                repeats: true
            )
        }
    }
    
    private func state(for device: IOHIDDevice) -> DeviceState? {
        stateLock.withLock {
            if let s = states[device] { return s }
            for s in states.values {
                if s.writeDevice === device { return s }
            }
            
            let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String
            let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
            let pid = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber
            
            if vid == nil { return nil }
            
            var candidates: [DeviceState] = []
            for s in states.values {
                var isMatch = (s.device === device || s.writeDevice === device)
                if !isMatch, let name = name {
                    let sName = IOHIDDeviceGetProperty(s.device, kIOHIDProductKey as CFString) as? String
                    let sVid = IOHIDDeviceGetProperty(s.device, kIOHIDVendorIDKey as CFString) as? NSNumber
                    if vid == sVid && name == sName {
                        isMatch = true
                    }
                }
                if isMatch {
                    candidates.append(s)
                }
            }
            
            if candidates.isEmpty, let pid = pid {
                for s in states.values {
                    let sVid = IOHIDDeviceGetProperty(s.device, kIOHIDVendorIDKey as CFString) as? NSNumber
                    let sPid = IOHIDDeviceGetProperty(s.device, kIOHIDProductIDKey as CFString) as? NSNumber
                    if vid == sVid && pid == sPid {
                        candidates.append(s)
                    }
                }
            }
            
            if candidates.isEmpty { return nil }
            
            var bestState: DeviceState? = nil
            for s in candidates {
                guard let currentBest = bestState else {
                    bestState = s
                    continue
                }
                let sHasSmartShift = s.featSmartShift != 0
                let bHasSmartShift = currentBest.featSmartShift != 0
                
                if sHasSmartShift && !bHasSmartShift {
                    bestState = s
                } else if sHasSmartShift && bHasSmartShift {
                    if s.isSmartShiftEnhanced && !currentBest.isSmartShiftEnhanced {
                        bestState = s
                    }
                } else if s.featReprogV4 != 0 && currentBest.featReprogV4 == 0 {
                    bestState = s
                }
            }
            return bestState
        }
    }
    
    private func findVendorInterface(for mouseDev: IOHIDDevice) -> IOHIDDevice {
        let mName = IOHIDDeviceGetProperty(mouseDev, kIOHIDProductKey as CFString) as? String ?? ""
        let vid = IOHIDDeviceGetProperty(mouseDev, kIOHIDVendorIDKey as CFString) as? NSNumber
        let pid = IOHIDDeviceGetProperty(mouseDev, kIOHIDProductIDKey as CFString) as? NSNumber
        
        os_log("LogitechCIDActivator: findVendorInterface starting for '%{public}@' (VID: %{public}@, PID: %{public}@)",
               log: self.logger, type: .info, mName, vid?.description ?? "nil", pid?.description ?? "nil")
               
        guard let vendorId = vid, let productId = pid else {
            return mouseDev
        }
        
        let matchingDict = IOServiceMatching(kIOHIDDeviceKey) as NSMutableDictionary
        matchingDict[kIOHIDVendorIDKey] = vendorId
        matchingDict[kIOHIDProductIDKey] = productId
        
        var iterator: io_iterator_t = 0
        var port: mach_port_t = kIOMasterPortDefault
        if #available(macOS 12.0, *) {
            port = kIOMainPortDefault
        }
        let kr = IOServiceGetMatchingServices(port, matchingDict as CFDictionary, &iterator)
        if kr != KERN_SUCCESS {
            return mouseDev
        }
        defer {
            IOObjectRelease(iterator)
        }
        
        var service = IOIteratorNext(iterator)
        var foundDev: IOHIDDevice? = nil
        
        while service != 0 {
            if let dev = IOHIDDeviceCreate(kCFAllocatorDefault, service) {
                let upage = IOHIDDeviceGetProperty(dev, kIOHIDPrimaryUsagePageKey as CFString) as? NSNumber
                let maxOut = IOHIDDeviceGetProperty(dev, kIOHIDMaxOutputReportSizeKey as CFString) as? NSNumber
                
                if let upVal = upage?.intValue, upVal >= 0xFF00 {
                    foundDev = dev
                    IOObjectRelease(service)
                    break
                } else if let maxOutVal = maxOut?.intValue, maxOutVal >= 20 {
                    foundDev = dev
                    IOObjectRelease(service)
                    break
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        
        if let dev = foundDev {
            os_log("LogitechCIDActivator: findVendorInterface found vendor interface", log: self.logger, type: .info)
            return dev
        }
        
        os_log("LogitechCIDActivator: findVendorInterface failed to find any vendor interface, returning mouseDev", log: self.logger, type: .error)
        return mouseDev
    }
    
    private func lookupFeature(_ s: DeviceState, featureId: UInt16) async -> UInt8 {
        var pkt = [UInt8](repeating: 0, count: 20)
        pkt[0] = kHIDPP_Long
        pkt[1] = s.deviceIndex
        pkt[2] = 0x00 // Root feature
        pkt[3] = 0x0E // GetFeature command (function 0, software ID 0x0E)
        pkt[4] = UInt8((featureId >> 8) & 0xFF)
        pkt[5] = UInt8(featureId & 0xFF)
        
        do {
            let resp = try await s.messenger.sendAndWait(feature: 0x00, function: 0x00, params: Array(pkt[4...5]), timeout: 1.0)
            return resp[4]
        } catch {
            os_log("LogitechCIDActivator: lookupFeature 0x%{public}04X failed: %{public}@", log: self.logger, type: .error, featureId, error.localizedDescription)
            return 0
        }
    }
    
    private func isNativeTID(_ tid: UInt16) -> Bool {
        return kNativeTIDs.contains(tid)
    }
    
    private func isNativeSideButton(_ cid: UInt16, _ tid: UInt16) -> Bool {
        return kNativeSideButtonTIDs.contains(tid) || kNativeSideButtonCIDs.contains(cid)
    }
    
    private func isButtonRemapped(_ buttonNumber: Int) -> Bool {
        guard let remapsTable = config(kMFConfigKeyRemaps) as? NSArray else { return false }
        for entry in remapsTable {
            guard let dict = entry as? NSDictionary,
                  let trigger = dict[kMFRemapsKeyTrigger] as? NSDictionary,
                  let buttonNum = trigger[kMFButtonTriggerKeyButtonNumber] as? NSNumber else {
                continue
            }
            if buttonNum.intValue == buttonNumber {
                return true
            }
        }
        return false
    }
    
    private func button(for cid: UInt16, state s: DeviceState) -> Int {
        if cid == 0x0053 { return 4 }
        if cid == 0x0056 { return 5 }
        if cid == 0x00C4 { return 6 }
        if cid == 0x00D7 { return 7 }
        
        for i in 0..<s.cidCount {
            if s.cidMap[i] == cid { return 8 + i }
        }
        if s.cidCount < 24 {
            s.cidMap[s.cidCount] = cid
            s.cidCount += 1
            return 8 + s.cidCount - 1
        }
        return 8
    }
    
    private func injectButton(_ s: DeviceState, cid: UInt16, down: Bool) {
        let btn = button(for: cid, state: s)
        let device = DeviceManager.attachedDevice(with: s.device) ?? Device.strange()
        let event = CGEvent(source: nil)
        
        if let ev = event {
            _ = Buttons.handleInput(device: device, button: NSNumber(value: btn), downNotUp: down, event: ev)
        }
    }
    
    private func activateDevice(_ s: DeviceState) async -> Int {
        let name = IOHIDDeviceGetProperty(s.device, kIOHIDProductKey as CFString) as? String ?? "Mouse"
        
        let indices: [UInt8] = [0xFF, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06]
        var activeIndex: UInt8 = 0
        
        for testIndex in indices {
            s.deviceIndex = testIndex
            await s.messenger.setDeviceIndex(testIndex)
            
            let params: [UInt8] = [0x00, 0x01] // Feature Set
            
            do {
                let resp = try await s.messenger.sendAndWait(feature: 0x00, function: 0x00, params: params, timeout: 1.0)
                if resp[2] == 0x00 {
                    activeIndex = testIndex
                    os_log("LogitechCIDActivator: Found active device index 0x%{public}02X on '%{public}@'",
                           log: self.logger, type: .info, activeIndex, name)
                    break
                } else {
                    os_log("LogitechCIDActivator: Probing index 0x%{public}02X returned unexpected resp[2]: 0x%{public}02X",
                           log: self.logger, type: .error, testIndex, resp[2])
                }
            } catch {
                os_log("LogitechCIDActivator: Probing index 0x%{public}02X failed with error: %{public}@",
                       log: self.logger, type: .error, testIndex, error.localizedDescription)
            }
        }
        
        if activeIndex == 0 {
            return -1
        }
        
        s.deviceIndex = activeIndex
        await s.messenger.setDeviceIndex(activeIndex)
        
        s.featReprogV4 = await lookupFeature(s, featureId: kFeat_ReprogV4)
        s.featWirelessStatus = await lookupFeature(s, featureId: 0x1D4B)
        
        if s.featWirelessStatus != 0 {
            os_log("[SMARTSHIFT] LogitechCIDActivator: Found wireless status feature 0x1D4B index 0x%{public}02X on index 0x%{public}02X",
                   log: self.logger, type: .info, s.featWirelessStatus, activeIndex)
        } else {
            os_log("[SMARTSHIFT] LogitechCIDActivator: Wireless status feature 0x1D4B not found on index 0x%{public}02X",
                   log: self.logger, type: .info, activeIndex)
        }
        
        s.featSmartShift = await lookupFeature(s, featureId: 0x2111)
        if s.featSmartShift != 0 {
            s.isSmartShiftEnhanced = true
        } else {
            s.featSmartShift = await lookupFeature(s, featureId: 0x2110)
            s.isSmartShiftEnhanced = false
        }
        
        if s.featSmartShift != 0 {
            os_log("[SMARTSHIFT] LogitechCIDActivator: Found SmartShift feature index 0x%{public}02X on index 0x%{public}02X",
                   log: self.logger, type: .info, s.featSmartShift, activeIndex)
        } else {
            os_log("[SMARTSHIFT] LogitechCIDActivator: SmartShift feature not supported on index 0x%{public}02X",
                   log: self.logger, type: .info, activeIndex)
        }
        
        s.featAdjustableDpi = await lookupFeature(s, featureId: kFeat_AdjustableDpi)
        s.featExtendedDpi = await lookupFeature(s, featureId: kFeat_ExtendedDpi)
        
        if s.featAdjustableDpi != 0 {
            os_log("LogitechCIDActivator: Found Adjustable DPI feature index 0x%{public}02X (Extended DPI support: %{public}d) on index 0x%{public}02X",
                   log: self.logger, type: .info, s.featAdjustableDpi, (s.featExtendedDpi != 0 ? 1 : 0), activeIndex)
        } else {
            os_log("LogitechCIDActivator: Adjustable DPI feature not supported on index 0x%{public}02X",
                   log: self.logger, type: .info, activeIndex)
        }
        
        s.featHiResWheel = await lookupFeature(s, featureId: 0x2121)
        if s.featHiResWheel != 0 {
            os_log("LogitechCIDActivator: Found HiRes Scroll Wheel feature index 0x%{public}02X on index 0x%{public}02X",
                   log: self.logger, type: .info, s.featHiResWheel, activeIndex)
        } else {
            os_log("LogitechCIDActivator: HiRes Scroll Wheel feature not supported on index 0x%{public}02X",
                   log: self.logger, type: .info, activeIndex)
        }
        
        s.featReportRate = await lookupFeature(s, featureId: 0x8060)
        s.featReportRateExt = await lookupFeature(s, featureId: 0x8061)
        if s.featReportRate != 0 || s.featReportRateExt != 0 {
            os_log("LogitechCIDActivator: Found Report Rate feature (0x8060 idx: 0x%{public}02X, 0x8061 idx: 0x%{public}02X) on index 0x%{public}02X",
                   log: self.logger, type: .info, s.featReportRate, s.featReportRateExt, activeIndex)
        } else {
            os_log("LogitechCIDActivator: Report Rate feature not supported on index 0x%{public}02X",
                   log: self.logger, type: .info, activeIndex)
        }
        
        s.featBattery = await lookupFeature(s, featureId: 0x1004)
        s.isBattery1004 = true
        if s.featBattery == 0 {
            s.featBattery = await lookupFeature(s, featureId: 0x1000)
            s.isBattery1004 = false
        }
        if s.featBattery != 0 {
            os_log("LogitechCIDActivator: Found Battery feature index 0x%{public}02X (is 0x1004 Unified Battery: %{public}d) on index 0x%{public}02X",
                   log: self.logger, type: .info, s.featBattery, (s.isBattery1004 ? 1 : 0), activeIndex)
        } else {
            os_log("LogitechCIDActivator: Battery features (0x1004/0x1000) not supported on index 0x%{public}02X",
                   log: self.logger, type: .info, activeIndex)
        }
        
        var diverted = 0
        if s.featReprogV4 != 0 {
            do {
                let resp = try await s.messenger.sendAndWait(feature: s.featReprogV4, function: 0x00, params: [], timeout: 1.0)
                let count = Int(resp[4])
                
                var todivert: [UInt16] = []
                for i in 0..<count {
                    guard todivert.count < 32 else { break }
                    
                    guard let info = try? await s.messenger.sendAndWait(feature: s.featReprogV4, function: 0x01, params: [UInt8(i)], timeout: 1.0) else {
                        continue
                    }
                    
                    let cid = (UInt16(info[4]) << 8) | UInt16(info[5])
                    let tid = (UInt16(info[6]) << 8) | UInt16(info[7])
                    let flags = info[8]
                    let btn = button(for: cid, state: s)
                    
                    if btn >= 6 && !isButtonRemapped(btn) {
                        os_log("LogitechCIDActivator: CID 0x%{public}04X maps to Button %{public}d which is not remapped. Skipping divert to keep native wheel mode switching.",
                               log: self.logger, type: .info, cid, btn)
                        continue
                    }
                    
                    if isNativeSideButton(cid, tid) {
                        if !todivert.contains(cid) { todivert.append(cid) }
                        os_log("LogitechCIDActivator: side-button CID 0x%{public}04X/TID 0x%{public}04X will be diverted as Button %{public}d on '%{public}@'",
                               log: self.logger, type: .info, cid, tid, btn, name)
                        continue
                    }
                    
                    if (flags & (1 << 5)) != 0 && !isNativeTID(tid) {
                        if !todivert.contains(cid) { todivert.append(cid) }
                    }
                }
                
                for cid in todivert {
                    _ = button(for: cid, state: s)
                }
                
                let divertFlags: UInt8 = kDivertFlags
                for cid in todivert {
                    let params: [UInt8] = [UInt8((cid >> 8) & 0xFF), UInt8(cid & 0xFF), divertFlags]
                    
                    var retResult = Result<[UInt8], Error>.success([])
                    do {
                        let r = try await s.messenger.sendAndWait(feature: s.featReprogV4, function: 0x03, params: params, timeout: 1.0)
                        retResult = .success(r)
                    } catch {
                        retResult = .failure(error)
                    }
                    
                    if case .failure(let err) = retResult, case HIDPPError.deviceError(0x04) = err {
                        os_log("LogitechCIDActivator: CID 0x%{public}04X set reporting failed with busy error 0x04. Retrying in 200ms...",
                               log: self.logger, type: .info, cid)
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        do {
                            let r = try await s.messenger.sendAndWait(feature: s.featReprogV4, function: 0x03, params: params, timeout: 1.0)
                            retResult = .success(r)
                        } catch {
                            retResult = .failure(error)
                        }
                    }
                    
                    switch retResult {
                    case .success:
                        diverted += 1
                        os_log("LogitechCIDActivator: diverted side-button CID 0x%{public}04X as Button %{public}d on '%{public}@'",
                               log: self.logger, type: .info, cid, button(for: cid, state: s), name)
                    case .failure(let err):
                        os_log("LogitechCIDActivator: Failed to divert CID 0x%{public}04X on '%{public}@', error: %{public}@",
                               log: self.logger, type: .error, cid, name, err.localizedDescription)
                    }
                }
            } catch {
                os_log("LogitechCIDActivator: Failed to get count or divert CIDs: %{public}@", log: self.logger, type: .error, error.localizedDescription)
            }
        }
        
        // Apply persisted settings
        if s.featAdjustableDpi != 0 || s.featExtendedDpi != 0 {
            if let savedDpi = config("Pointer.logitechDPI") as? NSNumber {
                let dpi = savedDpi.uint16Value
                os_log("LogitechCIDActivator: activateDevice applying saved DPI setting: %{public}d", log: self.logger, type: .info, dpi)
                _ = await setDpiAsync(dpi, forDevice: s.device)
            }
        }
        
        if s.featSmartShift != 0 {
            let savedWheelMode = config("Pointer.logitechWheelMode") as? NSNumber
            let savedAutoShift = config("Pointer.logitechAutoShift") as? NSNumber
            let savedThreshold = config("Pointer.logitechSmartShiftThreshold") as? NSNumber
            let savedTorque = config("Pointer.logitechTorque") as? NSNumber
            
            if savedWheelMode != nil || savedAutoShift != nil || savedThreshold != nil || savedTorque != nil {
                var state = LogitechSmartShiftState()
                state.wheelMode = savedWheelMode?.uint8Value ?? 1
                state.autoShift = savedAutoShift?.uint8Value ?? 0
                state.threshold = savedThreshold?.uint8Value ?? 20
                state.torque = savedTorque?.uint8Value ?? 0
                state.supportsTunableTorque = ObjCBool(s.isSmartShiftEnhanced)
                
                os_log("LogitechCIDActivator: activateDevice applying saved SmartShift settings (wheelMode: %{public}d, autoShift: %{public}d, threshold: %{public}d, torque: %{public}d)",
                       log: self.logger, type: .info, state.wheelMode, state.autoShift, state.threshold, state.torque)
                _ = await setSmartShiftStateAsync(state, forDevice: s.device)
            }
        }
        
        if s.featHiResWheel != 0 {
            if let savedHiRes = config("Pointer.logitechHiResWheel") as? NSNumber {
                let hiResEnabled = savedHiRes.boolValue
                os_log("LogitechCIDActivator: activateDevice applying saved HiRes Scroll setting: %{public}d", log: self.logger, type: .info, hiResEnabled)
                _ = await setHiResWheelModeAsync(hiResEnabled, forDevice: s.device)
            } else {
                setConfig("Pointer.logitechHiResWheel", NSNumber(value: false))
                commitConfig()
                if let shouldInvert = config("Scroll.reverseDirection") as? NSNumber {
                    _ = await setFirmwareScrollDirectionAsync(shouldInvert.boolValue, forDevice: s.device)
                }
            }
        }
        
        if s.featReportRate != 0 {
            if let savedRate = config("Pointer.logitechReportRate") as? NSNumber {
                let rateIndex = savedRate.uint8Value
                os_log("LogitechCIDActivator: activateDevice applying saved Report Rate index: %{public}d", log: self.logger, type: .info, rateIndex)
                _ = await setReportRateAsync(rateIndex, forDevice: s.device)
            }
        }
        
        return diverted
    }
    
    private func runSync<T>(_ block: @escaping () async throws -> T) -> T? {
        var result: Result<T, Error>?
        
        if Thread.isMainThread {
            let runLoop = CFRunLoopGetCurrent()
            var isDone = false
            let startTime = CACurrentMediaTime()
            Task {
                do {
                    let val = try await block()
                    result = .success(val)
                } catch {
                    result = .failure(error)
                }
                isDone = true
                CFRunLoopStop(runLoop)
            }
            while !isDone && (CACurrentMediaTime() - startTime < 2.0) {
                CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.05, false)
            }
        } else {
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                do {
                    let val = try await block()
                    result = .success(val)
                } catch {
                    result = .failure(error)
                }
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 2.0)
        }
        
        switch result {
        case .success(let val)?:
            return val
        case .failure(let err)?:
            os_log("runSync failed with error: %{public}@", log: self.logger, type: .error, err.localizedDescription)
            return nil
        case nil:
            os_log("runSync timed out", log: self.logger, type: .error)
            return nil
        }
    }
    
    private func queryBatteryAndDPI(for s: DeviceState, devWrapper: Device) async {
        if stateLock.withLock({ isActivatingOrReactivating }) {
            os_log("LogitechCIDActivator: Skipping battery/DPI query because device activation/reactivation is in progress.",
                   log: self.logger, type: .info)
            return
        }
        
        // 1. Query battery
        let featBattery = s.featBattery
        let is1004 = s.isBattery1004
        
        if featBattery != 0 {
            let function: UInt8 = is1004 ? 0x01 : 0x00
            do {
                let resp = try await s.messenger.sendAndWait(feature: featBattery, function: function, params: [], timeout: 1.0)
                let percentage = Int(resp[4])
                let status = Int(resp[6])
                
                devWrapper.logitechBatteryPercentage = Int32(percentage)
                devWrapper.logitechBatteryStatus = Int32(status)
                
                os_log("LogitechCIDActivator: Battery query successful. Percentage: %{public}d%%, Status: %{public}d",
                       log: self.logger, type: .info, percentage, status)
                
                let isDischarging = (status == 0x00)
                var threshold = 0
                if percentage <= 10 {
                    threshold = 10
                } else if percentage <= 20 {
                    threshold = 20
                } else if percentage <= 50 {
                    threshold = 50
                }
                
                if s.lastNotifiedBatteryLevel == 0 {
                    if percentage > 50 {
                        s.lastNotifiedBatteryLevel = 100
                    } else if percentage > 20 {
                        s.lastNotifiedBatteryLevel = 50
                    } else if percentage > 10 {
                        s.lastNotifiedBatteryLevel = 20
                    } else {
                        s.lastNotifiedBatteryLevel = 10
                    }
                } else {
                    if threshold > 0 {
                        if s.lastNotifiedBatteryLevel > threshold {
                            s.lastNotifiedBatteryLevel = threshold
                            if isDischarging {
                                self.postLowBatteryNotification(for: devWrapper, percentage: percentage, threshold: threshold)
                            }
                        }
                    } else {
                        if percentage > 50 {
                            s.lastNotifiedBatteryLevel = 100
                        }
                    }
                }
            } catch {
                os_log("LogitechCIDActivator: Battery query failed: %{public}@", log: self.logger, type: .error, error.localizedDescription)
            }
        }
        
        // 2. Query DPI
        var featDPI: UInt8 = 0
        var isExtendedDPI = false
        if s.featExtendedDpi != 0 {
            featDPI = s.featExtendedDpi
            isExtendedDPI = true
        } else if s.featAdjustableDpi != 0 {
            featDPI = s.featAdjustableDpi
        }
        
        if featDPI != 0 {
            devWrapper.supportsLogitechDPI = true
            let function: UInt8 = isExtendedDPI ? 0x05 : 0x02
            
            do {
                let resp = try await s.messenger.sendAndWait(feature: featDPI, function: function, params: [0], timeout: 1.0)
                var dpi = (Int(resp[5]) << 8) | Int(resp[6])
                if dpi == 0 && !isExtendedDPI {
                    dpi = (Int(resp[7]) << 8) | Int(resp[8])
                }
                
                if dpi > 0 && dpi <= 32000 {
                    devWrapper.logitechDPI = Int32(dpi)
                    os_log("LogitechCIDActivator: DPI query successful (feat 0x%{public}04X). DPI: %{public}d",
                           log: self.logger, type: .info, isExtendedDPI ? 0x2202 : 0x2201, dpi)
                } else {
                    os_log("LogitechCIDActivator: DPI query returned implausible value %{public}d (feat 0x%{public}04X), keeping previous DPI %{public}d",
                           log: self.logger, type: .info, dpi, isExtendedDPI ? 0x2202 : 0x2201, devWrapper.logitechDPI)
                }
                
                DispatchQueue.main.async {
                    PointerSpeed.setForAllDevices()
                }
            } catch {
                os_log("LogitechCIDActivator: DPI query failed: %{public}@", log: self.logger, type: .error, error.localizedDescription)
            }
        }
    }
    
    private func postLowBatteryNotification(for device: Device, percentage: Int, threshold: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            guard let self = self else { return }
            if granted {
                let content = UNMutableNotificationContent()
                var title = "Mouse Battery Low"
                var bodyFormat = "%@ battery is low: %d%%"
                let prefLanguage = Locale.preferredLanguages.first ?? "en"
                if prefLanguage.hasPrefix("zh") {
                    title = "鼠标电量低"
                    bodyFormat = "%@ 电量低: %d%%"
                }
                
                content.title = title
                let name = device.name()
                let deviceName = name.isEmpty ? "Mouse" : name
                content.body = String(format: bodyFormat, deviceName, percentage)
                content.sound = UNNotificationSound.default
                
                let identifier = "mmf-battery-\(device.uniqueID().description)-\(threshold)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
                
                center.add(request) { err in
                    if let err = err {
                        os_log("LogitechCIDActivator: Failed to post notification: %{public}@", log: self.logger, type: .error, err.localizedDescription)
                    } else {
                        os_log("LogitechCIDActivator: Posted low battery notification for %{public}@ (%{public}d%%)", log: self.logger, type: .info, deviceName, percentage)
                    }
                }
            } else if let error = error {
                os_log("LogitechCIDActivator: Notification permission denied: %{public}@", log: self.logger, type: .error, error.localizedDescription)
            }
        }
    }
    
    private func rateIndexToHz(_ idx: UInt8) -> UInt16 {
        switch idx {
        case 1: return 125
        case 2: return 250
        case 3: return 500
        case 4: return 1000
        case 5: return 2000
        case 6: return 4000
        case 8: return 8000
        default: return 0
        }
    }
    
    private let inputReportCallback: IOHIDReportCallback = { context, result, sender, type, reportId, report, reportLength in
        guard let context = context else { return }
        let this = Unmanaged<LogitechActivator>.fromOpaque(context).takeUnretainedValue()
        guard let senderPtr = sender else { return }
        let dev = Unmanaged<IOHIDDevice>.fromOpaque(senderPtr).takeUnretainedValue()
        
        guard reportLength >= 4 else { return }
        if report[0] != 0x10 && report[0] != 0x11 { return }
        
        guard let s = this.state(for: dev) else { return }
        
        var reportBytes = [UInt8](repeating: 0, count: reportLength)
        for i in 0..<reportLength {
            reportBytes[i] = report[i]
        }
        
        let hexStr = reportBytes.prefix(20).map { String(format: "%02x", $0) }.joined(separator: " ")
        os_log("LogitechCIDActivator: Input report [ID:%{public}02X, len:%{public}d]: %{public}@",
               log: this.logger, type: .info, reportBytes[0], reportLength, hexStr)
               
        if reportBytes[1] != s.deviceIndex && reportBytes[1] != 0xFF { return }
        
        Task {
            await s.messenger.handleReport(reportBytes)
        }
        
        var reconnectDetected = false
        if reportBytes[1] == 0xFF && reportBytes[2] == 0x00 && reportBytes[3] == 0x41 && reportLength >= 6 {
            let devIdx = reportBytes[4]
            let status = reportBytes[5]
            if devIdx == s.deviceIndex && (status & 0x40) != 0 {
                os_log("LogitechCIDActivator: Unifying reconnection event detected for deviceIndex 0x%{public}02X",
                       log: this.logger, type: .info, devIdx)
                reconnectDetected = true
            }
        }
        
        if !reconnectDetected && reportBytes[0] == 0x11 && (reportBytes[1] == s.deviceIndex || reportBytes[1] == 0xFF) && reportBytes[3] == 0x00 && reportLength >= 5 {
            if s.featWirelessStatus != 0 && reportBytes[2] == s.featWirelessStatus {
                let status = reportBytes[4]
                if status == 0x01 || status == 0x02 {
                    os_log("LogitechCIDActivator: Wireless reconnection event (StatusBroadcast via feature 0x1D4B) detected for deviceIndex 0x%{public}02X",
                           log: this.logger, type: .info, s.deviceIndex)
                    reconnectDetected = true
                }
            } else if reportBytes[2] != 0 && reportBytes[2] < 0x10 {
                let status = reportBytes[4]
                if status == 0x01 || status == 0x02 {
                    os_log("LogitechCIDActivator: Generic wireless status event detected for deviceIndex 0x%{public}02X",
                           log: this.logger, type: .info, s.deviceIndex)
                    reconnectDetected = true
                }
            }
        }
        
        if reconnectDetected {
            os_log("LogitechCIDActivator: Device reconnected wirelessly. Scheduling activation in 0.35 seconds...",
                   log: this.logger, type: .info)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                this.stateLock.withLock { this.isActivatingOrReactivating = true }
                Task {
                    let activeCount = await this.activateDevice(s)
                    this.stateLock.withLock { this.isActivatingOrReactivating = false }
                    os_log("LogitechCIDActivator: Async reactivation after wireless reconnect completed. CIDs configured: %{public}d",
                           log: this.logger, type: .info, activeCount)
                    if activeCount >= 0 {
                        if let attachedDev = DeviceManager.attachedDevice(with: s.device) {
                            attachedDev.isLogitechDiverted = (s.featReprogV4 != 0)
                            await this.queryBatteryAndDPI(for: s, devWrapper: attachedDev)
                        }
                    } else {
                        if let attachedDev = DeviceManager.attachedDevice(with: s.device) {
                            attachedDev.isLogitechDiverted = false
                        }
                        DispatchQueue.main.async {
                            this.lastReactivateTime = 0
                        }
                    }
                }
            }
            return
        }
        
        if reportBytes[3] != 0x00 || reportBytes[2] != s.featReprogV4 {
            return
        }
        
        var currentPressed: [UInt16] = []
        if reportLength >= 6 {
            let cid1 = (UInt16(reportBytes[4]) << 8) | UInt16(reportBytes[5])
            if cid1 != 0 { currentPressed.append(cid1) }
        }
        if reportLength >= 8 {
            let cid2 = (UInt16(reportBytes[6]) << 8) | UInt16(reportBytes[7])
            if cid2 != 0 { currentPressed.append(cid2) }
        }
        if reportLength >= 10 {
            let cid3 = (UInt16(reportBytes[8]) << 8) | UInt16(reportBytes[9])
            if cid3 != 0 { currentPressed.append(cid3) }
        }
        if reportLength >= 12 {
            let cid4 = (UInt16(reportBytes[10]) << 8) | UInt16(reportBytes[11])
            if cid4 != 0 { currentPressed.append(cid4) }
        }
        
        for i in 0..<s.pressedCount {
            let oldCid = s.pressedCIDs[i]
            if !currentPressed.contains(oldCid) {
                this.injectButton(s, cid: oldCid, down: false)
            }
        }
        
        for newCid in currentPressed {
            var alreadyPressed = false
            for i in 0..<s.pressedCount {
                if s.pressedCIDs[i] == newCid {
                    alreadyPressed = true
                    break
                }
            }
            if !alreadyPressed {
                this.injectButton(s, cid: newCid, down: true)
            }
        }
        
        s.pressedCount = 0
        for cid in currentPressed {
            if s.pressedCount < 32 {
                s.pressedCIDs[s.pressedCount] = cid
                s.pressedCount += 1
            }
        }
    }
    
    @objc public func handleDeviceAttached(_ device: IOHIDDevice) {
        let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Mouse"
        let vid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
        
        if vid == nil || vid?.intValue != 0x046D {
            return
        }
        
        stateLock.withLock { isActivatingOrReactivating = true }
        
        _ = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        
        let writeDevice = findVendorInterface(for: device)
        let s = DeviceState(device: device, writeDevice: writeDevice)
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(writeDevice, s.reportBuffer, 20, inputReportCallback, context)
        IOHIDDeviceScheduleWithRunLoop(writeDevice, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        
        let openRes = IOHIDDeviceOpen(writeDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        if openRes != kIOReturnSuccess {
            os_log("LogitechCIDActivator: Failed to open vendor interface: 0x%{public}x", log: self.logger, type: .error, openRes)
        }
        
        stateLock.withLock {
            states[device] = s
        }
        
        Task {
            let configured = await activateDevice(s)
            stateLock.withLock { isActivatingOrReactivating = false }
            
            if configured >= 0 {
                os_log("LogitechCIDActivator: configured %{public}d CID(s) on '%{public}@'",
                       log: self.logger, type: .info, configured, name)
                if let attachedDev = DeviceManager.attachedDevice(with: device) {
                    attachedDev.isLogitechDiverted = (s.featReprogV4 != 0)
                    await queryBatteryAndDPI(for: s, devWrapper: attachedDev)
                }
            } else {
                os_log("LogitechCIDActivator: Failed to configure device '%{public}@'.", log: self.logger, type: .error, name)
                if let attachedDev = DeviceManager.attachedDevice(with: device) {
                    attachedDev.isLogitechDiverted = false
                }
                DispatchQueue.main.async {
                    self.lastReactivateTime = 0
                }
            }
        }
    }
    
    @objc public func handleDeviceRemoved(_ device: IOHIDDevice) {
        var foundState: DeviceState? = nil
        stateLock.withLock {
            if let s = states.removeValue(forKey: device) {
                foundState = s
            }
        }
        
        guard let s = foundState else { return }
        
        for i in 0..<s.pressedCount {
            injectButton(s, cid: s.pressedCIDs[i], down: false)
        }
        
        IOHIDDeviceUnscheduleFromRunLoop(s.writeDevice, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDDeviceRegisterInputReportCallback(s.writeDevice, UnsafeMutablePointer<UInt8>(bitPattern: 0)!, 0, nil, nil)
        
        if s.writeDevice !== s.device {
            IOHIDDeviceClose(s.writeDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        }
    }
    
    @objc public func queryBatteryAndDPIForDevice(_ device: Any) {
        guard let devWrapper = device as? Device else { return }
        guard let dev = devWrapper.iohidDevice, let s = self.state(for: dev) else { return }
        Task {
            await queryBatteryAndDPI(for: s, devWrapper: devWrapper)
        }
    }
    
    @objc public func reactivateDeviceWithIOHIDDevice(_ device: IOHIDDevice) {
        let now = Date.timeIntervalSinceReferenceDate
        if now - lastReactivateTime < 2.0 {
            os_log("LogitechCIDActivator: Skipping reactivation request for device because another reactivation occurred less than 2.0s ago.",
                   log: self.logger, type: .info)
            return
        }
        lastReactivateTime = now
        
        stateLock.withLock { isActivatingOrReactivating = true }
        
        if let s = self.state(for: device) {
            let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Mouse"
            os_log("LogitechCIDActivator: Manually triggering activation for device '%{public}@'",
                   log: self.logger, type: .info, name)
            
            Task {
                let activeCount = await activateDevice(s)
                stateLock.withLock { isActivatingOrReactivating = false }
                
                if activeCount >= 0 {
                    if let attachedDev = DeviceManager.attachedDevice(with: device) {
                        attachedDev.isLogitechDiverted = (s.featReprogV4 != 0)
                        await queryBatteryAndDPI(for: s, devWrapper: attachedDev)
                    }
                } else {
                    if let attachedDev = DeviceManager.attachedDevice(with: device) {
                        attachedDev.isLogitechDiverted = false
                    }
                    DispatchQueue.main.async {
                        self.lastReactivateTime = 0
                    }
                }
            }
        } else {
            stateLock.withLock { isActivatingOrReactivating = false }
            os_log("LogitechCIDActivator: Cannot reactivate device, no state found for this IOHIDDeviceRef. Trying to handle as attached.",
                   log: self.logger, type: .info)
            handleDeviceAttached(device)
        }
    }
    
    @objc public func toggleSmartShiftForDevice(_ device: IOHIDDevice) -> Bool {
        let addr = unsafeBitCast(device, to: Int.self)
        os_log("[SMARTSHIFT] LogitechCIDActivator - toggleSmartShiftForDevice entered for device 0x%{public}x",
               log: self.logger, type: .info, addr)
        
        return runSync { [weak self] in
            guard let self = self else { return false }
            guard let s = self.state(for: device), s.featSmartShift != 0 else { return false }
            
            let is2111 = s.isSmartShiftEnhanced
            let function: UInt8 = 0x01
            
            let resp = try await s.messenger.sendAndWait(feature: s.featSmartShift, function: function, params: [], timeout: 1.0)
            
            let activeMode = resp[4]
            let rawThreshold = resp[5]
            
            let currentWheelMode = (activeMode == 1) ? 0 : 1
            let currentAutoShift = (rawThreshold == 255) ? 0 : 1
            let currentThreshold = (rawThreshold == 255) ? 20 : rawThreshold
            let currentTorque = is2111 ? resp[6] : 0
            
            var newWheelMode: UInt8 = 1
            var newAutoShift: UInt8 = 0
            
            if currentAutoShift == 1 {
                newWheelMode = 0
                newAutoShift = 0
            } else {
                if currentWheelMode == 0 {
                    newWheelMode = 1
                    newAutoShift = 0
                } else {
                    newWheelMode = 1
                    newAutoShift = 1
                }
            }
            
            var newState = LogitechSmartShiftState()
            newState.wheelMode = newWheelMode
            newState.autoShift = newAutoShift
            newState.threshold = currentThreshold
            newState.torque = currentTorque
            newState.supportsTunableTorque = ObjCBool(is2111)
            
            return await self.setSmartShiftStateAsync(newState, forDevice: device)
        } ?? false
    }
    
    @objc public func anyAttachedDeviceSupportsSmartShift() -> Bool {
        return stateLock.withLock {
            states.values.contains { $0.featSmartShift != 0 }
        }
    }
    
    @objc public func getSmartShiftState(_ outState: UnsafeMutablePointer<LogitechSmartShiftState>, forDevice device: IOHIDDevice) -> Bool {
        return runSync { [weak self] in
            guard let self = self else { return false }
            return await self.getSmartShiftStateAsync(outState, forDevice: device)
        } ?? false
    }
    
    @objc public func setSmartShiftState(_ state: LogitechSmartShiftState, forDevice device: IOHIDDevice) -> Bool {
        return runSync { [weak self] in
            guard let self = self else { return false }
            return await self.setSmartShiftStateAsync(state, forDevice: device)
        } ?? false
    }
    
    @objc public func getDPICapabilities(_ outCaps: UnsafeMutablePointer<LogitechDPICapabilities>, forDevice device: IOHIDDevice) -> Bool {
        return runSync { [weak self] in
            guard let self = self else { return false }
            return await self.getDPICapabilitiesAsync(outCaps, forDevice: device)
        } ?? false
    }
    
    @objc public func setDpi(_ dpi: UInt16, forDevice device: IOHIDDevice) -> Bool {
        return runSync { [weak self] in
            guard let self = self else { return false }
            return await self.setDpiAsync(dpi, forDevice: device)
        } ?? false
    }
    
    @objc public func getHiResWheelState(_ outState: UnsafeMutablePointer<LogitechHiResWheelState>, forDevice device: IOHIDDevice) -> Bool {
        return runSync { [weak self] in
            guard let self = self else { return false }
            guard let s = self.state(for: device), s.featHiResWheel != 0 else { return false }
            
            outState.pointee.supported = ObjCBool(true)
            
            do {
                let resp = try await s.messenger.sendAndWait(feature: s.featHiResWheel, function: 0x00, params: [], timeout: 1.0)
                outState.pointee.multiplier = resp[4]
                outState.pointee.hasRatchetSwitch = ObjCBool((resp[5] & 0x04) != 0)
            } catch {
                outState.pointee.multiplier = 8
                outState.pointee.hasRatchetSwitch = ObjCBool(false)
            }
            
            do {
                let resp = try await s.messenger.sendAndWait(feature: s.featHiResWheel, function: 0x01, params: [], timeout: 1.0)
                outState.pointee.hiResEnabled = ObjCBool((resp[4] & 0x02) != 0)
                os_log("LogitechCIDActivator: HiRes Wheel state: enabled=%{public}d, multiplier=%{public}d",
                       log: self.logger, type: .info, outState.pointee.hiResEnabled.boolValue ? 1 : 0, outState.pointee.multiplier)
            } catch {
                outState.pointee.hiResEnabled = ObjCBool(false)
            }
            
            return true
        } ?? false
    }
    
    @objc public func setHiResWheelMode(_ enabled: Bool, forDevice device: IOHIDDevice) -> Bool {
        return runSync { [weak self] in
            guard let self = self else { return false }
            return await self.setHiResWheelModeAsync(enabled, forDevice: device)
        } ?? false
    }
    
    @objc public func setFirmwareScrollDirection(_ inverted: Bool, forDevice device: IOHIDDevice) -> Bool {
        return runSync { [weak self] in
            guard let self = self else { return false }
            return await self.setFirmwareScrollDirectionAsync(inverted, forDevice: device)
        } ?? false
    }
    
    @objc public func getReportRateInfo(_ outInfo: UnsafeMutablePointer<LogitechReportRateInfo>, forDevice device: IOHIDDevice) -> Bool {
        return runSync { [weak self] in
            guard let self = self else { return false }
            guard let s = self.state(for: device) else { return false }
            let feat = s.featReportRate != 0 ? s.featReportRate : s.featReportRateExt
            if feat == 0 { return false }
            
            outInfo.pointee = LogitechReportRateInfo()
            
            do {
                let resp = try await s.messenger.sendAndWait(feature: feat, function: 0x00, params: [], timeout: 1.0)
                var count = 0
                withUnsafeMutablePointer(to: &outInfo.pointee.rates) { ptr in
                    let rawPtr = UnsafeMutableRawPointer(ptr)
                    let ratesPtr = rawPtr.bindMemory(to: UInt16.self, capacity: 8)
                    for i in 4..<12 {
                        guard count < 8 else { break }
                        if resp[i] == 0 { break }
                        let hz = self.rateIndexToHz(resp[i])
                        if hz > 0 {
                            ratesPtr[count] = hz
                            count += 1
                        }
                    }
                }
                outInfo.pointee.rateCount = UInt8(count)
            } catch {}
            
            do {
                let resp = try await s.messenger.sendAndWait(feature: feat, function: 0x02, params: [], timeout: 1.0)
                outInfo.pointee.currentRate = resp[4]
                os_log("LogitechCIDActivator: Report Rate query: current index=%{public}d (%{public}d Hz), %{public}d rates supported",
                       log: self.logger, type: .info, outInfo.pointee.currentRate, self.rateIndexToHz(outInfo.pointee.currentRate), outInfo.pointee.rateCount)
            } catch {}
            
            return true
        } ?? false
    }
    
    @objc public func setReportRate(_ rateIndex: UInt8, forDevice device: IOHIDDevice) -> Bool {
        return runSync { [weak self] in
            guard let self = self else { return false }
            return await self.setReportRateAsync(rateIndex, forDevice: device)
        } ?? false
    }
    
    // MARK: - Private Async Implementations
    
    private func getSmartShiftStateAsync(_ outState: UnsafeMutablePointer<LogitechSmartShiftState>, forDevice device: IOHIDDevice) async -> Bool {
        guard let s = self.state(for: device), s.featSmartShift != 0 else { return false }
        let is2111 = s.isSmartShiftEnhanced
        let function: UInt8 = 0x01
        
        do {
            let resp = try await s.messenger.sendAndWait(feature: s.featSmartShift, function: function, params: [], timeout: 1.0)
            let activeMode = resp[4]
            let rawThreshold = resp[5]
            
            outState.pointee.wheelMode = (activeMode == 1) ? 0 : 1
            outState.pointee.autoShift = (rawThreshold == 255) ? 0 : 1
            outState.pointee.threshold = (rawThreshold == 255) ? 20 : rawThreshold
            outState.pointee.torque = is2111 ? resp[6] : 0
            outState.pointee.supportsTunableTorque = ObjCBool(is2111)
            
            os_log("LogitechCIDActivator: SmartShift state queried: wheelMode=%{public}d, autoShift=%{public}d, threshold=%{public}d, torque=%{public}d",
                   log: self.logger, type: .info, outState.pointee.wheelMode, outState.pointee.autoShift, outState.pointee.threshold, outState.pointee.torque)
            return true
        } catch {
            os_log("LogitechCIDActivator: Failed to query SmartShift state: %{public}@", log: self.logger, type: .error, error.localizedDescription)
            return false
        }
    }
    
    private func setSmartShiftStateAsync(_ state: LogitechSmartShiftState, forDevice device: IOHIDDevice) async -> Bool {
        guard let s = self.state(for: device), s.featSmartShift != 0 else { return false }
        let is2111 = s.isSmartShiftEnhanced
        let function: UInt8 = 0x02
        
        let activeMode: UInt8 = (state.autoShift == 1) ? 2 : (state.wheelMode == 0 ? 1 : 2)
        let thresholdVal: UInt8 = (state.autoShift == 1) ? state.threshold : 255
        
        var params: [UInt8] = []
        if is2111 {
            params = [activeMode, thresholdVal, state.torque]
        } else {
            params = [activeMode, thresholdVal]
        }
        
        do {
            _ = try await s.messenger.sendAndWait(feature: s.featSmartShift, function: function, params: params, timeout: 1.0)
            os_log("LogitechCIDActivator: SmartShift state set: activeMode=%{public}d, threshold=%{public}d, torque=%{public}d",
                   log: self.logger, type: .info, activeMode, thresholdVal, is2111 ? state.torque : 0)
            return true
        } catch {
            os_log("LogitechCIDActivator: Failed to set SmartShift state: %{public}@", log: self.logger, type: .error, error.localizedDescription)
            return false
        }
    }
    
    private func getDPICapabilitiesAsync(_ outCaps: UnsafeMutablePointer<LogitechDPICapabilities>, forDevice device: IOHIDDevice) async -> Bool {
        guard let s = self.state(for: device) else { return false }
        let feat = s.featExtendedDpi != 0 ? s.featExtendedDpi : s.featAdjustableDpi
        if feat == 0 { return false }
        
        var dpiData = Data()
        let isExtended = (s.featExtendedDpi != 0)
        let function: UInt8 = isExtended ? 0x02 : 0x01
        let ignoreCount = isExtended ? 3 : 1
        
        for page in 0..<8 {
            let params: [UInt8] = [0, 0, UInt8(page)]
            do {
                let resp = try await s.messenger.sendAndWait(feature: feat, function: function, params: params, timeout: 1.0)
                let dataOffset = 4 + ignoreCount
                let dataLen = 16 - ignoreCount
                if dataOffset < resp.count {
                    let bytesToAppend = resp[dataOffset..<min(dataOffset + dataLen, resp.count)]
                    dpiData.append(contentsOf: bytesToAppend)
                }
                
                if dpiData.count >= 2 {
                    if dpiData[dpiData.count - 1] == 0x00 && dpiData[dpiData.count - 2] == 0x00 {
                        break
                    }
                }
            } catch {
                break
            }
        }
        
        var dpiList: [UInt16] = []
        let len = dpiData.count
        var idx = 0
        
        while idx + 1 < len {
            let val = (UInt16(dpiData[idx]) << 8) | UInt16(dpiData[idx + 1])
            if val == 0 {
                break
            }
            if (val >> 13) == 0x07 {
                let step = val & 0x1FFF
                if idx + 3 >= len {
                    break
                }
                let last = (UInt16(dpiData[idx + 2]) << 8) | UInt16(dpiData[idx + 3])
                if let lastDpi = dpiList.last, step > 0 && last >= lastDpi {
                    let start = lastDpi + step
                    for d in stride(from: start, through: last, by: Int(step)) {
                        dpiList.append(d)
                    }
                }
                idx += 4
            } else {
                dpiList.append(val)
                idx += 2
            }
        }
        
        var minDpi: UInt16 = 200
        var maxDpi: UInt16 = 4000
        var step: UInt16 = 50
        
        if dpiList.count >= 2 {
            minDpi = dpiList[0]
            maxDpi = dpiList[dpiList.count - 1]
            step = dpiList[1] - minDpi
        } else if dpiList.count == 1 {
            minDpi = dpiList[0]
            maxDpi = minDpi
            step = 50
        }
        
        outCaps.pointee.minDpi = minDpi
        outCaps.pointee.maxDpi = maxDpi
        outCaps.pointee.step = step
        
        if s.featExtendedDpi != 0 && outCaps.pointee.maxDpi < 8000 {
            outCaps.pointee.maxDpi = 8000
        }
        
        let getFunc: UInt8 = isExtended ? 0x05 : 0x02
        do {
            let resp = try await s.messenger.sendAndWait(feature: feat, function: getFunc, params: [0], timeout: 1.0)
            var dpi = (Int(resp[5]) << 8) | Int(resp[6])
            if dpi == 0 && !isExtended {
                dpi = (Int(resp[7]) << 8) | Int(resp[8])
            }
            if dpi > 0 && dpi <= 32000 {
                outCaps.pointee.currentDpi = UInt16(dpi)
                outCaps.pointee.defaultDpi = UInt16(dpi)
            } else {
                os_log("LogitechCIDActivator: getDPICapabilities returned implausible DPI %{public}d, using fallback 1000",
                       log: self.logger, type: .info, dpi)
                outCaps.pointee.currentDpi = 1000
                outCaps.pointee.defaultDpi = 1000
            }
        } catch {
            outCaps.pointee.currentDpi = 1000
            outCaps.pointee.defaultDpi = 1000
        }
        return true
    }
    
    private func setDpiAsync(_ dpi: UInt16, forDevice device: IOHIDDevice) async -> Bool {
        guard let s = self.state(for: device) else { return false }
        let feat = s.featExtendedDpi != 0 ? s.featExtendedDpi : s.featAdjustableDpi
        if feat == 0 { return false }
        
        let isExtended = (s.featExtendedDpi != 0)
        let function: UInt8 = isExtended ? 0x06 : 0x03
        
        var params: [UInt8] = []
        if isExtended {
            params = [
                0,
                UInt8((dpi >> 8) & 0xFF),
                UInt8(dpi & 0xFF),
                UInt8((dpi >> 8) & 0xFF),
                UInt8(dpi & 0xFF),
                0
            ]
        } else {
            params = [
                0,
                UInt8((dpi >> 8) & 0xFF),
                UInt8(dpi & 0xFF)
            ]
        }
        
        do {
            _ = try await s.messenger.sendAndWait(feature: feat, function: function, params: params, timeout: 1.0)
            if let attachedDev = DeviceManager.attachedDevice(with: device) {
                attachedDev.logitechDPI = Int32(dpi)
            }
            return true
        } catch {
            os_log("LogitechCIDActivator: Failed to set DPI: %{public}@", log: self.logger, type: .error, error.localizedDescription)
            return false
        }
    }
    
    private func setHiResWheelModeAsync(_ enabled: Bool, forDevice device: IOHIDDevice) async -> Bool {
        guard let s = self.state(for: device), s.featHiResWheel != 0 else { return false }
        let shouldInvert = (config("Scroll.reverseDirection") as? NSNumber)?.boolValue ?? false
        
        var flags: UInt8 = 0
        if enabled {
            flags |= 0x02
            if shouldInvert {
                flags |= 0x04
            }
        }
        
        do {
            _ = try await s.messenger.sendAndWait(feature: s.featHiResWheel, function: 0x02, params: [flags], timeout: 1.0)
            os_log("LogitechCIDActivator: HiRes Scroll Wheel mode set to %{public}d, invert: %{public}d (flags: 0x%{public}02X)",
                   log: self.logger, type: .info, enabled ? 1 : 0, shouldInvert ? 1 : 0, flags)
            return true
        } catch {
            os_log("LogitechCIDActivator: Failed to set HiRes Scroll Wheel mode, error: %{public}@",
                   log: self.logger, type: .error, error.localizedDescription)
            return false
        }
    }
    
    private func setFirmwareScrollDirectionAsync(_ inverted: Bool, forDevice device: IOHIDDevice) async -> Bool {
        guard let s = self.state(for: device), s.featHiResWheel != 0 else { return false }
        let hiResEnabled = (config("Pointer.logitechHiResWheel") as? NSNumber)?.boolValue ?? false
        
        var flags: UInt8 = 0
        if hiResEnabled {
            flags |= 0x02
            if inverted {
                flags |= 0x04
            }
        }
        
        do {
            _ = try await s.messenger.sendAndWait(feature: s.featHiResWheel, function: 0x02, params: [flags], timeout: 1.0)
            os_log("LogitechCIDActivator: Firmware scroll direction set to %{public}@ (hiRes: %{public}d, flags: 0x%{public}02X)",
                   log: self.logger, type: .info, inverted ? "inverted" : "normal", hiResEnabled ? 1 : 0, flags)
            return true
        } catch {
            os_log("LogitechCIDActivator: Failed to set firmware scroll direction, error: %{public}@",
                   log: self.logger, type: .error, error.localizedDescription)
            return false
        }
    }
    
    private func setReportRateAsync(_ rateIndex: UInt8, forDevice device: IOHIDDevice) async -> Bool {
        guard let s = self.state(for: device) else { return false }
        let feat = s.featReportRate != 0 ? s.featReportRate : s.featReportRateExt
        if feat == 0 { return false }
        
        do {
            _ = try await s.messenger.sendAndWait(feature: feat, function: 0x03, params: [rateIndex], timeout: 1.0)
            os_log("LogitechCIDActivator: Report Rate set to index %{public}d (%{public}d Hz)",
                   log: self.logger, type: .info, rateIndex, self.rateIndexToHz(rateIndex))
            return true
        } catch {
            os_log("LogitechCIDActivator: Failed to set Report Rate, error: %{public}@", log: self.logger, type: .error, error.localizedDescription)
            return false
        }
    }
    
    @objc private func periodicCheck() {
        let now = Date.timeIntervalSinceReferenceDate
        let activeStates = stateLock.withLock { Array(states.values) }
        
        for s in activeStates {
            guard let attachedDev = DeviceManager.attachedDevice(with: s.device) else { continue }
            
            if s.lastBatteryQueryTime == 0 || (now - s.lastBatteryQueryTime >= 1800.0) {
                s.lastBatteryQueryTime = now
                os_log("LogitechCIDActivator: Background querying battery level for device '%{public}@'",
                       log: self.logger, type: .info, attachedDev.name())
                Task {
                    await queryBatteryAndDPI(for: s, devWrapper: attachedDev)
                }
            }
            
            if s.featReprogV4 != 0 && !attachedDev.isLogitechDiverted {
                os_log("LogitechCIDActivator: Periodic check detected device '%{public}@' is not diverted. Reactivating...",
                       log: self.logger, type: .info, attachedDev.name())
                
                stateLock.withLock { isActivatingOrReactivating = true }
                Task {
                    let activeCount = await activateDevice(s)
                    stateLock.withLock { isActivatingOrReactivating = false }
                    
                    if activeCount >= 0 {
                        attachedDev.isLogitechDiverted = (s.featReprogV4 != 0)
                        await queryBatteryAndDPI(for: s, devWrapper: attachedDev)
                    } else {
                        attachedDev.isLogitechDiverted = false
                        DispatchQueue.main.async {
                            self.lastReactivateTime = 0
                        }
                    }
                }
            }
        }
    }
    
    @objc private func handleSystemWake() {
        os_log("LogitechCIDActivator: System woke up. Scheduling reactivation in 0.8 seconds...", log: self.logger, type: .info)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            self.reactivateAll()
        }
    }
    
    private func reactivateAll() {
        stateLock.withLock { isActivatingOrReactivating = true }
        let activeStates = stateLock.withLock { Array(states.values) }
        
        Task {
            for s in activeStates {
                _ = await activateDevice(s)
            }
            stateLock.withLock { isActivatingOrReactivating = false }
            os_log("LogitechCIDActivator: re-activated %{public}d device(s)", log: self.logger, type: .info, activeStates.count)
        }
    }
}
