import Foundation

enum M720SessionState: Equatable {
    case discovering
    case nativeReady
    case takingOver
    case active
    case restoring
    case conflict
    case invalid(M720StableErrorCode)
}

protocol M720JournalCoordinating: AnyObject {
    typealias Completion = (Result<M720OwnershipJournal, Error>) -> Void

    func reload(completion: @escaping Completion)
    func snapshot(completion: @escaping Completion)
    func mutateCID(
        for key: M720DeviceKey,
        cid: UInt16,
        mutation: @escaping (M720JournalCIDEntry?) throws -> M720JournalCIDEntry?,
        completion: @escaping Completion
    )
}

extension M720OwnershipJournalRepository: M720JournalCoordinating {}

protocol M720ButtonEventSink: AnyObject {
    func emit(device: Device, button: Int, downNotUp: Bool)
    func cancel(device: Device, button: Int, completion: @escaping () -> Void)
}

final class M720ButtonsEventSink: M720ButtonEventSink {
    func emit(device: Device, button: Int, downNotUp: Bool) {
        _ = Buttons.handleInput(ButtonInputContext(
            device: device,
            button: button,
            downNotUp: downNotUp,
            modifiers: NSDictionary(dictionary: Modifiers.modifiers(with: nil)),
            source: .hidpp,
            systemEvent: nil
        ))
    }

    func cancel(device: Device, button: Int, completion: @escaping () -> Void) {
        Buttons.cancelInput(
            device: device,
            button: NSNumber(value: button),
            completion: completion
        )
    }
}

final class M720HIDPPSession {
    private enum RollbackOutcome {
        case reconcilePolicy
        case invalid(M720StableErrorCode)
        case shutdown
    }

    private enum TerminalIntent: Equatable {
        case none
        case shutdown
        case removal
    }

    private enum TakeoverReadbackOwnership: Equatable {
        case intended
        case original
        case external
    }

    private final class CancelBatch {
        var remainingCIDs: Set<UInt16>
        var completed = false
        var completions: [() -> Void]

        init(cids: Set<UInt16>, completion: @escaping () -> Void) {
            remainingCIDs = cids
            completions = [completion]
        }
    }

    private final class EventEdgeBatch {
        let generation: UInt64
        let edges: [M720ButtonEdge]
        var nextIndex = 0

        init(generation: UInt64, edges: [M720ButtonEdge]) {
            self.generation = generation
            self.edges = edges
        }
    }

    private(set) var state: M720SessionState = .discovering
    private(set) var requiredCIDs: Set<UInt16> = []
    private(set) var appliedCIDs: Set<UInt16> = []
    private(set) var lifecycleGeneration: UInt64 = 0
    private(set) var eventGeneration: UInt64 = 0
    var onStateChange: ((M720SessionState) -> Void)?

    private let device: Device
    private let pipeline: HIDPPRequestPipeline
    private let journalRepository: M720JournalCoordinating
    private let deviceKey: M720DeviceKey
    private let journalIdentityUsable: Bool
    private let buttonSink: M720ButtonEventSink
    private var operationGeneration: UInt64 = 0
    private var policyGeneration: UInt64 = 0
    private var started = false
    private var discoveredFeatureIndex: UInt8?
    private var discoveredControls: [UInt16: HIDPPControlInfo] = [:]
    private var discoveredCurrentStates: [UInt16: HIDPPReportingState] = [:]
    private var originalStates: [UInt16: HIDPPReportingState] = [:]
    private var journalSnapshot = M720OwnershipJournal.emptyV1
    private var startupJournalEntriesPresent = false
    private var frozenRequiredCIDs: [UInt16] = []
    private var takeoverPreflightStates: [UInt16: HIDPPReportingState] = [:]
    private var intendedStates: [UInt16: HIDPPReportingState] = [:]
    private var preparedCIDs: Set<UInt16> = []
    private var touchedCIDs: Set<UInt16> = []
    private var knownWrittenCIDs: Set<UInt16> = []
    private var transactionAppliedCIDs: Set<UInt16> = []
    private var externallyOwnedCIDs: Set<UInt16> = []
    private var confirmedNotOwnedCIDs: Set<UInt16> = []
    private var gateOpen = false
    private var pressedSet = M720PressedSet()
    private var forwardedDownCIDs: Set<UInt16> = []
    private var activeEventEdgeBatch: EventEdgeBatch?
    private var pendingEventEdgeBatches: [EventEdgeBatch] = []
    private var eventEdgeContinuationPending = false
    private var cancelBatch: CancelBatch?
    private var rollbackCIDs: [UInt16] = []
    private var rollbackHadConflict = false
    private var rollbackOutcome: RollbackOutcome = .reconcilePolicy
    private var terminalIntent: TerminalIntent = .none
    private var shutdownWaiters: [() -> Void] = []
    private var removalWaiters: [() -> Void] = []
    private var terminalFinished = false

    init(
        device: Device,
        pipeline: HIDPPRequestPipeline,
        journalRepository: M720JournalCoordinating,
        deviceKey: M720DeviceKey,
        journalIdentityUsable: Bool,
        buttonSink: M720ButtonEventSink = M720ButtonsEventSink()
    ) {
        self.device = device
        self.pipeline = pipeline
        self.journalRepository = journalRepository
        self.deviceKey = deviceKey
        self.journalIdentityUsable = journalIdentityUsable
        self.buttonSink = buttonSink
    }

    func start() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  !self.started,
                  self.terminalIntent == .none,
                  !self.terminalFinished
            else { return }
            self.started = true
            self.lifecycleGeneration &+= 1
            self.operationGeneration &+= 1
            self.pipeline.beginNewLifecycle()
            let lifecycle = self.lifecycleGeneration
            let operation = self.operationGeneration
            self.journalRepository.reload { [weak self] result in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.continuationIsCurrent(
                        lifecycle: lifecycle,
                        operation: operation,
                        state: .discovering
                    ) else { return }
                    switch result {
                    case let .success(journal):
                        self.journalSnapshot = journal
                        self.startupJournalEntriesPresent = journal.devices
                            .first { $0.key == self.deviceKey }?
                            .controls.isEmpty == false
                        self.requestRootFeature(
                            lifecycle: lifecycle,
                            operation: operation
                        )
                    case .failure:
                        self.enterInvalid(.protocol)
                    }
                }
            }
        }
    }

    func setRequiredCIDs(_ cids: Set<UInt16>) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.terminalIntent == .none else { return }
            self.policyGeneration &+= 1
            self.requiredCIDs = cids
            guard self.started else { return }
            guard self.requiredPolicyIsSupported else {
                switch self.state {
                case .takingOver:
                    // The in-flight boundary may still durably record ownership.
                    // Its policy-token continuation will include that CID in rollback.
                    break
                case .active:
                    self.beginRollback(outcome: .invalid(.unsupported))
                case .restoring:
                    self.rollbackOutcome = .invalid(.unsupported)
                case .discovering, .nativeReady, .conflict, .invalid:
                    self.enterInvalid(.unsupported)
                }
                return
            }
            switch self.state {
            case .nativeReady where !cids.isEmpty:
                self.beginTakeover()
            case .active where cids == self.appliedCIDs:
                break
            case .active:
                self.beginRollbackForPolicyReplacement()
            default:
                break
            }
        }
    }

    func retryAfterConflict(requestID: UUID?) {
        DispatchQueue.main.async { _ = requestID }
    }

    func verifyOwnership() {
        DispatchQueue.main.async {}
    }

    func prepareForSleep(completion: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                completion()
                return
            }
            if self.cancelBatch != nil {
                self.beginCancelBarrier(completion: completion)
                return
            }
            guard self.state == .active else {
                completion()
                return
            }
            self.closeEventGate()
            self.beginCancelBarrier(completion: completion)
        }
    }

    func shutdown(completion: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                completion()
                return
            }
            if self.terminalFinished {
                DispatchQueue.main.async(execute: completion)
                return
            }
            self.shutdownWaiters.append(completion)
            guard self.terminalIntent == .none else { return }
            self.terminalIntent = .shutdown
            self.requiredCIDs.removeAll()
            self.policyGeneration &+= 1
            switch self.state {
            case .active:
                self.beginRollback(outcome: .shutdown)
            case .takingOver:
                break
            case .restoring:
                self.rollbackOutcome = .shutdown
            case .discovering, .nativeReady:
                self.finalizeShutdown()
            case .conflict:
                self.finalizeShutdown(reason: .conflict)
            case let .invalid(code):
                self.finalizeShutdown(reason: code)
            }
        }
    }

    func invalidateForRemoval(completion: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                completion()
                return
            }
            if self.terminalFinished {
                if self.terminalIntent == .shutdown {
                    self.terminalIntent = .removal
                    self.transition(to: .invalid(.disconnected))
                    completion()
                } else {
                    DispatchQueue.main.async(execute: completion)
                }
                return
            }
            self.removalWaiters.append(completion)
            guard self.terminalIntent != .removal else { return }
            self.terminalIntent = .removal
            self.closeEventGate()
            self.lifecycleGeneration &+= 1
            self.operationGeneration &+= 1
            self.pipeline.beginNewLifecycle()
            self.beginCancelBarrier { [weak self] in self?.finalizeRemoval() }
        }
    }

    private func requestRootFeature(lifecycle: UInt64, operation: UInt64) {
        pipeline.perform(
            featureIndex: 0,
            function: 0,
            parameters: [0x1B, 0x04]
        ) { [weak self] result in
            guard let self, self.continuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation,
                state: .discovering
            ) else { return }
            switch result {
            case let .success(parameters):
                do {
                    self.discoveredFeatureIndex = try ReprogControlsV4
                        .decodeFeatureLookup(parameters).featureIndex
                    self.requestControlCount(
                        lifecycle: lifecycle,
                        operation: operation
                    )
                } catch {
                    self.enterInvalid(.unsupported)
                }
            case let .failure(error):
                self.enterInvalid(self.stableCode(for: error))
            }
        }
    }

    private func requestControlCount(lifecycle: UInt64, operation: UInt64) {
        guard let featureIndex = discoveredFeatureIndex else {
            enterInvalid(.protocol)
            return
        }
        pipeline.perform(
            featureIndex: featureIndex,
            function: ReprogControlsV4.Function.getCount.rawValue,
            parameters: []
        ) { [weak self] result in
            guard let self, self.continuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation,
                state: .discovering
            ) else { return }
            switch result {
            case let .success(parameters):
                do {
                    let count = try ReprogControlsV4.decodeControlCount(parameters)
                    self.discoveredControls.removeAll(keepingCapacity: true)
                    self.requestControlInfo(
                        index: 0,
                        count: Int(count),
                        lifecycle: lifecycle,
                        operation: operation
                    )
                } catch {
                    self.enterInvalid(.protocol)
                }
            case let .failure(error):
                self.enterInvalid(self.stableCode(for: error))
            }
        }
    }

    private func requestControlInfo(
        index: Int,
        count: Int,
        lifecycle: UInt64,
        operation: UInt64
    ) {
        guard index < count else {
            validateDiscoveredTargetsAndRequestReporting(
                lifecycle: lifecycle,
                operation: operation
            )
            return
        }
        guard let featureIndex = discoveredFeatureIndex else {
            enterInvalid(.protocol)
            return
        }
        pipeline.perform(
            featureIndex: featureIndex,
            function: ReprogControlsV4.Function.getCidInfo.rawValue,
            parameters: [UInt8(index)]
        ) { [weak self] result in
            guard let self, self.continuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation,
                state: .discovering
            ) else { return }
            switch result {
            case let .success(parameters):
                do {
                    let info = try ReprogControlsV4.decodeControlInfo(parameters)
                    guard self.discoveredControls[info.cid] == nil else {
                        self.enterInvalid(.protocol)
                        return
                    }
                    self.discoveredControls[info.cid] = info
                    self.requestControlInfo(
                        index: index + 1,
                        count: count,
                        lifecycle: lifecycle,
                        operation: operation
                    )
                } catch {
                    self.enterInvalid(.protocol)
                }
            case let .failure(error):
                self.enterInvalid(self.stableCode(for: error))
            }
        }
    }

    private func validateDiscoveredTargetsAndRequestReporting(
        lifecycle: UInt64,
        operation: UInt64
    ) {
        let targetCIDs = M720Profile.cidToButton.keys.sorted()
        do {
            for cid in targetCIDs {
                guard let info = discoveredControls[cid] else {
                    enterInvalid(.unsupported)
                    return
                }
                try ReprogControlsV4.validateTarget(info)
            }
        } catch {
            enterInvalid(.unsupported)
            return
        }
        discoveredCurrentStates.removeAll(keepingCapacity: true)
        requestReportingSnapshot(
            targetIndex: 0,
            targetCIDs: targetCIDs,
            lifecycle: lifecycle,
            operation: operation
        )
    }

    private func requestReportingSnapshot(
        targetIndex: Int,
        targetCIDs: [UInt16],
        lifecycle: UInt64,
        operation: UInt64
    ) {
        guard targetIndex < targetCIDs.count else {
            finishDiscovery()
            return
        }
        guard let featureIndex = discoveredFeatureIndex else {
            enterInvalid(.protocol)
            return
        }
        let cid = targetCIDs[targetIndex]
        pipeline.perform(
            featureIndex: featureIndex,
            function: ReprogControlsV4.Function.getCidReporting.rawValue,
            parameters: [UInt8(cid >> 8), UInt8(cid & 0x00FF)]
        ) { [weak self] result in
            guard let self, self.continuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation,
                state: .discovering
            ) else { return }
            switch result {
            case let .success(parameters):
                do {
                    let snapshot = try ReprogControlsV4.decodeReportingState(parameters)
                    guard snapshot.cid == cid else {
                        self.enterInvalid(.protocol)
                        return
                    }
                    self.discoveredCurrentStates[cid] = snapshot
                    self.requestReportingSnapshot(
                        targetIndex: targetIndex + 1,
                        targetCIDs: targetCIDs,
                        lifecycle: lifecycle,
                        operation: operation
                    )
                } catch {
                    self.enterInvalid(.protocol)
                }
            case let .failure(error):
                self.enterInvalid(self.stableCode(for: error))
            }
        }
    }

    private func finishDiscovery() {
        originalStates = discoveredCurrentStates.filter { !$0.value.isDiverted }
        guard journalIdentityUsable, !deviceKey.serialNumber.isEmpty else {
            enterInvalid(.unsupported)
            return
        }
        guard !startupJournalEntriesPresent else {
            enterInvalid(.protocol)
            return
        }
        guard requiredPolicyIsSupported else {
            enterInvalid(.unsupported)
            return
        }
        transition(to: .nativeReady)
        if !requiredCIDs.isEmpty {
            beginTakeover()
        }
    }

    private func beginTakeover() {
        guard state == .nativeReady, !requiredCIDs.isEmpty else { return }
        operationGeneration &+= 1
        let lifecycle = lifecycleGeneration
        let operation = operationGeneration
        let policy = policyGeneration
        frozenRequiredCIDs = requiredCIDs.sorted()
        takeoverPreflightStates.removeAll(keepingCapacity: true)
        intendedStates = Dictionary(uniqueKeysWithValues: frozenRequiredCIDs.compactMap { cid in
            originalStates[cid].map { (cid, $0.changingDivert(to: true)) }
        })
        preparedCIDs.removeAll()
        touchedCIDs.removeAll()
        knownWrittenCIDs.removeAll()
        transactionAppliedCIDs.removeAll()
        externallyOwnedCIDs.removeAll()
        confirmedNotOwnedCIDs.removeAll()
        appliedCIDs.removeAll()
        gateOpen = false
        transition(to: .takingOver)
        requestTakeoverPreflight(
            index: 0,
            lifecycle: lifecycle,
            operation: operation,
            policy: policy
        )
    }

    private func requestTakeoverPreflight(
        index: Int,
        lifecycle: UInt64,
        operation: UInt64,
        policy: UInt64
    ) {
        guard takeoverContinuationIsCurrent(
            lifecycle: lifecycle,
            operation: operation,
            policy: policy
        ) else { return }
        guard index < frozenRequiredCIDs.count else {
            guard preflightAllowsTakeover() else {
                operationGeneration &+= 1
                transition(to: .conflict)
                return
            }
            persistPrepared(
                index: 0,
                lifecycle: lifecycle,
                operation: operation,
                policy: policy
            )
            return
        }
        guard let featureIndex = discoveredFeatureIndex else {
            enterInvalid(.protocol)
            return
        }
        let cid = frozenRequiredCIDs[index]
        pipeline.perform(
            featureIndex: featureIndex,
            function: ReprogControlsV4.Function.getCidReporting.rawValue,
            parameters: bigEndian(cid)
        ) { [weak self] result in
            guard let self, self.takeoverContinuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation,
                policy: policy
            ) else { return }
            switch result {
            case let .success(parameters):
                do {
                    let current = try ReprogControlsV4.decodeReportingState(parameters)
                    guard current.cid == cid else {
                        self.enterInvalid(.protocol)
                        return
                    }
                    self.takeoverPreflightStates[cid] = current
                    self.requestTakeoverPreflight(
                        index: index + 1,
                        lifecycle: lifecycle,
                        operation: operation,
                        policy: policy
                    )
                } catch {
                    self.enterInvalid(.protocol)
                }
            case let .failure(error):
                self.enterInvalid(self.stableCode(for: error))
            }
        }
    }

    private func preflightAllowsTakeover() -> Bool {
        let entries = journalEntriesForThisDevice()
        return frozenRequiredCIDs.allSatisfy { cid in
            guard let value = takeoverPreflightStates[cid],
                  let baseline = originalStates[cid]
            else { return false }
            let cleanBaseline = value == baseline && !value.isDiverted
            let explainedOwnership = entries[cid]?.intended == value
            return cleanBaseline || explainedOwnership
        }
    }

    private func persistPrepared(
        index: Int,
        lifecycle: UInt64,
        operation: UInt64,
        policy: UInt64
    ) {
        guard takeoverContinuationIsCurrent(
            lifecycle: lifecycle,
            operation: operation,
            policy: policy
        ) else { return }
        guard index < frozenRequiredCIDs.count else {
            publishCompletedTakeover()
            return
        }
        let cid = frozenRequiredCIDs[index]
        guard let original = originalStates[cid], let intended = intendedStates[cid] else {
            enterInvalid(.protocol)
            return
        }
        journalRepository.mutateCID(
            for: deviceKey,
            cid: cid,
            mutation: { existing in
                if let existing,
                   (existing.original != original || existing.intended != intended) {
                    throw M720JournalRepositoryError.mismatchedCID
                }
                return M720JournalCIDEntry(
                    cid: cid,
                    original: original,
                    intended: intended,
                    phase: .prepared
                )
            }
        ) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.takeoverBaseContinuationIsCurrent(
                    lifecycle: lifecycle,
                    operation: operation
                ) else { return }
                switch result {
                case let .success(journal):
                    self.journalSnapshot = journal
                    self.preparedCIDs.insert(cid)
                    guard self.takeoverPolicyIsCurrentOrBeginRollback(policy) else {
                        return
                    }
                    self.issueTakeoverSet(
                        index: index,
                        lifecycle: lifecycle,
                        operation: operation,
                        policy: policy
                    )
                case let .failure(error):
                    self.handleJournalMutationFailure(
                        error,
                        lifecycle: lifecycle,
                        operation: operation,
                        state: .takingOver
                    )
                }
            }
        }
    }

    private func issueTakeoverSet(
        index: Int,
        lifecycle: UInt64,
        operation: UInt64,
        policy: UInt64
    ) {
        guard takeoverContinuationIsCurrent(
            lifecycle: lifecycle,
            operation: operation,
            policy: policy
        ), let featureIndex = discoveredFeatureIndex else { return }
        let cid = frozenRequiredCIDs[index]
        let parameters = ReprogControlsV4.setReportingParameters(cid: cid, diverted: true)
        touchedCIDs.insert(cid)
        pipeline.perform(
            featureIndex: featureIndex,
            function: ReprogControlsV4.Function.setCidReporting.rawValue,
            parameters: parameters
        ) { [weak self] result in
            guard let self, self.takeoverContinuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation,
                policy: policy
            ) else { return }
            switch result {
            case let .success(response):
                do {
                    try ReprogControlsV4.validateSetCidReportingEcho(
                        response,
                        matches: parameters
                    )
                    self.requestTakeoverReadback(
                        index: index,
                        lifecycle: lifecycle,
                        operation: operation,
                        policy: policy
                    )
                } catch {
                    self.resolveTouchedCIDAfterUncertainSet(
                        index: index,
                        lifecycle: lifecycle,
                        operation: operation,
                        policy: policy
                    )
                }
            case .failure:
                self.resolveTouchedCIDAfterUncertainSet(
                    index: index,
                    lifecycle: lifecycle,
                    operation: operation,
                    policy: policy
                )
            }
        }
    }

    private func requestTakeoverReadback(
        index: Int,
        lifecycle: UInt64,
        operation: UInt64,
        policy: UInt64
    ) {
        guard takeoverContinuationIsCurrent(
            lifecycle: lifecycle,
            operation: operation,
            policy: policy
        ), let featureIndex = discoveredFeatureIndex else { return }
        let cid = frozenRequiredCIDs[index]
        pipeline.perform(
            featureIndex: featureIndex,
            function: ReprogControlsV4.Function.getCidReporting.rawValue,
            parameters: bigEndian(cid)
        ) { [weak self] result in
            guard let self, self.takeoverBaseContinuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation
            ) else { return }
            switch result {
            case let .success(parameters):
                do {
                    let current = try ReprogControlsV4.decodeReportingState(parameters)
                    guard let ownership = self.recordTakeoverReadbackOwnership(
                        current,
                        cid: cid
                    ) else {
                        guard self.takeoverPolicyIsCurrentOrBeginRollback(policy) else {
                            return
                        }
                        self.beginRollbackAfterTakeoverFailure(.protocol)
                        return
                    }
                    guard self.takeoverPolicyIsCurrentOrBeginRollback(policy) else {
                        return
                    }
                    guard ownership == .intended else {
                        self.beginRollbackAfterTakeoverFailure(.protocol)
                        return
                    }
                    self.persistApplied(
                        index: index,
                        lifecycle: lifecycle,
                        operation: operation,
                        policy: policy
                    )
                } catch {
                    guard self.takeoverPolicyIsCurrentOrBeginRollback(policy) else {
                        return
                    }
                    self.enterInvalid(.protocol)
                }
            case let .failure(error):
                guard self.takeoverPolicyIsCurrentOrBeginRollback(policy) else {
                    return
                }
                self.enterInvalid(self.stableCode(for: error))
            }
        }
    }

    private func persistApplied(
        index: Int,
        lifecycle: UInt64,
        operation: UInt64,
        policy: UInt64
    ) {
        let cid = frozenRequiredCIDs[index]
        journalRepository.mutateCID(
            for: deviceKey,
            cid: cid,
            mutation: { existing in
                guard var existing else {
                    throw M720JournalRepositoryError.notLoaded
                }
                existing.phase = .applied
                return existing
            }
        ) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.takeoverBaseContinuationIsCurrent(
                    lifecycle: lifecycle,
                    operation: operation
                ) else { return }
                switch result {
                case let .success(journal):
                    self.journalSnapshot = journal
                    self.transactionAppliedCIDs.insert(cid)
                    guard self.takeoverPolicyIsCurrentOrBeginRollback(policy) else {
                        return
                    }
                    self.persistPrepared(
                        index: index + 1,
                        lifecycle: lifecycle,
                        operation: operation,
                        policy: policy
                    )
                case let .failure(error):
                    self.handleJournalMutationFailure(
                        error,
                        lifecycle: lifecycle,
                        operation: operation,
                        state: .takingOver
                    )
                }
            }
        }
    }

    private func publishCompletedTakeover() {
        let completeSet = Set(frozenRequiredCIDs)
        guard transactionAppliedCIDs == completeSet,
              requiredCIDs == completeSet,
              !completeSet.isEmpty
        else {
            enterInvalid(.protocol)
            return
        }
        appliedCIDs = completeSet
        gateOpen = true
        transition(to: .active)
        installEventHandler()
    }

    private func beginRollbackForPolicyReplacement() {
        if terminalIntent == .shutdown {
            beginRollback(outcome: .shutdown)
        } else if !requiredPolicyIsSupported {
            beginRollback(outcome: .invalid(.unsupported))
        } else {
            beginRollback(outcome: .reconcilePolicy)
        }
    }

    private func beginRollbackAfterTakeoverFailure(_ code: M720StableErrorCode) {
        beginRollback(outcome: terminalIntent == .shutdown ? .shutdown : .invalid(code))
    }

    private func beginRollback(outcome: RollbackOutcome) {
        guard state == .active || state == .takingOver else { return }
        closeEventGate()
        operationGeneration &+= 1
        let lifecycle = lifecycleGeneration
        let operation = operationGeneration
        rollbackCIDs = Set(
            appliedCIDs
                .union(preparedCIDs)
                .union(touchedCIDs)
                .union(knownWrittenCIDs)
                .union(transactionAppliedCIDs)
        ).sorted()
        rollbackHadConflict = false
        rollbackOutcome = outcome
        transition(to: .restoring)
        beginCancelBarrier { [weak self] in
            guard let self, self.continuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation,
                state: .restoring
            ) else { return }
            self.requestRollbackCurrentState(
                index: 0,
                lifecycle: lifecycle,
                operation: operation
            )
        }
    }

    private func handlePipelineEvent(_ inbound: HIDPPInbound, generation: UInt64) {
        guard gateOpen,
              state == .active,
              generation == eventGeneration,
              case let .event(featureIndex, event, parameters) = inbound,
              featureIndex == discoveredFeatureIndex,
              event == 0,
              parameters.count >= 8
        else { return }
        let edges: [M720ButtonEdge]
        do {
            edges = try pressedSet.consume(parameters: Data(parameters.prefix(8)))
        } catch {
            return
        }
        pendingEventEdgeBatches.append(EventEdgeBatch(generation: generation, edges: edges))
        emitNextEventEdgeIfPossible()
    }

    private func emitNextEventEdgeIfPossible() {
        guard !eventEdgeContinuationPending else { return }
        if activeEventEdgeBatch == nil, !pendingEventEdgeBatches.isEmpty {
            activeEventEdgeBatch = pendingEventEdgeBatches.removeFirst()
        }
        guard let batch = activeEventEdgeBatch else { return }
        guard gateOpen,
              state == .active,
              batch.generation == eventGeneration
        else {
            activeEventEdgeBatch = nil
            pendingEventEdgeBatches.removeAll()
            return
        }
        guard batch.nextIndex < batch.edges.count else {
            activeEventEdgeBatch = nil
            emitNextEventEdgeIfPossible()
            return
        }

        let edge = batch.edges[batch.nextIndex]
        batch.nextIndex += 1
        eventEdgeContinuationPending = true
        switch edge {
        case let .down(cid, button) where appliedCIDs.contains(cid):
            forwardedDownCIDs.insert(cid)
            buttonSink.emit(device: device, button: button, downNotUp: true)
        case let .up(cid, button) where appliedCIDs.contains(cid):
            forwardedDownCIDs.remove(cid)
            buttonSink.emit(device: device, button: button, downNotUp: false)
        default:
            break
        }

        DispatchQueue.main.async { [weak self, weak batch] in
            guard let self, let batch, self.activeEventEdgeBatch === batch else { return }
            self.eventEdgeContinuationPending = false
            self.emitNextEventEdgeIfPossible()
        }
    }

    private func closeEventGate() {
        gateOpen = false
        eventGeneration &+= 1
        pipeline.onEvent = nil
        activeEventEdgeBatch = nil
        pendingEventEdgeBatches.removeAll()
        eventEdgeContinuationPending = false
        _ = pressedSet.releaseAll()
    }

    private func installEventHandler() {
        let generation = eventGeneration
        pipeline.onEvent = { [weak self] inbound in
            self?.handlePipelineEvent(inbound, generation: generation)
        }
    }

    private func beginCancelBarrier(completion: @escaping () -> Void) {
        if let batch = cancelBatch, !batch.completed {
            batch.completions.append(completion)
            return
        }
        let cids = forwardedDownCIDs
        forwardedDownCIDs.removeAll()
        let batch = CancelBatch(cids: cids, completion: completion)
        cancelBatch = batch
        guard !cids.isEmpty else {
            DispatchQueue.main.async { [weak self, weak batch] in
                guard let self, let batch else { return }
                self.finishCancelBatch(batch)
            }
            return
        }
        for cid in cids.sorted() {
            guard let button = M720Profile.cidToButton[cid] else { continue }
            buttonSink.cancel(device: device, button: button) { [weak self, weak batch] in
                DispatchQueue.main.async { [weak self, weak batch] in
                    guard let self,
                          let batch,
                          self.cancelBatch === batch,
                          !batch.completed,
                          batch.remainingCIDs.remove(cid) != nil
                    else { return }
                    guard batch.remainingCIDs.isEmpty else { return }
                    self.finishCancelBatch(batch)
                }
            }
        }
    }

    private func finishCancelBatch(_ batch: CancelBatch) {
        guard cancelBatch === batch, !batch.completed else { return }
        batch.completed = true
        cancelBatch = nil
        let completions = batch.completions
        batch.completions.removeAll()
        for completion in completions {
            completion()
        }
    }

    private func requestRollbackCurrentState(
        index: Int,
        lifecycle: UInt64,
        operation: UInt64
    ) {
        guard continuationIsCurrent(
            lifecycle: lifecycle,
            operation: operation,
            state: .restoring
        ) else { return }
        guard index < rollbackCIDs.count else {
            finishRollback()
            return
        }
        guard let featureIndex = discoveredFeatureIndex else {
            enterInvalid(.protocol)
            return
        }
        let cid = rollbackCIDs[index]
        pipeline.perform(
            featureIndex: featureIndex,
            function: ReprogControlsV4.Function.getCidReporting.rawValue,
            parameters: bigEndian(cid)
        ) { [weak self] result in
            guard let self, self.continuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation,
                state: .restoring
            ) else { return }
            switch result {
            case let .success(parameters):
                do {
                    let current = try ReprogControlsV4.decodeReportingState(parameters)
                    guard current.cid == cid,
                          let original = self.originalStates[cid],
                          let intended = self.intendedStates[cid]
                    else {
                        self.enterInvalid(.protocol)
                        return
                    }
                    if self.externallyOwnedCIDs.contains(cid) {
                        self.rollbackHadConflict = true
                        self.requestRollbackCurrentState(
                            index: index + 1,
                            lifecycle: lifecycle,
                            operation: operation
                        )
                    } else if self.confirmedNotOwnedCIDs.contains(cid) ||
                        (self.preparedCIDs.contains(cid) && !self.touchedCIDs.contains(cid)) {
                        if current != original {
                            self.rollbackHadConflict = true
                        }
                        self.removeJournalEntry(
                            cid: cid,
                            nextIndex: index + 1,
                            lifecycle: lifecycle,
                            operation: operation
                        )
                    } else if current == original {
                        self.removeJournalEntry(
                            cid: cid,
                            nextIndex: index + 1,
                            lifecycle: lifecycle,
                            operation: operation
                        )
                    } else if current == intended {
                        self.persistRestoring(
                            cid: cid,
                            index: index,
                            lifecycle: lifecycle,
                            operation: operation
                        )
                    } else {
                        self.rollbackHadConflict = true
                        self.requestRollbackCurrentState(
                            index: index + 1,
                            lifecycle: lifecycle,
                            operation: operation
                        )
                    }
                } catch {
                    self.enterInvalid(.protocol)
                }
            case let .failure(error):
                self.enterInvalid(self.stableCode(for: error))
            }
        }
    }

    private func persistRestoring(
        cid: UInt16,
        index: Int,
        lifecycle: UInt64,
        operation: UInt64
    ) {
        journalRepository.mutateCID(
            for: deviceKey,
            cid: cid,
            mutation: { existing in
                guard var existing else {
                    throw M720JournalRepositoryError.notLoaded
                }
                existing.phase = .restoring
                return existing
            }
        ) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.continuationIsCurrent(
                    lifecycle: lifecycle,
                    operation: operation,
                    state: .restoring
                ) else { return }
                switch result {
                case let .success(journal):
                    self.journalSnapshot = journal
                    self.issueRestoreSet(
                        cid: cid,
                        index: index,
                        lifecycle: lifecycle,
                        operation: operation
                    )
                case let .failure(error):
                    self.handleJournalMutationFailure(
                        error,
                        lifecycle: lifecycle,
                        operation: operation,
                        state: .restoring
                    )
                }
            }
        }
    }

    private func issueRestoreSet(
        cid: UInt16,
        index: Int,
        lifecycle: UInt64,
        operation: UInt64
    ) {
        guard let featureIndex = discoveredFeatureIndex,
              let original = originalStates[cid]
        else {
            enterInvalid(.protocol)
            return
        }
        let parameters = ReprogControlsV4.setReportingParameters(
            cid: cid,
            diverted: original.isDiverted
        )
        pipeline.perform(
            featureIndex: featureIndex,
            function: ReprogControlsV4.Function.setCidReporting.rawValue,
            parameters: parameters
        ) { [weak self] result in
            guard let self, self.continuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation,
                state: .restoring
            ) else { return }
            switch result {
            case let .success(response):
                do {
                    try ReprogControlsV4.validateSetCidReportingEcho(
                        response,
                        matches: parameters
                    )
                    self.requestRestoreReadback(
                        cid: cid,
                        nextIndex: index + 1,
                        lifecycle: lifecycle,
                        operation: operation,
                        unresolvedCode: .protocol
                    )
                } catch {
                    self.requestRestoreReadback(
                        cid: cid,
                        nextIndex: index + 1,
                        lifecycle: lifecycle,
                        operation: operation,
                        unresolvedCode: .protocol
                    )
                }
            case let .failure(error):
                self.requestRestoreReadback(
                    cid: cid,
                    nextIndex: index + 1,
                    lifecycle: lifecycle,
                    operation: operation,
                    unresolvedCode: self.stableCode(for: error)
                )
            }
        }
    }

    private func requestRestoreReadback(
        cid: UInt16,
        nextIndex: Int,
        lifecycle: UInt64,
        operation: UInt64,
        unresolvedCode: M720StableErrorCode
    ) {
        guard let featureIndex = discoveredFeatureIndex else {
            enterInvalid(.protocol)
            return
        }
        pipeline.perform(
            featureIndex: featureIndex,
            function: ReprogControlsV4.Function.getCidReporting.rawValue,
            parameters: bigEndian(cid)
        ) { [weak self] result in
            guard let self, self.continuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation,
                state: .restoring
            ) else { return }
            switch result {
            case let .success(parameters):
                do {
                    let current = try ReprogControlsV4.decodeReportingState(parameters)
                    guard current.cid == cid,
                          let original = self.originalStates[cid],
                          let intended = self.intendedStates[cid]
                    else {
                        self.enterInvalid(.protocol)
                        return
                    }
                    if current == original {
                        self.removeJournalEntry(
                            cid: cid,
                            nextIndex: nextIndex,
                            lifecycle: lifecycle,
                            operation: operation
                        )
                    } else if current == intended {
                        self.enterInvalid(unresolvedCode)
                    } else {
                        self.externallyOwnedCIDs.insert(cid)
                        self.rollbackHadConflict = true
                        self.requestRollbackCurrentState(
                            index: nextIndex,
                            lifecycle: lifecycle,
                            operation: operation
                        )
                    }
                } catch {
                    self.enterInvalid(.protocol)
                }
            case let .failure(error):
                self.enterInvalid(self.stableCode(for: error))
            }
        }
    }

    private func removeJournalEntry(
        cid: UInt16,
        nextIndex: Int,
        lifecycle: UInt64,
        operation: UInt64
    ) {
        journalRepository.mutateCID(
            for: deviceKey,
            cid: cid,
            mutation: { _ in nil }
        ) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.continuationIsCurrent(
                    lifecycle: lifecycle,
                    operation: operation,
                    state: .restoring
                ) else { return }
                switch result {
                case let .success(journal):
                    self.journalSnapshot = journal
                    self.preparedCIDs.remove(cid)
                    self.touchedCIDs.remove(cid)
                    self.knownWrittenCIDs.remove(cid)
                    self.transactionAppliedCIDs.remove(cid)
                    self.confirmedNotOwnedCIDs.remove(cid)
                    self.requestRollbackCurrentState(
                        index: nextIndex,
                        lifecycle: lifecycle,
                        operation: operation
                    )
                case let .failure(error):
                    self.handleJournalMutationFailure(
                        error,
                        lifecycle: lifecycle,
                        operation: operation,
                        state: .restoring
                    )
                }
            }
        }
    }

    private func finishRollback() {
        appliedCIDs.removeAll()
        if rollbackHadConflict {
            if terminalIntent == .shutdown {
                finalizeShutdown(reason: .conflict)
                return
            }
            operationGeneration &+= 1
            transition(to: .conflict)
            return
        }
        switch rollbackOutcome {
        case .reconcilePolicy:
            transition(to: .nativeReady)
            if !requiredCIDs.isEmpty {
                beginTakeover()
            }
        case let .invalid(code):
            operationGeneration &+= 1
            transition(to: .invalid(code))
        case .shutdown:
            finalizeShutdown(reason: .cancelled)
        }
    }

    private func finalizeShutdown(reason: M720StableErrorCode = .cancelled) {
        guard terminalIntent == .shutdown, !terminalFinished else { return }
        terminalFinished = true
        pipeline.invalidate()
        transition(to: .invalid(reason))
        let waiters = shutdownWaiters
        shutdownWaiters.removeAll()
        for waiter in waiters { waiter() }
    }

    private func finalizeRemoval() {
        guard terminalIntent == .removal, !terminalFinished else { return }
        terminalFinished = true
        pipeline.invalidate()
        transition(to: .invalid(.disconnected))
        let shutdowns = shutdownWaiters
        let removals = removalWaiters
        shutdownWaiters.removeAll()
        removalWaiters.removeAll()
        for waiter in shutdowns { waiter() }
        for waiter in removals { waiter() }
    }

    private func resolveTouchedCIDAfterUncertainSet(
        index: Int,
        lifecycle: UInt64,
        operation: UInt64,
        policy: UInt64
    ) {
        guard takeoverContinuationIsCurrent(
            lifecycle: lifecycle,
            operation: operation,
            policy: policy
        ), let featureIndex = discoveredFeatureIndex else { return }
        let cid = frozenRequiredCIDs[index]
        pipeline.perform(
            featureIndex: featureIndex,
            function: ReprogControlsV4.Function.getCidReporting.rawValue,
            parameters: bigEndian(cid)
        ) { [weak self] result in
            guard let self, self.takeoverBaseContinuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation
            ) else { return }
            guard case let .success(parameters) = result else {
                guard self.takeoverPolicyIsCurrentOrBeginRollback(policy) else {
                    return
                }
                self.enterInvalid(.protocol)
                return
            }
            do {
                let current = try ReprogControlsV4.decodeReportingState(parameters)
                guard self.recordTakeoverReadbackOwnership(current, cid: cid) != nil else {
                    guard self.takeoverPolicyIsCurrentOrBeginRollback(policy) else {
                        return
                    }
                    self.beginRollbackAfterTakeoverFailure(.protocol)
                    return
                }
                guard self.takeoverPolicyIsCurrentOrBeginRollback(policy) else {
                    return
                }
                self.beginRollbackAfterTakeoverFailure(.protocol)
            } catch {
                guard self.takeoverPolicyIsCurrentOrBeginRollback(policy) else {
                    return
                }
                self.enterInvalid(.protocol)
            }
        }
    }

    private func recordTakeoverReadbackOwnership(
        _ current: HIDPPReportingState,
        cid: UInt16
    ) -> TakeoverReadbackOwnership? {
        guard current.cid == cid,
              let original = originalStates[cid],
              let intended = intendedStates[cid]
        else { return nil }
        if current == intended {
            knownWrittenCIDs.insert(cid)
            return .intended
        }
        if current == original {
            confirmedNotOwnedCIDs.insert(cid)
            return .original
        }
        externallyOwnedCIDs.insert(cid)
        return .external
    }

    private func takeoverContinuationIsCurrent(
        lifecycle: UInt64,
        operation: UInt64,
        policy: UInt64
    ) -> Bool {
        guard continuationIsCurrent(
            lifecycle: lifecycle,
            operation: operation,
            state: .takingOver
        ) else { return false }
        return takeoverPolicyIsCurrentOrBeginRollback(policy)
    }

    private func takeoverBaseContinuationIsCurrent(
        lifecycle: UInt64,
        operation: UInt64
    ) -> Bool {
        continuationIsCurrent(
            lifecycle: lifecycle,
            operation: operation,
            state: .takingOver
        )
    }

    private func takeoverPolicyIsCurrentOrBeginRollback(_ policy: UInt64) -> Bool {
        guard policyGeneration != policy else { return true }
        beginRollbackForPolicyReplacement()
        return false
    }

    private func journalEntriesForThisDevice() -> [UInt16: M720JournalCIDEntry] {
        guard let device = journalSnapshot.devices.first(where: { $0.key == deviceKey }) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: device.controls.map { ($0.cid, $0) })
    }

    private var requiredPolicyIsSupported: Bool {
        requiredCIDs.isSubset(of: Set(M720Profile.cidToButton.keys))
    }

    private func handleJournalMutationFailure(
        _ error: Error,
        lifecycle: UInt64,
        operation: UInt64,
        state expectedState: M720SessionState
    ) {
        guard error as? M720JournalStoreError == .uncertain else {
            if expectedState == .takingOver,
               !preparedCIDs
                .union(touchedCIDs)
                .union(knownWrittenCIDs)
                .union(transactionAppliedCIDs)
                .isEmpty {
                beginRollbackAfterTakeoverFailure(.protocol)
            } else {
                enterInvalid(.protocol)
            }
            return
        }
        journalRepository.reload { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.continuationIsCurrent(
                    lifecycle: lifecycle,
                    operation: operation,
                    state: expectedState
                ) else { return }
                if case let .success(journal) = result {
                    self.journalSnapshot = journal
                }
                self.enterInvalid(.protocol)
            }
        }
    }

    private func bigEndian(_ value: UInt16) -> [UInt8] {
        [UInt8(value >> 8), UInt8(value & 0x00FF)]
    }

    private func continuationIsCurrent(
        lifecycle: UInt64,
        operation: UInt64,
        state expectedState: M720SessionState
    ) -> Bool {
        lifecycleGeneration == lifecycle &&
            operationGeneration == operation &&
            state == expectedState
    }

    private func stableCode(for error: HIDPPRequestError) -> M720StableErrorCode {
        switch error {
        case .timeout:
            return .timeout
        case .transport:
            return .disconnected
        case .invalidated:
            return .cancelled
        case .malformed, .device, .softwareIDsExhausted:
            return .protocol
        }
    }

    private func enterInvalid(_ code: M720StableErrorCode) {
        operationGeneration &+= 1
        transition(to: .invalid(code))
        if terminalIntent == .shutdown {
            finalizeShutdown(reason: code)
        }
    }

    private func transition(to newState: M720SessionState) {
        guard state != newState else { return }
        state = newState
        let observer = onStateChange
        if let observer {
            DispatchQueue.main.async { observer(newState) }
        }
    }
}
