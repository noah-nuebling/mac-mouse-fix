import Foundation
import IOKit.hid
import XCTest
@testable import Mac_Mouse_Fix_Helper

final class BLEHIDPPTransportTests: XCTestCase {
    func testUsesUniversalRequestIndexAndAcceptsBothBLEReplyAliases() {
        let transport = BLEHIDPPTransport(
            device: Device.unitTestDevice(),
            io: FakeHIDPPDeviceIO(maximumInputReportSize: 20),
            ioQueue: DispatchQueue(label: "com.nuebling.mac-mouse-fix.tests.m720-ble-io.indices")
        )

        XCTAssertEqual(transport.deviceIndex, 0xFF)
        XCTAssertEqual(transport.acceptedResponseDeviceIndices, [0x00, 0xFF])
        transport.invalidate()
    }

    func testRegistersOnMainWithAtLeastLongReportAndAdvertisedCapacity() {
        XCTAssertTrue(Thread.isMainThread)

        let smallIO = FakeHIDPPDeviceIO(maximumInputReportSize: 7)
        var smallTransport: BLEHIDPPTransport? = BLEHIDPPTransport(
            device: Device.unitTestDevice(),
            io: smallIO,
            ioQueue: DispatchQueue(label: "com.nuebling.mac-mouse-fix.tests.m720-ble-io.small")
        )
        XCTAssertEqual(smallIO.registeredLength, 20)
        XCTAssertTrue(smallIO.registeredOnMain)
        smallTransport?.invalidate()
        smallTransport = nil

        let largeIO = FakeHIDPPDeviceIO(maximumInputReportSize: 64)
        var largeTransport: BLEHIDPPTransport? = BLEHIDPPTransport(
            device: Device.unitTestDevice(),
            io: largeIO,
            ioQueue: DispatchQueue(label: "com.nuebling.mac-mouse-fix.tests.m720-ble-io.large")
        )
        XCTAssertEqual(largeIO.registeredLength, 64)
        XCTAssertTrue(largeIO.registeredOnMain)
        largeTransport?.invalidate()
        largeTransport = nil
    }

    func testCallbackCopiesExactBytesBeforeReturnAndDeliversImmutableDataOnMain() {
        let harness = BLETransportHarness(maximumInputReportSize: 64)
        let report = makeLongReport(featureIndex: 0x04, functionAndSoftwareID: 0x18)

        harness.invokeCallback(bytes: report)
        harness.overwriteReusableBuffer(with: 0xA5)
        drainMainQueue()

        XCTAssertEqual(harness.deliveredReports, [Data(report)])
        XCTAssertEqual(harness.deliveryWasOnMain, [true])
        XCTAssertEqual(
            harness.events.snapshot(),
            ["register", "callback entry", "report copy", "callback return", "main delivery"]
        )
    }

    func testCallbackChecksResultAndBoundsBeforeCopyThenFiltersLongReportID() {
        let harness = BLETransportHarness(maximumInputReportSize: 20)

        harness.invokeCallback(
            bytes: makeLongReport(),
            result: kIOReturnError
        )
        harness.invokeCallback(
            bytes: makeLongReport(),
            reportedLength: 0
        )
        harness.invokeCallback(
            bytes: makeLongReport(),
            reportedLength: 21
        )

        var wrongByteReport = makeLongReport()
        wrongByteReport[0] = 0x10
        harness.invokeCallback(bytes: wrongByteReport, reportID: 0x11)
        harness.invokeCallback(bytes: makeLongReport(), reportID: 0x10)
        drainMainQueue()

        XCTAssertEqual(harness.copyCount, 2, "Only in-bounds successful callbacks may copy")
        XCTAssertTrue(harness.deliveredReports.isEmpty)
    }

    func testInvalidationDropsQueuedOldGenerationReportAndReleasesAfterUnregister() {
        let harness = BLETransportHarness(maximumInputReportSize: 32)
        harness.invokeCallback(bytes: makeLongReport())

        harness.transport.invalidate()

        XCTAssertEqual(
            harness.events.snapshot(),
            [
                "register",
                "callback entry",
                "report copy",
                "callback return",
                "unregister",
                "context release",
                "buffer release",
            ]
        )
        XCTAssertTrue(harness.io.callbackStateWasAliveDuringUnregister)
        drainMainQueue()
        XCTAssertTrue(harness.deliveredReports.isEmpty)
    }

    func testInvalidationIsIdempotentAndUnregistersTheRegisteredBuffer() {
        let harness = BLETransportHarness(maximumInputReportSize: 31)
        let registeredAddress = harness.io.registeredBufferAddress

        harness.transport.invalidate()
        harness.transport.invalidate()

        XCTAssertEqual(harness.io.unregisterCallCount, 1)
        XCTAssertEqual(harness.io.unregisteredBufferAddress, registeredAddress)
        XCTAssertEqual(harness.io.unregisteredLength, 31)
        XCTAssertNil(harness.transport.onReport)
    }

    func testDeinitImplicitlyUnregistersBeforeReleasingCallbackState() {
        let events = ThreadSafeEventRecorder()
        let io = FakeHIDPPDeviceIO(maximumInputReportSize: 20, events: events)
        var transport: BLEHIDPPTransport? = BLEHIDPPTransport(
            device: Device.unitTestDevice(),
            io: io,
            ioQueue: DispatchQueue(label: "com.nuebling.mac-mouse-fix.tests.m720-ble-io.deinit"),
            testHooks: BLEHIDPPTransportTestHooks(
                didCopyInputReport: {},
                didReleaseCallbackContext: { events.append("context release") },
                didReleaseInputBuffer: { events.append("buffer release") }
            )
        )

        XCTAssertNotNil(transport)
        transport = nil

        XCTAssertEqual(
            events.snapshot(),
            ["register", "unregister", "context release", "buffer release"]
        )
        XCTAssertEqual(io.unregisterCallCount, 1)
    }

    func testSendUsesSerialIOAndPassesCompleteLongOutputReport() {
        let io = FakeHIDPPDeviceIO(maximumInputReportSize: 20)
        let transport = BLEHIDPPTransport(
            device: Device.unitTestDevice(),
            io: io,
            ioQueue: DispatchQueue(label: "com.nuebling.mac-mouse-fix.tests.m720-ble-io.serial")
        )
        let first = Data(makeLongReport(featureIndex: 0x04, functionAndSoftwareID: 0x18))
        let second = Data(makeLongReport(featureIndex: 0x05, functionAndSoftwareID: 0x29))
        let completions = expectation(description: "both sends complete")
        completions.expectedFulfillmentCount = 2

        transport.send(first) { result in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(result, kIOReturnSuccess)
            completions.fulfill()
        }
        transport.send(second) { result in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(result, kIOReturnSuccess)
            completions.fulfill()
        }

        wait(for: [completions], timeout: 2)
        XCTAssertEqual(io.outputCalls.map(\.reportID), [0x11, 0x11])
        XCTAssertEqual(io.outputCalls.map(\.data), [first, second])
        XCTAssertEqual(io.maximumConcurrentOutputCalls, 1)
        XCTAssertEqual(io.outputCalls.map(\.wasOnMain), [false, false])
        transport.invalidate()
    }

    func testInvalidOutboundReportsCompleteBadArgumentOnMainWithoutIO() {
        let io = FakeHIDPPDeviceIO(maximumInputReportSize: 20)
        let transport = BLEHIDPPTransport(
            device: Device.unitTestDevice(),
            io: io,
            ioQueue: DispatchQueue(label: "com.nuebling.mac-mouse-fix.tests.m720-ble-io.invalid")
        )
        var wrongLength = makeLongReport()
        wrongLength.removeLast()
        var wrongReportID = makeLongReport()
        wrongReportID[0] = 0x10
        var wrongDeviceIndex = makeLongReport()
        wrongDeviceIndex[1] = 0x00
        let completions = expectation(description: "invalid sends complete")
        completions.expectedFulfillmentCount = 3

        for bytes in [wrongLength, wrongReportID, wrongDeviceIndex] {
            transport.send(Data(bytes)) { result in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(result, kIOReturnBadArgument)
                completions.fulfill()
            }
        }

        wait(for: [completions], timeout: 2)
        XCTAssertTrue(io.outputCalls.isEmpty)
        transport.invalidate()
    }

    func testInvalidationAbortsQueuedWriteButAllowsAlreadyInFlightWriteToComplete() {
        let io = FakeHIDPPDeviceIO(maximumInputReportSize: 20)
        let firstSetReportEntered = DispatchSemaphore(value: 0)
        let allowFirstSetReportToReturn = DispatchSemaphore(value: 0)
        io.outputHandler = { callIndex, _, _ in
            if callIndex == 0 {
                firstSetReportEntered.signal()
                _ = allowFirstSetReportToReturn.wait(timeout: .now() + 2)
                return kIOReturnSuccess
            }
            return kIOReturnError
        }
        let transport = BLEHIDPPTransport(
            device: Device.unitTestDevice(),
            io: io,
            ioQueue: DispatchQueue(label: "com.nuebling.mac-mouse-fix.tests.m720-ble-io.invalidation")
        )
        let firstCompletion = expectation(description: "in-flight completion")
        let queuedCompletion = expectation(description: "queued completion")
        let resultLock = NSLock()
        var firstResults: [IOReturn] = []
        var queuedResults: [IOReturn] = []

        transport.send(Data(makeLongReport(featureIndex: 0x04))) { result in
            XCTAssertTrue(Thread.isMainThread)
            resultLock.lock()
            firstResults.append(result)
            resultLock.unlock()
            firstCompletion.fulfill()
        }
        XCTAssertEqual(firstSetReportEntered.wait(timeout: .now() + 1), .success)

        transport.send(Data(makeLongReport(featureIndex: 0x05))) { result in
            XCTAssertTrue(Thread.isMainThread)
            resultLock.lock()
            queuedResults.append(result)
            resultLock.unlock()
            queuedCompletion.fulfill()
        }
        transport.invalidate()
        allowFirstSetReportToReturn.signal()

        wait(for: [firstCompletion, queuedCompletion], timeout: 2)
        XCTAssertEqual(firstResults, [kIOReturnSuccess])
        XCTAssertEqual(queuedResults, [kIOReturnAborted])
        XCTAssertEqual(io.outputCalls.count, 1)
    }

    func testSendAfterInvalidationCompletesAbortedAsynchronouslyOnMainWithoutIO() {
        let io = FakeHIDPPDeviceIO(maximumInputReportSize: 20)
        let transport = BLEHIDPPTransport(
            device: Device.unitTestDevice(),
            io: io,
            ioQueue: DispatchQueue(label: "com.nuebling.mac-mouse-fix.tests.m720-ble-io.after-invalidation")
        )
        let completion = expectation(description: "send after invalidation completes")
        var didComplete = false
        transport.invalidate()

        transport.send(Data(makeLongReport())) { result in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(result, kIOReturnAborted)
            didComplete = true
            completion.fulfill()
        }

        XCTAssertFalse(didComplete, "Completion must never reenter the caller synchronously")
        wait(for: [completion], timeout: 1)
        XCTAssertTrue(io.outputCalls.isEmpty)
    }

    func testTransportRetainsDeviceUntilTransportDeinitializes() {
        let io = FakeHIDPPDeviceIO(maximumInputReportSize: 20)
        var device: Device? = Device.unitTestDevice()
        weak var weakDevice: Device?
        weakDevice = device
        var transport: BLEHIDPPTransport? = BLEHIDPPTransport(
            device: device!,
            io: io,
            ioQueue: DispatchQueue(label: "com.nuebling.mac-mouse-fix.tests.m720-ble-io.device-lifetime")
        )

        device = nil
        XCTAssertTrue(weakDevice != nil)

        transport?.invalidate()
        transport = nil
        XCTAssertTrue(weakDevice == nil)
    }

    func testProductionInitializerRejectsDeviceWithoutIOHIDHandle() {
        XCTAssertNil(BLEHIDPPTransport(device: Device.unitTestDevice()))
    }

    private func drainMainQueue(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }
}

private final class BLETransportHarness {
    let events: ThreadSafeEventRecorder
    let io: FakeHIDPPDeviceIO
    private(set) var transport: BLEHIDPPTransport!
    private let deliveryLock = NSLock()
    private var _deliveredReports: [Data] = []
    private var _deliveryWasOnMain: [Bool] = []
    private var _copyCount = 0

    var deliveredReports: [Data] {
        deliveryLock.withLock { _deliveredReports }
    }

    var deliveryWasOnMain: [Bool] {
        deliveryLock.withLock { _deliveryWasOnMain }
    }

    var copyCount: Int {
        deliveryLock.withLock { _copyCount }
    }

    init(maximumInputReportSize: Int) {
        events = ThreadSafeEventRecorder()
        let eventRecorder = events
        io = FakeHIDPPDeviceIO(
            maximumInputReportSize: maximumInputReportSize,
            events: eventRecorder
        )
        transport = BLEHIDPPTransport(
            device: Device.unitTestDevice(),
            io: io,
            ioQueue: DispatchQueue(label: "com.nuebling.mac-mouse-fix.tests.m720-ble-io.harness"),
            testHooks: BLEHIDPPTransportTestHooks(
                didCopyInputReport: { [weak self] in
                    guard let self else { return }
                    self.events.append("report copy")
                    self.deliveryLock.withLock { self._copyCount += 1 }
                },
                didReleaseCallbackContext: { eventRecorder.append("context release") },
                didReleaseInputBuffer: { eventRecorder.append("buffer release") }
            )
        )
        transport.onReport = { [weak self] data in
            guard let self else { return }
            self.events.append("main delivery")
            self.deliveryLock.withLock {
                self._deliveredReports.append(data)
                self._deliveryWasOnMain.append(Thread.isMainThread)
            }
        }
    }

    func invokeCallback(
        bytes: [UInt8],
        result: IOReturn = kIOReturnSuccess,
        reportedLength: Int? = nil,
        reportID: UInt32 = 0x11
    ) {
        events.append("callback entry")
        io.invokeCallback(
            bytes: bytes,
            result: result,
            reportedLength: reportedLength ?? bytes.count,
            reportID: reportID
        )
        events.append("callback return")
    }

    func overwriteReusableBuffer(with byte: UInt8) {
        io.overwriteRegisteredBuffer(with: byte)
    }
}

private final class FakeHIDPPDeviceIO: HIDPPDeviceIO {
    struct OutputCall {
        let reportID: CFIndex
        let data: Data
        let wasOnMain: Bool
    }

    let maximumInputReportSize: Int
    let events: ThreadSafeEventRecorder
    var outputHandler: ((Int, CFIndex, Data) -> IOReturn)?

    private let lock = NSLock()
    private var registeredBuffer: UnsafeMutablePointer<UInt8>?
    private var registeredCallback: IOHIDReportCallback?
    private var registeredContext: UnsafeMutableRawPointer?
    private var _registeredLength: Int?
    private var _registeredOnMain = false
    private var _registeredBufferAddress: UInt?
    private var _unregisterCallCount = 0
    private var _unregisteredBufferAddress: UInt?
    private var _unregisteredLength: Int?
    private var _callbackStateWasAliveDuringUnregister = false
    private var _outputCalls: [OutputCall] = []
    private var currentOutputCalls = 0
    private var _maximumConcurrentOutputCalls = 0

    var registeredLength: Int? { lock.withLock { _registeredLength } }
    var registeredOnMain: Bool { lock.withLock { _registeredOnMain } }
    var registeredBufferAddress: UInt? { lock.withLock { _registeredBufferAddress } }
    var unregisterCallCount: Int { lock.withLock { _unregisterCallCount } }
    var unregisteredBufferAddress: UInt? { lock.withLock { _unregisteredBufferAddress } }
    var unregisteredLength: Int? { lock.withLock { _unregisteredLength } }
    var callbackStateWasAliveDuringUnregister: Bool {
        lock.withLock { _callbackStateWasAliveDuringUnregister }
    }
    var outputCalls: [OutputCall] { lock.withLock { _outputCalls } }
    var maximumConcurrentOutputCalls: Int {
        lock.withLock { _maximumConcurrentOutputCalls }
    }

    init(
        maximumInputReportSize: Int,
        events: ThreadSafeEventRecorder = ThreadSafeEventRecorder()
    ) {
        self.maximumInputReportSize = maximumInputReportSize
        self.events = events
    }

    func registerInputReport(
        buffer: UnsafeMutablePointer<UInt8>,
        length: Int,
        callback: @escaping IOHIDReportCallback,
        context: UnsafeMutableRawPointer
    ) {
        lock.withLock {
            registeredBuffer = buffer
            registeredCallback = callback
            registeredContext = context
            _registeredLength = length
            _registeredOnMain = Thread.isMainThread
            _registeredBufferAddress = UInt(bitPattern: buffer)
        }
        events.append("register")
    }

    func unregisterInputReport(
        buffer: UnsafeMutablePointer<UInt8>,
        length: Int
    ) {
        lock.withLock {
            _unregisterCallCount += 1
            _unregisteredBufferAddress = UInt(bitPattern: buffer)
            _unregisteredLength = length
            _callbackStateWasAliveDuringUnregister = registeredCallback != nil && registeredContext != nil
            registeredCallback = nil
            registeredContext = nil
        }
        events.append("unregister")
    }

    func setOutputReport(reportID: CFIndex, data: Data) -> IOReturn {
        let callIndex: Int = lock.withLock {
            let index = _outputCalls.count
            _outputCalls.append(OutputCall(
                reportID: reportID,
                data: data,
                wasOnMain: Thread.isMainThread
            ))
            currentOutputCalls += 1
            _maximumConcurrentOutputCalls = max(_maximumConcurrentOutputCalls, currentOutputCalls)
            return index
        }
        let result = outputHandler?(callIndex, reportID, data) ?? kIOReturnSuccess
        lock.withLock { currentOutputCalls -= 1 }
        return result
    }

    func invokeCallback(
        bytes: [UInt8],
        result: IOReturn,
        reportedLength: Int,
        reportID: UInt32
    ) {
        let state: (
            UnsafeMutablePointer<UInt8>,
            IOHIDReportCallback,
            UnsafeMutableRawPointer,
            Int
        ) = lock.withLock {
            (
                registeredBuffer!,
                registeredCallback!,
                registeredContext!,
                _registeredLength!
            )
        }
        for index in 0..<min(bytes.count, state.3) {
            state.0[index] = bytes[index]
        }
        state.1(
            state.2,
            result,
            nil,
            kIOHIDReportTypeInput,
            reportID,
            state.0,
            CFIndex(reportedLength)
        )
    }

    func overwriteRegisteredBuffer(with byte: UInt8) {
        let state: (UnsafeMutablePointer<UInt8>, Int) = lock.withLock {
            (registeredBuffer!, _registeredLength!)
        }
        for index in 0..<state.1 {
            state.0[index] = byte
        }
    }
}

private final class ThreadSafeEventRecorder {
    private let lock = NSLock()
    private var events: [String] = []

    func append(_ event: String) {
        lock.withLock { events.append(event) }
    }

    func snapshot() -> [String] {
        lock.withLock { events }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

private func makeLongReport(
    featureIndex: UInt8 = 0x00,
    functionAndSoftwareID: UInt8 = 0x18
) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: 20)
    bytes[0] = 0x11
    bytes[1] = 0xFF
    bytes[2] = featureIndex
    bytes[3] = functionAndSoftwareID
    return bytes
}
