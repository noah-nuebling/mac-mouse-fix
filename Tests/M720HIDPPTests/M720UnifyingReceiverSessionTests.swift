import Foundation
import IOKit
import XCTest
@testable import Mac_Mouse_Fix_Helper

final class M720UnifyingReceiverSessionTests: XCTestCase {
    func testConfirmsM720BeforeJoiningPolicyAndStartingSlotChild() {
        let manager = FakeUnifyingReceiverManager()
        let device = receiverDevice(slot: 1, serial: "9965E67C")
        manager.prepareResults = [.success([device])]
        let harness = SessionHarness(manager: manager)
        let desired: Set<UInt16> = [0x005B, 0x00D0]
        var participationAtCallbacks: [Bool] = []
        harness.session.onStateChange = { _ in
            participationAtCallbacks.append(harness.session.isPolicyParticipant)
        }

        harness.session.setRequiredCIDs(desired)
        XCTAssertFalse(harness.session.isPolicyParticipant)
        harness.session.start()

        let child = try! XCTUnwrap(harness.children.single)
        XCTAssertTrue(harness.session.isPolicyParticipant)
        XCTAssertEqual(harness.receiverDevice.name(), "M720 Triathlon")
        XCTAssertEqual(harness.receiverDevice.nOfButtons(), 8)
        XCTAssertEqual(harness.factoryDevices, [device])
        XCTAssertTrue(harness.factoryTransports.single === manager.transports[1])
        XCTAssertEqual(child.requiredCIDCalls, [desired])
        XCTAssertEqual(child.startCallCount, 1)
        XCTAssertEqual(manager.requestConnectionSnapshotCallCount, 1)
        XCTAssertEqual(participationAtCallbacks, [true])
    }

    func testReceiverWithoutM720NeverJoinsPolicyButKeepsLinkMonitoring() {
        let manager = FakeUnifyingReceiverManager()
        manager.prepareResults = [.success([])]
        let harness = SessionHarness(manager: manager)
        var callbacks = 0
        harness.session.onStateChange = { _ in callbacks += 1 }

        harness.session.start()

        XCTAssertFalse(harness.session.isPolicyParticipant)
        XCTAssertEqual(harness.receiverDevice.nOfButtons(), 0)
        XCTAssertTrue(harness.children.isEmpty)
        XCTAssertEqual(manager.requestConnectionSnapshotCallCount, 1)
        XCTAssertEqual(callbacks, 0)
    }

    func testTwoM720SlotsFanOutPolicyAndBecomeActiveOnlyTogether() {
        let manager = FakeUnifyingReceiverManager()
        manager.prepareResults = [.success([
            receiverDevice(slot: 1, serial: "11111111"),
            receiverDevice(slot: 4, serial: "44444444"),
        ])]
        let harness = SessionHarness(manager: manager)

        harness.session.start()
        harness.session.setRequiredCIDs([0x005B])

        XCTAssertEqual(harness.children.count, 2)
        XCTAssertEqual(harness.children.map(\.requiredCIDs), [[0x005B], [0x005B]])
        harness.children[0].emit(.active)
        XCTAssertEqual(harness.session.state, .discovering)
        harness.children[1].emit(.active)
        XCTAssertEqual(harness.session.state, .active)
    }

    func testOfflineRemovesChildAndOnlineRescanRecreatesIt() {
        let manager = FakeUnifyingReceiverManager()
        let device = receiverDevice(slot: 1, serial: "9965E67C")
        manager.prepareResults = [
            .success([device]),
            .success([device]),
        ]
        let harness = SessionHarness(manager: manager)
        var participantHistory: [Bool] = []
        harness.session.onStateChange = { _ in
            participantHistory.append(harness.session.isPolicyParticipant)
        }
        harness.session.start()
        let first = try! XCTUnwrap(harness.children.single)

        manager.emit(.linkChanged(
            slot: 1,
            wirelessProductID: M720Profile.unifyingWirelessProductID,
            online: false
        ))

        XCTAssertEqual(first.invalidateCallCount, 1)
        first.completeInvalidation()
        XCTAssertFalse(harness.session.isPolicyParticipant)
        XCTAssertEqual(harness.receiverDevice.nOfButtons(), 0)

        manager.emit(.linkChanged(
            slot: 1,
            wirelessProductID: M720Profile.unifyingWirelessProductID,
            online: true
        ))

        XCTAssertEqual(manager.prepareCallCount, 2)
        XCTAssertEqual(harness.children.count, 2)
        XCTAssertTrue(harness.session.isPolicyParticipant)
        XCTAssertEqual(harness.receiverDevice.nOfButtons(), 8)
        XCTAssertEqual(participantHistory, [true, false, true])
    }

    func testOnlineDuringOfflineRestorationIsRescannedAfterRemovalCompletes() {
        let manager = FakeUnifyingReceiverManager()
        let device = receiverDevice(slot: 1, serial: "9965E67C")
        manager.prepareResults = [.success([device]), .success([device])]
        let harness = SessionHarness(manager: manager)
        harness.session.start()
        let first = try! XCTUnwrap(harness.children.single)

        manager.emit(.linkChanged(
            slot: 1,
            wirelessProductID: M720Profile.unifyingWirelessProductID,
            online: false
        ))
        manager.emit(.linkChanged(
            slot: 1,
            wirelessProductID: M720Profile.unifyingWirelessProductID,
            online: true
        ))

        XCTAssertEqual(manager.prepareCallCount, 1)
        first.completeInvalidation()
        XCTAssertEqual(manager.prepareCallCount, 2)
        XCTAssertEqual(harness.children.count, 2)
        XCTAssertTrue(harness.session.isPolicyParticipant)
    }

    func testShutdownDrainsChildrenBeforeRestoringAndClosingReceiver() {
        let manager = FakeUnifyingReceiverManager()
        manager.prepareResults = [.success([
            receiverDevice(slot: 1, serial: "9965E67C"),
        ])]
        manager.autoCompleteInvalidation = false
        let harness = SessionHarness(manager: manager)
        harness.session.start()
        let child = try! XCTUnwrap(harness.children.single)
        var completionCount = 0

        harness.session.shutdown { completionCount += 1 }

        XCTAssertEqual(child.shutdownCallCount, 1)
        XCTAssertEqual(manager.invalidateCallCount, 0)
        XCTAssertEqual(completionCount, 0)

        child.completeShutdown()

        XCTAssertEqual(manager.invalidateCallCount, 1)
        XCTAssertEqual(completionCount, 0)
        manager.completeInvalidation()
        XCTAssertEqual(completionCount, 1)
        XCTAssertEqual(harness.receiverDevice.nOfButtons(), 0)
    }

    func testRemovalDrainsChildrenAndFencesLateOnlineNotification() {
        let manager = FakeUnifyingReceiverManager()
        let device = receiverDevice(slot: 1, serial: "9965E67C")
        manager.prepareResults = [.success([device]), .success([device])]
        let harness = SessionHarness(manager: manager)
        harness.session.start()
        let child = try! XCTUnwrap(harness.children.single)
        var completed = false

        harness.session.invalidateForRemoval { completed = true }
        manager.emit(.linkChanged(
            slot: 1,
            wirelessProductID: M720Profile.unifyingWirelessProductID,
            online: true
        ))
        child.completeInvalidation()

        XCTAssertTrue(completed)
        XCTAssertEqual(manager.prepareCallCount, 1)
        XCTAssertEqual(manager.invalidateCallCount, 1)
        XCTAssertEqual(harness.children.count, 1)
    }

    private func receiverDevice(
        slot: UInt8,
        serial: String
    ) -> M720UnifyingReceiverDevice {
        M720UnifyingReceiverDevice(
            slot: slot,
            wirelessProductID: M720Profile.unifyingWirelessProductID,
            serialNumber: serial
        )
    }
}

private final class SessionHarness {
    private let recorder: ReceiverChildRecorder
    var children: [FakeReceiverChildSession] { recorder.children }
    var factoryDevices: [M720UnifyingReceiverDevice] { recorder.devices }
    var factoryTransports: [HIDPPTransport] { recorder.transports }
    let receiverDevice: Device
    let session: M720UnifyingReceiverSession

    init(manager: FakeUnifyingReceiverManager) {
        let recorder = ReceiverChildRecorder()
        let receiverDevice = Device.unitTestDevice()
        self.recorder = recorder
        self.receiverDevice = receiverDevice
        session = M720UnifyingReceiverSession(
            receiverDevice: receiverDevice,
            manager: manager,
            childFactory: { device, transport in
                let child = FakeReceiverChildSession()
                recorder.devices.append(device)
                recorder.transports.append(transport)
                recorder.children.append(child)
                return child
            }
        )
    }
}

private final class ReceiverChildRecorder {
    var children: [FakeReceiverChildSession] = []
    var devices: [M720UnifyingReceiverDevice] = []
    var transports: [HIDPPTransport] = []
}

private final class FakeUnifyingReceiverManager: UnifyingReceiverManaging {
    var onLinkEvent: ((UnifyingReceiverLinkEvent) -> Void)?
    var prepareResults: [Result<[M720UnifyingReceiverDevice], UnifyingReceiverManagerError>] = []
    var autoCompleteInvalidation = true
    private(set) var prepareCallCount = 0
    private(set) var requestConnectionSnapshotCallCount = 0
    private(set) var invalidateCallCount = 0
    private(set) var transports: [UInt8: FakeReceiverSlotTransport] = [:]
    private var invalidationCompletions: [() -> Void] = []

    func prepare(
        completion: @escaping (
            Result<[M720UnifyingReceiverDevice], UnifyingReceiverManagerError>
        ) -> Void
    ) {
        prepareCallCount += 1
        let result = prepareResults.isEmpty ? .success([]) : prepareResults.removeFirst()
        completion(result)
    }

    func makeSlotTransport(slot: UInt8) -> HIDPPTransport? {
        let transport = FakeReceiverSlotTransport(slot: slot)
        transports[slot] = transport
        return transport
    }

    func requestConnectionSnapshot(
        completion: @escaping (Result<Void, UnifyingReceiverManagerError>) -> Void
    ) {
        requestConnectionSnapshotCallCount += 1
        completion(.success(()))
    }

    func invalidate(completion: @escaping () -> Void) {
        invalidateCallCount += 1
        if autoCompleteInvalidation {
            completion()
        } else {
            invalidationCompletions.append(completion)
        }
    }

    func completeInvalidation() {
        let completions = invalidationCompletions
        invalidationCompletions.removeAll()
        completions.forEach { $0() }
    }

    func emit(_ event: UnifyingReceiverLinkEvent) {
        onLinkEvent?(event)
    }
}

private final class FakeReceiverSlotTransport: HIDPPTransport {
    let deviceIndex: UInt8
    let acceptedResponseDeviceIndices: Set<UInt8>
    var onReport: ((Data) -> Void)?

    init(slot: UInt8) {
        deviceIndex = slot
        acceptedResponseDeviceIndices = [slot]
    }

    func send(_ report: Data, completion: @escaping (IOReturn) -> Void) {
        completion(kIOReturnSuccess)
    }

    func invalidate(completion: @escaping () -> Void) {
        onReport = nil
        completion()
    }
}

private final class FakeReceiverChildSession: M720SessionControlling {
    private(set) var state: M720SessionState = .discovering
    private(set) var requiredCIDs: Set<UInt16> = []
    let isPolicyParticipant = true
    var onStateChange: ((M720SessionState) -> Void)?

    private(set) var requiredCIDCalls: [Set<UInt16>] = []
    private(set) var startCallCount = 0
    private(set) var shutdownCallCount = 0
    private(set) var invalidateCallCount = 0
    private var shutdownCompletions: [() -> Void] = []
    private var invalidationCompletions: [() -> Void] = []

    func start() { startCallCount += 1 }

    func setRequiredCIDs(_ cids: Set<UInt16>) {
        requiredCIDs = cids
        requiredCIDCalls.append(cids)
    }

    func markJournalIdentityUnusable() {}
    func prepareForSleep(completion: @escaping () -> Void) { completion() }
    func reconcileAfterWake() {}
    func knownOwnershipAgentDidLaunch() {}

    func shutdown(completion: @escaping () -> Void) {
        shutdownCallCount += 1
        shutdownCompletions.append(completion)
    }

    func shutdownDeadlineReached() {}

    func invalidateForRemoval(completion: @escaping () -> Void) {
        invalidateCallCount += 1
        invalidationCompletions.append(completion)
    }

    func retryAfterConflict(requestID _: UUID?) -> Bool { false }

    func emit(_ state: M720SessionState) {
        self.state = state
        onStateChange?(state)
    }

    func completeShutdown() {
        let completions = shutdownCompletions
        shutdownCompletions.removeAll()
        completions.forEach { $0() }
    }

    func completeInvalidation() {
        let completions = invalidationCompletions
        invalidationCompletions.removeAll()
        completions.forEach { $0() }
    }
}

private extension Array {
    var single: Element? { count == 1 ? self[0] : nil }
}
