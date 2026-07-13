import Foundation
import IOKit
@testable import Mac_Mouse_Fix_Helper

final class ScriptedHIDPPTransport: HIDPPTransport {
    let deviceIndex: UInt8 = 0xFF
    let acceptedResponseDeviceIndices: Set<UInt8> = [0x00, 0xFF]
    var onReport: ((Data) -> Void)?
    var automaticallyCompletesSends = true
    var automaticSendResult = kIOReturnSuccess
    var onSend: ((Data) -> Void)?
    var onInvalidate: (() -> Void)?
    private(set) var sent: [Data] = []
    private(set) var invalidateCallCount = 0
    private(set) var maximumSendCallDepth = 0
    private var pendingSendCompletions: [(IOReturn) -> Void] = []
    private var sendCallDepth = 0

    var pendingSendCompletionCount: Int {
        pendingSendCompletions.count
    }

    func send(_ report: Data, completion: @escaping (IOReturn) -> Void) {
        sendCallDepth += 1
        maximumSendCallDepth = max(maximumSendCallDepth, sendCallDepth)
        defer { sendCallDepth -= 1 }

        sent.append(report)
        onSend?(report)
        if automaticallyCompletesSends {
            completion(automaticSendResult)
        } else {
            pendingSendCompletions.append(completion)
        }
    }

    func completeNextSend(with result: IOReturn = kIOReturnSuccess) {
        precondition(!pendingSendCompletions.isEmpty)
        pendingSendCompletions.removeFirst()(result)
    }

    func inject(_ bytes: [UInt8]) {
        onReport?(Data(bytes))
    }

    func invalidate() {
        invalidateCallCount += 1
        onInvalidate?()
        onReport = nil
    }
}
