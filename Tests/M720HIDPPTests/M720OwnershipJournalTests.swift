import Foundation
import Darwin
import XCTest
@testable import Mac_Mouse_Fix_Helper

final class M720OwnershipJournalTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
    }

    func testJournalModelRoundTripsThroughPropertyList() throws {
        let journal = M720OwnershipJournal(
            version: M720OwnershipJournal.currentVersion,
            devices: [M720JournalDevice(
                key: fixtureKey(),
                controls: [fixtureEntry(phase: .prepared)]
            )]
        )

        let data = try PropertyListEncoder().encode(journal)

        XCTAssertEqual(
            try PropertyListDecoder().decode(M720OwnershipJournal.self, from: data),
            journal
        )
    }

    func testRecoveryDecisionTableForIntendedState() {
        let rows: [(M720JournalPhase, Bool, M720RecoveryDecision)] = [
            (.prepared, true, .setAppliedThenKeep),
            (.prepared, false, .setAppliedThenRestore),
            (.applied, true, .keepApplied),
            (.applied, false, .restore),
            (.restoring, true, .setAppliedThenKeep),
            (.restoring, false, .restore),
        ]

        for (phase, policyRequiresCapture, expected) in rows {
            let entry = fixtureEntry(phase: phase)
            XCTAssertEqual(
                M720OwnershipRecovery.decide(
                    entry: entry,
                    current: entry.intended,
                    policyRequiresCapture: policyRequiresCapture
                ),
                expected,
                "phase=\(phase), policy=\(policyRequiresCapture)"
            )
        }
    }

    func testEveryPhaseClearsWhenCurrentStateIsOriginal() {
        for phase in [M720JournalPhase.prepared, .applied, .restoring] {
            let entry = fixtureEntry(phase: phase)
            for policyRequiresCapture in [false, true] {
                XCTAssertEqual(
                    M720OwnershipRecovery.decide(
                        entry: entry,
                        current: entry.original,
                        policyRequiresCapture: policyRequiresCapture
                    ),
                    .clearThenReconcile
                )
            }
        }
    }

    func testEveryPhaseConflictsForAnyThirdFullReportingState() {
        for phase in [M720JournalPhase.prepared, .applied, .restoring] {
            let entry = fixtureEntry(phase: phase)
            let thirdStates = [
                HIDPPReportingState(
                    cid: entry.cid ^ 0x0001,
                    flags: entry.intended.flags,
                    remappedCID: entry.intended.remappedCID
                ),
                HIDPPReportingState(
                    cid: entry.cid,
                    flags: entry.intended.flags ^ 0x04,
                    remappedCID: entry.intended.remappedCID
                ),
                HIDPPReportingState(
                    cid: entry.cid,
                    flags: entry.intended.flags,
                    remappedCID: entry.intended.remappedCID ^ 0x0001
                ),
            ]
            for thirdState in thirdStates {
                for policyRequiresCapture in [false, true] {
                    XCTAssertEqual(
                        M720OwnershipRecovery.decide(
                            entry: entry,
                            current: thirdState,
                            policyRequiresCapture: policyRequiresCapture
                        ),
                        .conflict
                    )
                }
            }
        }
    }

    func testSemanticValidationRejectsEveryJournalInvariantViolation() {
        let key = fixtureKey()
        let entry = fixtureEntry(phase: .prepared)
        let original = entry.original
        let invalidJournals: [(String, M720OwnershipJournal)] = [
            ("version", journal(version: 2, key: key, controls: [entry])),
            ("negative vendor", journal(key: fixtureKey(vendorID: -1), controls: [entry])),
            ("large vendor", journal(key: fixtureKey(vendorID: 65_536), controls: [entry])),
            ("negative product", journal(key: fixtureKey(productID: -1), controls: [entry])),
            ("large product", journal(key: fixtureKey(productID: 65_536), controls: [entry])),
            ("empty transport", journal(key: fixtureKey(transport: ""), controls: [entry])),
            ("empty serial", journal(key: fixtureKey(serialNumber: ""), controls: [entry])),
            ("empty controls", journal(key: key, controls: [])),
            ("duplicate CID", journal(key: key, controls: [entry, entry])),
            ("unsupported CID", journal(key: key, controls: [fixtureEntry(cid: 0x1234, phase: .prepared)])),
            ("original CID mismatch", journal(key: key, controls: [M720JournalCIDEntry(
                cid: entry.cid,
                original: HIDPPReportingState(cid: 0x005D, flags: original.flags, remappedCID: original.remappedCID),
                intended: entry.intended,
                phase: .prepared
            )])),
            ("intended CID mismatch", journal(key: key, controls: [M720JournalCIDEntry(
                cid: entry.cid,
                original: original,
                intended: HIDPPReportingState(cid: 0x005D, flags: entry.intended.flags, remappedCID: entry.intended.remappedCID),
                phase: .prepared
            )])),
            ("original diverted", journal(key: key, controls: [M720JournalCIDEntry(
                cid: entry.cid,
                original: entry.intended,
                intended: entry.intended,
                phase: .prepared
            )])),
            ("intended extra flag", journal(key: key, controls: [M720JournalCIDEntry(
                cid: entry.cid,
                original: original,
                intended: HIDPPReportingState(cid: entry.cid, flags: entry.intended.flags ^ 0x04, remappedCID: original.remappedCID),
                phase: .prepared
            )])),
            ("intended remap", journal(key: key, controls: [M720JournalCIDEntry(
                cid: entry.cid,
                original: original,
                intended: HIDPPReportingState(cid: entry.cid, flags: entry.intended.flags, remappedCID: original.remappedCID ^ 1),
                phase: .prepared
            )])),
            ("original equals intended", journal(key: key, controls: [M720JournalCIDEntry(
                cid: entry.cid,
                original: original,
                intended: original,
                phase: .prepared
            )])),
            ("duplicate device", M720OwnershipJournal(
                version: M720OwnershipJournal.currentVersion,
                devices: [
                    M720JournalDevice(key: key, controls: [entry]),
                    M720JournalDevice(key: key, controls: [fixtureEntry(cid: 0x005D, phase: .applied)]),
                ]
            )),
        ]

        for (name, invalid) in invalidJournals {
            XCTAssertThrowsError(try invalid.validatedCanonicalized(), name)
        }
    }

    func testSemanticValidationAcceptsPartialTargetsAndPreservesExactStrings() throws {
        let key = fixtureKey(transport: " Bluetooth Low Energy ", serialNumber: " serial-1 ")
        let input = journal(key: key, controls: [fixtureEntry(cid: 0x00D0, phase: .restoring)])

        let validated = try input.validatedCanonicalized()

        XCTAssertEqual(validated, input)
        XCTAssertEqual(validated.devices[0].key.transport, " Bluetooth Low Energy ")
        XCTAssertEqual(validated.devices[0].key.serialNumber, " serial-1 ")
    }

    func testCanonicalizationSortsOnlyDeviceAndControlArrays() throws {
        let highKey = fixtureKey(vendorID: 0x046E, serialNumber: "z")
        let lowKeyB = fixtureKey(serialNumber: "b")
        let lowKeyA = fixtureKey(serialNumber: "a")
        let input = M720OwnershipJournal(
            version: M720OwnershipJournal.currentVersion,
            devices: [
                M720JournalDevice(key: highKey, controls: [fixtureEntry(cid: 0x005B, phase: .applied)]),
                M720JournalDevice(key: lowKeyB, controls: [fixtureEntry(cid: 0x005D, phase: .prepared)]),
                M720JournalDevice(key: lowKeyA, controls: [
                    fixtureEntry(cid: 0x00D0, phase: .restoring),
                    fixtureEntry(cid: 0x005B, phase: .applied),
                    fixtureEntry(cid: 0x005D, phase: .prepared),
                ]),
            ]
        )

        let canonical = try input.validatedCanonicalized()

        XCTAssertEqual(canonical.devices.map(\.key), [lowKeyA, lowKeyB, highKey])
        XCTAssertEqual(canonical.devices[0].controls.map(\.cid), [0x005B, 0x005D, 0x00D0])
    }

    func testEmptyV1IsAValidJournal() throws {
        XCTAssertEqual(
            try M720OwnershipJournal.emptyV1.validatedCanonicalized(),
            M720OwnershipJournal(version: 1, devices: [])
        )
    }

    func testProductionURLUsesExistingApplicationSupportFolder() {
        XCTAssertEqual(
            M720OwnershipJournalStore.productionURL,
            Locator.mfApplicationSupportFolderURL()
                .appendingPathComponent("M720HIDPPOwnership-v1.plist", isDirectory: false)
        )
    }

    func testLoadOfAbsentStoreReturnsInMemoryEmptyWithoutCreatingAnything() throws {
        let (store, finalURL) = makeStore()

        XCTAssertEqual(try store.load(), .emptyV1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.deletingLastPathComponent().path))
    }

    func testLoadOfAbsentFinalWithMatchingCorruptSiblingIsStablyQuarantined() throws {
        let (store, finalURL) = makeStore(createParent: true)
        let corruptURL = finalURL.deletingLastPathComponent()
            .appendingPathComponent(finalURL.lastPathComponent + ".old.corrupt")
        try Data("old".utf8).write(to: corruptURL)

        for _ in 0..<2 {
            XCTAssertThrowsError(try store.load()) { error in
                XCTAssertEqual(error as? M720JournalStoreError, .quarantined)
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: corruptURL.path))
    }

    func testUnrelatedCorruptFileDoesNotCreateQuarantineGate() throws {
        let (store, finalURL) = makeStore(createParent: true)
        let unrelated = finalURL.deletingLastPathComponent().appendingPathComponent("other.plist.old.corrupt")
        try Data("old".utf8).write(to: unrelated)

        XCTAssertEqual(try store.load(), .emptyV1)
    }

    func testMalformedUnknownMissingSerialAndSemanticInvalidFilesMoveToUniqueCorruptSiblings() throws {
        let (store, finalURL) = makeStore(createParent: true)
        let valid = journal(key: fixtureKey(), controls: [fixtureEntry(phase: .prepared)])
        var missingSerial = try propertyListDictionary(for: valid)
        var devices = missingSerial["devices"] as! [[String: Any]]
        var key = devices[0]["key"] as! [String: Any]
        key.removeValue(forKey: "serialNumber")
        devices[0]["key"] = key
        missingSerial["devices"] = devices

        let invalidPayloads: [Data] = [
            Data("not a plist".utf8),
            try PropertyListSerialization.data(
                fromPropertyList: ["version": 99, "devices": []],
                format: .xml,
                options: 0
            ),
            try PropertyListSerialization.data(fromPropertyList: missingSerial, format: .xml, options: 0),
            try PropertyListEncoder().encode(journal(
                key: fixtureKey(serialNumber: ""),
                controls: [fixtureEntry(phase: .prepared)]
            )),
            try PropertyListEncoder().encode(M720OwnershipJournal(
                version: 1,
                devices: [
                    M720JournalDevice(key: fixtureKey(), controls: [fixtureEntry(phase: .prepared)]),
                    M720JournalDevice(key: fixtureKey(), controls: [fixtureEntry(cid: 0x005D, phase: .applied)]),
                ]
            )),
            try PropertyListEncoder().encode(journal(
                key: fixtureKey(),
                controls: [fixtureEntry(phase: .prepared), fixtureEntry(phase: .applied)]
            )),
        ]

        for (index, payload) in invalidPayloads.enumerated() {
            try payload.write(to: finalURL)
            XCTAssertThrowsError(try store.load(), "payload \(index)") { error in
                XCTAssertEqual(error as? M720JournalStoreError, .corruptFileQuarantined)
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))
            XCTAssertEqual(try corruptSiblings(for: finalURL).count, index + 1)
        }
    }

    func testValidFinalWinsOverHistoricalCorruptSibling() throws {
        let (store, finalURL) = makeStore(createParent: true)
        let expected = journal(key: fixtureKey(), controls: [fixtureEntry(phase: .applied)])
        try PropertyListEncoder().encode(expected).write(to: finalURL)
        let corruptURL = finalURL.deletingLastPathComponent()
            .appendingPathComponent(finalURL.lastPathComponent + ".history.corrupt")
        try Data("history".utf8).write(to: corruptURL)

        XCTAssertEqual(try store.load(), expected)
        XCTAssertTrue(FileManager.default.fileExists(atPath: corruptURL.path))
    }

    func testLoadCanonicalizesLegalUnsortedArraysWithoutRewritingFile() throws {
        let (store, finalURL) = makeStore(createParent: true)
        let input = M720OwnershipJournal(
            version: 1,
            devices: [
                M720JournalDevice(key: fixtureKey(serialNumber: "z"), controls: [fixtureEntry(cid: 0x005B, phase: .applied)]),
                M720JournalDevice(key: fixtureKey(serialNumber: "a"), controls: [
                    fixtureEntry(cid: 0x00D0, phase: .restoring),
                    fixtureEntry(cid: 0x005B, phase: .prepared),
                ]),
            ]
        )
        let originalBytes = try PropertyListEncoder().encode(input)
        try originalBytes.write(to: finalURL)

        let loaded = try store.load()

        XCTAssertEqual(loaded.devices.map(\.key.serialNumber), ["a", "z"])
        XCTAssertEqual(loaded.devices[0].controls.map(\.cid), [0x005B, 0x00D0])
        XCTAssertEqual(try Data(contentsOf: finalURL), originalBytes)
    }

    func testRealPOSIXAtomicSaveSupportsFirstWriteAndReplacementAtMode0600() throws {
        let (store, finalURL) = makeStore()
        let first = journal(key: fixtureKey(serialNumber: "first"), controls: [fixtureEntry(phase: .prepared)])
        let replacement = journal(key: fixtureKey(serialNumber: "second"), controls: [fixtureEntry(cid: 0x005D, phase: .applied)])

        try store.save(first)
        XCTAssertEqual(try store.load(), first)
        XCTAssertEqual(try permissions(of: finalURL), 0o600)

        try store.save(replacement)
        XCTAssertEqual(try store.load(), replacement)
        XCTAssertEqual(try permissions(of: finalURL), 0o600)
        XCTAssertTrue(try temporarySiblings(for: finalURL).isEmpty)
    }

    func testSaveValidatesBeforeRenameAndPreservesExistingValidFinal() throws {
        let (store, finalURL) = makeStore()
        let valid = journal(key: fixtureKey(), controls: [fixtureEntry(phase: .prepared)])
        try store.save(valid)
        let oldBytes = try Data(contentsOf: finalURL)
        let invalid = journal(key: fixtureKey(serialNumber: ""), controls: [fixtureEntry(phase: .applied)])

        XCTAssertThrowsError(try store.save(invalid)) { error in
            XCTAssertEqual(error as? M720JournalValidationError, .emptySerialNumber)
        }
        XCTAssertEqual(try Data(contentsOf: finalURL), oldBytes)
        XCTAssertEqual(try store.load(), valid)
        XCTAssertTrue(try temporarySiblings(for: finalURL).isEmpty)
    }

    func testOrdinarySaveCannotBypassQuarantinedAbsentStore() throws {
        let (store, finalURL) = makeStore(createParent: true)
        try Data("bad".utf8).write(to: finalURL)
        XCTAssertThrowsError(try store.load())
        let corruptBefore = try corruptSiblings(for: finalURL)

        XCTAssertThrowsError(try store.save(.emptyV1)) { error in
            XCTAssertEqual(error as? M720JournalStoreError, .quarantined)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))
        XCTAssertEqual(try corruptSiblings(for: finalURL), corruptBefore)
    }

    func testDedicatedAcknowledgementWritesFreshEmptyV1WithoutDeletingHistory() throws {
        let (store, finalURL) = makeStore(createParent: true)
        let corruptURL = finalURL.deletingLastPathComponent()
            .appendingPathComponent(finalURL.lastPathComponent + ".history.corrupt")
        try Data("history".utf8).write(to: corruptURL)

        XCTAssertEqual(try store.acknowledgeQuarantineWithFreshEmptyV1(), .emptyV1)
        XCTAssertEqual(try store.load(), .emptyV1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: corruptURL.path))
        XCTAssertEqual(try permissions(of: finalURL), 0o600)

        let populated = journal(key: fixtureKey(), controls: [fixtureEntry(phase: .applied)])
        try store.save(populated)
        XCTAssertEqual(try store.load(), populated)
        XCTAssertTrue(FileManager.default.fileExists(atPath: corruptURL.path))
    }

    func testFailedAcknowledgementLeavesHistoryAndCleansTemporarySibling() throws {
        let (_, finalURL) = makeStore(createParent: true)
        let corruptURL = finalURL.deletingLastPathComponent()
            .appendingPathComponent(finalURL.lastPathComponent + ".history.corrupt")
        try Data("history".utf8).write(to: corruptURL)
        let store = M720OwnershipJournalStore(url: finalURL, faults: .init(renameError: .EIO))

        XCTAssertThrowsError(try store.acknowledgeQuarantineWithFreshEmptyV1())
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: corruptURL.path))
        XCTAssertTrue(try temporarySiblings(for: finalURL).isEmpty)
    }

    func testAcknowledgementRequiresQuarantinedAbsentState() {
        let (store, _) = makeStore()

        XCTAssertThrowsError(try store.acknowledgeQuarantineWithFreshEmptyV1()) { error in
            XCTAssertEqual(error as? M720JournalStoreError, .notQuarantined)
        }
    }

    func testRenameFailurePreservesOldFinalAndCleansTemporarySibling() throws {
        let (healthyStore, finalURL) = makeStore()
        let old = journal(key: fixtureKey(serialNumber: "old"), controls: [fixtureEntry(phase: .prepared)])
        try healthyStore.save(old)
        let oldBytes = try Data(contentsOf: finalURL)
        let failingStore = M720OwnershipJournalStore(
            url: finalURL,
            faults: .init(renameError: .EIO)
        )

        XCTAssertThrowsError(try failingStore.save(journal(
            key: fixtureKey(serialNumber: "new"),
            controls: [fixtureEntry(phase: .applied)]
        ))) { error in
            XCTAssertEqual((error as? POSIXError)?.code, .EIO)
        }
        XCTAssertEqual(try Data(contentsOf: finalURL), oldBytes)
        XCTAssertTrue(try temporarySiblings(for: finalURL).isEmpty)
    }

    func testDirectorySyncFailureAfterRenameReportsUncertainAndLeavesReloadableFinal() throws {
        let (healthyStore, finalURL) = makeStore()
        let old = journal(key: fixtureKey(serialNumber: "old"), controls: [fixtureEntry(phase: .prepared)])
        let replacement = journal(key: fixtureKey(serialNumber: "new"), controls: [fixtureEntry(phase: .applied)])
        try healthyStore.save(old)
        let failingStore = M720OwnershipJournalStore(
            url: finalURL,
            faults: .init(directorySyncError: .EIO)
        )

        XCTAssertThrowsError(try failingStore.save(replacement)) { error in
            XCTAssertEqual(error as? M720JournalStoreError, .uncertain)
        }
        XCTAssertEqual(try healthyStore.load(), replacement)
        XCTAssertTrue(try temporarySiblings(for: finalURL).isEmpty)
    }

    func testQuarantineDirectorySyncFailureIsUncertainAndRemainsFailClosed() throws {
        let (healthyStore, finalURL) = makeStore(createParent: true)
        try Data("bad".utf8).write(to: finalURL)
        let failingStore = M720OwnershipJournalStore(
            url: finalURL,
            faults: .init(directorySyncError: .EIO)
        )

        XCTAssertThrowsError(try failingStore.load()) { error in
            XCTAssertEqual(error as? M720JournalStoreError, .uncertain)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))
        XCTAssertEqual(try corruptSiblings(for: finalURL).count, 1)
        XCTAssertThrowsError(try healthyStore.load()) { error in
            XCTAssertEqual(error as? M720JournalStoreError, .quarantined)
        }
    }

    func testQuarantineRenameFailureLeavesInvalidFinalAndFailsClosed() throws {
        let (_, finalURL) = makeStore(createParent: true)
        try Data("bad".utf8).write(to: finalURL)
        let failingStore = M720OwnershipJournalStore(
            url: finalURL,
            faults: .init(renameError: .EIO)
        )

        XCTAssertThrowsError(try failingStore.load()) { error in
            XCTAssertEqual((error as? POSIXError)?.code, .EIO)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path))
        XCTAssertTrue(try corruptSiblings(for: finalURL).isEmpty)
    }

    func testOrdinaryDirectoryEnumerationFailureCannotOpenQuarantineGate() throws {
        let (_, finalURL) = makeStore(createParent: true)
        let parent = finalURL.deletingLastPathComponent()
        XCTAssertEqual(chmod(parent.path, 0o300), 0)
        defer { _ = chmod(parent.path, 0o700) }
        let store = M720OwnershipJournalStore(url: finalURL)

        XCTAssertThrowsError(try store.save(.emptyV1))
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))
    }

    func testOrdinaryReadIOFailureIsNotQuarantined() throws {
        let (store, finalURL) = makeStore(createParent: true)
        try FileManager.default.createDirectory(at: finalURL, withIntermediateDirectories: false)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertNil(error as? M720JournalStoreError)
        }
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertTrue(try corruptSiblings(for: finalURL).isEmpty)
    }

    func testFinalStatAccessFailureIsPropagatedInsteadOfTreatedAsAbsent() throws {
        let (store, finalURL) = makeStore(createParent: true)
        let parent = finalURL.deletingLastPathComponent()
        XCTAssertEqual(chmod(parent.path, 0o000), 0)
        defer { _ = chmod(parent.path, 0o700) }

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual((error as? POSIXError)?.code, .EACCES)
        }
    }

    func testWritesCanonicalPlistFixtureForPlutil() throws {
        let directory = URL(fileURLWithPath: "/tmp/mmf-m720-journal-test", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        let finalURL = directory.appendingPathComponent("M720HIDPPOwnership-v1.plist")
        let store = M720OwnershipJournalStore(url: finalURL)
        let input = M720OwnershipJournal(
            version: 1,
            devices: [M720JournalDevice(key: fixtureKey(), controls: [
                fixtureEntry(cid: 0x00D0, phase: .restoring),
                fixtureEntry(cid: 0x005B, phase: .prepared),
            ])]
        )

        try store.save(input)

        let disk = try PropertyListDecoder().decode(
            M720OwnershipJournal.self,
            from: Data(contentsOf: finalURL)
        )
        XCTAssertEqual(disk.devices[0].controls.map(\.cid), [0x005B, 0x00D0])
        XCTAssertEqual(try permissions(of: finalURL), 0o600)
    }

    func testRepositoryLoadsMutatesSeriallyAndPreservesOtherDevicesAndCIDs() throws {
        let keyA = fixtureKey(serialNumber: "a")
        let keyB = fixtureKey(serialNumber: "b")
        let originalA = fixtureEntry(cid: 0x005B, phase: .prepared)
        let untouchedA = fixtureEntry(cid: 0x00D0, phase: .applied)
        let store = FakeM720JournalStore(durable: M720OwnershipJournal(
            version: 1,
            devices: [M720JournalDevice(key: keyA, controls: [originalA, untouchedA])]
        ))
        let repository = M720OwnershipJournalRepository(store: store)
        _ = try awaitRepositoryResult { repository.reload(completion: $0) }.get()

        let firstDone = expectation(description: "first mutation")
        let secondDone = expectation(description: "second mutation")
        var firstResult: Result<M720OwnershipJournal, Error>?
        var secondResult: Result<M720OwnershipJournal, Error>?
        repository.mutateCID(for: keyA, cid: 0x005B, mutation: { existing in
            var updated = try XCTUnwrap(existing)
            updated.phase = .applied
            return updated
        }) {
            firstResult = $0
            firstDone.fulfill()
        }
        repository.mutateCID(for: keyB, cid: 0x005D, mutation: { _ in
            self.fixtureEntry(cid: 0x005D, phase: .prepared)
        }) {
            secondResult = $0
            secondDone.fulfill()
        }
        wait(for: [firstDone, secondDone], timeout: 3)

        XCTAssertNoThrow(try XCTUnwrap(firstResult).get())
        let final = try XCTUnwrap(secondResult).get()
        XCTAssertEqual(store.savedSnapshots.count, 2)
        XCTAssertEqual(final.devices.map(\.key), [keyA, keyB])
        XCTAssertEqual(final.devices[0].controls.map(\.cid), [0x005B, 0x00D0])
        XCTAssertEqual(final.devices[0].controls.first(where: { $0.cid == 0x005B })?.phase, .applied)
        XCTAssertEqual(final.devices[0].controls.first(where: { $0.cid == 0x00D0 }), untouchedA)
        XCTAssertEqual(store.durable, final)
    }

    func testRepositoryDoesAllStoreWorkAndCallbacksOffMainThread() throws {
        let store = FakeM720JournalStore(durable: .emptyV1)
        let repository = M720OwnershipJournalRepository(store: store)
        let callback = expectation(description: "callback")

        repository.reload { result in
            if case let .failure(error) = result {
                XCTFail("unexpected reload error: \(error)")
            }
            XCTAssertFalse(Thread.isMainThread)
            callback.fulfill()
        }
        wait(for: [callback], timeout: 3)

        XCTAssertEqual(store.operationWasMainThread, [false])
    }

    func testRepositoryFailedSaveDoesNotPublishMemoryAheadOfDurableSnapshot() throws {
        let key = fixtureKey()
        let original = journal(key: key, controls: [fixtureEntry(phase: .prepared)])
        let store = FakeM720JournalStore(durable: original)
        let repository = M720OwnershipJournalRepository(store: store)
        _ = try awaitRepositoryResult { repository.reload(completion: $0) }.get()
        store.failSaveNumbers = [1]

        let failed = awaitRepositoryResult { completion in
            repository.mutateCID(for: key, cid: 0x005B, mutation: { existing in
                var updated = try XCTUnwrap(existing)
                updated.phase = .applied
                return updated
            }, completion: completion)
        }

        XCTAssertThrowsError(try failed.get())
        XCTAssertEqual(try awaitRepositoryResult { repository.snapshot(completion: $0) }.get(), original)
        XCTAssertEqual(store.durable, original)
        XCTAssertTrue(store.savedSnapshots.isEmpty)
    }

    func testRepositoryProductionUncertainSaveAutomaticallyReloadsPersistedSnapshot() throws {
        let (healthyStore, finalURL) = makeStore()
        let key = fixtureKey()
        let initial = journal(key: key, controls: [fixtureEntry(phase: .prepared)])
        try healthyStore.save(initial)
        let uncertainStore = M720OwnershipJournalStore(
            url: finalURL,
            faults: .init(directorySyncError: .EIO)
        )
        let repository = M720OwnershipJournalRepository(store: uncertainStore)
        _ = try awaitRepositoryResult { repository.reload(completion: $0) }.get()

        let uncertain = awaitRepositoryResult { completion in
            repository.mutateCID(for: key, cid: 0x005B, mutation: { existing in
                var updated = try XCTUnwrap(existing)
                updated.phase = .applied
                return updated
            }, completion: completion)
        }
        XCTAssertThrowsError(try uncertain.get()) { error in
            XCTAssertEqual(error as? M720JournalStoreError, .uncertain)
        }

        let durableAfterUncertain = try healthyStore.load()
        XCTAssertEqual(durableAfterUncertain.devices[0].controls[0].phase, .applied)
        XCTAssertEqual(
            try awaitRepositoryResult { repository.snapshot(completion: $0) }.get(),
            durableAfterUncertain
        )
    }

    func testRepositoryReloadsPersistedUncertainSaveBeforeAnotherDeviceMutation() throws {
        let (diskStore, _) = makeStore()
        let keyA = fixtureKey(serialNumber: "uncertain-originator")
        let keyB = fixtureKey(serialNumber: "other-device")
        let initial = journal(key: keyA, controls: [fixtureEntry(phase: .prepared)])
        try diskStore.save(initial)
        let store = PersistThenThrowUncertainOnceM720JournalStore(delegate: diskStore)
        let repository = M720OwnershipJournalRepository(store: store)
        _ = try awaitRepositoryResult { repository.reload(completion: $0) }.get()

        let uncertain = awaitRepositoryResult { completion in
            repository.mutateCID(for: keyA, cid: 0x005B, mutation: { existing in
                var updated = try XCTUnwrap(existing)
                updated.phase = .applied
                return updated
            }, completion: completion)
        }
        XCTAssertThrowsError(try uncertain.get()) { error in
            XCTAssertEqual(error as? M720JournalStoreError, .uncertain)
        }

        let final = try awaitRepositoryResult { completion in
            repository.mutateCID(for: keyB, cid: 0x005D, mutation: { _ in
                self.fixtureEntry(cid: 0x005D, phase: .prepared)
            }, completion: completion)
        }.get()
        XCTAssertEqual(Set(final.devices.map(\.key)), Set([keyA, keyB]))
        XCTAssertEqual(
            final.devices.first(where: { $0.key == keyA })?.controls[0].phase,
            .applied
        )
        XCTAssertEqual(final, try diskStore.load())
    }

    func testRepositoryAutomaticReloadFailureRemainsRetryable() throws {
        let initial = journal(
            key: fixtureKey(serialNumber: "reload-retry"),
            controls: [fixtureEntry(phase: .applied)]
        )
        let store = FakeM720JournalStore(durable: initial)
        let repository = M720OwnershipJournalRepository(store: store)
        _ = try awaitRepositoryResult { repository.reload(completion: $0) }.get()
        store.acknowledgementError = M720JournalStoreError.uncertain
        XCTAssertThrowsError(
            try awaitRepositoryResult {
                repository.acknowledgeQuarantineWithFreshEmptyV1(completion: $0)
            }.get()
        )

        store.loadError = FakeM720JournalStore.Failure.load
        XCTAssertThrowsError(
            try awaitRepositoryResult { repository.snapshot(completion: $0) }.get()
        ) { error in
            guard let failure = error as? FakeM720JournalStore.Failure,
                  case .load = failure else {
                return XCTFail("expected automatic load failure, got \(error)")
            }
        }

        store.loadError = nil
        XCTAssertEqual(
            try awaitRepositoryResult { repository.snapshot(completion: $0) }.get(),
            initial
        )
    }

    func testRepositoryNeverLoadedMutationRemainsNotLoaded() {
        let key = fixtureKey(serialNumber: "never-loaded")
        let store = FakeM720JournalStore(durable: journal(
            key: key,
            controls: [fixtureEntry(phase: .applied)]
        ))
        let repository = M720OwnershipJournalRepository(store: store)

        XCTAssertRepositoryNotLoaded(awaitRepositoryResult { completion in
            repository.mutateCID(for: key, cid: 0x005B, mutation: { $0 }, completion: completion)
        })
    }

    func testRepositoryFailedReloadInvalidatesPreviouslyLoadedSnapshot() throws {
        let key = fixtureKey()
        let initial = journal(key: key, controls: [fixtureEntry(phase: .prepared)])
        let store = FakeM720JournalStore(durable: initial)
        let repository = M720OwnershipJournalRepository(store: store)
        _ = try awaitRepositoryResult { repository.reload(completion: $0) }.get()
        store.loadError = FakeM720JournalStore.Failure.load

        XCTAssertThrowsError(try awaitRepositoryResult { repository.reload(completion: $0) }.get())
        XCTAssertRepositoryNotLoaded(awaitRepositoryResult { repository.snapshot(completion: $0) })
        XCTAssertRepositoryNotLoaded(awaitRepositoryResult { completion in
            repository.mutateCID(for: key, cid: 0x005B, mutation: { $0 }, completion: completion)
        })
        XCTAssertEqual(store.durable, initial)
    }

    func testRepositoryRemovingLastEntrySavesAndPublishesLegalEmptyFinal() throws {
        let key = fixtureKey()
        let initial = journal(key: key, controls: [fixtureEntry(phase: .applied)])
        let store = FakeM720JournalStore(durable: initial)
        let repository = M720OwnershipJournalRepository(store: store)
        _ = try awaitRepositoryResult { repository.reload(completion: $0) }.get()

        let result = try awaitRepositoryResult { completion in
            repository.mutateCID(for: key, cid: 0x005B, mutation: { _ in nil }, completion: completion)
        }.get()

        XCTAssertEqual(result, .emptyV1)
        XCTAssertEqual(store.durable, .emptyV1)
        XCTAssertEqual(store.savedSnapshots, [.emptyV1])
    }

    func testRepositoryRejectsMutationResultForAnotherCIDBeforeSave() throws {
        let key = fixtureKey()
        let store = FakeM720JournalStore(durable: .emptyV1)
        let repository = M720OwnershipJournalRepository(store: store)
        _ = try awaitRepositoryResult { repository.reload(completion: $0) }.get()

        let result = awaitRepositoryResult { completion in
            repository.mutateCID(for: key, cid: 0x005B, mutation: { _ in
                self.fixtureEntry(cid: 0x005D, phase: .prepared)
            }, completion: completion)
        }

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? M720JournalRepositoryError, .mismatchedCID)
        }
        XCTAssertEqual(store.durable, .emptyV1)
        XCTAssertTrue(store.savedSnapshots.isEmpty)
    }

    func testRepositoryAcknowledgementPublishesOnlyAfterDurableSuccess() throws {
        let key = fixtureKey()
        let initial = journal(key: key, controls: [fixtureEntry(phase: .applied)])
        let store = FakeM720JournalStore(durable: initial)
        let repository = M720OwnershipJournalRepository(store: store)
        _ = try awaitRepositoryResult { repository.reload(completion: $0) }.get()
        store.acknowledgementError = FakeM720JournalStore.Failure.acknowledgement

        let failed = awaitRepositoryResult { repository.acknowledgeQuarantineWithFreshEmptyV1(completion: $0) }
        XCTAssertThrowsError(try failed.get())
        XCTAssertEqual(try awaitRepositoryResult { repository.snapshot(completion: $0) }.get(), initial)

        store.acknowledgementError = nil
        XCTAssertEqual(
            try awaitRepositoryResult { repository.acknowledgeQuarantineWithFreshEmptyV1(completion: $0) }.get(),
            .emptyV1
        )
        XCTAssertEqual(try awaitRepositoryResult { repository.snapshot(completion: $0) }.get(), .emptyV1)
    }

    func testRepositoryUncertainAcknowledgementAutomaticallyReloadsDurableEmptySnapshot() throws {
        let (healthyStore, finalURL) = makeStore(createParent: true)
        try Data("bad".utf8).write(to: finalURL)
        XCTAssertThrowsError(try healthyStore.load()) { error in
            XCTAssertEqual(error as? M720JournalStoreError, .corruptFileQuarantined)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalURL.path))
        XCTAssertEqual(try corruptSiblings(for: finalURL).count, 1)

        let uncertainStore = M720OwnershipJournalStore(
            url: finalURL,
            faults: .init(directorySyncError: .EIO)
        )
        let repository = M720OwnershipJournalRepository(store: uncertainStore)
        XCTAssertThrowsError(
            try awaitRepositoryResult { repository.reload(completion: $0) }.get()
        ) { error in
            XCTAssertEqual(error as? M720JournalStoreError, .quarantined)
        }

        XCTAssertThrowsError(
            try awaitRepositoryResult {
                repository.acknowledgeQuarantineWithFreshEmptyV1(completion: $0)
            }.get()
        ) { error in
            XCTAssertEqual(error as? M720JournalStoreError, .uncertain)
        }
        XCTAssertEqual(
            try awaitRepositoryResult { repository.snapshot(completion: $0) }.get(),
            .emptyV1
        )
        XCTAssertEqual(try healthyStore.load(), .emptyV1)
    }

    func testTwoCIDCrashBoundariesPreserveLastDurableSnapshotAndRecoveryDecision() throws {
        let boundaries = crashWriteBoundaries()
        XCTAssertEqual(
            boundaries.map(\.name),
            [
                "prepared CID 1",
                "applied CID 1",
                "prepared CID 2",
                "applied CID 2",
                "restoring CID 1",
                "remove CID 1",
                "restoring CID 2",
                "remove CID 2",
            ]
        )

        for (operationIndex, boundary) in boundaries.enumerated() {
            let beforeStore = FakeM720JournalStore(durable: .emptyV1)
            beforeStore.failSaveNumbers = [operationIndex + 1]
            let beforeRepository = M720OwnershipJournalRepository(store: beforeStore)
            _ = try awaitRepositoryResult { beforeRepository.reload(completion: $0) }.get()
            let beforeResults = performCrashScript(
                repository: beforeRepository,
                boundaries: boundaries,
                stoppingAfter: nil
            )
            XCTAssertThrowsError(try beforeResults[operationIndex].get(), "before operation \(operationIndex)")
            assertCrashSnapshot(
                beforeStore.durable,
                expectedEntries: boundary.durableBefore,
                boundary: boundary,
                context: "immediately before \(boundary.name)"
            )
            XCTAssertEqual(
                try awaitRepositoryResult { beforeRepository.snapshot(completion: $0) }.get(),
                beforeStore.durable,
                "failed repository memory must not lead durable state before \(boundary.name)"
            )

            let afterStore = FakeM720JournalStore(durable: .emptyV1)
            let afterRepository = M720OwnershipJournalRepository(store: afterStore)
            _ = try awaitRepositoryResult { afterRepository.reload(completion: $0) }.get()
            let afterResults = performCrashScript(
                repository: afterRepository,
                boundaries: boundaries,
                stoppingAfter: operationIndex
            )
            XCTAssertNoThrow(try afterResults[operationIndex].get(), "after operation \(operationIndex)")
            assertCrashSnapshot(
                afterStore.durable,
                expectedEntries: boundary.durableAfter,
                boundary: boundary,
                context: "immediately after \(boundary.name)"
            )
            XCTAssertEqual(
                try awaitRepositoryResult { afterRepository.snapshot(completion: $0) }.get(),
                afterStore.durable,
                "repository memory after \(boundary.name)"
            )
        }
    }

    private struct CrashEntryExpectation {
        let cid: UInt16
        let phase: M720JournalPhase
        let decision: M720RecoveryDecision
    }

    private struct CrashWriteBoundary {
        let name: String
        let cid: UInt16
        let phase: M720JournalPhase?
        let currentStatesAtWrite: [UInt16: HIDPPReportingState]
        let policyRequiresCaptureByCID: [UInt16: Bool]
        let durableBefore: [CrashEntryExpectation]
        let durableAfter: [CrashEntryExpectation]
    }

    private func fixtureKey(
        vendorID: Int = 0x046D,
        productID: Int = 0xB015,
        transport: String = "Bluetooth Low Energy",
        serialNumber: String = "serial-1"
    ) -> M720DeviceKey {
        M720DeviceKey(
            vendorID: vendorID,
            productID: productID,
            transport: transport,
            serialNumber: serialNumber
        )
    }

    private func journal(
        version: Int = M720OwnershipJournal.currentVersion,
        key: M720DeviceKey,
        controls: [M720JournalCIDEntry]
    ) -> M720OwnershipJournal {
        M720OwnershipJournal(
            version: version,
            devices: [M720JournalDevice(key: key, controls: controls)]
        )
    }

    private func makeStore(
        createParent: Bool = false
    ) -> (M720OwnershipJournalStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("M720OwnershipJournalTests-\(UUID().uuidString)", isDirectory: true)
        temporaryDirectories.append(root)
        let parent = root.appendingPathComponent("Application Support/com.nuebling.mac-mouse-fix", isDirectory: true)
        if createParent {
            try! FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        let finalURL = parent.appendingPathComponent("M720HIDPPOwnership-v1.plist")
        return (M720OwnershipJournalStore(url: finalURL), finalURL)
    }

    private func propertyListDictionary(for journal: M720OwnershipJournal) throws -> [String: Any] {
        let data = try PropertyListEncoder().encode(journal)
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )
    }

    private func corruptSiblings(for finalURL: URL) throws -> [String] {
        let names = try FileManager.default.contentsOfDirectory(atPath: finalURL.deletingLastPathComponent().path)
        return names.filter {
            $0.hasPrefix(finalURL.lastPathComponent + ".") && $0.hasSuffix(".corrupt")
        }.sorted()
    }

    private func temporarySiblings(for finalURL: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: finalURL.deletingLastPathComponent().path)
            .filter { $0.hasPrefix("." + finalURL.lastPathComponent + ".tmp.") }
    }

    private func permissions(of url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap((attributes[.posixPermissions] as? NSNumber)?.intValue)
    }

    private func awaitRepositoryResult(
        _ operation: (@escaping M720OwnershipJournalRepository.Completion) -> Void
    ) -> Result<M720OwnershipJournal, Error> {
        let completed = expectation(description: "repository completion")
        var result: Result<M720OwnershipJournal, Error>?
        operation {
            result = $0
            completed.fulfill()
        }
        wait(for: [completed], timeout: 3)
        return result ?? .failure(FakeM720JournalStore.Failure.missingCompletion)
    }

    private func XCTAssertRepositoryNotLoaded(
        _ result: Result<M720OwnershipJournal, Error>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try result.get(), file: file, line: line) { error in
            XCTAssertEqual(
                error as? M720JournalRepositoryError,
                .notLoaded,
                file: file,
                line: line
            )
        }
    }

    private func performCrashScript(
        repository: M720OwnershipJournalRepository,
        boundaries: [CrashWriteBoundary],
        stoppingAfter finalOperationIndex: Int?
    ) -> [Result<M720OwnershipJournal, Error>] {
        let key = fixtureKey(serialNumber: "crash-device")
        var results: [Result<M720OwnershipJournal, Error>] = []
        for (index, boundary) in boundaries.enumerated() {
            let result = awaitRepositoryResult { completion in
                repository.mutateCID(for: key, cid: boundary.cid, mutation: { existing in
                    guard let phase = boundary.phase else { return nil }
                    if phase == .prepared {
                        return self.fixtureEntry(cid: boundary.cid, phase: phase)
                    }
                    var updated = try XCTUnwrap(existing)
                    updated.phase = phase
                    return updated
                }, completion: completion)
            }
            results.append(result)
            if case .failure = result { break }
            if finalOperationIndex == index { break }
        }
        return results
    }

    private func assertCrashSnapshot(
        _ actual: M720OwnershipJournal,
        expectedEntries: [CrashEntryExpectation],
        boundary: CrashWriteBoundary,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let key = fixtureKey(serialNumber: "crash-device")
        let expected: M720OwnershipJournal
        if expectedEntries.isEmpty {
            expected = .emptyV1
        } else {
            expected = journal(
                key: key,
                controls: expectedEntries.map { fixtureEntry(cid: $0.cid, phase: $0.phase) }
            )
        }
        XCTAssertEqual(actual, expected, context, file: file, line: line)

        XCTAssertEqual(boundary.currentStatesAtWrite.count, 2, context, file: file, line: line)
        XCTAssertEqual(boundary.policyRequiresCaptureByCID.count, 2, context, file: file, line: line)
        for expectation in expectedEntries {
            let entry = fixtureEntry(cid: expectation.cid, phase: expectation.phase)
            guard
                let current = boundary.currentStatesAtWrite[expectation.cid],
                let policyRequiresCapture = boundary.policyRequiresCaptureByCID[expectation.cid]
            else {
                XCTFail("missing per-CID boundary state for \(expectation.cid): \(context)", file: file, line: line)
                continue
            }
            XCTAssertEqual(
                M720OwnershipRecovery.decide(
                    entry: entry,
                    current: current,
                    policyRequiresCapture: policyRequiresCapture
                ),
                expectation.decision,
                context,
                file: file,
                line: line
            )
        }
    }

    private func crashWriteBoundaries() -> [CrashWriteBoundary] {
        let cid1: UInt16 = 0x005B
        let cid2: UInt16 = 0x005D
        let entry1 = fixtureEntry(cid: cid1, phase: .prepared)
        let entry2 = fixtureEntry(cid: cid2, phase: .prepared)
        let capturePolicy = [cid1: true, cid2: true]
        let restorePolicy = [cid1: false, cid2: false]

        func expected(
            _ cid: UInt16,
            _ phase: M720JournalPhase,
            _ decision: M720RecoveryDecision
        ) -> CrashEntryExpectation {
            CrashEntryExpectation(cid: cid, phase: phase, decision: decision)
        }

        return [
            CrashWriteBoundary(
                name: "prepared CID 1",
                cid: cid1,
                phase: .prepared,
                currentStatesAtWrite: [cid1: entry1.original, cid2: entry2.original],
                policyRequiresCaptureByCID: capturePolicy,
                durableBefore: [],
                durableAfter: [expected(cid1, .prepared, .clearThenReconcile)]
            ),
            CrashWriteBoundary(
                name: "applied CID 1",
                cid: cid1,
                phase: .applied,
                currentStatesAtWrite: [cid1: entry1.intended, cid2: entry2.original],
                policyRequiresCaptureByCID: capturePolicy,
                durableBefore: [expected(cid1, .prepared, .setAppliedThenKeep)],
                durableAfter: [expected(cid1, .applied, .keepApplied)]
            ),
            CrashWriteBoundary(
                name: "prepared CID 2",
                cid: cid2,
                phase: .prepared,
                currentStatesAtWrite: [cid1: entry1.intended, cid2: entry2.original],
                policyRequiresCaptureByCID: capturePolicy,
                durableBefore: [expected(cid1, .applied, .keepApplied)],
                durableAfter: [
                    expected(cid1, .applied, .keepApplied),
                    expected(cid2, .prepared, .clearThenReconcile),
                ]
            ),
            CrashWriteBoundary(
                name: "applied CID 2",
                cid: cid2,
                phase: .applied,
                currentStatesAtWrite: [cid1: entry1.intended, cid2: entry2.intended],
                policyRequiresCaptureByCID: capturePolicy,
                durableBefore: [
                    expected(cid1, .applied, .keepApplied),
                    expected(cid2, .prepared, .setAppliedThenKeep),
                ],
                durableAfter: [
                    expected(cid1, .applied, .keepApplied),
                    expected(cid2, .applied, .keepApplied),
                ]
            ),
            CrashWriteBoundary(
                name: "restoring CID 1",
                cid: cid1,
                phase: .restoring,
                currentStatesAtWrite: [cid1: entry1.intended, cid2: entry2.intended],
                policyRequiresCaptureByCID: restorePolicy,
                durableBefore: [
                    expected(cid1, .applied, .restore),
                    expected(cid2, .applied, .restore),
                ],
                durableAfter: [
                    expected(cid1, .restoring, .restore),
                    expected(cid2, .applied, .restore),
                ]
            ),
            CrashWriteBoundary(
                name: "remove CID 1",
                cid: cid1,
                phase: nil,
                currentStatesAtWrite: [cid1: entry1.original, cid2: entry2.intended],
                policyRequiresCaptureByCID: restorePolicy,
                durableBefore: [
                    expected(cid1, .restoring, .clearThenReconcile),
                    expected(cid2, .applied, .restore),
                ],
                durableAfter: [expected(cid2, .applied, .restore)]
            ),
            CrashWriteBoundary(
                name: "restoring CID 2",
                cid: cid2,
                phase: .restoring,
                currentStatesAtWrite: [cid1: entry1.original, cid2: entry2.intended],
                policyRequiresCaptureByCID: restorePolicy,
                durableBefore: [expected(cid2, .applied, .restore)],
                durableAfter: [expected(cid2, .restoring, .restore)]
            ),
            CrashWriteBoundary(
                name: "remove CID 2",
                cid: cid2,
                phase: nil,
                currentStatesAtWrite: [cid1: entry1.original, cid2: entry2.original],
                policyRequiresCaptureByCID: restorePolicy,
                durableBefore: [expected(cid2, .restoring, .clearThenReconcile)],
                durableAfter: []
            ),
        ]
    }

    private func fixtureEntry(
        cid: UInt16 = 0x005B,
        phase: M720JournalPhase
    ) -> M720JournalCIDEntry {
        let original = HIDPPReportingState(cid: cid, flags: 0x14, remappedCID: 0x4321)
        return M720JournalCIDEntry(
            cid: cid,
            original: original,
            intended: original.changingDivert(to: true),
            phase: phase
        )
    }
}

private final class PersistThenThrowUncertainOnceM720JournalStore: M720JournalStoring {
    private let delegate: M720JournalStoring
    private var shouldThrowAfterSave = true

    init(delegate: M720JournalStoring) {
        self.delegate = delegate
    }

    func load() throws -> M720OwnershipJournal {
        try delegate.load()
    }

    func save(_ journal: M720OwnershipJournal) throws {
        try delegate.save(journal)
        if shouldThrowAfterSave {
            shouldThrowAfterSave = false
            throw M720JournalStoreError.uncertain
        }
    }

    func acknowledgeQuarantineWithFreshEmptyV1() throws -> M720OwnershipJournal {
        try delegate.acknowledgeQuarantineWithFreshEmptyV1()
    }
}

private final class FakeM720JournalStore: M720JournalStoring {
    enum Failure: Error {
        case load
        case save(Int)
        case acknowledgement
        case missingCompletion
    }

    var durable: M720OwnershipJournal
    var savedSnapshots: [M720OwnershipJournal] = []
    var failSaveNumbers: Set<Int> = []
    var loadError: Error?
    var acknowledgementError: Error?
    var operationWasMainThread: [Bool] = []
    private var saveCallCount = 0

    init(durable: M720OwnershipJournal) {
        self.durable = durable
    }

    func load() throws -> M720OwnershipJournal {
        operationWasMainThread.append(Thread.isMainThread)
        if let loadError {
            throw loadError
        }
        return durable
    }

    func save(_ journal: M720OwnershipJournal) throws {
        operationWasMainThread.append(Thread.isMainThread)
        saveCallCount += 1
        if failSaveNumbers.contains(saveCallCount) {
            throw Failure.save(saveCallCount)
        }
        durable = journal
        savedSnapshots.append(journal)
    }

    func acknowledgeQuarantineWithFreshEmptyV1() throws -> M720OwnershipJournal {
        operationWasMainThread.append(Thread.isMainThread)
        if let acknowledgementError {
            throw acknowledgementError
        }
        durable = .emptyV1
        return .emptyV1
    }
}
