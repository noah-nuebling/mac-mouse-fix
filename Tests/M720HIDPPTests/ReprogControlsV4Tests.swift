import Foundation
import XCTest
@testable import Mac_Mouse_Fix_Helper

final class ReprogControlsV4Tests: XCTestCase {
    func testFunctionIDsMatchProtocol() {
        XCTAssertEqual(ReprogControlsV4.Function.getCount.rawValue, 0)
        XCTAssertEqual(ReprogControlsV4.Function.getCidInfo.rawValue, 1)
        XCTAssertEqual(ReprogControlsV4.Function.getCidReporting.rawValue, 2)
        XCTAssertEqual(ReprogControlsV4.Function.setCidReporting.rawValue, 3)
    }

    func testEncodesRootGetFeatureRequest() {
        let report = ReprogControlsV4.rootGetFeatureRequest(
            deviceIndex: 0xFF,
            softwareID: 0x8
        )

        XCTAssertEqual(Array(report.data), expectedRequest(
            deviceIndex: 0xFF,
            featureIndex: 0x00,
            function: 0,
            softwareID: 0x8,
            parameters: [0x1B, 0x04]
        ))
    }

    func testEncodesGetCountRequest() {
        let report = ReprogControlsV4.getCountRequest(
            deviceIndex: 0xFF,
            featureIndex: 0x2A,
            softwareID: 0x8
        )

        XCTAssertEqual(Array(report.data), expectedRequest(
            deviceIndex: 0xFF,
            featureIndex: 0x2A,
            function: 0,
            softwareID: 0x8,
            parameters: []
        ))
    }

    func testEncodesGetCidInfoRequest() {
        let report = ReprogControlsV4.getCidInfoRequest(
            deviceIndex: 0xFF,
            featureIndex: 0x2A,
            softwareID: 0x8,
            index: 0x07
        )

        XCTAssertEqual(Array(report.data), expectedRequest(
            deviceIndex: 0xFF,
            featureIndex: 0x2A,
            function: 1,
            softwareID: 0x8,
            parameters: [0x07]
        ))
    }

    func testEncodesGetCidReportingRequestBigEndian() {
        let report = ReprogControlsV4.getCidReportingRequest(
            deviceIndex: 0xFF,
            featureIndex: 0x2A,
            softwareID: 0x8,
            cid: 0x1234
        )

        XCTAssertEqual(Array(report.data), expectedRequest(
            deviceIndex: 0xFF,
            featureIndex: 0x2A,
            function: 2,
            softwareID: 0x8,
            parameters: [0x12, 0x34]
        ))
    }

    func testEncodesTakeoverSetCidReportingRequest() {
        let report = ReprogControlsV4.setCidReportingRequest(
            deviceIndex: 0xFF,
            featureIndex: 0x2A,
            softwareID: 0x8,
            cid: 0x005B,
            diverted: true
        )

        XCTAssertEqual(Array(report.data), expectedRequest(
            deviceIndex: 0xFF,
            featureIndex: 0x2A,
            function: 3,
            softwareID: 0x8,
            parameters: [0x00, 0x5B, 0x03, 0x00, 0x00]
        ))
    }

    func testRestoreRequestUsesSnapshotDivertBit() {
        let notDiverted = HIDPPReportingState(cid: 0x00D0, flags: 0x14, remappedCID: 0x4321)
        let diverted = HIDPPReportingState(cid: 0x00D0, flags: 0x15, remappedCID: 0x4321)

        let notDivertedReport = ReprogControlsV4.setCidReportingRequest(
            deviceIndex: 0xFF,
            featureIndex: 0x2A,
            softwareID: 0x8,
            cid: notDiverted.cid,
            diverted: notDiverted.isDiverted
        )
        let divertedReport = ReprogControlsV4.setCidReportingRequest(
            deviceIndex: 0xFF,
            featureIndex: 0x2A,
            softwareID: 0x8,
            cid: diverted.cid,
            diverted: diverted.isDiverted
        )

        XCTAssertEqual(Array(notDivertedReport.data), expectedRequest(
            deviceIndex: 0xFF,
            featureIndex: 0x2A,
            function: 3,
            softwareID: 0x8,
            parameters: [0x00, 0xD0, 0x02, 0x00, 0x00]
        ))
        XCTAssertEqual(Array(divertedReport.data), expectedRequest(
            deviceIndex: 0xFF,
            featureIndex: 0x2A,
            function: 3,
            softwareID: 0x8,
            parameters: [0x00, 0xD0, 0x03, 0x00, 0x00]
        ))
    }

    func testTakeoverChangesOnlyTemporaryDivert() {
        let diverted = ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: true)
        let notDiverted = ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: false)

        XCTAssertEqual(diverted, [0x00, 0x5B, 0x03, 0x00, 0x00])
        XCTAssertEqual(notDiverted, [0x00, 0x5B, 0x02, 0x00, 0x00])
        XCTAssertEqual(diverted[2] & 0x3C, 0)
        XCTAssertEqual(notDiverted[2] & 0x3C, 0)
        XCTAssertEqual(Array(diverted[3...4]), [0x00, 0x00])
        XCTAssertEqual(Array(notDiverted[3...4]), [0x00, 0x00])
    }

    func testDecodesFeatureLookupPrefixAndIgnoresPadding() throws {
        let lookup = try ReprogControlsV4.decodeFeatureLookup(Data([
            0x2A, 0x03, 0x07, 0xDE, 0xAD,
        ]))

        XCTAssertEqual(lookup, HIDPPFeatureLookup(
            featureIndex: 0x2A,
            featureType: 0x03,
            featureVersion: 0x07
        ))
    }

    func testRejectsZeroFeatureIndexWithoutReturningPartialLookup() {
        var lookup: HIDPPFeatureLookup?

        XCTAssertThrowsError(
            lookup = try ReprogControlsV4.decodeFeatureLookup(Data([0x00, 0x03, 0x07]))
        ) { error in
            XCTAssertEqual(error as? ReprogControlsError, .unsupportedFeature)
        }
        XCTAssertNil(lookup)
    }

    func testAcceptsMaximumControlCountAndRejectsNextValue() throws {
        XCTAssertEqual(try ReprogControlsV4.decodeControlCount(Data([32, 0xFF])), 32)

        var count: UInt8?
        XCTAssertThrowsError(
            count = try ReprogControlsV4.decodeControlCount(Data([33]))
        ) { error in
            XCTAssertEqual(error as? ReprogControlsError, .controlCountExceedsMaximum(33))
        }
        XCTAssertNil(count)
    }

    func testDecodesControlInfoBigEndianAndDocumentedFlags() throws {
        let info = try ReprogControlsV4.decodeControlInfo(Data([
            0x12, 0x34,
            0xAB, 0xCD,
            0x21,
            0x06,
            0x07,
            0x80,
            0x55,
            0xEE,
        ]))

        XCTAssertEqual(info, HIDPPControlInfo(
            cid: 0x1234,
            taskID: 0xABCD,
            flags: 0x21,
            position: 0x06,
            group: 0x07,
            groupMask: 0x80,
            rawXYFlags: 0x55
        ))
        XCTAssertTrue(info.isMouseControl)
        XCTAssertFalse(info.isReprogrammable)
        XCTAssertTrue(info.isDivertable)
    }

    func testBitFiveNotBitFourControlsDivertCapability() throws {
        let bitFour = try ReprogControlsV4.decodeControlInfo(Data([
            0, 1, 0, 2, 0x10, 0, 0, 0, 0,
        ]))
        let bitFive = try ReprogControlsV4.decodeControlInfo(Data([
            0, 1, 0, 2, 0x20, 0, 0, 0, 0,
        ]))

        XCTAssertTrue(bitFour.isReprogrammable)
        XCTAssertFalse(bitFour.isDivertable)
        XCTAssertFalse(bitFive.isReprogrammable)
        XCTAssertTrue(bitFive.isDivertable)
    }

    func testDecodesReportingStateBigEndianAndDocumentedFlags() throws {
        let state = try ReprogControlsV4.decodeReportingState(Data([
            0x12, 0x34,
            0x15,
            0xAB, 0xCD,
            0xEE,
        ]))

        XCTAssertEqual(state, HIDPPReportingState(
            cid: 0x1234,
            flags: 0x15,
            remappedCID: 0xABCD
        ))
        XCTAssertTrue(state.isDiverted)
        XCTAssertTrue(state.isPersistent)
        XCTAssertTrue(state.hasRawXY)
    }

    func testChangingDivertChangesOnlyBitZero() {
        let notDiverted = HIDPPReportingState(cid: 0x005B, flags: 0xB4, remappedCID: 0x4321)
        let diverted = HIDPPReportingState(cid: 0x005B, flags: 0xB5, remappedCID: 0x4321)

        XCTAssertEqual(notDiverted.changingDivert(to: true), diverted)
        XCTAssertEqual(diverted.changingDivert(to: false), notDiverted)
        XCTAssertEqual(diverted.changingDivert(to: true), diverted)
        XCTAssertEqual(notDiverted.changingDivert(to: false), notDiverted)
    }

    func testReportingStateIsCodable() throws {
        let state = HIDPPReportingState(cid: 0x005B, flags: 0x15, remappedCID: 0x1234)

        let encoded = try JSONEncoder().encode(state)

        XCTAssertEqual(try JSONDecoder().decode(HIDPPReportingState.self, from: encoded), state)
    }

    func testValidatesMappedMouseDivertableTarget() {
        XCTAssertNoThrow(try validateTarget(
            cid: 0x005B,
            flags: 0x21
        ))
    }

    func testRejectsMappedTargetWithBitFourButNotBitFive() {
        XCTAssertThrowsError(try validateTarget(
            cid: 0x005B,
            flags: 0x11
        )) { error in
            XCTAssertEqual(error as? ReprogControlsError, .unsupportedTarget(0x005B))
        }
    }

    func testRejectsMappedDivertableTargetThatIsNotMouseControl() {
        XCTAssertThrowsError(try validateTarget(
            cid: 0x005D,
            flags: 0x20
        )) { error in
            XCTAssertEqual(error as? ReprogControlsError, .unsupportedTarget(0x005D))
        }
    }

    func testIgnoresUnsupportedCapabilitiesForUnmappedControl() {
        XCTAssertNoThrow(try validateTarget(
            cid: 0x1234,
            flags: 0x00
        ))
    }

    func testSetEchoValidatorIgnoresUndefinedPadding() {
        let expected = ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: true)
        let response = Data(expected + [UInt8](repeating: 0xA5, count: 11))

        XCTAssertNoThrow(try ReprogControlsV4.validateSetCidReportingEcho(
            response,
            matches: expected
        ))
    }

    func testSetEchoValidatorRejectsMismatchInEveryDocumentedByte() {
        let expected = ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: true)

        for index in expected.indices {
            var response = expected
            response[index] ^= 0x01

            XCTAssertThrowsError(try ReprogControlsV4.validateSetCidReportingEcho(
                Data(response),
                matches: expected
            ), "byte \(index)") { error in
                XCTAssertEqual(
                    error as? ReprogControlsError,
                    .setCidReportingEchoMismatch,
                    "byte \(index)"
                )
            }
        }
    }

    func testFeatureLookupRejectsEveryShortPayloadWithoutPartialResult() {
        for length in 0..<3 {
            var lookup: HIDPPFeatureLookup?

            XCTAssertThrowsError(
                lookup = try ReprogControlsV4.decodeFeatureLookup(payload(length: length))
            ) { error in
                XCTAssertEqual(
                    error as? ReprogControlsError,
                    .shortPayload(expected: 3, actual: length)
                )
            }
            XCTAssertNil(lookup)
        }
    }

    func testControlCountRejectsEmptyPayloadWithoutPartialResult() {
        var count: UInt8?

        XCTAssertThrowsError(
            count = try ReprogControlsV4.decodeControlCount(Data())
        ) { error in
            XCTAssertEqual(error as? ReprogControlsError, .shortPayload(expected: 1, actual: 0))
        }
        XCTAssertNil(count)
    }

    func testControlInfoRejectsEveryShortPayloadWithoutPartialResult() {
        for length in 0..<9 {
            var info: HIDPPControlInfo?

            XCTAssertThrowsError(
                info = try ReprogControlsV4.decodeControlInfo(payload(length: length))
            ) { error in
                XCTAssertEqual(
                    error as? ReprogControlsError,
                    .shortPayload(expected: 9, actual: length)
                )
            }
            XCTAssertNil(info)
        }
    }

    func testReportingStateRejectsEveryShortPayloadWithoutPartialResult() {
        for length in 0..<5 {
            var state: HIDPPReportingState?

            XCTAssertThrowsError(
                state = try ReprogControlsV4.decodeReportingState(payload(length: length))
            ) { error in
                XCTAssertEqual(
                    error as? ReprogControlsError,
                    .shortPayload(expected: 5, actual: length)
                )
            }
            XCTAssertNil(state)
        }
    }

    func testSetEchoValidatorRejectsEveryShortPayload() {
        let expected = ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: true)

        for length in 0..<5 {
            XCTAssertThrowsError(try ReprogControlsV4.validateSetCidReportingEcho(
                payload(length: length),
                matches: expected
            )) { error in
                XCTAssertEqual(
                    error as? ReprogControlsError,
                    .shortPayload(expected: 5, actual: length)
                )
            }
        }
    }

    private func expectedRequest(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        function: UInt8,
        softwareID: UInt8,
        parameters: [UInt8]
    ) -> [UInt8] {
        [0x11, deviceIndex, featureIndex, (function << 4) | softwareID] +
            parameters +
            [UInt8](repeating: 0, count: 16 - parameters.count)
    }

    private func validateTarget(cid: UInt16, flags: UInt8) throws {
        try ReprogControlsV4.validateTarget(HIDPPControlInfo(
            cid: cid,
            taskID: 0,
            flags: flags,
            position: 0,
            group: 0,
            groupMask: 0,
            rawXYFlags: 0
        ))
    }

    private func payload(length: Int) -> Data {
        Data([UInt8](repeating: 0xA5, count: length))
    }
}
