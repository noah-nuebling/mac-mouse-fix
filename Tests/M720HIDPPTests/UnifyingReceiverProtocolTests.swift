import Foundation
import XCTest
@testable import Mac_Mouse_Fix_Helper

final class UnifyingReceiverProtocolTests: XCTestCase {
    func testRealM720ReceiverFixtureDecodesSlotWPIDAndSerial() throws {
        let fixture = try loadFixture()

        XCTAssertEqual(
            Array(try UnifyingReceiverProtocol.pairingInformationRequest(slot: fixture.slot)),
            fixture.pairingRequest
        )
        XCTAssertEqual(
            Array(try UnifyingReceiverProtocol.extendedPairingInformationRequest(slot: fixture.slot)),
            fixture.extendedPairingRequest
        )
        XCTAssertEqual(
            try UnifyingReceiverProtocol.decodePairingInformation(
                Data(fixture.pairingResponse),
                slot: fixture.slot
            ),
            UnifyingReceiverPairingInformation(
                slot: fixture.slot,
                wirelessProductID: fixture.wirelessProductID
            )
        )
        XCTAssertEqual(
            try UnifyingReceiverProtocol.decodeExtendedPairingInformation(
                Data(fixture.extendedPairingResponse),
                slot: fixture.slot
            ),
            UnifyingReceiverExtendedPairingInformation(
                slot: fixture.slot,
                serialNumber: fixture.serialNumber
            )
        )
    }

    func testRealEmptySlotResponseDecodesAsReceiverInvalidValueError() throws {
        let fixture = try loadFixture()

        XCTAssertEqual(
            Array(try UnifyingReceiverProtocol.pairingInformationRequest(slot: 2)),
            fixture.emptySlotRequest
        )
        XCTAssertEqual(
            try UnifyingReceiverProtocol.decodeError(Data(fixture.emptySlotResponse)),
            UnifyingReceiverErrorFrame(
                command: 0x83,
                address: 0xB5,
                code: 0x03
            )
        )
        XCTAssertThrowsError(
            try UnifyingReceiverProtocol.decodePairingInformation(
                Data(fixture.emptySlotResponse),
                slot: 2
            )
        ) { error in
            XCTAssertEqual(
                error as? UnifyingReceiverProtocolError,
                .receiver(code: 0x03)
            )
        }
    }

    func testNotificationFlagRequestsPreserveThreeByteBigEndianLayout() {
        XCTAssertEqual(
            Array(UnifyingReceiverProtocol.notificationFlagsReadRequest()),
            [0x10, 0xFF, 0x81, 0x00, 0x00, 0x00, 0x00]
        )
        XCTAssertEqual(
            Array(UnifyingReceiverProtocol.notificationFlagsWriteRequest(0x123456)),
            [0x10, 0xFF, 0x80, 0x00, 0x12, 0x34, 0x56]
        )
        XCTAssertEqual(
            try? UnifyingReceiverProtocol.decodeNotificationFlags(
                Data([0x10, 0xFF, 0x81, 0x00, 0x12, 0x34, 0x56])
            ),
            0x123456
        )
        XCTAssertEqual(
            Array(UnifyingReceiverProtocol.notifyConnectedDevicesRequest()),
            [0x10, 0xFF, 0x80, 0x02, 0x02, 0x00, 0x00]
        )
    }

    func testConnectionNotificationsDecodeOnlineOfflineAndUnpaired() throws {
        XCTAssertEqual(
            try UnifyingReceiverProtocol.decodeLinkEvent(Data([
                0x10, 0x01, 0x41, 0x04, 0x20, 0x5E, 0x40,
            ])),
            .linkChanged(slot: 1, wirelessProductID: 0x405E, online: true)
        )
        XCTAssertEqual(
            try UnifyingReceiverProtocol.decodeLinkEvent(Data([
                0x10, 0x01, 0x41, 0x04, 0x60, 0x5E, 0x40,
            ])),
            .linkChanged(slot: 1, wirelessProductID: 0x405E, online: false)
        )
        XCTAssertEqual(
            try UnifyingReceiverProtocol.decodeLinkEvent(Data([
                0x10, 0x01, 0x40, 0x02, 0x00, 0x00, 0x00,
            ])),
            .unpaired(slot: 1)
        )
    }

    func testRejectsWrongSlotSubregisterAndMalformedFrames() {
        let realPairing = Data([
            0x11, 0xFF, 0x83, 0xB5, 0x20, 0x08, 0x08, 0x40, 0x5E,
            0x04, 0x03, 0x02, 0x07, 0, 0, 0, 0, 0, 0, 0,
        ])

        XCTAssertThrowsError(
            try UnifyingReceiverProtocol.decodePairingInformation(realPairing, slot: 2)
        ) { error in
            XCTAssertEqual(
                error as? UnifyingReceiverProtocolError,
                .unexpectedSubregister(expected: 0x21, actual: 0x20)
            )
        }
        XCTAssertThrowsError(
            try UnifyingReceiverProtocol.decodeLinkEvent(Data([0x10, 0x01, 0x41]))
        ) { error in
            XCTAssertEqual(
                error as? UnifyingReceiverProtocolError,
                .invalidLength(3)
            )
        }
        XCTAssertThrowsError(
            try UnifyingReceiverProtocol.pairingInformationRequest(slot: 0)
        ) { error in
            XCTAssertEqual(error as? UnifyingReceiverProtocolError, .invalidSlot(0))
        }
    }

    private func loadFixture() throws -> UnifyingReceiverReferenceFixture {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(
            forResource: "M720-405E-Unifying-reference",
            withExtension: "json"
        ))
        return try JSONDecoder().decode(
            UnifyingReceiverReferenceFixture.self,
            from: Data(contentsOf: url)
        )
    }
}

private struct UnifyingReceiverReferenceFixture: Decodable {
    let receiverProductID: Int
    let wirelessProductID: UInt16
    let slot: UInt8
    let serialNumber: String
    let pairingRequest: [UInt8]
    let pairingResponse: [UInt8]
    let extendedPairingRequest: [UInt8]
    let extendedPairingResponse: [UInt8]
    let emptySlotRequest: [UInt8]
    let emptySlotResponse: [UInt8]
}
