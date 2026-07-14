import IOKit
import XCTest
@testable import Mac_Mouse_Fix_Helper

final class M720HIDPPSessionTests: XCTestCase {
    func testDiscoveryStartsWithExactRootFeatureRequest() throws {
        let harness = M720SessionHarness()

        harness.session.start()
        drainMainQueue(turns: 3)

        let request = [UInt8](try XCTUnwrap(harness.transport.sent.first))
        XCTAssertEqual(harness.transport.sent.count, 1)
        XCTAssertEqual(request[2], 0x00)
        XCTAssertEqual(request[3] >> 4, 0)
        XCTAssertEqual(Array(request[4...5]), [0x1B, 0x04])
    }

    func testDiscoveryReadsEveryAdvertisedRowBeforeAllTargetReportingSnapshots() throws {
        let harness = M720SessionHarness()
        let rows = referenceRows

        harness.session.start()
        driveDiscovery(harness, rows: rows)

        XCTAssertEqual(harness.requestKinds, [
            .rootGetFeature,
            .getCount,
        ] + rows.indices.map(M720TestRequestKind.getCidInfo) + [
            .getCidReporting(0x005B),
            .getCidReporting(0x005D),
            .getCidReporting(0x00D0),
        ])
        XCTAssertEqual(harness.semanticRequests, [
            M720SemanticRequest(featureIndex: 0x00, function: 0, parameters: wireParameters([0x1B, 0x04])),
            M720SemanticRequest(featureIndex: 0x2A, function: 0, parameters: wireParameters([])),
        ] + rows.indices.map {
            M720SemanticRequest(featureIndex: 0x2A, function: 1, parameters: wireParameters([UInt8($0)]))
        } + [
            M720SemanticRequest(featureIndex: 0x2A, function: 2, parameters: wireParameters([0x00, 0x5B])),
            M720SemanticRequest(featureIndex: 0x2A, function: 2, parameters: wireParameters([0x00, 0x5D])),
            M720SemanticRequest(featureIndex: 0x2A, function: 2, parameters: wireParameters([0x00, 0xD0])),
        ])
        XCTAssertEqual(harness.session.state, .nativeReady)
        XCTAssertTrue(harness.requestKinds.allSatisfy { kind in
            if case .setCidReporting = kind { return false }
            return true
        })
    }

    func testDiscoveryRejectsCountThirtyThreeWithoutAnySetRequest() {
        let harness = M720SessionHarness()
        let rows = (0..<33).map { offset in
            control(UInt16(0x0100 + offset), flags: 0x21)
        }

        harness.session.start()
        driveDiscovery(harness, rows: rows)

        XCTAssertEqual(harness.requestKinds, [.rootGetFeature, .getCount])
        XCTAssertEqual(harness.session.state, .invalid(.protocol))
        XCTAssertFalse(harness.requestKinds.contains { kind in
            if case .setCidReporting = kind { return true }
            return false
        })
    }

    func testDiscoveryHandlesZeroAndMaximumAdvertisedRowsAtTheProtocolBoundary() {
        let emptyHarness = M720SessionHarness()
        emptyHarness.session.start()
        driveDiscovery(emptyHarness, rows: [])
        XCTAssertEqual(emptyHarness.requestKinds, [.rootGetFeature, .getCount])
        XCTAssertEqual(emptyHarness.session.state, .invalid(.unsupported))
        assertNoSet(emptyHarness)

        let maximumHarness = M720SessionHarness()
        let maximumRows = referenceRows + (0..<23).map { offset in
            control(UInt16(0x0200 + offset), flags: 0x01)
        }
        XCTAssertEqual(maximumRows.count, 32)
        maximumHarness.session.start()
        driveDiscovery(maximumHarness, rows: maximumRows)
        XCTAssertEqual(
            maximumHarness.requestKinds.filter {
                if case .getCidInfo = $0 { return true }
                return false
            }.count,
            32
        )
        XCTAssertEqual(maximumHarness.session.state, .nativeReady)
        assertNoSet(maximumHarness)
    }

    func testDiscoveryRejectsDuplicateCIDAfterReadingThatRowWithoutSet() {
        let harness = M720SessionHarness()
        let rows = referenceRows + [referenceRows[0]]

        harness.session.start()
        driveDiscovery(harness, rows: rows)

        XCTAssertEqual(harness.session.state, .invalid(.protocol))
        XCTAssertEqual(harness.requestKinds.last, .getCidInfo(rows.count - 1))
        assertNoSet(harness)
    }

    func testDiscoveryRejectsMissingTargetAndMissingTargetCapabilitiesWithoutSet() {
        let missingTargetHarness = M720SessionHarness()
        let missingTargetRows = referenceRows.filter { $0.cid != 0x00D0 }
        missingTargetHarness.session.start()
        driveDiscovery(missingTargetHarness, rows: missingTargetRows)
        XCTAssertEqual(missingTargetHarness.session.state, .invalid(.unsupported))
        XCTAssertEqual(missingTargetHarness.requestKinds.last, .getCidInfo(missingTargetRows.count - 1))
        assertNoSet(missingTargetHarness)

        for invalidFlags: UInt8 in [0x20, 0x01] {
            let harness = M720SessionHarness()
            let rows = referenceRows.map { row in
                row.cid == 0x005D ? control(row.cid, flags: invalidFlags) : row
            }
            harness.session.start()
            driveDiscovery(harness, rows: rows)
            XCTAssertEqual(harness.session.state, .invalid(.unsupported))
            XCTAssertEqual(harness.requestKinds.last, .getCidInfo(rows.count - 1))
            assertNoSet(harness)
        }
    }

    func testDiscoveryRejectsWrongReportingCIDEchoWithoutSet() {
        let harness = M720SessionHarness()

        harness.session.start()
        driveDiscovery(
            harness,
            rows: referenceRows,
            reportingOverrides: [
                0x005B: HIDPPReportingState(cid: 0x005D, flags: 0, remappedCID: 0x005D),
            ]
        )

        XCTAssertEqual(harness.requestKinds.last, .getCidReporting(0x005B))
        XCTAssertEqual(harness.session.state, .invalid(.protocol))
        assertNoSet(harness)
    }

    func testDiscoveryWaitsForJournalReloadBarrierAndAcceptsOffMainCallback() {
        let harness = M720SessionHarness(holdsReload: true)
        harness.session.start()
        drainMainQueue(turns: 3)

        XCTAssertEqual(harness.trace.events, [.reloadBegin])
        XCTAssertTrue(harness.transport.sent.isEmpty)
        XCTAssertEqual(harness.journal.mutationCallCount, 0)

        let callbackInvoked = expectation(description: "off-main reload callback")
        harness.journal.completeReload(on: .global(qos: .utility)) {
            callbackInvoked.fulfill()
        }
        wait(for: [callbackInvoked], timeout: 1)
        driveDiscovery(harness, rows: referenceRows)

        XCTAssertEqual(Array(harness.trace.events.prefix(3)), [
            .reloadBegin,
            .reloadComplete,
            .request(.rootGetFeature),
        ])
        XCTAssertEqual(harness.session.state, .nativeReady)
    }

    func testOffMainReloadFailureCannotMutateSessionUntilMainHop() {
        let harness = M720SessionHarness(
            reloadResult: .failure(M720JournalStoreError.uncertain),
            holdsReload: true
        )
        var stateWhenCoordinatorCallbackReturned: M720SessionState?
        var callbackWasMain = true
        var callbackWaitSucceeded = false
        var observerWasMain: [Bool] = []
        harness.session.onStateChange = { _ in
            observerWasMain.append(Thread.isMainThread)
        }
        harness.session.start()
        drainMainQueue(turns: 3)

        let callbackReturned = expectation(description: "main queue observes callback return")
        let callbackSemaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            harness.journal.completeReload(on: .global(qos: .utility)) {
                callbackWasMain = Thread.isMainThread
                callbackSemaphore.signal()
            }
            callbackWaitSucceeded = callbackSemaphore.wait(timeout: .now() + 2) == .success
            if callbackWaitSucceeded {
                stateWhenCoordinatorCallbackReturned = harness.session.state
            }
            callbackReturned.fulfill()
        }
        wait(for: [callbackReturned], timeout: 3)

        XCTAssertTrue(callbackWaitSucceeded)
        guard callbackWaitSucceeded else { return }
        XCTAssertFalse(callbackWasMain)
        XCTAssertEqual(stateWhenCoordinatorCallbackReturned, .discovering)
        drainMainQueue(turns: 3)
        XCTAssertEqual(harness.session.state, .invalid(.protocol))
        XCTAssertEqual(observerWasMain, [true])
    }

    func testNextLaunchRecoveryCoversEveryPhaseCurrentStateAndPolicyBranch() {
        let matchingKey = M720SessionHarness.defaultDeviceKey
        let cid: UInt16 = 0x005B

        for phase in [M720JournalPhase.prepared, .applied, .restoring] {
            let entry = journalEntry(cid: cid, phase: phase)
            let third = HIDPPReportingState(cid: cid, flags: 0x11, remappedCID: 0x1234)
            let currentRows: [(String, HIDPPReportingState)] = [
                ("original", entry.original),
                ("intended", entry.intended),
                ("third", third),
            ]
            for (currentName, current) in currentRows {
                for policyRequiresCapture in [false, true] {
                    let context = "phase=\(phase), current=\(currentName), policy=\(policyRequiresCapture)"
                    let journal = M720OwnershipJournal(
                        version: M720OwnershipJournal.currentVersion,
                        devices: [M720JournalDevice(key: matchingKey, controls: [entry])]
                    )
                    let harness = M720SessionHarness(initialJournal: journal)
                    if policyRequiresCapture {
                        harness.session.setRequiredCIDs([cid])
                    }
                    harness.session.start()
                    var states = baselineStates(0x005B, 0x005D, 0x00D0)
                    states[cid] = current
                    driveDiscovery(
                        harness,
                        rows: referenceRows,
                        reportingOverrides: states,
                        stopAfterDiscoverySnapshots: true
                    )
                    let recoveryStart = 2 + referenceRows.count + M720Profile.cidToButton.count
                    driveTakeover(
                        harness,
                        startingAt: recoveryStart,
                        initialStates: states
                    )

                    let setRequests = harness.requestKinds.compactMap { kind -> (UInt16, Bool)? in
                        guard case let .setCidReporting(setCID, diverted) = kind else { return nil }
                        return (setCID, diverted)
                    }
                    if current == entry.original {
                        XCTAssertEqual(
                            harness.session.state,
                            policyRequiresCapture ? .active : .nativeReady,
                            context
                        )
                        XCTAssertEqual(setRequests.map(\.0), policyRequiresCapture ? [cid] : [], context)
                        XCTAssertEqual(setRequests.map(\.1), policyRequiresCapture ? [true] : [], context)
                    } else if current == entry.intended {
                        XCTAssertEqual(
                            harness.session.state,
                            policyRequiresCapture ? .active : .nativeReady,
                            context
                        )
                        XCTAssertEqual(setRequests.map(\.0), policyRequiresCapture ? [] : [cid], context)
                        XCTAssertEqual(setRequests.map(\.1), policyRequiresCapture ? [] : [false], context)
                    } else {
                        XCTAssertEqual(harness.session.state, .conflict, context)
                        XCTAssertTrue(setRequests.isEmpty, context)
                    }

                    if harness.session.state == .active {
                        XCTAssertEqual(
                            harness.journal.currentJournal.devices.first?.controls,
                            [journalEntry(cid: cid, phase: .applied)],
                            context
                        )
                    } else if harness.session.state == .conflict {
                        XCTAssertEqual(harness.journal.currentJournal, journal, context)
                    } else {
                        XCTAssertEqual(harness.journal.currentJournal, .emptyV1, context)
                    }
                }
            }
        }
    }

    func testRecoveryReadsAndClassifiesWholeJournalBeforeRestoringOwnedSiblingsOnConflict() {
        let entries = [
            journalEntry(cid: 0x005B, phase: .applied),
            journalEntry(cid: 0x005D, phase: .prepared),
            journalEntry(cid: 0x00D0, phase: .restoring),
        ]
        let journal = M720OwnershipJournal(
            version: M720OwnershipJournal.currentVersion,
            devices: [M720JournalDevice(
                key: M720SessionHarness.defaultDeviceKey,
                controls: entries
            )]
        )
        let harness = M720SessionHarness(initialJournal: journal)
        harness.session.setRequiredCIDs(Set(M720Profile.cidToButton.keys))
        harness.session.start()
        let external = HIDPPReportingState(cid: 0x00D0, flags: 0x11, remappedCID: 0x4321)
        let states: [UInt16: HIDPPReportingState] = [
            0x005B: entries[0].intended,
            0x005D: entries[1].intended,
            0x00D0: external,
        ]
        driveDiscovery(
            harness,
            rows: referenceRows,
            reportingOverrides: states,
            stopAfterDiscoverySnapshots: true
        )
        let recoveryStart = 2 + referenceRows.count + M720Profile.cidToButton.count
        driveTakeover(harness, startingAt: recoveryStart, initialStates: states)

        let firstJournalIndex = try? XCTUnwrap(
            harness.trace.events.firstIndex { event in
                if case .journal = event { return true }
                return false
            }
        )
        if let firstJournalIndex {
            let readsBeforeMutation = harness.trace.events[..<firstJournalIndex].compactMap { event -> UInt16? in
                guard case let .request(.getCidReporting(cid)) = event else { return nil }
                return cid
            }
            XCTAssertEqual(Array(readsBeforeMutation.suffix(3)), [0x005B, 0x005D, 0x00D0])
        }
        XCTAssertEqual(
            harness.requestKinds.compactMap { kind -> UInt16? in
                guard case let .setCidReporting(cid, diverted) = kind, !diverted else { return nil }
                return cid
            },
            [0x005B, 0x005D]
        )
        XCTAssertEqual(harness.session.state, .conflict)
        XCTAssertEqual(
            harness.journal.currentJournal.devices.first?.controls,
            [entries[2]]
        )
    }

    func testPolicyChangeAtHeldRecoveryMutationRestoresOldSeedBeforeReconcilingLatestPolicy() {
        let entry = journalEntry(cid: 0x005B, phase: .prepared)
        let journal = M720OwnershipJournal(
            version: M720OwnershipJournal.currentVersion,
            devices: [M720JournalDevice(
                key: M720SessionHarness.defaultDeviceKey,
                controls: [entry]
            )]
        )
        let harness = M720SessionHarness(initialJournal: journal)
        harness.session.setRequiredCIDs([entry.cid])
        harness.session.start()
        var states = baselineStates(0x005B, 0x005D, 0x00D0)
        states[entry.cid] = entry.intended
        driveDiscovery(
            harness,
            rows: referenceRows,
            reportingOverrides: states,
            stopAfterDiscoverySnapshots: true
        )
        let recoveryStart = 2 + referenceRows.count + M720Profile.cidToButton.count
        harness.journal.holdNextMutationCompletion = M720JournalFailurePoint(
            cid: entry.cid,
            phase: .applied
        )
        let recoveryRead = harness.request(at: recoveryStart)
        harness.respond(
            to: recoveryRead,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(entry.intended)
        )
        drainMainQueue(turns: 5)
        XCTAssertTrue(harness.journal.hasHeldMutationCompletion)

        harness.session.setRequiredCIDs([])
        drainMainQueue(turns: 3)
        harness.journal.completeHeldMutation()
        driveTakeover(
            harness,
            startingAt: recoveryStart + 1,
            initialStates: states
        )

        XCTAssertEqual(harness.session.state, .nativeReady)
        XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
        XCTAssertEqual(
            harness.requestKinds.compactMap { kind -> (UInt16, Bool)? in
                guard case let .setCidReporting(cid, diverted) = kind else { return nil }
                return (cid, diverted)
            }.map(\.0),
            [entry.cid]
        )
        XCTAssertEqual(
            harness.requestKinds.compactMap { kind -> Bool? in
                guard case let .setCidReporting(_, diverted) = kind else { return nil }
                return diverted
            },
            [false]
        )
    }

    func testShutdownDuringRecoveryWaitsForVerifiedRestoreBeforeFinalizing() {
        let entry = journalEntry(cid: 0x005B, phase: .prepared)
        let journal = M720OwnershipJournal(
            version: M720OwnershipJournal.currentVersion,
            devices: [M720JournalDevice(
                key: M720SessionHarness.defaultDeviceKey,
                controls: [entry]
            )]
        )
        let harness = M720SessionHarness(initialJournal: journal)
        harness.session.setRequiredCIDs([entry.cid])
        harness.session.start()
        var states = baselineStates(0x005B, 0x005D, 0x00D0)
        states[entry.cid] = entry.intended
        driveDiscovery(
            harness,
            rows: referenceRows,
            reportingOverrides: states,
            stopAfterDiscoverySnapshots: true
        )
        let recoveryStart = 2 + referenceRows.count + M720Profile.cidToButton.count
        harness.journal.holdNextMutationCompletion = M720JournalFailurePoint(
            cid: entry.cid,
            phase: .applied
        )
        harness.respond(
            to: harness.request(at: recoveryStart),
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(entry.intended)
        )
        drainMainQueue(turns: 5)
        var shutdownCompletions = 0
        harness.session.shutdown { shutdownCompletions += 1 }
        drainMainQueue(turns: 3)
        XCTAssertEqual(shutdownCompletions, 0)

        harness.journal.completeHeldMutation()
        driveTakeover(
            harness,
            startingAt: recoveryStart + 1,
            initialStates: states
        )

        XCTAssertEqual(shutdownCompletions, 1)
        XCTAssertEqual(harness.session.state, .invalid(.cancelled))
        XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
        XCTAssertEqual(
            harness.requestKinds.compactMap { kind -> Bool? in
                guard case let .setCidReporting(_, diverted) = kind else { return nil }
                return diverted
            },
            [false]
        )
    }

    func testRecoveryMutationCompareFailsClosedInsteadOfDeletingNewerOwnership() {
        let stale = journalEntry(cid: 0x005B, phase: .prepared)
        let newerOriginal = HIDPPReportingState(cid: stale.cid, flags: 0x04, remappedCID: stale.cid)
        let newer = M720JournalCIDEntry(
            cid: stale.cid,
            original: newerOriginal,
            intended: newerOriginal.changingDivert(to: true),
            phase: .prepared
        )
        let journal = M720OwnershipJournal(
            version: M720OwnershipJournal.currentVersion,
            devices: [M720JournalDevice(
                key: M720SessionHarness.defaultDeviceKey,
                controls: [stale]
            )]
        )
        let harness = M720SessionHarness(initialJournal: journal)
        harness.journal.replaceEntryBeforeNextMutation = newer
        harness.session.start()
        var states = baselineStates(0x005B, 0x005D, 0x00D0)
        states[stale.cid] = stale.original
        driveDiscovery(
            harness,
            rows: referenceRows,
            reportingOverrides: states,
            stopAfterDiscoverySnapshots: true
        )
        let recoveryStart = 2 + referenceRows.count + M720Profile.cidToButton.count
        driveTakeover(harness, startingAt: recoveryStart, initialStates: states)

        XCTAssertEqual(harness.session.state, .invalid(.protocol))
        XCTAssertEqual(harness.journal.currentJournal.devices.first?.controls, [newer])
        assertNoSet(harness)
    }

    func testRecoveredSeedIsRestoredWhenMissingRequiredCIDFailsFreshPreflight() {
        let seed = journalEntry(cid: 0x005B, phase: .applied)
        let journal = M720OwnershipJournal(
            version: M720OwnershipJournal.currentVersion,
            devices: [M720JournalDevice(
                key: M720SessionHarness.defaultDeviceKey,
                controls: [seed]
            )]
        )
        let harness = M720SessionHarness(initialJournal: journal)
        harness.session.setRequiredCIDs([0x005B, 0x005D])
        harness.session.start()
        var discoveryStates = baselineStates(0x005B, 0x005D, 0x00D0)
        discoveryStates[seed.cid] = seed.intended
        driveDiscovery(
            harness,
            rows: referenceRows,
            reportingOverrides: discoveryStates,
            stopAfterDiscoverySnapshots: true
        )
        let external5D = HIDPPReportingState(cid: 0x005D, flags: 0x11, remappedCID: 0x2222)
        var recoveryAndPreflightStates = discoveryStates
        recoveryAndPreflightStates[0x005D] = external5D
        let recoveryStart = 2 + referenceRows.count + M720Profile.cidToButton.count
        driveTakeover(
            harness,
            startingAt: recoveryStart,
            initialStates: recoveryAndPreflightStates
        )

        XCTAssertEqual(harness.session.state, .conflict)
        XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
        XCTAssertEqual(
            harness.requestKinds.compactMap { kind -> (UInt16, Bool)? in
                guard case let .setCidReporting(cid, diverted) = kind else { return nil }
                return (cid, diverted)
            }.map(\.0),
            [seed.cid]
        )
        XCTAssertEqual(
            harness.requestKinds.compactMap { kind -> Bool? in
                guard case let .setCidReporting(_, diverted) = kind else { return nil }
                return diverted
            },
            [false]
        )
    }

    func testLateConflictWhileRestoringRecoverySubsetAlsoRestoresKeptSibling() {
        let kept = journalEntry(cid: 0x005B, phase: .applied)
        let restoring = journalEntry(cid: 0x005D, phase: .applied)
        let journal = M720OwnershipJournal(
            version: M720OwnershipJournal.currentVersion,
            devices: [M720JournalDevice(
                key: M720SessionHarness.defaultDeviceKey,
                controls: [kept, restoring]
            )]
        )
        let harness = M720SessionHarness(initialJournal: journal)
        harness.session.setRequiredCIDs([kept.cid])
        harness.session.start()
        var discoveryStates = baselineStates(0x005B, 0x005D, 0x00D0)
        discoveryStates[kept.cid] = kept.intended
        discoveryStates[restoring.cid] = restoring.intended
        driveDiscovery(
            harness,
            rows: referenceRows,
            reportingOverrides: discoveryStates,
            stopAfterDiscoverySnapshots: true
        )
        let recoveryStart = 2 + referenceRows.count + M720Profile.cidToButton.count
        for offset in 0..<2 {
            let request = harness.request(at: recoveryStart + offset)
            let entry = offset == 0 ? kept : restoring
            harness.respond(
                to: request,
                responseFeatureIndex: 0x2A,
                parameters: harness.reportingParameters(entry.intended)
            )
            drainMainQueue(turns: 5)
        }
        let externalRestoring = HIDPPReportingState(
            cid: restoring.cid,
            flags: 0x11,
            remappedCID: 0x3333
        )
        var rollbackStates = discoveryStates
        rollbackStates[restoring.cid] = externalRestoring
        driveTakeover(
            harness,
            startingAt: recoveryStart + 2,
            initialStates: rollbackStates
        )

        XCTAssertEqual(harness.session.state, .conflict)
        XCTAssertEqual(
            harness.journal.currentJournal.devices.first?.controls,
            [restoring]
        )
        XCTAssertEqual(
            harness.requestKinds.compactMap { kind -> (UInt16, Bool)? in
                guard case let .setCidReporting(cid, diverted) = kind else { return nil }
                return (cid, diverted)
            }.map(\.0),
            [kept.cid]
        )
    }

    func testRecoveryRemoveUsesCASAndRetainsEntryReplacedAfterRestoreReadback() {
        let entry = journalEntry(cid: 0x005B, phase: .applied)
        let newerOriginal = HIDPPReportingState(cid: entry.cid, flags: 0x04, remappedCID: entry.cid)
        let newer = M720JournalCIDEntry(
            cid: entry.cid,
            original: newerOriginal,
            intended: newerOriginal.changingDivert(to: true),
            phase: .restoring
        )
        let journal = M720OwnershipJournal(
            version: M720OwnershipJournal.currentVersion,
            devices: [M720JournalDevice(
                key: M720SessionHarness.defaultDeviceKey,
                controls: [entry]
            )]
        )
        let harness = M720SessionHarness(initialJournal: journal)
        var sawRestoreSet = false
        harness.onRequestSent = { kind in
            switch kind {
            case let .setCidReporting(cid, diverted) where cid == entry.cid && !diverted:
                sawRestoreSet = true
            case let .getCidReporting(cid) where cid == entry.cid && sawRestoreSet:
                harness.journal.replaceEntryBeforeNextMutation = newer
            default:
                break
            }
        }
        harness.session.start()
        var states = baselineStates(0x005B, 0x005D, 0x00D0)
        states[entry.cid] = entry.intended
        driveDiscovery(
            harness,
            rows: referenceRows,
            reportingOverrides: states,
            stopAfterDiscoverySnapshots: true
        )
        let recoveryStart = 2 + referenceRows.count + M720Profile.cidToButton.count
        driveTakeover(harness, startingAt: recoveryStart, initialStates: states)

        XCTAssertEqual(harness.session.state, .invalid(.protocol))
        XCTAssertEqual(harness.journal.currentJournal.devices.first?.controls, [newer])
    }

    func testPolicyOrShutdownDuringRecoveryRestoreExpandsRollbackToEveryOwnedCID() {
        for shutdown in [false, true] {
            let kept = journalEntry(cid: 0x005B, phase: .applied)
            let restoring = journalEntry(cid: 0x005D, phase: .applied)
            let journal = M720OwnershipJournal(
                version: M720OwnershipJournal.currentVersion,
                devices: [M720JournalDevice(
                    key: M720SessionHarness.defaultDeviceKey,
                    controls: [kept, restoring]
                )]
            )
            let harness = M720SessionHarness(initialJournal: journal)
            harness.session.setRequiredCIDs([kept.cid])
            harness.session.start()
            var states = baselineStates(0x005B, 0x005D, 0x00D0)
            states[kept.cid] = kept.intended
            states[restoring.cid] = restoring.intended
            driveDiscovery(
                harness,
                rows: referenceRows,
                reportingOverrides: states,
                stopAfterDiscoverySnapshots: true
            )
            let recoveryStart = 2 + referenceRows.count + M720Profile.cidToButton.count
            for offset in 0..<2 {
                let entry = offset == 0 ? kept : restoring
                harness.respond(
                    to: harness.request(at: recoveryStart + offset),
                    responseFeatureIndex: 0x2A,
                    parameters: harness.reportingParameters(entry.intended)
                )
                drainMainQueue(turns: 5)
            }
            XCTAssertEqual(
                harness.request(at: recoveryStart + 2).kind,
                .getCidReporting(restoring.cid)
            )
            var shutdownCompletions = 0
            if shutdown {
                harness.session.shutdown { shutdownCompletions += 1 }
            } else {
                harness.session.setRequiredCIDs([])
            }
            drainMainQueue(turns: 3)
            driveTakeover(
                harness,
                startingAt: recoveryStart + 2,
                initialStates: states
            )

            XCTAssertEqual(harness.journal.currentJournal, .emptyV1, "shutdown=\(shutdown)")
            XCTAssertEqual(
                harness.requestKinds.compactMap { kind -> UInt16? in
                    guard case let .setCidReporting(cid, diverted) = kind, !diverted else { return nil }
                    return cid
                },
                [restoring.cid, kept.cid],
                "shutdown=\(shutdown)"
            )
            XCTAssertEqual(
                harness.session.state,
                shutdown ? .invalid(.cancelled) : .nativeReady,
                "shutdown=\(shutdown)"
            )
            XCTAssertEqual(shutdownCompletions, shutdown ? 1 : 0)
        }
    }

    func testActiveOwnershipVerificationUsesFourExactFiniteOffsets() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B, 0x005D, 0x00D0)
        )
        XCTAssertEqual(harness.session.state, .active)

        let verificationStart = harness.transport.sent.count
        XCTAssertEqual(harness.scheduler.pendingDeadlines, [0, 0.25, 2, 10])
        guard harness.scheduler.pendingDeadlines == [0, 0.25, 2, 10] else { return }
        let intended = divertedStates(0x005B)[0x005B]!
        for (offset, deadline) in [0.0, 0.25, 2.0, 10.0].enumerated() {
            harness.scheduler.advance(to: deadline)
            drainMainQueue(turns: 4)
            let requestIndex = verificationStart + offset
            XCTAssertGreaterThan(harness.transport.sent.count, requestIndex)
            guard harness.transport.sent.count > requestIndex else { return }
            let request = harness.request(at: requestIndex)
            XCTAssertEqual(request.kind, .getCidReporting(0x005B))
            harness.respond(
                to: request,
                responseFeatureIndex: 0x2A,
                parameters: harness.reportingParameters(intended)
            )
            drainMainQueue(turns: 4)
        }
        XCTAssertEqual(harness.transport.sent.count, verificationStart + 4)

        harness.scheduler.advance(to: 20)
        drainMainQueue(turns: 4)
        XCTAssertEqual(harness.transport.sent.count, verificationStart + 4)
        XCTAssertEqual(harness.session.state, .active)
    }

    func testVerificationMismatchRollsBackOwnedSiblingAndDeduplicatesConflict() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B, 0x005D])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B, 0x005D, 0x00D0)
        )
        XCTAssertEqual(harness.session.state, .active)
        var conflictTransitions = 0
        harness.session.onStateChange = { state in
            if state == .conflict { conflictTransitions += 1 }
        }

        let verificationStart = harness.transport.sent.count
        harness.session.verifyOwnership()
        drainMainQueue(turns: 4)
        let external5B = HIDPPReportingState(cid: 0x005B, flags: 0x11, remappedCID: 0x4444)
        driveTakeover(
            harness,
            startingAt: verificationStart,
            initialStates: [
                0x005B: external5B,
                0x005D: divertedStates(0x005D)[0x005D]!,
            ]
        )

        XCTAssertEqual(harness.session.state, .conflict)
        XCTAssertEqual(conflictTransitions, 1)
        XCTAssertEqual(
            harness.requestKinds[verificationStart...].compactMap { kind -> UInt16? in
                guard case let .setCidReporting(cid, diverted) = kind, !diverted else { return nil }
                return cid
            },
            [0x005D]
        )
        XCTAssertEqual(
            harness.journal.currentJournal.devices.first?.controls.map(\.cid),
            [0x005B]
        )

        let requestCountAtConflict = harness.transport.sent.count
        harness.session.verifyOwnership()
        harness.scheduler.advance(to: 20)
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.transport.sent.count, requestCountAtConflict)
        XCTAssertEqual(conflictTransitions, 1)
    }

    func testVerificationOriginalThenRollbackIntendedNeverOverwritesNewOwner() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        let verificationStart = harness.transport.sent.count
        harness.session.verifyOwnership()
        drainMainQueue(turns: 5)
        harness.respond(
            to: harness.request(at: verificationStart),
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(baselineStates(0x005B)[0x005B]!)
        )
        driveTakeover(
            harness,
            startingAt: verificationStart + 1,
            initialStates: divertedStates(0x005B)
        )

        XCTAssertEqual(harness.session.state, .conflict)
        XCTAssertFalse(harness.requestKinds[(verificationStart + 1)...].contains {
            if case .setCidReporting = $0 { return true }
            return false
        })
        XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
    }

    func testWakeOriginalThenRollbackIntendedNeverOverwritesNewOwner() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        harness.session.prepareForSleep {}
        drainMainQueue(turns: 5)
        let wakeStart = harness.transport.sent.count
        harness.session.reconcileAfterWake()
        drainMainQueue(turns: 3)
        harness.scheduler.advance(to: harness.scheduler.now)
        drainMainQueue(turns: 5)
        harness.respond(
            to: harness.request(at: wakeStart),
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(baselineStates(0x005B)[0x005B]!)
        )
        driveTakeover(
            harness,
            startingAt: wakeStart + 1,
            initialStates: divertedStates(0x005B)
        )

        XCTAssertEqual(harness.session.state, .conflict)
        XCTAssertFalse(harness.requestKinds[(wakeStart + 1)...].contains {
            if case .setCidReporting = $0 { return true }
            return false
        })
        XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
    }

    func testTakeoverAppliedMutationUsesCASAndNeverPublishesOverNewerJournalEntry() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        drainMainQueue(turns: 4)
        let baseline = baselineStates(0x005B)[0x005B]!
        let intended = baseline.changingDivert(to: true)

        let preflight = harness.request(at: takeoverStart)
        harness.respond(
            to: preflight,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(baseline)
        )
        drainMainQueue(turns: 5)
        let set = harness.request(at: takeoverStart + 1)
        harness.respond(
            to: set,
            responseFeatureIndex: 0x2A,
            parameters: ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: true)
        )
        drainMainQueue(turns: 4)

        let newerOriginal = HIDPPReportingState(cid: 0x005B, flags: 0x04, remappedCID: 0x005B)
        let newer = M720JournalCIDEntry(
            cid: 0x005B,
            original: newerOriginal,
            intended: newerOriginal.changingDivert(to: true),
            phase: .prepared
        )
        harness.journal.replaceEntryBeforeNextMutation = newer
        let readback = harness.request(at: takeoverStart + 2)
        harness.respond(
            to: readback,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(intended)
        )
        drainMainQueue(turns: 5)
        driveTakeover(
            harness,
            startingAt: takeoverStart + 3,
            initialStates: [0x005B: intended]
        )

        XCTAssertEqual(harness.session.state, .invalid(.protocol))
        XCTAssertNotEqual(harness.session.state, .active)
        XCTAssertEqual(harness.journal.currentJournal.devices.first?.controls, [newer])
    }

    func testVerificationCoalescesSlowChecksToOnePendingCycle() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B, 0x005D, 0x00D0)
        )
        let verificationStart = harness.transport.sent.count
        harness.session.verifyOwnership()
        harness.session.verifyOwnership()
        harness.session.verifyOwnership()
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.transport.sent.count, verificationStart + 1)

        let intended = divertedStates(0x005B)[0x005B]!
        harness.respond(
            to: harness.request(at: verificationStart),
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(intended)
        )
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.transport.sent.count, verificationStart + 2)
        harness.respond(
            to: harness.request(at: verificationStart + 1),
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(intended)
        )
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.transport.sent.count, verificationStart + 2)
        XCTAssertEqual(harness.session.state, .active)
    }

    func testCompletedVerificationTimersAreReleasedAcrossRepeatedSequences() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        var responseIndex = harness.transport.sent.count
        let intended = divertedStates(0x005B)[0x005B]!

        for _ in 0..<12 {
            harness.scheduler.advance(by: 2.01)
            harness.session.knownOwnershipAgentDidLaunch()
            drainMainQueue(turns: 5)
            while responseIndex < harness.transport.sent.count {
                let request = harness.request(at: responseIndex)
                XCTAssertEqual(request.kind, .getCidReporting(0x005B))
                harness.respond(
                    to: request,
                    responseFeatureIndex: 0x2A,
                    parameters: harness.reportingParameters(intended)
                )
                responseIndex += 1
                drainMainQueue(turns: 5)
            }
            XCTAssertLessThanOrEqual(harness.session.pendingVerificationTimerCount, 20)
        }

        harness.scheduler.advance(by: 11)
        drainMainQueue(turns: 6)
        while responseIndex < harness.transport.sent.count {
            let request = harness.request(at: responseIndex)
            harness.respond(
                to: request,
                responseFeatureIndex: 0x2A,
                parameters: harness.reportingParameters(intended)
            )
            responseIndex += 1
            drainMainQueue(turns: 5)
        }
        XCTAssertEqual(harness.session.pendingVerificationTimerCount, 0)
        XCTAssertEqual(harness.session.state, .active)
    }

    func testKnownAgentAndForeignSetTriggersAreRateLimitedButForeignGetIsIgnored() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B, 0x005D, 0x00D0)
        )
        XCTAssertEqual(harness.scheduler.pendingDeadlines, [0, 0.25, 2, 10])

        harness.session.knownOwnershipAgentDidLaunch()
        drainMainQueue(turns: 3)
        XCTAssertEqual(harness.scheduler.pendingDeadlines, [0, 0.25, 2, 10])

        harness.scheduler.advance(to: 2.1)
        drainMainQueue(turns: 4)
        let deadlinesBeforeForeign = harness.scheduler.pendingDeadlines
        harness.injectForeignResponse(
            featureIndex: 0x2A,
            function: ReprogControlsV4.Function.getCidReporting.rawValue
        )
        drainMainQueue(turns: 3)
        XCTAssertEqual(harness.scheduler.pendingDeadlines, deadlinesBeforeForeign)

        harness.injectForeignResponse(
            featureIndex: 0x2A,
            function: ReprogControlsV4.Function.setCidReporting.rawValue
        )
        drainMainQueue(turns: 3)
        XCTAssertEqual(
            harness.scheduler.pendingDeadlines.filter { $0 == 2.1 || $0 == 2.35 || $0 == 4.1 || $0 == 12.1 },
            [2.1, 2.35, 4.1, 12.1]
        )
        let deadlinesAfterForeign = harness.scheduler.pendingDeadlines
        harness.session.knownOwnershipAgentDidLaunch()
        drainMainQueue(turns: 3)
        XCTAssertEqual(harness.scheduler.pendingDeadlines, deadlinesAfterForeign)
    }

    func testWakeKeepsGateClosedUntilFullMatchingReadbackThenReopensIt() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B, 0x005D, 0x00D0)
        )
        var sleepCompletions = 0
        harness.session.prepareForSleep { sleepCompletions += 1 }
        drainMainQueue(turns: 5)
        XCTAssertEqual(sleepCompletions, 1)

        harness.session.reconcileAfterWake()
        drainMainQueue(turns: 3)
        harness.scheduler.advance(to: harness.scheduler.now)
        drainMainQueue(turns: 4)
        let wakeReadback = harness.request(at: harness.transport.sent.count - 1)
        XCTAssertEqual(wakeReadback.kind, .getCidReporting(0x005B))
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 4)
        XCTAssertTrue(harness.sink.emissions.isEmpty)

        harness.respond(
            to: wakeReadback,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(divertedStates(0x005B)[0x005B]!)
        )
        drainMainQueue(turns: 5)
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.sink.emissions, [M720SinkEmission(button: 6, downNotUp: true)])
    }

    func testWakeResetToOriginalDurablyClearsThenFreshlyReacquiresOwnership() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        harness.session.prepareForSleep {}
        drainMainQueue(turns: 5)
        harness.trace.removeAll()

        let wakeStart = harness.transport.sent.count
        harness.session.reconcileAfterWake()
        drainMainQueue(turns: 3)
        harness.scheduler.advance(to: harness.scheduler.now)
        drainMainQueue(turns: 5)
        let wakeReadback = harness.request(at: wakeStart)
        XCTAssertEqual(wakeReadback.kind, .getCidReporting(0x005B))
        let original = baselineStates(0x005B)[0x005B]!
        harness.respond(
            to: wakeReadback,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(original)
        )
        driveTakeover(
            harness,
            startingAt: wakeStart + 1,
            initialStates: [0x005B: original]
        )

        XCTAssertEqual(harness.session.state, .active)
        XCTAssertEqual(harness.session.appliedCIDs, [0x005B])
        let trace = harness.trace.events
        guard let clear = trace.firstIndex(of: .journal(cid: 0x005B, phase: nil)),
              let freshPreflight = trace.indices.first(where: {
                  $0 > clear && trace[$0] == .request(.getCidReporting(0x005B))
              }),
              let prepared = trace.firstIndex(of: .journal(cid: 0x005B, phase: .prepared))
        else {
            XCTFail("missing durable clear/fresh-preflight trace: \(trace)")
            return
        }
        XCTAssertLessThan(clear, freshPreflight)
        XCTAssertLessThan(freshPreflight, prepared)
        XCTAssertEqual(
            harness.requestKinds[wakeStart...].filter {
                $0 == .setCidReporting(0x005B, diverted: true)
            }.count,
            1
        )
    }

    func testWakeThirdStateConflictsWithoutOverwritingExternalState() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        harness.session.prepareForSleep {}
        drainMainQueue(turns: 5)

        let wakeStart = harness.transport.sent.count
        harness.session.reconcileAfterWake()
        drainMainQueue(turns: 3)
        harness.scheduler.advance(to: harness.scheduler.now)
        drainMainQueue(turns: 5)
        let third = HIDPPReportingState(cid: 0x005B, flags: 0x11, remappedCID: 0x4444)
        harness.respond(
            to: harness.request(at: wakeStart),
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(third)
        )
        driveTakeover(
            harness,
            startingAt: wakeStart + 1,
            initialStates: [0x005B: third]
        )

        XCTAssertEqual(harness.session.state, .conflict)
        XCTAssertFalse(harness.requestKinds[wakeStart...].contains {
            if case .setCidReporting = $0 { return true }
            return false
        })
        XCTAssertEqual(harness.journal.currentJournal.devices.first?.controls.map(\.cid), [0x005B])
    }

    func testSleepInvalidatesOldVerificationBeforeWakeAuthoritativeRead() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )

        let verificationStart = harness.transport.sent.count
        harness.session.verifyOwnership()
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.transport.sent.count, verificationStart + 1)
        let staleRead = harness.request(at: verificationStart)

        harness.session.prepareForSleep {}
        harness.session.reconcileAfterWake()
        drainMainQueue(turns: 3)
        harness.scheduler.advance(to: harness.scheduler.now)
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.transport.sent.count, verificationStart + 2)
        XCTAssertEqual(harness.request(at: verificationStart + 1).kind, .getCidReporting(0x005B))
        let third = HIDPPReportingState(cid: 0x005B, flags: 0x11, remappedCID: 0x7777)
        harness.respond(
            to: staleRead,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(third)
        )
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.session.state, .active)
    }

    func testWakeReadbackAndSleepCancelMustBothCompleteBeforeGateReopens() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 5)
        harness.sink.resetEmissions()
        harness.sink.automaticallyCompletesCancels = false
        var sleepCompletions = 0

        harness.session.prepareForSleep { sleepCompletions += 1 }
        harness.session.reconcileAfterWake()
        drainMainQueue(turns: 3)
        harness.scheduler.advance(to: harness.scheduler.now)
        drainMainQueue(turns: 6)
        let wakeReadback = harness.request(at: harness.transport.sent.count - 1)
        XCTAssertEqual(wakeReadback.kind, .getCidReporting(0x005B))
        harness.respond(
            to: wakeReadback,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(divertedStates(0x005B)[0x005B]!)
        )
        drainMainQueue(turns: 5)

        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 5)
        XCTAssertTrue(harness.sink.emissions.isEmpty)
        XCTAssertEqual(sleepCompletions, 0)

        harness.sink.completeCancel(button: 6)
        drainMainQueue(turns: 5)
        XCTAssertEqual(sleepCompletions, 1)
        let finalWakeReadback = harness.request(at: harness.transport.sent.count - 1)
        XCTAssertEqual(finalWakeReadback.kind, .getCidReporting(0x005B))
        harness.respond(
            to: finalWakeReadback,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(divertedStates(0x005B)[0x005B]!)
        )
        drainMainQueue(turns: 5)
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.sink.emissions, [M720SinkEmission(button: 6, downNotUp: true)])
    }

    func testDelayedSleepCancelForcesFinalWakeReadBeforeGateCanReopen() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 5)
        harness.sink.resetEmissions()
        harness.sink.automaticallyCompletesCancels = false
        harness.session.prepareForSleep {}
        let wakeSequenceStart = harness.scheduler.now
        harness.session.reconcileAfterWake()
        drainMainQueue(turns: 3)
        harness.scheduler.advance(to: harness.scheduler.now)
        drainMainQueue(turns: 5)
        let firstWakeRead = harness.request(at: harness.transport.sent.count - 1)
        harness.respond(
            to: firstWakeRead,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(divertedStates(0x005B)[0x005B]!)
        )
        drainMainQueue(turns: 5)

        for offset in [0.25, 2.0, 10.0] {
            let sentBeforeCheck = harness.transport.sent.count
            harness.scheduler.advance(to: wakeSequenceStart + offset)
            drainMainQueue(turns: 5)
            XCTAssertEqual(harness.transport.sent.count, sentBeforeCheck + 1)
            guard harness.transport.sent.count > sentBeforeCheck else { return }
            let followUp = harness.request(at: sentBeforeCheck)
            XCTAssertEqual(followUp.kind, .getCidReporting(0x005B))
            harness.respond(
                to: followUp,
                responseFeatureIndex: 0x2A,
                parameters: harness.reportingParameters(divertedStates(0x005B)[0x005B]!)
            )
            drainMainQueue(turns: 5)
        }
        let finalReadStart = harness.transport.sent.count
        harness.sink.completeCancel(button: 6)
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.transport.sent.count, finalReadStart + 1)
        guard harness.transport.sent.count > finalReadStart else { return }
        let finalWakeRead = harness.request(at: finalReadStart)
        XCTAssertEqual(finalWakeRead.kind, .getCidReporting(0x005B))
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 5)
        XCTAssertTrue(harness.sink.emissions.isEmpty)

        let third = HIDPPReportingState(cid: 0x005B, flags: 0x11, remappedCID: 0x4444)
        harness.respond(
            to: finalWakeRead,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(third)
        )
        driveTakeover(
            harness,
            startingAt: finalReadStart + 1,
            initialStates: [0x005B: third]
        )
        XCTAssertEqual(harness.session.state, .conflict)
        XCTAssertTrue(harness.sink.emissions.isEmpty)
    }

    func testSleepRejectsVerificationTriggersAndCannotReopenGateBeforeWake() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        harness.session.prepareForSleep {}
        drainMainQueue(turns: 5)
        let sentAtSleep = harness.transport.sent.count

        harness.session.verifyOwnership()
        harness.session.knownOwnershipAgentDidLaunch()
        drainMainQueue(turns: 5)
        harness.scheduler.advance(by: 20)
        drainMainQueue(turns: 5)

        XCTAssertEqual(harness.transport.sent.count, sentAtSleep)
        if harness.transport.sent.count > sentAtSleep {
            harness.respond(
                to: harness.request(at: sentAtSleep),
                responseFeatureIndex: 0x2A,
                parameters: harness.reportingParameters(divertedStates(0x005B)[0x005B]!)
            )
            drainMainQueue(turns: 5)
        }
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 5)
        XCTAssertTrue(harness.sink.emissions.isEmpty)
    }

    func testSleepDefersPolicyIOUntilWakeThenReconcilesLatestPolicy() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        harness.session.prepareForSleep {}
        drainMainQueue(turns: 5)
        let sentAtSleep = harness.transport.sent.count

        harness.session.setRequiredCIDs([])
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.session.state, .active)
        XCTAssertEqual(harness.transport.sent.count, sentAtSleep)
        harness.session.reconcileAfterWake()
        driveTakeover(
            harness,
            startingAt: sentAtSleep,
            initialStates: divertedStates(0x005B)
        )
        XCTAssertEqual(harness.session.state, .nativeReady)
        XCTAssertEqual(harness.session.appliedCIDs, [])
        XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
    }

    func testWakeReconcilesChangedNonemptyPolicyInsteadOfVerifyingOldAppliedSet() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B, 0x005D)
        )
        harness.session.prepareForSleep {}
        drainMainQueue(turns: 5)
        let sentAtSleep = harness.transport.sent.count

        harness.session.setRequiredCIDs([0x005D])
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.transport.sent.count, sentAtSleep)
        XCTAssertEqual(harness.session.appliedCIDs, [0x005B])

        harness.session.reconcileAfterWake()
        driveTakeover(
            harness,
            startingAt: sentAtSleep,
            initialStates: [
                0x005B: divertedStates(0x005B)[0x005B]!,
                0x005D: baselineStates(0x005D)[0x005D]!,
            ]
        )
        XCTAssertEqual(harness.session.state, .active)
        XCTAssertEqual(harness.session.appliedCIDs, [0x005D])
        XCTAssertEqual(harness.request(at: sentAtSleep).kind, .getCidReporting(0x005B))
    }

    func testRepeatedWakeNotificationDoesNotRestartVerificationSequence() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        harness.session.prepareForSleep {}
        drainMainQueue(turns: 5)

        harness.session.reconcileAfterWake()
        drainMainQueue(turns: 3)
        harness.scheduler.advance(to: harness.scheduler.now)
        drainMainQueue(turns: 4)
        let firstWakeRead = harness.request(at: harness.transport.sent.count - 1)
        harness.respond(
            to: firstWakeRead,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(divertedStates(0x005B)[0x005B]!)
        )
        drainMainQueue(turns: 5)
        let sentAfterFirstWake = harness.transport.sent.count

        harness.session.reconcileAfterWake()
        drainMainQueue(turns: 3)
        harness.scheduler.advance(to: harness.scheduler.now)
        drainMainQueue(turns: 5)

        XCTAssertEqual(harness.transport.sent.count, sentAfterFirstWake)
    }

    func testPolicyChangeDuringWakeReadSupersedesStaleVerificationAndReconciles() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B, 0x005D)
        )
        harness.session.prepareForSleep {}
        drainMainQueue(turns: 5)

        let wakeStart = harness.transport.sent.count
        harness.session.reconcileAfterWake()
        drainMainQueue(turns: 3)
        harness.scheduler.advance(to: harness.scheduler.now)
        drainMainQueue(turns: 5)
        let staleWakeRead = harness.request(at: wakeStart)

        harness.session.setRequiredCIDs([0x005D])
        drainMainQueue(turns: 6)
        XCTAssertEqual(harness.transport.sent.count, wakeStart + 2)
        XCTAssertEqual(harness.request(at: wakeStart + 1).kind, .getCidReporting(0x005B))
        harness.respond(
            to: staleWakeRead,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(divertedStates(0x005B)[0x005B]!)
        )
        driveTakeover(
            harness,
            startingAt: wakeStart + 1,
            initialStates: [
                0x005B: divertedStates(0x005B)[0x005B]!,
                0x005D: baselineStates(0x005D)[0x005D]!,
            ]
        )
        XCTAssertEqual(harness.session.state, .active)
        XCTAssertEqual(harness.session.appliedCIDs, [0x005D])
    }

    func testSecondSleepSupersedesWakeReadAndRequiresASecondWakeCycle() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        harness.session.prepareForSleep {}
        drainMainQueue(turns: 5)
        harness.session.reconcileAfterWake()
        drainMainQueue(turns: 3)
        harness.scheduler.advance(to: harness.scheduler.now)
        drainMainQueue(turns: 5)
        let firstWakeRead = harness.request(at: harness.transport.sent.count - 1)
        let sentAtSecondSleep = harness.transport.sent.count

        var secondSleepCompletions = 0
        harness.session.prepareForSleep { secondSleepCompletions += 1 }
        drainMainQueue(turns: 6)
        XCTAssertEqual(secondSleepCompletions, 1)
        harness.respond(
            to: firstWakeRead,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(divertedStates(0x005B)[0x005B]!)
        )
        drainMainQueue(turns: 5)
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 5)
        XCTAssertTrue(harness.sink.emissions.isEmpty)

        harness.session.reconcileAfterWake()
        drainMainQueue(turns: 3)
        harness.scheduler.advance(to: harness.scheduler.now)
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.transport.sent.count, sentAtSecondSleep + 1)
        XCTAssertEqual(
            harness.request(at: sentAtSecondSleep).kind,
            .getCidReporting(0x005B)
        )
    }

    func testWakeMatchCannotReopenGateAfterPolicySupersedesHeldCancel() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 5)
        harness.sink.resetEmissions()
        harness.sink.automaticallyCompletesCancels = false
        harness.session.prepareForSleep {}
        harness.session.reconcileAfterWake()
        drainMainQueue(turns: 3)
        harness.scheduler.advance(to: harness.scheduler.now)
        drainMainQueue(turns: 5)
        let wakeRead = harness.request(at: harness.transport.sent.count - 1)
        harness.respond(
            to: wakeRead,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(divertedStates(0x005B)[0x005B]!)
        )
        drainMainQueue(turns: 5)
        let rollbackStart = harness.transport.sent.count

        harness.session.setRequiredCIDs([])
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.session.state, .restoring)
        harness.sink.completeCancel(button: 6)
        drainMainQueue(turns: 5)
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 5)
        XCTAssertTrue(harness.sink.emissions.isEmpty)
        driveTakeover(
            harness,
            startingAt: rollbackStart,
            initialStates: divertedStates(0x005B)
        )
        XCTAssertEqual(harness.session.state, .nativeReady)
    }

    func testInitialOwnershipAgentScanRunsOnlyOnFirstActiveEpoch() {
        let harness = M720SessionHarness(initialOwnershipAgentIsRunning: true)
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var nextRequest = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: nextRequest,
            initialStates: baselineStates(0x005B, 0x005D, 0x00D0)
        )
        XCTAssertEqual(harness.ownershipAgentProbe.scanCount, 1)

        nextRequest = harness.transport.sent.count
        harness.session.setRequiredCIDs([])
        driveTakeover(
            harness,
            startingAt: nextRequest,
            initialStates: divertedStates(0x005B)
        )
        nextRequest = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: nextRequest,
            initialStates: baselineStates(0x005B, 0x005D, 0x00D0)
        )
        XCTAssertEqual(harness.session.state, .active)
        XCTAssertEqual(harness.ownershipAgentProbe.scanCount, 1)
    }

    func testQuarantinedJournalAutomaticPathIsReadOnlyForEmptyAndNonemptyPolicy() {
        for required in [Set<UInt16>(), Set([UInt16(0x005B)])] {
            let harness = M720SessionHarness(
                reloadResult: .failure(M720JournalStoreError.corruptFileQuarantined)
            )
            harness.session.setRequiredCIDs(required)
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)

            XCTAssertEqual(
                harness.session.state,
                required.isEmpty ? .nativeReady : .conflict,
                "required=\(required)"
            )
            XCTAssertEqual(harness.journal.mutationCallCount, 0)
            XCTAssertEqual(harness.journal.acknowledgementCallCount, 0)
            assertNoSet(harness)
        }
    }

    func testExplicitRetryAcceptsOnlyAllThreeNondivertedAndReachesFinalState() {
        for retryCanAccept in [false, true] {
            let harness = M720SessionHarness()
            harness.session.setRequiredCIDs([0x005B])
            harness.session.start()
            let unknown = HIDPPReportingState(cid: 0x005B, flags: 0x11, remappedCID: 0x5555)
            driveDiscovery(
                harness,
                rows: referenceRows,
                reportingOverrides: [0x005B: unknown]
            )
            XCTAssertEqual(harness.session.state, .conflict)
            let retryStart = harness.transport.sent.count

            XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
            drainMainQueue(turns: 5)
            var retryStates = baselineStates(0x005B, 0x005D, 0x00D0)
            if !retryCanAccept {
                retryStates[0x00D0] = HIDPPReportingState(
                    cid: 0x00D0,
                    flags: 0x11,
                    remappedCID: 0x6666
                )
            }
            driveExplicitRetryBaseline(
                harness,
                startingAt: retryStart,
                states: retryStates
            )
            XCTAssertEqual(
                Array(harness.requestKinds[retryStart..<min(
                    harness.requestKinds.count,
                    retryStart + M720Profile.cidToButton.count
                )]),
                M720Profile.cidToButton.keys.sorted().map(M720TestRequestKind.getCidReporting)
            )
            if retryCanAccept {
                let takeoverStart = retryStart + M720Profile.cidToButton.count
                driveTakeover(
                    harness,
                    startingAt: takeoverStart,
                    initialStates: retryStates
                )
            }

            XCTAssertEqual(
                harness.session.state,
                retryCanAccept ? .active : .conflict,
                "accept=\(retryCanAccept)"
            )
            if !retryCanAccept {
                XCTAssertFalse(
                    harness.requestKinds[retryStart...].contains { kind in
                        if case .setCidReporting = kind { return true }
                        return false
                    }
                )
            }
        }
    }

    func testQuarantinedJournalRetryAcknowledgesOnlyAfterCleanThreeCIDBaseline() {
        let harness = M720SessionHarness(
            reloadResult: .failure(M720JournalStoreError.quarantined)
        )
        harness.session.setRequiredCIDs([0x005B])
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        XCTAssertEqual(harness.session.state, .conflict)
        XCTAssertEqual(harness.journal.acknowledgementCallCount, 0)

        let retryStart = harness.transport.sent.count
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        let clean = baselineStates(0x005B, 0x005D, 0x00D0)
        driveExplicitRetryBaseline(harness, startingAt: retryStart, states: clean)
        let takeoverStart = retryStart + M720Profile.cidToButton.count
        driveTakeover(harness, startingAt: takeoverStart, initialStates: clean)

        XCTAssertEqual(harness.journal.acknowledgementCallCount, 1)
        XCTAssertEqual(harness.session.state, .active)
    }

    func testConcurrentQuarantineRetriesPreserveFirstSessionsJournalMutation() {
        let sharedTrace = M720SessionTraceRecorder()
        let sharedJournal = M720SessionJournalCoordinator(
            trace: sharedTrace,
            initialJournal: .emptyV1,
            reloadResult: .failure(M720JournalStoreError.quarantined),
            holdsReload: false
        )
        let keyA = M720SessionHarness.defaultDeviceKey
        let keyB = M720DeviceKey(
            vendorID: M720Profile.vendorID,
            productID: M720Profile.bluetoothLEProductID,
            transport: M720Profile.bluetoothLETransport,
            serialNumber: "quarantine-session-b"
        )
        let sessionA = M720SessionHarness(
            deviceKey: keyA,
            journalCoordinator: sharedJournal
        )
        let sessionB = M720SessionHarness(
            deviceKey: keyB,
            journalCoordinator: sharedJournal
        )
        for harness in [sessionA, sessionB] {
            harness.session.setRequiredCIDs([0x005B])
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            XCTAssertEqual(harness.session.state, .conflict)
        }

        let clean = baselineStates(0x005B, 0x005D, 0x00D0)
        let retryA = sessionA.transport.sent.count
        XCTAssertTrue(sessionA.session.retryAfterConflict(requestID: UUID()))
        driveExplicitRetryBaseline(sessionA, startingAt: retryA, states: clean)
        driveTakeover(
            sessionA,
            startingAt: retryA + M720Profile.cidToButton.count,
            initialStates: clean
        )
        XCTAssertEqual(sessionA.session.state, .active)

        let retryB = sessionB.transport.sent.count
        XCTAssertTrue(sessionB.session.retryAfterConflict(requestID: UUID()))
        driveExplicitRetryBaseline(sessionB, startingAt: retryB, states: clean)
        driveTakeover(
            sessionB,
            startingAt: retryB + M720Profile.cidToButton.count,
            initialStates: clean
        )

        XCTAssertEqual(sharedJournal.acknowledgementCallCount, 2)
        XCTAssertEqual(sharedJournal.removeDeviceCallCount, 1)
        XCTAssertEqual(sessionB.session.state, .active)
        XCTAssertEqual(
            Set(sharedJournal.currentJournal.devices.map(\.key)),
            [keyA, keyB]
        )
        XCTAssertEqual(
            sharedJournal.currentJournal.devices.first { $0.key == keyA }?.controls,
            [journalEntry(cid: 0x005B)]
        )
        XCTAssertEqual(
            sharedJournal.currentJournal.devices.first { $0.key == keyB }?.controls,
            [journalEntry(cid: 0x005B)]
        )
    }

    func testConcurrentQuarantineRetryExpectedNilCASRejectsNewerMatchingDevice() {
        let sharedTrace = M720SessionTraceRecorder()
        let sharedJournal = M720SessionJournalCoordinator(
            trace: sharedTrace,
            initialJournal: .emptyV1,
            reloadResult: .failure(M720JournalStoreError.quarantined),
            holdsReload: false
        )
        let keyA = M720SessionHarness.defaultDeviceKey
        let keyB = M720DeviceKey(
            vendorID: M720Profile.vendorID,
            productID: M720Profile.bluetoothLEProductID,
            transport: M720Profile.bluetoothLETransport,
            serialNumber: "quarantine-session-b-cas"
        )
        let sessionA = M720SessionHarness(
            deviceKey: keyA,
            journalCoordinator: sharedJournal
        )
        let sessionB = M720SessionHarness(
            deviceKey: keyB,
            journalCoordinator: sharedJournal
        )
        for harness in [sessionA, sessionB] {
            harness.session.setRequiredCIDs([0x005B])
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            XCTAssertEqual(harness.session.state, .conflict)
        }

        let clean = baselineStates(0x005B, 0x005D, 0x00D0)
        let retryA = sessionA.transport.sent.count
        XCTAssertTrue(sessionA.session.retryAfterConflict(requestID: UUID()))
        driveExplicitRetryBaseline(sessionA, startingAt: retryA, states: clean)
        driveTakeover(
            sessionA,
            startingAt: retryA + M720Profile.cidToButton.count,
            initialStates: clean
        )
        XCTAssertEqual(sessionA.session.state, .active)

        let newerB = M720JournalDevice(
            key: keyB,
            controls: [journalEntry(cid: 0x005D)]
        )
        sharedJournal.replaceDeviceBeforeNextRemove = newerB
        let retryB = sessionB.transport.sent.count
        XCTAssertTrue(sessionB.session.retryAfterConflict(requestID: UUID()))
        driveExplicitRetryBaseline(sessionB, startingAt: retryB, states: clean)

        XCTAssertEqual(sessionB.session.state, .invalid(.protocol))
        XCTAssertEqual(sharedJournal.removeDeviceCallCount, 1)
        XCTAssertEqual(
            sharedJournal.currentJournal.devices.first { $0.key == keyA }?.controls,
            [journalEntry(cid: 0x005B)]
        )
        XCTAssertEqual(
            sharedJournal.currentJournal.devices.first { $0.key == keyB },
            newerB
        )
        XCTAssertFalse(sessionB.requestKinds[retryB...].contains {
            if case .setCidReporting = $0 { return true }
            return false
        })
    }

    func testQuarantineAcknowledgementUncertainAfterPersistRecoversCurrentRetry() {
        let harness = M720SessionHarness(
            reloadResult: .failure(M720JournalStoreError.quarantined)
        )
        harness.session.setRequiredCIDs([0x005B])
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        XCTAssertEqual(harness.session.state, .conflict)
        harness.journal.acknowledgementError = M720JournalStoreError.uncertain
        harness.journal.acknowledgementFailurePersistsChange = true
        let retryStart = harness.transport.sent.count
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        let clean = baselineStates(0x005B, 0x005D, 0x00D0)
        driveExplicitRetryBaseline(harness, startingAt: retryStart, states: clean)
        driveTakeover(
            harness,
            startingAt: retryStart + M720Profile.cidToButton.count,
            initialStates: clean
        )

        XCTAssertEqual(harness.journal.acknowledgementCallCount, 1)
        XCTAssertEqual(harness.journal.removeDeviceCallCount, 1)
        XCTAssertEqual(harness.session.state, .active)
    }

    func testRetryAfterTransientInitialReloadFailureRebuildsBarrierAndIgnoresOldCallback() {
        let harness = M720SessionHarness(
            reloadResult: .failure(M720InjectedError.mutation)
        )
        harness.session.setRequiredCIDs([0x005B])
        harness.session.start()
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.session.state, .invalid(.protocol))
        XCTAssertTrue(harness.transport.sent.isEmpty)

        harness.journal.reloadResult = .success(.emptyV1)
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        drainMainQueue(turns: 5)
        XCTAssertEqual(
            harness.trace.events.filter { $0 == .reloadBegin }.count,
            2
        )
        XCTAssertEqual(harness.request(at: 0).kind, .rootGetFeature)
        let requestsBeforeStaleCallback = harness.transport.sent.count

        harness.journal.replayReloadCompletion(at: 0)
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.session.state, .discovering)
        XCTAssertEqual(harness.transport.sent.count, requestsBeforeStaleCallback)

        let clean = baselineStates(0x005B, 0x005D, 0x00D0)
        driveDiscovery(
            harness,
            rows: referenceRows,
            reportingOverrides: clean,
            stopAfterDiscoverySnapshots: true,
            featureIndex: 0x2B
        )
        let takeoverStart = 2 + referenceRows.count + M720Profile.cidToButton.count
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: clean,
            responseFeatureIndex: 0x2B
        )
        XCTAssertEqual(harness.session.state, .active)
    }

    func testRetryAfterDiscoveryInvalidFullyRediscoversAndIgnoresOldWireReply() {
        let harness = M720SessionHarness()
        harness.session.setRequiredCIDs([0x005B])
        harness.session.start()
        drainMainQueue(turns: 5)
        let staleRoot = harness.request(at: 0)
        harness.respond(
            to: staleRoot,
            responseFeatureIndex: 0,
            parameters: [0, 0, 4]
        )
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.session.state, .invalid(.unsupported))
        let retryStart = harness.transport.sent.count
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        drainMainQueue(turns: 5)
        XCTAssertGreaterThan(harness.transport.sent.count, retryStart)
        guard harness.transport.sent.count > retryStart else { return }
        XCTAssertEqual(harness.request(at: retryStart).kind, .rootGetFeature)
        harness.respond(
            to: staleRoot,
            responseFeatureIndex: 0,
            parameters: [0x55, 0, 4]
        )
        drainMainQueue(turns: 4)
        XCTAssertEqual(harness.transport.sent.count, retryStart + 1)

        let clean = baselineStates(0x005B, 0x005D, 0x00D0)
        driveDiscovery(
            harness,
            rows: referenceRows,
            reportingOverrides: clean,
            startingAt: retryStart,
            stopAfterDiscoverySnapshots: true,
            featureIndex: 0x2B
        )
        let takeoverStart = retryStart + 2 + referenceRows.count + M720Profile.cidToButton.count
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: clean,
            responseFeatureIndex: 0x2B
        )

        XCTAssertEqual(harness.session.state, .active)
        XCTAssertEqual(
            Set(harness.semanticRequests[retryStart...].dropFirst().map(\.featureIndex)),
            [0x2B]
        )
    }

    func testRetryAfterDiscoveryFailureRecoversValidMatchingJournalBeforeCleanBaselineRule() {
        let applied = journalEntry(cid: 0x005B)
        let initialJournal = M720OwnershipJournal(
            version: M720OwnershipJournal.currentVersion,
            devices: [M720JournalDevice(
                key: M720SessionHarness.defaultDeviceKey,
                controls: [applied]
            )]
        )
        let harness = M720SessionHarness(initialJournal: initialJournal)
        harness.session.setRequiredCIDs([0x005B])
        harness.session.start()
        drainMainQueue(turns: 5)
        let staleRoot = harness.request(at: 0)
        harness.respondWithDeviceError(to: staleRoot, code: 0x01)
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.session.state, .invalid(.protocol))

        let retryStart = harness.transport.sent.count
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.request(at: retryStart).kind, .rootGetFeature)
        let requestsBeforeStaleReply = harness.transport.sent.count
        harness.respond(
            to: staleRoot,
            responseFeatureIndex: 0,
            parameters: [0x55, 0, 4]
        )
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.transport.sent.count, requestsBeforeStaleReply)

        var discoveryStates = baselineStates(0x005B, 0x005D, 0x00D0)
        discoveryStates[0x005B] = applied.intended
        driveDiscovery(
            harness,
            rows: referenceRows,
            reportingOverrides: discoveryStates,
            startingAt: retryStart,
            stopAfterDiscoverySnapshots: true,
            featureIndex: 0x2B
        )

        let recoveryReadIndex = retryStart + 2 + referenceRows.count +
            M720Profile.cidToButton.count
        XCTAssertEqual(harness.session.state, .discovering)
        guard harness.transport.sent.indices.contains(recoveryReadIndex) else {
            XCTFail("matching journal must start ordinary recovery before retry acceptance")
            return
        }
        let recoveryRead = harness.request(at: recoveryReadIndex)
        XCTAssertEqual(recoveryRead.kind, .getCidReporting(0x005B))
        harness.respond(
            to: recoveryRead,
            responseFeatureIndex: 0x2B,
            parameters: harness.reportingParameters(applied.intended)
        )
        drainMainQueue(turns: 8)

        XCTAssertEqual(harness.session.state, .active)
        XCTAssertEqual(harness.session.appliedCIDs, [0x005B])
        XCTAssertEqual(harness.journal.currentJournal, initialJournal)
        XCTAssertFalse(harness.requestKinds[retryStart...].contains {
            if case .setCidReporting = $0 { return true }
            return false
        })
    }

    func testConflictRetryFailureKeepsCleanBaselineGateAcrossFullRediscovery() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B)
        )
        XCTAssertEqual(harness.session.state, .active)

        requestIndex = harness.transport.sent.count
        harness.session.verifyOwnership()
        drainMainQueue(turns: 5)
        let external = HIDPPReportingState(
            cid: 0x005B,
            flags: 0x11,
            remappedCID: 0x4444
        )
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: [0x005B: external]
        )
        XCTAssertEqual(harness.session.state, .conflict)
        let journalAtConflict = harness.journal.currentJournal

        let failedRetryStart = harness.transport.sent.count
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        drainMainQueue(turns: 5)
        let failedBaselineRead = harness.request(at: failedRetryStart)
        XCTAssertEqual(failedBaselineRead.kind, .getCidReporting(0x005B))
        harness.respondWithDeviceError(to: failedBaselineRead, code: 0x01)
        drainMainQueue(turns: 6)
        XCTAssertEqual(harness.session.state, .invalid(.protocol))

        let dirtyRetryStart = harness.transport.sent.count
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        var dirty = baselineStates(0x005B, 0x005D, 0x00D0)
        dirty[0x005D] = divertedStates(0x005D)[0x005D]!
        driveDiscovery(
            harness,
            rows: referenceRows,
            reportingOverrides: dirty,
            startingAt: dirtyRetryStart,
            stopAfterDiscoverySnapshots: true,
            featureIndex: 0x2B
        )

        XCTAssertEqual(harness.session.state, .conflict)
        XCTAssertEqual(harness.journal.currentJournal, journalAtConflict)
        XCTAssertFalse(harness.requestKinds[dirtyRetryStart...].contains {
            if case .setCidReporting = $0 { return true }
            return false
        })
        guard harness.session.state == .conflict else { return }

        let cleanRetryStart = harness.transport.sent.count
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        let clean = baselineStates(0x005B, 0x005D, 0x00D0)
        driveExplicitRetryBaseline(
            harness,
            startingAt: cleanRetryStart,
            states: clean,
            featureIndex: 0x2B
        )
        driveTakeover(
            harness,
            startingAt: cleanRetryStart + M720Profile.cidToButton.count,
            initialStates: clean,
            responseFeatureIndex: 0x2B
        )

        XCTAssertEqual(harness.journal.removeDeviceCallCount, 1)
        XCTAssertEqual(harness.session.state, .active)
    }

    func testRetryAfterCachedFeatureDiscoveryFailureAlwaysRestartsFromRoot() {
        let boundaries: [M720TestRequestKind] = [
            .getCount,
            .getCidInfo(0),
            .getCidReporting(0x005B),
        ]
        for boundary in boundaries {
            let harness = M720SessionHarness()
            harness.session.setRequiredCIDs([0x005B])
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows, until: boundary)
            let failed = harness.request(at: harness.transport.sent.count - 1)
            XCTAssertEqual(failed.kind, boundary)
            harness.respondWithDeviceError(to: failed, code: 0x01)
            drainMainQueue(turns: 6)
            XCTAssertEqual(harness.session.state, .invalid(.protocol), "\(boundary)")

            let retryStart = harness.transport.sent.count
            XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
            drainMainQueue(turns: 5)
            let newRoot = harness.request(at: retryStart)
            XCTAssertEqual(newRoot.kind, .rootGetFeature, "\(boundary)")
            harness.respond(
                to: newRoot,
                responseFeatureIndex: 0,
                parameters: [0x2B, 0, 4]
            )
            drainMainQueue(turns: 5)
            let newCount = harness.request(at: retryStart + 1)
            XCTAssertEqual(newCount.kind, .getCount, "\(boundary)")
            let sentBeforeOldFeatureReply = harness.transport.sent.count
            harness.injectForeignResponse(
                featureIndex: 0x2A,
                function: ReprogControlsV4.Function.getCount.rawValue,
                softwareID: newCount.identityByte & 0x0F
            )
            drainMainQueue(turns: 5)
            XCTAssertEqual(
                harness.transport.sent.count,
                sentBeforeOldFeatureReply,
                "\(boundary)"
            )

            let clean = baselineStates(0x005B, 0x005D, 0x00D0)
            driveDiscovery(
                harness,
                rows: referenceRows,
                reportingOverrides: clean,
                startingAt: retryStart,
                stopAfterDiscoverySnapshots: true,
                featureIndex: 0x2B
            )
            let takeoverStart = retryStart + 2 + referenceRows.count +
                M720Profile.cidToButton.count
            driveTakeover(
                harness,
                startingAt: takeoverStart,
                initialStates: clean,
                responseFeatureIndex: 0x2B
            )
            XCTAssertEqual(harness.session.state, .active, "\(boundary)")
        }
    }

    func testRetryAtomicallyClearsOnlyMatchingJournalDevice() {
        let matching = journalEntry(cid: 0x005B)
        let otherKey = M720DeviceKey(
            vendorID: M720Profile.vendorID,
            productID: M720Profile.bluetoothLEProductID,
            transport: M720Profile.bluetoothLETransport,
            serialNumber: "other-retry-device"
        )
        let otherDevice = M720JournalDevice(
            key: otherKey,
            controls: [journalEntry(cid: 0x005D)]
        )
        let initial = M720OwnershipJournal(
            version: M720OwnershipJournal.currentVersion,
            devices: [
                M720JournalDevice(
                    key: M720SessionHarness.defaultDeviceKey,
                    controls: [matching]
                ),
                otherDevice,
            ]
        )
        let harness = M720SessionHarness(initialJournal: initial)
        harness.session.setRequiredCIDs([0x005B])
        harness.session.start()
        let third = HIDPPReportingState(cid: 0x005B, flags: 0x11, remappedCID: 0x7777)
        driveDiscovery(
            harness,
            rows: referenceRows,
            reportingOverrides: [0x005B: third]
        )
        XCTAssertEqual(harness.session.state, .conflict)

        let retryStart = harness.transport.sent.count
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        let clean = baselineStates(0x005B, 0x005D, 0x00D0)
        driveExplicitRetryBaseline(harness, startingAt: retryStart, states: clean)

        XCTAssertEqual(harness.journal.removeDeviceCallCount, 1)
        XCTAssertEqual(harness.journal.currentJournal.devices, [otherDevice])
        let takeoverStart = retryStart + M720Profile.cidToButton.count
        driveTakeover(harness, startingAt: takeoverStart, initialStates: clean)
        XCTAssertEqual(harness.session.state, .active)
        XCTAssertEqual(
            harness.journal.currentJournal.devices.first(where: { $0.key == otherKey }),
            otherDevice
        )
    }

    func testRetryAtomicJournalClearFailureNeverStartsTakeover() {
        let failures: [(String, Error)] = [
            ("ordinary", M720InjectedError.mutation),
            ("uncertain", M720JournalStoreError.uncertain),
        ]
        for (name, error) in failures {
            let harness = conflictedHarness()
            harness.journal.removeDeviceError = error
            let retryStart = harness.transport.sent.count

            XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()), name)
            driveExplicitRetryBaseline(
                harness,
                startingAt: retryStart,
                states: baselineStates(0x005B, 0x005D, 0x00D0)
            )

            XCTAssertEqual(harness.session.state, .invalid(.protocol), name)
            XCTAssertEqual(harness.journal.removeDeviceCallCount, 1, name)
            XCTAssertEqual(harness.journal.mutationCallCount, 0, name)
            XCTAssertFalse(harness.requestKinds[retryStart...].contains {
                if case .setCidReporting = $0 { return true }
                return false
            }, name)
        }
    }

    func testRetryJournalClearUsesExpectedDeviceCASAndPreservesNewerEntry() {
        let harness = conflictedHarness()
        let newer = M720JournalDevice(
            key: M720SessionHarness.defaultDeviceKey,
            controls: [journalEntry(cid: 0x005D)]
        )
        harness.journal.replaceDeviceBeforeNextRemove = newer
        let retryStart = harness.transport.sent.count

        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        driveExplicitRetryBaseline(
            harness,
            startingAt: retryStart,
            states: baselineStates(0x005B, 0x005D, 0x00D0)
        )

        XCTAssertEqual(harness.session.state, .invalid(.protocol))
        XCTAssertEqual(harness.journal.currentJournal.devices, [newer])
        XCTAssertFalse(harness.requestKinds[retryStart...].contains {
            if case .setCidReporting = $0 { return true }
            return false
        })
    }

    func testRetryQuarantineAcknowledgementFailureNeverStartsTakeover() {
        let failures: [(String, Error)] = [
            ("not-quarantined", M720JournalStoreError.notQuarantined),
            ("ordinary", M720InjectedError.mutation),
        ]
        for (name, error) in failures {
            let harness = M720SessionHarness(
                reloadResult: .failure(M720JournalStoreError.quarantined)
            )
            harness.session.setRequiredCIDs([0x005B])
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            harness.journal.acknowledgementError = error
            let retryStart = harness.transport.sent.count

            XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()), name)
            driveExplicitRetryBaseline(
                harness,
                startingAt: retryStart,
                states: baselineStates(0x005B, 0x005D, 0x00D0)
            )

            XCTAssertEqual(harness.session.state, .invalid(.protocol), name)
            XCTAssertEqual(harness.journal.acknowledgementCallCount, 1, name)
            XCTAssertEqual(harness.journal.mutationCallCount, 0, name)
            XCTAssertFalse(harness.requestKinds[retryStart...].contains {
                if case .setCidReporting = $0 { return true }
                return false
            }, name)
        }
    }

    func testRejectedDivertedRetryCanBeRetriedAgainCleanly() {
        let harness = conflictedHarness()
        let firstStart = harness.transport.sent.count
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        var diverted = baselineStates(0x005B, 0x005D, 0x00D0)
        diverted[0x005D] = divertedStates(0x005D)[0x005D]!
        driveExplicitRetryBaseline(harness, startingAt: firstStart, states: diverted)
        XCTAssertEqual(harness.session.state, .conflict)

        let secondStart = harness.transport.sent.count
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        let clean = baselineStates(0x005B, 0x005D, 0x00D0)
        driveExplicitRetryBaseline(harness, startingAt: secondStart, states: clean)
        let takeoverStart = secondStart + M720Profile.cidToButton.count
        driveTakeover(harness, startingAt: takeoverStart, initialStates: clean)

        XCTAssertEqual(harness.session.state, .active)
        XCTAssertFalse(harness.requestKinds[firstStart..<secondStart].contains {
            if case .setCidReporting = $0 { return true }
            return false
        })
    }

    func testMalformedCIDAndGetFailureRetryEachReachInvalidWithoutSet() {
        for mode in ["wrong-cid", "get-failure"] {
            let harness = conflictedHarness()
            let retryStart = harness.transport.sent.count
            if mode == "get-failure" {
                harness.sendFailureKind = .getCidReporting(0x005B)
            }

            XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()), mode)
            drainMainQueue(turns: 6)
            if mode == "wrong-cid" {
                let request = harness.request(at: retryStart)
                let wrong = HIDPPReportingState(cid: 0x005D, flags: 0, remappedCID: 0x005D)
                harness.respond(
                    to: request,
                    responseFeatureIndex: 0x2A,
                    parameters: harness.reportingParameters(wrong)
                )
                drainMainQueue(turns: 6)
            }

            XCTAssertTrue({
                guard case .invalid = harness.session.state else { return false }
                return true
            }(), mode)
            XCTAssertFalse(harness.requestKinds[retryStart...].contains {
                if case .setCidReporting = $0 { return true }
                return false
            }, mode)
        }
    }

    func testRetryUsesLatestEmptyPolicyAndIgnoresDuplicateRequest() {
        let harness = conflictedHarness()
        let retryStart = harness.transport.sent.count

        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        XCTAssertFalse(harness.session.retryAfterConflict(requestID: UUID()))
        harness.session.setRequiredCIDs([])
        driveExplicitRetryBaseline(
            harness,
            startingAt: retryStart,
            states: baselineStates(0x005B, 0x005D, 0x00D0)
        )

        XCTAssertEqual(harness.session.state, .nativeReady)
        XCTAssertEqual(harness.journal.removeDeviceCallCount, 1)
        XCTAssertEqual(harness.transport.sent.count, retryStart + 3)
        XCTAssertFalse(harness.requestKinds[retryStart...].contains {
            if case .setCidReporting = $0 { return true }
            return false
        })
    }

    func testDirtyRetryWithPolicyClearedFinishesNativeButKeepsRetryLatch() {
        let harness = conflictedHarness()
        let retryStart = harness.transport.sent.count
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        harness.session.setRequiredCIDs([])
        var dirty = baselineStates(0x005B, 0x005D, 0x00D0)
        dirty[0x00D0] = divertedStates(0x00D0)[0x00D0]!
        driveExplicitRetryBaseline(harness, startingAt: retryStart, states: dirty)

        XCTAssertEqual(harness.session.state, .nativeReady)
        XCTAssertEqual(harness.journal.removeDeviceCallCount, 0)
        XCTAssertEqual(harness.journal.mutationCallCount, 0)
        let requestCount = harness.transport.sent.count

        harness.session.setRequiredCIDs([0x005B])
        drainMainQueue(turns: 5)
        XCTAssertEqual(harness.session.state, .conflict)
        XCTAssertEqual(harness.transport.sent.count, requestCount)
        XCTAssertFalse(harness.requestKinds[retryStart...].contains {
            if case .setCidReporting = $0 { return true }
            return false
        })
    }

    func testShutdownWinsRetryAndLateReadCannotMutateAfterTerminalState() {
        let harness = conflictedHarness()
        let retryStart = harness.transport.sent.count
        var shutdownCompletions = 0
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        drainMainQueue(turns: 5)
        let staleRead = harness.request(at: retryStart)

        harness.session.shutdown { shutdownCompletions += 1 }
        drainMainQueue(turns: 6)
        let mutationsAtShutdown = harness.journal.mutationCallCount
        harness.respond(
            to: staleRead,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(baselineStates(0x005B)[0x005B]!)
        )
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.session.state, .invalid(.cancelled))
        XCTAssertEqual(shutdownCompletions, 1)
        XCTAssertEqual(harness.journal.mutationCallCount, mutationsAtShutdown)
        XCTAssertEqual(harness.journal.removeDeviceCallCount, 0)
    }

    func testRemovalWinsRetryAndLateBaselineReadCannotMutateAfterTerminalState() {
        let harness = conflictedHarness()
        let retryStart = harness.transport.sent.count
        var removalCompletions = 0
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        drainMainQueue(turns: 5)
        let staleRead = harness.request(at: retryStart)

        harness.session.invalidateForRemoval { removalCompletions += 1 }
        drainMainQueue(turns: 6)
        let mutationsAtRemoval = harness.journal.mutationCallCount
        let removesAtRemoval = harness.journal.removeDeviceCallCount
        let requestsAtRemoval = harness.transport.sent.count
        harness.respond(
            to: staleRead,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(baselineStates(0x005B)[0x005B]!)
        )
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.session.state, .invalid(.disconnected))
        XCTAssertEqual(removalCompletions, 1)
        XCTAssertEqual(harness.journal.mutationCallCount, mutationsAtRemoval)
        XCTAssertEqual(harness.journal.removeDeviceCallCount, removesAtRemoval)
        XCTAssertEqual(harness.transport.sent.count, requestsAtRemoval)
    }

    func testRemovalWinsRetryAndLateJournalClearCannotStartTakeoverAfterTerminalState() {
        let harness = conflictedHarness()
        harness.journal.holdNextRemoveCompletion = true
        let retryStart = harness.transport.sent.count
        var removalCompletions = 0
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        driveExplicitRetryBaseline(
            harness,
            startingAt: retryStart,
            states: baselineStates(0x005B, 0x005D, 0x00D0)
        )
        XCTAssertTrue(harness.journal.hasHeldRemoveCompletion)

        harness.session.invalidateForRemoval { removalCompletions += 1 }
        drainMainQueue(turns: 6)
        let journalAtRemoval = harness.journal.currentJournal
        let mutationsAtRemoval = harness.journal.mutationCallCount
        let requestsAtRemoval = harness.transport.sent.count
        harness.journal.completeHeldRemove()
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.session.state, .invalid(.disconnected))
        XCTAssertEqual(removalCompletions, 1)
        XCTAssertEqual(harness.journal.currentJournal, journalAtRemoval)
        XCTAssertEqual(harness.journal.mutationCallCount, mutationsAtRemoval)
        XCTAssertEqual(harness.transport.sent.count, requestsAtRemoval)
        XCTAssertFalse(harness.requestKinds[retryStart...].contains {
            if case .setCidReporting = $0 { return true }
            return false
        })
    }

    func testAcceptedRetryStillFreshPreflightsAndConflictsWithoutTakeoverSet() {
        let harness = conflictedHarness()
        let retryStart = harness.transport.sent.count
        XCTAssertTrue(harness.session.retryAfterConflict(requestID: UUID()))
        let clean = baselineStates(0x005B, 0x005D, 0x00D0)
        driveExplicitRetryBaseline(harness, startingAt: retryStart, states: clean)
        let takeoverStart = retryStart + M720Profile.cidToButton.count
        let external = HIDPPReportingState(cid: 0x005B, flags: 0x10, remappedCID: 0x1234)
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: [0x005B: external]
        )

        XCTAssertEqual(harness.session.state, .conflict)
        XCTAssertFalse(harness.requestKinds[takeoverStart...].contains {
            if case .setCidReporting = $0 { return true }
            return false
        })
    }

    func testClearingBindingsLeavesExplicitRetryLatchBeforeAnyLaterTakeover() {
        let harness = M720SessionHarness()
        harness.session.setRequiredCIDs([0x005B])
        harness.session.start()
        let unknown = HIDPPReportingState(cid: 0x005B, flags: 0x11, remappedCID: 0x7777)
        driveDiscovery(
            harness,
            rows: referenceRows,
            reportingOverrides: [0x005B: unknown]
        )
        XCTAssertEqual(harness.session.state, .conflict)
        let requestCountAtConflict = harness.transport.sent.count

        harness.session.setRequiredCIDs([])
        drainMainQueue(turns: 4)
        XCTAssertEqual(harness.session.state, .nativeReady)
        harness.session.setRequiredCIDs([0x005B])
        drainMainQueue(turns: 4)
        XCTAssertEqual(harness.session.state, .conflict)
        XCTAssertEqual(harness.transport.sent.count, requestCountAtConflict)
        assertNoSet(harness)
    }

    func testDiscoveryIgnoresJournalEntriesForDisconnectedOtherDevice() {
        let matchingEntry = journalEntry(cid: 0x005B)

        let otherKey = M720DeviceKey(
            vendorID: M720Profile.vendorID,
            productID: M720Profile.bluetoothLEProductID,
            transport: M720Profile.bluetoothLETransport,
            serialNumber: "other-device"
        )
        let otherJournal = M720OwnershipJournal(
            version: M720OwnershipJournal.currentVersion,
            devices: [M720JournalDevice(key: otherKey, controls: [matchingEntry])]
        )
        let otherHarness = M720SessionHarness(initialJournal: otherJournal)
        otherHarness.session.start()
        driveDiscovery(otherHarness, rows: referenceRows)
        XCTAssertEqual(otherHarness.session.state, .nativeReady)
        XCTAssertEqual(otherHarness.journal.currentJournal, otherJournal)
        XCTAssertEqual(otherHarness.journal.mutationCallCount, 0)
        assertNoSet(otherHarness)
    }

    func testDiscoveryRejectsUnusableOrEmptyJournalIdentityAfterDiagnostics() {
        let emptySerialKey = M720DeviceKey(
            vendorID: M720Profile.vendorID,
            productID: M720Profile.bluetoothLEProductID,
            transport: M720Profile.bluetoothLETransport,
            serialNumber: ""
        )
        for harness in [
            M720SessionHarness(deviceKey: emptySerialKey),
            M720SessionHarness(journalIdentityUsable: false),
        ] {
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            XCTAssertEqual(harness.session.state, .invalid(.unsupported))
            XCTAssertEqual(harness.journal.mutationCallCount, 0)
            assertNoSet(harness)
        }
    }

    func testInitiallyDiagnosticIdentityIgnoresMidDiscoveryPolicyUntilAllGetsComplete() {
        let emptySerialKey = M720DeviceKey(
            vendorID: M720Profile.vendorID,
            productID: M720Profile.bluetoothLEProductID,
            transport: M720Profile.bluetoothLETransport,
            serialNumber: ""
        )
        let origins: [(M720DeviceKey, Bool, Bool)] = [
            (M720SessionHarness.defaultDeviceKey, false, false),
            (emptySerialKey, true, false),
            (M720SessionHarness.defaultDeviceKey, true, true),
        ]
        let interruptionStages: [M720TestRequestKind] = [
            .rootGetFeature,
            .getCount,
        ]

        for (deviceKey, journalIdentityUsable, markBeforeStart) in origins {
            for stage in interruptionStages {
                let harness = M720SessionHarness(
                    deviceKey: deviceKey,
                    journalIdentityUsable: journalIdentityUsable
                )
                if markBeforeStart {
                    harness.session.markJournalIdentityUnusable()
                }
                harness.session.start()
                driveDiscovery(harness, rows: referenceRows, until: stage)
                let pendingRequestIndex = harness.transport.sent.count - 1
                XCTAssertEqual(harness.request(at: pendingRequestIndex).kind, stage)

                harness.session.setRequiredCIDs([0x005B])

                XCTAssertEqual(harness.session.state, .discovering)
                driveDiscovery(
                    harness,
                    rows: referenceRows,
                    startingAt: pendingRequestIndex
                )

                XCTAssertEqual(harness.session.state, .invalid(.unsupported))
                XCTAssertEqual(
                    harness.requestKinds.compactMap { request -> Int? in
                        if case let .getCidInfo(index) = request { return index }
                        return nil
                    },
                    Array(referenceRows.indices)
                )
                for cid in M720Profile.cidToButton.keys {
                    XCTAssertTrue(harness.requestKinds.contains(.getCidReporting(cid)))
                }
                XCTAssertEqual(harness.journal.mutationCallCount, 0)
                assertNoSet(harness)
            }
        }
    }

    func testDiscoveryReloadFailureStopsBeforeHIDAndJournalMutation() {
        let harness = M720SessionHarness(
            reloadResult: .failure(M720JournalStoreError.uncertain)
        )

        harness.session.start()
        drainMainQueue(turns: 3)

        XCTAssertEqual(harness.trace.events, [.reloadBegin, .reloadComplete])
        XCTAssertEqual(harness.session.state, .invalid(.protocol))
        XCTAssertTrue(harness.transport.sent.isEmpty)
        XCTAssertEqual(harness.journal.mutationCallCount, 0)
    }

    func testDiscoveryMapsFaultsAtEveryWireStageAndStopsWithoutWrites() {
        let stages: [M720TestRequestKind] = [
            .rootGetFeature,
            .getCount,
            .getCidInfo(4),
            .getCidReporting(0x005D),
        ]
        for stage in stages {
            for fault in M720DiscoveryFault.allCases {
                let harness = M720SessionHarness()
                if fault == .transport {
                    harness.sendFailureKind = stage
                }
                harness.session.start()
                driveDiscovery(harness, rows: referenceRows, until: stage)
                let firstFaultRequestIndex = harness.transport.sent.count - 1
                guard let request = harness.transport.sent.last.map({ harness.request(data: $0) }) else {
                    XCTFail("missing request for \(stage)")
                    continue
                }

                switch fault {
                case .transport:
                    break
                case .device:
                    harness.respondWithDeviceError(to: request, code: 0x08)
                case .timeout:
                    exhaustTimeouts(harness)
                case .malformed:
                    harness.transport.inject([UInt8](repeating: 0, count: 19))
                }
                drainMainQueue(turns: 3)

                let expected: M720StableErrorCode = {
                    switch fault {
                    case .transport: return .disconnected
                    case .timeout: return .timeout
                    case .device, .malformed: return .protocol
                    }
                }()
                XCTAssertEqual(harness.session.state, .invalid(expected), "stage=\(stage), fault=\(fault)")
                XCTAssertTrue(
                    harness.requestKinds.dropFirst(firstFaultRequestIndex).allSatisfy { $0 == stage },
                    "fault must not advance beyond stage=\(stage)"
                )
                let terminalRequestCount = harness.transport.sent.count
                harness.scheduler.advance(by: 10)
                drainMainQueue(turns: 3)
                XCTAssertEqual(harness.transport.sent.count, terminalRequestCount)
                XCTAssertEqual(harness.journal.mutationCallCount, 0)
                assertNoSet(harness)
            }
        }
    }

    func testDiscoveryRejectsUnsupportedRootLookupWithoutFurtherRequests() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows, until: .rootGetFeature)
        let request = harness.request(at: 0)

        harness.respond(
            to: request,
            responseFeatureIndex: 0x00,
            parameters: [0x00, 0x00, 0x00]
        )
        drainMainQueue(turns: 3)

        XCTAssertEqual(harness.requestKinds, [.rootGetFeature])
        XCTAssertEqual(harness.session.state, .invalid(.unsupported))
        XCTAssertEqual(harness.journal.mutationCallCount, 0)
        assertNoSet(harness)
    }

    func testTakeoverPreflightsWholeSetThenJournalsEachCIDInExactOrder() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let firstTakeoverRequest = harness.transport.sent.count
        harness.trace.removeAll()
        var appliedSnapshotsAtDurableMutation: [Set<UInt16>] = []
        harness.journal.onMutation = { _ in
            appliedSnapshotsAtDurableMutation.append(harness.session.appliedCIDs)
        }

        harness.session.setRequiredCIDs([0x005D, 0x005B])
        driveTakeover(
            harness,
            startingAt: firstTakeoverRequest,
            initialStates: [
                0x005B: HIDPPReportingState(cid: 0x005B, flags: 0, remappedCID: 0x005B),
                0x005D: HIDPPReportingState(cid: 0x005D, flags: 0, remappedCID: 0x005D),
            ]
        )

        XCTAssertEqual(harness.trace.events, [
            .request(.getCidReporting(0x005B)),
            .request(.getCidReporting(0x005D)),
            .journal(cid: 0x005B, phase: .prepared),
            .request(.setCidReporting(0x005B, diverted: true)),
            .request(.getCidReporting(0x005B)),
            .journal(cid: 0x005B, phase: .applied),
            .journal(cid: 0x005D, phase: .prepared),
            .request(.setCidReporting(0x005D, diverted: true)),
            .request(.getCidReporting(0x005D)),
            .journal(cid: 0x005D, phase: .applied),
        ])
        XCTAssertEqual(appliedSnapshotsAtDurableMutation, [[], [], [], []])
        XCTAssertEqual(harness.session.requiredCIDs, [0x005B, 0x005D])
        XCTAssertEqual(harness.session.appliedCIDs, [0x005B, 0x005D])
        XCTAssertEqual(harness.session.state, .active)
    }

    func testPolicyRemovalCompareAndRestoresEveryOwnedCIDBeforeNativeReady() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B, 0x005D])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B, 0x005D)
        )
        requestIndex = harness.transport.sent.count
        harness.trace.removeAll()

        harness.session.setRequiredCIDs([])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: divertedStates(0x005B, 0x005D)
        )

        XCTAssertEqual(harness.trace.events, [
            .request(.getCidReporting(0x005B)),
            .journal(cid: 0x005B, phase: .restoring),
            .request(.setCidReporting(0x005B, diverted: false)),
            .request(.getCidReporting(0x005B)),
            .journal(cid: 0x005B, phase: nil),
            .request(.getCidReporting(0x005D)),
            .journal(cid: 0x005D, phase: .restoring),
            .request(.setCidReporting(0x005D, diverted: false)),
            .request(.getCidReporting(0x005D)),
            .journal(cid: 0x005D, phase: nil),
        ])
        XCTAssertEqual(harness.session.requiredCIDs, [])
        XCTAssertEqual(harness.session.appliedCIDs, [])
        XCTAssertEqual(harness.session.state, .nativeReady)
    }

    func testRollbackNeverOverwritesThirdStateAndStillRestoresOwnedSibling() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B, 0x005D])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B, 0x005D)
        )
        requestIndex = harness.transport.sent.count
        harness.trace.removeAll()
        let thirdState = HIDPPReportingState(
            cid: 0x005B,
            flags: 0x10,
            remappedCID: 0x1234
        )

        harness.session.setRequiredCIDs([])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: [
                0x005B: thirdState,
                0x005D: HIDPPReportingState(
                    cid: 0x005D,
                    flags: 1,
                    remappedCID: 0x005D
                ),
            ]
        )

        XCTAssertEqual(harness.trace.events, [
            .request(.getCidReporting(0x005B)),
            .request(.getCidReporting(0x005D)),
            .journal(cid: 0x005D, phase: .restoring),
            .request(.setCidReporting(0x005D, diverted: false)),
            .request(.getCidReporting(0x005D)),
            .journal(cid: 0x005D, phase: nil),
        ])
        XCTAssertEqual(harness.journal.currentJournal.devices.first?.controls.map(\.cid), [0x005B])
        XCTAssertEqual(harness.session.state, .conflict)
        XCTAssertEqual(harness.session.appliedCIDs, [])
    }

    func testTakeoverThirdStateLatchesExternalOwnershipAcrossRollbackReread() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        let thirdState = HIDPPReportingState(
            cid: 0x005D,
            flags: 0x10,
            remappedCID: 0x1234
        )

        harness.session.setRequiredCIDs([0x005B, 0x005D])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B, 0x005D),
            injectedFailure: .readbackThirdThenRollbackIntended(
                cid: 0x005D,
                third: thirdState
            )
        )

        let requests = Array(harness.requestKinds.dropFirst(takeoverStart))
        XCTAssertTrue(requests.contains(.setCidReporting(0x005B, diverted: false)))
        XCTAssertFalse(
            requests.contains(.setCidReporting(0x005D, diverted: false)),
            "a CID observed under external ownership must never be written during rollback"
        )
        XCTAssertEqual(
            harness.journal.currentJournal.devices.first?.controls,
            [journalEntry(cid: 0x005D, phase: .prepared)]
        )
        XCTAssertEqual(harness.session.appliedCIDs, [])
        XCTAssertEqual(harness.session.state, .conflict)
    }

    func testUncertainTakeoverSetAlsoLatchesThirdStateAcrossRollbackReread() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        let thirdState = HIDPPReportingState(
            cid: 0x005D,
            flags: 0x10,
            remappedCID: 0x1234
        )

        harness.session.setRequiredCIDs([0x005B, 0x005D])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B, 0x005D),
            injectedFailure: .badEchoThenThirdReadbackThenRollbackIntended(
                cid: 0x005D,
                third: thirdState
            )
        )

        let requests = Array(harness.requestKinds.dropFirst(takeoverStart))
        XCTAssertTrue(requests.contains(.setCidReporting(0x005B, diverted: false)))
        XCTAssertFalse(requests.contains(.setCidReporting(0x005D, diverted: false)))
        XCTAssertEqual(
            harness.journal.currentJournal.devices.first?.controls,
            [journalEntry(cid: 0x005D, phase: .prepared)]
        )
        XCTAssertEqual(harness.session.state, .conflict)
    }

    func testPolicyOrShutdownAfterReadbackSendStillClassifiesTrustedPayload() {
        for path in M720DelayedTakeoverReadbackPath.allCases {
            for interruption in M720TakeoverInterruption.allCases {
                for ownership in M720TrustedReadbackOwnership.allCases {
                    let context = "path=\(path), interruption=\(interruption), ownership=\(ownership)"
                    let harness = M720SessionHarness()
                    harness.session.start()
                    driveDiscovery(harness, rows: referenceRows)
                    let pendingReadback = advanceToSecondCIDAuthoritativeReadback(
                        harness,
                        path: path
                    )
                    let rollbackStart = harness.transport.sent.count
                    var shutdownCompletions = 0

                    switch interruption {
                    case .policy:
                        harness.session.setRequiredCIDs([])
                    case .shutdown:
                        harness.session.shutdown { shutdownCompletions += 1 }
                    }
                    drainMainQueue(turns: 4)
                    XCTAssertEqual(harness.session.state, .takingOver, context)

                    let trustedState: HIDPPReportingState
                    switch ownership {
                    case .third:
                        trustedState = HIDPPReportingState(
                            cid: 0x005D,
                            flags: 0x10,
                            remappedCID: 0x1234
                        )
                    case .original:
                        trustedState = baselineStates(0x005D)[0x005D]!
                    }
                    harness.respond(
                        to: pendingReadback,
                        responseFeatureIndex: 0x2A,
                        parameters: harness.reportingParameters(trustedState)
                    )
                    driveTakeover(
                        harness,
                        startingAt: rollbackStart,
                        initialStates: divertedStates(0x005B, 0x005D)
                    )

                    let rollbackRequests = Array(
                        harness.requestKinds.dropFirst(rollbackStart)
                    )
                    XCTAssertTrue(
                        rollbackRequests.contains(.setCidReporting(0x005B, diverted: false)),
                        "owned sibling must still restore; \(context)"
                    )
                    XCTAssertFalse(
                        rollbackRequests.contains(.setCidReporting(0x005D, diverted: false)),
                        "trusted not-owned evidence must survive the policy boundary; \(context)"
                    )
                    switch ownership {
                    case .third:
                        XCTAssertEqual(
                            harness.journal.currentJournal.devices.first?.controls,
                            [journalEntry(cid: 0x005D, phase: .prepared)],
                            context
                        )
                    case .original:
                        XCTAssertEqual(harness.journal.currentJournal, .emptyV1, context)
                    }
                    XCTAssertEqual(harness.session.appliedCIDs, [], context)
                    switch interruption {
                    case .policy:
                        XCTAssertEqual(harness.session.state, .conflict, context)
                        XCTAssertEqual(shutdownCompletions, 0, context)
                        XCTAssertEqual(harness.transport.invalidateCallCount, 0, context)
                    case .shutdown:
                        XCTAssertEqual(harness.session.state, .invalid(.conflict), context)
                        XCTAssertEqual(shutdownCompletions, 1, context)
                        XCTAssertEqual(harness.transport.invalidateCallCount, 1, context)
                    }
                }
            }
        }
    }

    func testDecodedWrongCIDAfterTakeoverSetRollsBackTouchedOwnership() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let pendingReadback = advanceToSecondCIDAuthoritativeReadback(
            harness,
            path: .normal
        )
        let rollbackStart = harness.transport.sent.count
        let wrongCIDState = HIDPPReportingState(
            cid: 0x005B,
            flags: 1,
            remappedCID: 0x005B
        )

        harness.respond(
            to: pendingReadback,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(wrongCIDState)
        )
        driveTakeover(
            harness,
            startingAt: rollbackStart,
            initialStates: divertedStates(0x005B, 0x005D)
        )

        let rollbackRequests = Array(harness.requestKinds.dropFirst(rollbackStart))
        XCTAssertTrue(rollbackRequests.contains(.setCidReporting(0x005B, diverted: false)))
        XCTAssertTrue(rollbackRequests.contains(.setCidReporting(0x005D, diverted: false)))
        XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
        XCTAssertEqual(harness.session.appliedCIDs, [])
        XCTAssertEqual(harness.session.state, .invalid(.protocol))
    }

    func testRestoreAttemptUsesAuthoritativeReadbackDecisionTable() {
        for attempt in M720RestoreAttemptFault.allCases {
            for outcome in M720RestoreReadbackOutcome.allCases {
                let context = "attempt=\(attempt), outcome=\(outcome)"
                let harness = M720SessionHarness()
                harness.session.start()
                driveDiscovery(harness, rows: referenceRows)
                var requestIndex = harness.transport.sent.count
                harness.session.setRequiredCIDs([0x005B, 0x005D])
                driveTakeover(
                    harness,
                    startingAt: requestIndex,
                    initialStates: baselineStates(0x005B, 0x005D)
                )
                requestIndex = harness.transport.sent.count
                if attempt == .sendFailure {
                    harness.sendFailureKind = .setCidReporting(0x005B, diverted: false)
                }
                if outcome == .getFailure {
                    harness.onRequestSent = { kind in
                        if kind == .setCidReporting(0x005B, diverted: false) {
                            harness.sendFailureKind = .getCidReporting(0x005B)
                        }
                    }
                }

                harness.session.setRequiredCIDs([])
                driveTakeover(
                    harness,
                    startingAt: requestIndex,
                    initialStates: divertedStates(0x005B, 0x005D),
                    restoreFault: M720RestoreDriveFault(
                        cid: 0x005B,
                        attempt: attempt,
                        outcome: outcome
                    )
                )

                let rollbackRequests = Array(harness.requestKinds.dropFirst(requestIndex))
                XCTAssertEqual(
                    rollbackRequests.filter { $0 == .getCidReporting(0x005B) }.count,
                    2,
                    "restore attempt must always be followed by one authoritative Get; \(context)"
                )
                XCTAssertEqual(
                    rollbackRequests.filter {
                        $0 == .setCidReporting(0x005B, diverted: false)
                    }.count,
                    1,
                    context
                )

                switch outcome {
                case .original:
                    XCTAssertEqual(harness.journal.currentJournal, .emptyV1, context)
                    XCTAssertTrue(
                        rollbackRequests.contains(.setCidReporting(0x005D, diverted: false)),
                        context
                    )
                    XCTAssertEqual(harness.session.state, .nativeReady, context)
                case .third:
                    XCTAssertEqual(
                        harness.journal.currentJournal.devices.first?.controls,
                        [journalEntry(cid: 0x005B, phase: .restoring)],
                        context
                    )
                    XCTAssertTrue(
                        rollbackRequests.contains(.setCidReporting(0x005D, diverted: false)),
                        "third-party CID must not stop owned siblings; \(context)"
                    )
                    XCTAssertEqual(harness.session.state, .conflict, context)
                case .intended, .getFailure, .malformed:
                    XCTAssertEqual(
                        harness.journal.currentJournal.devices.first?.controls,
                        [
                            journalEntry(cid: 0x005B, phase: .restoring),
                            journalEntry(cid: 0x005D, phase: .applied),
                        ],
                        context
                    )
                    XCTAssertFalse(
                        rollbackRequests.contains(.setCidReporting(0x005D, diverted: false)),
                        context
                    )
                    let expectedState: M720SessionState
                    if outcome == .getFailure || attempt == .sendFailure && outcome == .intended {
                        expectedState = .invalid(.disconnected)
                    } else {
                        expectedState = .invalid(.protocol)
                    }
                    XCTAssertEqual(harness.session.state, expectedState, context)
                }
            }
        }
    }

    func testRollbackJournalFailuresRetainEntryAndUncertainResultsReloadBeforeSiblingIO() {
        struct Scenario {
            let name: String
            let point: M720JournalFailurePoint
            let afterMutation: Bool
            let currentIsOriginal: Bool
            let expectedPhase: M720JournalPhase
        }
        let scenarios = [
            Scenario(
                name: "restoring-before",
                point: M720JournalFailurePoint(cid: 0x005B, phase: .restoring),
                afterMutation: false,
                currentIsOriginal: false,
                expectedPhase: .applied
            ),
            Scenario(
                name: "restoring-after-uncertain",
                point: M720JournalFailurePoint(cid: 0x005B, phase: .restoring),
                afterMutation: true,
                currentIsOriginal: false,
                expectedPhase: .restoring
            ),
            Scenario(
                name: "remove-before",
                point: M720JournalFailurePoint(cid: 0x005B, phase: nil),
                afterMutation: false,
                currentIsOriginal: true,
                expectedPhase: .applied
            ),
            Scenario(
                name: "remove-after-uncertain",
                point: M720JournalFailurePoint(cid: 0x005B, phase: nil),
                afterMutation: true,
                currentIsOriginal: true,
                expectedPhase: .applied
            ),
        ]

        for scenario in scenarios {
            let harness = M720SessionHarness()
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            var requestIndex = harness.transport.sent.count
            harness.session.setRequiredCIDs([0x005B, 0x005D])
            driveTakeover(
                harness,
                startingAt: requestIndex,
                initialStates: baselineStates(0x005B, 0x005D)
            )
            requestIndex = harness.transport.sent.count
            harness.trace.removeAll()
            if scenario.afterMutation {
                harness.journal.failAfterNextMutation = scenario.point
                harness.journal.failedAfterMutationPersistsChange = scenario.point.phase != nil
            } else {
                harness.journal.failBeforeNextMutation = scenario.point
            }
            let current5B = scenario.currentIsOriginal
                ? baselineStates(0x005B)[0x005B]!
                : divertedStates(0x005B)[0x005B]!

            harness.session.setRequiredCIDs([])
            driveTakeover(
                harness,
                startingAt: requestIndex,
                initialStates: [
                    0x005B: current5B,
                    0x005D: divertedStates(0x005D)[0x005D]!,
                ]
            )

            let retained = harness.journal.currentJournal.devices
                .first { $0.key == M720SessionHarness.defaultDeviceKey }?
                .controls.first { $0.cid == 0x005B }
            XCTAssertEqual(retained?.phase, scenario.expectedPhase, scenario.name)
            XCTAssertEqual(harness.session.state, .invalid(.protocol), scenario.name)
            XCTAssertFalse(
                harness.requestKinds.dropFirst(requestIndex).contains(.setCidReporting(0x005B, diverted: false)),
                scenario.name
            )
            XCTAssertFalse(
                harness.requestKinds.dropFirst(requestIndex).contains(.getCidReporting(0x005D)),
                scenario.name
            )
            if scenario.afterMutation {
                XCTAssertTrue(harness.trace.events.contains(.reloadBegin), scenario.name)
                XCTAssertTrue(harness.trace.events.contains(.reloadComplete), scenario.name)
            } else {
                XCTAssertFalse(harness.trace.events.contains(.reloadBegin), scenario.name)
            }
        }
    }

    func testEventsRouteOnlyAppliedEdgesFromActiveReprogControlsBroadcasts() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 3)
        XCTAssertTrue(harness.sink.emissions.isEmpty)

        let requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B)
        )

        harness.injectEvent(featureIndex: 0x2B, event: 0, cids: [0x005B])
        harness.injectEvent(featureIndex: 0x2A, event: 1, cids: [0x005B])
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B, 0x005B])
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B, 0x005D])
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B, 0x005D])
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [])
        drainMainQueue(turns: 3)

        XCTAssertEqual(harness.sink.emissions, [
            M720SinkEmission(button: 6, downNotUp: true),
            M720SinkEmission(button: 6, downNotUp: false),
        ])
        XCTAssertTrue(harness.sink.cancellations.isEmpty)
    }

    func testCopiedOldEventHandlerStaysStaleAfterRollbackAndNewActiveGeneration() throws {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B, 0x005D)
        )
        let copiedOldHandler = try XCTUnwrap(harness.pipeline.onEvent)
        requestIndex = harness.transport.sent.count

        harness.session.setRequiredCIDs([0x005D])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: [
                0x005B: HIDPPReportingState(cid: 0x005B, flags: 1, remappedCID: 0x005B),
                0x005D: HIDPPReportingState(cid: 0x005D, flags: 0, remappedCID: 0x005D),
            ]
        )
        harness.sink.resetEmissions()

        copiedOldHandler(.event(
            featureIndex: 0x2A,
            event: 0,
            parameters: Data(harness.eventParameters(cids: [0x005D]))
        ))
        drainMainQueue(turns: 3)
        XCTAssertTrue(harness.sink.emissions.isEmpty)

        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005D])
        drainMainQueue(turns: 3)
        XCTAssertEqual(harness.sink.emissions, [
            M720SinkEmission(button: 7, downNotUp: true),
        ])
    }

    func testReentrantGateCloseDuringMultiEdgeSnapshotStopsBeforeSecondEmission() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B, 0x005D])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B, 0x005D)
        )
        var didReenter = false
        harness.sink.onEmit = { [weak session = harness.session] _ in
            guard !didReenter else { return }
            didReenter = true
            harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B, 0x005D])
            session?.setRequiredCIDs([])
        }

        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B, 0x005D])
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.sink.emissions, [
            M720SinkEmission(button: 6, downNotUp: true),
        ])
        XCTAssertEqual(harness.sink.cancellations, [6])
        XCTAssertEqual(harness.session.state, .restoring)
    }

    func testNormalUpRemovesForwardedDownSoTeardownDoesNotCancelItAgain() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B)
        )
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [])
        drainMainQueue(turns: 6)
        requestIndex = harness.transport.sent.count

        harness.session.setRequiredCIDs([])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: divertedStates(0x005B)
        )

        XCTAssertEqual(harness.sink.emissions, [
            M720SinkEmission(button: 6, downNotUp: true),
            M720SinkEmission(button: 6, downNotUp: false),
        ])
        XCTAssertTrue(harness.sink.cancellations.isEmpty)
        XCTAssertEqual(harness.session.state, .nativeReady)
    }

    func testGateCloseWaitsForExactCancelBatchBeforeFirstRestoreRequest() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B, 0x005D])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B, 0x005D)
        )
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B, 0x005D])
        drainMainQueue(turns: 3)
        XCTAssertEqual(harness.sink.emissions, [
            M720SinkEmission(button: 6, downNotUp: true),
            M720SinkEmission(button: 7, downNotUp: true),
        ])
        harness.sink.automaticallyCompletesCancels = false
        requestIndex = harness.transport.sent.count

        harness.session.setRequiredCIDs([])
        drainMainQueue(turns: 3)

        XCTAssertEqual(harness.session.state, .restoring)
        XCTAssertEqual(harness.sink.cancellations, [6, 7])
        XCTAssertEqual(harness.transport.sent.count, requestIndex)
        XCTAssertEqual(harness.sink.emissions.count, 2, "gate close must not synthesize ups")

        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [])
        drainMainQueue(turns: 3)
        XCTAssertEqual(harness.sink.emissions.count, 2, "rollback events must be ignored")

        harness.sink.completeCancel(button: 7, times: 2)
        drainMainQueue(turns: 3)
        XCTAssertEqual(harness.transport.sent.count, requestIndex)

        harness.sink.completeCancel(button: 6)
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: divertedStates(0x005B, 0x005D)
        )

        XCTAssertEqual(harness.sink.cancellations, [6, 7])
        XCTAssertEqual(harness.sink.emissions.count, 2)
        XCTAssertEqual(harness.session.state, .nativeReady)
    }

    func testSleepDefersPolicyRollbackUntilWakeAndDrainsAllCancelWaiters() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B)
        )
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 4)
        harness.sink.automaticallyCompletesCancels = false
        requestIndex = harness.transport.sent.count
        var sleepCompletions = 0

        harness.session.prepareForSleep { sleepCompletions += 1 }
        harness.session.prepareForSleep { sleepCompletions += 1 }
        harness.session.setRequiredCIDs([])
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.sink.cancellations, [6])
        XCTAssertEqual(sleepCompletions, 0)
        XCTAssertEqual(harness.transport.sent.count, requestIndex)
        XCTAssertEqual(harness.session.state, .active)

        harness.sink.completeCancel(button: 6, times: 2)
        drainMainQueue(turns: 5)
        XCTAssertEqual(sleepCompletions, 2)
        XCTAssertEqual(harness.transport.sent.count, requestIndex)
        XCTAssertEqual(harness.session.state, .active)

        harness.session.reconcileAfterWake()
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: divertedStates(0x005B)
        )

        XCTAssertEqual(harness.sink.cancellations, [6])
        XCTAssertEqual(harness.session.state, .nativeReady)
    }

    func testRemovalJoinsHeldSleepCancelWithoutDroppingEitherCompletion() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B)
        )
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 4)
        harness.sink.automaticallyCompletesCancels = false
        var sleepCompletions = 0
        var removalCompletions = 0

        harness.session.prepareForSleep { sleepCompletions += 1 }
        harness.session.invalidateForRemoval { removalCompletions += 1 }
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.sink.cancellations, [6])
        XCTAssertEqual(sleepCompletions, 0)
        XCTAssertEqual(removalCompletions, 0)
        XCTAssertEqual(harness.transport.invalidateCallCount, 0)

        harness.sink.completeCancel(button: 6)
        drainMainQueue(turns: 6)

        XCTAssertEqual(sleepCompletions, 1)
        XCTAssertEqual(removalCompletions, 1)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
        XCTAssertEqual(harness.session.state, .invalid(.disconnected))
    }

    func testSleepJoinsCancelBatchAlreadyOwnedByPolicyShutdownOrRemoval() {
        for owner in M720CancelBatchOwner.allCases {
            let context = "owner=\(owner)"
            let harness = M720SessionHarness()
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            var requestIndex = harness.transport.sent.count
            harness.session.setRequiredCIDs([0x005B])
            driveTakeover(
                harness,
                startingAt: requestIndex,
                initialStates: baselineStates(0x005B)
            )
            harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
            drainMainQueue(turns: 4)
            harness.sink.automaticallyCompletesCancels = false
            requestIndex = harness.transport.sent.count
            var ownerCompletions = 0
            var sleepCompletions = 0

            switch owner {
            case .policy:
                harness.session.setRequiredCIDs([])
            case .shutdown:
                harness.session.shutdown { ownerCompletions += 1 }
            case .removal:
                harness.session.invalidateForRemoval { ownerCompletions += 1 }
            }
            drainMainQueue(turns: 5)
            harness.session.prepareForSleep { sleepCompletions += 1 }
            drainMainQueue(turns: 5)

            XCTAssertEqual(harness.sink.cancellations, [6], context)
            XCTAssertEqual(sleepCompletions, 0, "sleep must wait for the existing batch; \(context)")
            XCTAssertEqual(ownerCompletions, 0, context)
            XCTAssertEqual(harness.transport.invalidateCallCount, 0, context)

            harness.sink.completeCancel(button: 6, times: 2)
            if owner == .removal {
                drainMainQueue(turns: 6)
            } else {
                driveTakeover(
                    harness,
                    startingAt: requestIndex,
                    initialStates: divertedStates(0x005B)
                )
            }

            XCTAssertEqual(sleepCompletions, 1, context)
            switch owner {
            case .policy:
                XCTAssertEqual(ownerCompletions, 0, context)
                XCTAssertEqual(harness.transport.invalidateCallCount, 0, context)
                XCTAssertEqual(harness.session.state, .nativeReady, context)
            case .shutdown:
                XCTAssertEqual(ownerCompletions, 1, context)
                XCTAssertEqual(harness.transport.invalidateCallCount, 1, context)
                XCTAssertEqual(harness.session.state, .invalid(.cancelled), context)
            case .removal:
                XCTAssertEqual(ownerCompletions, 1, context)
                XCTAssertEqual(harness.transport.invalidateCallCount, 1, context)
                XCTAssertEqual(harness.session.state, .invalid(.disconnected), context)
            }
        }
    }

    func testRemovalPublishesDisconnectedOnlyAfterCancelAndPipelineInvalidation() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 4)
        harness.sink.automaticallyCompletesCancels = false
        var events: [String] = []
        var observerInvalidateCounts: [Int] = []
        var observerSawCancelCompletionReturn: [Bool] = []
        var cancelCompletionReturned = false
        harness.transport.onInvalidate = { events.append("invalidate") }
        harness.session.onStateChange = { state in
            guard state == .invalid(.disconnected) else { return }
            observerInvalidateCounts.append(harness.transport.invalidateCallCount)
            observerSawCancelCompletionReturn.append(cancelCompletionReturned)
            events.append("disconnected")
        }
        var removalCompletions = 0

        harness.session.invalidateForRemoval {
            removalCompletions += 1
            events.append("completion")
        }
        drainMainQueue(turns: 6)

        XCTAssertEqual(events, [])
        XCTAssertEqual(harness.session.state, .active)
        XCTAssertEqual(harness.transport.invalidateCallCount, 0)
        XCTAssertEqual(removalCompletions, 0)

        harness.sink.completeCancel(button: 6, times: 2)
        cancelCompletionReturned = true
        drainMainQueue(turns: 6)

        XCTAssertTrue(cancelCompletionReturned)
        XCTAssertEqual(observerInvalidateCounts, [1])
        XCTAssertEqual(observerSawCancelCompletionReturn, [true])
        XCTAssertEqual(events, ["invalidate", "completion", "disconnected"])
        XCTAssertEqual(removalCompletions, 1)
        XCTAssertEqual(harness.session.state, .invalid(.disconnected))
    }

    func testPolicyChangeAtDurablePreparedBoundaryRollsBackBeforeFreshPreflight() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.trace.removeAll()
        harness.journal.holdNextCompletionForPhase = .prepared

        harness.session.setRequiredCIDs([0x005B, 0x005D])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B, 0x005D, 0x00D0)
        )
        XCTAssertTrue(harness.journal.hasHeldMutationCompletion)
        XCTAssertEqual(harness.session.state, .takingOver)
        XCTAssertFalse(harness.requestKinds.contains { kind in
            if case .setCidReporting = kind { return true }
            return false
        })

        harness.session.setRequiredCIDs([0x00D0])
        drainMainQueue(turns: 3)
        requestIndex = harness.transport.sent.count
        harness.journal.completeHeldMutation()
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B, 0x005D, 0x00D0)
        )

        XCTAssertEqual(harness.trace.events, [
            .request(.getCidReporting(0x005B)),
            .request(.getCidReporting(0x005D)),
            .journal(cid: 0x005B, phase: .prepared),
            .request(.getCidReporting(0x005B)),
            .journal(cid: 0x005B, phase: nil),
            .request(.getCidReporting(0x00D0)),
            .journal(cid: 0x00D0, phase: .prepared),
            .request(.setCidReporting(0x00D0, diverted: true)),
            .request(.getCidReporting(0x00D0)),
            .journal(cid: 0x00D0, phase: .applied),
        ])
        XCTAssertEqual(harness.session.requiredCIDs, [0x00D0])
        XCTAssertEqual(harness.session.appliedCIDs, [0x00D0])
        XCTAssertEqual(harness.session.state, .active)
    }

    func testHeldUntouchedPreparedClaimNeverRestoresExternalIntendedState() {
        for shutdown in [false, true] {
            let harness = M720SessionHarness()
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            let takeoverStart = harness.transport.sent.count
            harness.journal.holdNextMutationCompletion = M720JournalFailurePoint(
                cid: 0x005D,
                phase: .prepared
            )

            harness.session.setRequiredCIDs([0x005B, 0x005D])
            driveTakeover(
                harness,
                startingAt: takeoverStart,
                initialStates: baselineStates(0x005B, 0x005D)
            )
            XCTAssertTrue(harness.journal.hasHeldMutationCompletion, "shutdown=\(shutdown)")
            XCTAssertEqual(harness.session.state, .takingOver, "shutdown=\(shutdown)")
            let rollbackStart = harness.transport.sent.count
            var shutdownCompletions = 0

            if shutdown {
                harness.session.shutdown { shutdownCompletions += 1 }
            } else {
                harness.session.setRequiredCIDs([])
            }
            drainMainQueue(turns: 3)
            harness.journal.completeHeldMutation()
            driveTakeover(
                harness,
                startingAt: rollbackStart,
                initialStates: divertedStates(0x005B, 0x005D)
            )

            let rollbackRequests = Array(harness.requestKinds.dropFirst(rollbackStart))
            XCTAssertTrue(
                rollbackRequests.contains(.setCidReporting(0x005B, diverted: false)),
                "shutdown=\(shutdown)"
            )
            XCTAssertFalse(
                rollbackRequests.contains(.setCidReporting(0x005D, diverted: false)),
                "untouched prepared CID belongs to the external writer; shutdown=\(shutdown)"
            )
            XCTAssertEqual(harness.journal.currentJournal, .emptyV1, "shutdown=\(shutdown)")
            XCTAssertEqual(harness.session.appliedCIDs, [], "shutdown=\(shutdown)")
            XCTAssertEqual(
                harness.session.state,
                shutdown ? .invalid(.conflict) : .conflict,
                "shutdown=\(shutdown)"
            )
            XCTAssertEqual(shutdownCompletions, shutdown ? 1 : 0)
            XCTAssertEqual(harness.transport.invalidateCallCount, shutdown ? 1 : 0)
        }
    }

    func testPolicyChangeAtEveryRequestAndWriteBoundaryRestoresThenFreshPreflightsLatestSet() {
        for boundary in M720PolicyTakeoverBoundary.allCases {
            let harness = M720SessionHarness()
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            let requestIndex = harness.transport.sent.count
            var staleRequest: M720TestRequest?
            var nextResponseIndex: Int
            if boundary == .applied {
                harness.journal.holdNextCompletionForPhase = .applied
            }
            harness.session.setRequiredCIDs([0x005B])
            drainMainQueue(turns: 4)
            let preflight = harness.request(at: requestIndex)
            if boundary == .preflight {
                staleRequest = preflight
                nextResponseIndex = requestIndex + 1
            } else {
                harness.respond(
                    to: preflight,
                    responseFeatureIndex: 0x2A,
                    parameters: harness.reportingParameters(baselineStates(0x005B)[0x005B]!)
                )
                if boundary == .setSend {
                    harness.transport.automaticallyCompletesSends = false
                }
                drainMainQueue(turns: 6)
                let pendingSet = harness.request(at: requestIndex + 1)
                switch boundary {
                case .setSend, .setEcho:
                    staleRequest = pendingSet
                    nextResponseIndex = requestIndex + 2
                case .readback, .applied:
                    harness.respond(
                        to: pendingSet,
                        responseFeatureIndex: 0x2A,
                        parameters: ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: true)
                    )
                    drainMainQueue(turns: 6)
                    let pendingReadback = harness.request(at: requestIndex + 2)
                    if boundary == .readback {
                        staleRequest = pendingReadback
                    } else {
                        harness.respond(
                            to: pendingReadback,
                            responseFeatureIndex: 0x2A,
                            parameters: harness.reportingParameters(divertedStates(0x005B)[0x005B]!)
                        )
                        drainMainQueue(turns: 6)
                        XCTAssertTrue(harness.journal.hasHeldMutationCompletion)
                    }
                    nextResponseIndex = requestIndex + 3
                case .preflight:
                    preconditionFailure("handled above")
                }
            }
            harness.session.setRequiredCIDs([0x005D])
            drainMainQueue(turns: 4)
            XCTAssertEqual(harness.session.state, .takingOver, "boundary=\(boundary)")

            if boundary == .setSend {
                harness.transport.automaticallyCompletesSends = true
                harness.transport.completeNextSend()
                drainMainQueue(turns: 4)
            }
            if let staleRequest {
                let parameters: [UInt8]
                switch staleRequest.kind {
                case .setCidReporting:
                    parameters = ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: true)
                case .getCidReporting:
                    parameters = harness.reportingParameters(
                        boundary == .preflight
                            ? baselineStates(0x005B)[0x005B]!
                            : divertedStates(0x005B)[0x005B]!
                    )
                default:
                    preconditionFailure("unexpected stale boundary request")
                }
                harness.respond(
                    to: staleRequest,
                    responseFeatureIndex: 0x2A,
                    parameters: parameters
                )
            } else {
                harness.journal.completeHeldMutation()
            }
            driveTakeover(
                harness,
                startingAt: nextResponseIndex,
                initialStates: [
                    0x005B: boundary == .preflight
                        ? baselineStates(0x005B)[0x005B]!
                        : divertedStates(0x005B)[0x005B]!,
                    0x005D: baselineStates(0x005D)[0x005D]!,
                ]
            )

            XCTAssertEqual(harness.session.requiredCIDs, [0x005D], "boundary=\(boundary)")
            XCTAssertEqual(harness.session.appliedCIDs, [0x005D], "boundary=\(boundary)")
            XCTAssertEqual(harness.session.state, .active, "boundary=\(boundary)")
            XCTAssertEqual(
                harness.journal.currentJournal.devices.first?.controls,
                [journalEntry(cid: 0x005D, phase: .applied)],
                "boundary=\(boundary)"
            )
            if boundary != .preflight {
                let removal = harness.trace.events.firstIndex(of: .journal(cid: 0x005B, phase: nil))
                let freshPreflight = harness.trace.events.lastIndex(of: .request(.getCidReporting(0x005D)))
                XCTAssertNotNil(removal, "boundary=\(boundary)")
                XCTAssertNotNil(freshPreflight, "boundary=\(boundary)")
                if let removal, let freshPreflight {
                    XCTAssertLessThan(removal, freshPreflight, "boundary=\(boundary)")
                }
            }
        }
    }

    func testUncertainPreparedMutationReloadsBeforeFailingClosedWithoutSet() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let requestIndex = harness.transport.sent.count
        harness.trace.removeAll()
        harness.journal.failAfterNextPhase = .prepared

        harness.session.setRequiredCIDs([0x005B, 0x005D])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B, 0x005D)
        )

        XCTAssertEqual(harness.trace.events, [
            .request(.getCidReporting(0x005B)),
            .request(.getCidReporting(0x005D)),
            .journal(cid: 0x005B, phase: .prepared),
            .reloadBegin,
            .reloadComplete,
        ])
        XCTAssertFalse(harness.requestKinds.dropFirst(requestIndex).contains { kind in
            if case .setCidReporting = kind { return true }
            return false
        })
        XCTAssertEqual(harness.journal.currentJournal.devices.first?.controls, [
            journalEntry(cid: 0x005B, phase: .prepared),
        ])
        XCTAssertEqual(harness.session.state, .invalid(.protocol))
    }

    func testUncertainAppliedMutationReloadsThenRestoresKnownWrittenCID() {
        for durableApplied in [false, true] {
            let context = "durable phase=\(durableApplied ? "applied" : "prepared")"
            let harness = M720SessionHarness()
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            let requestIndex = harness.transport.sent.count
            harness.trace.removeAll()
            harness.journal.failAfterNextMutation = M720JournalFailurePoint(
                cid: 0x005B,
                phase: .applied
            )
            harness.journal.failedAfterMutationPersistsChange = durableApplied
            var invalidTransitions = 0
            harness.session.onStateChange = { state in
                if state == .invalid(.protocol) { invalidTransitions += 1 }
            }

            harness.session.setRequiredCIDs([0x005B])
            driveTakeover(
                harness,
                startingAt: requestIndex,
                initialStates: baselineStates(0x005B)
            )

            let events = harness.trace.events
            let reloadComplete = events.firstIndex(of: .reloadComplete)
            let restoring = events.firstIndex(of: .journal(cid: 0x005B, phase: .restoring))
            XCTAssertNotNil(reloadComplete, context)
            XCTAssertNotNil(restoring, context)
            if let reloadComplete, let restoring {
                XCTAssertLessThan(reloadComplete, restoring, context)
            }
            XCTAssertTrue(
                harness.requestKinds.dropFirst(requestIndex).contains(
                    .setCidReporting(0x005B, diverted: false)
                ),
                context
            )
            XCTAssertEqual(harness.journal.currentJournal, .emptyV1, context)
            XCTAssertEqual(harness.session.appliedCIDs, [], context)
            XCTAssertEqual(harness.session.state, .invalid(.protocol), context)
            XCTAssertEqual(invalidTransitions, 1, context)
        }
    }

    func testLaterUncertainPreparedMutationRestoresEarlierCIDAndClearsDurableClaim() {
        for failingPreparedPersisted in [false, true] {
            let context = "failing prepared persisted=\(failingPreparedPersisted)"
            let harness = M720SessionHarness()
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            let requestIndex = harness.transport.sent.count
            harness.trace.removeAll()
            harness.journal.failAfterNextMutation = M720JournalFailurePoint(
                cid: 0x005D,
                phase: .prepared
            )
            harness.journal.failedAfterMutationPersistsChange = failingPreparedPersisted

            harness.session.setRequiredCIDs([0x005B, 0x005D])
            driveTakeover(
                harness,
                startingAt: requestIndex,
                initialStates: baselineStates(0x005B, 0x005D)
            )
            if harness.session.state == .restoring {
                driveTakeover(
                    harness,
                    startingAt: requestIndex + 4,
                    initialStates: [
                        0x005B: divertedStates(0x005B)[0x005B]!,
                        0x005D: baselineStates(0x005D)[0x005D]!,
                    ]
                )
            }

            let requests = Array(harness.requestKinds.dropFirst(requestIndex))
            XCTAssertTrue(
                requests.contains(.setCidReporting(0x005B, diverted: true)),
                context
            )
            XCTAssertTrue(
                requests.contains(.setCidReporting(0x005B, diverted: false)),
                context
            )
            XCTAssertFalse(
                requests.contains(.setCidReporting(0x005D, diverted: true)),
                context
            )
            XCTAssertTrue(harness.trace.events.contains(.reloadComplete), context)
            XCTAssertEqual(harness.journal.currentJournal, .emptyV1, context)
            XCTAssertEqual(harness.session.appliedCIDs, [], context)
            XCTAssertEqual(harness.session.state, .invalid(.protocol), context)
        }
    }

    func testPreparedFailureOnSecondAndThirdCIDRestoresAllEarlierOwnedSiblings() {
        for (required, failingCID) in [
            (Set<UInt16>([0x005B, 0x005D]), UInt16(0x005D)),
            (Set<UInt16>([0x005B, 0x005D, 0x00D0]), UInt16(0x00D0)),
        ] {
            let harness = M720SessionHarness()
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            let requestIndex = harness.transport.sent.count
            harness.journal.failBeforeNextMutation = M720JournalFailurePoint(
                cid: failingCID,
                phase: .prepared
            )

            harness.session.setRequiredCIDs(required)
            driveTakeover(
                harness,
                startingAt: requestIndex,
                initialStates: baselineStates(0x005B, 0x005D, 0x00D0)
            )

            XCTAssertFalse(harness.requestKinds.contains(
                .setCidReporting(failingCID, diverted: true)
            ))
            XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
            XCTAssertEqual(harness.session.appliedCIDs, [])
            XCTAssertEqual(harness.session.state, .invalid(.protocol))
        }
    }

    func testSecondAndThirdCIDSetEchoReadbackAndAppliedFailuresRollbackWholeTransaction() {
        for (required, failingCID) in [
            (Set<UInt16>([0x005B, 0x005D]), UInt16(0x005D)),
            (Set<UInt16>([0x005B, 0x005D, 0x00D0]), UInt16(0x00D0)),
        ] {
            for fault in M720TakeoverFailure.allCases {
                let harness = M720SessionHarness()
                harness.session.start()
                driveDiscovery(harness, rows: referenceRows)
                let requestIndex = harness.transport.sent.count
                switch fault {
                case .setSend:
                    harness.sendFailureKind = .setCidReporting(failingCID, diverted: true)
                case .appliedSave:
                    harness.journal.failBeforeNextMutation = M720JournalFailurePoint(
                        cid: failingCID,
                        phase: .applied
                    )
                case .echo, .readback:
                    break
                }

                harness.session.setRequiredCIDs(required)
                driveTakeover(
                    harness,
                    startingAt: requestIndex,
                    initialStates: baselineStates(0x005B, 0x005D, 0x00D0),
                    injectedFailure: fault.driveFailure(cid: failingCID)
                )

                XCTAssertEqual(
                    harness.journal.currentJournal,
                    .emptyV1,
                    "failingCID=\(failingCID), fault=\(fault)"
                )
                XCTAssertEqual(harness.session.appliedCIDs, [])
                XCTAssertEqual(
                    harness.session.state,
                    .invalid(.protocol),
                    "failingCID=\(failingCID), fault=\(fault)"
                )
            }
        }
    }

    func testSecondCIDPostSetAuthoritativeGetFailureRetainsJournalAndFailsClosed() {
        for fault in M720PostSetReadFailure.allCases {
            let harness = M720SessionHarness()
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            let requestIndex = harness.transport.sent.count
            harness.onRequestSent = { kind in
                if kind == .setCidReporting(0x005D, diverted: true) {
                    harness.sendFailureKind = .getCidReporting(0x005D)
                }
            }
            if fault == .setSend {
                harness.sendFailureKind = .setCidReporting(0x005D, diverted: true)
            }

            harness.session.setRequiredCIDs([0x005B, 0x005D])
            driveTakeover(
                harness,
                startingAt: requestIndex,
                initialStates: baselineStates(0x005B, 0x005D),
                injectedFailure: fault == .badEcho ? .badEcho(cid: 0x005D) : nil
            )

            XCTAssertEqual(
                harness.journal.currentJournal.devices.first?.controls,
                [
                    journalEntry(cid: 0x005B, phase: .applied),
                    journalEntry(cid: 0x005D, phase: .prepared),
                ],
                "fault=\(fault)"
            )
            XCTAssertEqual(harness.session.appliedCIDs, [], "fault=\(fault)")
            XCTAssertNil(harness.pipeline.onEvent, "fault=\(fault)")
            XCTAssertFalse(
                harness.requestKinds.dropFirst(requestIndex).contains { kind in
                    if case .setCidReporting(_, diverted: false) = kind { return true }
                    return false
                },
                "fault=\(fault)"
            )
            XCTAssertEqual(
                harness.session.state,
                fault == .readback ? .invalid(.disconnected) : .invalid(.protocol),
                "fault=\(fault)"
            )
        }
    }

    func testRemovalSupersedesShutdownAndInvalidatesOnlyAfterAllHeldCancels() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B, 0x005D])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B, 0x005D)
        )
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B, 0x005D])
        drainMainQueue(turns: 3)
        harness.sink.automaticallyCompletesCancels = false
        let sentBeforeRemoval = harness.transport.sent.count
        var removalCompletions = 0
        var shutdownCompletions = 0

        harness.session.shutdown { shutdownCompletions += 1 }
        harness.session.invalidateForRemoval { removalCompletions += 1 }
        harness.session.invalidateForRemoval { removalCompletions += 1 }
        drainMainQueue(turns: 3)

        XCTAssertEqual(harness.sink.cancellations, [6, 7])
        XCTAssertEqual(harness.transport.invalidateCallCount, 0)
        XCTAssertEqual(harness.transport.sent.count, sentBeforeRemoval)
        XCTAssertEqual(removalCompletions, 0)
        XCTAssertEqual(shutdownCompletions, 0)

        harness.sink.completeCancel(button: 7, times: 2)
        drainMainQueue(turns: 3)
        XCTAssertEqual(harness.transport.invalidateCallCount, 0)

        harness.sink.completeCancel(button: 6)
        drainMainQueue(turns: 3)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
        XCTAssertEqual(removalCompletions, 2)
        XCTAssertEqual(shutdownCompletions, 1)
        XCTAssertEqual(harness.session.state, .invalid(.disconnected))
        XCTAssertEqual(harness.transport.sent.count, sentBeforeRemoval)

        harness.session.invalidateForRemoval { removalCompletions += 1 }
        drainMainQueue(turns: 3)
        XCTAssertEqual(removalCompletions, 3)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
    }

    func testRemovalClosesEventGateSynchronouslyBeforeQueuedOldReport() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        harness.sink.resetEmissions()
        let generationBeforeRemoval = harness.session.eventGeneration
        var removalCompletions = 0

        DispatchQueue.main.async {
            harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        }
        harness.session.invalidateForRemoval { removalCompletions += 1 }

        XCTAssertGreaterThan(harness.session.eventGeneration, generationBeforeRemoval)
        XCTAssertEqual(removalCompletions, 0)
        drainMainQueue(turns: 6)

        XCTAssertTrue(harness.sink.emissions.isEmpty)
        XCTAssertTrue(harness.sink.cancellations.isEmpty)
        XCTAssertEqual(removalCompletions, 1)
        XCTAssertEqual(harness.session.state, .invalid(.disconnected))
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
    }

    func testShutdownClosesEventGateSynchronouslyBeforeQueuedOldReport() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        harness.sink.resetEmissions()
        let rollbackStart = harness.transport.sent.count
        let generationBeforeShutdown = harness.session.eventGeneration
        var shutdownCompletions = 0

        DispatchQueue.main.async {
            harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        }
        harness.session.shutdown { shutdownCompletions += 1 }

        XCTAssertGreaterThan(harness.session.eventGeneration, generationBeforeShutdown)
        XCTAssertEqual(shutdownCompletions, 0)
        drainMainQueue(turns: 6)

        XCTAssertTrue(harness.sink.emissions.isEmpty)
        XCTAssertTrue(harness.sink.cancellations.isEmpty)
        driveTakeover(
            harness,
            startingAt: rollbackStart,
            initialStates: divertedStates(0x005B)
        )
        drainMainQueue(turns: 6)

        XCTAssertEqual(shutdownCompletions, 1)
        XCTAssertEqual(harness.session.state, .invalid(.cancelled))
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
    }

    func testShutdownThenRemovalWaitersCompleteOnlyAfterSingleTransportDrain() {
        let harness = M720SessionHarness()
        harness.transport.automaticallyCompletesInvalidation = false
        var events: [String] = []
        harness.session.onStateChange = { state in
            if state == .invalid(.disconnected) {
                events.append("observer")
            }
        }

        harness.session.shutdown { events.append("shutdown-1") }
        harness.session.shutdown { events.append("shutdown-2") }
        harness.session.invalidateForRemoval { events.append("removal-1") }
        harness.session.invalidateForRemoval { events.append("removal-2") }
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
        XCTAssertEqual(harness.transport.pendingInvalidationCompletionCount, 1)
        XCTAssertTrue(events.isEmpty)
        XCTAssertNotEqual(harness.session.state, .invalid(.disconnected))

        harness.transport.completeInvalidation()
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.session.state, .invalid(.disconnected))
        XCTAssertEqual(
            events,
            ["removal-1", "removal-2", "shutdown-1", "shutdown-2", "observer"]
        )
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)

        harness.session.shutdown { events.append("late-shutdown") }
        harness.session.invalidateForRemoval { events.append("late-removal") }
        XCTAssertEqual(events.count, 5)
        drainMainQueue(turns: 6)

        XCTAssertEqual(
            events,
            [
                "removal-1", "removal-2", "shutdown-1", "shutdown-2", "observer",
                "late-shutdown", "late-removal",
            ]
        )
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
    }

    func testRemovalThenShutdownWaitersCompleteOnlyAfterSingleTransportDrain() {
        let harness = M720SessionHarness()
        harness.transport.automaticallyCompletesInvalidation = false
        var events: [String] = []
        harness.session.onStateChange = { state in
            if state == .invalid(.disconnected) {
                events.append("observer")
            }
        }

        harness.session.invalidateForRemoval { events.append("removal-1") }
        harness.session.invalidateForRemoval { events.append("removal-2") }
        harness.session.shutdown { events.append("shutdown-1") }
        harness.session.shutdown { events.append("shutdown-2") }
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
        XCTAssertEqual(harness.transport.pendingInvalidationCompletionCount, 1)
        XCTAssertTrue(events.isEmpty)
        XCTAssertNotEqual(harness.session.state, .invalid(.disconnected))

        harness.transport.completeInvalidation()
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.session.state, .invalid(.disconnected))
        XCTAssertEqual(
            events,
            ["removal-1", "removal-2", "shutdown-1", "shutdown-2", "observer"]
        )
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)

        harness.session.invalidateForRemoval { events.append("late-removal") }
        harness.session.shutdown { events.append("late-shutdown") }
        XCTAssertEqual(events.count, 5)
        drainMainQueue(turns: 6)

        XCTAssertEqual(
            events,
            [
                "removal-1", "removal-2", "shutdown-1", "shutdown-2", "observer",
                "late-removal", "late-shutdown",
            ]
        )
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
    }

    func testTerminalDrainRejectsActiveDiscoveryCompletionBeforePublishingFinalState() {
        enum Intent {
            case shutdown
            case removal
        }

        for intent in [Intent.shutdown, .removal] {
            let harness = M720SessionHarness()
            harness.transport.automaticallyCompletesInvalidation = false
            var events: [String] = []
            harness.session.onStateChange = { state in
                if case .invalid = state {
                    events.append("observer")
                }
            }
            harness.session.start()
            drainMainQueue(turns: 3)
            XCTAssertEqual(harness.session.state, .discovering)
            XCTAssertEqual(harness.requestKinds, [.rootGetFeature])

            switch intent {
            case .shutdown:
                harness.session.shutdown { events.append("waiter") }
            case .removal:
                harness.session.invalidateForRemoval { events.append("waiter") }
            }
            drainMainQueue(turns: 6)

            XCTAssertEqual(harness.transport.invalidateCallCount, 1)
            XCTAssertEqual(harness.transport.pendingInvalidationCompletionCount, 1)
            XCTAssertEqual(harness.session.state, .discovering)
            XCTAssertTrue(events.isEmpty)

            harness.transport.completeInvalidation()
            drainMainQueue(turns: 6)

            let expectedState: M720SessionState
            switch intent {
            case .shutdown:
                expectedState = .invalid(.cancelled)
            case .removal:
                expectedState = .invalid(.disconnected)
            }
            XCTAssertEqual(harness.session.state, expectedState)
            XCTAssertEqual(events, ["waiter", "observer"])
        }
    }

    func testRemovalDuringHeldReloadRejectsStaleCompletionAndStartIsIdempotent() {
        let harness = M720SessionHarness(holdsReload: true)
        var completions = 0
        harness.session.start()
        harness.session.start()
        drainMainQueue(turns: 3)
        XCTAssertEqual(harness.trace.events, [.reloadBegin])

        harness.session.invalidateForRemoval { completions += 1 }
        drainMainQueue(turns: 3)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(harness.session.state, .invalid(.disconnected))

        harness.journal.completeReload()
        harness.session.start()
        drainMainQueue(turns: 3)
        XCTAssertTrue(harness.transport.sent.isEmpty)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
        XCTAssertEqual(harness.trace.events, [.reloadBegin, .reloadComplete])
    }

    func testRemovalDuringEveryDiscoveryRequestRejectsLateResponseWithoutAdvancing() {
        let stages: [M720TestRequestKind] = [
            .rootGetFeature,
            .getCount,
            .getCidInfo(4),
            .getCidReporting(0x005D),
        ]
        for stage in stages {
            let harness = M720SessionHarness()
            var completions = 0
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows, until: stage)
            let staleRequest = harness.request(at: harness.transport.sent.count - 1)
            XCTAssertEqual(staleRequest.kind, stage)

            harness.session.invalidateForRemoval { completions += 1 }
            drainMainQueue(turns: 6)
            let terminalRequestCount = harness.transport.sent.count
            let parameters: [UInt8]
            switch stage {
            case .rootGetFeature:
                parameters = [0x2A, 0x00, 0x04]
            case .getCount:
                parameters = [UInt8(referenceRows.count)]
            case let .getCidInfo(index):
                parameters = harness.controlInfoParameters(referenceRows[index])
            case let .getCidReporting(cid):
                parameters = harness.reportingParameters(baselineStates(cid)[cid]!)
            case .setCidReporting:
                preconditionFailure("not a discovery stage")
            }
            harness.respond(
                to: staleRequest,
                responseFeatureIndex: stage == .rootGetFeature ? 0 : 0x2A,
                parameters: parameters
            )
            drainMainQueue(turns: 6)

            XCTAssertEqual(harness.transport.sent.count, terminalRequestCount, "stage=\(stage)")
            XCTAssertEqual(harness.transport.invalidateCallCount, 1, "stage=\(stage)")
            XCTAssertEqual(completions, 1, "stage=\(stage)")
            XCTAssertEqual(harness.session.state, .invalid(.disconnected), "stage=\(stage)")
            XCTAssertEqual(harness.journal.mutationCallCount, 0, "stage=\(stage)")
        }
    }

    func testRemovalAtEveryTakeoverBoundaryRejectsLateCompletion() {
        for boundary in M720RemovalTakeoverBoundary.allCases {
            let harness = M720SessionHarness()
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            let requestIndex = harness.transport.sent.count
            var staleRequest: M720TestRequest?
            var hasHeldMutation = false
            var hasHeldSend = false
            switch boundary {
            case .preflight:
                harness.session.setRequiredCIDs([0x005B])
                drainMainQueue(turns: 4)
                staleRequest = harness.request(at: requestIndex)
            case .prepared:
                harness.journal.holdNextCompletionForPhase = .prepared
                harness.session.setRequiredCIDs([0x005B])
                driveTakeover(
                    harness,
                    startingAt: requestIndex,
                    initialStates: baselineStates(0x005B)
                )
                hasHeldMutation = true
            case .setSend, .setEcho, .readback:
                harness.session.setRequiredCIDs([0x005B])
                drainMainQueue(turns: 4)
                let preflight = harness.request(at: requestIndex)
                harness.respond(
                    to: preflight,
                    responseFeatureIndex: 0x2A,
                    parameters: harness.reportingParameters(baselineStates(0x005B)[0x005B]!)
                )
                if boundary == .setSend {
                    harness.transport.automaticallyCompletesSends = false
                }
                drainMainQueue(turns: 6)
                let pendingSet = harness.request(at: requestIndex + 1)
                if boundary == .setSend {
                    hasHeldSend = true
                } else if boundary == .setEcho {
                    staleRequest = pendingSet
                } else {
                    harness.respond(
                        to: pendingSet,
                        responseFeatureIndex: 0x2A,
                        parameters: ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: true)
                    )
                    drainMainQueue(turns: 6)
                    staleRequest = harness.request(at: requestIndex + 2)
                }
            case .applied:
                harness.journal.holdNextCompletionForPhase = .applied
                harness.session.setRequiredCIDs([0x005B])
                driveTakeover(
                    harness,
                    startingAt: requestIndex,
                    initialStates: baselineStates(0x005B)
                )
                hasHeldMutation = true
            }
            XCTAssertEqual(harness.session.state, .takingOver, "boundary=\(boundary)")
            if hasHeldMutation {
                XCTAssertTrue(harness.journal.hasHeldMutationCompletion, "boundary=\(boundary)")
            }
            var completions = 0

            harness.session.invalidateForRemoval { completions += 1 }
            drainMainQueue(turns: 6)
            let terminalRequestCount = harness.transport.sent.count
            let terminalMutationCount = harness.journal.mutationCallCount
            if let staleRequest {
                let parameters: [UInt8]
                switch staleRequest.kind {
                case .setCidReporting:
                    parameters = ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: true)
                default:
                    parameters = harness.reportingParameters(baselineStates(0x005B)[0x005B]!)
                }
                harness.respond(
                    to: staleRequest,
                    responseFeatureIndex: 0x2A,
                    parameters: parameters
                )
            }
            if hasHeldSend {
                harness.transport.automaticallyCompletesSends = true
                harness.transport.completeNextSend()
            }
            if hasHeldMutation {
                harness.journal.completeHeldMutation(times: 2)
            }
            drainMainQueue(turns: 8)

            XCTAssertEqual(harness.transport.sent.count, terminalRequestCount, "boundary=\(boundary)")
            XCTAssertEqual(harness.journal.mutationCallCount, terminalMutationCount, "boundary=\(boundary)")
            XCTAssertEqual(harness.transport.invalidateCallCount, 1, "boundary=\(boundary)")
            XCTAssertEqual(completions, 1, "boundary=\(boundary)")
            XCTAssertEqual(harness.session.appliedCIDs, [], "boundary=\(boundary)")
            XCTAssertEqual(harness.session.state, .invalid(.disconnected), "boundary=\(boundary)")
        }
    }

    func testRemovalAtEveryRollbackBoundaryRejectsLateCompletion() {
        for boundary in M720RemovalRollbackBoundary.allCases {
            let harness = M720SessionHarness()
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            var requestIndex = harness.transport.sent.count
            harness.session.setRequiredCIDs([0x005B])
            driveTakeover(
                harness,
                startingAt: requestIndex,
                initialStates: baselineStates(0x005B)
            )
            requestIndex = harness.transport.sent.count
            var staleRequest: M720TestRequest?
            var hasHeldMutation = false
            var hasHeldSend = false
            var hasHeldCancel = false

            switch boundary {
            case .cancel:
                harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
                drainMainQueue(turns: 4)
                harness.sink.automaticallyCompletesCancels = false
                harness.session.setRequiredCIDs([])
                drainMainQueue(turns: 6)
                hasHeldCancel = true
            case .compare:
                harness.session.setRequiredCIDs([])
                drainMainQueue(turns: 6)
                staleRequest = harness.request(at: requestIndex)
            case .restoring:
                harness.journal.holdNextCompletionForPhase = .restoring
                harness.session.setRequiredCIDs([])
                driveTakeover(
                    harness,
                    startingAt: requestIndex,
                    initialStates: divertedStates(0x005B)
                )
                hasHeldMutation = true
            case .setSend, .setEcho, .readback:
                harness.session.setRequiredCIDs([])
                drainMainQueue(turns: 6)
                let compare = harness.request(at: requestIndex)
                harness.respond(
                    to: compare,
                    responseFeatureIndex: 0x2A,
                    parameters: harness.reportingParameters(divertedStates(0x005B)[0x005B]!)
                )
                if boundary == .setSend {
                    harness.transport.automaticallyCompletesSends = false
                }
                drainMainQueue(turns: 6)
                let restoreSet = harness.request(at: requestIndex + 1)
                if boundary == .setSend {
                    hasHeldSend = true
                } else if boundary == .setEcho {
                    staleRequest = restoreSet
                } else {
                    harness.respond(
                        to: restoreSet,
                        responseFeatureIndex: 0x2A,
                        parameters: ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: false)
                    )
                    drainMainQueue(turns: 6)
                    staleRequest = harness.request(at: requestIndex + 2)
                }
            case .remove:
                harness.journal.holdNextMutationCompletion = M720JournalFailurePoint(
                    cid: 0x005B,
                    phase: nil
                )
                harness.session.setRequiredCIDs([])
                driveTakeover(
                    harness,
                    startingAt: requestIndex,
                    initialStates: baselineStates(0x005B)
                )
                hasHeldMutation = true
            }

            XCTAssertEqual(harness.session.state, .restoring, "boundary=\(boundary)")
            var completions = 0
            harness.session.invalidateForRemoval { completions += 1 }
            drainMainQueue(turns: 6)
            if hasHeldCancel {
                XCTAssertEqual(harness.transport.invalidateCallCount, 0)
                XCTAssertEqual(completions, 0)
            }
            let terminalRequestCount = harness.transport.sent.count
            let terminalMutationCount = harness.journal.mutationCallCount

            if let staleRequest {
                let parameters: [UInt8]
                switch staleRequest.kind {
                case .setCidReporting:
                    parameters = ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: false)
                case .getCidReporting:
                    parameters = harness.reportingParameters(baselineStates(0x005B)[0x005B]!)
                default:
                    preconditionFailure("unexpected rollback request")
                }
                harness.respond(
                    to: staleRequest,
                    responseFeatureIndex: 0x2A,
                    parameters: parameters
                )
            }
            if hasHeldSend {
                harness.transport.automaticallyCompletesSends = true
                harness.transport.completeNextSend()
            }
            if hasHeldMutation {
                harness.journal.completeHeldMutation(times: 2)
            }
            if hasHeldCancel {
                harness.sink.completeCancel(button: 6, times: 2)
            }
            drainMainQueue(turns: 8)

            XCTAssertEqual(harness.transport.sent.count, terminalRequestCount, "boundary=\(boundary)")
            XCTAssertEqual(harness.journal.mutationCallCount, terminalMutationCount, "boundary=\(boundary)")
            XCTAssertEqual(harness.transport.invalidateCallCount, 1, "boundary=\(boundary)")
            XCTAssertEqual(completions, 1, "boundary=\(boundary)")
            XCTAssertEqual(harness.session.state, .invalid(.disconnected), "boundary=\(boundary)")
        }
    }

    func testRemovalBeforeFirstStartMakesLaterStartAnIdempotentNoOp() {
        let harness = M720SessionHarness()
        var completions = 0

        harness.session.invalidateForRemoval { completions += 1 }
        harness.session.start()
        drainMainQueue(turns: 6)

        XCTAssertEqual(completions, 1)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
        XCTAssertTrue(harness.transport.sent.isEmpty)
        XCTAssertTrue(harness.trace.events.isEmpty)
        XCTAssertEqual(harness.session.state, .invalid(.disconnected))
    }

    func testShutdownBeforeFirstStartMakesLaterStartAnIdempotentNoOp() {
        let harness = M720SessionHarness()
        var completions = 0

        harness.session.shutdown { completions += 1 }
        harness.session.start()
        drainMainQueue(turns: 6)

        XCTAssertEqual(completions, 1)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
        XCTAssertTrue(harness.transport.sent.isEmpty)
        XCTAssertTrue(harness.trace.events.isEmpty)
        XCTAssertEqual(harness.session.state, .invalid(.cancelled))
    }

    func testRemovalSupersedesEveryAlreadyCompletedShutdownOrigin() {
        for origin in M720CompletedShutdownOrigin.allCases {
            let context = "origin=\(origin)"
            let harness = M720SessionHarness(
                journalIdentityUsable: origin != .invalid
            )
            switch origin {
            case .preStart:
                break
            case .nativeReady, .invalid:
                harness.session.start()
                driveDiscovery(harness, rows: referenceRows)
            case .conflict:
                harness.session.start()
                driveDiscovery(harness, rows: referenceRows)
                let takeoverStart = harness.transport.sent.count
                harness.session.setRequiredCIDs([0x005B])
                driveTakeover(
                    harness,
                    startingAt: takeoverStart,
                    initialStates: [
                        0x005B: HIDPPReportingState(
                            cid: 0x005B,
                            flags: 0x10,
                            remappedCID: 0x1234
                        ),
                    ]
                )
                XCTAssertEqual(harness.session.state, .conflict, context)
            }
            var shutdownCompletions = 0
            harness.session.shutdown { shutdownCompletions += 1 }
            drainMainQueue(turns: 6)

            let shutdownState: M720SessionState
            switch origin {
            case .preStart, .nativeReady:
                shutdownState = .invalid(.cancelled)
            case .conflict:
                shutdownState = .invalid(.conflict)
            case .invalid:
                shutdownState = .invalid(.unsupported)
            }
            XCTAssertEqual(harness.session.state, shutdownState, context)
            XCTAssertEqual(shutdownCompletions, 1, context)
            XCTAssertEqual(harness.transport.invalidateCallCount, 1, context)
            let sentAfterShutdown = harness.transport.sent.count
            var disconnectedNotifications = 0
            var removalEvents: [String] = []
            harness.session.onStateChange = { state in
                if state == .invalid(.disconnected) {
                    disconnectedNotifications += 1
                    removalEvents.append("observer")
                }
            }
            var removalCompletions = 0
            var stateAtRemovalCompletion: [M720SessionState] = []
            var invalidationsAtRemovalCompletion: [Int] = []

            harness.session.invalidateForRemoval {
                removalCompletions += 1
                stateAtRemovalCompletion.append(harness.session.state)
                invalidationsAtRemovalCompletion.append(
                    harness.transport.invalidateCallCount
                )
                removalEvents.append("completion")
            }
            XCTAssertEqual(removalCompletions, 0, context)
            drainMainQueue(turns: 6)

            XCTAssertEqual(harness.session.state, .invalid(.disconnected), context)
            XCTAssertEqual(removalCompletions, 1, context)
            XCTAssertEqual(disconnectedNotifications, 1, context)
            XCTAssertEqual(removalEvents, ["completion", "observer"], context)
            XCTAssertEqual(stateAtRemovalCompletion, [.invalid(.disconnected)], context)
            XCTAssertEqual(invalidationsAtRemovalCompletion, [1], context)
            XCTAssertEqual(harness.transport.invalidateCallCount, 1, context)
            XCTAssertEqual(harness.transport.sent.count, sentAfterShutdown, context)
            XCTAssertTrue(harness.sink.cancellations.isEmpty, context)

            harness.session.invalidateForRemoval {
                removalCompletions += 1
                removalEvents.append("repeat-completion")
            }
            XCTAssertEqual(removalCompletions, 1, context)
            drainMainQueue(turns: 6)
            XCTAssertEqual(removalCompletions, 2, context)
            XCTAssertEqual(disconnectedNotifications, 1, context)
            XCTAssertEqual(
                removalEvents,
                ["completion", "observer", "repeat-completion"],
                context
            )
            XCTAssertEqual(harness.transport.invalidateCallCount, 1, context)

            harness.session.shutdown { shutdownCompletions += 1 }
            drainMainQueue(turns: 6)
            XCTAssertEqual(shutdownCompletions, 2, context)
            XCTAssertEqual(harness.session.state, .invalid(.disconnected), context)
            XCTAssertEqual(disconnectedNotifications, 1, context)
            XCTAssertEqual(harness.transport.invalidateCallCount, 1, context)
        }
    }

    func testShutdownRestoresOwnershipBeforeSingleTransportInvalidation() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B)
        )
        requestIndex = harness.transport.sent.count
        var completions = 0

        harness.session.shutdown { completions += 1 }
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: divertedStates(0x005B)
        )

        XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(harness.session.state, .invalid(.cancelled))

        harness.session.shutdown { completions += 1 }
        drainMainQueue(turns: 3)
        XCTAssertEqual(completions, 2)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
    }

    func testShutdownDuringTakeoverJournalFailureStillFinalizesAfterOwnedSiblingRollback() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.journal.holdFailureBeforeNextMutation = M720JournalFailurePoint(
            cid: 0x005D,
            phase: .prepared
        )
        harness.session.setRequiredCIDs([0x005B, 0x005D])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B, 0x005D)
        )
        XCTAssertTrue(harness.journal.hasHeldMutationCompletion)
        XCTAssertEqual(harness.session.state, .takingOver)
        requestIndex = harness.transport.sent.count
        var completions = 0

        harness.session.shutdown { completions += 1 }
        harness.journal.completeHeldMutation()
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: [
                0x005B: divertedStates(0x005B)[0x005B]!,
                0x005D: baselineStates(0x005D)[0x005D]!,
            ]
        )

        XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
        XCTAssertEqual(harness.session.appliedCIDs, [])
        XCTAssertEqual(harness.session.state, .invalid(.cancelled))
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
    }

    func testPolicySetBeforeStartStillCompletesDiscoveryBeforeTakeover() {
        let harness = M720SessionHarness()
        harness.session.setRequiredCIDs([0x00D0])
        harness.session.start()
        driveDiscovery(
            harness,
            rows: referenceRows,
            stopAfterDiscoverySnapshots: true
        )
        let takeoverStart = 2 + referenceRows.count + M720Profile.cidToButton.count

        XCTAssertEqual(harness.requestKinds.prefix(takeoverStart), [
            .rootGetFeature,
            .getCount,
        ] + referenceRows.indices.map(M720TestRequestKind.getCidInfo) + [
            .getCidReporting(0x005B),
            .getCidReporting(0x005D),
            .getCidReporting(0x00D0),
        ])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x00D0)
        )
        XCTAssertEqual(harness.session.state, .active)
        XCTAssertEqual(harness.session.appliedCIDs, [0x00D0])
    }

    func testFreshPreflightExternalFullStateChangeConflictsWithZeroJournalAndSet() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        let external = HIDPPReportingState(cid: 0x005D, flags: 0x10, remappedCID: 0x1234)

        harness.session.setRequiredCIDs([0x005B, 0x005D])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: [
                0x005B: HIDPPReportingState(cid: 0x005B, flags: 0, remappedCID: 0x005B),
                0x005D: external,
            ]
        )

        XCTAssertEqual(harness.requestKinds.dropFirst(takeoverStart), [
            .getCidReporting(0x005B),
            .getCidReporting(0x005D),
        ])
        XCTAssertEqual(harness.journal.mutationCallCount, 0)
        XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
        XCTAssertEqual(harness.session.state, .conflict)
    }

    func testShutdownRestoreFailureDrainsWaitersAndPreservesRealInvalidReason() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B)
        )
        requestIndex = harness.transport.sent.count
        harness.sendFailureKind = .setCidReporting(0x005B, diverted: false)
        var completions = 0

        harness.session.shutdown { completions += 1 }
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: divertedStates(0x005B),
            restoreFault: M720RestoreDriveFault(
                cid: 0x005B,
                attempt: .sendFailure,
                outcome: .intended
            )
        )

        XCTAssertEqual(completions, 1)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
        XCTAssertEqual(harness.session.state, .invalid(.disconnected))
        XCTAssertEqual(harness.journal.currentJournal.devices.first?.controls.first?.phase, .restoring)

        harness.session.shutdown { completions += 1 }
        drainMainQueue(turns: 3)
        XCTAssertEqual(completions, 2)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
    }

    func testShutdownFromConflictPreservesConflictReasonAndDrainsWaiters() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: [
                0x005B: HIDPPReportingState(cid: 0x005B, flags: 0x10, remappedCID: 0x1234),
            ]
        )
        XCTAssertEqual(harness.session.state, .conflict)
        var completions = 0

        harness.session.shutdown { completions += 1 }
        harness.session.shutdown { completions += 1 }
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.session.state, .invalid(.conflict))
        XCTAssertEqual(completions, 2)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
    }

    func testShutdownFromExistingInvalidStatePreservesOriginalReason() {
        let harness = M720SessionHarness()
        harness.sendFailureKind = .rootGetFeature
        harness.session.start()
        drainMainQueue(turns: 6)
        XCTAssertEqual(harness.session.state, .invalid(.disconnected))
        var completions = 0

        harness.session.shutdown { completions += 1 }
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.session.state, .invalid(.disconnected))
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
    }

    func testUnsupportedPolicyWhileActiveCancelsHeldInputAndRestoresBeforeInvalid() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B)
        )
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 4)
        harness.sink.automaticallyCompletesCancels = false
        requestIndex = harness.transport.sent.count

        harness.session.setRequiredCIDs([0xFFFF])
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.session.state, .restoring)
        XCTAssertEqual(harness.sink.cancellations, [6])
        XCTAssertEqual(harness.transport.sent.count, requestIndex)

        harness.sink.completeCancel(button: 6)
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: divertedStates(0x005B)
        )

        XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
        XCTAssertEqual(harness.session.appliedCIDs, [])
        XCTAssertEqual(harness.session.state, .invalid(.unsupported))
    }

    func testUnsupportedPolicyDuringTakeoverWaitsForSetBoundaryThenRollsBackTouchedCID() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        drainMainQueue(turns: 4)

        let preflight = harness.request(at: requestIndex)
        XCTAssertEqual(preflight.kind, .getCidReporting(0x005B))
        harness.respond(
            to: preflight,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(baselineStates(0x005B)[0x005B]!)
        )
        drainMainQueue(turns: 6)
        let pendingSet = harness.request(at: requestIndex + 1)
        XCTAssertEqual(pendingSet.kind, .setCidReporting(0x005B, diverted: true))

        harness.session.setRequiredCIDs([0xFFFF])
        drainMainQueue(turns: 4)
        XCTAssertEqual(harness.session.state, .takingOver)

        harness.respond(
            to: pendingSet,
            responseFeatureIndex: 0x2A,
            parameters: ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: true)
        )
        driveTakeover(
            harness,
            startingAt: requestIndex + 2,
            initialStates: divertedStates(0x005B)
        )

        XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
        XCTAssertEqual(harness.session.appliedCIDs, [])
        XCTAssertEqual(harness.session.state, .invalid(.unsupported))
    }

    func testUnsupportedPolicyDuringRestoreFinishesCleanupThenInvalidates() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B)
        )
        requestIndex = harness.transport.sent.count

        harness.session.setRequiredCIDs([])
        drainMainQueue(turns: 4)
        XCTAssertEqual(harness.session.state, .restoring)
        XCTAssertEqual(harness.request(at: requestIndex).kind, .getCidReporting(0x005B))

        harness.session.setRequiredCIDs([0xFFFF])
        drainMainQueue(turns: 4)
        XCTAssertEqual(harness.session.state, .restoring)
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: divertedStates(0x005B)
        )

        XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
        XCTAssertEqual(harness.session.appliedCIDs, [])
        XCTAssertEqual(harness.session.state, .invalid(.unsupported))
    }

    func testUnsupportedPolicySetBeforeStartFailsAfterDiscoveryWithoutTakeoverWrite() {
        let harness = M720SessionHarness()
        harness.session.setRequiredCIDs([0xFFFF])
        harness.session.start()

        driveDiscovery(harness, rows: referenceRows)

        XCTAssertEqual(harness.session.state, .invalid(.unsupported))
        XCTAssertEqual(harness.journal.mutationCallCount, 0)
        assertNoSet(harness)
    }

    func testIdentityDowngradeBeforeStartWaitsForGetOnlyDiagnosticsThenBecomesUnsupported() {
        let harness = M720SessionHarness()

        harness.session.markJournalIdentityUnusable()

        XCTAssertEqual(harness.session.state, .discovering)
        XCTAssertTrue(harness.transport.sent.isEmpty)

        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)

        XCTAssertEqual(harness.session.state, .invalid(.unsupported))
        XCTAssertEqual(harness.journal.mutationCallCount, 0)
        assertNoSet(harness)
    }

    func testIdentityDowngradeDuringDiscoveryStopsAmbiguousRecoveryAndRejectsLateReply() {
        let matchingJournal = M720OwnershipJournal(
            version: M720OwnershipJournal.currentVersion,
            devices: [
                M720JournalDevice(
                    key: M720SessionHarness.defaultDeviceKey,
                    controls: [journalEntry(cid: 0x005B)]
                ),
            ]
        )
        let harness = M720SessionHarness(initialJournal: matchingJournal)
        harness.session.start()
        drainMainQueue(turns: 4)
        let staleRootRequest = harness.request(at: 0)

        harness.session.markJournalIdentityUnusable()
        drainMainQueue(turns: 4)

        XCTAssertEqual(harness.session.state, .invalid(.unsupported))
        XCTAssertEqual(harness.transport.sent.count, 1)
        XCTAssertEqual(harness.journal.mutationCallCount, 0)

        harness.respond(
            to: staleRootRequest,
            responseFeatureIndex: 0,
            parameters: [0x2A, 0x00, 0x04]
        )
        drainMainQueue(turns: 6)

        XCTAssertEqual(harness.transport.sent.count, 1)
        XCTAssertEqual(harness.session.state, .invalid(.unsupported))
        XCTAssertEqual(harness.journal.currentJournal, matchingJournal)
        assertNoSet(harness)
    }

    func testIdentityDowngradeWhileActiveCancelsHeldInputAndRestoresBeforeUnsupported() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B)
        )
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 4)
        harness.sink.automaticallyCompletesCancels = false
        harness.sink.resetEmissions()
        requestIndex = harness.transport.sent.count
        let requiredBeforeDowngrade = harness.session.requiredCIDs
        let eventGenerationBeforeDowngrade = harness.session.eventGeneration

        DispatchQueue.main.async {
            harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [])
        }
        XCTAssertTrue(Thread.isMainThread)

        harness.session.markJournalIdentityUnusable()

        XCTAssertEqual(harness.session.state, .restoring)
        XCTAssertEqual(harness.sink.cancellations, [6])
        XCTAssertEqual(harness.transport.sent.count, requestIndex)
        XCTAssertTrue(harness.sink.emissions.isEmpty)
        XCTAssertEqual(harness.session.requiredCIDs, requiredBeforeDowngrade)
        XCTAssertEqual(harness.session.eventGeneration, eventGenerationBeforeDowngrade + 1)

        let eventGenerationAfterDowngrade = harness.session.eventGeneration
        harness.session.markJournalIdentityUnusable()
        XCTAssertEqual(harness.session.state, .restoring)
        XCTAssertEqual(harness.session.eventGeneration, eventGenerationAfterDowngrade)
        XCTAssertEqual(harness.sink.cancellations, [6])

        drainMainQueue(turns: 5)
        XCTAssertTrue(harness.sink.emissions.isEmpty, "queued old-generation reports must see the closed gate")

        harness.sink.completeCancel(button: 6)
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: divertedStates(0x005B)
        )

        XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
        XCTAssertEqual(harness.session.appliedCIDs, [])
        XCTAssertEqual(harness.session.state, .invalid(.unsupported))
    }

    func testActivePolicyReplacementClosesEventGateSynchronouslyOnMainTurn() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B, 0x005D)
        )
        harness.sink.resetEmissions()
        let eventGenerationBeforeReplacement = harness.session.eventGeneration

        DispatchQueue.main.async {
            harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        }
        XCTAssertTrue(Thread.isMainThread)

        harness.session.setRequiredCIDs([0x005D])

        XCTAssertEqual(harness.session.state, .restoring)
        XCTAssertEqual(harness.session.requiredCIDs, [0x005D])
        XCTAssertEqual(
            harness.session.eventGeneration,
            eventGenerationBeforeReplacement + 1
        )
        XCTAssertTrue(harness.sink.emissions.isEmpty)

        drainMainQueue(turns: 5)
        XCTAssertTrue(
            harness.sink.emissions.isEmpty,
            "queued old-policy reports must observe the synchronously closed gate"
        )
    }

    func testIdentityDowngradeDuringTakeoverWaitsForWriteBoundaryThenRollsBackTouchedCID() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        drainMainQueue(turns: 4)

        let preflight = harness.request(at: requestIndex)
        harness.respond(
            to: preflight,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(baselineStates(0x005B)[0x005B]!)
        )
        drainMainQueue(turns: 6)
        let pendingSet = harness.request(at: requestIndex + 1)
        XCTAssertEqual(pendingSet.kind, .setCidReporting(0x005B, diverted: true))

        harness.session.markJournalIdentityUnusable()
        harness.session.markJournalIdentityUnusable()
        drainMainQueue(turns: 4)

        XCTAssertEqual(harness.session.state, .takingOver)

        harness.respond(
            to: pendingSet,
            responseFeatureIndex: 0x2A,
            parameters: ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: true)
        )
        driveTakeover(
            harness,
            startingAt: requestIndex + 2,
            initialStates: divertedStates(0x005B)
        )

        XCTAssertEqual(harness.journal.currentJournal, .emptyV1)
        XCTAssertEqual(harness.session.appliedCIDs, [])
        XCTAssertEqual(harness.session.state, .invalid(.unsupported))
    }

    func testSleepOverlayClosesGateAndCancelsWithoutRestoreOrPublicStateChange() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        let takeoverStart = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: takeoverStart,
            initialStates: baselineStates(0x005B)
        )
        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005B])
        drainMainQueue(turns: 3)
        harness.sink.automaticallyCompletesCancels = false
        let sentBeforeSleep = harness.transport.sent.count
        var completions = 0

        harness.session.prepareForSleep { completions += 1 }
        drainMainQueue(turns: 3)
        XCTAssertEqual(harness.session.state, .active)
        XCTAssertEqual(harness.sink.cancellations, [6])
        XCTAssertEqual(harness.transport.sent.count, sentBeforeSleep)
        XCTAssertEqual(completions, 0)

        harness.injectEvent(featureIndex: 0x2A, event: 0, cids: [])
        harness.sink.completeCancel(button: 6)
        drainMainQueue(turns: 3)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(harness.session.state, .active)
        XCTAssertEqual(harness.transport.sent.count, sentBeforeSleep)
        XCTAssertEqual(harness.sink.emissions, [
            M720SinkEmission(button: 6, downNotUp: true),
        ])
    }

    func testActiveExpansionFullyRestoresOldSetThenFreshPreflightsWholeNewSet() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B, 0x005D)
        )
        requestIndex = harness.transport.sent.count
        harness.trace.removeAll()

        harness.session.setRequiredCIDs([0x005B, 0x005D])
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: [
                0x005B: HIDPPReportingState(cid: 0x005B, flags: 1, remappedCID: 0x005B),
                0x005D: HIDPPReportingState(cid: 0x005D, flags: 0, remappedCID: 0x005D),
            ]
        )

        XCTAssertEqual(Array(harness.trace.events.prefix(8)), [
            .request(.getCidReporting(0x005B)),
            .journal(cid: 0x005B, phase: .restoring),
            .request(.setCidReporting(0x005B, diverted: false)),
            .request(.getCidReporting(0x005B)),
            .journal(cid: 0x005B, phase: nil),
            .request(.getCidReporting(0x005B)),
            .request(.getCidReporting(0x005D)),
            .journal(cid: 0x005B, phase: .prepared),
        ])
        XCTAssertEqual(harness.session.appliedCIDs, [0x005B, 0x005D])
        XCTAssertEqual(harness.session.state, .active)
    }

    func testAddModeAllTargetPolicyReturnsThroughExistingRollbackForSubsetAndEmpty() {
        let allTargets = Set(M720Profile.cidToButton.keys)
        let fixtures: [(saved: Set<UInt16>, state: M720SessionState)] = [
            ([0x005B], .active),
            ([], .nativeReady),
        ]

        for fixture in fixtures {
            let harness = M720SessionHarness()
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            var requestIndex = harness.transport.sent.count
            harness.session.setRequiredCIDs(allTargets)
            driveTakeover(
                harness,
                startingAt: requestIndex,
                initialStates: baselineStates(0x005B, 0x005D, 0x00D0)
            )
            XCTAssertEqual(harness.session.appliedCIDs, allTargets)
            XCTAssertEqual(harness.session.state, .active)

            requestIndex = harness.transport.sent.count
            harness.trace.removeAll()
            harness.session.setRequiredCIDs(fixture.saved)
            driveTakeover(
                harness,
                startingAt: requestIndex,
                initialStates: divertedStates(0x005B, 0x005D, 0x00D0)
            )

            let setDirections = harness.trace.events.compactMap { event -> Bool? in
                guard case let .request(.setCidReporting(_, diverted)) = event else {
                    return nil
                }
                return diverted
            }
            XCTAssertEqual(
                setDirections,
                fixture.saved.isEmpty
                    ? [false, false, false]
                    : [false, false, false, true]
            )
            XCTAssertEqual(harness.session.requiredCIDs, fixture.saved)
            XCTAssertEqual(harness.session.appliedCIDs, fixture.saved)
            XCTAssertEqual(harness.session.state, fixture.state)
            XCTAssertEqual(
                Set(harness.journal.currentJournal.devices
                    .flatMap(\.controls)
                    .map(\.cid)),
                fixture.saved
            )
        }
    }

    func testEveryNonemptyRequiredSubsetPublishesExactlyThatAtomicSet() {
        let cids: [UInt16] = [0x005B, 0x005D, 0x00D0]
        for mask in 1..<(1 << cids.count) {
            let required = Set(cids.enumerated().compactMap { index, cid in
                mask & (1 << index) == 0 ? nil : cid
            })
            let harness = M720SessionHarness()
            harness.session.start()
            driveDiscovery(harness, rows: referenceRows)
            let takeoverStart = harness.transport.sent.count
            harness.session.setRequiredCIDs(required)
            driveTakeover(
                harness,
                startingAt: takeoverStart,
                initialStates: baselineStates(0x005B, 0x005D, 0x00D0)
            )

            XCTAssertEqual(harness.session.requiredCIDs, required)
            XCTAssertEqual(harness.session.appliedCIDs, required)
            XCTAssertEqual(harness.session.state, .active)
        }
    }

    func testPolicyABAInvalidatesOldTransactionEvenWhenDesiredSetReturnsEqual() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var requestIndex = harness.transport.sent.count
        harness.trace.removeAll()
        harness.journal.holdNextCompletionForPhase = .prepared
        let policyA: Set<UInt16> = [0x005B, 0x005D]

        harness.session.setRequiredCIDs(policyA)
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B, 0x005D, 0x00D0)
        )
        XCTAssertTrue(harness.journal.hasHeldMutationCompletion)

        harness.session.setRequiredCIDs([0x00D0])
        harness.session.setRequiredCIDs(policyA)
        drainMainQueue(turns: 3)
        requestIndex = harness.transport.sent.count
        harness.journal.completeHeldMutation()
        driveTakeover(
            harness,
            startingAt: requestIndex,
            initialStates: baselineStates(0x005B, 0x005D, 0x00D0)
        )

        let events = harness.trace.events
        let firstPrepared = try? XCTUnwrap(events.firstIndex(of: .journal(cid: 0x005B, phase: .prepared)))
        let removal = try? XCTUnwrap(events.firstIndex(of: .journal(cid: 0x005B, phase: nil)))
        let firstSet = try? XCTUnwrap(events.firstIndex(of: .request(.setCidReporting(0x005B, diverted: true))))
        XCTAssertNotNil(firstPrepared)
        XCTAssertNotNil(removal)
        XCTAssertNotNil(firstSet)
        if let removal, let firstSet {
            XCTAssertLessThan(removal, firstSet)
        }
        XCTAssertEqual(harness.session.requiredCIDs, policyA)
        XCTAssertEqual(harness.session.appliedCIDs, policyA)
        XCTAssertEqual(harness.session.state, .active)
    }

    func testDuplicateOldAppliedCompletionCannotEnterLaterTakingOverState() {
        let harness = M720SessionHarness()
        harness.session.start()
        driveDiscovery(harness, rows: referenceRows)
        var responseIndex = harness.transport.sent.count
        harness.journal.holdNextCompletionForPhase = .applied
        harness.session.setRequiredCIDs([0x005B])
        driveTakeover(
            harness,
            startingAt: responseIndex,
            initialStates: baselineStates(0x005B, 0x005D)
        )
        XCTAssertTrue(harness.journal.hasHeldMutationCompletion)
        responseIndex = harness.transport.sent.count

        harness.session.setRequiredCIDs([0x005D])
        harness.journal.completeHeldMutation()
        drainMainQueue(turns: 6)
        let compare = harness.request(at: responseIndex)
        XCTAssertEqual(compare.kind, .getCidReporting(0x005B))
        harness.respond(
            to: compare,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(divertedStates(0x005B)[0x005B]!)
        )
        drainMainQueue(turns: 6)
        let restoreSet = harness.request(at: responseIndex + 1)
        XCTAssertEqual(restoreSet.kind, .setCidReporting(0x005B, diverted: false))
        harness.respond(
            to: restoreSet,
            responseFeatureIndex: 0x2A,
            parameters: ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: false)
        )
        drainMainQueue(turns: 6)
        let restoreReadback = harness.request(at: responseIndex + 2)
        XCTAssertEqual(restoreReadback.kind, .getCidReporting(0x005B))
        harness.respond(
            to: restoreReadback,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(baselineStates(0x005B)[0x005B]!)
        )
        drainMainQueue(turns: 8)
        let freshPreflightIndex = responseIndex + 3
        XCTAssertEqual(harness.request(at: freshPreflightIndex).kind, .getCidReporting(0x005D))
        XCTAssertEqual(harness.session.state, .takingOver)
        let requestCount = harness.transport.sent.count
        let mutationCount = harness.journal.mutationCallCount

        harness.journal.replayLastMutationCompletion(times: 2)
        drainMainQueue(turns: 8)

        XCTAssertEqual(harness.session.state, .takingOver)
        XCTAssertEqual(harness.transport.sent.count, requestCount)
        XCTAssertEqual(harness.journal.mutationCallCount, mutationCount)
        driveTakeover(
            harness,
            startingAt: freshPreflightIndex,
            initialStates: baselineStates(0x005B, 0x005D)
        )
        XCTAssertEqual(harness.session.state, .active)
        XCTAssertEqual(harness.session.appliedCIDs, [0x005D])
    }

    func testTwoSessionsSharingCoordinatorNeverLoseTheOtherDeviceMutation() {
        let sharedTrace = M720SessionTraceRecorder()
        let sharedJournal = M720SessionJournalCoordinator(
            trace: sharedTrace,
            initialJournal: .emptyV1,
            reloadResult: nil,
            holdsReload: false
        )
        let keyA = M720SessionHarness.defaultDeviceKey
        let keyB = M720DeviceKey(
            vendorID: M720Profile.vendorID,
            productID: M720Profile.bluetoothLEProductID,
            transport: M720Profile.bluetoothLETransport,
            serialNumber: "session-test-b"
        )
        let sessionA = M720SessionHarness(
            deviceKey: keyA,
            journalCoordinator: sharedJournal
        )
        let sessionB = M720SessionHarness(
            deviceKey: keyB,
            journalCoordinator: sharedJournal
        )
        sessionA.session.start()
        sessionB.session.start()
        driveDiscovery(sessionA, rows: referenceRows)
        driveDiscovery(sessionB, rows: referenceRows)
        var requestA = sessionA.transport.sent.count
        var requestB = sessionB.transport.sent.count
        sharedJournal.holdNextCompletionForPhase = .prepared

        sessionA.session.setRequiredCIDs([0x005B])
        driveTakeover(
            sessionA,
            startingAt: requestA,
            initialStates: baselineStates(0x005B)
        )
        XCTAssertTrue(sharedJournal.hasHeldMutationCompletion)

        sessionB.session.setRequiredCIDs([0x005D])
        driveTakeover(
            sessionB,
            startingAt: requestB,
            initialStates: baselineStates(0x005D)
        )
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: sharedJournal.currentJournal.devices.map { ($0.key, $0.controls) }),
            [
                keyA: [journalEntry(cid: 0x005B, phase: .prepared)],
                keyB: [journalEntry(cid: 0x005D, phase: .applied)],
            ]
        )

        requestA = sessionA.transport.sent.count
        sharedJournal.completeHeldMutation()
        driveTakeover(
            sessionA,
            startingAt: requestA,
            initialStates: baselineStates(0x005B)
        )
        XCTAssertEqual(sessionA.session.state, .active)
        XCTAssertEqual(sessionB.session.state, .active)

        requestA = sessionA.transport.sent.count
        sessionA.session.setRequiredCIDs([])
        driveTakeover(
            sessionA,
            startingAt: requestA,
            initialStates: divertedStates(0x005B)
        )
        XCTAssertNil(sharedJournal.currentJournal.devices.first { $0.key == keyA })
        XCTAssertEqual(
            sharedJournal.currentJournal.devices.first { $0.key == keyB }?.controls,
            [journalEntry(cid: 0x005D, phase: .applied)]
        )
        XCTAssertEqual(sessionB.session.state, .active)
        sessionB.injectEvent(featureIndex: 0x2A, event: 0, cids: [0x005D])
        drainMainQueue(turns: 4)
        XCTAssertEqual(sessionB.sink.emissions, [
            M720SinkEmission(button: 7, downNotUp: true),
        ])

        requestB = sessionB.transport.sent.count
        sessionB.session.setRequiredCIDs([])
        driveTakeover(
            sessionB,
            startingAt: requestB,
            initialStates: divertedStates(0x005D)
        )
        XCTAssertEqual(sharedJournal.currentJournal, .emptyV1)
    }

    private var referenceRows: [HIDPPControlInfo] {
        [
            control(0x0052, flags: 0x01),
            control(0x0053, flags: 0x01),
            control(0x0056, flags: 0x01),
            control(0x005B, flags: 0x21),
            control(0x005D, flags: 0x21),
            control(0x00C4, flags: 0x01),
            control(0x00D0, flags: 0x21),
            control(0x00D1, flags: 0x01),
            control(0x00D2, flags: 0x01),
        ]
    }

    private func control(_ cid: UInt16, flags: UInt8) -> HIDPPControlInfo {
        HIDPPControlInfo(
            cid: cid,
            taskID: cid,
            flags: flags,
            position: 0,
            group: 0,
            groupMask: 0,
            rawXYFlags: 0
        )
    }

    private func baselineStates(_ cids: UInt16...) -> [UInt16: HIDPPReportingState] {
        Dictionary(uniqueKeysWithValues: cids.map { cid in
            (cid, HIDPPReportingState(cid: cid, flags: 0, remappedCID: cid))
        })
    }

    private func divertedStates(_ cids: UInt16...) -> [UInt16: HIDPPReportingState] {
        Dictionary(uniqueKeysWithValues: cids.map { cid in
            let baseline = HIDPPReportingState(cid: cid, flags: 0, remappedCID: cid)
            return (cid, baseline.changingDivert(to: true))
        })
    }

    private func conflictedHarness() -> M720SessionHarness {
        let harness = M720SessionHarness()
        harness.session.setRequiredCIDs([0x005B])
        harness.session.start()
        let unknown = HIDPPReportingState(cid: 0x005B, flags: 0x11, remappedCID: 0x5555)
        driveDiscovery(
            harness,
            rows: referenceRows,
            reportingOverrides: [0x005B: unknown]
        )
        XCTAssertEqual(harness.session.state, .conflict)
        return harness
    }

    private func wireParameters(_ documented: [UInt8]) -> [UInt8] {
        documented + [UInt8](repeating: 0, count: 16 - documented.count)
    }

    private func journalEntry(
        cid: UInt16,
        phase: M720JournalPhase = .applied
    ) -> M720JournalCIDEntry {
        let original = HIDPPReportingState(cid: cid, flags: 0, remappedCID: cid)
        return M720JournalCIDEntry(
            cid: cid,
            original: original,
            intended: original.changingDivert(to: true),
            phase: phase
        )
    }

    private func driveDiscovery(
        _ harness: M720SessionHarness,
        rows: [HIDPPControlInfo],
        reportingOverrides: [UInt16: HIDPPReportingState] = [:],
        until target: M720TestRequestKind? = nil,
        startingAt startIndex: Int = 0,
        stopAfterDiscoverySnapshots: Bool = false,
        featureIndex: UInt8 = 0x2A
    ) {
        var responseIndex = startIndex
        for _ in 0..<100 {
            drainMainQueue(turns: 3)
            guard responseIndex < harness.transport.sent.count else { break }
            let request = harness.request(at: responseIndex)
            if request.kind == target { return }
            let parameters: [UInt8]
            switch request.kind {
            case .rootGetFeature:
                parameters = [featureIndex, 0x00, 0x04]
            case .getCount:
                parameters = [UInt8(rows.count)]
            case let .getCidInfo(index):
                guard rows.indices.contains(index) else {
                    XCTFail("unexpected row index \(index)")
                    return
                }
                parameters = harness.controlInfoParameters(rows[index])
            case let .getCidReporting(cid):
                parameters = harness.reportingParameters(reportingOverrides[cid] ?? HIDPPReportingState(
                    cid: cid,
                    flags: 0,
                    remappedCID: cid
                ))
            case .setCidReporting:
                XCTFail("discovery must not write policy")
                return
            }
            harness.respond(
                to: request,
                responseFeatureIndex: request.kind == .rootGetFeature ? 0x00 : featureIndex,
                parameters: parameters
            )
            responseIndex += 1
            if stopAfterDiscoverySnapshots,
               responseIndex == startIndex + 2 + rows.count + M720Profile.cidToButton.count {
                drainMainQueue(turns: 3)
                return
            }
        }
        drainMainQueue(turns: 3)
    }

    private func driveExplicitRetryBaseline(
        _ harness: M720SessionHarness,
        startingAt startIndex: Int,
        states: [UInt16: HIDPPReportingState],
        featureIndex: UInt8 = 0x2A
    ) {
        var responseIndex = startIndex
        for cid in M720Profile.cidToButton.keys.sorted() {
            drainMainQueue(turns: 4)
            guard responseIndex < harness.transport.sent.count else {
                XCTFail("missing explicit retry read for CID \(cid)")
                return
            }
            let request = harness.request(at: responseIndex)
            XCTAssertEqual(request.kind, .getCidReporting(cid))
            guard let state = states[cid] else {
                XCTFail("missing retry state for CID \(cid)")
                return
            }
            harness.respond(
                to: request,
                responseFeatureIndex: featureIndex,
                parameters: harness.reportingParameters(state)
            )
            responseIndex += 1
        }
        drainMainQueue(turns: 5)
    }

    private func exhaustTimeouts(_ harness: M720SessionHarness) {
        harness.scheduler.advance(by: 1.0)
        drainMainQueue(turns: 3)
        harness.scheduler.advance(by: 0.2)
        drainMainQueue(turns: 3)
        harness.scheduler.advance(by: 1.0)
        drainMainQueue(turns: 3)
    }

    private func assertNoSet(
        _ harness: M720SessionHarness,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(harness.requestKinds.contains { kind in
            if case .setCidReporting = kind { return true }
            return false
        }, file: file, line: line)
    }

    private func driveTakeover(
        _ harness: M720SessionHarness,
        startingAt startIndex: Int,
        initialStates: [UInt16: HIDPPReportingState],
        injectedFailure: M720TakeoverDriveFailure? = nil,
        restoreFault: M720RestoreDriveFault? = nil,
        responseFeatureIndex: UInt8 = 0x2A
    ) {
        var states = initialStates
        var responseIndex = startIndex
        var setCIDs = Set<UInt16>()
        var consumedDriveFailure = false
        var compoundBadEchoSent = false
        var consumedRestoreFault = false
        var pendingRestoreReadback: M720RestoreDriveFault?
        for _ in 0..<100 {
            drainMainQueue(turns: 3)
            guard responseIndex < harness.transport.sent.count else { break }
            let request = harness.request(at: responseIndex)
            let parameters: [UInt8]
            switch request.kind {
            case let .getCidReporting(cid):
                guard let current = states[cid] else {
                    XCTFail("missing state for CID \(cid)")
                    return
                }
                if let pending = pendingRestoreReadback, pending.cid == cid {
                    switch pending.outcome {
                    case .original, .intended, .third, .getFailure:
                        parameters = harness.reportingParameters(current)
                    case .malformed:
                        parameters = harness.reportingParameters(HIDPPReportingState(
                            cid: cid &+ 1,
                            flags: current.flags,
                            remappedCID: current.remappedCID
                        ))
                    }
                    pendingRestoreReadback = nil
                } else if !consumedDriveFailure,
                   injectedFailure == .readbackOriginal(cid: cid),
                   setCIDs.contains(cid) {
                    let original = HIDPPReportingState(cid: cid, flags: 0, remappedCID: cid)
                    states[cid] = original
                    parameters = harness.reportingParameters(original)
                    consumedDriveFailure = true
                } else if !consumedDriveFailure,
                          case let .some(.readbackThirdThenRollbackIntended(
                              failureCID,
                              third
                          )) = injectedFailure,
                          failureCID == cid,
                          setCIDs.contains(cid) {
                    parameters = harness.reportingParameters(third)
                    consumedDriveFailure = true
                } else if compoundBadEchoSent,
                          !consumedDriveFailure,
                          case let .some(.badEchoThenThirdReadbackThenRollbackIntended(
                              failureCID,
                              third
                          )) = injectedFailure,
                          failureCID == cid {
                    parameters = harness.reportingParameters(third)
                    consumedDriveFailure = true
                } else {
                    parameters = harness.reportingParameters(current)
                }
            case let .setCidReporting(cid, diverted):
                guard let current = states[cid] else {
                    XCTFail("missing state for CID \(cid)")
                    return
                }
                let expectedSet = ReprogControlsV4.setReportingParameters(
                    cid: cid,
                    diverted: diverted
                )
                let matchingRestoreFault = !consumedRestoreFault &&
                    restoreFault?.cid == cid &&
                    diverted == false
                if matchingRestoreFault, let restoreFault {
                    pendingRestoreReadback = restoreFault
                    consumedRestoreFault = true
                    switch restoreFault.outcome {
                    case .original:
                        states[cid] = HIDPPReportingState(
                            cid: cid,
                            flags: 0,
                            remappedCID: cid
                        )
                    case .intended, .getFailure, .malformed:
                        states[cid] = current.changingDivert(to: true)
                    case .third:
                        states[cid] = HIDPPReportingState(
                            cid: cid,
                            flags: 0x10,
                            remappedCID: 0x1234
                        )
                    }
                } else if Array(request.parameters.prefix(5)) == expectedSet,
                          request.parameters.dropFirst(5).allSatisfy({ $0 == 0 }) {
                    states[cid] = current.changingDivert(to: diverted)
                }
                setCIDs.insert(cid)
                if matchingRestoreFault, restoreFault?.attempt == .badEcho {
                    var badEcho = expectedSet
                    badEcho[4] ^= 0x01
                    parameters = badEcho
                } else if !compoundBadEchoSent,
                          case let .some(.badEchoThenThirdReadbackThenRollbackIntended(
                              failureCID,
                              _
                          )) = injectedFailure,
                          failureCID == cid {
                    var badEcho = expectedSet
                    badEcho[4] ^= 0x01
                    parameters = badEcho
                    compoundBadEchoSent = true
                } else if !consumedDriveFailure,
                   injectedFailure == .badEcho(cid: cid) {
                    var badEcho = expectedSet
                    badEcho[4] ^= 0x01
                    parameters = badEcho
                    consumedDriveFailure = true
                } else {
                    parameters = expectedSet
                }
            default:
                XCTFail("unexpected takeover request \(request.kind)")
                return
            }
            harness.respond(
                to: request,
                responseFeatureIndex: responseFeatureIndex,
                parameters: parameters
            )
            responseIndex += 1
        }
        drainMainQueue(turns: 3)
    }

    private func advanceToSecondCIDAuthoritativeReadback(
        _ harness: M720SessionHarness,
        path: M720DelayedTakeoverReadbackPath,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> M720TestRequest {
        let start = harness.transport.sent.count
        harness.session.setRequiredCIDs([0x005B, 0x005D])
        drainMainQueue(turns: 4)

        let preflight5B = harness.request(at: start)
        XCTAssertEqual(preflight5B.kind, .getCidReporting(0x005B), file: file, line: line)
        harness.respond(
            to: preflight5B,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(baselineStates(0x005B)[0x005B]!)
        )
        drainMainQueue(turns: 4)

        let preflight5D = harness.request(at: start + 1)
        XCTAssertEqual(preflight5D.kind, .getCidReporting(0x005D), file: file, line: line)
        harness.respond(
            to: preflight5D,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(baselineStates(0x005D)[0x005D]!)
        )
        drainMainQueue(turns: 5)

        let set5B = harness.request(at: start + 2)
        XCTAssertEqual(
            set5B.kind,
            .setCidReporting(0x005B, diverted: true),
            file: file,
            line: line
        )
        harness.respond(
            to: set5B,
            responseFeatureIndex: 0x2A,
            parameters: ReprogControlsV4.setReportingParameters(cid: 0x005B, diverted: true)
        )
        drainMainQueue(turns: 4)

        let readback5B = harness.request(at: start + 3)
        XCTAssertEqual(readback5B.kind, .getCidReporting(0x005B), file: file, line: line)
        harness.respond(
            to: readback5B,
            responseFeatureIndex: 0x2A,
            parameters: harness.reportingParameters(divertedStates(0x005B)[0x005B]!)
        )
        drainMainQueue(turns: 5)

        let set5D = harness.request(at: start + 4)
        XCTAssertEqual(
            set5D.kind,
            .setCidReporting(0x005D, diverted: true),
            file: file,
            line: line
        )
        var echo = ReprogControlsV4.setReportingParameters(cid: 0x005D, diverted: true)
        if path == .uncertain {
            echo[4] ^= 0x01
        }
        harness.respond(
            to: set5D,
            responseFeatureIndex: 0x2A,
            parameters: echo
        )
        drainMainQueue(turns: 5)

        let pendingReadback = harness.request(at: start + 5)
        XCTAssertEqual(
            pendingReadback.kind,
            .getCidReporting(0x005D),
            file: file,
            line: line
        )
        return pendingReadback
    }

    private func drainMainQueue(turns: Int) {
        let drained = expectation(description: "main queue drained")
        func drain(_ remaining: Int) {
            guard remaining > 0 else {
                drained.fulfill()
                return
            }
            DispatchQueue.main.async { drain(remaining - 1) }
        }
        drain(turns)
        wait(for: [drained], timeout: 3)
    }
}

private enum M720TestRequestKind: Equatable {
    case rootGetFeature
    case getCount
    case getCidInfo(Int)
    case getCidReporting(UInt16)
    case setCidReporting(UInt16, diverted: Bool)
}

private enum M720DiscoveryFault: CaseIterable {
    case transport
    case device
    case timeout
    case malformed
}

private enum M720TakeoverDriveFailure: Equatable {
    case badEcho(cid: UInt16)
    case readbackOriginal(cid: UInt16)
    case readbackThirdThenRollbackIntended(cid: UInt16, third: HIDPPReportingState)
    case badEchoThenThirdReadbackThenRollbackIntended(
        cid: UInt16,
        third: HIDPPReportingState
    )
}

private enum M720DelayedTakeoverReadbackPath: CaseIterable, Equatable {
    case normal
    case uncertain
}

private enum M720TakeoverInterruption: CaseIterable {
    case policy
    case shutdown
}

private enum M720TrustedReadbackOwnership: CaseIterable {
    case third
    case original
}

private enum M720RestoreAttemptFault: CaseIterable, Equatable {
    case sendFailure
    case badEcho
    case successfulEcho
}

private enum M720RestoreReadbackOutcome: CaseIterable, Equatable {
    case original
    case intended
    case third
    case getFailure
    case malformed
}

private enum M720CancelBatchOwner: CaseIterable, Equatable {
    case policy
    case shutdown
    case removal
}

private enum M720CompletedShutdownOrigin: CaseIterable, Equatable {
    case preStart
    case nativeReady
    case conflict
    case invalid
}

private struct M720RestoreDriveFault: Equatable {
    let cid: UInt16
    let attempt: M720RestoreAttemptFault
    let outcome: M720RestoreReadbackOutcome
}

private enum M720TakeoverFailure: CaseIterable {
    case setSend
    case echo
    case readback
    case appliedSave

    func driveFailure(cid: UInt16) -> M720TakeoverDriveFailure? {
        switch self {
        case .echo: return .badEcho(cid: cid)
        case .readback: return .readbackOriginal(cid: cid)
        case .setSend, .appliedSave: return nil
        }
    }
}

private enum M720RemovalTakeoverBoundary: CaseIterable {
    case preflight
    case prepared
    case setSend
    case setEcho
    case readback
    case applied
}

private enum M720PolicyTakeoverBoundary: CaseIterable {
    case preflight
    case setSend
    case setEcho
    case readback
    case applied
}

private enum M720RemovalRollbackBoundary: CaseIterable {
    case cancel
    case compare
    case restoring
    case setSend
    case setEcho
    case readback
    case remove
}

private enum M720PostSetReadFailure: CaseIterable {
    case setSend
    case badEcho
    case readback
}

private struct M720JournalFailurePoint: Equatable {
    let cid: UInt16
    let phase: M720JournalPhase?
}

private enum M720InjectedError: Error {
    case mutation
}

private struct M720TestRequest {
    let identityByte: UInt8
    let featureIndex: UInt8
    let kind: M720TestRequestKind
    let parameters: [UInt8]
}

private struct M720SemanticRequest: Equatable {
    let featureIndex: UInt8
    let function: UInt8
    let parameters: [UInt8]
}

private enum M720SessionTraceEvent: Equatable {
    case reloadBegin
    case reloadComplete
    case request(M720TestRequestKind)
    case journal(cid: UInt16, phase: M720JournalPhase?)
}

private final class M720SessionTraceRecorder {
    private let lock = NSLock()
    private var storage: [M720SessionTraceEvent] = []

    var events: [M720SessionTraceEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ event: M720SessionTraceEvent) {
        lock.lock()
        storage.append(event)
        lock.unlock()
    }

    func removeAll() {
        lock.lock()
        storage.removeAll()
        lock.unlock()
    }
}

private final class M720SessionHarness {
    static let defaultDeviceKey = M720DeviceKey(
        vendorID: M720Profile.vendorID,
        productID: M720Profile.bluetoothLEProductID,
        transport: M720Profile.bluetoothLETransport,
        serialNumber: "session-test"
    )

    let transport = ScriptedHIDPPTransport()
    let scheduler = ManualScheduler()
    let pipeline: HIDPPRequestPipeline
    let session: M720HIDPPSession
    let trace = M720SessionTraceRecorder()
    let journal: M720SessionJournalCoordinator
    let sink: M720SessionButtonSink
    let ownershipAgentProbe: M720OwnershipAgentProbe
    var sendFailureKind: M720TestRequestKind?
    var onRequestSent: ((M720TestRequestKind) -> Void)?

    init(
        initialJournal: M720OwnershipJournal = .emptyV1,
        reloadResult: Result<M720OwnershipJournal, Error>? = nil,
        holdsReload: Bool = false,
        deviceKey: M720DeviceKey = M720SessionHarness.defaultDeviceKey,
        journalIdentityUsable: Bool = true,
        journalCoordinator: M720SessionJournalCoordinator? = nil,
        initialOwnershipAgentIsRunning: Bool = false
    ) {
        journal = journalCoordinator ?? M720SessionJournalCoordinator(
            trace: trace,
            initialJournal: initialJournal,
            reloadResult: reloadResult,
            holdsReload: holdsReload
        )
        sink = M720SessionButtonSink(trace: trace)
        ownershipAgentProbe = M720OwnershipAgentProbe(isRunning: initialOwnershipAgentIsRunning)
        pipeline = HIDPPRequestPipeline(
            transport: transport,
            scheduler: scheduler,
            stateQueue: .main
        )
        session = M720HIDPPSession(
            device: Device.unitTestDevice(),
            pipeline: pipeline,
            journalRepository: journal,
            deviceKey: deviceKey,
            journalIdentityUsable: journalIdentityUsable,
            buttonSink: sink,
            scheduler: scheduler,
            initialOwnershipAgentScan: { [ownershipAgentProbe] in
                ownershipAgentProbe.scanCount += 1
                return ownershipAgentProbe.isRunning
            }
        )
        transport.onSend = { [weak self] data in
            guard let self else { return }
            let kind = self.request(data: data).kind
            self.trace.append(.request(kind))
            if kind == self.sendFailureKind {
                self.sendFailureKind = nil
                self.transport.automaticSendResult = kIOReturnNotResponding
                DispatchQueue.main.async { [weak self] in
                    self?.transport.automaticSendResult = kIOReturnSuccess
                }
            }
            self.onRequestSent?(kind)
        }
    }

    var requestKinds: [M720TestRequestKind] {
        transport.sent.map { request(data: $0).kind }
    }

    var semanticRequests: [M720SemanticRequest] {
        transport.sent.map { data in
            let request = request(data: data)
            return M720SemanticRequest(
                featureIndex: request.featureIndex,
                function: request.identityByte >> 4,
                parameters: request.parameters
            )
        }
    }

    func request(at index: Int) -> M720TestRequest {
        request(data: transport.sent[index])
    }

    func respond(
        to request: M720TestRequest,
        responseFeatureIndex: UInt8,
        parameters: [UInt8]
    ) {
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = 0x11
        bytes[1] = transport.deviceIndex
        bytes[2] = responseFeatureIndex
        bytes[3] = request.identityByte
        bytes.replaceSubrange(4..<(4 + parameters.count), with: parameters)
        transport.inject(bytes)
    }

    func controlInfoParameters(_ info: HIDPPControlInfo) -> [UInt8] {
        bigEndian(info.cid) + bigEndian(info.taskID) + [
            info.flags,
            info.position,
            info.group,
            info.groupMask,
            info.rawXYFlags,
        ]
    }

    func reportingParameters(_ state: HIDPPReportingState) -> [UInt8] {
        bigEndian(state.cid) + [state.flags] + bigEndian(state.remappedCID)
    }

    func injectEvent(featureIndex: UInt8, event: UInt8, cids: [UInt16]) {
        precondition(cids.count <= 4)
        let parameters = eventParameters(cids: cids)
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = 0x11
        bytes[1] = transport.deviceIndex
        bytes[2] = featureIndex
        bytes[3] = event << 4
        bytes.replaceSubrange(4..<20, with: parameters)
        transport.inject(bytes)
    }

    func injectForeignResponse(featureIndex: UInt8, function: UInt8, softwareID: UInt8 = 0xF) {
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = 0x11
        bytes[1] = transport.deviceIndex
        bytes[2] = featureIndex
        bytes[3] = function << 4 | softwareID
        transport.inject(bytes)
    }

    func eventParameters(cids: [UInt16]) -> [UInt8] {
        precondition(cids.count <= 4)
        var parameters = cids.flatMap(bigEndian)
        parameters.append(contentsOf: repeatElement(0, count: 16 - parameters.count))
        return parameters
    }

    func request(data: Data) -> M720TestRequest {
        let bytes = [UInt8](data)
        let featureIndex = bytes[2]
        let identityByte = bytes[3]
        let function = identityByte >> 4
        let kind: M720TestRequestKind
        switch (featureIndex, function) {
        case (0, 0):
            kind = .rootGetFeature
        case (_, ReprogControlsV4.Function.getCount.rawValue):
            kind = .getCount
        case (_, ReprogControlsV4.Function.getCidInfo.rawValue):
            kind = .getCidInfo(Int(bytes[4]))
        case (_, ReprogControlsV4.Function.getCidReporting.rawValue):
            kind = .getCidReporting(uint16(bytes[4], bytes[5]))
        case (_, ReprogControlsV4.Function.setCidReporting.rawValue):
            kind = .setCidReporting(
                uint16(bytes[4], bytes[5]),
                diverted: bytes[6] & 0x01 != 0
            )
        default:
            preconditionFailure("unknown request")
        }
        return M720TestRequest(
            identityByte: identityByte,
            featureIndex: featureIndex,
            kind: kind,
            parameters: Array(bytes[4...])
        )
    }


    func respondWithDeviceError(to request: M720TestRequest, code: UInt8) {
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = 0x11
        bytes[1] = transport.deviceIndex
        bytes[2] = 0xFF
        bytes[3] = request.featureIndex
        bytes[4] = request.identityByte
        bytes[5] = code
        transport.inject(bytes)
    }

    private func bigEndian(_ value: UInt16) -> [UInt8] {
        [UInt8(value >> 8), UInt8(value & 0x00FF)]
    }

    private func uint16(_ high: UInt8, _ low: UInt8) -> UInt16 {
        UInt16(high) << 8 | UInt16(low)
    }
}

private final class M720OwnershipAgentProbe {
    let isRunning: Bool
    var scanCount = 0

    init(isRunning: Bool) {
        self.isRunning = isRunning
    }
}

private struct M720SinkEmission: Equatable {
    let button: Int
    let downNotUp: Bool
}

private final class M720SessionButtonSink: M720ButtonEventSink {
    private let trace: M720SessionTraceRecorder
    private(set) var emissions: [M720SinkEmission] = []
    private(set) var cancellations: [Int] = []
    var automaticallyCompletesCancels = true
    var onEmit: ((M720SinkEmission) -> Void)?
    private var pendingCancelCompletions: [Int: [() -> Void]] = [:]

    init(trace: M720SessionTraceRecorder) {
        self.trace = trace
    }

    func emit(device: Device, button: Int, downNotUp: Bool) {
        let emission = M720SinkEmission(button: button, downNotUp: downNotUp)
        emissions.append(emission)
        onEmit?(emission)
    }

    func cancel(device: Device, button: Int, completion: @escaping () -> Void) {
        cancellations.append(button)
        if automaticallyCompletesCancels {
            completion()
        } else {
            pendingCancelCompletions[button, default: []].append(completion)
        }
    }

    func completeCancel(button: Int, times: Int = 1) {
        guard let completion = pendingCancelCompletions[button]?.first else {
            preconditionFailure("no pending cancel for button \(button)")
        }
        for _ in 0..<times { completion() }
        pendingCancelCompletions[button]?.removeFirst()
    }

    func resetEmissions() {
        emissions.removeAll()
    }
}

private final class M720SessionJournalCoordinator: M720JournalCoordinating {
    private var journal: M720OwnershipJournal
    private let trace: M720SessionTraceRecorder
    var reloadResult: Result<M720OwnershipJournal, Error>?
    private let holdsReload: Bool
    private var heldReloadCompletion: Completion?
    private var reloadCompletionHistory: [(Completion, Result<M720OwnershipJournal, Error>)] = []
    var onMutation: ((M720SessionTraceEvent) -> Void)?
    private(set) var mutationCallCount = 0
    private(set) var acknowledgementCallCount = 0
    private(set) var removeDeviceCallCount = 0
    var holdNextCompletionForPhase: M720JournalPhase?
    var holdNextMutationCompletion: M720JournalFailurePoint?
    var failAfterNextPhase: M720JournalPhase?
    var failBeforeNextMutation: M720JournalFailurePoint?
    var failAfterNextMutation: M720JournalFailurePoint?
    var failedAfterMutationPersistsChange = true
    var holdFailureBeforeNextMutation: M720JournalFailurePoint?
    var replaceEntryBeforeNextMutation: M720JournalCIDEntry?
    var acknowledgementError: Error?
    var acknowledgementFailurePersistsChange = false
    var removeDeviceError: Error?
    var replaceDeviceBeforeNextRemove: M720JournalDevice?
    var holdNextRemoveCompletion = false
    private var heldMutationCompletion: (() -> Void)?
    private var heldRemoveCompletion: (() -> Void)?
    private var lastReleasedMutationCompletion: (() -> Void)?
    private var didAcknowledgeQuarantine = false

    init(
        trace: M720SessionTraceRecorder,
        initialJournal: M720OwnershipJournal,
        reloadResult: Result<M720OwnershipJournal, Error>?,
        holdsReload: Bool
    ) {
        self.trace = trace
        journal = initialJournal
        self.reloadResult = reloadResult
        self.holdsReload = holdsReload
    }

    var currentJournal: M720OwnershipJournal {
        journal
    }

    var hasHeldMutationCompletion: Bool {
        heldMutationCompletion != nil
    }

    var hasHeldRemoveCompletion: Bool {
        heldRemoveCompletion != nil
    }

    func completeHeldMutation(times: Int = 1) {
        guard let completion = heldMutationCompletion else {
            preconditionFailure("no held mutation")
        }
        heldMutationCompletion = nil
        lastReleasedMutationCompletion = completion
        for _ in 0..<times { completion() }
    }

    func replayLastMutationCompletion(times: Int = 1) {
        guard let completion = lastReleasedMutationCompletion else {
            preconditionFailure("no released mutation completion")
        }
        for _ in 0..<times { completion() }
    }

    func completeHeldRemove() {
        guard let completion = heldRemoveCompletion else {
            preconditionFailure("no held remove")
        }
        heldRemoveCompletion = nil
        completion()
    }

    func reload(completion: @escaping Completion) {
        trace.append(.reloadBegin)
        if holdsReload {
            heldReloadCompletion = completion
        } else {
            complete(completion)
        }
    }

    func completeReload(
        on queue: DispatchQueue? = nil,
        didInvoke: (() -> Void)? = nil
    ) {
        guard let completion = heldReloadCompletion else {
            preconditionFailure("no held reload")
        }
        heldReloadCompletion = nil
        let invoke = { [self] in
            complete(completion)
            didInvoke?()
        }
        if let queue {
            queue.async(execute: invoke)
        } else {
            invoke()
        }
    }

    private func complete(_ completion: @escaping Completion) {
        trace.append(.reloadComplete)
        let result = didAcknowledgeQuarantine ? .success(journal) :
            (reloadResult ?? .success(journal))
        reloadCompletionHistory.append((completion, result))
        completion(result)
    }

    func replayReloadCompletion(at index: Int) {
        guard reloadCompletionHistory.indices.contains(index) else {
            preconditionFailure("no reload completion at index \(index)")
        }
        let (completion, result) = reloadCompletionHistory[index]
        completion(result)
    }

    func snapshot(completion: @escaping Completion) {
        completion(.success(journal))
    }

    func acknowledgeQuarantineWithFreshEmptyV1(completion: @escaping Completion) {
        acknowledgementCallCount += 1
        if let acknowledgementError {
            if acknowledgementFailurePersistsChange {
                didAcknowledgeQuarantine = true
                journal = .emptyV1
            }
            completion(.failure(acknowledgementError))
            return
        }
        if didAcknowledgeQuarantine {
            completion(.failure(M720JournalStoreError.notQuarantined))
            return
        }
        didAcknowledgeQuarantine = true
        journal = .emptyV1
        completion(.success(journal))
    }

    func removeDevice(
        for key: M720DeviceKey,
        expected: M720JournalDevice?,
        completion: @escaping Completion
    ) {
        removeDeviceCallCount += 1
        if let removeDeviceError {
            completion(.failure(removeDeviceError))
            return
        }
        if let replacement = replaceDeviceBeforeNextRemove {
            journal.devices.removeAll { $0.key == replacement.key }
            journal.devices.append(replacement)
            replaceDeviceBeforeNextRemove = nil
        }
        let deviceIndex = journal.devices.firstIndex { $0.key == key }
        let existing = deviceIndex.map { journal.devices[$0] }
        guard existing == expected else {
            completion(.failure(M720JournalRepositoryError.mismatchedDevice))
            return
        }
        if let deviceIndex {
            journal.devices.remove(at: deviceIndex)
        }
        do {
            journal = try journal.validatedCanonicalized()
            let result = journal
            if holdNextRemoveCompletion {
                holdNextRemoveCompletion = false
                heldRemoveCompletion = { completion(.success(result)) }
            } else {
                completion(.success(result))
            }
        } catch {
            completion(.failure(error))
        }
    }

    func mutateCID(
        for key: M720DeviceKey,
        cid: UInt16,
        mutation: @escaping (M720JournalCIDEntry?) throws -> M720JournalCIDEntry?,
        completion: @escaping Completion
    ) {
        mutationCallCount += 1
        do {
            if let replacement = replaceEntryBeforeNextMutation,
               replacement.cid == cid,
               let replacementDeviceIndex = journal.devices.firstIndex(where: { $0.key == key }),
               let replacementControlIndex = journal.devices[replacementDeviceIndex].controls
                .firstIndex(where: { $0.cid == cid }) {
                journal.devices[replacementDeviceIndex].controls[replacementControlIndex] = replacement
                journal = try journal.validatedCanonicalized()
                replaceEntryBeforeNextMutation = nil
            }
            let journalBeforeMutation = journal
            let deviceIndex = journal.devices.firstIndex { $0.key == key }
            let controlIndex = deviceIndex.flatMap { deviceIndex in
                journal.devices[deviceIndex].controls.firstIndex { $0.cid == cid }
            }
            let existing = deviceIndex.flatMap { deviceIndex in
                controlIndex.map { journal.devices[deviceIndex].controls[$0] }
            }
            let updated = try mutation(existing)
            let point = M720JournalFailurePoint(cid: cid, phase: updated?.phase)
            if point == holdFailureBeforeNextMutation {
                holdFailureBeforeNextMutation = nil
                heldMutationCompletion = {
                    completion(.failure(M720InjectedError.mutation))
                }
                return
            }
            if point == failBeforeNextMutation {
                failBeforeNextMutation = nil
                completion(.failure(M720InjectedError.mutation))
                return
            }
            if let updated {
                if let deviceIndex {
                    if let controlIndex {
                        journal.devices[deviceIndex].controls[controlIndex] = updated
                    } else {
                        journal.devices[deviceIndex].controls.append(updated)
                    }
                } else {
                    journal.devices.append(M720JournalDevice(key: key, controls: [updated]))
                }
            } else if let deviceIndex, let controlIndex {
                journal.devices[deviceIndex].controls.remove(at: controlIndex)
                if journal.devices[deviceIndex].controls.isEmpty {
                    journal.devices.remove(at: deviceIndex)
                }
            }
            journal = try journal.validatedCanonicalized()
            let event = M720SessionTraceEvent.journal(cid: cid, phase: updated?.phase)
            trace.append(event)
            onMutation?(event)
            let result = Result<M720OwnershipJournal, Error>.success(journal)
            if point == failAfterNextMutation {
                failAfterNextMutation = nil
                if !failedAfterMutationPersistsChange {
                    journal = journalBeforeMutation
                }
                completion(.failure(M720JournalStoreError.uncertain))
            } else if let failedPhase = failAfterNextPhase,
               updated?.phase == failedPhase {
                failAfterNextPhase = nil
                completion(.failure(M720JournalStoreError.uncertain))
            } else if point == holdNextMutationCompletion {
                holdNextMutationCompletion = nil
                heldMutationCompletion = { completion(result) }
            } else if let heldPhase = holdNextCompletionForPhase,
               updated?.phase == heldPhase {
                holdNextCompletionForPhase = nil
                heldMutationCompletion = { completion(result) }
            } else {
                completion(result)
            }
        } catch {
            completion(.failure(error))
        }
    }
}
