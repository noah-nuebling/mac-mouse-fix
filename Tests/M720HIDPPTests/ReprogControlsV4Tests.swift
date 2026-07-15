import Foundation
import XCTest
@testable import Mac_Mouse_Fix_Helper

final class ReprogControlsV4Tests: XCTestCase {
    func testDiagnosticSoftwareIDAllocatorNeverReusesIdentityAndFailsClosedAtSixteenthAllocation() throws {
        var allocator = M720DiagnosticSoftwareIDAllocator()
        var identities: [HIDPPRequestIdentity] = []
        var writerCallCount = 0

        func allocateBeforeWriter() throws -> HIDPPRequestIdentity {
            let identity = try allocator.allocateIdentity(
                featureIndex: 0x2A,
                function: ReprogControlsV4.Function.getCidInfo.rawValue
            )
            writerCallCount += 1
            return identity
        }

        for _ in 0..<15 {
            identities.append(try allocateBeforeWriter())
        }

        XCTAssertEqual(
            identities.map(\.softwareID),
            Array(UInt8(0x8)...UInt8(0xF)) + Array(UInt8(0x1)...UInt8(0x7))
        )
        XCTAssertEqual(Set(identities).count, 15)
        XCTAssertFalse(identities.dropFirst().contains(identities[0]))
        XCTAssertThrowsError(try allocateBeforeWriter()) { error in
            XCTAssertEqual(error as? M720DiagnosticError, .softwareIDsExhausted)
            XCTAssertEqual(
                String(describing: error),
                "exhausted unique HID++ software IDs for this feature/function"
            )
        }
        XCTAssertEqual(identities.count, 15)
        XCTAssertEqual(writerCallCount, 15)
    }

    func testDiagnosticSoftwareIDAllocatorScopesReuseByFeatureAndFunction() throws {
        var allocator = M720DiagnosticSoftwareIDAllocator()

        let count = try allocator.allocateIdentity(
            featureIndex: 0x2A,
            function: ReprogControlsV4.Function.getCount.rawValue
        )
        let info = try allocator.allocateIdentity(
            featureIndex: 0x2A,
            function: ReprogControlsV4.Function.getCidInfo.rawValue
        )
        let otherFeature = try allocator.allocateIdentity(
            featureIndex: 0x2B,
            function: ReprogControlsV4.Function.getCount.rawValue
        )

        XCTAssertEqual(count.softwareID, 0x8)
        XCTAssertEqual(info.softwareID, 0x8)
        XCTAssertEqual(otherFeature.softwareID, 0x8)
        XCTAssertNotEqual(count, info)
        XCTAssertNotEqual(count, otherFeature)
    }

    func testDiagnosticOperationsEncodeOnlyFourExactGetShapes() throws {
        let operations: [M720ReadOnlyOperation] = [
            .rootGetFeature,
            .getCount,
            .getCidInfo(index: 7),
            .getCidReporting(cid: 0x005B),
        ]

        for (offset, operation) in operations.enumerated() {
            let report = operation.request(
                deviceIndex: 0xFF,
                featureIndex: 0x2A,
                softwareID: UInt8(0x8 + offset)
            )
            XCTAssertNoThrow(try M720ReadOnlyRequestValidator.validate(
                report.data,
                reprogFeatureIndex: operation == .rootGetFeature ? nil : 0x2A
            ))
        }
    }

    func testDiagnosticSecondaryValidatorRejectsSetPersistentFeatureAndMalformedGetBeforeWrite() {
        var writes: [Data] = []
        let writer = M720ValidatedReportWriter { report in
            writes.append(report)
            return 0
        }
        let forbiddenReports: [(Data, M720DiagnosticError)] = [
            (
                ReprogControlsV4.setCidReportingRequest(
                    deviceIndex: 0xFF,
                    featureIndex: 0x2A,
                    softwareID: 0x8,
                    cid: 0x005B,
                    diverted: true
                ).data,
                .forbiddenRequest
            ),
            (
                HIDPPLongReport.request(
                    deviceIndex: 0xFF,
                    featureIndex: 0,
                    function: 0,
                    softwareID: 0x8,
                    parameters: [0x1C, 0x00]
                ).data,
                .persistentFeatureForbidden
            ),
            (
                HIDPPLongReport.request(
                    deviceIndex: 0xFF,
                    featureIndex: 0x2A,
                    function: 0,
                    softwareID: 0x8,
                    parameters: [0x01]
                ).data,
                .forbiddenRequest
            ),
        ]

        for (report, expectedError) in forbiddenReports {
            XCTAssertThrowsError(try writer.send(
                report,
                reprogFeatureIndex: 0x2A
            )) { error in
                XCTAssertEqual(error as? M720DiagnosticError, expectedError)
            }
        }
        XCTAssertTrue(writes.isEmpty)
    }

    func testDeviceSnapshotRefusesHelperBeforeAnyIOHIDCapture() {
        var captureCallCount = 0
        let client = M720DiagnosticIOHIDClient(
            helperPortExists: { true },
            captureSnapshot: { _, _ in
                captureCallCount += 1
                return [:]
            }
        )

        XCTAssertThrowsError(try client.snapshot(
            vendorID: M720Profile.vendorID,
            productID: M720Profile.bluetoothLEProductID
        )) { error in
            XCTAssertEqual(error as? M720DiagnosticError, .helperRunning)
        }
        XCTAssertEqual(captureCallCount, 0)
    }

    func testProductionEnumerationCandidateRetainsOwnedDeviceUntilCandidateRelease() {
        weak var weakOwner: DiagnosticEnumerationOwner?
        var candidates = autoreleasepool { () -> [M720DiagnosticDeviceCandidate] in
            let owner = DiagnosticEnumerationOwner(serial: "retained-owner")
            weakOwner = owner
            return M720DiagnosticIOHIDClient.makeCandidates(retaining: [owner])
        }

        XCTAssertNotNil(weakOwner)
        candidates.removeAll()
        XCTAssertNil(weakOwner)
    }

    func testProductionEnumerationOpenFailureDoesNotCloseUnopenedOwnedDevice() {
        let owner = DiagnosticEnumerationOwner(
            serial: "open-failure-owner",
            openError: .deviceOwnershipUnavailable(kIOReturnUnsupported)
        )
        let client = M720DiagnosticIOHIDClient(
            helperPortExists: { false },
            enumerateDevices: {
                M720DiagnosticIOHIDClient.makeCandidates(retaining: [owner])
            }
        )

        XCTAssertThrowsError(try client.snapshot(
            vendorID: M720Profile.vendorID,
            productID: M720Profile.bluetoothLEProductID
        )) { error in
            XCTAssertEqual(
                error as? M720DiagnosticError,
                .deviceOwnershipUnavailable(kIOReturnUnsupported)
            )
        }
        XCTAssertEqual(owner.openCallCount, 1)
        XCTAssertEqual(owner.openedDeviceCloseCallCount, 0)
    }

    func testDeviceInventoryRejectsZeroAmbiguousMissingAndDuplicateSerialBeforeOpen() {
        let missing = diagnosticCandidate(serial: nil)
        let ambiguousOne = diagnosticCandidate(serial: "one")
        let ambiguousTwo = diagnosticCandidate(serial: "two")
        let duplicateOne = diagnosticCandidate(serial: "same")
        let duplicateTwo = diagnosticCandidate(serial: "same")
        let fixtures: [(
            String,
            [M720DiagnosticDeviceCandidate],
            [DiagnosticCandidateProbe],
            M720DiagnosticError
        )] = [
            ("zero", [], [], .noMatchingDevice),
            ("missing", [missing.candidate], [missing.probe], .missingSerialIdentity),
            (
                "ambiguous",
                [ambiguousOne.candidate, ambiguousTwo.candidate],
                [ambiguousOne.probe, ambiguousTwo.probe],
                .ambiguousDevice
            ),
            (
                "duplicate",
                [duplicateOne.candidate, duplicateTwo.candidate],
                [duplicateOne.probe, duplicateTwo.probe],
                .ambiguousDevice
            ),
        ]

        for (name, candidates, probes, expectedError) in fixtures {
            XCTAssertThrowsError(try diagnosticClient(candidates).snapshot(
                vendorID: M720Profile.vendorID,
                productID: M720Profile.bluetoothLEProductID
            )) { error in
                XCTAssertEqual(error as? M720DiagnosticError, expectedError, name)
            }
            XCTAssertTrue(probes.allSatisfy { $0.openCallCount == 0 }, name)
        }
    }

    func testDeviceInventoryFiltersExactVIDPIDAndBLETransportBeforeOpen() throws {
        let wrongVendor = diagnosticCandidate(vendorID: 0x1234, serial: "wrong-vendor")
        let wrongProduct = diagnosticCandidate(productID: 0x5678, serial: "wrong-product")
        let wrongTransport = diagnosticCandidate(transport: "Bluetooth", serial: "wrong-transport")
        let exact = diagnosticCandidate(serial: "exact")

        _ = try diagnosticClient([
            wrongVendor.candidate,
            wrongProduct.candidate,
            wrongTransport.candidate,
            exact.candidate,
        ]).snapshot(
            vendorID: M720Profile.vendorID,
            productID: M720Profile.bluetoothLEProductID
        )

        XCTAssertEqual(wrongVendor.probe.openCallCount, 0)
        XCTAssertEqual(wrongProduct.probe.openCallCount, 0)
        XCTAssertEqual(wrongTransport.probe.openCallCount, 0)
        XCTAssertEqual(exact.probe.openCallCount, 1)
        XCTAssertEqual(exact.probe.closeCallCount, 1)
    }

    func testDeviceLifecycleClosesExactlyOnceOnlyAfterSuccessfulOpenOnEveryExit() throws {
        let openFailure = diagnosticCandidate(
            serial: "open-failure",
            openError: .deviceOwnershipUnavailable(-1)
        )
        XCTAssertThrowsError(try diagnosticClient([openFailure.candidate]).snapshot(
            vendorID: M720Profile.vendorID,
            productID: M720Profile.bluetoothLEProductID
        ))
        XCTAssertEqual(openFailure.probe.closeCallCount, 0)

        for error: M720DiagnosticError in [.timeout, .malformedResponse, .forbiddenRequest] {
            let candidate = diagnosticCandidate(serial: "capture-error", captureError: error)
            XCTAssertThrowsError(try diagnosticClient([candidate.candidate]).snapshot(
                vendorID: M720Profile.vendorID,
                productID: M720Profile.bluetoothLEProductID
            )) { thrown in
                XCTAssertEqual(thrown as? M720DiagnosticError, error)
            }
            XCTAssertEqual(candidate.probe.openCallCount, 1)
            XCTAssertEqual(candidate.probe.closeCallCount, 1)
        }
    }

    func testUnsupportedDeviceOpenFailsClosedAsUnavailableOwnership() {
        XCTAssertEqual(
            try M720DiagnosticDeviceAccessMode.resolveDeviceOpen(
                status: kIOReturnSuccess
            ),
            .deviceOpenedByCLI
        )
        XCTAssertEqual(
            M720DiagnosticError.deviceOwnershipUnavailable(
                kIOReturnUnsupported
            ).description,
            "cannot claim CLI ownership of the exact M720; another HID client may have seized it (\(kIOReturnUnsupported))"
        )
        for status in [kIOReturnUnsupported, kIOReturnNotPrivileged, kIOReturnExclusiveAccess] {
            XCTAssertThrowsError(
                try M720DiagnosticDeviceAccessMode.resolveDeviceOpen(status: status)
            ) { error in
                XCTAssertEqual(
                    error as? M720DiagnosticError,
                    .deviceOwnershipUnavailable(status)
                )
            }
        }
    }

    func testDiagnosticOwnershipClosesAndUnschedulesOnlyCLIOpenedDevice() throws {
        let candidate = diagnosticCandidate(serial: "device-opened-by-cli")

        _ = try diagnosticClient([candidate.candidate]).snapshot(
            vendorID: M720Profile.vendorID,
            productID: M720Profile.bluetoothLEProductID
        )

        XCTAssertEqual(candidate.probe.closeCallCount, 1)
        XCTAssertEqual(candidate.probe.deviceCloseCallCount, 1)
        XCTAssertEqual(candidate.probe.deviceUnscheduleCallCount, 1)
    }

    private func diagnosticClient(
        _ candidates: [M720DiagnosticDeviceCandidate]
    ) -> M720DiagnosticIOHIDClient {
        M720DiagnosticIOHIDClient(
            helperPortExists: { false },
            enumerateDevices: { candidates }
        )
    }

    private func diagnosticCandidate(
        vendorID: Int = M720Profile.vendorID,
        productID: Int = M720Profile.bluetoothLEProductID,
        transport: String = M720Profile.bluetoothLETransport,
        serial: String?,
        openError: M720DiagnosticError? = nil,
        captureError: M720DiagnosticError? = nil,
        accessMode: M720DiagnosticDeviceAccessMode = .deviceOpenedByCLI
    ) -> (candidate: M720DiagnosticDeviceCandidate, probe: DiagnosticCandidateProbe) {
        let probe = DiagnosticCandidateProbe(
            captureError: captureError,
            accessMode: accessMode
        )
        let candidate = M720DiagnosticDeviceCandidate(
            vendorID: vendorID,
            productID: productID,
            transport: transport,
            serialNumber: serial,
            open: {
                probe.openCallCount += 1
                if let openError { throw openError }
                return FakeDiagnosticOpenedDevice(probe: probe)
            }
        )
        return (candidate, probe)
    }

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

    func testDecodesNonZeroStartIndexDataSlice() throws {
        let storage = Data([
            0xFF,
            0x12, 0x34,
            0xAB, 0xCD,
            0x21,
            0x06,
            0x07,
            0x80,
            0x55,
        ])
        let parameters = storage.dropFirst()

        XCTAssertNotEqual(parameters.startIndex, 0)
        XCTAssertEqual(
            try ReprogControlsV4.decodeControlInfo(parameters),
            HIDPPControlInfo(
                cid: 0x1234,
                taskID: 0xABCD,
                flags: 0x21,
                position: 0x06,
                group: 0x07,
                groupMask: 0x80,
                rawXYFlags: 0x55
            )
        )
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

    func testSetEchoValidatorIgnoresRequestAndResponsePadding() {
        let documented = ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: true)
        let request = documented + [UInt8](repeating: 0xC3, count: 11)
        let response = Data(documented + [UInt8](repeating: 0xA5, count: 11))

        XCTAssertNoThrow(try ReprogControlsV4.validateSetCidReportingEcho(
            response,
            matches: request
        ))
    }

    func testSetEchoValidatorAcceptsM720ZeroFilledAcknowledgement() {
        let request = ReprogControlsV4.setReportingParameters(
            cid: 0x005B,
            diverted: true
        )
        let response = Data(repeating: 0, count: 16)

        XCTAssertNoThrow(try ReprogControlsV4.validateSetCidReportingEcho(
            response,
            matches: request
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

    func testSetEchoValidatorRejectsEveryShortRequestWithoutTrapping() {
        let documented = ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: true)

        for length in 0..<5 {
            XCTAssertThrowsError(try ReprogControlsV4.validateSetCidReportingEcho(
                Data(documented),
                matches: Array(documented.prefix(length))
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

private final class DiagnosticCandidateProbe {
    let captureError: M720DiagnosticError?
    let accessMode: M720DiagnosticDeviceAccessMode
    var openCallCount = 0
    var captureCallCount = 0
    var closeCallCount = 0
    var deviceCloseCallCount = 0
    var deviceUnscheduleCallCount = 0

    init(
        captureError: M720DiagnosticError?,
        accessMode: M720DiagnosticDeviceAccessMode
    ) {
        self.captureError = captureError
        self.accessMode = accessMode
    }
}

private final class DiagnosticEnumerationOwner: M720DiagnosticEnumeratedDeviceOwner {
    let vendorID = M720Profile.vendorID
    let productID = M720Profile.bluetoothLEProductID
    let transport = M720Profile.bluetoothLETransport
    let serialNumber: String?
    let openError: M720DiagnosticError?
    var openCallCount = 0
    var openedDeviceCloseCallCount = 0

    init(serial: String?, openError: M720DiagnosticError? = nil) {
        serialNumber = serial
        self.openError = openError
    }

    func open() throws -> M720DiagnosticOpenedDevice {
        openCallCount += 1
        if let openError { throw openError }
        return EnumerationFakeOpenedDevice(owner: self)
    }
}

private final class EnumerationFakeOpenedDevice: M720DiagnosticOpenedDevice {
    private unowned let owner: DiagnosticEnumerationOwner

    init(owner: DiagnosticEnumerationOwner) {
        self.owner = owner
    }

    let accessMode: M720DiagnosticDeviceAccessMode = .deviceOpenedByCLI

    func captureSnapshot() throws -> NSDictionary { ["ok": true] }

    func close() {
        owner.openedDeviceCloseCallCount += 1
    }
}

private final class FakeDiagnosticOpenedDevice: M720DiagnosticOpenedDevice {
    private let probe: DiagnosticCandidateProbe

    init(probe: DiagnosticCandidateProbe) {
        self.probe = probe
    }

    func captureSnapshot() throws -> NSDictionary {
        probe.captureCallCount += 1
        if let error = probe.captureError { throw error }
        return [
            "ok": true,
            "accessMode": probe.accessMode.rawValue,
        ]
    }

    var accessMode: M720DiagnosticDeviceAccessMode { probe.accessMode }

    func close() {
        probe.closeCallCount += 1
        if probe.accessMode.closesDevice { probe.deviceCloseCallCount += 1 }
        if probe.accessMode.unschedulesDevice { probe.deviceUnscheduleCallCount += 1 }
    }
}
