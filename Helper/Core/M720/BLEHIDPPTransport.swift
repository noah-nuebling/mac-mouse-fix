import Foundation
import IOKit.hid

protocol HIDPPDeviceIO: AnyObject {
    var maximumInputReportSize: Int { get }

    func registerInputReport(
        buffer: UnsafeMutablePointer<UInt8>,
        length: Int,
        callback: @escaping IOHIDReportCallback,
        context: UnsafeMutableRawPointer
    )

    func unregisterInputReport(
        buffer: UnsafeMutablePointer<UInt8>,
        length: Int
    )

    func setOutputReport(reportID: CFIndex, data: Data) -> IOReturn
}

struct BLEHIDPPTransportTestHooks {
    let didCopyInputReport: () -> Void
    let didReleaseCallbackContext: () -> Void
    let didReleaseInputBuffer: () -> Void

    init(
        didCopyInputReport: @escaping () -> Void = {},
        didReleaseCallbackContext: @escaping () -> Void = {},
        didReleaseInputBuffer: @escaping () -> Void = {}
    ) {
        self.didCopyInputReport = didCopyInputReport
        self.didReleaseCallbackContext = didReleaseCallbackContext
        self.didReleaseInputBuffer = didReleaseInputBuffer
    }
}

final class BLEHIDPPTransport: HIDPPTransport {
    let deviceIndex: UInt8 = 0xFF
    let acceptedResponseDeviceIndices: Set<UInt8> = [0x00, 0xFF]
    var onReport: ((Data) -> Void)?

    private let device: Device
    private let io: HIDPPDeviceIO
    private let ioQueue: DispatchQueue
    private let sendGate = BLEHIDPPSendGate()
    private var inputBuffer: BLEHIDPPInputBuffer?
    private var callbackContext: BLEHIDPPCallbackContext?
    private var isInvalidated = false

    convenience init?(device: Device) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let iohidDevice = device.iohidDevice else { return nil }

        self.init(
            device: device,
            io: BLEIOHIDDeviceIO(owner: device, device: iohidDevice),
            ioQueue: DispatchQueue(label: "com.nuebling.mac-mouse-fix.m720.ble-hidpp-io")
        )
    }

    init(
        device: Device,
        io: HIDPPDeviceIO,
        ioQueue: DispatchQueue,
        testHooks: BLEHIDPPTransportTestHooks = BLEHIDPPTransportTestHooks()
    ) {
        dispatchPrecondition(condition: .onQueue(.main))

        self.device = device
        self.io = io
        self.ioQueue = ioQueue

        let bufferLength = max(20, io.maximumInputReportSize)
        let inputBuffer = BLEHIDPPInputBuffer(
            capacity: bufferLength,
            didRelease: testHooks.didReleaseInputBuffer
        )
        self.inputBuffer = inputBuffer

        let callbackContext = BLEHIDPPCallbackContext(
            transport: self,
            bufferCapacity: bufferLength,
            didCopyInputReport: testHooks.didCopyInputReport,
            didRelease: testHooks.didReleaseCallbackContext
        )
        self.callbackContext = callbackContext

        io.registerInputReport(
            buffer: inputBuffer.pointer,
            length: inputBuffer.capacity,
            callback: bleHIDPPInputReportCallback,
            context: Unmanaged.passUnretained(callbackContext).toOpaque()
        )
    }

    deinit {
        dispatchPrecondition(condition: .onQueue(.main))
        tearDownIfNeeded()
    }

    func send(_ report: Data, completion: @escaping (IOReturn) -> Void) {
        guard
            report.count == 20,
            report[0] == 0x11,
            report[1] == deviceIndex
        else {
            completeOnMain(kIOReturnBadArgument, completion: completion)
            return
        }

        guard let ticket = sendGate.makeTicket() else {
            completeOnMain(kIOReturnAborted, completion: completion)
            return
        }

        let io = self.io
        let sendGate = self.sendGate
        ioQueue.async {
            guard sendGate.beginWrite(ifCurrent: ticket) else {
                DispatchQueue.main.async { completion(kIOReturnAborted) }
                return
            }

            let result = io.setOutputReport(reportID: 0x11, data: report)
            DispatchQueue.main.async { completion(result) }
        }
    }

    func invalidate() {
        dispatchPrecondition(condition: .onQueue(.main))
        tearDownIfNeeded()
    }

    fileprivate func deliver(_ report: Data, generation: UInt64) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !isInvalidated else { return }
        onReport?(report)
    }

    private func tearDownIfNeeded() {
        guard !isInvalidated else { return }
        isInvalidated = true
        sendGate.invalidate()
        callbackContext?.invalidate()
        onReport = nil

        if
            let buffer = inputBuffer?.pointer,
            let length = inputBuffer?.capacity
        {
            io.unregisterInputReport(buffer: buffer, length: length)
        }

        callbackContext = nil
        inputBuffer = nil
    }

    private func completeOnMain(
        _ result: IOReturn,
        completion: @escaping (IOReturn) -> Void
    ) {
        DispatchQueue.main.async { completion(result) }
    }
}

private final class BLEHIDPPInputBuffer {
    let pointer: UnsafeMutablePointer<UInt8>
    let capacity: Int
    private let didRelease: () -> Void

    init(capacity: Int, didRelease: @escaping () -> Void) {
        self.capacity = capacity
        self.didRelease = didRelease
        pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        pointer.initialize(repeating: 0, count: capacity)
    }

    deinit {
        pointer.deinitialize(count: capacity)
        pointer.deallocate()
        didRelease()
    }
}

private final class BLEHIDPPCallbackContext {
    let bufferCapacity: Int
    private weak var transport: BLEHIDPPTransport?
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private let didCopyInputReport: () -> Void
    private let didRelease: () -> Void

    init(
        transport: BLEHIDPPTransport,
        bufferCapacity: Int,
        didCopyInputReport: @escaping () -> Void,
        didRelease: @escaping () -> Void
    ) {
        self.transport = transport
        self.bufferCapacity = bufferCapacity
        self.didCopyInputReport = didCopyInputReport
        self.didRelease = didRelease
    }

    deinit {
        didRelease()
    }

    func didCopyReport() {
        didCopyInputReport()
    }

    func currentGeneration() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return generation
    }

    func invalidate() {
        lock.lock()
        generation &+= 1
        transport = nil
        lock.unlock()
    }

    func deliver(_ report: Data, generation callbackGeneration: UInt64) {
        lock.lock()
        guard callbackGeneration == generation, let transport else {
            lock.unlock()
            return
        }
        lock.unlock()

        transport.deliver(report, generation: callbackGeneration)
    }
}

private let bleHIDPPInputReportCallback: IOHIDReportCallback = {
    rawContext,
    result,
    _,
    _,
    reportID,
    report,
    reportLength in

    guard
        result == kIOReturnSuccess,
        reportLength > 0,
        let rawContext
    else { return }

    let owner = Unmanaged<BLEHIDPPCallbackContext>
        .fromOpaque(rawContext)
        .takeUnretainedValue()
    guard reportLength <= CFIndex(owner.bufferCapacity) else { return }

    let copied = Data(bytes: report, count: Int(reportLength))
    owner.didCopyReport()
    let callbackGeneration = owner.currentGeneration()
    guard reportID == 0x11, copied.first == 0x11 else { return }

    DispatchQueue.main.async { [weak owner] in
        owner?.deliver(copied, generation: callbackGeneration)
    }
}

private final class BLEHIDPPSendGate {
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var isInvalidated = false

    func makeTicket() -> UInt64? {
        lock.lock()
        defer { lock.unlock() }
        return isInvalidated ? nil : generation
    }

    func beginWrite(ifCurrent ticket: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !isInvalidated && ticket == generation
    }

    func invalidate() {
        lock.lock()
        guard !isInvalidated else {
            lock.unlock()
            return
        }
        isInvalidated = true
        generation &+= 1
        lock.unlock()
    }
}

private final class BLEIOHIDDeviceIO: HIDPPDeviceIO {
    private let owner: Device
    private let device: Unmanaged<IOHIDDevice>

    init(owner: Device, device: IOHIDDevice) {
        self.owner = owner
        self.device = Unmanaged.passUnretained(device)
    }

    var maximumInputReportSize: Int {
        withBorrowedDevice { device in
            let value = IOHIDDeviceGetProperty(
                device,
                kIOHIDMaxInputReportSizeKey as CFString
            ) as? NSNumber
            return max(0, value?.intValue ?? 0)
        }
    }

    func registerInputReport(
        buffer: UnsafeMutablePointer<UInt8>,
        length: Int,
        callback: @escaping IOHIDReportCallback,
        context: UnsafeMutableRawPointer
    ) {
        withBorrowedDevice { device in
            IOHIDDeviceRegisterInputReportCallback(
                device,
                buffer,
                CFIndex(length),
                callback,
                context
            )
        }
    }

    func unregisterInputReport(
        buffer: UnsafeMutablePointer<UInt8>,
        length: Int
    ) {
        withBorrowedDevice { device in
            IOHIDDeviceRegisterInputReportCallback(
                device,
                buffer,
                CFIndex(length),
                nil,
                nil
            )
        }
    }

    func setOutputReport(reportID: CFIndex, data: Data) -> IOReturn {
        data.withUnsafeBytes { rawBuffer in
            guard let bytes = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return kIOReturnBadArgument
            }
            return withBorrowedDevice { device in
                IOHIDDeviceSetReport(
                    device,
                    kIOHIDReportTypeOutput,
                    reportID,
                    bytes,
                    CFIndex(data.count)
                )
            }
        }
    }

    private func withBorrowedDevice<T>(_ body: (IOHIDDevice) -> T) -> T {
        withExtendedLifetime(owner) {
            body(device.takeUnretainedValue())
        }
    }
}
