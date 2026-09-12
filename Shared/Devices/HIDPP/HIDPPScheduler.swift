import Foundation

protocol HIDPPCancellation: AnyObject {
    func cancel()
}

protocol HIDPPScheduler {
    var now: TimeInterval { get }

    @discardableResult
    func schedule(
        after delay: TimeInterval,
        _ block: @escaping () -> Void
    ) -> HIDPPCancellation
}

final class DispatchHIDPPScheduler: HIDPPScheduler {
    private let queue: DispatchQueue

    init(queue: DispatchQueue = .main) {
        self.queue = queue
    }

    var now: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    @discardableResult
    func schedule(
        after delay: TimeInterval,
        _ block: @escaping () -> Void
    ) -> HIDPPCancellation {
        let workItem = DispatchWorkItem(block: block)
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
        return DispatchHIDPPCancellation(workItem: workItem)
    }
}

private final class DispatchHIDPPCancellation: HIDPPCancellation {
    private let workItem: DispatchWorkItem

    init(workItem: DispatchWorkItem) {
        self.workItem = workItem
    }

    func cancel() {
        workItem.cancel()
    }
}
