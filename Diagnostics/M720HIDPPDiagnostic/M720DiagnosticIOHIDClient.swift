import CoreFoundation
import Foundation
import IOKit
import IOKit.hid
#if canImport(XCTest)
@testable import Mac_Mouse_Fix_Helper
#endif

enum M720ReadOnlyOperation: Equatable {
    case rootGetFeature
    case getCount
    case getCidInfo(index: UInt8)
    case getCidReporting(cid: UInt16)

    func request(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        softwareID: UInt8
    ) -> HIDPPLongReport {
        switch self {
        case .rootGetFeature:
            return ReprogControlsV4.rootGetFeatureRequest(
                deviceIndex: deviceIndex,
                softwareID: softwareID
            )
        case .getCount:
            return ReprogControlsV4.getCountRequest(
                deviceIndex: deviceIndex,
                featureIndex: featureIndex,
                softwareID: softwareID
            )
        case let .getCidInfo(index):
            return ReprogControlsV4.getCidInfoRequest(
                deviceIndex: deviceIndex,
                featureIndex: featureIndex,
                softwareID: softwareID,
                index: index
            )
        case let .getCidReporting(cid):
            return ReprogControlsV4.getCidReportingRequest(
                deviceIndex: deviceIndex,
                featureIndex: featureIndex,
                softwareID: softwareID,
                cid: cid
            )
        }
    }
}

enum M720ReadOnlyRequestValidator {
    @discardableResult
    static func validate(
        _ report: Data,
        reprogFeatureIndex: UInt8?
    ) throws -> HIDPPRequestIdentity {
        guard report.count == 20 else { throw M720DiagnosticError.forbiddenRequest }
        let bytes = [UInt8](report)
        let function = bytes[3] >> 4
        let softwareID = bytes[3] & 0x0F
        guard bytes[0] == 0x11, bytes[1] == 0xFF, softwareID != 0 else {
            throw M720DiagnosticError.forbiddenRequest
        }

        if bytes[2] == 0 {
            if bytes[4] == 0x1C, bytes[5] == 0x00 {
                throw M720DiagnosticError.persistentFeatureForbidden
            }
            guard function == 0,
                  bytes[4] == 0x1B,
                  bytes[5] == 0x04,
                  bytes[6...].allSatisfy({ $0 == 0 })
            else { throw M720DiagnosticError.forbiddenRequest }
        } else {
            guard let reprogFeatureIndex, bytes[2] == reprogFeatureIndex else {
                throw M720DiagnosticError.forbiddenRequest
            }
            let isAllowed: Bool
            switch function {
            case ReprogControlsV4.Function.getCount.rawValue:
                isAllowed = bytes[4...].allSatisfy { $0 == 0 }
            case ReprogControlsV4.Function.getCidInfo.rawValue:
                isAllowed = bytes[5...].allSatisfy { $0 == 0 }
            case ReprogControlsV4.Function.getCidReporting.rawValue:
                isAllowed = bytes[6...].allSatisfy { $0 == 0 }
            default:
                isAllowed = false
            }
            guard isAllowed else { throw M720DiagnosticError.forbiddenRequest }
        }

        return HIDPPRequestIdentity(
            featureIndex: bytes[2],
            function: function,
            softwareID: softwareID
        )
    }
}

struct M720DiagnosticSoftwareIDAllocator {
    private static let candidates =
        Array(UInt8(0x8)...UInt8(0xF)) + Array(UInt8(0x1)...UInt8(0x7))
    private var usedSoftwareIDsByRequest: [UInt16: Set<UInt8>] = [:]

    mutating func allocateIdentity(
        featureIndex: UInt8,
        function: UInt8
    ) throws -> HIDPPRequestIdentity {
        let key = UInt16(featureIndex) << 8 | UInt16(function)
        var usedSoftwareIDs = usedSoftwareIDsByRequest[key, default: []]
        guard let softwareID = Self.candidates.first(where: {
            !usedSoftwareIDs.contains($0)
        }) else {
            throw M720DiagnosticError.softwareIDsExhausted
        }
        usedSoftwareIDs.insert(softwareID)
        usedSoftwareIDsByRequest[key] = usedSoftwareIDs
        return HIDPPRequestIdentity(
            featureIndex: featureIndex,
            function: function,
            softwareID: softwareID
        )
    }
}

struct M720ValidatedReportWriter {
    private let writeReport: (Data) -> Int32

    init(writeReport: @escaping (Data) -> Int32) {
        self.writeReport = writeReport
    }

    func send(_ report: Data, reprogFeatureIndex: UInt8?) throws {
        try M720ReadOnlyRequestValidator.validate(
            report,
            reprogFeatureIndex: reprogFeatureIndex
        )
        let result = writeReport(report)
        guard result == 0 else { throw M720DiagnosticError.transport(result) }
    }
}

protocol M720DiagnosticOpenedDevice: AnyObject {
    var accessMode: M720DiagnosticDeviceAccessMode { get }
    func captureSnapshot() throws -> NSDictionary
    func close()
}

protocol M720DiagnosticEnumeratedDeviceOwner: AnyObject {
    var vendorID: Int { get }
    var productID: Int { get }
    var transport: String { get }
    var serialNumber: String? { get }
    func open() throws -> M720DiagnosticOpenedDevice
}

enum M720DiagnosticDeviceAccessMode: String, Equatable {
    case deviceOpenedByCLI

    static func resolveDeviceOpen(status: IOReturn) throws -> Self {
        guard status == kIOReturnSuccess else {
            throw M720DiagnosticError.deviceOwnershipUnavailable(status)
        }
        return .deviceOpenedByCLI
    }

    var closesDevice: Bool { true }
    var unschedulesDevice: Bool { true }
}

struct M720DiagnosticDeviceCandidate {
    let vendorID: Int
    let productID: Int
    let transport: String
    let serialNumber: String?
    private let openDevice: () throws -> M720DiagnosticOpenedDevice

    init(
        vendorID: Int,
        productID: Int,
        transport: String,
        serialNumber: String?,
        open: @escaping () throws -> M720DiagnosticOpenedDevice
    ) {
        self.vendorID = vendorID
        self.productID = productID
        self.transport = transport
        self.serialNumber = serialNumber
        openDevice = open
    }

    func open() throws -> M720DiagnosticOpenedDevice {
        try openDevice()
    }
}

struct M720DiagnosticIOHIDClient {
    private let helperPortExists: () -> Bool
    private let enumerateDevices: (() throws -> [M720DiagnosticDeviceCandidate])?
    private let captureSnapshotOverride: ((Int, Int) throws -> NSDictionary)?

    static let production = M720DiagnosticIOHIDClient(
        helperPortExists: M720DiagnosticMessagePortClient.helperPortExists,
        enumerateDevices: enumerateProductionDevices
    )

    init(
        helperPortExists: @escaping () -> Bool,
        captureSnapshot: @escaping (Int, Int) throws -> NSDictionary
    ) {
        self.helperPortExists = helperPortExists
        enumerateDevices = nil
        captureSnapshotOverride = captureSnapshot
    }

    init(
        helperPortExists: @escaping () -> Bool,
        enumerateDevices: @escaping () throws -> [M720DiagnosticDeviceCandidate]
    ) {
        self.helperPortExists = helperPortExists
        self.enumerateDevices = enumerateDevices
        captureSnapshotOverride = nil
    }

    func snapshot(vendorID: Int, productID: Int) throws -> NSDictionary {
        guard !helperPortExists() else { throw M720DiagnosticError.helperRunning }
        if let captureSnapshotOverride {
            return try captureSnapshotOverride(vendorID, productID)
        }
        guard let enumerateDevices else { throw M720DiagnosticError.noMatchingDevice }
        let matches = try enumerateDevices().filter {
            $0.vendorID == vendorID &&
                $0.productID == productID &&
                $0.transport == "Bluetooth Low Energy"
        }
        guard !matches.isEmpty else { throw M720DiagnosticError.noMatchingDevice }
        guard matches.count == 1 else { throw M720DiagnosticError.ambiguousDevice }
        guard let serialNumber = matches[0].serialNumber, !serialNumber.isEmpty else {
            throw M720DiagnosticError.missingSerialIdentity
        }

        let opened = try matches[0].open()
        defer { opened.close() }
        return try opened.captureSnapshot()
    }

    static func makeCandidates(
        retaining owners: [M720DiagnosticEnumeratedDeviceOwner]
    ) -> [M720DiagnosticDeviceCandidate] {
        owners.map { owner in
            M720DiagnosticDeviceCandidate(
                vendorID: owner.vendorID,
                productID: owner.productID,
                transport: owner.transport,
                serialNumber: owner.serialNumber,
                open: { [owner] in try owner.open() }
            )
        }
    }

    private static func enumerateProductionDevices() throws -> [M720DiagnosticDeviceCandidate] {
        guard let matching = IOServiceMatching("IOHIDDevice") else { return [] }
        var iterator: io_iterator_t = IO_OBJECT_NULL
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            matching,
            &iterator
        ) == KERN_SUCCESS else {
            return []
        }
        defer {
            if iterator != IO_OBJECT_NULL {
                _ = IOObjectRelease(iterator)
            }
        }

        var owners: [M720DiagnosticEnumeratedDeviceOwner] = []
        while true {
            let service = IOIteratorNext(iterator)
            guard service != IO_OBJECT_NULL else { break }
            let device = IOHIDDeviceCreate(kCFAllocatorDefault, service)
            _ = IOObjectRelease(service)
            guard let device else { continue }

            let vendorID = integerProperty(device, key: kIOHIDVendorIDKey) ?? -1
            let productID = integerProperty(device, key: kIOHIDProductIDKey) ?? -1
            let transport = IOHIDDeviceGetProperty(
                device,
                kIOHIDTransportKey as CFString
            ) as? String ?? ""
            let serialNumber = IOHIDDeviceGetProperty(
                device,
                kIOHIDSerialNumberKey as CFString
            ) as? String
            guard vendorID == M720Profile.vendorID,
                  productID == M720Profile.bluetoothLEProductID,
                  transport == M720Profile.bluetoothLETransport
            else { continue }

            owners.append(M720ProductionEnumeratedDeviceOwner(
                device: device,
                vendorID: vendorID,
                productID: productID,
                transport: transport,
                serialNumber: serialNumber
            ))
        }
        return makeCandidates(retaining: owners)
    }

    private static func integerProperty(_ device: IOHIDDevice, key: String) -> Int? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
    }
}

private final class M720ProductionEnumeratedDeviceOwner:
    M720DiagnosticEnumeratedDeviceOwner
{
    private let device: IOHIDDevice
    let vendorID: Int
    let productID: Int
    let transport: String
    let serialNumber: String?

    init(
        device: IOHIDDevice,
        vendorID: Int,
        productID: Int,
        transport: String,
        serialNumber: String?
    ) {
        self.device = device
        self.vendorID = vendorID
        self.productID = productID
        self.transport = transport
        self.serialNumber = serialNumber
    }

    func open() throws -> M720DiagnosticOpenedDevice {
        let status = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        let accessMode = try M720DiagnosticDeviceAccessMode.resolveDeviceOpen(status: status)
        return M720ProductionOpenedDevice(
            device: device,
            runLoop: CFRunLoopGetCurrent(),
            vendorID: vendorID,
            productID: productID,
            transport: transport,
            serialNumber: serialNumber ?? "",
            accessMode: accessMode
        )
    }
}

private struct M720DiagnosticExchange {
    let name: String
    let request: Data
    let response: Data

    var payload: NSDictionary {
        [
            "name": name,
            "request": [UInt8](request),
            "response": [UInt8](response),
        ]
    }
}

private struct M720DiagnosticOperationResponse {
    let inbound: HIDPPInbound
    let exchange: M720DiagnosticExchange
}

private final class M720ProductionOpenedDevice: M720DiagnosticOpenedDevice {
    private static let responseTimeout: TimeInterval = 1
    private let device: IOHIDDevice
    private let runLoop: CFRunLoop
    private let vendorID: Int
    private let productID: Int
    private let transport: String
    private let serialNumber: String
    let accessMode: M720DiagnosticDeviceAccessMode
    private let inputCapacity: Int
    private let inputBuffer: UnsafeMutablePointer<UInt8>
    private var softwareIDAllocator = M720DiagnosticSoftwareIDAllocator()
    private var pendingIdentity: HIDPPRequestIdentity?
    private var pendingResponse: (Data, HIDPPInbound)?
    private var malformedPendingResponse = false
    private var sentCounts: [UInt16: UInt64] = [:]
    private var exchanges: [M720DiagnosticExchange] = []
    private var isClosed = false

    init(
        device: IOHIDDevice,
        runLoop: CFRunLoop,
        vendorID: Int,
        productID: Int,
        transport: String,
        serialNumber: String,
        accessMode: M720DiagnosticDeviceAccessMode
    ) {
        self.device = device
        self.runLoop = runLoop
        self.vendorID = vendorID
        self.productID = productID
        self.transport = transport
        self.serialNumber = serialNumber
        self.accessMode = accessMode
        let advertised = (IOHIDDeviceGetProperty(
            device,
            kIOHIDMaxInputReportSizeKey as CFString
        ) as? NSNumber)?.intValue ?? 0
        inputCapacity = max(20, advertised)
        inputBuffer = .allocate(capacity: inputCapacity)
        inputBuffer.initialize(repeating: 0, count: inputCapacity)
        IOHIDDeviceRegisterInputReportCallback(
            device,
            inputBuffer,
            CFIndex(inputCapacity),
            m720DiagnosticInputReportCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        IOHIDDeviceScheduleWithRunLoop(
            device,
            runLoop,
            CFRunLoopMode.defaultMode.rawValue
        )
    }

    deinit {
        close()
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        pendingIdentity = nil
        pendingResponse = nil
        IOHIDDeviceRegisterInputReportCallback(
            device,
            inputBuffer,
            CFIndex(inputCapacity),
            nil,
            nil
        )
        if accessMode.unschedulesDevice {
            IOHIDDeviceUnscheduleFromRunLoop(
                device,
                runLoop,
                CFRunLoopMode.defaultMode.rawValue
            )
        }
        if accessMode.closesDevice {
            _ = IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        inputBuffer.deinitialize(count: inputCapacity)
        inputBuffer.deallocate()
    }

    func captureSnapshot() throws -> NSDictionary {
        let lookupResponse = try perform(.rootGetFeature, featureIndex: 0)
        let lookup = try ReprogControlsV4.decodeFeatureLookup(
            try responseParameters(lookupResponse.inbound)
        )
        guard lookup.featureIndex != 0 else { throw M720DiagnosticError.unsupportedFeature }

        let countResponse = try perform(.getCount, featureIndex: lookup.featureIndex)
        let count = try ReprogControlsV4.decodeControlCount(
            try responseParameters(countResponse.inbound)
        )
        var controls: [HIDPPControlInfo] = []
        for index in 0..<count {
            let response = try perform(
                .getCidInfo(index: index),
                featureIndex: lookup.featureIndex
            )
            controls.append(try ReprogControlsV4.decodeControlInfo(
                try responseParameters(response.inbound)
            ))
        }

        let targetCIDs = Set(M720Profile.cidToButton.keys)
        let targetControls = controls
            .filter { targetCIDs.contains($0.cid) }
            .sorted { $0.cid < $1.cid }
        guard Set(targetControls.map(\.cid)) == targetCIDs else {
            throw M720DiagnosticError.unsupportedFeature
        }

        var targets: [NSDictionary] = []
        for control in targetControls {
            do {
                try ReprogControlsV4.validateTarget(control)
            } catch {
                throw M720DiagnosticError.unsupportedFeature
            }
            let response = try perform(
                .getCidReporting(cid: control.cid),
                featureIndex: lookup.featureIndex
            )
            let reporting = try ReprogControlsV4.decodeReportingState(
                try responseParameters(response.inbound)
            )
            guard reporting.cid == control.cid else {
                throw M720DiagnosticError.malformedResponse
            }
            targets.append([
                "cid": NSNumber(value: control.cid),
                "taskID": NSNumber(value: control.taskID),
                "controlFlags": NSNumber(value: control.flags),
                "position": NSNumber(value: control.position),
                "group": NSNumber(value: control.group),
                "groupMask": NSNumber(value: control.groupMask),
                "controlRawXYFlags": NSNumber(value: control.rawXYFlags),
                "reportingFlags": NSNumber(value: reporting.flags),
                "divert": reporting.isDiverted,
                "persist": reporting.isPersistent,
                "rawXY": reporting.hasRawXY,
                "remappedCID": NSNumber(value: reporting.remappedCID),
            ])
        }

        let invalidResponse = try perform(
            .getCidInfo(index: count),
            featureIndex: lookup.featureIndex,
            name: "ReprogControlsV4.GetCidInfo[advertisedCount]"
        )
        let invalidErrorCode: UInt8
        guard case let .error(frame) = invalidResponse.inbound else {
            throw M720DiagnosticError.malformedResponse
        }
        invalidErrorCode = frame.code

        let counts = sentCounts.sorted { $0.key < $1.key }.map { key, value in
            [
                "feature": NSNumber(value: UInt8(key >> 8)),
                "function": NSNumber(value: UInt8(key & 0xFF)),
                "count": NSNumber(value: value),
            ] as NSDictionary
        }
        return [
            "accessMode": accessMode.rawValue,
            "device": [
                "vendorID": NSNumber(value: vendorID),
                "productID": NSNumber(value: productID),
                "transport": transport,
                "serialNumber": serialNumber,
            ],
            "featureIndex": NSNumber(value: lookup.featureIndex),
            "featureType": NSNumber(value: lookup.featureType),
            "featureVersion": NSNumber(value: lookup.featureVersion),
            "advertisedCount": NSNumber(value: count),
            "targets": targets,
            "invalidGetErrorCode": NSNumber(value: invalidErrorCode),
            "sentCounts": counts,
            "exchanges": exchanges.map(\.payload),
        ]
    }

    private func perform(
        _ operation: M720ReadOnlyOperation,
        featureIndex: UInt8,
        name: String? = nil
    ) throws -> M720DiagnosticOperationResponse {
        guard !isClosed else { throw M720DiagnosticError.transport(kIOReturnAborted) }
        let allocatedIdentity = try softwareIDAllocator.allocateIdentity(
            featureIndex: featureIndex,
            function: operation.function
        )
        let request = operation.request(
            deviceIndex: 0xFF,
            featureIndex: featureIndex,
            softwareID: allocatedIdentity.softwareID
        ).data
        let identity = try M720ReadOnlyRequestValidator.validate(
            request,
            reprogFeatureIndex: operation == .rootGetFeature ? nil : featureIndex
        )
        guard identity == allocatedIdentity else {
            throw M720DiagnosticError.forbiddenRequest
        }
        pendingIdentity = identity
        pendingResponse = nil
        malformedPendingResponse = false
        defer {
            pendingIdentity = nil
            pendingResponse = nil
            malformedPendingResponse = false
        }

        let writer = M720ValidatedReportWriter { [device] report in
            report.withUnsafeBytes { raw in
                guard let bytes = raw.bindMemory(to: UInt8.self).baseAddress else {
                    return kIOReturnBadArgument
                }
                return IOHIDDeviceSetReport(
                    device,
                    kIOHIDReportTypeOutput,
                    0x11,
                    bytes,
                    CFIndex(report.count)
                )
            }
        }
        try writer.send(request, reprogFeatureIndex: operation == .rootGetFeature ? nil : featureIndex)
        let countKey = UInt16(identity.featureIndex) << 8 | UInt16(identity.function)
        sentCounts[countKey, default: 0] &+= 1

        let deadline = CFAbsoluteTimeGetCurrent() + Self.responseTimeout
        while pendingResponse == nil,
              !malformedPendingResponse,
              CFAbsoluteTimeGetCurrent() < deadline {
            let remaining = deadline - CFAbsoluteTimeGetCurrent()
            _ = CFRunLoopRunInMode(
                CFRunLoopMode.defaultMode,
                min(0.05, max(0, remaining)),
                true
            )
        }
        if malformedPendingResponse { throw M720DiagnosticError.malformedResponse }
        guard let (rawResponse, inbound) = pendingResponse else {
            throw M720DiagnosticError.timeout
        }
        let exchange = M720DiagnosticExchange(
            name: name ?? operation.diagnosticName,
            request: request,
            response: rawResponse
        )
        exchanges.append(exchange)
        return M720DiagnosticOperationResponse(inbound: inbound, exchange: exchange)
    }

    fileprivate func receive(
        result: IOReturn,
        reportID: UInt32,
        report: UnsafeMutablePointer<UInt8>,
        length: Int
    ) {
        guard result == kIOReturnSuccess,
              reportID == 0x11,
              length == 20,
              pendingIdentity != nil
        else { return }
        let data = Data(bytes: report, count: length)
        guard data.first == 0x11 else { return }
        let inbound: HIDPPInbound
        do {
            inbound = try HIDPPLongReport.decode(
                data,
                acceptedDeviceIndices: [0x00, 0xFF]
            )
        } catch {
            malformedPendingResponse = true
            return
        }
        let identity: HIDPPRequestIdentity
        switch inbound {
        case let .response(responseIdentity, _): identity = responseIdentity
        case let .error(frame): identity = frame.identity
        case .event: return
        }
        guard identity == pendingIdentity else { return }
        pendingResponse = (data, inbound)
    }

    private func responseParameters(_ inbound: HIDPPInbound) throws -> Data {
        switch inbound {
        case let .response(_, parameters): return parameters
        case let .error(frame): throw M720DiagnosticError.device(frame.code)
        case .event: throw M720DiagnosticError.malformedResponse
        }
    }
}

private extension M720ReadOnlyOperation {
    var function: UInt8 {
        switch self {
        case .rootGetFeature: return 0
        case .getCount: return ReprogControlsV4.Function.getCount.rawValue
        case .getCidInfo: return ReprogControlsV4.Function.getCidInfo.rawValue
        case .getCidReporting: return ReprogControlsV4.Function.getCidReporting.rawValue
        }
    }

    var diagnosticName: String {
        switch self {
        case .rootGetFeature: return "Root.GetFeature[1B04]"
        case .getCount: return "ReprogControlsV4.GetCount"
        case let .getCidInfo(index): return "ReprogControlsV4.GetCidInfo[\(index)]"
        case let .getCidReporting(cid):
            return String(format: "ReprogControlsV4.GetCidReporting[%04X]", cid)
        }
    }
}

private let m720DiagnosticInputReportCallback: IOHIDReportCallback = {
    context,
    result,
    _,
    _,
    reportID,
    report,
    reportLength in

    guard let context else { return }
    let owner = Unmanaged<M720ProductionOpenedDevice>
        .fromOpaque(context)
        .takeUnretainedValue()
    owner.receive(
        result: result,
        reportID: reportID,
        report: report,
        length: Int(reportLength)
    )
}
