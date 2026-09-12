import CoreFoundation
import Foundation
#if canImport(XCTest)
@testable import Mac_Mouse_Fix_Helper
#endif

struct M720DiagnosticMessagePortClient {
    static let helperPortName = "com.nuebling.mac-mouse-fix.helper"
    private static let messageID: Int32 = 0x420666

    static func helperPortExists() -> Bool {
        CFMessagePortCreateRemote(nil, helperPortName as CFString) != nil
    }

    func snapshot() throws -> NSDictionary {
        guard let port = CFMessagePortCreateRemote(
            nil,
            Self.helperPortName as CFString
        ) else {
            throw M720DiagnosticError.helperUnavailable
        }
        let request = try NSKeyedArchiver.archivedData(
            withRootObject: ["message": M720IPCMessage.getDiagnosticState],
            requiringSecureCoding: false
        )
        var unmanagedResponse: Unmanaged<CFData>?
        let status = CFMessagePortSendRequest(
            port,
            Self.messageID,
            request as CFData,
            0,
            1,
            CFRunLoopMode.defaultMode.rawValue,
            &unmanagedResponse
        )
        guard status == kCFMessagePortSuccess,
              let response = unmanagedResponse?.takeRetainedValue()
        else {
            throw M720DiagnosticError.messagePort(status)
        }
        guard let raw = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(
            response as Data
        ) else {
            throw M720DiagnosticError.invalidHelperResponse
        }
        guard let state = try? M720HelperDiagnosticState.decode(raw) else {
            throw M720DiagnosticError.invalidHelperResponse
        }
        return state.payload
    }
}
