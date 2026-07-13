import Foundation

struct HIDPPRequestIdentity: Equatable, Hashable {
    let featureIndex: UInt8
    let function: UInt8
    let softwareID: UInt8
}

struct HIDPPErrorFrame: Equatable {
    let identity: HIDPPRequestIdentity
    let code: UInt8
}

enum HIDPPInbound: Equatable {
    case response(identity: HIDPPRequestIdentity, parameters: Data)
    case event(featureIndex: UInt8, event: UInt8, parameters: Data)
    case error(HIDPPErrorFrame)
}

enum HIDPPFrameError: Error, Equatable {
    case invalidLength(Int)
    case invalidReportID(UInt8)
    case invalidDeviceIndex(UInt8)
    case invalidSoftwareID(UInt8)
}

struct HIDPPLongReport {
    let data: Data

    static func request(
        deviceIndex: UInt8,
        featureIndex: UInt8,
        function: UInt8,
        softwareID: UInt8,
        parameters: [UInt8]
    ) -> HIDPPLongReport {
        precondition(function <= 0x0F, "HID++ function must fit in four bits")
        precondition(softwareID >= 0x01 && softwareID <= 0x0F, "HID++ request software ID must be 1...15")
        precondition(parameters.count <= 16, "HID++ long reports hold at most 16 parameter bytes")

        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = 0x11
        bytes[1] = deviceIndex
        bytes[2] = featureIndex
        bytes[3] = (function << 4) | softwareID
        bytes.replaceSubrange(4..<(4 + parameters.count), with: parameters)
        return HIDPPLongReport(data: Data(bytes))
    }

    static func decode(
        _ data: Data,
        acceptedDeviceIndices: Set<UInt8>
    ) throws -> HIDPPInbound {
        guard data.count == 20 else {
            throw HIDPPFrameError.invalidLength(data.count)
        }

        let bytes = [UInt8](data)
        guard bytes[0] == 0x11 else {
            throw HIDPPFrameError.invalidReportID(bytes[0])
        }
        guard acceptedDeviceIndices.contains(bytes[1]) else {
            throw HIDPPFrameError.invalidDeviceIndex(bytes[1])
        }

        if bytes[2] == 0xFF {
            let functionAndSoftwareID = bytes[4]
            let softwareID = functionAndSoftwareID & 0x0F
            guard softwareID != 0 else {
                throw HIDPPFrameError.invalidSoftwareID(softwareID)
            }

            return .error(HIDPPErrorFrame(
                identity: HIDPPRequestIdentity(
                    featureIndex: bytes[3],
                    function: functionAndSoftwareID >> 4,
                    softwareID: softwareID
                ),
                code: bytes[5]
            ))
        }

        let functionAndSoftwareID = bytes[3]
        let function = functionAndSoftwareID >> 4
        let softwareID = functionAndSoftwareID & 0x0F
        let parameters = Data(bytes[4...])

        if softwareID == 0 {
            return .event(featureIndex: bytes[2], event: function, parameters: parameters)
        }

        return .response(
            identity: HIDPPRequestIdentity(
                featureIndex: bytes[2],
                function: function,
                softwareID: softwareID
            ),
            parameters: parameters
        )
    }
}
