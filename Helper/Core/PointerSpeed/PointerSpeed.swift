//
// --------------------------------------------------------------------------
// PointerSpeed.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021 (Swift rewrite in 2026)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation
import IOKit.hid

@objc class PointerSpeed: NSObject {
    
    private static let customCurveIndex: Double = 123
    
    @objc public static func setForAllDevices() {
        for device in DeviceManager.attachedDevices() {
            if let iohidDevice = device.iohidDevice {
                self.setForDevice(iohidDevice)
            }
        }
    }
    
    @objc public static func setForDevice(_ device: IOHIDDevice) {
        var multiplier: Double = 1.0
        var ignoreSensitivity = false
        let attachedDev = DeviceManager.attachedDevice(with: device)
        
        var isLogitechDPI = false
        if let attachedDev = attachedDev {
            if let vidVal = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int, vidVal == 0x046D {
                if attachedDev.supportsLogitechDPI || PointerConfig.hasSavedLogitechDPI {
                    isLogitechDPI = true
                }
            }
        }
        
        if isLogitechDPI {
            var dpi = PointerConfig.logitechDPI
            if dpi < 200 { dpi = 1000 }
            multiplier = 400.0 / dpi
            ignoreSensitivity = true
        }
        
        if PointerConfig.useSystemSpeed {
            self.deconfigureDevice(device)
        } else if PointerConfig.useParametricCurve {
            let sensitivity = PointerConfig.CPIMultiplier * multiplier
            let curve = PointerConfig.parametricCurve(ignoreSensitivity: ignoreSensitivity, isLogitechDPI: isLogitechDPI)
            _ = self.setForDevice(device, sensitivity: sensitivity, parametricCurve: curve)
        } else {
            let sensitivity = PointerConfig.CPIMultiplier * multiplier
            let curve = PointerConfig.tableBasedCurve(ignoreSensitivity: ignoreSensitivity, isLogitechDPI: isLogitechDPI)
            _ = self.setForDevice(device, sensitivity: sensitivity, tableBasedCurve: curve)
        }
    }
    
    @objc public static func deconfigureDevice(_ device: IOHIDDevice) {
        self.setForDevice(device, sensitivity: PointerConfig.systemSensitivity, systemCurveIndex: PointerConfig.systemAccelCurveIndex)
    }
    
    // MARK: - Core Level 3
    
    @discardableResult
    private static func setForDevice(_ device: IOHIDDevice, sensitivity: Double, tableBasedCurve points: [Any]) -> Bool {
        var serviceClient: IOHIDServiceClient? = nil
        var systemClient: IOHIDEventSystemClient? = nil
        self.copyEventServiceAndSystemClients(device, serviceClient: &serviceClient, systemClient: &systemClient)
        
        guard let sClient = serviceClient else {
            return false
        }
        
        var success = self.setSensitivity(sensitivity, sClient)
        if !success {
            return false
        }
        
        success = self.setAccelToTableBasedCurve(points, sClient)
        return success
    }
    
    @discardableResult
    private static func setForDevice(_ device: IOHIDDevice, sensitivity: Double, parametricCurve accelCurve: MFAppleAccelerationCurveParams) -> Bool {
        var serviceClient: IOHIDServiceClient? = nil
        var systemClient: IOHIDEventSystemClient? = nil
        self.copyEventServiceAndSystemClients(device, serviceClient: &serviceClient, systemClient: &systemClient)
        
        guard let sClient = serviceClient else {
            return false
        }
        
        var success = self.setSensitivity(sensitivity, sClient)
        if !success {
            return false
        }
        
        success = self.setAccelToParametricCurve(accelCurve, sClient)
        return success
    }
    
    private static func setForDevice(_ device: IOHIDDevice, sensitivity: Double, systemCurveIndex curveIndex: Double) {
        var adjustedCurveIndex = curveIndex
        if adjustedCurveIndex < -1.0 {
            adjustedCurveIndex = -1.0
        }
        
        var serviceClient: IOHIDServiceClient? = nil
        var systemClient: IOHIDEventSystemClient? = nil
        self.copyEventServiceAndSystemClients(device, serviceClient: &serviceClient, systemClient: &systemClient)
        
        guard let sClient = serviceClient else {
            return
        }
        
        let success = self.setSensitivity(sensitivity, sClient)
        if !success {
            return
        }
        
        self.removeCustomCurves(sClient)
        _ = self.selectAccelCurveWithIndex(adjustedCurveIndex, sClient)
    }
    
    // MARK: - Core Level 2
    
    private static func setSensitivity(_ sensitivity: Double, _ serviceClient: IOHIDServiceClient) -> Bool {
        let pointerResolution = 400.0 / sensitivity
        let pointerResolutionCF = PointerConfig.FloatToFixed(pointerResolution) as CFNumber
        return IOHIDServiceClientSetProperty(serviceClient, kIOHIDPointerResolutionKey as CFString, pointerResolutionCF)
    }
    
    private static func selectAccelCurveWithIndex(_ accelerationPresetIndex: Double, _ eventServiceClient: IOHIDServiceClient) -> Bool {
        if runningPreRelease() {
            let accelType = IOHIDServiceClientCopyProperty(eventServiceClient, kIOHIDPointerAccelerationTypeKey as CFString) as? String ?? "nil"
            DDLogDebug("Setting AccelCurve preset \(accelerationPresetIndex) for eventServiceClient: \(eventServiceClient) with kIOHIDPointerAccelerationTypeKey: \(accelType)")
        }
        
        let mouseAccelerationCF = PointerConfig.FloatToFixed(accelerationPresetIndex) as CFNumber
        return IOHIDServiceClientSetProperty(eventServiceClient, kIOHIDMouseAccelerationType as CFString, mouseAccelerationCF)
    }
    
    private static func setAccelToTableBasedCurve(_ points: [Any], _ eventServiceClient: IOHIDServiceClient) -> Bool {
        let table = createAccelerationTableWithArray(points).takeRetainedValue()
        printAccelerationTable(table)
        
        let success = self.setTableCurves(table, eventServiceClient)
        if !success { return false }
        
        return self.selectAccelCurveWithIndex(1.5, eventServiceClient)
    }
    
    private static func setAccelToParametricCurve(_ params: MFAppleAccelerationCurveParams, _ eventServiceClient: IOHIDServiceClient) -> Bool {
        let customCurveParams: [AnyHashable: Any] = [
            kHIDAccelIndexKey: PointerConfig.FloatToFixed(self.customCurveIndex),
            kHIDAccelGainLinearKey: PointerConfig.FloatToFixed(params.linearGain),
            kHIDAccelGainParabolicKey: PointerConfig.FloatToFixed(params.parabolicGain),
            kHIDAccelGainCubicKey: PointerConfig.FloatToFixed(params.cubicGain),
            kHIDAccelGainQuarticKey: PointerConfig.FloatToFixed(params.quarticGain),
            kHIDAccelTangentSpeedLinearKey: PointerConfig.FloatToFixed(params.capSpeedLinear),
            kHIDAccelTangentSpeedParabolicRootKey: PointerConfig.FloatToFixed(params.capSpeedParabolicRoot)
        ]
        
        let customCurveArray = [customCurveParams] as CFArray
        let success = IOHIDServiceClientSetProperty(eventServiceClient, kHIDAccelParametricCurvesKey as CFString, customCurveArray)
        if !success { return false }
        
        return self.selectAccelCurveWithIndex(self.customCurveIndex, eventServiceClient)
    }
    
    // MARK: - Core Level 1
    
    private static func parametricCurvesAreSet(_ serviceClient: IOHIDServiceClient) -> Bool {
        return IOHIDServiceClientCopyProperty(serviceClient, kHIDAccelParametricCurvesKey as CFString) != nil
    }
    
    private static func setTableCurves(_ curves: CFData, _ serviceClient: IOHIDServiceClient) -> Bool {
        if self.parametricCurvesAreSet(serviceClient) {
            DDLogError("Trying to set tableBasedCurve but parametricCurve is already set. This has no effect.")
            return false
        }
        return IOHIDServiceClientSetProperty(serviceClient, kIOHIDPointerAccelerationTableKey as CFString, curves)
    }
    
    private static func setParametricCurves(_ curves: CFArray, _ serviceClient: IOHIDServiceClient) -> Bool {
        return IOHIDServiceClientSetProperty(serviceClient, kHIDAccelParametricCurvesKey as CFString, curves)
    }
    
    @discardableResult
    private static func removeCustomCurves(_ serviceClient: IOHIDServiceClient) -> Bool {
        if self.parametricCurvesAreSet(serviceClient) {
            return self.setParametricCurves(PointerConfig.systemAccelCurves, serviceClient)
        } else {
            let defaultCurves = copyDefaultAccelerationTable().takeRetainedValue()
            let success = self.setTableCurves(defaultCurves, serviceClient)
            assert(success)
            return success
        }
    }
    
    private static func copyEventServiceClient_WithEventSystem(_ service: io_service_t, _ eventSystemClient: IOHIDEventSystemClient) -> IOHIDServiceClient? {
        if service == 0 { return nil }
        var serviceID: UInt64 = 0
        let kr = IORegistryEntryGetRegistryEntryID(service, &serviceID)
        if kr != KERN_SUCCESS { return nil }
        
        guard let clientUnmanaged = IOHIDEventSystemClientCopyServiceForRegistryID(eventSystemClient, serviceID) else {
            return nil
        }
        return clientUnmanaged.takeRetainedValue()
    }
    
    private static func copyEventServiceAndSystemClients(
        _ device: IOHIDDevice,
        serviceClient: inout IOHIDServiceClient?,
        systemClient: inout IOHIDEventSystemClient?
    ) {
        let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown Device"
        DDLogInfo("[PointerSpeed] copyEventServiceAndSystemClients starting for device: \(productName)")
        
        if let systemClientUnmanaged = IOHIDEventSystemClientCreateWithType(kCFAllocatorDefault, .passive, nil) {
            systemClient = systemClientUnmanaged.takeRetainedValue()
        } else {
            DDLogWarn("[PointerSpeed] Failed to create passive eventSystemClient")
            systemClient = nil
        }
        
        var client: IOHIDServiceClient? = nil
        let driverService = self.copyDriverService(device)
        if driverService != 0 {
            var serviceID: UInt64 = 0
            let kr = IORegistryEntryGetRegistryEntryID(driverService, &serviceID)
            if kr == KERN_SUCCESS {
                DDLogInfo("[PointerSpeed] driverService registry ID: 0x\(String(serviceID, radix: 16))")
                if let sysClient = systemClient {
                    client = self.copyEventServiceClient_WithEventSystem(driverService, sysClient)
                }
            }
            IOObjectRelease(driverService)
        }
        
        if client == nil && systemClient != nil {
            DDLogInfo("[PointerSpeed] copyDriverService failed or returned defunct client, attempting fallback property-matching search")
            let deviceVid = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber
            let devicePid = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber
            let deviceLoc = IOHIDDeviceGetProperty(device, kIOHIDLocationIDKey as CFString) as? NSNumber
            let deviceUnique = IOHIDDeviceGetProperty(device, kIOHIDUniqueIDKey as CFString) as? String
            
            DDLogInfo("[PointerSpeed] Target device properties: Vid = \(String(describing: deviceVid)), Pid = \(String(describing: devicePid)), Loc = \(String(describing: deviceLoc)), Unique = \(String(describing: deviceUnique))")
            
            if let sysClient = systemClient {
                if let servicesUnmanaged = IOHIDEventSystemClientCopyServices(sysClient) {
                    let services = servicesUnmanaged as! [IOHIDServiceClient]
                    DDLogInfo("[PointerSpeed] Number of services found: \(services.count)")
                    for candidateClient in services {
                        
                        let clientVid = IOHIDServiceClientCopyProperty(candidateClient, kIOHIDVendorIDKey as CFString) as? NSNumber
                        let clientPid = IOHIDServiceClientCopyProperty(candidateClient, kIOHIDProductIDKey as CFString) as? NSNumber
                        let clientLoc = IOHIDServiceClientCopyProperty(candidateClient, kIOHIDLocationIDKey as CFString) as? NSNumber
                        let clientUnique = IOHIDServiceClientCopyProperty(candidateClient, kIOHIDUniqueIDKey as CFString) as? String
                        let clientProduct = IOHIDServiceClientCopyProperty(candidateClient, kIOHIDProductKey as CFString) as? String
                        
                        DDLogInfo("[PointerSpeed] Client product: '\(clientProduct ?? "nil")', properties: Vid = \(String(describing: clientVid)), Pid = \(String(describing: clientPid)), Loc = \(String(describing: clientLoc)), Unique = \(String(describing: clientUnique))")
                        
                        var match = false
                        if let devUnique = deviceUnique, let cliUnique = clientUnique, !devUnique.isEmpty {
                            if devUnique == cliUnique {
                                match = true
                            }
                        }
                        
                        if !match, let devVid = deviceVid, let cliVid = clientVid, let devPid = devicePid, let cliPid = clientPid {
                            if devVid == cliVid && devPid == cliPid {
                                let conforms = (IOHIDServiceClientConformsTo(candidateClient, 0x01, 0x02) != 0) ||
                                               (IOHIDServiceClientConformsTo(candidateClient, 0x01, 0x01) != 0)
                                if conforms {
                                    let devLocVal = deviceLoc?.intValue ?? 0
                                    let cliLocVal = clientLoc?.intValue ?? 0
                                    
                                    if devLocVal != 0 && cliLocVal != 0 {
                                        if devLocVal == cliLocVal {
                                            match = true
                                        }
                                    } else {
                                        if let cliProd = clientProduct {
                                            if productName.lowercased() == cliProd.lowercased() {
                                                match = true
                                            }
                                        } else {
                                            match = true
                                        }
                                    }
                                }
                            }
                        }
                        
                        if match {
                            client = candidateClient
                            DDLogInfo("[PointerSpeed] Found matching service client via property matching for device: \(productName)")
                            break
                        }
                    }
                } else {
                    DDLogWarn("[PointerSpeed] IOHIDEventSystemClientCopyServices returned NULL")
                }
            }
        }
        
        serviceClient = client
        if serviceClient == nil {
            DDLogWarn("Failed to get service client. Can't set PointerSpeed (device: \(productName))")
        } else {
            DDLogInfo("[PointerSpeed] Successfully got service client for device \(productName)")
        }
    }
    
    private static func findChildOfRegistryEntryRecursive(_ entry: io_registry_entry_t, _ name: String) -> io_registry_entry_t {
        if entry == 0 { return 0 }
        var iterator: io_iterator_t = 0
        let kr = IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iterator)
        if kr != KERN_SUCCESS {
            return 0
        }
        
        var childEntry: io_registry_entry_t = 0
        var childEntryFound = false
        
        while true {
            childEntry = IOIteratorNext(iterator)
            if childEntry == 0 { break }
            
            var childName = [CChar](repeating: 0, count: 1000)
            IORegistryEntryGetNameInPlane(childEntry, kIOServicePlane, &childName)
            let childNameStr = String(cString: childName)
            if name == childNameStr {
                childEntryFound = true
                break
            }
            
            let deepChild = self.findChildOfRegistryEntryRecursive(childEntry, name)
            if deepChild != 0 {
                childEntryFound = true
                IOObjectRelease(childEntry)
                childEntry = deepChild
                break
            }
            IOObjectRelease(childEntry)
        }
        IOObjectRelease(iterator)
        return childEntryFound ? childEntry : 0
    }
    
    private static func printRegistrySubtree(_ entry: io_registry_entry_t, indent: Int) {
        var name = [CChar](repeating: 0, count: 128)
        var className = [CChar](repeating: 0, count: 128)
        IORegistryEntryGetName(entry, &name)
        IOObjectGetClass(entry, &className)
        var entryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(entry, &entryID)
        
        let indentStr = String(repeating: "  ", count: indent)
        let nameStr = String(cString: name)
        let classNameStr = String(cString: className)
        DDLogInfo("[PointerSpeed] Subtree: \(indentStr)Name: \(nameStr), Class: \(classNameStr), ID: 0x\(String(entryID, radix: 16))")
        
        var iterator: io_iterator_t = 0
        let kr = IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iterator)
        if kr == KERN_SUCCESS {
            while true {
                let child = IOIteratorNext(iterator)
                if child == 0 { break }
                self.printRegistrySubtree(child, indent: indent + 1)
                IOObjectRelease(child)
            }
            IOObjectRelease(iterator)
        }
    }
    
    private static func copyDriverService(_ device: IOHIDDevice) -> io_service_t {
        let iohidDeviceService = IOHIDDeviceGetService(device)
        if iohidDeviceService == 0 {
            DDLogWarn("[PointerSpeed] IOHIDDeviceGetService returned 0")
            return 0
        }
        
        var parentID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(iohidDeviceService, &parentID)
        var parentClassName = [CChar](repeating: 0, count: 128)
        IOObjectGetClass(iohidDeviceService, &parentClassName)
        let parentClassNameStr = String(cString: parentClassName)
        DDLogInfo("[PointerSpeed] copyDriverService checking iohidDeviceService ID: 0x\(String(parentID, radix: 16)), Class: \(parentClassNameStr)")
        
        let interfaceService = self.findChildOfRegistryEntryRecursive(iohidDeviceService, "IOHIDInterface")
        if interfaceService == 0 {
            DDLogWarn("[PointerSpeed] failed to find IOHIDInterface under iohidDeviceService (ID: 0x\(String(parentID, radix: 16)))")
            self.printRegistrySubtree(iohidDeviceService, indent: 0)
            IOObjectRelease(iohidDeviceService)
            return 0
        }
        
        let driverService = self.findChildOfRegistryEntryRecursive(interfaceService, "AppleUserHIDEventDriver")
        if driverService == 0 {
            DDLogWarn("[PointerSpeed] failed to find AppleUserHIDEventDriver under IOHIDInterface")
            self.printRegistrySubtree(iohidDeviceService, indent: 0)
        }
        
        IOObjectRelease(iohidDeviceService)
        IOObjectRelease(interfaceService)
        
        return driverService
    }
}
