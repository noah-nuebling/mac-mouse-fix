import Foundation
import IOKit.hid
import XCTest
@testable import Mac_Mouse_Fix_Helper

final class UnifyingReceiverChannelTests: XCTestCase {
    func testSlotTransportUsesExactReceiverSlotAsRequestAndResponseIndex() throws {
        let harness = ReceiverChannelHarness()
        let slot = try XCTUnwrap(harness.channel.makeSlotTransport(slot: 3))

        XCTAssertEqual(slot.deviceIndex, 3)
        XCTAssertEqual(slot.acceptedResponseDeviceIndices, [3])
        XCTAssertNil(harness.channel.makeSlotTransport(slot: 0))
        XCTAssertNil(harness.channel.makeSlotTransport(slot: 7))
        XCTAssertNil(harness.channel.makeSlotTransport(slot: 3), "one route may own a slot")

        slot.invalidate()
        harness.channel.invalidate()
    }

    func testRoutesReceiverSlotAndLinkReportsWithoutCrossDelivery() throws {
        let harness = ReceiverChannelHarness()
        let slot1 = try XCTUnwrap(harness.channel.makeSlotTransport(slot: 1))
        let slot2 = try XCTUnwrap(harness.channel.makeSlotTransport(slot: 2))
        var receiverReports: [Data] = []
        var slot1Reports: [Data] = []
        var slot2Reports: [Data] = []
        var linkEvents: [UnifyingReceiverLinkEvent] = []
        harness.channel.onReceiverReport = { receiverReports.append($0) }
        harness.channel.onLinkEvent = { linkEvents.append($0) }
        slot1.onReport = { slot1Reports.append($0) }
        slot2.onReport = { slot2Reports.append($0) }

        let receiver = makeReceiverPairingResponse(slot: 1)
        let first = makeSlotLongReport(slot: 1, featureIndex: 0x04)
        let second = makeSlotLongReport(slot: 2, featureIndex: 0x05)
        let online: [UInt8] = [0x10, 0x01, 0x41, 0x04, 0x20, 0x5E, 0x40]
        harness.io.invokeCallback(bytes: receiver, reportID: 0x11)
        harness.io.invokeCallback(bytes: first, reportID: 0x11)
        harness.io.invokeCallback(bytes: second, reportID: 0x11)
        harness.io.invokeCallback(bytes: online, reportID: 0x10)
        drainMainQueue()

        XCTAssertEqual(receiverReports, [Data(receiver)])
        XCTAssertEqual(slot1Reports, [Data(first)])
        XCTAssertEqual(slot2Reports, [Data(second)])
        XCTAssertEqual(linkEvents, [
            .linkChanged(slot: 1, wirelessProductID: 0x405E, online: true),
        ])

        slot1.invalidate()
        slot2.invalidate()
        harness.channel.invalidate()
    }

    func testCallbackCopiesBeforeReturnAndIgnoresMalformedOrMismatchedReports() throws {
        let harness = ReceiverChannelHarness()
        let slot = try XCTUnwrap(harness.channel.makeSlotTransport(slot: 1))
        let expected = makeSlotLongReport(slot: 1, featureIndex: 0x04)
        var delivered: [Data] = []
        slot.onReport = { delivered.append($0) }

        harness.io.invokeCallback(bytes: expected, reportID: 0x11)
        harness.io.overwriteRegisteredBuffer(with: 0xA5)
        harness.io.invokeCallback(
            bytes: expected,
            reportedLength: 33,
            reportID: 0x11
        )
        harness.io.invokeCallback(bytes: expected, reportID: 0x10)
        harness.io.invokeCallback(
            bytes: Array(expected.dropLast()),
            reportID: 0x11
        )
        drainMainQueue()

        XCTAssertEqual(delivered, [Data(expected)])
        XCTAssertEqual(harness.copyCount, 3, "only in-bounds callbacks copy before format filtering")

        slot.invalidate()
        harness.channel.invalidate()
    }

    func testReceiverAndSlotWritesShareSerialIOAndUseTheirWireReportIDs() throws {
        let harness = ReceiverChannelHarness()
        let slot1 = try XCTUnwrap(harness.channel.makeSlotTransport(slot: 1))
        let slot2 = try XCTUnwrap(harness.channel.makeSlotTransport(slot: 2))
        let receiver = try UnifyingReceiverProtocol.pairingInformationRequest(slot: 1)
        let first = Data(makeSlotLongReport(slot: 1, featureIndex: 0x04))
        let second = Data(makeSlotLongReport(slot: 2, featureIndex: 0x05))
        let completions = expectation(description: "all writes complete")
        completions.expectedFulfillmentCount = 3

        harness.channel.sendReceiver(receiver) { result in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(result, kIOReturnSuccess)
            completions.fulfill()
        }
        slot1.send(first) { result in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(result, kIOReturnSuccess)
            completions.fulfill()
        }
        slot2.send(second) { result in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(result, kIOReturnSuccess)
            completions.fulfill()
        }

        wait(for: [completions], timeout: 2)
        XCTAssertEqual(harness.io.outputCalls.map(\.reportID), [0x10, 0x11, 0x11])
        XCTAssertEqual(harness.io.outputCalls.map(\.data), [receiver, first, second])
        XCTAssertEqual(harness.io.maximumConcurrentOutputCalls, 1)
        XCTAssertEqual(harness.io.outputCalls.map(\.wasOnMain), [false, false, false])

        slot1.invalidate()
        slot2.invalidate()
        harness.channel.invalidate()
    }

    func testSlotInvalidationAbortsQueuedSlotWriteButKeepsReceiverChannelAlive() throws {
        let harness = ReceiverChannelHarness()
        let slot = try XCTUnwrap(harness.channel.makeSlotTransport(slot: 1))
        let firstWriteEntered = DispatchSemaphore(value: 0)
        let allowFirstWrite = DispatchSemaphore(value: 0)
        harness.io.outputHandler = { index, _, _ in
            if index == 0 {
                firstWriteEntered.signal()
                _ = allowFirstWrite.wait(timeout: .now() + 2)
            }
            return kIOReturnSuccess
        }
        let firstCompletion = expectation(description: "accepted write completes")
        let queuedCompletion = expectation(description: "queued write aborts")
        let invalidated = expectation(description: "slot drain completes")

        slot.send(Data(makeSlotLongReport(slot: 1, featureIndex: 0x04))) { result in
            XCTAssertEqual(result, kIOReturnSuccess)
            firstCompletion.fulfill()
        }
        XCTAssertEqual(firstWriteEntered.wait(timeout: .now() + 1), .success)
        slot.send(Data(makeSlotLongReport(slot: 1, featureIndex: 0x05))) { result in
            XCTAssertEqual(result, kIOReturnAborted)
            queuedCompletion.fulfill()
        }
        slot.invalidate { invalidated.fulfill() }
        allowFirstWrite.signal()

        wait(for: [firstCompletion, queuedCompletion, invalidated], timeout: 2)
        XCTAssertEqual(harness.io.outputCalls.count, 1)

        let receiverCompletion = expectation(description: "receiver still writes")
        harness.channel.sendReceiver(
            UnifyingReceiverProtocol.notificationFlagsReadRequest()
        ) { result in
            XCTAssertEqual(result, kIOReturnSuccess)
            receiverCompletion.fulfill()
        }
        wait(for: [receiverCompletion], timeout: 1)
        XCTAssertEqual(harness.io.outputCalls.count, 2)
        harness.channel.invalidate()
    }

    func testChannelInvalidationDrainsWritesThenUnregistersOnce() throws {
        let events = ReceiverChannelEventRecorder()
        let io = FakeReceiverChannelIO(maximumInputReportSize: 32, events: events)
        let channel = UnifyingReceiverChannel(
            io: io,
            ioQueue: DispatchQueue(label: "com.nuebling.mac-mouse-fix.tests.m720-unifying.drain"),
            testHooks: UnifyingReceiverChannelTestHooks(
                didCopyInputReport: {},
                didReleaseCallbackContext: { events.append("context release") },
                didReleaseInputBuffer: { events.append("buffer release") }
            )
        )
        let slot = try XCTUnwrap(channel.makeSlotTransport(slot: 1))
        let writeEntered = DispatchSemaphore(value: 0)
        let allowWrite = DispatchSemaphore(value: 0)
        io.outputHandler = { _, _, _ in
            events.append("set entered")
            writeEntered.signal()
            _ = allowWrite.wait(timeout: .now() + 2)
            events.append("set return")
            return kIOReturnSuccess
        }
        let writeCompletion = expectation(description: "write completes")
        let drains = expectation(description: "coalesced drains")
        drains.expectedFulfillmentCount = 2
        slot.send(Data(makeSlotLongReport(slot: 1))) { _ in
            events.append("send")
            writeCompletion.fulfill()
        }
        XCTAssertEqual(writeEntered.wait(timeout: .now() + 1), .success)

        channel.invalidate {
            events.append("drain 1")
            drains.fulfill()
        }
        channel.invalidate {
            events.append("drain 2")
            drains.fulfill()
        }
        XCTAssertEqual(io.unregisterCallCount, 0)
        allowWrite.signal()

        wait(for: [writeCompletion, drains], timeout: 2)
        XCTAssertEqual(io.unregisterCallCount, 1)
        XCTAssertEqual(events.snapshot(), [
            "register", "set entered", "set return", "send", "unregister",
            "context release", "buffer release", "drain 1", "drain 2",
        ])
    }

    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }
}

private final class ReceiverChannelHarness {
    let io: FakeReceiverChannelIO
    let channel: UnifyingReceiverChannel
    private let copyCounter: ReceiverCopyCounter

    var copyCount: Int { copyCounter.value }

    init() {
        io = FakeReceiverChannelIO(maximumInputReportSize: 32)
        let copyCounter = ReceiverCopyCounter()
        self.copyCounter = copyCounter
        channel = UnifyingReceiverChannel(
            io: io,
            ioQueue: DispatchQueue(label: "com.nuebling.mac-mouse-fix.tests.m720-unifying.channel"),
            testHooks: UnifyingReceiverChannelTestHooks(
                didCopyInputReport: { copyCounter.increment() }
            )
        )
    }
}

private final class ReceiverCopyCounter {
    private let lock = NSLock()
    private var count = 0

    var value: Int { lock.withReceiverLock { count } }

    func increment() {
        lock.withReceiverLock { count += 1 }
    }
}

private final class FakeReceiverChannelIO: HIDPPDeviceIO {
    struct OutputCall {
        let reportID: CFIndex
        let data: Data
        let wasOnMain: Bool
    }

    let maximumInputReportSize: Int
    let events: ReceiverChannelEventRecorder
    var outputHandler: ((Int, CFIndex, Data) -> IOReturn)?

    private let lock = NSLock()
    private var registeredBuffer: UnsafeMutablePointer<UInt8>?
    private var registeredCallback: IOHIDReportCallback?
    private var registeredContext: UnsafeMutableRawPointer?
    private var registeredLength = 0
    private var _unregisterCallCount = 0
    private var _outputCalls: [OutputCall] = []
    private var activeOutputCalls = 0
    private var _maximumConcurrentOutputCalls = 0

    var unregisterCallCount: Int { lock.withReceiverLock { _unregisterCallCount } }
    var outputCalls: [OutputCall] { lock.withReceiverLock { _outputCalls } }
    var maximumConcurrentOutputCalls: Int {
        lock.withReceiverLock { _maximumConcurrentOutputCalls }
    }

    init(
        maximumInputReportSize: Int,
        events: ReceiverChannelEventRecorder = ReceiverChannelEventRecorder()
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
        lock.withReceiverLock {
            registeredBuffer = buffer
            registeredLength = length
            registeredCallback = callback
            registeredContext = context
        }
        events.append("register")
    }

    func unregisterInputReport(
        buffer _: UnsafeMutablePointer<UInt8>,
        length _: Int
    ) {
        lock.withReceiverLock {
            _unregisterCallCount += 1
            registeredCallback = nil
            registeredContext = nil
        }
        events.append("unregister")
    }

    func setOutputReport(reportID: CFIndex, data: Data) -> IOReturn {
        let index = lock.withReceiverLock {
            let index = _outputCalls.count
            _outputCalls.append(OutputCall(
                reportID: reportID,
                data: data,
                wasOnMain: Thread.isMainThread
            ))
            activeOutputCalls += 1
            _maximumConcurrentOutputCalls = max(_maximumConcurrentOutputCalls, activeOutputCalls)
            return index
        }
        let result = outputHandler?(index, reportID, data) ?? kIOReturnSuccess
        lock.withReceiverLock { activeOutputCalls -= 1 }
        return result
    }

    func invokeCallback(
        bytes: [UInt8],
        result: IOReturn = kIOReturnSuccess,
        reportedLength: Int? = nil,
        reportID: UInt32
    ) {
        let state = lock.withReceiverLock {
            (
                registeredBuffer!,
                registeredCallback!,
                registeredContext!,
                registeredLength
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
            CFIndex(reportedLength ?? bytes.count)
        )
    }

    func overwriteRegisteredBuffer(with value: UInt8) {
        let state = lock.withReceiverLock { (registeredBuffer!, registeredLength) }
        for index in 0..<state.1 {
            state.0[index] = value
        }
    }
}

private final class ReceiverChannelEventRecorder {
    private let lock = NSLock()
    private var events: [String] = []

    func append(_ event: String) {
        lock.withReceiverLock { events.append(event) }
    }

    func snapshot() -> [String] {
        lock.withReceiverLock { events }
    }
}

private extension NSLock {
    func withReceiverLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}

private func makeReceiverPairingResponse(slot: UInt8) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: 20)
    bytes[0] = 0x11
    bytes[1] = 0xFF
    bytes[2] = 0x83
    bytes[3] = 0xB5
    bytes[4] = 0x1F + slot
    bytes[7] = 0x40
    bytes[8] = 0x5E
    return bytes
}

private func makeSlotLongReport(
    slot: UInt8,
    featureIndex: UInt8 = 0,
    functionAndSoftwareID: UInt8 = 0x18
) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: 20)
    bytes[0] = 0x11
    bytes[1] = slot
    bytes[2] = featureIndex
    bytes[3] = functionAndSoftwareID
    return bytes
}
