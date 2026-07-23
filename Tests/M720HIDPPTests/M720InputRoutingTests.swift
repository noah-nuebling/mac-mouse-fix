import XCTest
@testable import Mac_Mouse_Fix_Helper

final class M720InputRoutingTests: XCTestCase {
    func testAdversarialSchedulerOrdersDeadlineChainByQuantizedNanoseconds() {
        let scheduler = AdversarialScheduler()
        let nanosecond = 0.000_000_001
        var executionOrder: [String] = []

        _ = scheduler.schedule(after: 1.5 * nanosecond) { executionOrder.append("C") }
        _ = scheduler.schedule(after: 0.75 * nanosecond) { executionOrder.append("B") }
        _ = scheduler.schedule(after: 0) { executionOrder.append("A") }

        scheduler.runNext()
        scheduler.runNext()
        scheduler.runNext()

        XCTAssertEqual(executionOrder, ["A", "B", "C"])
    }

    func testUseButtonModifiersSetterWaitsForButtonsQueue() {
        let queueOccupied = DispatchSemaphore(value: 0)
        let releaseQueue = DispatchSemaphore(value: 0)
        let setterStarted = DispatchSemaphore(value: 0)
        let setterReturned = DispatchSemaphore(value: 0)
        let setterQueue = DispatchQueue(label: "M720InputRoutingTests.setter")

        Buttons.useButtonModifiers = false
        Buttons.queue.async {
            queueOccupied.signal()
            _ = releaseQueue.wait(timeout: .now() + 2)
        }
        XCTAssertEqual(queueOccupied.wait(timeout: .now() + 2), .success)

        setterQueue.async {
            setterStarted.signal()
            Buttons.useButtonModifiers = true
            setterReturned.signal()
        }
        XCTAssertEqual(setterStarted.wait(timeout: .now() + 2), .success)
        let setterReturnedEarly = setterReturned.wait(timeout: .now() + 0.1)
        XCTAssertEqual(setterReturnedEarly, .timedOut)

        releaseQueue.signal()
        if setterReturnedEarly == .timedOut {
            XCTAssertEqual(setterReturned.wait(timeout: .now() + 2), .success)
        }
        XCTAssertTrue(Buttons.useButtonModifiers)
        Buttons.useButtonModifiers = false
    }

    func testSameButtonOnTwoDevicesUsesDifferentCleanupKeys() {
        let first = Device.unitTestDevice()
        let second = Device.unitTestDevice()

        XCTAssertNotEqual(
            ButtonInputKey(device: first, button: 6),
            ButtonInputKey(device: second, button: 6)
        )
    }

    func testButtonInputContextDefensivelyCopiesModifiers() {
        let mutableModifiers = NSMutableDictionary(dictionary: ["marker": "down"])
        let context = ButtonInputContext(
            device: Device.unitTestDevice(),
            button: 6,
            downNotUp: true,
            modifiers: mutableModifiers,
            source: .hidpp,
            systemEvent: nil
        )

        mutableModifiers["marker"] = "changed"

        XCTAssertEqual(context.modifiers["marker"] as? String, "down")
    }

    func testSameButtonOnTwoDevicesDoesNotCrossReleaseCallbacks() {
        let scheduler = AdversarialScheduler()
        let cycle = makeCycle(scheduler: scheduler)
        let first = Device.unitTestDevice()
        let second = Device.unitTestDevice()
        let firstIdentity = ObjectIdentifier(first)
        var firstCleanupCount = 0
        var secondCleanupCount = 0

        let trigger: ClickCycleTriggerCallback = { phase, _, device, _, releaseCallbacks in
            guard phase == .press else { return }
            if ObjectIdentifier(device) == firstIdentity {
                releaseCallbacks.append { firstCleanupCount += 1 }
            } else {
                releaseCallbacks.append { secondCleanupCount += 1 }
            }
        }

        send(cycle, device: first, downNotUp: true, trigger: trigger)
        send(cycle, device: second, downNotUp: true, trigger: trigger)
        send(cycle, device: first, downNotUp: false, trigger: trigger)

        XCTAssertEqual(firstCleanupCount, 1)
        XCTAssertEqual(secondCleanupCount, 0)
        XCTAssertFalse(cycle.waitingForRelease(device: first, button: 6))
        XCTAssertTrue(cycle.waitingForRelease(device: second, button: 6))
        XCTAssertTrue(cycle.isActiveFor(device: second, button: 6))

        send(cycle, device: second, downNotUp: false, trigger: trigger)

        XCTAssertEqual(firstCleanupCount, 1)
        XCTAssertEqual(secondCleanupCount, 1)
    }

    func testNormalAndDuplicateUpDrainCleanupExactlyOnce() {
        let scheduler = AdversarialScheduler()
        let cycle = makeCycle(scheduler: scheduler)
        let device = Device.unitTestDevice()
        var cleanupCount = 0
        var wasRemovedBeforeCleanup = false
        var phases: [ClickCycleTriggerPhase] = []

        let trigger: ClickCycleTriggerCallback = { phase, _, _, _, releaseCallbacks in
            phases.append(phase)
            if phase == .press {
                releaseCallbacks.append {
                    wasRemovedBeforeCleanup = !cycle.waitingForRelease(device: device, button: 6)
                    cleanupCount += 1
                }
            }
        }

        send(cycle, device: device, downNotUp: true, trigger: trigger)
        send(cycle, device: device, downNotUp: false, trigger: trigger)
        send(cycle, device: device, downNotUp: false, trigger: trigger)

        XCTAssertEqual(cleanupCount, 1)
        XCTAssertTrue(wasRemovedBeforeCleanup)
        XCTAssertEqual(phases, [.press, .release])
    }

    func testOrdinaryKillRetainsCleanupForRealUp() {
        let scheduler = AdversarialScheduler()
        let cycle = makeCycle(scheduler: scheduler)
        let device = Device.unitTestDevice()
        var cleanupCount = 0

        let trigger: ClickCycleTriggerCallback = { phase, _, _, _, releaseCallbacks in
            if phase == .press {
                releaseCallbacks.append { cleanupCount += 1 }
            }
        }

        send(cycle, device: device, downNotUp: true, trigger: trigger)
        cycle.kill()

        XCTAssertTrue(cycle.waitingForRelease(device: device, button: 6))
        send(cycle, device: device, downNotUp: false, trigger: trigger)

        XCTAssertEqual(cleanupCount, 1)
        XCTAssertFalse(cycle.waitingForRelease(device: device, button: 6))
    }

    func testCancelDrainsCleanupAndRealUpDoesNotDrainAgain() {
        let scheduler = AdversarialScheduler()
        let cycle = makeCycle(scheduler: scheduler)
        let device = Device.unitTestDevice()
        let key = ButtonInputKey(device: device, button: 6)
        var cleanupCount = 0

        let trigger: ClickCycleTriggerCallback = { phase, _, _, _, releaseCallbacks in
            if phase == .press {
                releaseCallbacks.append { cleanupCount += 1 }
            }
        }

        send(cycle, device: device, downNotUp: true, trigger: trigger)
        cycle.cancel(key: key)
        send(cycle, device: device, downNotUp: false, trigger: trigger)

        XCTAssertEqual(cleanupCount, 1)
        XCTAssertFalse(cycle.waitingForRelease(device: device, button: 6))
    }

    func testCancelledHoldAndExpiryAfterUpAreIndividuallyStaleBeforeLegalExpiry() throws {
        let scheduler = AdversarialScheduler()
        let cycle = makeCycle(scheduler: scheduler)
        let device = Device.unitTestDevice()
        var phases: [ClickCycleTriggerPhase] = []
        var delayedCleanupCount = 0

        let trigger: ClickCycleTriggerCallback = { phase, _, _, _, releaseCallbacks in
            phases.append(phase)
            if phase == .hold {
                releaseCallbacks.append { delayedCleanupCount += 1 }
            }
        }

        send(cycle, device: device, downNotUp: true, trigger: trigger)
        scheduler.moveClock(to: 0.25)
        send(cycle, device: device, downNotUp: false, trigger: trigger)

        XCTAssertEqual(
            try XCTUnwrap(scheduler.runNext(executingCancelled: true)),
            0.25,
            accuracy: 0.000_001
        )
        XCTAssertEqual(phases, [.press, .release])
        XCTAssertTrue(cycle.isActiveFor(device: device, button: 6))

        XCTAssertEqual(
            try XCTUnwrap(scheduler.runNext(executingCancelled: true)),
            0.26,
            accuracy: 0.000_001
        )
        XCTAssertEqual(phases, [.press, .release])
        XCTAssertTrue(cycle.isActiveFor(device: device, button: 6))

        XCTAssertEqual(
            try XCTUnwrap(scheduler.runNext(executingCancelled: true)),
            0.26,
            accuracy: 0.000_001
        )
        XCTAssertEqual(phases, [.press, .release, .levelExpired])
        XCTAssertFalse(cycle.isActiveFor(device: device, button: 6))

        send(cycle, device: device, downNotUp: false, trigger: trigger)

        XCTAssertEqual(phases, [.press, .release, .levelExpired])
        XCTAssertEqual(delayedCleanupCount, 0)
    }

    func testSameKeySubsequentDownInvalidatesEveryOldExpiryAndUsesNewDeadline() throws {
        let scheduler = AdversarialScheduler()
        let cycle = makeCycle(scheduler: scheduler)
        let device = Device.unitTestDevice()
        var phases: [ClickCycleTriggerPhase] = []

        let trigger: ClickCycleTriggerCallback = { phase, _, _, _, _ in
            phases.append(phase)
        }

        send(cycle, device: device, downNotUp: true, trigger: trigger)
        scheduler.moveClock(to: 0.10)
        send(cycle, device: device, downNotUp: false, trigger: trigger)
        scheduler.moveClock(to: 0.20)
        send(cycle, device: device, downNotUp: true, trigger: trigger)
        scheduler.moveClock(to: 0.21)
        send(cycle, device: device, downNotUp: false, trigger: trigger)

        let phasesBeforeTimers: [ClickCycleTriggerPhase] = [
            .press,
            .release,
            .press,
            .release,
        ]
        XCTAssertEqual(phases, phasesBeforeTimers)

        for oldDeadline in [0.25, 0.26, 0.26, 0.45, 0.46] {
            XCTAssertEqual(
                try XCTUnwrap(scheduler.runNext(executingCancelled: true)),
                oldDeadline,
                accuracy: 0.000_001
            )
            XCTAssertEqual(phases, phasesBeforeTimers)
            XCTAssertTrue(cycle.isActiveFor(device: device, button: 6))
        }

        XCTAssertEqual(
            try XCTUnwrap(scheduler.runNext(executingCancelled: true)),
            0.46,
            accuracy: 0.000_001
        )
        XCTAssertEqual(phases, phasesBeforeTimers + [.levelExpired])
        XCTAssertFalse(cycle.isActiveFor(device: device, button: 6))
    }

    func testCancelledHoldAndExpiryAfterReplacementCannotTriggerOrAppendCleanup() {
        let scheduler = AdversarialScheduler()
        let cycle = makeCycle(scheduler: scheduler)
        let first = Device.unitTestDevice()
        let second = Device.unitTestDevice()
        let firstIdentity = ObjectIdentifier(first)
        var firstPhases: [ClickCycleTriggerPhase] = []
        var firstDelayedCleanupCount = 0

        let trigger: ClickCycleTriggerCallback = { phase, _, device, _, releaseCallbacks in
            guard ObjectIdentifier(device) == firstIdentity else { return }
            firstPhases.append(phase)
            if phase == .hold {
                releaseCallbacks.append { firstDelayedCleanupCount += 1 }
            }
        }

        send(cycle, device: first, downNotUp: true, trigger: trigger)
        scheduler.moveClock(to: 0.25)
        send(cycle, device: second, downNotUp: true, trigger: trigger)
        scheduler.advance(to: 0.26, executingCancelled: true)
        send(cycle, device: first, downNotUp: false, trigger: trigger)

        XCTAssertEqual(firstPhases, [.press])
        XCTAssertEqual(firstDelayedCleanupCount, 0)
    }

    func testCancelledHoldAndExpiryAfterOrdinaryKillCannotTriggerOrAppendCleanup() {
        let scheduler = AdversarialScheduler()
        let cycle = makeCycle(scheduler: scheduler)
        let device = Device.unitTestDevice()
        var phases: [ClickCycleTriggerPhase] = []
        var delayedCleanupCount = 0

        let trigger: ClickCycleTriggerCallback = { phase, _, _, _, releaseCallbacks in
            phases.append(phase)
            if phase == .hold {
                releaseCallbacks.append { delayedCleanupCount += 1 }
            }
        }

        send(cycle, device: device, downNotUp: true, trigger: trigger)
        scheduler.moveClock(to: 0.25)
        cycle.kill()
        scheduler.advance(to: 0.26, executingCancelled: true)
        send(cycle, device: device, downNotUp: false, trigger: trigger)

        XCTAssertEqual(phases, [.press])
        XCTAssertEqual(delayedCleanupCount, 0)
    }

    func testCancelledHoldAndExpiryAfterCancelCannotFirePendingAction() {
        let scheduler = AdversarialScheduler()
        let cycle = makeCycle(scheduler: scheduler)
        let device = Device.unitTestDevice()
        let key = ButtonInputKey(device: device, button: 6)
        var phases: [ClickCycleTriggerPhase] = []
        var delayedCleanupCount = 0

        let trigger: ClickCycleTriggerCallback = { phase, _, _, _, releaseCallbacks in
            phases.append(phase)
            if phase == .hold {
                releaseCallbacks.append { delayedCleanupCount += 1 }
            }
        }

        send(cycle, device: device, downNotUp: true, trigger: trigger)
        scheduler.moveClock(to: 0.25)
        cycle.cancel(key: key)
        scheduler.advance(to: 0.26, executingCancelled: true)

        XCTAssertEqual(phases, [.press])
        XCTAssertEqual(delayedCleanupCount, 0)
    }

    func testValidHoldMayKillItselfAndStillRegisterCleanup() {
        let scheduler = AdversarialScheduler()
        let cycle = makeCycle(scheduler: scheduler)
        let device = Device.unitTestDevice()
        var cleanupCount = 0

        let trigger: ClickCycleTriggerCallback = { phase, _, _, _, releaseCallbacks in
            guard phase == .hold else { return }
            cycle.kill()
            releaseCallbacks.append { cleanupCount += 1 }
        }

        send(cycle, device: device, downNotUp: true, trigger: trigger)
        scheduler.advance(to: 0.25)

        XCTAssertFalse(cycle.isActiveFor(device: device, button: 6))
        XCTAssertTrue(cycle.waitingForRelease(device: device, button: 6))

        send(cycle, device: device, downNotUp: false, trigger: trigger)

        XCTAssertEqual(cleanupCount, 1)
    }

    func testUpReschedulesExpiryForOriginalDownDeadline() {
        let scheduler = AdversarialScheduler()
        let cycle = makeCycle(scheduler: scheduler)
        let device = Device.unitTestDevice()
        var expiryTimes: [TimeInterval] = []

        let trigger: ClickCycleTriggerCallback = { phase, _, _, _, _ in
            if phase == .levelExpired {
                expiryTimes.append(scheduler.now)
            }
        }

        send(cycle, device: device, downNotUp: true, trigger: trigger)
        scheduler.advance(to: 0.10)
        send(cycle, device: device, downNotUp: false, trigger: trigger)

        XCTAssertEqual(scheduler.pendingDeadlines, [0.26])

        scheduler.advance(to: 0.259)
        XCTAssertTrue(expiryTimes.isEmpty)

        scheduler.advance(to: 0.26)
        XCTAssertEqual(expiryTimes.count, 1)
        XCTAssertEqual(expiryTimes[0], 0.26, accuracy: 0.000_001)
    }

    func testCapturedDownUsesItsSnapshotForMatchingUp() {
        let scheduler = AdversarialScheduler()
        Buttons.unitTestReset(scheduler: scheduler)
        let device = Device.unitTestDevice()
        var downSnapshotPhases: [ClickCycleTriggerPhase] = []
        var replacementSnapshotPhases: [ClickCycleTriggerPhase] = []
        let downTrigger: ClickCycleTriggerCallback = { phase, _, _, _, _ in
            downSnapshotPhases.append(phase)
        }
        let replacementTrigger: ClickCycleTriggerCallback = { phase, _, _, _, _ in
            replacementSnapshotPhases.append(phase)
        }

        _ = Buttons.unitTestHandleResolved(
            context(device: device, downNotUp: true, source: .coreGraphics),
            maxClickLevel: 1,
            triggerCallback: downTrigger
        )
        _ = Buttons.unitTestHandleResolved(
            context(device: device, downNotUp: false, source: .coreGraphics),
            maxClickLevel: 0,
            triggerCallback: replacementTrigger
        )

        XCTAssertEqual(downSnapshotPhases, [.press, .release])
        XCTAssertTrue(replacementSnapshotPhases.isEmpty)
    }

    func testCapturedAThenUnconfiguredBUpFirstKeepsIndependentPassThroughAndCleanup() {
        assertCapturedAndUnconfiguredInterleaving(releaseUnconfiguredFirst: true)
    }

    func testCapturedAThenUnconfiguredBUpLastKeepsIndependentPassThroughAndCleanup() {
        assertCapturedAndUnconfiguredInterleaving(releaseUnconfiguredFirst: false)
    }

    func testUnconfiguredBDownBeforeCapturedADoesNotGetSwallowed() {
        let scheduler = AdversarialScheduler()
        Buttons.unitTestReset(scheduler: scheduler)
        let captured = Device.unitTestDevice()
        let unconfigured = Device.unitTestDevice()
        var cleanupCount = 0
        let trigger: ClickCycleTriggerCallback = { phase, _, _, _, releaseCallbacks in
            if phase == .press {
                releaseCallbacks.append { cleanupCount += 1 }
            }
        }

        let unconfiguredDown = Buttons.unitTestHandleResolved(
            context(device: unconfigured, downNotUp: true, source: .coreGraphics),
            maxClickLevel: 0,
            triggerCallback: { _, _, _, _, _ in XCTFail("Unconfigured input must not trigger") }
        )
        let capturedDown = Buttons.unitTestHandleResolved(
            context(device: captured, downNotUp: true, source: .coreGraphics),
            maxClickLevel: 1,
            triggerCallback: trigger
        )
        let capturedUp = Buttons.unitTestHandleResolved(
            context(device: captured, downNotUp: false, source: .coreGraphics),
            maxClickLevel: 0,
            triggerCallback: { _, _, _, _, _ in XCTFail("Up must use captured snapshot") }
        )
        let unconfiguredUp = Buttons.unitTestHandleResolved(
            context(device: unconfigured, downNotUp: false, source: .coreGraphics),
            maxClickLevel: 0,
            triggerCallback: { _, _, _, _, _ in XCTFail("Unconfigured input must not trigger") }
        )

        XCTAssertEqual(unconfiguredDown, kMFEventPassThroughApproval)
        XCTAssertEqual(unconfiguredUp, kMFEventPassThroughApproval)
        XCTAssertEqual(capturedDown, kMFEventPassThroughRefusal)
        XCTAssertEqual(capturedUp, kMFEventPassThroughRefusal)
        XCTAssertEqual(cleanupCount, 1)
    }

    func testUnconfiguredHIDPPInputHasNoEventAndNeverRequestsCGPassThrough() {
        let scheduler = AdversarialScheduler()
        Buttons.unitTestReset(scheduler: scheduler)
        let input = context(
            device: Device.unitTestDevice(),
            downNotUp: true,
            source: .hidpp
        )

        let result = Buttons.unitTestHandleResolved(
            input,
            maxClickLevel: 0,
            triggerCallback: { _, _, _, _, _ in XCTFail("Unconfigured input must not trigger") }
        )

        XCTAssertNil(input.systemEvent)
        XCTAssertEqual(result, kMFEventPassThroughRefusal)
    }

    func testCancelInputRunsCleanupBeforeCompletionOnButtonsQueue() {
        let scheduler = AdversarialScheduler()
        Buttons.unitTestReset(scheduler: scheduler)
        let device = Device.unitTestDevice()
        let queueMarker = DispatchSpecificKey<Bool>()
        Buttons.queue.setSpecific(key: queueMarker, value: true)
        var order: [String] = []
        var completionWasOnQueue = false

        _ = Buttons.unitTestHandleResolved(
            context(device: device, downNotUp: true, source: .hidpp),
            maxClickLevel: 1,
            triggerCallback: { phase, _, _, _, releaseCallbacks in
                if phase == .press {
                    releaseCallbacks.append { order.append("cleanup") }
                }
            }
        )

        Buttons.cancelInput(device: device, button: 6) {
            completionWasOnQueue = DispatchQueue.getSpecific(key: queueMarker) == true
            order.append("completion")
        }
        Buttons.queue.setSpecific(key: queueMarker, value: nil)

        XCTAssertEqual(order, ["cleanup", "completion"])
        XCTAssertTrue(completionWasOnQueue)
    }

    func testButtonsCancelRemovesCapturedLedgerSoRealCGUpPassesThrough() {
        let scheduler = AdversarialScheduler()
        Buttons.unitTestReset(scheduler: scheduler)
        let device = Device.unitTestDevice()
        var cleanupCount = 0

        _ = Buttons.unitTestHandleResolved(
            context(device: device, downNotUp: true, source: .coreGraphics),
            maxClickLevel: 1,
            triggerCallback: { phase, _, _, _, releaseCallbacks in
                if phase == .press {
                    releaseCallbacks.append { cleanupCount += 1 }
                }
            }
        )
        Buttons.cancelInput(device: device, button: 6) {}

        let realUp = Buttons.unitTestHandleResolved(
            context(device: device, downNotUp: false, source: .coreGraphics),
            maxClickLevel: 0,
            triggerCallback: { _, _, _, _, _ in XCTFail("Cancelled up must not trigger") }
        )

        XCTAssertEqual(cleanupCount, 1)
        XCTAssertEqual(realUp, kMFEventPassThroughApproval)
    }

    private func assertCapturedAndUnconfiguredInterleaving(releaseUnconfiguredFirst: Bool) {
        let scheduler = AdversarialScheduler()
        Buttons.unitTestReset(scheduler: scheduler)
        let captured = Device.unitTestDevice()
        let unconfigured = Device.unitTestDevice()
        var cleanupCount = 0
        var capturedPhases: [ClickCycleTriggerPhase] = []
        let trigger: ClickCycleTriggerCallback = { phase, _, _, _, releaseCallbacks in
            capturedPhases.append(phase)
            if phase == .press {
                releaseCallbacks.append { cleanupCount += 1 }
            }
        }

        let capturedDown = Buttons.unitTestHandleResolved(
            context(device: captured, downNotUp: true, source: .coreGraphics),
            maxClickLevel: 1,
            triggerCallback: trigger
        )
        let unconfiguredDown = Buttons.unitTestHandleResolved(
            context(device: unconfigured, downNotUp: true, source: .coreGraphics),
            maxClickLevel: 0,
            triggerCallback: { _, _, _, _, _ in XCTFail("Unconfigured input must not trigger") }
        )

        let capturedUp: MFEventPassThroughEvaluation
        let unconfiguredUp: MFEventPassThroughEvaluation
        if releaseUnconfiguredFirst {
            unconfiguredUp = Buttons.unitTestHandleResolved(
                context(device: unconfigured, downNotUp: false, source: .coreGraphics),
                maxClickLevel: 0,
                triggerCallback: { _, _, _, _, _ in XCTFail("Unconfigured input must not trigger") }
            )
            capturedUp = Buttons.unitTestHandleResolved(
                context(device: captured, downNotUp: false, source: .coreGraphics),
                maxClickLevel: 0,
                triggerCallback: { _, _, _, _, _ in XCTFail("Up must use captured snapshot") }
            )
        } else {
            capturedUp = Buttons.unitTestHandleResolved(
                context(device: captured, downNotUp: false, source: .coreGraphics),
                maxClickLevel: 0,
                triggerCallback: { _, _, _, _, _ in XCTFail("Up must use captured snapshot") }
            )
            unconfiguredUp = Buttons.unitTestHandleResolved(
                context(device: unconfigured, downNotUp: false, source: .coreGraphics),
                maxClickLevel: 0,
                triggerCallback: { _, _, _, _, _ in XCTFail("Unconfigured input must not trigger") }
            )
        }

        XCTAssertEqual(capturedDown, kMFEventPassThroughRefusal)
        XCTAssertEqual(capturedUp, kMFEventPassThroughRefusal)
        XCTAssertEqual(unconfiguredDown, kMFEventPassThroughApproval)
        XCTAssertEqual(unconfiguredUp, kMFEventPassThroughApproval)
        XCTAssertEqual(capturedPhases, [.press, .release])
        XCTAssertEqual(cleanupCount, 1)
    }

    private func makeCycle(scheduler: HIDPPScheduler) -> ClickCycle {
        ClickCycle(
            buttonQueue: DispatchQueue(label: "M720InputRoutingTests.ClickCycle"),
            scheduler: scheduler
        )
    }

    private func send(
        _ cycle: ClickCycle,
        device: Device,
        downNotUp: Bool,
        trigger: @escaping ClickCycleTriggerCallback
    ) {
        cycle.handleClick(
            device: device,
            button: 6,
            downNotUp: downNotUp,
            maxClickLevel: 2,
            triggerCallback: trigger
        )
    }

    private func context(
        device: Device,
        downNotUp: Bool,
        source: ButtonInputSource
    ) -> ButtonInputContext {
        ButtonInputContext(
            device: device,
            button: 6,
            downNotUp: downNotUp,
            modifiers: NSDictionary(dictionary: ["marker": "snapshot"]),
            source: source,
            systemEvent: source == .coreGraphics ? CGEvent(source: nil) : nil
        )
    }
}

private final class AdversarialScheduler: HIDPPScheduler {
    private struct ScheduledBlock {
        let deadline: TimeInterval
        let insertionOrder: Int
        let cancellation: AdversarialCancellation
        let block: () -> Void
    }

    private var scheduledBlocks: [ScheduledBlock] = []
    private var nextInsertionOrder = 0
    private(set) var now: TimeInterval = 0

    var pendingDeadlines: [TimeInterval] {
        scheduledBlocks
            .filter { !$0.cancellation.isCancelled }
            .sorted(by: comesBefore)
            .map(\.deadline)
    }

    @discardableResult
    func schedule(
        after delay: TimeInterval,
        _ block: @escaping () -> Void
    ) -> HIDPPCancellation {
        precondition(delay >= 0)
        let cancellation = AdversarialCancellation()
        scheduledBlocks.append(ScheduledBlock(
            deadline: now + delay,
            insertionOrder: nextInsertionOrder,
            cancellation: cancellation,
            block: block
        ))
        nextInsertionOrder += 1
        return cancellation
    }

    func moveClock(to target: TimeInterval) {
        precondition(target >= now)
        now = target
    }

    func advance(to target: TimeInterval, executingCancelled: Bool = false) {
        precondition(target >= now)

        while let nextIndex = scheduledBlocks.indices
            .filter({ scheduledBlocks[$0].deadline <= target })
            .min(by: { comesBefore(scheduledBlocks[$0], scheduledBlocks[$1]) }) {
            let scheduledBlock = scheduledBlocks.remove(at: nextIndex)
            now = max(now, scheduledBlock.deadline)
            if executingCancelled || !scheduledBlock.cancellation.isCancelled {
                scheduledBlock.block()
            }
        }

        now = target
    }

    @discardableResult
    func runNext(executingCancelled: Bool = false) -> TimeInterval? {
        guard let nextIndex = scheduledBlocks.indices.min(by: {
            comesBefore(scheduledBlocks[$0], scheduledBlocks[$1])
        }) else {
            return nil
        }

        let scheduledBlock = scheduledBlocks.remove(at: nextIndex)
        now = max(now, scheduledBlock.deadline)
        if executingCancelled || !scheduledBlock.cancellation.isCancelled {
            scheduledBlock.block()
        }
        return scheduledBlock.deadline
    }

    private func comesBefore(_ lhs: ScheduledBlock, _ rhs: ScheduledBlock) -> Bool {
        (deadlineOrderKey(lhs.deadline), lhs.insertionOrder) <
            (deadlineOrderKey(rhs.deadline), rhs.insertionOrder)
    }

    private func deadlineOrderKey(_ deadline: TimeInterval) -> Int64 {
        Int64((deadline * 1_000_000_000).rounded())
    }
}

private final class AdversarialCancellation: HIDPPCancellation {
    private(set) var isCancelled = false

    func cancel() {
        isCancelled = true
    }
}
