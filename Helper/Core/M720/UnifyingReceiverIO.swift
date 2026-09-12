import Foundation
import IOKit.hid

struct UnifyingReceiverInterfaceDescriptor: Equatable {
    let registryEntryID: UInt64
    let vendorID: Int
    let productID: Int
    let transport: String
    let locationID: UInt32?
    let usagePage: Int
    let usage: Int
}

enum UnifyingReceiverInterfaceMatcher {
    static func selectVendorInterface(
        for candidate: UnifyingReceiverInterfaceDescriptor,
        from interfaces: [UnifyingReceiverInterfaceDescriptor]
    ) -> UnifyingReceiverInterfaceDescriptor? {
        guard M720Profile.isUnifyingReceiverCandidate(
            vendorID: candidate.vendorID,
            productID: candidate.productID,
            transport: candidate.transport
        ), let locationID = candidate.locationID else { return nil }

        let matches = interfaces.filter {
            $0.vendorID == M720Profile.vendorID &&
                $0.productID == M720Profile.unifyingReceiverProductID &&
                $0.transport == M720Profile.unifyingReceiverTransport &&
                $0.locationID == locationID &&
                $0.usagePage == 0xFF00 &&
                $0.usage == 0x01
        }
        guard matches.count == 1 else { return nil }
        return matches[0]
    }
}

final class UnifyingReceiverIOHIDDeviceIO: HIDPPDeviceIO {
    private let manager: IOHIDManager
    private let device: IOHIDDevice

    convenience init?(receiverDevice: Device) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let candidateDevice = receiverDevice.iohidDevice,
              let candidate = Self.descriptor(for: candidateDevice)
        else { return nil }

        let manager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
        let match: [String: Any] = [
            kIOHIDVendorIDKey: M720Profile.vendorID,
            kIOHIDProductIDKey: M720Profile.unifyingReceiverProductID,
            kIOHIDTransportKey: M720Profile.unifyingReceiverTransport,
        ]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.defaultMode.rawValue
        )
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess,
              let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>
        else {
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.defaultMode.rawValue
            )
            if openResult == kIOReturnSuccess {
                IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            }
            return nil
        }

        let interfaces = deviceSet.compactMap(Self.descriptor(for:))
        guard let selected = UnifyingReceiverInterfaceMatcher.selectVendorInterface(
            for: candidate,
            from: interfaces
        ), let selectedDevice = deviceSet.first(where: {
            Self.registryEntryID(for: $0) == selected.registryEntryID
        }) else {
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.defaultMode.rawValue
            )
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return nil
        }

        self.init(manager: manager, device: selectedDevice)
    }

    private init(manager: IOHIDManager, device: IOHIDDevice) {
        self.manager = manager
        self.device = device
    }

    deinit {
        dispatchPrecondition(condition: .onQueue(.main))
        IOHIDManagerUnscheduleFromRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.defaultMode.rawValue
        )
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    var maximumInputReportSize: Int {
        let value = IOHIDDeviceGetProperty(
            device,
            kIOHIDMaxInputReportSizeKey as CFString
        ) as? NSNumber
        return max(0, value?.intValue ?? 0)
    }

    func registerInputReport(
        buffer: UnsafeMutablePointer<UInt8>,
        length: Int,
        callback: @escaping IOHIDReportCallback,
        context: UnsafeMutableRawPointer
    ) {
        IOHIDDeviceRegisterInputReportCallback(
            device,
            buffer,
            CFIndex(length),
            callback,
            context
        )
    }

    func unregisterInputReport(
        buffer: UnsafeMutablePointer<UInt8>,
        length: Int
    ) {
        IOHIDDeviceRegisterInputReportCallback(
            device,
            buffer,
            CFIndex(length),
            nil,
            nil
        )
    }

    func setOutputReport(reportID: CFIndex, data: Data) -> IOReturn {
        data.withUnsafeBytes { rawBuffer in
            guard let bytes = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return kIOReturnBadArgument
            }
            return IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeOutput,
                reportID,
                bytes,
                CFIndex(data.count)
            )
        }
    }

    private static func descriptor(
        for device: IOHIDDevice
    ) -> UnifyingReceiverInterfaceDescriptor? {
        guard let vendorID = numberProperty(kIOHIDVendorIDKey, device: device),
              let productID = numberProperty(kIOHIDProductIDKey, device: device),
              let transport = IOHIDDeviceGetProperty(
                  device,
                  kIOHIDTransportKey as CFString
              ) as? String,
              let usagePage = numberProperty(
                  kIOHIDPrimaryUsagePageKey,
                  fallback: kIOHIDDeviceUsagePageKey,
                  device: device
              ),
              let usage = numberProperty(
                  kIOHIDPrimaryUsageKey,
                  fallback: kIOHIDDeviceUsageKey,
                  device: device
              )
        else { return nil }

        let locationID = numberProperty(kIOHIDLocationIDKey, device: device)?.uint32Value
        return UnifyingReceiverInterfaceDescriptor(
            registryEntryID: registryEntryID(for: device),
            vendorID: vendorID.intValue,
            productID: productID.intValue,
            transport: transport,
            locationID: locationID,
            usagePage: usagePage.intValue,
            usage: usage.intValue
        )
    }

    private static func numberProperty(
        _ key: String,
        fallback: String? = nil,
        device: IOHIDDevice
    ) -> NSNumber? {
        if let value = IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber {
            return value
        }
        guard let fallback else { return nil }
        return IOHIDDeviceGetProperty(device, fallback as CFString) as? NSNumber
    }

    private static func registryEntryID(for device: IOHIDDevice) -> UInt64 {
        let service = IOHIDDeviceGetService(device)
        guard service != IO_OBJECT_NULL else { return 0 }
        var value: UInt64 = 0
        return IORegistryEntryGetRegistryEntryID(service, &value) == KERN_SUCCESS
            ? value
            : 0
    }
}
