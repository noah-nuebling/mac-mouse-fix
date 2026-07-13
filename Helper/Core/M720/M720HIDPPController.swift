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
    func shutdown(completion: @escaping () -> Void)
    func invalidateForRemoval(completion: @escaping () -> Void)
    func retryAfterConflict(requestID: UUID?)
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

    private var entries: [UInt64: Entry] = [:]
    private var pendingReplacements: [UInt64: PendingReplacement] = [:]
    private var savedRequiredCIDs: Set<UInt16> = []
    private var buttonsEnabled = false

    private override init() {
        identityProvider = Self.productionSnapshot
        sessionFactory = Self.productionSession
        tokenFactory = UUID.init
        enqueueStart = { block in DispatchQueue.main.async(execute: block) }
        stableStateObserver = { _ in }
        super.init()
    }

    @nonobjc init(
        identityProvider: @escaping IdentityProvider,
        sessionFactory: @escaping SessionFactory,
        tokenFactory: @escaping () -> UUID,
        enqueueStart: @escaping StartExecutor,
        stableStateObserver: @escaping StableStateObserver
    ) {
        self.identityProvider = identityProvider
        self.sessionFactory = sessionFactory
        self.tokenFactory = tokenFactory
        self.enqueueStart = enqueueStart
        self.stableStateObserver = stableStateObserver
        super.init()
    }

    @objc(deviceDidAttach:)
    func deviceDidAttach(_ device: Device) {
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
        if !remapsAreAddMode {
            savedRequiredCIDs = M720CapturePolicy.requiredCIDs(
                remaps: remaps,
                addMode: false,
                buttonsEnabled: true
            )
        }
        self.buttonsEnabled = buttonsEnabled

        let desired = effectiveRequiredCIDs
        for entry in entries.values where !entry.invalidationFinished {
            entry.requiredCIDs = desired
            entry.session.setRequiredCIDs(desired)
            publishStableState(for: entry, state: entry.session.state)
        }
    }

    @objc func prepareForSleep() {
        for entry in entries.values where !entry.invalidationStarted {
            entry.session.prepareForSleep(completion: {})
        }
    }

    @objc func reconcileAfterWake() {
        for entry in entries.values where !entry.invalidationStarted {
            entry.session.reconcileAfterWake()
        }
    }

    @objc func shutdown(completion: @escaping () -> Void) {
        let currentEntries = entries.values.filter { !$0.invalidationStarted }
        guard !currentEntries.isEmpty else {
            completion()
            return
        }

        let barrier = CompletionBarrier(
            tokens: Set(currentEntries.map(\.token)),
            completion: completion
        )
        for entry in currentEntries {
            entry.session.shutdown { [weak self] in
                self?.performOnMain {
                    barrier.finish(token: entry.token)
                }
            }
        }
    }

    @nonobjc func captureStateSnapshots() -> [M720ControllerSessionSnapshot] {
        entries.values
            .filter { !$0.invalidationFinished }
            .sorted { $0.registryEntryID < $1.registryEntryID }
            .map { snapshot(for: $0, state: $0.session.state) }
    }

    @discardableResult
    @nonobjc func retryCapture(deviceToken: UUID, requestID: UUID?) -> Bool {
        guard let entry = entries.values.first(where: {
            $0.token == deviceToken && !$0.invalidationStarted
        }) else { return false }
        entry.session.retryAfterConflict(requestID: requestID)
        return true
    }

    private var effectiveRequiredCIDs: Set<UInt16> {
        buttonsEnabled ? savedRequiredCIDs : []
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
        guard entries[snapshot.registryEntryID] == nil else { return }
        guard let session = sessionFactory(
            device,
            snapshot,
            journalIdentityUsable
        ) else { return }

        let token = tokenFactory()
        let entry = Entry(
            device: device,
            snapshot: snapshot,
            token: token,
            session: session,
            journalIdentityUsable: journalIdentityUsable,
            requiredCIDs: effectiveRequiredCIDs
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

        enqueueStart { [weak self] in
            guard let self,
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
    }

    private func publishStableState(for entry: Entry, state: M720SessionState) {
        guard state.isStableForController else { return }
        let next = snapshot(for: entry, state: state)
        guard !next.requiredCIDs.isEmpty || entry.lastPublishedSnapshot != nil else {
            return
        }
        guard entry.lastPublishedSnapshot != next else { return }
        entry.lastPublishedSnapshot = next
        stableStateObserver(next)
    }

    private func snapshot(
        for entry: Entry,
        state: M720SessionState
    ) -> M720ControllerSessionSnapshot {
        M720ControllerSessionSnapshot(
            deviceToken: entry.token,
            state: state,
            errorCode: state.controllerErrorCode,
            requiredCIDs: entry.requiredCIDs
        )
    }

    private func performOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
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
