import Foundation
import IOKit

protocol HIDPPTransport: AnyObject {
    var deviceIndex: UInt8 { get }
    var acceptedResponseDeviceIndices: Set<UInt8> { get }
    var onReport: ((Data) -> Void)? { get set }

    func send(_ report: Data, completion: @escaping (IOReturn) -> Void)
    func invalidate(completion: @escaping () -> Void)
}

extension HIDPPTransport {
    func invalidate() {
        invalidate(completion: {})
    }
}
