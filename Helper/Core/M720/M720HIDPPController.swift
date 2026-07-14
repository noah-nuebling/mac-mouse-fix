import AppKit
import Foundation
import IOKit.hid

struct M720DeviceSnapshot: Equatable {
    let registryEntryID: UInt64
    let vendorID: Int
    let productID: Int
    let transport: String
    let serialNumber: String?
    let physicalDeviceUniqueID: String?

    fileprivate var journalKey: M720DeviceKey? {
        guard let serialNumber, !serialNumber.isEmpty else { return nil }
        return M720DeviceKey(
            vendorID: vendorID,
            productID: productID,
            transport: transport,
            serialNumber: serialNumber
        )
    }
}

struct M720ControllerSessionSnapshot: Equatable {
    let deviceToken: UUID
    let state: M720SessionState
    let errorCode: M720StableErrorCode?
    let requiredCIDs: Set<UInt16>
    let requestID: UUID?

    init(
        deviceToken: UUID,
        state: M720SessionState,
        errorCode: M720StableErrorCode?,
        requiredCIDs: Set<UInt16>,
        requestID: UUID? = nil
    ) {
        self.deviceToken = deviceToken
        self.state = state
        self.errorCode = errorCode
        self.requiredCIDs = requiredCIDs
        self.requestID = requestID
    }
}

struct M720PreparationParticipant: Equatable {
    let deviceToken: UUID
    let exactRequiredCIDs: Set<UInt16>
}

struct M720PreparationSnapshot: Equatable {
    let deviceSetRevision: UInt64
    let environmentEnabled: Bool
    let participants: [M720PreparationParticipant]
}

enum M720TemporaryPolicyResult: Equatable {
    case ready
    case failed(M720StableErrorCode)
}

enum M720PreparationContextChange: Equatable {
    case deviceSetChanged(revision: UInt64)
    case environmentChanged(enabled: Bool)

    var isDeviceSetChange: Bool {
        if case .deviceSetChanged = self { return true }
        return false
    }
}

protocol M720SessionControlling: AnyObject {
    var state: M720SessionState { get }
    var requiredCIDs: Set<UInt16> { get }
    var onStateChange: ((M720SessionState) -> Void)? { get set }

    func start()
    func setRequiredCIDs(_ cids: Set<UInt16>)
    func markJournalIdentityUnusable()
    func prepareForSleep(completion: @escaping () -> Void)
    func reconcileAfterWake()
    func knownOwnershipAgentDidLaunch()
    func shutdown(completion: @escaping () -> Void)
    func shutdownDeadlineReached()
    func invalidateForRemoval(completion: @escaping () -> Void)
    @discardableResult
    func retryAfterConflict(requestID: UUID?) -> Bool
}

extension M720HIDPPSession: M720SessionControlling {}

final class M720HIDPPController: NSObject {
    typealias IdentityProvider = (Device) -> M720DeviceSnapshot?
    typealias SessionFactory = (
        Device,
        M720DeviceSnapshot,
        Bool
    ) -> M720SessionControlling?
    typealias StartExecutor = (@escaping () -> Void) -> Void
    typealias StableStateObserver = (M720ControllerSessionSnapshot) -> Void

    private final class Entry {
        let registryEntryID: UInt64
        let device: Device
        let snapshot: M720DeviceSnapshot
        let token: UUID
        let session: M720SessionControlling
        var journalIdentityUsable: Bool
        var requiredCIDs: Set<UInt16>
        var lastPublishedSnapshot: M720ControllerSessionSnapshot?
        var pendingRetryRequestID: UUID?
        var removalWaiters: [() -> Void] = []
        var invalidationStarted = false
        var invalidationFinished = false

        init(
            device: Device,
            snapshot: M720DeviceSnapshot,
            token: UUID,
            session: M720SessionControlling,
            journalIdentityUsable: Bool,
            requiredCIDs: Set<UInt16>
        ) {
            registryEntryID = snapshot.registryEntryID
            self.device = device
            self.snapshot = snapshot
            self.token = token
            self.session = session
            self.journalIdentityUsable = journalIdentityUsable
            self.requiredCIDs = requiredCIDs
        }
    }

    private final class TemporaryPolicyOperation {
        let generation: UInt64
        let contextGeneration: UInt64
        let targetsByToken: [UUID: Set<UInt16>]
        let blocksLeaseOnFailure: Bool
        let completion: (M720TemporaryPolicyResult) -> Void
        var didComplete = false
        var readyDeliveryWasEnqueued = false

        init(
            generation: UInt64,
            contextGeneration: UInt64,
            targetsByToken: [UUID: Set<UInt16>],
            blocksLeaseOnFailure: Bool,
            completion: @escaping (M720TemporaryPolicyResult) -> Void
        ) {
            self.generation = generation
            self.contextGeneration = contextGeneration
            self.targetsByToken = targetsByToken
            self.blocksLeaseOnFailure = blocksLeaseOnFailure
            self.completion = completion
        }
    }

    private final class TemporaryPolicyLease {
        let ownerID: UUID
        let frozenSavedTargets: [UUID: Set<UInt16>]
        var overridesByToken: [UUID: Set<UInt16>]
        var operation: TemporaryPolicyOperation?
        var lastVerifiedTargets: [UUID: Set<UInt16>]?
        var lastVerifiedContextGeneration: UInt64?
        var blocked = false

        init(
            ownerID: UUID,
            frozenSavedTargets: [UUID: Set<UInt16>],
            overridesByToken: [UUID: Set<UInt16>]
        ) {
            self.ownerID = ownerID
            self.frozenSavedTargets = frozenSavedTargets
            self.overridesByToken = overridesByToken
        }
    }

    private enum TemporaryPolicyEvaluation {
        case ready
        case waiting
        case failed(M720StableErrorCode, shouldBlockLease: Bool?)
    }

    private final class PendingReplacement {
        let device: Device
        let snapshot: M720DeviceSnapshot
        var journalIdentityUsable: Bool
        var waitingForTokens: Set<UUID>

        init(
            device: Device,
            snapshot: M720DeviceSnapshot,
            journalIdentityUsable: Bool,
            waitingForTokens: Set<UUID>
        ) {
            self.device = device
            self.snapshot = snapshot
            self.journalIdentityUsable = journalIdentityUsable
            self.waitingForTokens = waitingForTokens
        }
    }

    private final class CompletionBarrier {
        private var remainingTokens: Set<UUID>
        private var didComplete = false
        private let completion: () -> Void

        init(tokens: Set<UUID>, completion: @escaping () -> Void) {
            remainingTokens = tokens
            self.completion = completion
        }

        func finish(token: UUID) {
            guard !didComplete, remainingTokens.remove(token) != nil else { return }
            guard remainingTokens.isEmpty else { return }
            didComplete = true
            completion()
        }
    }

    @objc static let shared = M720HIDPPController()

    private let identityProvider: IdentityProvider
    private let sessionFactory: SessionFactory
    private let tokenFactory: () -> UUID
    private let enqueueStart: StartExecutor
    private let stableStateObserver: StableStateObserver
    private let workspaceCenter: NotificationCenter
    private var workspaceObservers: [NSObjectProtocol] = []

    private var entries: [UInt64: Entry] = [:]
    private var pendingReplacements: [UInt64: PendingReplacement] = [:]
    private var savedRequiredCIDs: Set<UInt16> = []
    private var buttonsEnabled = false
    private var deviceSetRevision: UInt64 = 0
    private var temporaryPolicyLease: TemporaryPolicyLease?
    private var temporaryPolicyOperationGeneration: UInt64 = 0
    private var policyContextGeneration: UInt64 = 0
    private var lastPolicyContextError: M720StableErrorCode = .cancelled
    private var shutdownStarted = false
    private var shutdownFinished = false
    private var shutdownDeadlineWasPropagated = false
    private var shutdownWaiters: [() -> Void] = []

    @nonobjc var onPreparationContextChange: ((M720PreparationContextChange) -> Void)?
    @nonobjc var onStableStateChange: ((M720ControllerSessionSnapshot) -> Void)?

    private override init() {
        identityProvider = Self.productionSnapshot
        sessionFactory = Self.productionSession
        tokenFactory = UUID.init
        enqueueStart = { block in DispatchQueue.main.async(execute: block) }
        stableStateObserver = { _ in }
        workspaceCenter = NSWorkspace.shared.notificationCenter
        super.init()
        observeWorkspaceLifecycle()
    }

    @nonobjc init(
        identityProvider: @escaping IdentityProvider,
        sessionFactory: @escaping SessionFactory,
        tokenFactory: @escaping () -> UUID,
        enqueueStart: @escaping StartExecutor,
        stableStateObserver: @escaping StableStateObserver,
        workspaceCenter: NotificationCenter
    ) {
        self.identityProvider = identityProvider
        self.sessionFactory = sessionFactory
        self.tokenFactory = tokenFactory
        self.enqueueStart = enqueueStart
        self.stableStateObserver = stableStateObserver
        self.workspaceCenter = workspaceCenter
        super.init()
        observeWorkspaceLifecycle()
    }

    deinit {
        workspaceObservers.forEach(workspaceCenter.removeObserver)
    }

    @objc(deviceDidAttach:)
    func deviceDidAttach(_ device: Device) {
        guard !shutdownStarted else { return }
        guard !contains(device: device) else { return }
        guard let snapshot = identityProvider(device) else { return }
        guard snapshot.registryEntryID != 0 else { return }
        guard M720Profile.isEligible(
            vendorID: snapshot.vendorID,
            productID: snapshot.productID,
            transport: snapshot.transport
        ) else { return }

        let oldEntry = entries[snapshot.registryEntryID]
        let supersededPending = pendingReplacements[snapshot.registryEntryID]
        let journalIdentityUsable = downgradeCollidersAndDetermineUsability(
            for: snapshot,
            excludingReplacedEntry: oldEntry,
            excludingSupersededPending: supersededPending
        )
        let waitingForTokens = teardownBarrierTokens(
            for: snapshot,
            replacing: oldEntry,
            superseding: supersededPending
        )

        if !waitingForTokens.isEmpty {
            pendingReplacements[snapshot.registryEntryID] = PendingReplacement(
                device: device,
                snapshot: snapshot,
                journalIdentityUsable: journalIdentityUsable,
                waitingForTokens: waitingForTokens
            )
            noteDeviceSetChange()
            if let oldEntry {
                beginInvalidationIfNeeded(oldEntry)
            }
            return
        }

        pendingReplacements.removeValue(forKey: snapshot.registryEntryID)
        install(
            device: device,
            snapshot: snapshot,
            journalIdentityUsable: journalIdentityUsable
        )
    }

    @objc(prepareForDeviceRemoval:completion:)
    func prepareForDeviceRemoval(
        _ device: Device,
        completion: @escaping () -> Void
    ) {
        if let pending = pendingReplacements.first(where: { $0.value.device === device }) {
            pendingReplacements.removeValue(forKey: pending.key)
            noteDeviceSetChange()
            completion()
            return
        }

        guard let entry = entries.values.first(where: { $0.device === device }) else {
            completion()
            return
        }

        entry.removalWaiters.append(completion)
        beginInvalidationIfNeeded(entry)
    }

    @objc
    func reconcile(
        remaps: NSDictionary,
        buttonsEnabled: Bool,
        remapsAreAddMode: Bool
    ) {
        requireMainTurn()
        guard !shutdownStarted else { return }
        if !remapsAreAddMode {
            savedRequiredCIDs = M720CapturePolicy.requiredCIDs(
                remaps: remaps,
                addMode: false,
                buttonsEnabled: true
            )
        }
        let environmentChanged = self.buttonsEnabled != buttonsEnabled
        self.buttonsEnabled = buttonsEnabled
        if environmentChanged {
            noteEnvironmentChange(enabled: buttonsEnabled)
        }

        for entry in entries.values where !entry.invalidationFinished {
            let desired = effectiveRequiredCIDs(for: entry.token)
            entry.requiredCIDs = desired
            entry.session.setRequiredCIDs(desired)
            publishStableState(for: entry, state: entry.session.state)
            evaluateTemporaryPolicyOperationIfNeeded()
        }
    }

    @objc func prepareForSleep() {
        requireMainTurn()
        guard !shutdownStarted else { return }
        for entry in entries.values where !entry.invalidationStarted {
            entry.session.prepareForSleep(completion: {})
        }
    }

    @objc func reconcileAfterWake() {
        requireMainTurn()
        guard !shutdownStarted else { return }
        for entry in entries.values where !entry.invalidationStarted {
            entry.session.reconcileAfterWake()
        }
    }

    private func knownOwnershipAgentDidLaunch() {
        requireMainTurn()
        guard !shutdownStarted else { return }
        for entry in entries.values where !entry.invalidationStarted {
            entry.session.knownOwnershipAgentDidLaunch()
        }
    }

    @objc func shutdown(completion: @escaping () -> Void) {
        requireMainTurn()
        if shutdownFinished {
            completion()
            return
        }
        shutdownWaiters.append(completion)
        guard !shutdownStarted else { return }
        shutdownStarted = true
        pendingReplacements.removeAll()

        let currentEntries = entries.values.filter { !$0.invalidationFinished }
        guard !currentEntries.isEmpty else {
            finishShutdown()
            return
        }

        let barrier = CompletionBarrier(
            tokens: Set(currentEntries.map(\.token)),
            completion: { [weak self] in self?.finishShutdown() }
        )
        for entry in currentEntries {
            if entry.invalidationStarted {
                entry.removalWaiters.append { [weak self] in
                    self?.performOnMain {
                        barrier.finish(token: entry.token)
                    }
                }
                continue
            }
            entry.session.shutdown { [weak self] in
                self?.performOnMain {
                    barrier.finish(token: entry.token)
                }
            }
        }
    }

    private func finishShutdown() {
        guard shutdownStarted, !shutdownFinished else { return }
        shutdownFinished = true
        let completions = shutdownWaiters
        shutdownWaiters.removeAll()
        completions.forEach { $0() }
    }

    @objc func shutdownDeadlineReached() {
        requireMainTurn()
        guard shutdownStarted, !shutdownDeadlineWasPropagated else { return }
        shutdownDeadlineWasPropagated = true
        for entry in entries.values where !entry.invalidationFinished {
            entry.session.shutdownDeadlineReached()
        }
    }

    @nonobjc func captureStateSnapshots() -> [M720ControllerSessionSnapshot] {
        requireMainTurn()
        return entries.values
            .filter { !$0.invalidationFinished }
            .sorted { $0.registryEntryID < $1.registryEntryID }
            .map { snapshot(for: $0, state: $0.session.state) }
    }

    @discardableResult
    @nonobjc func retryCapture(deviceToken: UUID, requestID: UUID?) -> Bool {
        requireMainTurn()
        guard !shutdownStarted,
              let entry = entries.values.first(where: {
            $0.token == deviceToken && !$0.invalidationStarted
        }), entry.pendingRetryRequestID == nil else { return false }
        guard entry.session.retryAfterConflict(requestID: requestID) else { return false }
        entry.pendingRetryRequestID = requestID
        return true
    }

    @nonobjc func capturePreparationSnapshot() -> M720PreparationSnapshot {
        requireMainTurn()
        guard !shutdownStarted else {
            return M720PreparationSnapshot(
                deviceSetRevision: deviceSetRevision,
                environmentEnabled: false,
                participants: []
            )
        }
        let participants = entries.values
            .filter { !$0.invalidationStarted && !$0.invalidationFinished }
            .map {
                M720PreparationParticipant(
                    deviceToken: $0.token,
                    exactRequiredCIDs: savedRequiredCIDs
                )
            }
            .sorted { $0.deviceToken.uuidString < $1.deviceToken.uuidString }
        return M720PreparationSnapshot(
            deviceSetRevision: deviceSetRevision,
            environmentEnabled: buttonsEnabled,
            participants: participants
        )
    }

    @discardableResult
    @nonobjc func beginTemporaryPolicyLease(
        ownerID: UUID,
        snapshot: M720PreparationSnapshot,
        targetCIDs: Set<UInt16>,
        completion: @escaping (M720TemporaryPolicyResult) -> Void
    ) -> Bool {
        requireMainTurn()
        guard !shutdownStarted,
              temporaryPolicyLease == nil,
              snapshot == capturePreparationSnapshot()
        else { return false }
        let frozen = Dictionary(uniqueKeysWithValues: snapshot.participants.map {
            ($0.deviceToken, $0.exactRequiredCIDs)
        })
        let overrides = Dictionary(uniqueKeysWithValues: snapshot.participants.map {
            ($0.deviceToken, targetCIDs)
        })
        let lease = TemporaryPolicyLease(
            ownerID: ownerID,
            frozenSavedTargets: frozen,
            overridesByToken: overrides
        )
        temporaryPolicyLease = lease
        startTemporaryPolicyOperation(
            lease: lease,
            rawTargetsByToken: overrides,
            blocksLeaseOnFailure: false,
            completion: completion
        )
        return true
    }

    @discardableResult
    @nonobjc func restoreTemporaryPolicyLease(
        ownerID: UUID,
        completion: @escaping (M720TemporaryPolicyResult) -> Void
    ) -> Bool {
        requireMainTurn()
        guard !shutdownStarted,
              let lease = temporaryPolicyLease,
              lease.ownerID == ownerID,
              !lease.blocked
        else { return false }
        startTemporaryPolicyOperation(
            lease: lease,
            rawTargetsByToken: lease.frozenSavedTargets,
            blocksLeaseOnFailure: true,
            completion: completion
        )
        return true
    }

    @discardableResult
    @nonobjc func updateTemporaryPolicyLeaseToCurrentSaved(
        ownerID: UUID,
        completion: @escaping (M720TemporaryPolicyResult) -> Void
    ) -> Bool {
        requireMainTurn()
        guard !shutdownStarted,
              let lease = temporaryPolicyLease,
              lease.ownerID == ownerID,
              !lease.blocked
        else { return false }
        let current = Dictionary(uniqueKeysWithValues: lease.frozenSavedTargets.keys.map {
            ($0, savedRequiredCIDs)
        })
        startTemporaryPolicyOperation(
            lease: lease,
            rawTargetsByToken: current,
            blocksLeaseOnFailure: true,
            completion: completion
        )
        return true
    }

    @discardableResult
    @nonobjc func clearTemporaryPolicyLease(ownerID: UUID) -> Bool {
        requireMainTurn()
        guard !shutdownStarted,
              let lease = temporaryPolicyLease,
              lease.ownerID == ownerID,
              lease.operation == nil,
              !lease.blocked,
              let verifiedTargets = lease.lastVerifiedTargets,
              let verifiedContextGeneration = lease.lastVerifiedContextGeneration,
              verifiedTargets == currentSavedEffectiveTargets(for: lease),
              case .ready = evaluateTemporaryPolicyTargets(
                verifiedTargets,
                contextGeneration: verifiedContextGeneration
              )
        else { return false }
        temporaryPolicyLease = nil
        return true
    }

    private func effectiveRequiredCIDs(for token: UUID) -> Set<UInt16> {
        guard buttonsEnabled else { return [] }
        return temporaryPolicyLease?.overridesByToken[token] ?? savedRequiredCIDs
    }

    private func contains(device: Device) -> Bool {
        entries.values.contains { $0.device === device } ||
            pendingReplacements.values.contains { $0.device === device }
    }

    private func downgradeCollidersAndDetermineUsability(
        for snapshot: M720DeviceSnapshot,
        excludingReplacedEntry replacedEntry: Entry?,
        excludingSupersededPending supersededPending: PendingReplacement?
    ) -> Bool {
        guard let journalKey = snapshot.journalKey else { return false }
        var collisionFound = false

        for entry in entries.values
        where entry !== replacedEntry &&
            !entry.invalidationStarted &&
            entry.snapshot.journalKey == journalKey {
            collisionFound = true
            guard entry.journalIdentityUsable else { continue }
            entry.journalIdentityUsable = false
            entry.session.markJournalIdentityUnusable()
        }

        for pending in pendingReplacements.values
        where pending !== supersededPending && pending.snapshot.journalKey == journalKey {
            collisionFound = true
            pending.journalIdentityUsable = false
        }

        return !collisionFound
    }

    private func teardownBarrierTokens(
        for snapshot: M720DeviceSnapshot,
        replacing oldEntry: Entry?,
        superseding oldPending: PendingReplacement?
    ) -> Set<UUID> {
        var result = oldPending?.waitingForTokens ?? []
        if let oldEntry {
            result.insert(oldEntry.token)
        }
        if let journalKey = snapshot.journalKey {
            for entry in entries.values
            where entry.invalidationStarted && entry.snapshot.journalKey == journalKey {
                result.insert(entry.token)
            }
        }
        return result
    }

    private func install(
        device: Device,
        snapshot: M720DeviceSnapshot,
        journalIdentityUsable: Bool
    ) {
        guard !shutdownStarted,
              entries[snapshot.registryEntryID] == nil
        else { return }
        guard let session = sessionFactory(
            device,
            snapshot,
            journalIdentityUsable
        ) else { return }

        let token = tokenFactory()
        let requiredCIDs = effectiveRequiredCIDs(for: token)
        let entry = Entry(
            device: device,
            snapshot: snapshot,
            token: token,
            session: session,
            journalIdentityUsable: journalIdentityUsable,
            requiredCIDs: requiredCIDs
        )
        entries[snapshot.registryEntryID] = entry

        session.onStateChange = { [weak self] state in
            self?.performOnMain {
                self?.handleStateChange(
                    registryEntryID: snapshot.registryEntryID,
                    token: token,
                    state: state
                )
            }
        }
        session.setRequiredCIDs(entry.requiredCIDs)
        noteDeviceSetChange()

        enqueueStart { [weak self] in
            guard let self,
                  !self.shutdownStarted,
                  let current = self.entries[snapshot.registryEntryID],
                  current === entry,
                  current.token == token,
                  !current.invalidationStarted
            else { return }
            current.session.start()
        }
    }

    private func beginInvalidationIfNeeded(_ entry: Entry) {
        guard !entry.invalidationStarted else { return }
        entry.invalidationStarted = true
        noteDeviceSetChange()
        let registryEntryID = entry.registryEntryID
        let token = entry.token
        entry.session.invalidateForRemoval { [weak self] in
            self?.performOnMain {
                self?.finishInvalidation(
                    entry,
                    registryEntryID: registryEntryID,
                    token: token
                )
            }
        }
    }

    private func finishInvalidation(
        _ entry: Entry,
        registryEntryID: UInt64,
        token: UUID
    ) {
        guard !entry.invalidationFinished,
              let current = entries[registryEntryID],
              current === entry,
              current.token == token
        else { return }

        entry.invalidationFinished = true
        publishStableState(for: entry, state: .invalid(.disconnected))
        entries.removeValue(forKey: registryEntryID)

        let waiters = entry.removalWaiters
        entry.removalWaiters.removeAll()
        waiters.forEach { $0() }
        completeTeardownBarrier(token: token)
    }

    private func completeTeardownBarrier(token: UUID) {
        for pending in pendingReplacements.values {
            pending.waitingForTokens.remove(token)
        }

        let readyRegistryEntryIDs = pendingReplacements
            .filter { registryEntryID, pending in
                pending.waitingForTokens.isEmpty && entries[registryEntryID] == nil
            }
            .map(\.key)
            .sorted()
        for registryEntryID in readyRegistryEntryIDs {
            guard
                entries[registryEntryID] == nil,
                let pending = pendingReplacements[registryEntryID],
                pending.waitingForTokens.isEmpty
            else { continue }
            pendingReplacements.removeValue(forKey: registryEntryID)
            install(
                device: pending.device,
                snapshot: pending.snapshot,
                journalIdentityUsable: pending.journalIdentityUsable
            )
        }
    }

    private func handleStateChange(
        registryEntryID: UInt64,
        token: UUID,
        state: M720SessionState
    ) {
        guard let entry = entries[registryEntryID],
              entry.token == token,
              entry.session.state == state
        else { return }
        publishStableState(for: entry, state: state)
        evaluateTemporaryPolicyOperationIfNeeded()
    }

    private func publishStableState(for entry: Entry, state: M720SessionState) {
        guard state.isStableForController else { return }
        let baseline = snapshot(for: entry, state: state, requestID: nil)
        let requestID = entry.pendingRetryRequestID
        guard requestID != nil || !baseline.requiredCIDs.isEmpty || entry.lastPublishedSnapshot != nil else {
            return
        }
        guard requestID != nil || entry.lastPublishedSnapshot != baseline else { return }
        entry.lastPublishedSnapshot = baseline
        entry.pendingRetryRequestID = nil
        let published = snapshot(for: entry, state: state, requestID: requestID)
        stableStateObserver(published)
        onStableStateChange?(published)
    }

    private func snapshot(
        for entry: Entry,
        state: M720SessionState,
        requestID: UUID? = nil
    ) -> M720ControllerSessionSnapshot {
        M720ControllerSessionSnapshot(
            deviceToken: entry.token,
            state: state,
            errorCode: state.controllerErrorCode,
            requiredCIDs: entry.requiredCIDs,
            requestID: requestID
        )
    }

    private func startTemporaryPolicyOperation(
        lease: TemporaryPolicyLease,
        rawTargetsByToken: [UUID: Set<UInt16>],
        blocksLeaseOnFailure: Bool,
        completion: @escaping (M720TemporaryPolicyResult) -> Void
    ) {
        guard temporaryPolicyLease === lease, !lease.blocked else { return }
        if let current = lease.operation {
            completeSupersededOperation(current, in: lease)
        }

        lease.overridesByToken = rawTargetsByToken
        let liveTokens = Set(entries.values
            .filter { !$0.invalidationStarted && !$0.invalidationFinished }
            .map(\.token))
        let effectiveTargets = rawTargetsByToken.reduce(into: [UUID: Set<UInt16>]()) {
            result, pair in
            guard liveTokens.contains(pair.key) else { return }
            result[pair.key] = buttonsEnabled ? pair.value : []
        }
        temporaryPolicyOperationGeneration &+= 1
        let operation = TemporaryPolicyOperation(
            generation: temporaryPolicyOperationGeneration,
            contextGeneration: policyContextGeneration,
            targetsByToken: effectiveTargets,
            blocksLeaseOnFailure: blocksLeaseOnFailure,
            completion: completion
        )
        lease.operation = operation
        lease.lastVerifiedTargets = nil
        lease.lastVerifiedContextGeneration = nil

        for (token, target) in effectiveTargets.sorted(by: {
            $0.key.uuidString < $1.key.uuidString
        }) {
            guard let entry = liveEntry(for: token) else { continue }
            entry.requiredCIDs = target
            entry.session.setRequiredCIDs(target)
        }
        evaluateTemporaryPolicyOperationIfNeeded()
    }

    private func evaluateTemporaryPolicyOperationIfNeeded() {
        guard let lease = temporaryPolicyLease,
              let operation = lease.operation,
              !operation.didComplete
        else { return }

        switch evaluateTemporaryPolicyTargets(
            operation.targetsByToken,
            contextGeneration: operation.contextGeneration
        ) {
        case .ready:
            enqueueTemporaryPolicyReadyDelivery(operation, in: lease)
        case .waiting:
            return
        case let .failed(error, shouldBlockLease):
            completeTemporaryPolicyOperation(
                operation,
                in: lease,
                result: .failed(error),
                shouldBlockLease: shouldBlockLease
            )
        }
    }

    private func evaluateTemporaryPolicyTargets(
        _ targetsByToken: [UUID: Set<UInt16>],
        contextGeneration: UInt64
    ) -> TemporaryPolicyEvaluation {
        guard contextGeneration == policyContextGeneration else {
            return .failed(lastPolicyContextError, shouldBlockLease: false)
        }
        for (token, target) in targetsByToken {
            guard let entry = liveEntry(for: token) else {
                return .failed(.deviceSetChanged, shouldBlockLease: false)
            }
            guard entry.requiredCIDs == target,
                  entry.session.requiredCIDs == target
            else { return .waiting }
            switch (target.isEmpty, entry.session.state) {
            case (true, .nativeReady), (false, .active):
                continue
            case (_, .conflict):
                return .failed(.conflict, shouldBlockLease: nil)
            case let (_, .invalid(error)):
                return .failed(error, shouldBlockLease: nil)
            case (_, .discovering), (_, .nativeReady), (_, .takingOver),
                 (_, .active), (_, .restoring):
                return .waiting
            }
        }
        return .ready
    }

    private func enqueueTemporaryPolicyReadyDelivery(
        _ operation: TemporaryPolicyOperation,
        in lease: TemporaryPolicyLease
    ) {
        guard !operation.readyDeliveryWasEnqueued else { return }
        operation.readyDeliveryWasEnqueued = true
        enqueueStart { [weak self] in
            guard let self,
                  self.temporaryPolicyLease === lease,
                  lease.operation === operation,
                  !operation.didComplete
            else { return }
            operation.readyDeliveryWasEnqueued = false

            switch self.evaluateTemporaryPolicyTargets(
                operation.targetsByToken,
                contextGeneration: operation.contextGeneration
            ) {
            case .ready:
                guard self.finalizeTemporaryPolicyOperation(
                    operation,
                    in: lease,
                    result: .ready
                ) else { return }
                operation.completion(.ready)
            case .waiting:
                return
            case let .failed(error, shouldBlockLease):
                guard self.finalizeTemporaryPolicyOperation(
                    operation,
                    in: lease,
                    result: .failed(error),
                    shouldBlockLease: shouldBlockLease
                ) else { return }
                operation.completion(.failed(error))
            }
        }
    }

    private func completeTemporaryPolicyOperation(
        _ operation: TemporaryPolicyOperation,
        in lease: TemporaryPolicyLease,
        result: M720TemporaryPolicyResult,
        shouldBlockLease: Bool? = nil
    ) {
        guard finalizeTemporaryPolicyOperation(
            operation,
            in: lease,
            result: result,
            shouldBlockLease: shouldBlockLease
        ) else { return }
        enqueueStart { operation.completion(result) }
    }

    @discardableResult
    private func finalizeTemporaryPolicyOperation(
        _ operation: TemporaryPolicyOperation,
        in lease: TemporaryPolicyLease,
        result: M720TemporaryPolicyResult,
        shouldBlockLease: Bool? = nil
    ) -> Bool {
        guard temporaryPolicyLease === lease,
              lease.operation === operation,
              !operation.didComplete
        else { return false }
        operation.didComplete = true
        lease.operation = nil
        switch result {
        case .ready:
            lease.lastVerifiedTargets = operation.targetsByToken
            lease.lastVerifiedContextGeneration = operation.contextGeneration
        case .failed:
            lease.lastVerifiedTargets = nil
            lease.lastVerifiedContextGeneration = nil
            if shouldBlockLease ?? operation.blocksLeaseOnFailure {
                lease.blocked = true
            }
        }
        return true
    }

    private func completeSupersededOperation(
        _ operation: TemporaryPolicyOperation,
        in lease: TemporaryPolicyLease
    ) {
        guard lease.operation === operation, !operation.didComplete else { return }
        operation.didComplete = true
        lease.operation = nil
        lease.lastVerifiedTargets = nil
        lease.lastVerifiedContextGeneration = nil
        enqueueStart { operation.completion(.failed(.cancelled)) }
    }

    private func currentSavedEffectiveTargets(
        for lease: TemporaryPolicyLease
    ) -> [UUID: Set<UInt16>] {
        let liveTokens = Set(entries.values
            .filter { !$0.invalidationStarted && !$0.invalidationFinished }
            .map(\.token))
        return lease.frozenSavedTargets.reduce(into: [UUID: Set<UInt16>]()) {
            result, pair in
            guard liveTokens.contains(pair.key) else { return }
            result[pair.key] = buttonsEnabled ? savedRequiredCIDs : []
        }
    }

    private func liveEntry(for token: UUID) -> Entry? {
        entries.values.first {
            $0.token == token && !$0.invalidationStarted && !$0.invalidationFinished
        }
    }

    private func noteDeviceSetChange() {
        deviceSetRevision &+= 1
        policyContextGeneration &+= 1
        lastPolicyContextError = .deviceSetChanged
        enqueuePreparationContextChange(.deviceSetChanged(revision: deviceSetRevision))
        evaluateTemporaryPolicyOperationIfNeeded()
    }

    private func noteEnvironmentChange(enabled: Bool) {
        policyContextGeneration &+= 1
        lastPolicyContextError = .cancelled
        enqueuePreparationContextChange(.environmentChanged(enabled: enabled))
        evaluateTemporaryPolicyOperationIfNeeded()
    }

    private func enqueuePreparationContextChange(_ change: M720PreparationContextChange) {
        guard onPreparationContextChange != nil else { return }
        enqueueStart { [weak self] in
            self?.onPreparationContextChange?(change)
        }
    }

    private func requireMainTurn() {
        precondition(Thread.isMainThread, "M720 controller mutation must run on the main thread")
    }

    private func performOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private func observeWorkspaceLifecycle() {
        workspaceObservers = [
            workspaceCenter.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.prepareForSleep()
            },
            workspaceCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.reconcileAfterWake()
            },
            workspaceCenter.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.knownOwnershipAgentDidLaunch()
            },
        ]
    }

    private static func productionSnapshot(_ device: Device) -> M720DeviceSnapshot? {
        guard let iohidDevice = device.iohidDevice else { return nil }
        guard
            let vendorID = IOHIDDeviceGetProperty(
                iohidDevice,
                kIOHIDVendorIDKey as CFString
            ) as? NSNumber,
            let productID = IOHIDDeviceGetProperty(
                iohidDevice,
                kIOHIDProductIDKey as CFString
            ) as? NSNumber,
            let transport = IOHIDDeviceGetProperty(
                iohidDevice,
                kIOHIDTransportKey as CFString
            ) as? String
        else { return nil }

        let serialNumber = IOHIDDeviceGetProperty(
            iohidDevice,
            kIOHIDSerialNumberKey as CFString
        ) as? String
        let physicalDeviceUniqueID = IOHIDDeviceGetProperty(
            iohidDevice,
            "PhysicalDeviceUniqueID" as CFString
        ) as? String

        return M720DeviceSnapshot(
            registryEntryID: device.registryEntryID(),
            vendorID: vendorID.intValue,
            productID: productID.intValue,
            transport: transport,
            serialNumber: serialNumber,
            physicalDeviceUniqueID: physicalDeviceUniqueID
        )
    }

    private static func productionSession(
        device: Device,
        snapshot: M720DeviceSnapshot,
        journalIdentityUsable: Bool
    ) -> M720SessionControlling? {
        guard let transport = BLEHIDPPTransport(device: device) else { return nil }
        let scheduler = DispatchHIDPPScheduler()
        let pipeline = HIDPPRequestPipeline(
            transport: transport,
            scheduler: scheduler
        )
        let deviceKey = M720DeviceKey(
            vendorID: snapshot.vendorID,
            productID: snapshot.productID,
            transport: snapshot.transport,
            serialNumber: snapshot.serialNumber ?? ""
        )
        return M720HIDPPSession(
            device: device,
            pipeline: pipeline,
            journalRepository: M720OwnershipJournalRepository.shared,
            deviceKey: deviceKey,
            journalIdentityUsable: journalIdentityUsable,
            scheduler: scheduler
        )
    }
}

private extension M720SessionState {
    var isStableForController: Bool {
        switch self {
        case .nativeReady, .active, .conflict, .invalid:
            return true
        case .discovering, .takingOver, .restoring:
            return false
        }
    }

    var controllerErrorCode: M720StableErrorCode? {
        switch self {
        case .conflict:
            return .conflict
        case let .invalid(errorCode):
            return errorCode
        case .discovering, .nativeReady, .takingOver, .active, .restoring:
            return nil
        }
    }
}
