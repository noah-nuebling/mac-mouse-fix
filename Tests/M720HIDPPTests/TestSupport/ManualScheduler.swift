import Foundation
@testable import Mac_Mouse_Fix_Helper

final class ManualScheduler: HIDPPScheduler {
    private struct ScheduledBlock {
        let deadline: TimeInterval
        let insertionOrder: Int
        let cancellation: ManualHIDPPCancellation
        let block: () -> Void
    }

    private var scheduledBlocks: [ScheduledBlock] = []
    private var nextInsertionOrder = 0
    private(set) var now: TimeInterval = 0

    @discardableResult
    func schedule(
        after delay: TimeInterval,
        _ block: @escaping () -> Void
    ) -> HIDPPCancellation {
        let cancellation = ManualHIDPPCancellation()
        scheduledBlocks.append(ScheduledBlock(
            deadline: now + delay,
            insertionOrder: nextInsertionOrder,
            cancellation: cancellation,
            block: block
        ))
        nextInsertionOrder += 1
        return cancellation
    }

    func advance(by interval: TimeInterval) {
        let target = now + interval

        while let nextIndex = scheduledBlocks.indices
            .filter({ scheduledBlocks[$0].deadline <= target })
            .min(by: { lhs, rhs in
                let left = scheduledBlocks[lhs]
                let right = scheduledBlocks[rhs]
                return (left.deadline, left.insertionOrder) < (right.deadline, right.insertionOrder)
            }) {
            let scheduledBlock = scheduledBlocks.remove(at: nextIndex)
            now = scheduledBlock.deadline
            if !scheduledBlock.cancellation.isCancelled {
                scheduledBlock.block()
            }
        }

        now = target
    }
}

private final class ManualHIDPPCancellation: HIDPPCancellation {
    private(set) var isCancelled = false

    func cancel() {
        isCancelled = true
    }
}
