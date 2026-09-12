import Foundation

struct UnifyingReceiverPairingInformation: Equatable {
    let slot: UInt8
    let wirelessProductID: UInt16
}

struct UnifyingReceiverExtendedPairingInformation: Equatable {
    let slot: UInt8
    let serialNumber: String
}

struct UnifyingReceiverErrorFrame: Equatable {
    let command: UInt8
    let address: UInt8
    let code: UInt8
}

enum UnifyingReceiverLinkEvent: Equatable {
    case linkChanged(slot: UInt8, wirelessProductID: UInt16, online: Bool)
    case unpaired(slot: UInt8)
}

enum UnifyingReceiverProtocolError: Error, Equatable {
    case invalidLength(Int)
    case invalidReportID(UInt8)
    case invalidDeviceIndex(UInt8)
    case invalidSlot(UInt8)
    case unexpectedCommand(expected: UInt8, actual: UInt8)
    case unexpectedAddress(expected: UInt8, actual: UInt8)
    case unexpectedSubregister(expected: UInt8, actual: UInt8)
    case unsupportedNotification(subID: UInt8, address: UInt8)
    case receiver(code: UInt8)
}

enum UnifyingReceiverProtocol {
    static let receiverDeviceIndex: UInt8 = 0xFF
    static let slotRange = UInt8(1)...UInt8(6)
    static let wirelessNotificationFlag: UInt32 = 0x000100

    static func pairingInformationRequest(slot: UInt8) throws -> Data {
        try receiverInformationRequest(subregister: pairingSubregister(slot: slot))
    }

    static func extendedPairingInformationRequest(slot: UInt8) throws -> Data {
        try receiverInformationRequest(subregister: extendedPairingSubregister(slot: slot))
    }

    static func notificationFlagsReadRequest() -> Data {
        shortReport(command: 0x81, address: 0x00, parameters: [0, 0, 0])
    }

    static func notificationFlagsWriteRequest(_ flags: UInt32) -> Data {
        precondition(flags <= 0x00FF_FFFF, "receiver notification flags hold 24 bits")
        return shortReport(
            command: 0x80,
            address: 0x00,
            parameters: [
                UInt8((flags >> 16) & 0xFF),
                UInt8((flags >> 8) & 0xFF),
                UInt8(flags & 0xFF),
            ]
        )
    }

    static func notifyConnectedDevicesRequest() -> Data {
        shortReport(command: 0x80, address: 0x02, parameters: [0x02, 0, 0])
    }

    static func decodePairingInformation(
        _ data: Data,
        slot: UInt8
    ) throws -> UnifyingReceiverPairingInformation {
        let expectedSubregister = try pairingSubregister(slot: slot)
        let bytes = try decodeReceiverInformationResponse(
            data,
            expectedSubregister: expectedSubregister
        )
        return UnifyingReceiverPairingInformation(
            slot: slot,
            wirelessProductID: UInt16(bytes[7]) << 8 | UInt16(bytes[8])
        )
    }

    static func decodeExtendedPairingInformation(
        _ data: Data,
        slot: UInt8
    ) throws -> UnifyingReceiverExtendedPairingInformation {
        let expectedSubregister = try extendedPairingSubregister(slot: slot)
        let bytes = try decodeReceiverInformationResponse(
            data,
            expectedSubregister: expectedSubregister
        )
        let serial = bytes[5...8]
            .map { String(format: "%02X", $0) }
            .joined()
        return UnifyingReceiverExtendedPairingInformation(
            slot: slot,
            serialNumber: serial
        )
    }

    static func decodeError(_ data: Data) throws -> UnifyingReceiverErrorFrame {
        let bytes = [UInt8](data)
        guard bytes.count == 7 else {
            throw UnifyingReceiverProtocolError.invalidLength(bytes.count)
        }
        guard bytes[0] == 0x10 else {
            throw UnifyingReceiverProtocolError.invalidReportID(bytes[0])
        }
        guard bytes[1] == receiverDeviceIndex else {
            throw UnifyingReceiverProtocolError.invalidDeviceIndex(bytes[1])
        }
        guard bytes[2] == 0x8F else {
            throw UnifyingReceiverProtocolError.unexpectedCommand(
                expected: 0x8F,
                actual: bytes[2]
            )
        }
        return UnifyingReceiverErrorFrame(
            command: bytes[3],
            address: bytes[4],
            code: bytes[5]
        )
    }

    static func decodeNotificationFlags(_ data: Data) throws -> UInt32 {
        let bytes = try decodeShortResponse(
            data,
            expectedCommand: 0x81,
            expectedAddress: 0x00
        )
        return UInt32(bytes[4]) << 16 |
            UInt32(bytes[5]) << 8 |
            UInt32(bytes[6])
    }

    static func decodeLinkEvent(_ data: Data) throws -> UnifyingReceiverLinkEvent {
        let bytes = [UInt8](data)
        guard bytes.count == 7 else {
            throw UnifyingReceiverProtocolError.invalidLength(bytes.count)
        }
        guard bytes[0] == 0x10 else {
            throw UnifyingReceiverProtocolError.invalidReportID(bytes[0])
        }
        let slot = bytes[1]
        guard slotRange.contains(slot) else {
            throw UnifyingReceiverProtocolError.invalidSlot(slot)
        }

        switch (bytes[2], bytes[3]) {
        case (0x41, let address) where address != 0:
            let wirelessProductID = UInt16(bytes[6]) << 8 | UInt16(bytes[5])
            return .linkChanged(
                slot: slot,
                wirelessProductID: wirelessProductID,
                online: bytes[4] & 0x40 == 0
            )
        case (0x40, 0x02):
            return .unpaired(slot: slot)
        default:
            throw UnifyingReceiverProtocolError.unsupportedNotification(
                subID: bytes[2],
                address: bytes[3]
            )
        }
    }

    private static func pairingSubregister(slot: UInt8) throws -> UInt8 {
        guard slotRange.contains(slot) else {
            throw UnifyingReceiverProtocolError.invalidSlot(slot)
        }
        return 0x1F + slot
    }

    private static func extendedPairingSubregister(slot: UInt8) throws -> UInt8 {
        guard slotRange.contains(slot) else {
            throw UnifyingReceiverProtocolError.invalidSlot(slot)
        }
        return 0x2F + slot
    }

    private static func receiverInformationRequest(subregister: UInt8) throws -> Data {
        shortReport(
            command: 0x83,
            address: 0xB5,
            parameters: [subregister, 0, 0]
        )
    }

    private static func shortReport(
        command: UInt8,
        address: UInt8,
        parameters: [UInt8]
    ) -> Data {
        precondition(parameters.count == 3)
        return Data([
            0x10,
            receiverDeviceIndex,
            command,
            address,
            parameters[0],
            parameters[1],
            parameters[2],
        ])
    }

    private static func decodeReceiverInformationResponse(
        _ data: Data,
        expectedSubregister: UInt8
    ) throws -> [UInt8] {
        if data.count == 7,
           let error = try? decodeError(data),
           error.command == 0x83,
           error.address == 0xB5
        {
            throw UnifyingReceiverProtocolError.receiver(code: error.code)
        }

        let bytes = [UInt8](data)
        guard bytes.count == 20 else {
            throw UnifyingReceiverProtocolError.invalidLength(bytes.count)
        }
        guard bytes[0] == 0x11 else {
            throw UnifyingReceiverProtocolError.invalidReportID(bytes[0])
        }
        guard bytes[1] == receiverDeviceIndex else {
            throw UnifyingReceiverProtocolError.invalidDeviceIndex(bytes[1])
        }
        guard bytes[2] == 0x83 else {
            throw UnifyingReceiverProtocolError.unexpectedCommand(
                expected: 0x83,
                actual: bytes[2]
            )
        }
        guard bytes[3] == 0xB5 else {
            throw UnifyingReceiverProtocolError.unexpectedAddress(
                expected: 0xB5,
                actual: bytes[3]
            )
        }
        guard bytes[4] == expectedSubregister else {
            throw UnifyingReceiverProtocolError.unexpectedSubregister(
                expected: expectedSubregister,
                actual: bytes[4]
            )
        }
        return bytes
    }

    private static func decodeShortResponse(
        _ data: Data,
        expectedCommand: UInt8,
        expectedAddress: UInt8
    ) throws -> [UInt8] {
        if data.count == 7,
           let error = try? decodeError(data),
           error.command == expectedCommand,
           error.address == expectedAddress
        {
            throw UnifyingReceiverProtocolError.receiver(code: error.code)
        }

        let bytes = [UInt8](data)
        guard bytes.count == 7 else {
            throw UnifyingReceiverProtocolError.invalidLength(bytes.count)
        }
        guard bytes[0] == 0x10 else {
            throw UnifyingReceiverProtocolError.invalidReportID(bytes[0])
        }
        guard bytes[1] == receiverDeviceIndex else {
            throw UnifyingReceiverProtocolError.invalidDeviceIndex(bytes[1])
        }
        guard bytes[2] == expectedCommand else {
            throw UnifyingReceiverProtocolError.unexpectedCommand(
                expected: expectedCommand,
                actual: bytes[2]
            )
        }
        guard bytes[3] == expectedAddress else {
            throw UnifyingReceiverProtocolError.unexpectedAddress(
                expected: expectedAddress,
                actual: bytes[3]
            )
        }
        return bytes
    }
}
