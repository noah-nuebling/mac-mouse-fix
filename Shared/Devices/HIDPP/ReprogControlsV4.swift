import Foundation

struct HIDPPFeatureLookup: Equatable {
    let featureIndex: UInt8
    let featureType: UInt8
    let featureVersion: UInt8
}

struct HIDPPControlInfo: Equatable {
    let cid: UInt16
    let taskID: UInt16
    let flags: UInt8
    let position: UInt8
    let group: UInt8
    let groupMask: UInt8
    let rawXYFlags: UInt8

    var isMouseControl: Bool { flags & 0x01 != 0 }
    var isReprogrammable: Bool { flags & 0x10 != 0 }
    var isDivertable: Bool { flags & 0x20 != 0 }
}

struct HIDPPReportingState: Codable, Equatable {
    let cid: UInt16
    let flags: UInt8
    let remappedCID: UInt16

    var isDiverted: Bool { flags & 0x01 != 0 }
    var isPersistent: Bool { flags & 0x04 != 0 }
    var hasRawXY: Bool { flags & 0x10 != 0 }

    func changingDivert(to value: Bool) -> HIDPPReportingState {
        HIDPPReportingState(
            cid: cid,
            flags: value ? flags | 0x01 : flags & ~UInt8(0x01),
            remappedCID: remappedCID
        )
    }
}

enum ReprogControlsError: Error, Equatable {
    case shortPayload(expected: Int, actual: Int)
    case unsupportedFeature
    case controlCountExceedsMaximum(UInt8)
    case setCidReportingEchoMismatch
    case unsupportedTarget(UInt16)
}

enum ReprogControlsV4 {
    enum Function: UInt8 {
        case getCount = 0
        case getCidInfo = 1
        case getCidReporting = 2
        case setCidReporting = 3
    }

    static func rootGetFeatureRequest(
        deviceIndex: UInt8,
        softwareID: UInt8
    ) -> HIDPPLongReport {
        HIDPPLongReport.request(
            deviceIndex: deviceIndex,
            featureIndex: 0,
            function: 0,
            softwareID: softwareID,
            parameters: bigEndianBytes(M720Profile.featureID)
        )
    }

    static func getCountRequest(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        softwareID: UInt8
    ) -> HIDPPLongReport {
        request(
            deviceIndex: deviceIndex,
            featureIndex: featureIndex,
            function: .getCount,
            softwareID: softwareID,
            parameters: []
        )
    }

    static func getCidInfoRequest(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        softwareID: UInt8,
        index: UInt8
    ) -> HIDPPLongReport {
        request(
            deviceIndex: deviceIndex,
            featureIndex: featureIndex,
            function: .getCidInfo,
            softwareID: softwareID,
            parameters: [index]
        )
    }

    static func getCidReportingRequest(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        softwareID: UInt8,
        cid: UInt16
    ) -> HIDPPLongReport {
        request(
            deviceIndex: deviceIndex,
            featureIndex: featureIndex,
            function: .getCidReporting,
            softwareID: softwareID,
            parameters: bigEndianBytes(cid)
        )
    }

    static func setCidReportingRequest(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        softwareID: UInt8,
        cid: UInt16,
        diverted: Bool
    ) -> HIDPPLongReport {
        request(
            deviceIndex: deviceIndex,
            featureIndex: featureIndex,
            function: .setCidReporting,
            softwareID: softwareID,
            parameters: setReportingParameters(cid: cid, diverted: diverted)
        )
    }

    static func setReportingParameters(cid: UInt16, diverted: Bool) -> [UInt8] {
        bigEndianBytes(cid) + [diverted ? 0x03 : 0x02, 0x00, 0x00]
    }

    static func decodeFeatureLookup(_ parameters: Data) throws -> HIDPPFeatureLookup {
        let bytes = try documentedPrefix(parameters, length: 3)
        guard bytes[0] != 0 else {
            throw ReprogControlsError.unsupportedFeature
        }

        return HIDPPFeatureLookup(
            featureIndex: bytes[0],
            featureType: bytes[1],
            featureVersion: bytes[2]
        )
    }

    static func decodeControlCount(_ parameters: Data) throws -> UInt8 {
        let bytes = try documentedPrefix(parameters, length: 1)
        let count = bytes[0]
        guard Int(count) <= M720Profile.maximumControlCount else {
            throw ReprogControlsError.controlCountExceedsMaximum(count)
        }
        return count
    }

    static func decodeControlInfo(_ parameters: Data) throws -> HIDPPControlInfo {
        let bytes = try documentedPrefix(parameters, length: 9)
        return HIDPPControlInfo(
            cid: uint16(bytes[0], bytes[1]),
            taskID: uint16(bytes[2], bytes[3]),
            flags: bytes[4],
            position: bytes[5],
            group: bytes[6],
            groupMask: bytes[7],
            rawXYFlags: bytes[8]
        )
    }

    static func decodeReportingState(_ parameters: Data) throws -> HIDPPReportingState {
        let bytes = try documentedPrefix(parameters, length: 5)
        return HIDPPReportingState(
            cid: uint16(bytes[0], bytes[1]),
            flags: bytes[2],
            remappedCID: uint16(bytes[3], bytes[4])
        )
    }

    static func validateSetCidReportingEcho(
        _ parameters: Data,
        matches requestParameters: [UInt8]
    ) throws {
        precondition(requestParameters.count == 5)
        let responseParameters = try documentedPrefix(parameters, length: 5)
        guard responseParameters == requestParameters else {
            throw ReprogControlsError.setCidReportingEchoMismatch
        }
    }

    static func validateTarget(_ info: HIDPPControlInfo) throws {
        guard M720Profile.cidToButton[info.cid] != nil else { return }
        guard info.isMouseControl && info.isDivertable else {
            throw ReprogControlsError.unsupportedTarget(info.cid)
        }
    }

    private static func request(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        function: Function,
        softwareID: UInt8,
        parameters: [UInt8]
    ) -> HIDPPLongReport {
        HIDPPLongReport.request(
            deviceIndex: deviceIndex,
            featureIndex: featureIndex,
            function: function.rawValue,
            softwareID: softwareID,
            parameters: parameters
        )
    }

    private static func documentedPrefix(_ parameters: Data, length: Int) throws -> [UInt8] {
        guard parameters.count >= length else {
            throw ReprogControlsError.shortPayload(
                expected: length,
                actual: parameters.count
            )
        }
        return Array(parameters.prefix(length))
    }

    private static func bigEndianBytes(_ value: UInt16) -> [UInt8] {
        [UInt8(value >> 8), UInt8(value & 0x00FF)]
    }

    private static func uint16(_ mostSignificantByte: UInt8, _ leastSignificantByte: UInt8) -> UInt16 {
        UInt16(mostSignificantByte) << 8 | UInt16(leastSignificantByte)
    }
}
