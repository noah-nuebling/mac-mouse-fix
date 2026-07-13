import Foundation
import IOKit
@testable import Mac_Mouse_Fix_Helper

final class ScriptedHIDPPTransport: HIDPPTransport {
    let deviceIndex: UInt8 = 0xFF
    let acceptedResponseDeviceIndices: Set<UInt8> = [0x00, 0xFF]
    var onReport: ((Data) -> Void)?
    private(set) var sent: [Data] = []

    func send(_ report: Data, completion: @escaping (IOReturn) -> Void) {
        sent.append(report)
        completion(kIOReturnSuccess)
    }

    func inject(_ bytes: [UInt8]) {
        onReport?(Data(bytes))
    }

    func invalidate() {
        onReport = nil
    }
}
