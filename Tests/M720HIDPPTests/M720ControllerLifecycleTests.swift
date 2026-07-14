import AppKit
import XCTest
@testable import Mac_Mouse_Fix_Helper

final class M720ControllerLifecycleTests: XCTestCase {
    func testCachedPolicyAndDeviceManagerNotificationPrecedeFactoryAndAsyncStart() {
        let harness = M720ControllerHarness()
        let device = harness.makeDevice(snapshot: .m720(registryEntryID: 101, serialNumber: "attach"))
        let attachedDevices = NSMutableArray()

        harness.controller.reconcile(
            remaps: makeRemaps(triggerButtons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        XCTAssertTrue(harness.factoryCalls.isEmpty)

        DeviceManager.unitTestAttach(
            device: device,
            attachedDevices: attachedDevices,
            notify: { devices in
                XCTAssertEqual(devices.count, 1)
                XCTAssertTrue(devices.first.map { $0 === device } == true)
                harness.trace.append("notify")
            },
            controllerAttach: { attached in
                harness.controller.deviceDidAttach(attached)
            }
        )

        let session = try! XCTUnwrap(harness.session(for: device))
        XCTAssertEqual(
            harness.trace.events,
            ["notify", "snapshot:101", "factory:101:true", "set:005b"]
        )
        XCTAssertEqual(session.startCallCount, 0)
        XCTAssertEqual(harness.executor.pendingCount, 1)

        harness.executor.runAll()

        XCTAssertEqual(session.startCallCount, 1)
        XCTAssertEqual(harness.trace.events.last, "start")
    }

    func testNonM720NilSnapshotAndZeroRegistryNeverCreateSession() {
        let harness = M720ControllerHarness()
        let nonM720 = harness.makeDevice(snapshot: .m720(
            registryEntryID: 201,
            productID: 0xFFFF,
            serialNumber: "other"
        ))
        let nilSnapshot = harness.makeDevice(snapshot: nil)
        let zeroRegistry = harness.makeDevice(snapshot: .m720(
            registryEntryID: 0,
            serialNumber: "zero"
        ))

        harness.controller.deviceDidAttach(nonM720)
        harness.controller.deviceDidAttach(nilSnapshot)
        harness.controller.deviceDidAttach(zeroRegistry)
        harness.executor.runAll()

        XCTAssertTrue(harness.factoryCalls.isEmpty)
        XCTAssertTrue(harness.controller.captureStateSnapshots().isEmpty)

        var completions = 0
        for device in [nonM720, nilSnapshot, zeroRegistry] {
            harness.controller.prepareForDeviceRemoval(device) { completions += 1 }
        }
        XCTAssertEqual(completions, 3)
    }

    func testEmptySerialCreatesGetOnlyDiagnosticSessionWithUnusableJournalIdentity() {
        let harness = M720ControllerHarness()
        let device = harness.makeDevice(snapshot: .m720(
            registryEntryID: 301,
            serialNumber: nil,
            physicalDeviceUniqueID: "diagnostic-only"
        ))
        harness.controller.reconcile(
            remaps: makeRemaps(triggerButtons: [8]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )

        harness.controller.deviceDidAttach(device)
        harness.executor.runAll()

        let call = try! XCTUnwrap(harness.factoryCalls.first)
        XCTAssertFalse(call.journalIdentityUsable)
        XCTAssertEqual(call.snapshot.physicalDeviceUniqueID, "diagnostic-only")
        XCTAssertEqual(call.session.requiredCIDCalls, [[0x00D0]])
        XCTAssertEqual(call.session.startCallCount, 1)
        XCTAssertEqual(call.session.markIdentityUnusableCallCount, 0)
    }

    func testDuplicateCompositeIdentityDowngradesEveryColliderAndPhysicalIDDoesNotDisambiguate() {
        let harness = M720ControllerHarness()
        let first = harness.makeDevice(snapshot: .m720(
            registryEntryID: 401,
            serialNumber: "duplicate",
            physicalDeviceUniqueID: "physical-a"
        ))
        let second = harness.makeDevice(snapshot: .m720(
            registryEntryID: 402,
            serialNumber: "duplicate",
            physicalDeviceUniqueID: "physical-b"
        ))

        harness.controller.deviceDidAttach(first)
        harness.executor.runAll()
        harness.controller.deviceDidAttach(first)
        harness.controller.deviceDidAttach(second)
        harness.executor.runAll()

        XCTAssertEqual(harness.factoryCalls.count, 2)
        XCTAssertTrue(harness.factoryCalls[0].journalIdentityUsable)
        XCTAssertFalse(harness.factoryCalls[1].journalIdentityUsable)
        XCTAssertEqual(harness.factoryCalls[0].session.markIdentityUnusableCallCount, 1)
        XCTAssertEqual(harness.factoryCalls[1].session.markIdentityUnusableCallCount, 0)
        XCTAssertEqual(harness.factoryCalls[0].session.startCallCount, 1)
        XCTAssertEqual(harness.factoryCalls[1].session.startCallCount, 1)
    }

    func testRemovingOneColliderDoesNotRecaptureAndFreshAttachAfterAllLeaveIsUsable() {
        let harness = M720ControllerHarness()
        let first = harness.makeDevice(snapshot: .m720(registryEntryID: 411, serialNumber: "collision"))
        let second = harness.makeDevice(snapshot: .m720(registryEntryID: 412, serialNumber: "collision"))

        harness.controller.deviceDidAttach(first)
        harness.executor.runAll()
        harness.controller.deviceDidAttach(second)
        harness.executor.runAll()
        let firstSession = harness.factoryCalls[0].session
        let secondSession = harness.factoryCalls[1].session

        var secondRemoved = 0
        harness.controller.prepareForDeviceRemoval(second) { secondRemoved += 1 }
        secondSession.completeInvalidation()

        XCTAssertEqual(secondRemoved, 1)
        XCTAssertEqual(firstSession.startCallCount, 1)
        XCTAssertEqual(firstSession.markIdentityUnusableCallCount, 1)

        var firstRemoved = 0
        harness.controller.prepareForDeviceRemoval(first) { firstRemoved += 1 }
        firstSession.completeInvalidation()
        XCTAssertEqual(firstRemoved, 1)

        let fresh = harness.makeDevice(snapshot: .m720(registryEntryID: 413, serialNumber: "collision"))
        harness.controller.deviceDidAttach(fresh)
        harness.executor.runAll()

        XCTAssertEqual(harness.factoryCalls.count, 3)
        XCTAssertTrue(harness.factoryCalls[2].journalIdentityUsable)
        XCTAssertEqual(harness.factoryCalls[2].session.startCallCount, 1)
    }

    func testDelayedDuplicateRemovalUsesRetainedDeviceAndPublishesDisconnectedBeforeDeletingEntry() {
        let harness = M720ControllerHarness()
        let device = harness.makeDevice(snapshot: .m720(registryEntryID: 501, serialNumber: "remove"))
        harness.controller.reconcile(
            remaps: makeRemaps(triggerButtons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        harness.controller.deviceDidAttach(device)
        harness.executor.runAll()
        let session = try! XCTUnwrap(harness.session(for: device))
        let copiedOldObserver = session.onStateChange
        let identityReadsAfterAttach = harness.identityReadCount(for: device)
        harness.setSnapshot(nil, for: device)
        var completions = 0

        harness.controller.prepareForDeviceRemoval(device) { completions += 1 }
        harness.controller.prepareForDeviceRemoval(device) { completions += 1 }

        XCTAssertEqual(session.invalidateCallCount, 1)
        XCTAssertEqual(completions, 0)
        XCTAssertEqual(harness.identityReadCount(for: device), identityReadsAfterAttach)
        XCTAssertEqual(harness.controller.captureStateSnapshots().count, 1)

        session.completeInvalidation()

        XCTAssertEqual(completions, 2)
        XCTAssertTrue(harness.controller.captureStateSnapshots().isEmpty)
        XCTAssertEqual(harness.publishedStates.last?.state, .invalid(.disconnected))

        let publishedCount = harness.publishedStates.count
        copiedOldObserver?(.conflict)
        session.completeInvalidation()
        XCTAssertEqual(harness.publishedStates.count, publishedCount)
        XCTAssertEqual(completions, 2)
    }

    func testRegistryReuseWaitsForOldInvalidationAndEveryOldTokenContinuationStaysStale() {
        let oldToken = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let newToken = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let harness = M720ControllerHarness(tokens: [oldToken, newToken])
        let oldDevice = harness.makeDevice(snapshot: .m720(registryEntryID: 601, serialNumber: "old"))
        let newDevice = harness.makeDevice(snapshot: .m720(registryEntryID: 601, serialNumber: "new"))

        harness.controller.deviceDidAttach(oldDevice)
        harness.executor.runAll()
        let oldSession = try! XCTUnwrap(harness.session(for: oldDevice))
        let copiedOldObserver = oldSession.onStateChange

        harness.controller.deviceDidAttach(newDevice)

        XCTAssertEqual(oldSession.invalidateCallCount, 1)
        XCTAssertEqual(harness.factoryCalls.count, 1)
        XCTAssertEqual(harness.executor.pendingCount, 0)

        oldSession.completeInvalidation()

        XCTAssertEqual(harness.factoryCalls.count, 2)
        let newSession = try! XCTUnwrap(harness.session(for: newDevice))
        XCTAssertEqual(newSession.startCallCount, 0)
        XCTAssertEqual(harness.executor.pendingCount, 1)

        harness.executor.runAll()
        XCTAssertEqual(newSession.startCallCount, 1)
        XCTAssertEqual(harness.controller.captureStateSnapshots().map(\.deviceToken), [newToken])

        let publishedCount = harness.publishedStates.count
        copiedOldObserver?(.conflict)
        oldSession.completeInvalidation()

        XCTAssertEqual(harness.controller.captureStateSnapshots().map(\.deviceToken), [newToken])
        XCTAssertEqual(harness.publishedStates.count, publishedCount)

        XCTAssertFalse(harness.controller.retryCapture(deviceToken: oldToken, requestID: UUID()))
        XCTAssertTrue(oldSession.retryRequestIDs.isEmpty)

        var oldRemovalCompletion = 0
        harness.controller.prepareForDeviceRemoval(oldDevice) { oldRemovalCompletion += 1 }
        XCTAssertEqual(oldRemovalCompletion, 1)
        XCTAssertEqual(newSession.invalidateCallCount, 0)
    }

    func testRegistryReuseWithSameJournalIdentityDoesNotTreatTearingDownOldEntryAsCollider() {
        let harness = M720ControllerHarness()
        let oldDevice = harness.makeDevice(snapshot: .m720(
            registryEntryID: 606,
            serialNumber: "same-physical-m720"
        ))
        let newDevice = harness.makeDevice(snapshot: .m720(
            registryEntryID: 606,
            serialNumber: "same-physical-m720"
        ))
        harness.controller.deviceDidAttach(oldDevice)
        harness.executor.runAll()
        let oldSession = try! XCTUnwrap(harness.session(for: oldDevice))

        harness.controller.deviceDidAttach(newDevice)

        XCTAssertEqual(oldSession.invalidateCallCount, 1)
        XCTAssertEqual(oldSession.markIdentityUnusableCallCount, 0)
        XCTAssertEqual(harness.factoryCalls.count, 1)

        oldSession.completeInvalidation()

        XCTAssertEqual(harness.factoryCalls.count, 2)
        XCTAssertTrue(harness.factoryCalls[1].device === newDevice)
        XCTAssertTrue(harness.factoryCalls[1].journalIdentityUsable)
    }

    func testFastReconnectWithDifferentRegistryWaitsForSameIdentityTeardownBarrier() {
        let harness = M720ControllerHarness()
        let oldDevice = harness.makeDevice(snapshot: .m720(
            registryEntryID: 607,
            serialNumber: "fast-reconnect"
        ))
        let newDevice = harness.makeDevice(snapshot: .m720(
            registryEntryID: 608,
            serialNumber: "fast-reconnect"
        ))
        harness.controller.deviceDidAttach(oldDevice)
        harness.executor.runAll()
        let oldSession = try! XCTUnwrap(harness.session(for: oldDevice))

        var oldRemovalCompletions = 0
        harness.controller.prepareForDeviceRemoval(oldDevice) {
            oldRemovalCompletions += 1
        }
        harness.controller.deviceDidAttach(newDevice)

        XCTAssertEqual(oldSession.invalidateCallCount, 1)
        XCTAssertEqual(oldSession.markIdentityUnusableCallCount, 0)
        XCTAssertEqual(harness.factoryCalls.count, 1)
        XCTAssertEqual(harness.identityReadCount(for: newDevice), 1)

        oldSession.completeInvalidation()

        XCTAssertEqual(oldRemovalCompletions, 1)
        XCTAssertEqual(harness.factoryCalls.count, 2)
        XCTAssertTrue(harness.factoryCalls[1].device === newDevice)
        XCTAssertTrue(harness.factoryCalls[1].journalIdentityUsable)
        XCTAssertEqual(harness.identityReadCount(for: newDevice), 1)
    }

    func testFreshAttachWaitsForEverySameIdentityTeardownToken() {
        let harness = M720ControllerHarness()
        let first = harness.makeDevice(snapshot: .m720(
            registryEntryID: 609,
            serialNumber: "multi-barrier"
        ))
        let second = harness.makeDevice(snapshot: .m720(
            registryEntryID: 610,
            serialNumber: "multi-barrier"
        ))
        let fresh = harness.makeDevice(snapshot: .m720(
            registryEntryID: 611,
            serialNumber: "multi-barrier"
        ))
        harness.controller.deviceDidAttach(first)
        harness.controller.deviceDidAttach(second)
        harness.executor.runAll()
        let firstSession = try! XCTUnwrap(harness.session(for: first))
        let secondSession = try! XCTUnwrap(harness.session(for: second))
        XCTAssertEqual(harness.factoryCalls.count, 2)

        harness.controller.prepareForDeviceRemoval(first, completion: {})
        harness.controller.prepareForDeviceRemoval(second, completion: {})
        harness.controller.deviceDidAttach(fresh)

        XCTAssertEqual(harness.factoryCalls.count, 2)
        XCTAssertEqual(harness.identityReadCount(for: fresh), 1)

        firstSession.completeInvalidation()
        XCTAssertEqual(harness.factoryCalls.count, 2)

        secondSession.completeInvalidation()
        XCTAssertEqual(harness.factoryCalls.count, 3)
        XCTAssertTrue(harness.factoryCalls[2].device === fresh)
        XCTAssertTrue(harness.factoryCalls[2].journalIdentityUsable)
        XCTAssertEqual(harness.identityReadCount(for: fresh), 1)
    }

    func testPendingRegistryReuseRemovedBeforeOldInvalidationNeverCreatesOrStartsSession() {
        let harness = M720ControllerHarness()
        let oldDevice = harness.makeDevice(snapshot: .m720(registryEntryID: 611, serialNumber: "old"))
        let pendingDevice = harness.makeDevice(snapshot: .m720(registryEntryID: 611, serialNumber: "pending"))
        harness.controller.deviceDidAttach(oldDevice)
        harness.executor.runAll()
        let oldSession = try! XCTUnwrap(harness.session(for: oldDevice))

        harness.controller.deviceDidAttach(pendingDevice)
        XCTAssertEqual(oldSession.invalidateCallCount, 1)
        XCTAssertEqual(harness.factoryCalls.count, 1)

        var pendingRemovalCompletions = 0
        harness.controller.prepareForDeviceRemoval(pendingDevice) {
            pendingRemovalCompletions += 1
        }

        XCTAssertEqual(pendingRemovalCompletions, 1)
        oldSession.completeInvalidation()
        harness.executor.runAll()

        XCTAssertEqual(harness.factoryCalls.count, 1)
        XCTAssertNil(harness.session(for: pendingDevice))
        XCTAssertTrue(harness.controller.captureStateSnapshots().isEmpty)
    }

    func testThirdRegistryReuseAttachSupersedesPendingOnSameOldTeardownBarrier() {
        let oldToken = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
        let latestToken = UUID(uuidString: "00000000-0000-0000-0000-000000000023")!
        let harness = M720ControllerHarness(tokens: [oldToken, latestToken])
        let oldDevice = harness.makeDevice(snapshot: .m720(registryEntryID: 621, serialNumber: "old"))
        let supersededDevice = harness.makeDevice(snapshot: .m720(registryEntryID: 621, serialNumber: "superseded"))
        let latestDevice = harness.makeDevice(snapshot: .m720(registryEntryID: 621, serialNumber: "latest"))
        harness.controller.deviceDidAttach(oldDevice)
        harness.executor.runAll()
        let oldSession = try! XCTUnwrap(harness.session(for: oldDevice))

        harness.controller.deviceDidAttach(supersededDevice)
        harness.controller.deviceDidAttach(latestDevice)

        XCTAssertEqual(oldSession.invalidateCallCount, 1)
        XCTAssertEqual(harness.factoryCalls.count, 1)
        XCTAssertEqual(harness.executor.pendingCount, 0)

        oldSession.completeInvalidation()

        XCTAssertEqual(harness.factoryCalls.count, 2)
        XCTAssertTrue(harness.factoryCalls[1].device === latestDevice)
        XCTAssertNil(harness.session(for: supersededDevice))
        XCTAssertEqual(harness.session(for: latestDevice)?.startCallCount, 0)

        harness.executor.runAll()

        XCTAssertEqual(harness.session(for: latestDevice)?.startCallCount, 1)
        XCTAssertEqual(
            harness.controller.captureStateSnapshots().map(\.deviceToken),
            [latestToken]
        )
    }

    func testSameRegistryPendingGenerationDoesNotCollideWithItsLatestSuperseder() {
        let harness = M720ControllerHarness()
        let oldDevice = harness.makeDevice(snapshot: .m720(
            registryEntryID: 626,
            serialNumber: "same-generation-domain"
        ))
        let supersededDevice = harness.makeDevice(snapshot: .m720(
            registryEntryID: 626,
            serialNumber: "same-generation-domain"
        ))
        let latestDevice = harness.makeDevice(snapshot: .m720(
            registryEntryID: 626,
            serialNumber: "same-generation-domain"
        ))
        harness.controller.deviceDidAttach(oldDevice)
        harness.executor.runAll()
        let oldSession = try! XCTUnwrap(harness.session(for: oldDevice))

        harness.controller.deviceDidAttach(supersededDevice)
        harness.controller.deviceDidAttach(latestDevice)

        XCTAssertEqual(oldSession.invalidateCallCount, 1)
        XCTAssertEqual(oldSession.markIdentityUnusableCallCount, 0)
        XCTAssertEqual(harness.factoryCalls.count, 1)
        XCTAssertEqual(harness.identityReadCount(for: supersededDevice), 1)
        XCTAssertEqual(harness.identityReadCount(for: latestDevice), 1)

        oldSession.completeInvalidation()

        XCTAssertEqual(harness.factoryCalls.count, 2)
        XCTAssertTrue(harness.factoryCalls[1].device === latestDevice)
        XCTAssertTrue(harness.factoryCalls[1].journalIdentityUsable)
        XCTAssertNil(harness.session(for: supersededDevice))
    }

    func testPendingRegistryReuseKeepsCollisionUnusableAfterColliderLeavesBeforeBarrierCompletes() {
        let harness = M720ControllerHarness()
        let oldRegistryHolder = harness.makeDevice(snapshot: .m720(
            registryEntryID: 631,
            serialNumber: "old-registry-key"
        ))
        let collider = harness.makeDevice(snapshot: .m720(
            registryEntryID: 632,
            serialNumber: "pending-key"
        ))
        let pending = harness.makeDevice(snapshot: .m720(
            registryEntryID: 631,
            serialNumber: "pending-key"
        ))
        harness.controller.deviceDidAttach(oldRegistryHolder)
        harness.controller.deviceDidAttach(collider)
        harness.executor.runAll()
        let oldSession = try! XCTUnwrap(harness.session(for: oldRegistryHolder))
        let colliderSession = try! XCTUnwrap(harness.session(for: collider))

        harness.controller.deviceDidAttach(pending)

        XCTAssertEqual(oldSession.invalidateCallCount, 1)
        XCTAssertEqual(colliderSession.markIdentityUnusableCallCount, 1)
        XCTAssertEqual(harness.factoryCalls.count, 2)
        XCTAssertEqual(harness.identityReadCount(for: pending), 1)

        var colliderRemovalCompletions = 0
        harness.controller.prepareForDeviceRemoval(collider) {
            colliderRemovalCompletions += 1
        }
        colliderSession.completeInvalidation()
        XCTAssertEqual(colliderRemovalCompletions, 1)

        oldSession.completeInvalidation()

        XCTAssertEqual(harness.factoryCalls.count, 3)
        XCTAssertTrue(harness.factoryCalls[2].device === pending)
        XCTAssertFalse(harness.factoryCalls[2].journalIdentityUsable)
        XCTAssertEqual(harness.identityReadCount(for: pending), 1)
    }

    func testSavedPolicySurvivesEnvironmentDisableAndSyntheticAddModeRemapsAndFansOut() {
        let harness = M720ControllerHarness()
        let first = harness.makeDevice(snapshot: .m720(registryEntryID: 701, serialNumber: "policy-a"))
        let second = harness.makeDevice(snapshot: .m720(registryEntryID: 702, serialNumber: "policy-b"))
        harness.controller.deviceDidAttach(first)
        harness.controller.deviceDidAttach(second)
        harness.executor.runAll()
        let firstSession = try! XCTUnwrap(harness.session(for: first))
        let secondSession = try! XCTUnwrap(harness.session(for: second))

        harness.controller.reconcile(
            remaps: makeRemaps(triggerButtons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        harness.controller.reconcile(
            remaps: makeRemaps(triggerButtons: [7]),
            buttonsEnabled: false,
            remapsAreAddMode: false
        )
        harness.controller.reconcile(
            remaps: makeRemaps(triggerButtons: [8]),
            buttonsEnabled: true,
            remapsAreAddMode: true
        )

        let expected: [Set<UInt16>] = [[], [0x005B], [], [0x005D]]
        XCTAssertEqual(firstSession.requiredCIDCalls, expected)
        XCTAssertEqual(secondSession.requiredCIDCalls, expected)

        let later = harness.makeDevice(snapshot: .m720(registryEntryID: 703, serialNumber: "policy-c"))
        harness.controller.deviceDidAttach(later)
        harness.executor.runAll()
        XCTAssertEqual(harness.session(for: later)?.requiredCIDCalls, [[0x005D]])

        harness.controller.reconcile(
            remaps: makeRemaps(triggerButtons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        XCTAssertEqual(firstSession.requiredCIDCalls.last, [0x005B])
        XCTAssertEqual(secondSession.requiredCIDCalls.last, [0x005B])
    }

    func testStableErrorsAreSilentWithoutConfigurationThenPublishAndDedupeWhenConfigured() {
        let token = UUID(uuidString: "00000000-0000-0000-0000-000000000031")!
        let harness = M720ControllerHarness(tokens: [token])
        let device = harness.makeDevice(snapshot: .m720(registryEntryID: 801, serialNumber: "publish"))
        harness.controller.deviceDidAttach(device)
        harness.executor.runAll()
        let session = try! XCTUnwrap(harness.session(for: device))

        session.emit(.invalid(.protocol))
        XCTAssertTrue(harness.publishedStates.isEmpty)

        harness.controller.reconcile(
            remaps: makeRemaps(triggerButtons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        XCTAssertEqual(harness.publishedStates.count, 1)
        XCTAssertEqual(harness.publishedStates[0].deviceToken, token)
        XCTAssertEqual(harness.publishedStates[0].state, .invalid(.protocol))
        XCTAssertEqual(harness.publishedStates[0].errorCode, .protocol)
        XCTAssertEqual(harness.publishedStates[0].requiredCIDs, [0x005B])

        session.emit(.invalid(.protocol))
        session.emit(.invalid(.protocol))
        XCTAssertEqual(harness.publishedStates.count, 1)

        session.emit(.nativeReady)
        XCTAssertEqual(harness.publishedStates.count, 2)
        XCTAssertEqual(harness.publishedStates.last?.deviceToken, token)
        XCTAssertEqual(harness.publishedStates.last?.state, .nativeReady)
        XCTAssertNil(harness.publishedStates.last?.errorCode)

        harness.controller.reconcile(
            remaps: makeRemaps(triggerButtons: [6]),
            buttonsEnabled: false,
            remapsAreAddMode: false
        )
        XCTAssertEqual(harness.publishedStates.count, 3)
        XCTAssertEqual(harness.publishedStates.last?.requiredCIDs, [])
    }

    func testSameTokenStaleActiveObserverCannotPublishNewPolicyBeforeVerifiedActive() {
        let harness = M720ControllerHarness()
        let device = harness.makeDevice(snapshot: .m720(
            registryEntryID: 851,
            serialNumber: "stale-state"
        ))
        harness.controller.deviceDidAttach(device)
        harness.executor.runAll()
        let session = try! XCTUnwrap(harness.session(for: device))

        harness.controller.reconcile(
            remaps: makeRemaps(triggerButtons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        session.emit(.active)
        XCTAssertEqual(harness.publishedStates.count, 1)
        XCTAssertEqual(harness.publishedStates.last?.requiredCIDs, [0x005B])
        let copiedOldObserver = session.onStateChange

        session.stateOnNextRequiredCIDSet = .restoring
        harness.controller.reconcile(
            remaps: makeRemaps(triggerButtons: [7]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        XCTAssertEqual(harness.publishedStates.count, 1)

        copiedOldObserver?(.active)
        XCTAssertEqual(harness.publishedStates.count, 1)

        session.emit(.active)
        XCTAssertEqual(harness.publishedStates.count, 2)
        XCTAssertEqual(harness.publishedStates.last?.state, .active)
        XCTAssertEqual(harness.publishedStates.last?.requiredCIDs, [0x005D])
    }

    func testRetrySleepWakeAndShutdownUseOnlyCurrentLiveTokens() {
        let firstToken = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
        let secondToken = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
        let harness = M720ControllerHarness(tokens: [firstToken, secondToken])
        let first = harness.makeDevice(snapshot: .m720(registryEntryID: 901, serialNumber: "lifecycle-a"))
        let second = harness.makeDevice(snapshot: .m720(registryEntryID: 902, serialNumber: "lifecycle-b"))
        harness.controller.deviceDidAttach(first)
        harness.controller.deviceDidAttach(second)
        harness.executor.runAll()
        let firstSession = try! XCTUnwrap(harness.session(for: first))
        let secondSession = try! XCTUnwrap(harness.session(for: second))
        let requestID = UUID()
        firstSession.retryAccepted = true

        XCTAssertFalse(harness.controller.retryCapture(deviceToken: UUID(), requestID: requestID))
        XCTAssertTrue(harness.controller.retryCapture(deviceToken: firstToken, requestID: requestID))
        XCTAssertEqual(firstSession.retryRequestIDs, [requestID])
        XCTAssertTrue(secondSession.retryRequestIDs.isEmpty)

        harness.controller.prepareForSleep()
        harness.controller.reconcileAfterWake()
        XCTAssertEqual(firstSession.prepareForSleepCallCount, 1)
        XCTAssertEqual(secondSession.prepareForSleepCallCount, 1)
        XCTAssertEqual(firstSession.reconcileAfterWakeCallCount, 1)
        XCTAssertEqual(secondSession.reconcileAfterWakeCallCount, 1)

        var shutdownCompletions = 0
        harness.controller.shutdown { shutdownCompletions += 1 }
        XCTAssertEqual(firstSession.shutdownCallCount, 1)
        XCTAssertEqual(secondSession.shutdownCallCount, 1)
        XCTAssertEqual(shutdownCompletions, 0)

        firstSession.completeShutdown()
        XCTAssertEqual(shutdownCompletions, 0)
        secondSession.completeShutdown()
        XCTAssertEqual(shutdownCompletions, 1)
    }

    func testWorkspaceLifecycleNotificationsForwardToLiveSessionsOnMain() {
        let workspaceCenter = NotificationCenter()
        let harness = M720ControllerHarness(workspaceCenter: workspaceCenter)
        let removing = harness.makeDevice(snapshot: .m720(
            registryEntryID: 911,
            serialNumber: "lifecycle-removing"
        ))
        let live = harness.makeDevice(snapshot: .m720(
            registryEntryID: 912,
            serialNumber: "lifecycle-live"
        ))
        harness.controller.deviceDidAttach(removing)
        harness.controller.deviceDidAttach(live)
        harness.executor.runAll()
        let removingSession = try! XCTUnwrap(harness.session(for: removing))
        let liveSession = try! XCTUnwrap(harness.session(for: live))
        harness.controller.prepareForDeviceRemoval(removing) {}

        workspaceCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        workspaceCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        workspaceCenter.post(
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        XCTAssertEqual(removingSession.prepareForSleepCallCount, 0)
        XCTAssertEqual(removingSession.reconcileAfterWakeCallCount, 0)
        XCTAssertEqual(removingSession.knownOwnershipAgentLaunchCallCount, 0)
        XCTAssertEqual(liveSession.prepareForSleepCallCount, 1)
        XCTAssertEqual(liveSession.reconcileAfterWakeCallCount, 1)
        XCTAssertEqual(liveSession.knownOwnershipAgentLaunchCallCount, 1)
        XCTAssertEqual(liveSession.lifecycleCallbacksWereOnMain, [true, true, true])
    }

    func testShutdownImmediatelyRejectsNewControllerWorkAndCoalescesWaiters() {
        let workspaceCenter = NotificationCenter()
        let token = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
        let harness = M720ControllerHarness(
            tokens: [token],
            workspaceCenter: workspaceCenter
        )
        let attached = harness.makeDevice(snapshot: .m720(
            registryEntryID: 921,
            serialNumber: "shutdown-attached"
        ))
        harness.controller.deviceDidAttach(attached)
        let session = try! XCTUnwrap(harness.session(for: attached))
        let requiredCIDCallCount = session.requiredCIDCalls.count
        var completions = 0

        harness.controller.shutdown { completions += 1 }
        harness.controller.shutdown { completions += 1 }

        XCTAssertEqual(session.shutdownCallCount, 1)
        XCTAssertEqual(completions, 0)

        harness.executor.runAll()
        XCTAssertEqual(session.startCallCount, 0)

        harness.controller.reconcile(
            remaps: makeRemaps(triggerButtons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        workspaceCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        workspaceCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        workspaceCenter.post(
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        XCTAssertEqual(session.requiredCIDCalls.count, requiredCIDCallCount)
        XCTAssertTrue(session.lifecycleCallbacksWereOnMain.isEmpty)
        XCTAssertFalse(harness.controller.retryCapture(
            deviceToken: token,
            requestID: UUID()
        ))
        XCTAssertFalse(harness.controller.beginTemporaryPolicyLease(
            ownerID: UUID(),
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: [0x005B],
            completion: { _ in XCTFail("shutdown must reject temporary policy work") }
        ))
        XCTAssertTrue(
            harness.controller.capturePreparationSnapshot().participants.isEmpty
        )

        let lateAttach = harness.makeDevice(snapshot: .m720(
            registryEntryID: 922,
            serialNumber: "shutdown-late"
        ))
        harness.controller.deviceDidAttach(lateAttach)
        XCTAssertEqual(harness.factoryCalls.count, 1)

        session.completeShutdown()
        session.completeShutdown()
        XCTAssertEqual(completions, 2)

        harness.controller.shutdown { completions += 1 }
        XCTAssertEqual(completions, 3)
        XCTAssertEqual(session.shutdownCallCount, 1)
    }

    func testShutdownWaitsForRemovalCleanupAlreadyInFlight() {
        let harness = M720ControllerHarness()
        let removing = harness.makeDevice(snapshot: .m720(
            registryEntryID: 923,
            serialNumber: "shutdown-removing"
        ))
        let live = harness.makeDevice(snapshot: .m720(
            registryEntryID: 924,
            serialNumber: "shutdown-live"
        ))
        harness.controller.deviceDidAttach(removing)
        harness.controller.deviceDidAttach(live)
        harness.executor.runAll()
        let removingSession = try! XCTUnwrap(harness.session(for: removing))
        let liveSession = try! XCTUnwrap(harness.session(for: live))
        harness.controller.prepareForDeviceRemoval(removing) {}
        var completions = 0

        harness.controller.shutdown { completions += 1 }

        XCTAssertEqual(removingSession.shutdownCallCount, 0)
        XCTAssertEqual(liveSession.shutdownCallCount, 1)
        liveSession.completeShutdown()
        XCTAssertEqual(completions, 0)

        removingSession.completeInvalidation()
        XCTAssertEqual(completions, 1)
    }

    func testShutdownDeadlineReachesParticipantRemovedAfterJoiningShutdown() {
        let harness = M720ControllerHarness()
        let removing = harness.makeDevice(snapshot: .m720(
            registryEntryID: 925,
            serialNumber: "deadline-removing"
        ))
        let live = harness.makeDevice(snapshot: .m720(
            registryEntryID: 926,
            serialNumber: "deadline-live"
        ))
        harness.controller.deviceDidAttach(removing)
        harness.controller.deviceDidAttach(live)
        harness.executor.runAll()
        let removingSession = try! XCTUnwrap(harness.session(for: removing))
        let liveSession = try! XCTUnwrap(harness.session(for: live))
        harness.controller.prepareForDeviceRemoval(removing) {}

        harness.controller.shutdown {}
        removingSession.completeInvalidation()
        XCTAssertEqual(harness.controller.captureStateSnapshots().count, 1)
        harness.controller.shutdownDeadlineReached()
        harness.controller.shutdownDeadlineReached()

        XCTAssertEqual(removingSession.shutdownDeadlineCallCount, 1)
        XCTAssertEqual(liveSession.shutdownDeadlineCallCount, 1)
    }

    func testDeviceManagerDebugSeamUsesCallerOwnedArrayAndIdentityRemovalIsIdempotent() {
        let first = Device.unitTestDevice()
        let equalButDifferent = Device.unitTestDevice()
        let attachedDevices = NSMutableArray(object: equalButDifferent)
        var events: [String] = []

        DeviceManager.unitTestAttach(
            device: first,
            attachedDevices: attachedDevices,
            notify: { devices in
                XCTAssertEqual(devices.count, 2)
                XCTAssertTrue(devices.last.map { $0 === first } == true)
                events.append("attach-notify")
            },
            controllerAttach: { device in
                XCTAssertTrue(device === first)
                events.append("controller-attach")
            }
        )

        var finishRemoval: (() -> Void)?
        DeviceManager.unitTestRemove(
            device: first,
            attachedDevices: attachedDevices,
            prepare: { device, completion in
                XCTAssertTrue(device === first)
                events.append("prepare")
                finishRemoval = completion
            },
            notify: { devices in
                XCTAssertEqual(devices.count, 1)
                XCTAssertTrue(devices.first.map { $0 === equalButDifferent } == true)
                events.append("remove-notify")
            }
        )

        XCTAssertEqual(attachedDevices.count, 2)
        XCTAssertEqual(events, ["attach-notify", "controller-attach", "prepare"])

        finishRemoval?()
        finishRemoval?()

        XCTAssertEqual(attachedDevices.count, 1)
        XCTAssertEqual(
            events,
            ["attach-notify", "controller-attach", "prepare", "remove-notify"]
        )
    }

    private func makeRemaps(triggerButtons: [Int]) -> NSDictionary {
        let modification = NSMutableDictionary()
        for button in triggerButtons {
            modification.setObject(NSDictionary(), forKey: NSNumber(value: button))
        }
        let remaps = NSMutableDictionary()
        remaps.setObject(modification, forKey: NSDictionary())
        return remaps
    }
}

final class M720ControllerTemporaryPolicyTests: XCTestCase {
    private let allTargets = Set(M720Profile.cidToButton.keys)

    func testPreparationSnapshotContainsRevisionEnvironmentAndSortedExactSavedPolicy() {
        let highToken = UUID(uuidString: "F0000000-0000-0000-0000-000000000001")!
        let lowToken = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        let harness = M720ControllerHarness(tokens: [highToken, lowToken])
        harness.controller.reconcile(
            remaps: makeControllerRemaps(buttons: [6, 8]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let first = harness.makeDevice(snapshot: .m720(registryEntryID: 10, serialNumber: "one"))
        let second = harness.makeDevice(snapshot: .m720(registryEntryID: 20, serialNumber: "two"))
        harness.controller.deviceDidAttach(first)
        harness.controller.deviceDidAttach(second)

        let snapshot = harness.controller.capturePreparationSnapshot()

        XCTAssertEqual(snapshot.deviceSetRevision, 2)
        XCTAssertTrue(snapshot.environmentEnabled)
        XCTAssertEqual(snapshot.participants.map(\.deviceToken), [lowToken, highToken])
        XCTAssertEqual(
            snapshot.participants.map(\.exactRequiredCIDs),
            [Set([0x005B, 0x00D0]), Set([0x005B, 0x00D0])]
        )
    }

    func testLeaseAtomicallyRejectsStaleRevisionAndIncompleteTokenSetWithoutApplyingTargets() {
        let harness = M720ControllerHarness()
        let first = harness.makeDevice(snapshot: .m720(registryEntryID: 30, serialNumber: "one"))
        harness.controller.deviceDidAttach(first)
        let stale = harness.controller.capturePreparationSnapshot()
        let second = harness.makeDevice(snapshot: .m720(registryEntryID: 31, serialNumber: "two"))
        harness.controller.deviceDidAttach(second)
        let callsBefore = harness.factoryCalls.map { $0.session.requiredCIDCalls.count }

        XCTAssertFalse(harness.controller.beginTemporaryPolicyLease(
            ownerID: UUID(),
            snapshot: stale,
            targetCIDs: allTargets,
            completion: { _ in XCTFail("Rejected lease must not complete") }
        ))
        XCTAssertEqual(
            harness.factoryCalls.map { $0.session.requiredCIDCalls.count },
            callsBefore
        )

        let current = harness.controller.capturePreparationSnapshot()
        let incomplete = M720PreparationSnapshot(
            deviceSetRevision: current.deviceSetRevision,
            environmentEnabled: current.environmentEnabled,
            participants: Array(current.participants.dropLast())
        )
        XCTAssertFalse(harness.controller.beginTemporaryPolicyLease(
            ownerID: UUID(),
            snapshot: incomplete,
            targetCIDs: allTargets,
            completion: { _ in XCTFail("Incomplete token set must not complete") }
        ))
        XCTAssertEqual(
            harness.factoryCalls.map { $0.session.requiredCIDCalls.count },
            callsBefore
        )
    }

    func testAlreadyStableParticipantSchedulesCompletionWithoutWaitingForObserver() {
        let harness = M720ControllerHarness()
        harness.controller.reconcile(
            remaps: makeControllerRemaps(buttons: [6, 7, 8]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let device = harness.makeDevice(snapshot: .m720(registryEntryID: 40, serialNumber: "stable"))
        harness.controller.deviceDidAttach(device)
        let session = try! XCTUnwrap(harness.session(for: device))
        session.emit(.active)
        var results: [M720TemporaryPolicyResult] = []

        XCTAssertTrue(harness.controller.beginTemporaryPolicyLease(
            ownerID: UUID(),
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { results.append($0) }
        ))
        XCTAssertTrue(results.isEmpty)
        harness.executor.runAll()
        XCTAssertEqual(results, [.ready])

        session.emit(.active)
        XCTAssertEqual(results, [.ready])
    }

    func testQueuedBeginReadyRevalidatesConflictBeforeDelivery() {
        let harness = M720ControllerHarness()
        harness.controller.reconcile(
            remaps: NSDictionary(),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let device = harness.makeDevice(
            snapshot: .m720(registryEntryID: 41, serialNumber: "begin-race")
        )
        harness.controller.deviceDidAttach(device)
        let session = try! XCTUnwrap(harness.session(for: device))
        let owner = UUID()
        session.stateOnNextRequiredCIDSet = .active
        var results: [M720TemporaryPolicyResult] = []

        XCTAssertTrue(harness.controller.beginTemporaryPolicyLease(
            ownerID: owner,
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { results.append($0) }
        ))
        session.emit(.conflict)
        harness.executor.runAll()

        XCTAssertEqual(results, [.failed(.conflict)])
        XCTAssertFalse(harness.controller.clearTemporaryPolicyLease(ownerID: owner))
    }

    func testQueuedBeginReadyWaitsForTransientRegressionToBecomeStableAgain() {
        let harness = M720ControllerHarness()
        harness.controller.reconcile(
            remaps: NSDictionary(),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let device = harness.makeDevice(
            snapshot: .m720(registryEntryID: 42, serialNumber: "begin-transient")
        )
        harness.controller.deviceDidAttach(device)
        let session = try! XCTUnwrap(harness.session(for: device))
        session.stateOnNextRequiredCIDSet = .active
        var results: [M720TemporaryPolicyResult] = []

        XCTAssertTrue(harness.controller.beginTemporaryPolicyLease(
            ownerID: UUID(),
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { results.append($0) }
        ))
        session.emit(.restoring)
        harness.executor.runAll()
        XCTAssertTrue(results.isEmpty)

        session.emit(.active)
        harness.executor.runAll()
        XCTAssertEqual(results, [.ready])
    }

    func testQueuedRestoreReadyRevalidatesInvalidStateAndBlocksLease() {
        let harness = M720ControllerHarness()
        harness.controller.reconcile(
            remaps: NSDictionary(),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let device = harness.makeDevice(
            snapshot: .m720(registryEntryID: 43, serialNumber: "restore-race")
        )
        harness.controller.deviceDidAttach(device)
        let session = try! XCTUnwrap(harness.session(for: device))
        let owner = UUID()
        session.stateOnNextRequiredCIDSet = .active
        XCTAssertTrue(harness.controller.beginTemporaryPolicyLease(
            ownerID: owner,
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { XCTAssertEqual($0, .ready) }
        ))
        harness.executor.runAll()

        session.stateOnNextRequiredCIDSet = .nativeReady
        var results: [M720TemporaryPolicyResult] = []
        XCTAssertTrue(harness.controller.restoreTemporaryPolicyLease(
            ownerID: owner,
            completion: { results.append($0) }
        ))
        session.emit(.invalid(.disconnected))
        harness.executor.runAll()

        XCTAssertEqual(results, [.failed(.disconnected)])
        XCTAssertFalse(harness.controller.restoreTemporaryPolicyLease(
            ownerID: owner,
            completion: { _ in XCTFail("Failed rollback must block the lease") }
        ))
    }

    func testQueuedUpdateReadyRevalidatesConflictAndBlocksLease() {
        let harness = M720ControllerHarness()
        harness.controller.reconcile(
            remaps: makeControllerRemaps(buttons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let device = harness.makeDevice(
            snapshot: .m720(registryEntryID: 44, serialNumber: "update-race")
        )
        harness.controller.deviceDidAttach(device)
        let session = try! XCTUnwrap(harness.session(for: device))
        let owner = UUID()
        session.stateOnNextRequiredCIDSet = .active
        XCTAssertTrue(harness.controller.beginTemporaryPolicyLease(
            ownerID: owner,
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { XCTAssertEqual($0, .ready) }
        ))
        harness.executor.runAll()

        session.stateOnNextRequiredCIDSet = .active
        harness.controller.reconcile(
            remaps: makeControllerRemaps(buttons: [8]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        session.stateOnNextRequiredCIDSet = .active
        var results: [M720TemporaryPolicyResult] = []
        XCTAssertTrue(harness.controller.updateTemporaryPolicyLeaseToCurrentSaved(
            ownerID: owner,
            completion: { results.append($0) }
        ))
        session.emit(.conflict)
        harness.executor.runAll()

        XCTAssertEqual(results, [.failed(.conflict)])
        XCTAssertFalse(harness.controller.updateTemporaryPolicyLeaseToCurrentSaved(
            ownerID: owner,
            completion: { _ in XCTFail("Failed update must block the lease") }
        ))
    }

    func testClearRevalidatesLiveStableStateAfterVerifiedSavedTarget() {
        let harness = M720ControllerHarness()
        harness.controller.reconcile(
            remaps: makeControllerRemaps(buttons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let device = harness.makeDevice(
            snapshot: .m720(registryEntryID: 45, serialNumber: "clear-race")
        )
        harness.controller.deviceDidAttach(device)
        let session = try! XCTUnwrap(harness.session(for: device))
        let owner = UUID()
        session.stateOnNextRequiredCIDSet = .active
        XCTAssertTrue(harness.controller.beginTemporaryPolicyLease(
            ownerID: owner,
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { XCTAssertEqual($0, .ready) }
        ))
        harness.executor.runAll()

        session.stateOnNextRequiredCIDSet = .active
        XCTAssertTrue(harness.controller.updateTemporaryPolicyLeaseToCurrentSaved(
            ownerID: owner,
            completion: { XCTAssertEqual($0, .ready) }
        ))
        harness.executor.runAll()

        session.emit(.restoring)
        XCTAssertFalse(harness.controller.clearTemporaryPolicyLease(ownerID: owner))
        session.emit(.active)
        XCTAssertTrue(harness.controller.clearTemporaryPolicyLease(ownerID: owner))
    }

    func testTwoParticipantLeaseAggregatesOneStableResult() {
        let harness = M720ControllerHarness()
        harness.controller.reconcile(
            remaps: NSDictionary(),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let first = harness.makeDevice(snapshot: .m720(registryEntryID: 50, serialNumber: "one"))
        let second = harness.makeDevice(snapshot: .m720(registryEntryID: 51, serialNumber: "two"))
        harness.controller.deviceDidAttach(first)
        harness.controller.deviceDidAttach(second)
        let firstSession = try! XCTUnwrap(harness.session(for: first))
        let secondSession = try! XCTUnwrap(harness.session(for: second))
        firstSession.stateOnNextRequiredCIDSet = .active
        secondSession.stateOnNextRequiredCIDSet = .takingOver
        var results: [M720TemporaryPolicyResult] = []

        XCTAssertTrue(harness.controller.beginTemporaryPolicyLease(
            ownerID: UUID(),
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { results.append($0) }
        ))
        harness.executor.runAll()
        XCTAssertTrue(results.isEmpty)

        secondSession.emit(.active)
        secondSession.emit(.active)
        harness.executor.runAll()
        XCTAssertEqual(results, [.ready])
    }

    func testBlockedRollbackRetainsOwnerAndRejectsNewLease() {
        let harness = M720ControllerHarness()
        harness.controller.reconcile(
            remaps: NSDictionary(),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let device = harness.makeDevice(snapshot: .m720(registryEntryID: 60, serialNumber: "blocked"))
        harness.controller.deviceDidAttach(device)
        let session = try! XCTUnwrap(harness.session(for: device))
        let owner = UUID()
        session.stateOnNextRequiredCIDSet = .active
        XCTAssertTrue(harness.controller.beginTemporaryPolicyLease(
            ownerID: owner,
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { XCTAssertEqual($0, .ready) }
        ))
        harness.executor.runAll()
        session.stateOnNextRequiredCIDSet = .conflict
        var rollbackResults: [M720TemporaryPolicyResult] = []

        XCTAssertTrue(harness.controller.restoreTemporaryPolicyLease(
            ownerID: owner,
            completion: { rollbackResults.append($0) }
        ))
        harness.executor.runAll()
        XCTAssertEqual(rollbackResults, [.failed(.conflict)])
        XCTAssertFalse(harness.controller.clearTemporaryPolicyLease(ownerID: owner))
        XCTAssertFalse(harness.controller.beginTemporaryPolicyLease(
            ownerID: UUID(),
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { _ in XCTFail("Blocked rollback must retain owner") }
        ))
    }

    func testSyntheticAddModeReconcileDoesNotOverwriteSavedCacheOrLeaseOverride() {
        let harness = M720ControllerHarness()
        harness.controller.reconcile(
            remaps: makeControllerRemaps(buttons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let device = harness.makeDevice(snapshot: .m720(registryEntryID: 70, serialNumber: "synthetic"))
        harness.controller.deviceDidAttach(device)
        let session = try! XCTUnwrap(harness.session(for: device))
        session.stateOnNextRequiredCIDSet = .active
        XCTAssertTrue(harness.controller.beginTemporaryPolicyLease(
            ownerID: UUID(),
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { XCTAssertEqual($0, .ready) }
        ))
        harness.executor.runAll()

        harness.controller.reconcile(
            remaps: makeControllerRemaps(buttons: [7, 8]),
            buttonsEnabled: true,
            remapsAreAddMode: true
        )

        XCTAssertEqual(session.requiredCIDCalls.last, allTargets)
        XCTAssertEqual(
            harness.controller.capturePreparationSnapshot().participants.single?.exactRequiredCIDs,
            Set([0x005B])
        )
    }

    func testEnvironmentDisableSendsOnlyEmptyTargetsPreservesSavedCacheAndReenableStartsBaseline() {
        let harness = M720ControllerHarness()
        let saved = Set<UInt16>([0x005B])
        harness.controller.reconcile(
            remaps: makeControllerRemaps(buttons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let device = harness.makeDevice(snapshot: .m720(registryEntryID: 80, serialNumber: "gate"))
        harness.controller.deviceDidAttach(device)
        let session = try! XCTUnwrap(harness.session(for: device))
        let owner = UUID()
        session.stateOnNextRequiredCIDSet = .active
        XCTAssertTrue(harness.controller.beginTemporaryPolicyLease(
            ownerID: owner,
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { XCTAssertEqual($0, .ready) }
        ))
        harness.executor.runAll()
        let callsBeforeDisable = session.requiredCIDCalls.count

        session.stateOnNextRequiredCIDSet = .nativeReady
        harness.controller.reconcile(
            remaps: makeControllerRemaps(buttons: [7, 8]),
            buttonsEnabled: false,
            remapsAreAddMode: true
        )
        XCTAssertTrue(harness.controller.restoreTemporaryPolicyLease(
            ownerID: owner,
            completion: { XCTAssertEqual($0, .ready) }
        ))
        harness.executor.runAll()
        XCTAssertTrue(harness.controller.clearTemporaryPolicyLease(ownerID: owner))

        XCTAssertTrue(session.requiredCIDCalls[callsBeforeDisable...].allSatisfy(\.isEmpty))
        let disabledSnapshot = harness.controller.capturePreparationSnapshot()
        XCTAssertFalse(disabledSnapshot.environmentEnabled)
        XCTAssertEqual(disabledSnapshot.participants.single?.exactRequiredCIDs, saved)

        session.stateOnNextRequiredCIDSet = .active
        harness.controller.reconcile(
            remaps: makeControllerRemaps(buttons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        XCTAssertEqual(session.requiredCIDCalls.last, saved)
    }

    func testEnvironmentDisableFencesQueuedReadyBeforeApplyingEmptyTarget() {
        let harness = M720ControllerHarness()
        harness.controller.reconcile(
            remaps: NSDictionary(),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let device = harness.makeDevice(snapshot: .m720(registryEntryID: 85, serialNumber: "disable-race"))
        harness.controller.deviceDidAttach(device)
        let session = try! XCTUnwrap(harness.session(for: device))
        session.stateOnNextRequiredCIDSet = .active
        var results: [M720TemporaryPolicyResult] = []
        XCTAssertTrue(harness.controller.beginTemporaryPolicyLease(
            ownerID: UUID(),
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { results.append($0) }
        ))
        XCTAssertTrue(results.isEmpty)

        session.stateOnNextRequiredCIDSet = .nativeReady
        harness.controller.reconcile(
            remaps: NSDictionary(),
            buttonsEnabled: false,
            remapsAreAddMode: true
        )
        harness.executor.runAll()

        XCTAssertEqual(results, [.failed(.cancelled)])
        XCTAssertEqual(session.requiredCIDCalls.last, [])
    }

    func testClearRequiresVerifiedCurrentSavedTargetAfterFrozenRollback() {
        let harness = M720ControllerHarness()
        harness.controller.reconcile(
            remaps: makeControllerRemaps(buttons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let device = harness.makeDevice(snapshot: .m720(registryEntryID: 90, serialNumber: "finish"))
        harness.controller.deviceDidAttach(device)
        let session = try! XCTUnwrap(harness.session(for: device))
        let owner = UUID()
        session.stateOnNextRequiredCIDSet = .active
        XCTAssertTrue(harness.controller.beginTemporaryPolicyLease(
            ownerID: owner,
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { XCTAssertEqual($0, .ready) }
        ))
        harness.executor.runAll()
        harness.controller.reconcile(
            remaps: makeControllerRemaps(buttons: [8]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )

        session.stateOnNextRequiredCIDSet = .active
        XCTAssertTrue(harness.controller.restoreTemporaryPolicyLease(
            ownerID: owner,
            completion: { XCTAssertEqual($0, .ready) }
        ))
        harness.executor.runAll()
        XCTAssertEqual(session.requiredCIDCalls.last, Set([0x005B]))
        XCTAssertFalse(harness.controller.clearTemporaryPolicyLease(ownerID: owner))

        session.stateOnNextRequiredCIDSet = .active
        XCTAssertTrue(harness.controller.updateTemporaryPolicyLeaseToCurrentSaved(
            ownerID: owner,
            completion: { XCTAssertEqual($0, .ready) }
        ))
        harness.executor.runAll()
        XCTAssertEqual(session.requiredCIDCalls.last, Set([0x00D0]))
        XCTAssertTrue(harness.controller.clearTemporaryPolicyLease(ownerID: owner))
    }

    func testAttachAndRemovalAdvanceRevisionAndNewTokenNeverInheritsLease() {
        let harness = M720ControllerHarness()
        harness.controller.reconcile(
            remaps: makeControllerRemaps(buttons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        var changes: [M720PreparationContextChange] = []
        harness.controller.onPreparationContextChange = { changes.append($0) }
        let first = harness.makeDevice(snapshot: .m720(registryEntryID: 100, serialNumber: "one"))
        harness.controller.deviceDidAttach(first)
        let firstSession = try! XCTUnwrap(harness.session(for: first))
        firstSession.stateOnNextRequiredCIDSet = .active
        XCTAssertTrue(harness.controller.beginTemporaryPolicyLease(
            ownerID: UUID(),
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { XCTAssertEqual($0, .ready) }
        ))
        harness.executor.runAll()

        let second = harness.makeDevice(snapshot: .m720(registryEntryID: 101, serialNumber: "two"))
        harness.controller.deviceDidAttach(second)
        let secondSession = try! XCTUnwrap(harness.session(for: second))
        XCTAssertEqual(secondSession.requiredCIDCalls.first, Set([0x005B]))
        let afterAttach = harness.controller.capturePreparationSnapshot().deviceSetRevision

        harness.controller.prepareForDeviceRemoval(first) {}
        harness.executor.runAll()
        let afterRemovalStart = harness.controller.capturePreparationSnapshot().deviceSetRevision
        XCTAssertGreaterThan(afterRemovalStart, afterAttach)
        XCTAssertEqual(changes.filter { $0.isDeviceSetChange }.count, 3)
    }

    func testDeviceSetChangeFencesQueuedReadyAndLateStableCompletion() {
        let harness = M720ControllerHarness()
        harness.controller.reconcile(
            remaps: NSDictionary(),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let first = harness.makeDevice(snapshot: .m720(registryEntryID: 105, serialNumber: "old"))
        harness.controller.deviceDidAttach(first)
        let session = try! XCTUnwrap(harness.session(for: first))
        session.stateOnNextRequiredCIDSet = .active
        var results: [M720TemporaryPolicyResult] = []
        XCTAssertTrue(harness.controller.beginTemporaryPolicyLease(
            ownerID: UUID(),
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { results.append($0) }
        ))

        let second = harness.makeDevice(snapshot: .m720(registryEntryID: 106, serialNumber: "new"))
        harness.controller.deviceDidAttach(second)
        session.emit(.active)
        harness.executor.runAll()

        XCTAssertEqual(results, [.failed(.deviceSetChanged)])
    }

    func testRemovalDuringRollbackDoesNotBlockOwnerFromRetryingLiveIntersection() {
        let harness = M720ControllerHarness()
        harness.controller.reconcile(
            remaps: makeControllerRemaps(buttons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let first = harness.makeDevice(snapshot: .m720(registryEntryID: 107, serialNumber: "stay"))
        let second = harness.makeDevice(snapshot: .m720(registryEntryID: 108, serialNumber: "leave"))
        harness.controller.deviceDidAttach(first)
        harness.controller.deviceDidAttach(second)
        let firstSession = try! XCTUnwrap(harness.session(for: first))
        let secondSession = try! XCTUnwrap(harness.session(for: second))
        let owner = UUID()
        firstSession.stateOnNextRequiredCIDSet = .active
        secondSession.stateOnNextRequiredCIDSet = .active
        XCTAssertTrue(harness.controller.beginTemporaryPolicyLease(
            ownerID: owner,
            snapshot: harness.controller.capturePreparationSnapshot(),
            targetCIDs: allTargets,
            completion: { XCTAssertEqual($0, .ready) }
        ))
        harness.executor.runAll()

        firstSession.stateOnNextRequiredCIDSet = .active
        secondSession.stateOnNextRequiredCIDSet = .takingOver
        var firstRollbackResults: [M720TemporaryPolicyResult] = []
        XCTAssertTrue(harness.controller.restoreTemporaryPolicyLease(
            ownerID: owner,
            completion: { firstRollbackResults.append($0) }
        ))

        harness.controller.prepareForDeviceRemoval(second) {}
        var retriedRollbackResults: [M720TemporaryPolicyResult] = []
        firstSession.stateOnNextRequiredCIDSet = .active
        XCTAssertTrue(harness.controller.restoreTemporaryPolicyLease(
            ownerID: owner,
            completion: { retriedRollbackResults.append($0) }
        ))
        harness.executor.runAll()

        XCTAssertEqual(firstRollbackResults, [.failed(.deviceSetChanged)])
        XCTAssertEqual(retriedRollbackResults, [.ready])
        XCTAssertTrue(harness.controller.clearTemporaryPolicyLease(ownerID: owner))
    }

    func testAcceptedRetryForcesOneCorrelatedStablePublicationDespiteDedupe() {
        let requestID = UUID()
        let token = UUID()
        let harness = M720ControllerHarness(tokens: [token])
        harness.controller.reconcile(
            remaps: makeControllerRemaps(buttons: [6]),
            buttonsEnabled: true,
            remapsAreAddMode: false
        )
        let device = harness.makeDevice(snapshot: .m720(registryEntryID: 110, serialNumber: "retry"))
        harness.controller.deviceDidAttach(device)
        let session = try! XCTUnwrap(harness.session(for: device))
        session.emit(.conflict)
        session.retryAccepted = true

        XCTAssertTrue(harness.controller.retryCapture(deviceToken: token, requestID: requestID))
        session.emit(.conflict)
        session.emit(.conflict)

        XCTAssertEqual(harness.publishedStates.filter { $0.requestID == requestID }.count, 1)
        XCTAssertEqual(harness.publishedStates.last?.deviceToken, token)
    }

    func testRejectedRetryPublishesNoCorrelatedState() {
        let requestID = UUID()
        let token = UUID()
        let harness = M720ControllerHarness(tokens: [token])
        let device = harness.makeDevice(snapshot: .m720(registryEntryID: 120, serialNumber: "reject"))
        harness.controller.deviceDidAttach(device)
        let session = try! XCTUnwrap(harness.session(for: device))
        session.retryAccepted = false

        XCTAssertFalse(harness.controller.retryCapture(deviceToken: token, requestID: requestID))
        session.emit(.invalid(.protocol))
        XCTAssertTrue(harness.publishedStates.allSatisfy { $0.requestID == nil })
    }

    func testRemovalConsumesAcceptedRetryWithOneCorrelatedDisconnectedPublication() {
        let requestID = UUID()
        let token = UUID()
        let harness = M720ControllerHarness(tokens: [token])
        let device = harness.makeDevice(snapshot: .m720(registryEntryID: 130, serialNumber: "remove"))
        harness.controller.deviceDidAttach(device)
        let session = try! XCTUnwrap(harness.session(for: device))
        session.retryAccepted = true
        XCTAssertTrue(harness.controller.retryCapture(deviceToken: token, requestID: requestID))

        harness.controller.prepareForDeviceRemoval(device) {}
        session.completeInvalidation()
        session.completeInvalidation()

        let correlated = harness.publishedStates.filter { $0.requestID == requestID }
        XCTAssertEqual(correlated.count, 1)
        XCTAssertEqual(correlated.single?.state, .invalid(.disconnected))
    }
}

private final class M720ControllerHarness {
    struct FactoryCall {
        let device: Device
        let snapshot: M720DeviceSnapshot
        let journalIdentityUsable: Bool
        let session: FakeM720Session
    }

    let trace = M720ControllerTrace()
    let executor = M720ManualExecutor()
    private(set) var factoryCalls: [FactoryCall] = []
    private(set) var publishedStates: [M720ControllerSessionSnapshot] = []
    private var snapshots: [ObjectIdentifier: M720DeviceSnapshot] = [:]
    private var identityReadCounts: [ObjectIdentifier: Int] = [:]
    private var tokens: [UUID]
    private let workspaceCenter: NotificationCenter

    lazy var controller = M720HIDPPController(
        identityProvider: { [unowned self] device in
            let identity = ObjectIdentifier(device)
            self.identityReadCounts[identity, default: 0] += 1
            if let snapshot = self.snapshots[identity] {
                self.trace.append("snapshot:\(snapshot.registryEntryID)")
                return snapshot
            }
            self.trace.append("snapshot:nil")
            return nil
        },
        sessionFactory: { [unowned self] device, snapshot, journalIdentityUsable in
            let session = FakeM720Session(trace: self.trace)
            self.factoryCalls.append(FactoryCall(
                device: device,
                snapshot: snapshot,
                journalIdentityUsable: journalIdentityUsable,
                session: session
            ))
            self.trace.append("factory:\(snapshot.registryEntryID):\(journalIdentityUsable)")
            return session
        },
        tokenFactory: { [unowned self] in
            self.tokens.isEmpty ? UUID() : self.tokens.removeFirst()
        },
        enqueueStart: { [unowned self] block in
            self.executor.enqueue(block)
        },
        stableStateObserver: { [unowned self] snapshot in
            self.publishedStates.append(snapshot)
        },
        workspaceCenter: workspaceCenter
    )

    init(
        tokens: [UUID] = [],
        workspaceCenter: NotificationCenter = NotificationCenter()
    ) {
        self.tokens = tokens
        self.workspaceCenter = workspaceCenter
    }

    func makeDevice(snapshot: M720DeviceSnapshot?) -> Device {
        let device = Device.unitTestDevice()
        setSnapshot(snapshot, for: device)
        return device
    }

    func setSnapshot(_ snapshot: M720DeviceSnapshot?, for device: Device) {
        snapshots[ObjectIdentifier(device)] = snapshot
    }

    func identityReadCount(for device: Device) -> Int {
        identityReadCounts[ObjectIdentifier(device), default: 0]
    }

    func session(for device: Device) -> FakeM720Session? {
        factoryCalls.last { $0.device === device }?.session
    }
}

private extension M720DeviceSnapshot {
    static func m720(
        registryEntryID: UInt64,
        productID: Int = M720Profile.bluetoothLEProductID,
        serialNumber: String?,
        physicalDeviceUniqueID: String? = nil
    ) -> M720DeviceSnapshot {
        M720DeviceSnapshot(
            registryEntryID: registryEntryID,
            vendorID: M720Profile.vendorID,
            productID: productID,
            transport: M720Profile.bluetoothLETransport,
            serialNumber: serialNumber,
            physicalDeviceUniqueID: physicalDeviceUniqueID
        )
    }
}

private final class FakeM720Session: M720SessionControlling {
    private(set) var state: M720SessionState = .discovering
    private(set) var requiredCIDs: Set<UInt16> = []
    var onStateChange: ((M720SessionState) -> Void)?

    private(set) var requiredCIDCalls: [Set<UInt16>] = []
    private(set) var startCallCount = 0
    private(set) var markIdentityUnusableCallCount = 0
    private(set) var prepareForSleepCallCount = 0
    private(set) var reconcileAfterWakeCallCount = 0
    private(set) var knownOwnershipAgentLaunchCallCount = 0
    private(set) var shutdownCallCount = 0
    private(set) var shutdownDeadlineCallCount = 0
    private(set) var invalidateCallCount = 0
    private(set) var retryRequestIDs: [UUID?] = []
    var retryAccepted = false
    var stateOnNextRequiredCIDSet: M720SessionState?
    private(set) var lifecycleCallbacksWereOnMain: [Bool] = []

    private let trace: M720ControllerTrace
    private var shutdownCompletions: [() -> Void] = []
    private var invalidationCompletions: [() -> Void] = []

    init(trace: M720ControllerTrace) {
        self.trace = trace
    }

    func start() {
        startCallCount += 1
        trace.append("start")
    }

    func setRequiredCIDs(_ cids: Set<UInt16>) {
        requiredCIDs = cids
        requiredCIDCalls.append(cids)
        if let nextState = stateOnNextRequiredCIDSet {
            state = nextState
            stateOnNextRequiredCIDSet = nil
        }
        let rendered = cids.sorted().map { String(format: "%04x", $0) }.joined(separator: ",")
        trace.append("set:\(rendered)")
    }

    func markJournalIdentityUnusable() {
        markIdentityUnusableCallCount += 1
        trace.append("identity-unusable")
    }

    func prepareForSleep(completion: @escaping () -> Void) {
        prepareForSleepCallCount += 1
        lifecycleCallbacksWereOnMain.append(Thread.isMainThread)
        completion()
    }

    func reconcileAfterWake() {
        reconcileAfterWakeCallCount += 1
        lifecycleCallbacksWereOnMain.append(Thread.isMainThread)
    }

    func knownOwnershipAgentDidLaunch() {
        knownOwnershipAgentLaunchCallCount += 1
        lifecycleCallbacksWereOnMain.append(Thread.isMainThread)
    }

    func shutdown(completion: @escaping () -> Void) {
        shutdownCallCount += 1
        shutdownCompletions.append(completion)
    }

    func shutdownDeadlineReached() {
        shutdownDeadlineCallCount += 1
    }

    func invalidateForRemoval(completion: @escaping () -> Void) {
        invalidateCallCount += 1
        invalidationCompletions.append(completion)
    }

    func retryAfterConflict(requestID: UUID?) -> Bool {
        retryRequestIDs.append(requestID)
        return retryAccepted
    }

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
        invalidationCompletions.forEach { $0() }
    }
}

private extension Array {
    var single: Element? {
        count == 1 ? self[0] : nil
    }
}

private func makeControllerRemaps(buttons: [Int]) -> NSDictionary {
    let modification = NSMutableDictionary()
    for button in buttons {
        modification.setObject(NSDictionary(), forKey: NSNumber(value: button))
    }
    let remaps = NSMutableDictionary()
    remaps.setObject(modification, forKey: NSDictionary())
    return remaps
}

private final class M720ManualExecutor {
    private var blocks: [() -> Void] = []
    var pendingCount: Int { blocks.count }

    func enqueue(_ block: @escaping () -> Void) {
        blocks.append(block)
    }

    func runAll() {
        while !blocks.isEmpty {
            blocks.removeFirst()()
        }
    }
}

private final class M720ControllerTrace {
    private(set) var events: [String] = []

    func append(_ event: String) {
        events.append(event)
    }
}
