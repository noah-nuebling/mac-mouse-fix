import Foundation

enum M720DiagnosticCommand: Equatable {
    private static let supportedVendorID = 0x046D
    private static let supportedProductID = 0xB015

    case helperSnapshot
    case deviceSnapshot(vendorID: Int, productID: Int)

    static func parse(_ arguments: [String]) throws -> Self {
        if arguments == ["helper-snapshot"] {
            return .helperSnapshot
        }
        guard arguments.count == 5,
              arguments[0] == "device-snapshot",
              arguments[1] == "--vid",
              arguments[3] == "--pid",
              let vendorID = Int(arguments[2], radix: 16),
              let productID = Int(arguments[4], radix: 16),
              vendorID == supportedVendorID,
              productID == supportedProductID
        else {
            throw M720DiagnosticError.usage
        }
        return .deviceSnapshot(vendorID: vendorID, productID: productID)
    }
}

enum M720DiagnosticError: Error, Equatable {
    case usage
    case helperUnavailable
    case helperRunning
    case invalidHelperResponse
    case messagePort(Int32)
    case noMatchingDevice
    case ambiguousDevice
    case missingSerialIdentity
    case deviceOwnershipUnavailable(Int32)
    case transport(Int32)
    case timeout
    case malformedResponse
    case device(UInt8)
    case forbiddenRequest
    case persistentFeatureForbidden
    case softwareIDsExhausted
    case unsupportedFeature

    static let usageText = """
    usage:
      M720 HIDPP Diagnostic helper-snapshot
      M720 HIDPP Diagnostic device-snapshot --vid 046d --pid b015
    """
}

extension M720DiagnosticError: CustomStringConvertible {
    var description: String {
        switch self {
        case .usage: return "invalid command"
        case .helperUnavailable: return "Helper message port is unavailable"
        case .helperRunning:
            return "refusing direct IOHID access while the Helper message port exists"
        case .invalidHelperResponse: return "Helper returned an invalid diagnostic response"
        case let .messagePort(status): return "message-port request failed (\(status))"
        case .noMatchingDevice: return "no exact BLE 046D:B015 device was found"
        case .ambiguousDevice: return "multiple exact BLE 046D:B015 devices were found"
        case .missingSerialIdentity: return "the exact BLE device has no unique serial identity"
        case let .deviceOwnershipUnavailable(status):
            return "cannot claim CLI ownership of the exact M720; another HID client may have seized it (\(status))"
        case let .transport(status): return "sending the HID++ report failed (\(status))"
        case .timeout: return "timed out waiting for the HID++ response"
        case .malformedResponse: return "received a malformed HID++ response"
        case let .device(code): return String(format: "device returned HID++ error 0x%02x", code)
        case .forbiddenRequest: return "the request is not one of the four read-only Get shapes"
        case .persistentFeatureForbidden: return "feature 0x1C00 is forbidden"
        case .softwareIDsExhausted:
            return "exhausted unique HID++ software IDs for this feature/function"
        case .unsupportedFeature: return "ReprogControlsV4 is unavailable or incomplete"
        }
    }
}
