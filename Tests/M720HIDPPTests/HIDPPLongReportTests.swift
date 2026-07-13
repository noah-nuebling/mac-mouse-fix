import Foundation
import IOKit
import XCTest
@testable import Mac_Mouse_Fix_Helper

final class HIDPPLongReportTests: XCTestCase {
    func testEncodesRootGetFeature() throws {
        let data = HIDPPLongReport.request(
            deviceIndex: 0xFF,
            featureIndex: 0x00,
            function: 0x0,
            softwareID: 0x8,
            parameters: [0x1B, 0x04]
        ).data

        XCTAssertEqual(Array(data), [
            0x11, 0xFF, 0x00, 0x08, 0x1B, 0x04,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        ])
    }

    func testAcceptsBothBLEReplyDeviceIndices() throws {
        for deviceIndex: UInt8 in [0x00, 0xFF] {
            let bytes = normalFrame(deviceIndex: deviceIndex)
            let inbound = try HIDPPLongReport.decode(
                Data(bytes),
                acceptedDeviceIndices: [0x00, 0xFF]
            )

            XCTAssertEqual(inbound, .response(
                identity: .init(featureIndex: 0x0B, function: 0x3, softwareID: 0x8),
                parameters: Data(bytes[4...])
            ))
        }
    }

    func testRejectsEveryOtherBLEReplyDeviceIndex() {
        for value in UInt16(UInt8.min)...UInt16(UInt8.max) {
            let deviceIndex = UInt8(value)
            guard deviceIndex != 0x00, deviceIndex != 0xFF else { continue }

            assertDecodeThrows(
                normalFrame(deviceIndex: deviceIndex),
                expected: .invalidDeviceIndex(deviceIndex)
            )
        }
    }

    func testRejectsWrongReportIDWithoutReturningPartialFrame() {
        var bytes = normalFrame()
        bytes[0] = 0x10

        assertDecodeThrows(bytes, expected: .invalidReportID(0x10))
    }

    func testRejectsNineteenByteFrameWithoutReturningPartialFrame() {
        let bytes = Array(normalFrame().dropLast())

        assertDecodeThrows(bytes, expected: .invalidLength(19))
    }

    func testRejectsTwentyOneByteFrameWithoutReturningPartialFrame() {
        let bytes = normalFrame() + [0x00]

        assertDecodeThrows(bytes, expected: .invalidLength(21))
    }

    func testDecodesExactResponseIdentityAndParameters() throws {
        let bytes: [UInt8] = [
            0x11, 0xFF, 0x42, 0xE7,
            0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
            0x10, 0x32, 0x54, 0x76, 0x98, 0xBA, 0xDC, 0xFE,
        ]

        let inbound = try HIDPPLongReport.decode(
            Data(bytes),
            acceptedDeviceIndices: [0xFF]
        )

        XCTAssertEqual(inbound, .response(
            identity: .init(featureIndex: 0x42, function: 0xE, softwareID: 0x7),
            parameters: Data(bytes[4...])
        ))
    }

    func testDecodesSoftwareIDZeroAsEvent() throws {
        let bytes: [UInt8] = [
            0x11, 0x00, 0x22, 0x40,
            0xDE, 0xAD, 0xBE, 0xEF,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        ]

        let inbound = try HIDPPLongReport.decode(
            Data(bytes),
            acceptedDeviceIndices: [0x00, 0xFF]
        )

        XCTAssertEqual(inbound, .event(
            featureIndex: 0x22,
            event: 0x4,
            parameters: Data(bytes[4...])
        ))
    }

    func testDecodesSpecialErrorLayout() throws {
        let bytes: [UInt8] = [
            0x11, 0x00, 0xFF, 0x0B, 0x38, 0x08,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        ]

        let inbound = try HIDPPLongReport.decode(
            Data(bytes),
            acceptedDeviceIndices: [0x00, 0xFF]
        )

        XCTAssertEqual(inbound, .error(.init(
            identity: .init(featureIndex: 0x0B, function: 0x3, softwareID: 0x8),
            code: 0x08
        )))
    }

    func testRejectsSpecialErrorWithZeroSoftwareIDWithoutReturningPartialFrame() {
        let bytes: [UInt8] = [
            0x11, 0x00, 0xFF, 0x0B, 0x30, 0x08,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        ]

        assertDecodeThrows(bytes, expected: .invalidSoftwareID(0x00))
    }

    private func normalFrame(deviceIndex: UInt8 = 0xFF) -> [UInt8] {
        [
            0x11, deviceIndex, 0x0B, 0x38, 0xAA, 0xBB,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        ]
    }

    private func assertDecodeThrows(
        _ bytes: [UInt8],
        expected: HIDPPFrameError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var decoded: HIDPPInbound?

        XCTAssertThrowsError(
            decoded = try HIDPPLongReport.decode(
                Data(bytes),
                acceptedDeviceIndices: [0x00, 0xFF]
            ),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(error as? HIDPPFrameError, expected, file: file, line: line)
        }
        XCTAssertNil(decoded, file: file, line: line)
    }
}

final class ManualSchedulerTests: XCTestCase {
    func testAdvancesTimeAndRunsDueBlocksByDeadlineThenInsertionOrder() {
        let scheduler = ManualScheduler()
        var events: [String] = []

        scheduler.schedule(after: 2) {
            XCTAssertEqual(scheduler.now, 2)
            events.append("second-first")
        }
        scheduler.schedule(after: 1) {
            XCTAssertEqual(scheduler.now, 1)
            events.append("first")
        }
        scheduler.schedule(after: 2) {
            XCTAssertEqual(scheduler.now, 2)
            events.append("second-second")
        }
        scheduler.schedule(after: 3) {
            events.append("not-due")
        }

        scheduler.advance(by: 2.5)

        XCTAssertEqual(events, ["first", "second-first", "second-second"])
        XCTAssertEqual(scheduler.now, 2.5)
    }

    func testCancelledBlockDoesNotRun() {
        let scheduler = ManualScheduler()
        var didRun = false
        let cancellation = scheduler.schedule(after: 1) {
            didRun = true
        }

        cancellation.cancel()
        scheduler.advance(by: 1)

        XCTAssertFalse(didRun)
        XCTAssertEqual(scheduler.now, 1)
    }
}

final class ScriptedHIDPPTransportTests: XCTestCase {
    func testSendRecordsReportAndCompletesSynchronously() {
        let transport = ScriptedHIDPPTransport()
        let report = Data([0x11, 0xFF])
        var completionResult: IOReturn?

        transport.send(report) { result in
            completionResult = result
            XCTAssertEqual(transport.sent, [report])
        }

        XCTAssertEqual(transport.deviceIndex, 0xFF)
        XCTAssertEqual(transport.acceptedResponseDeviceIndices, [0x00, 0xFF])
        XCTAssertEqual(completionResult, kIOReturnSuccess)
    }

    func testInjectDeliversExactReportUntilInvalidated() {
        let transport = ScriptedHIDPPTransport()
        var received: [Data] = []
        transport.onReport = { received.append($0) }

        transport.inject([0x11, 0x00, 0x01])
        transport.invalidate()
        transport.inject([0x11, 0xFF, 0x02])

        XCTAssertEqual(received, [Data([0x11, 0x00, 0x01])])
    }
}
