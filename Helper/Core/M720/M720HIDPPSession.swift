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
        commitPermission: M720JournalCommitPermission,
        completion: @escaping Completion
    )
    func removeDevice(
        for key: M720DeviceKey,
        expected: M720JournalDevice?,
        commitPermission: M720JournalCommitPermission,
        completion: @escaping Completion
    )
    func acknowledgeQuarantineWithFreshEmptyV1(
        commitPermission: M720JournalCommitPermission,
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
        case finishRecovery(Set<UInt16>)
        case conflict
        case invalid(M720StableErrorCode)
        case shutdown
    }

    private struct RecoveryClassification {
        let entry: M720JournalCIDEntry
        let current: HIDPPReportingState
        let decision: M720RecoveryDecision
    }

    private struct VerificationSnapshot {
        let lifecycle: UInt64
        let operation: UInt64
        let activeEpoch: UInt64
        let cids: [UInt16]
        let intended: [UInt16: HIDPPReportingState]
        let wakeAuthoritative: Bool
        let sleepCycle: UInt64?
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

    private enum RetryPath: Equatable {
        case knownFeature
        case fullRediscovery
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
    var pendingVerificationTimerCount: Int { verificationTimerTokens.count }
    var onStateChange: ((M720SessionState) -> Void)?

    private let device: Device
    private let pipeline: HIDPPRequestPipeline
    private let journalRepository: M720JournalCoordinating
    private let deviceKey: M720DeviceKey
    private var journalIdentityUsable: Bool
    private var completesInitialGetOnlyDiagnostics: Bool
    private let buttonSink: M720ButtonEventSink
    private let scheduler: HIDPPScheduler
    private let initialOwnershipAgentScan: () -> Bool
    private var operationGeneration: UInt64 = 0
    private var policyGeneration: UInt64 = 0
    private var started = false
    private var discoveredFeatureIndex: UInt8?
    private var discoveredControls: [UInt16: HIDPPControlInfo] = [:]
    private var discoveredCurrentStates: [UInt16: HIDPPReportingState] = [:]
    private var originalStates: [UInt16: HIDPPReportingState] = [:]
    private var journalSnapshot = M720OwnershipJournal.emptyV1
    private var journalTrustQuarantined = false
    private var explicitRetryRequired = false
    private var retryInProgress = false
    private var retryPath: RetryPath?
    private var retryBaselineStates: [UInt16: HIDPPReportingState] = [:]
    private var recoveryEntries: [M720JournalCIDEntry] = []
    private var recoveryCurrentStates: [UInt16: HIDPPReportingState] = [:]
    private var recoveryClassifications: [RecoveryClassification] = []
    private var recoveryOwnedCIDs: Set<UInt16> = []
    private var recoveryHadConflict = false
    private var recoveryInProgress = false
    private var takeoverSeedCIDs: Set<UInt16> = []
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
    private var rollbackResolvedCIDs: Set<UInt16> = []
    private var rollbackHadConflict = false
    private var rollbackOutcome: RollbackOutcome = .reconcilePolicy
    private var recoveryRollbackActive = false
    private var terminalIntent: TerminalIntent = .none
    private var shutdownWaiters: [() -> Void] = []
    private var removalWaiters: [() -> Void] = []
    private var terminalFinalizationStarted = false
    private var terminalFinished = false
    private var terminalShutdownReason: M720StableErrorCode = .cancelled
    private let shutdownJournalCommitPermission = M720JournalCommitPermission()
    private var nextShutdownGeneration: UInt64 = 0
    private var activeShutdownGeneration: UInt64?
    private var fencedShutdownGeneration: UInt64?
    private var activeEpoch: UInt64 = 0
    private var verificationCancellations: [UInt64: HIDPPCancellation] = [:]
    private var verificationTimerTokens: Set<UInt64> = []
    private var nextVerificationTimerToken: UInt64 = 0
    private var lastVerificationSequenceStart = -Double.infinity
    private var verificationInFlight = false
    private var pendingVerification: VerificationSnapshot?
    private var sleepSuspended = false
    private var wakeRequested = false
    private var sleepCancelCompleted = true
    private var wakeReadbackCompleted = true
    private var sleepCycleGeneration: UInt64 = 0
    private var activeSleepCycle: UInt64?
    private var didScanInitialOwnershipAgents = false
    private var diagnosticSentCounts: [UInt16: UInt64] = [:]
    private var diagnosticRecentRequests: [M720DiagnosticRequestIdentity] = []

    init(
        device: Device,
        pipeline: HIDPPRequestPipeline,
        journalRepository: M720JournalCoordinating,
        deviceKey: M720DeviceKey,
        journalIdentityUsable: Bool,
        buttonSink: M720ButtonEventSink = M720ButtonsEventSink(),
        scheduler: HIDPPScheduler = DispatchHIDPPScheduler(),
        initialOwnershipAgentScan: @escaping () -> Bool = { false }
    ) {
        self.device = device
        self.pipeline = pipeline
        self.journalRepository = journalRepository
        self.deviceKey = deviceKey
        self.journalIdentityUsable = journalIdentityUsable
        self.completesInitialGetOnlyDiagnostics =
            !journalIdentityUsable || deviceKey.serialNumber.isEmpty
        self.buttonSink = buttonSink
        self.scheduler = scheduler
        self.initialOwnershipAgentScan = initialOwnershipAgentScan
        pipeline.onRequestSent = { [weak self] request in
            self?.recordDiagnosticRequest(request)
        }
    }

    func diagnosticSnapshot(deviceToken: UUID) -> M720DiagnosticSessionSnapshot {
        precondition(Thread.isMainThread, "M720 session diagnostics must be read on the main thread")
        let stateName: M720SessionStateName
        switch state {
        case .discovering: stateName = .discovering
        case .nativeReady: stateName = .nativeReady
        case .takingOver: stateName = .takingOver
        case .active: stateName = .active
        case .restoring: stateName = .restoring
        case .conflict: stateName = .conflict
        case .invalid: stateName = .invalid
        }
        let counts = diagnosticSentCounts.map { key, count in
            M720DiagnosticSentCount(
                feature: UInt8(key >> 8),
                function: UInt8(key & 0xFF),
                count: count
            )
        }
        return M720DiagnosticSessionSnapshot(
            deviceToken: deviceToken,
            state: stateName,
            generation: lifecycleGeneration,
            requiredCIDs: requiredCIDs,
            appliedCIDs: appliedCIDs,
            pressedCIDs: Set(pressedSet.orderedCIDs),
            sentCounts: counts,
            recentRequests: diagnosticRecentRequests
        )
    }

    private func recordDiagnosticRequest(_ request: HIDPPSentRequest) {
        precondition(Thread.isMainThread, "M720 request diagnostics must mutate on the main thread")
        let key = UInt16(request.identity.featureIndex) << 8 |
            UInt16(request.identity.function)
        diagnosticSentCounts[key, default: 0] &+= 1

        let cid: UInt16?
        switch request.identity.function {
        case ReprogControlsV4.Function.getCidReporting.rawValue,
             ReprogControlsV4.Function.setCidReporting.rawValue where request.parameters.count >= 2:
            cid = UInt16(request.parameters[0]) << 8 | UInt16(request.parameters[1])
        default:
            cid = nil
        }
        diagnosticRecentRequests.append(M720DiagnosticRequestIdentity(
            feature: request.identity.featureIndex,
            function: request.identity.function,
            cid: cid,
            generation: request.generation
        ))
        let overflow = diagnosticRecentRequests.count -
            M720DiagnosticSessionSnapshot.maximumRecentRequestCount
        if overflow > 0 {
            diagnosticRecentRequests.removeFirst(overflow)
        }
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
                        self.recoveryInProgress = journal.devices
                            .first { $0.key == self.deviceKey }?
                            .controls.isEmpty == false
                        self.requestRootFeature(
                            lifecycle: lifecycle,
                            operation: operation
                        )
                    case let .failure(error):
                        if self.isQuarantinedJournalError(error) {
                            self.journalTrustQuarantined = true
                            self.explicitRetryRequired = true
                            self.journalSnapshot = .emptyV1
                            self.recoveryInProgress = false
                            self.requestRootFeature(
                                lifecycle: lifecycle,
                                operation: operation
                            )
                        } else {
                            self.enterInvalid(.protocol)
                        }
                    }
                }
            }
        }
    }

    func setRequiredCIDs(_ cids: Set<UInt16>) {
        if Thread.isMainThread {
            setRequiredCIDsOnMain(cids)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.setRequiredCIDsOnMain(cids)
            }
        }
    }

    private func setRequiredCIDsOnMain(_ cids: Set<UInt16>) {
        guard terminalIntent == .none else { return }
        policyGeneration &+= 1
        requiredCIDs = cids
        guard started else { return }
        if sleepSuspended {
            guard wakeRequested, state == .active else { return }
            if !requiredPolicyIsSupported {
                beginRollback(outcome: .invalid(.unsupported))
            } else if cids != appliedCIDs {
                self.beginRollbackForPolicyReplacement()
            }
            return
        }
        if state == .discovering, completesInitialGetOnlyDiagnostics {
            return
        }
        guard requiredPolicyIsSupported else {
            switch state {
            case .takingOver:
                // The in-flight boundary may still durably record ownership.
                // Its policy-token continuation will include that CID in rollback.
                break
            case .active:
                beginRollback(outcome: .invalid(.unsupported))
            case .restoring:
                rollbackOutcome = .invalid(.unsupported)
                refreshRecoveryRollbackPlan()
            case .discovering, .nativeReady, .conflict, .invalid:
                enterInvalid(.unsupported)
            }
            return
        }
        switch state {
        case .nativeReady where !cids.isEmpty:
            if explicitRetryRequired {
                transition(to: .conflict)
            } else {
                beginTakeover()
            }
        case .conflict where cids.isEmpty:
            transition(to: .nativeReady)
        case .active where cids == appliedCIDs:
            break
        case .active:
            beginRollbackForPolicyReplacement()
        case .restoring where recoveryRollbackActive:
            refreshRecoveryRollbackPlan()
        default:
            break
        }
    }

    func markJournalIdentityUnusable() {
        if Thread.isMainThread {
            markJournalIdentityUnusableOnMain()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.markJournalIdentityUnusableOnMain()
            }
        }
    }

    private func markJournalIdentityUnusableOnMain() {
        guard journalIdentityUsable,
              terminalIntent == .none,
              !terminalFinished
        else { return }

        journalIdentityUsable = false
        policyGeneration &+= 1

        switch state {
        case .discovering:
            guard started else {
                completesInitialGetOnlyDiagnostics = true
                return
            }
            operationGeneration &+= 1
            pipeline.beginNewLifecycle()
            enterInvalid(.unsupported)
        case .active:
            beginRollback(outcome: .invalid(.unsupported))
        case .takingOver:
            // A Set may already be in flight. Its policy-generation guard
            // classifies the boundary before rolling back every touched CID.
            break
        case .restoring:
            rollbackOutcome = .invalid(.unsupported)
            refreshRecoveryRollbackPlan()
        case .nativeReady, .conflict, .invalid:
            enterInvalid(.unsupported)
        }
    }

    @discardableResult
    func retryAfterConflict(requestID _: UUID?) -> Bool {
        guard Thread.isMainThread,
              terminalIntent == .none,
              !retryInProgress
        else { return false }
        let path: RetryPath
        switch state {
        case .conflict:
            path = discoveredFeatureIndex == nil ? .fullRediscovery : .knownFeature
        case .nativeReady where explicitRetryRequired:
            path = discoveredFeatureIndex == nil ? .fullRediscovery : .knownFeature
        case .invalid:
            path = .fullRediscovery
        default:
            return false
        }

        closeEventGate()
        lifecycleGeneration &+= 1
        operationGeneration &+= 1
        pipeline.beginNewLifecycle()
        retryInProgress = true
        retryPath = path
        retryBaselineStates.removeAll(keepingCapacity: true)
        resetOwnershipTransactionForRetry()
        transition(to: .discovering)
        let lifecycle = lifecycleGeneration
        let operation = operationGeneration
        switch path {
        case .knownFeature:
            requestRetryBaseline(
                index: 0,
                targetCIDs: M720Profile.cidToButton.keys.sorted(),
                lifecycle: lifecycle,
                operation: operation
            )
        case .fullRediscovery:
            discoveredFeatureIndex = nil
            discoveredControls.removeAll(keepingCapacity: true)
            discoveredCurrentStates.removeAll(keepingCapacity: true)
            originalStates.removeAll(keepingCapacity: true)
            intendedStates.removeAll(keepingCapacity: true)
            reloadJournalForFullRediscoveryRetry(
                lifecycle: lifecycle,
                operation: operation
            )
        }
        return true
    }

    func verifyOwnership() {
        DispatchQueue.main.async { [weak self] in
            self?.enqueueVerificationCheck()
        }
    }

    func knownOwnershipAgentDidLaunch() {
        DispatchQueue.main.async { [weak self] in
            self?.startVerificationSequence()
        }
    }

    func reconcileAfterWake() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.state == .active,
                  self.sleepSuspended,
                  !self.wakeRequested
            else { return }
            self.wakeRequested = true
            self.activeEpoch &+= 1
            self.cancelScheduledVerifications()
            self.verificationInFlight = false
            self.pendingVerification = nil
            self.lastVerificationSequenceStart = -Double.infinity
            guard self.requiredPolicyIsSupported else {
                self.beginRollback(outcome: .invalid(.unsupported))
                return
            }
            guard self.requiredCIDs == self.appliedCIDs else {
                self.beginRollbackForPolicyReplacement()
                return
            }
            guard !self.requiredCIDs.isEmpty else {
                self.wakeReadbackCompleted = true
                self.maybeCompleteWakeOverlay(sleepCycle: self.activeSleepCycle)
                return
            }
            self.startVerificationSequence(allowDuringWake: true)
        }
    }

    func prepareForSleep(completion: @escaping () -> Void) {
        let deferredCompletion = {
            DispatchQueue.main.async(execute: completion)
        }
        if Thread.isMainThread {
            prepareForSleepOnMain(completion: deferredCompletion)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    deferredCompletion()
                    return
                }
                self.prepareForSleepOnMain(completion: deferredCompletion)
            }
        }
    }

    private func prepareForSleepOnMain(completion: @escaping () -> Void) {
        if sleepSuspended, wakeRequested, state == .active {
            beginActiveSleepCycle(completion: completion)
            return
        }
        if cancelBatch != nil {
            beginCancelBarrier(completion: completion)
            return
        }
        if sleepSuspended {
            completion()
            return
        }
        guard state == .active else {
            completion()
            return
        }
        beginActiveSleepCycle(completion: completion)
    }

    private func beginActiveSleepCycle(completion: @escaping () -> Void) {
        sleepSuspended = true
        wakeRequested = false
        sleepCancelCompleted = false
        wakeReadbackCompleted = false
        sleepCycleGeneration &+= 1
        let sleepCycle = sleepCycleGeneration
        activeSleepCycle = sleepCycle
        closeEventGate(preservingWakeOverlay: true)
        operationGeneration &+= 1
        pipeline.beginNewLifecycle()
        beginCancelBarrier { [weak self] in
            guard let self else {
                completion()
                return
            }
            if self.activeSleepCycle == sleepCycle {
                self.sleepCancelCompleted = true
                if self.wakeRequested,
                   self.wakeReadbackCompleted,
                   !self.verificationInFlight,
                   self.pendingVerification == nil {
                    self.wakeReadbackCompleted = false
                    self.enqueueVerificationCheck(wakeAuthoritative: true)
                }
                self.maybeCompleteWakeOverlay(sleepCycle: sleepCycle)
            }
            completion()
        }
    }

    func shutdown(completion: @escaping () -> Void) {
        if Thread.isMainThread {
            shutdownOnMain(completion: completion)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    completion()
                    return
                }
                self.shutdownOnMain(completion: completion)
            }
        }
    }

    private func shutdownOnMain(completion: @escaping () -> Void) {
        if terminalFinished {
            DispatchQueue.main.async(execute: completion)
            return
        }
        _ = ensureActiveShutdownGeneration()
        shutdownWaiters.append(completion)
        guard terminalIntent == .none else { return }
        terminalIntent = .shutdown
        requiredCIDs.removeAll()
        policyGeneration &+= 1
        switch state {
        case .active:
            beginRollback(outcome: .shutdown)
        case .takingOver:
            break
        case .restoring:
            rollbackOutcome = .shutdown
            refreshRecoveryRollbackPlan()
        case .discovering where recoveryInProgress:
            break
        case .discovering, .nativeReady:
            finalizeShutdown()
        case .conflict:
            finalizeShutdown(reason: .conflict)
        case let .invalid(code):
            finalizeShutdown(reason: code)
        }
    }

    func shutdownDeadlineReached() {
        precondition(Thread.isMainThread, "M720 shutdown deadline must run on the main thread")
        guard terminalIntent != .none else { return }
        let generation = ensureActiveShutdownGeneration()
        guard fencedShutdownGeneration != generation else { return }
        fencedShutdownGeneration = generation
        shutdownJournalCommitPermission.close()
    }

    private func ensureActiveShutdownGeneration() -> UInt64 {
        if let activeShutdownGeneration { return activeShutdownGeneration }
        nextShutdownGeneration &+= 1
        activeShutdownGeneration = nextShutdownGeneration
        return nextShutdownGeneration
    }

    func invalidateForRemoval(completion: @escaping () -> Void) {
        if Thread.isMainThread {
            invalidateForRemovalOnMain(completion: completion)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    completion()
                    return
                }
                self.invalidateForRemovalOnMain(completion: completion)
            }
        }
    }

    private func invalidateForRemovalOnMain(completion: @escaping () -> Void) {
        if terminalFinished {
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    completion()
                    return
                }
                if self.terminalIntent == .shutdown {
                    self.terminalIntent = .removal
                    self.transition(to: .invalid(.disconnected))
                }
                completion()
            }
            return
        }
        removalWaiters.append(completion)
        guard terminalIntent != .removal else { return }
        terminalIntent = .removal
        closeEventGate()
        lifecycleGeneration &+= 1
        operationGeneration &+= 1
        pipeline.beginNewLifecycle()
        beginCancelBarrier { [weak self] in self?.finalizeRemoval() }
    }

    private func resetOwnershipTransactionForRetry() {
        recoveryEntries.removeAll()
        recoveryCurrentStates.removeAll()
        recoveryClassifications.removeAll()
        recoveryOwnedCIDs.removeAll()
        recoveryHadConflict = false
        recoveryInProgress = false
        recoveryRollbackActive = false
        takeoverSeedCIDs.removeAll()
        frozenRequiredCIDs.removeAll()
        takeoverPreflightStates.removeAll()
        preparedCIDs.removeAll()
        touchedCIDs.removeAll()
        knownWrittenCIDs.removeAll()
        transactionAppliedCIDs.removeAll()
        appliedCIDs.removeAll()
        externallyOwnedCIDs.removeAll()
        confirmedNotOwnedCIDs.removeAll()
        rollbackCIDs.removeAll()
        rollbackResolvedCIDs.removeAll()
        rollbackHadConflict = false
    }

    private func requestRetryBaseline(
        index: Int,
        targetCIDs: [UInt16],
        lifecycle: UInt64,
        operation: UInt64
    ) {
        guard continuationIsCurrent(
            lifecycle: lifecycle,
            operation: operation,
            state: .discovering
        ), retryInProgress, retryPath == .knownFeature else { return }
        guard index < targetCIDs.count else {
            finishRetryBaseline(
                retryBaselineStates,
                lifecycle: lifecycle,
                operation: operation
            )
            return
        }
        guard let featureIndex = discoveredFeatureIndex else {
            enterInvalid(.protocol)
            return
        }
        let cid = targetCIDs[index]
        pipeline.perform(
            featureIndex: featureIndex,
            function: ReprogControlsV4.Function.getCidReporting.rawValue,
            parameters: bigEndian(cid)
        ) { [weak self] result in
            guard let self, self.continuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation,
                state: .discovering
            ), self.retryInProgress, self.retryPath == .knownFeature else { return }
            switch result {
            case let .success(parameters):
                do {
                    let current = try ReprogControlsV4.decodeReportingState(parameters)
                    guard current.cid == cid else {
                        self.enterInvalid(.protocol)
                        return
                    }
                    self.retryBaselineStates[cid] = current
                    self.requestRetryBaseline(
                        index: index + 1,
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

    private func finishRetryBaseline(
        _ states: [UInt16: HIDPPReportingState],
        lifecycle: UInt64,
        operation: UInt64
    ) {
        guard continuationIsCurrent(
            lifecycle: lifecycle,
            operation: operation,
            state: .discovering
        ), retryInProgress else { return }
        let targets = Set(M720Profile.cidToButton.keys)
        guard journalIdentityUsable,
              !deviceKey.serialNumber.isEmpty,
              requiredPolicyIsSupported
        else {
            enterInvalid(.unsupported)
            return
        }
        guard Set(states.keys) == targets,
              states.allSatisfy({ $0.value.cid == $0.key })
        else {
            rejectRetryBaseline()
            return
        }
        if states.contains(where: { $0.value.isDiverted }) {
            guard canResetStaleDiversions(states),
                  !initialOwnershipAgentScan()
            else {
                rejectRetryBaseline()
                return
            }
            let cleanStates = states.mapValues { $0.changingDivert(to: false) }
            requestStaleDiversionReset(
                index: 0,
                targetCIDs: targets.sorted(),
                currentStates: states,
                cleanStates: cleanStates,
                lifecycle: lifecycle,
                operation: operation
            )
            return
        }

        if journalTrustQuarantined {
            journalRepository.acknowledgeQuarantineWithFreshEmptyV1(
                commitPermission: shutdownJournalCommitPermission,
                completion: { [weak self] result in
                    self?.handleRetryJournalPreparation(
                        result,
                        states: states,
                        lifecycle: lifecycle,
                        operation: operation,
                        canRecoverAmbiguousQuarantineAcknowledgement: true
                    )
                }
            )
        } else {
            let expected = journalSnapshot.devices.first { $0.key == deviceKey }
            journalRepository.removeDevice(
                for: deviceKey,
                expected: expected,
                commitPermission: shutdownJournalCommitPermission,
                completion: { [weak self] result in
                    self?.handleRetryJournalPreparation(
                        result,
                        states: states,
                        lifecycle: lifecycle,
                        operation: operation,
                        canRecoverAmbiguousQuarantineAcknowledgement: false
                    )
                }
            )
        }
    }

    private func canResetStaleDiversions(
        _ states: [UInt16: HIDPPReportingState]
    ) -> Bool {
        guard retryPath == .knownFeature,
              !requiredCIDs.isEmpty,
              !journalTrustQuarantined,
              journalEntriesForThisDevice().isEmpty
        else { return false }
        return states.allSatisfy { cid, state in
            state.remappedCID == cid
        }
    }

    private func requestStaleDiversionReset(
        index: Int,
        targetCIDs: [UInt16],
        currentStates: [UInt16: HIDPPReportingState],
        cleanStates: [UInt16: HIDPPReportingState],
        lifecycle: UInt64,
        operation: UInt64
    ) {
        guard continuationIsCurrent(
            lifecycle: lifecycle,
            operation: operation,
            state: .discovering
        ), retryInProgress else { return }
        guard !requiredCIDs.isEmpty else {
            rejectRetryBaseline()
            return
        }
        guard index < targetCIDs.count else {
            guard !initialOwnershipAgentScan() else {
                rejectRetryBaseline()
                return
            }
            finishRetryBaseline(
                cleanStates,
                lifecycle: lifecycle,
                operation: operation
            )
            return
        }
        let cid = targetCIDs[index]
        guard let current = currentStates[cid], current.isDiverted else {
            requestStaleDiversionReset(
                index: index + 1,
                targetCIDs: targetCIDs,
                currentStates: currentStates,
                cleanStates: cleanStates,
                lifecycle: lifecycle,
                operation: operation
            )
            return
        }
        guard !initialOwnershipAgentScan(),
              let featureIndex = discoveredFeatureIndex
        else {
            rejectRetryBaseline()
            return
        }

        // Retry is an explicit user authorization boundary. A stale diversion can
        // be cleared without a journal because interruption leaves the control in
        // its native state; every Set is followed by authoritative readback before
        // the regular journaled takeover is allowed to begin.
        let parameters = ReprogControlsV4.setReportingParameters(
            cid: cid,
            diverted: false
        )
        pipeline.perform(
            featureIndex: featureIndex,
            function: ReprogControlsV4.Function.setCidReporting.rawValue,
            parameters: parameters
        ) { [weak self] _ in
            guard let self, self.continuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation,
                state: .discovering
            ), self.retryInProgress else { return }
            self.requestStaleDiversionResetReadback(
                cid: cid,
                nextIndex: index + 1,
                targetCIDs: targetCIDs,
                currentStates: currentStates,
                cleanStates: cleanStates,
                lifecycle: lifecycle,
                operation: operation
            )
        }
    }

    private func requestStaleDiversionResetReadback(
        cid: UInt16,
        nextIndex: Int,
        targetCIDs: [UInt16],
        currentStates: [UInt16: HIDPPReportingState],
        cleanStates: [UInt16: HIDPPReportingState],
        lifecycle: UInt64,
        operation: UInt64
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
                state: .discovering
            ), self.retryInProgress else { return }
            switch result {
            case let .success(parameters):
                do {
                    let readback = try ReprogControlsV4.decodeReportingState(parameters)
                    guard readback.cid == cid else {
                        self.enterInvalid(.protocol)
                        return
                    }
                    guard readback == cleanStates[cid] else {
                        self.rejectRetryBaseline()
                        return
                    }
                    self.requestStaleDiversionReset(
                        index: nextIndex,
                        targetCIDs: targetCIDs,
                        currentStates: currentStates,
                        cleanStates: cleanStates,
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

    private func rejectRetryBaseline() {
        explicitRetryRequired = true
        transition(to: requiredCIDs.isEmpty ? .nativeReady : .conflict)
    }

    private func reloadJournalForFullRediscoveryRetry(
        lifecycle: UInt64,
        operation: UInt64
    ) {
        journalRepository.reload { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.continuationIsCurrent(
                    lifecycle: lifecycle,
                    operation: operation,
                    state: .discovering
                ), self.retryInProgress, self.retryPath == .fullRediscovery else { return }
                switch result {
                case let .success(journal):
                    self.journalSnapshot = journal
                    self.journalTrustQuarantined = false
                    self.recoveryInProgress = journal.devices
                        .first { $0.key == self.deviceKey }?
                        .controls.isEmpty == false
                    self.requestRootFeature(lifecycle: lifecycle, operation: operation)
                case let .failure(error) where self.isQuarantinedJournalError(error):
                    self.journalSnapshot = .emptyV1
                    self.journalTrustQuarantined = true
                    self.explicitRetryRequired = true
                    self.requestRootFeature(lifecycle: lifecycle, operation: operation)
                case .failure:
                    self.enterInvalid(.protocol)
                }
            }
        }
    }

    private func handleRetryJournalPreparation(
        _ result: Result<M720OwnershipJournal, Error>,
        states: [UInt16: HIDPPReportingState],
        lifecycle: UInt64,
        operation: UInt64,
        canRecoverAmbiguousQuarantineAcknowledgement: Bool
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.continuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation,
                state: .discovering
            ), self.retryInProgress else { return }
            switch result {
            case let .success(journal):
                self.acceptRetryBaseline(
                    states,
                    journal: journal,
                    lifecycle: lifecycle,
                    operation: operation
                )
            case let .failure(error):
                let storeError = error as? M720JournalStoreError
                if canRecoverAmbiguousQuarantineAcknowledgement,
                   (storeError == .notQuarantined || storeError == .uncertain) {
                    self.recoverAfterAmbiguousQuarantineAcknowledgement(
                        states: states,
                        lifecycle: lifecycle,
                        operation: operation
                    )
                } else {
                    self.enterInvalid(.protocol)
                }
            }
        }
    }

    private func recoverAfterAmbiguousQuarantineAcknowledgement(
        states: [UInt16: HIDPPReportingState],
        lifecycle: UInt64,
        operation: UInt64
    ) {
        journalRepository.reload { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.continuationIsCurrent(
                    lifecycle: lifecycle,
                    operation: operation,
                    state: .discovering
                ), self.retryInProgress else { return }
                guard case let .success(journal) = result else {
                    self.enterInvalid(.protocol)
                    return
                }
                self.journalSnapshot = journal
                self.journalTrustQuarantined = false
                guard !journal.devices.contains(where: { $0.key == self.deviceKey }) else {
                    self.enterInvalid(.protocol)
                    return
                }
                self.journalRepository.removeDevice(
                    for: self.deviceKey,
                    expected: nil,
                    commitPermission: self.shutdownJournalCommitPermission,
                    completion: { [weak self] result in
                        self?.handleRetryJournalPreparation(
                            result,
                            states: states,
                            lifecycle: lifecycle,
                            operation: operation,
                            canRecoverAmbiguousQuarantineAcknowledgement: false
                        )
                    }
                )
            }
        }
    }

    private func acceptRetryBaseline(
        _ states: [UInt16: HIDPPReportingState],
        journal: M720OwnershipJournal,
        lifecycle: UInt64,
        operation: UInt64
    ) {
        guard continuationIsCurrent(
            lifecycle: lifecycle,
            operation: operation,
            state: .discovering
        ), retryInProgress else { return }
        journalSnapshot = journal
        journalTrustQuarantined = false
        explicitRetryRequired = false
        originalStates = states
        discoveredCurrentStates = states
        intendedStates.removeAll(keepingCapacity: true)
        transition(to: .nativeReady)
        if !requiredCIDs.isEmpty {
            beginTakeover()
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
        guard requiredPolicyIsSupported else {
            enterInvalid(.unsupported)
            return
        }
        if retryInProgress, retryPath == .fullRediscovery {
            if !journalTrustQuarantined,
               !explicitRetryRequired,
               beginMatchingJournalRecoveryIfNeeded() {
                return
            }
            finishRetryBaseline(
                discoveredCurrentStates,
                lifecycle: lifecycleGeneration,
                operation: operationGeneration
            )
            return
        }
        if journalTrustQuarantined {
            recoveryInProgress = false
            explicitRetryRequired = true
            transition(to: requiredCIDs.isEmpty ? .nativeReady : .conflict)
            return
        }
        if beginMatchingJournalRecoveryIfNeeded() { return }
        finishDiscoveryWithoutRecovery()
    }

    @discardableResult
    private func beginMatchingJournalRecoveryIfNeeded() -> Bool {
        let entries = journalEntriesForThisDevice().values.sorted { $0.cid < $1.cid }
        guard !entries.isEmpty else {
            recoveryInProgress = false
            return false
        }
        for entry in entries {
            originalStates[entry.cid] = entry.original
            intendedStates[entry.cid] = entry.intended
        }
        recoveryEntries = entries
        recoveryInProgress = true
        recoveryCurrentStates.removeAll(keepingCapacity: true)
        recoveryClassifications.removeAll(keepingCapacity: true)
        recoveryOwnedCIDs.removeAll()
        recoveryHadConflict = false
        requestRecoveryCurrentState(
            index: 0,
            lifecycle: lifecycleGeneration,
            operation: operationGeneration
        )
        return true
    }

    private func finishDiscoveryWithoutRecovery() {
        transition(to: .nativeReady)
        if !requiredCIDs.isEmpty {
            beginTakeover()
        }
    }

    private func requestRecoveryCurrentState(
        index: Int,
        lifecycle: UInt64,
        operation: UInt64
    ) {
        guard continuationIsCurrent(
            lifecycle: lifecycle,
            operation: operation,
            state: .discovering
        ) else { return }
        guard index < recoveryEntries.count else {
            classifyRecoverySnapshot()
            applyRecoveryMutation(
                index: 0,
                lifecycle: lifecycle,
                operation: operation
            )
            return
        }
        guard let featureIndex = discoveredFeatureIndex else {
            enterInvalid(.protocol)
            return
        }
        let entry = recoveryEntries[index]
        pipeline.perform(
            featureIndex: featureIndex,
            function: ReprogControlsV4.Function.getCidReporting.rawValue,
            parameters: bigEndian(entry.cid)
        ) { [weak self] result in
            guard let self, self.continuationIsCurrent(
                lifecycle: lifecycle,
                operation: operation,
                state: .discovering
            ) else { return }
            switch result {
            case let .success(parameters):
                do {
                    let current = try ReprogControlsV4.decodeReportingState(parameters)
                    guard current.cid == entry.cid else {
                        self.enterInvalid(.protocol)
                        return
                    }
                    self.recoveryCurrentStates[entry.cid] = current
                    self.requestRecoveryCurrentState(
                        index: index + 1,
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

    private func classifyRecoverySnapshot() {
        recoveryClassifications = recoveryEntries.compactMap { entry in
            guard let current = recoveryCurrentStates[entry.cid] else { return nil }
            let decision = M720OwnershipRecovery.decide(
                entry: entry,
                current: current,
                policyRequiresCapture: requiredCIDs.contains(entry.cid)
            )
            if current == entry.intended {
                recoveryOwnedCIDs.insert(entry.cid)
            }
            if decision == .conflict {
                recoveryHadConflict = true
                externallyOwnedCIDs.insert(entry.cid)
            }
            return RecoveryClassification(entry: entry, current: current, decision: decision)
        }
        if recoveryClassifications.count != recoveryEntries.count {
            enterInvalid(.protocol)
        }
    }

    private func applyRecoveryMutation(
        index: Int,
        lifecycle: UInt64,
        operation: UInt64
    ) {
        guard continuationIsCurrent(
            lifecycle: lifecycle,
            operation: operation,
            state: .discovering
        ) else { return }
        guard index < recoveryClassifications.count else {
            finishRecoveryClassification()
            return
        }
        let classification = recoveryClassifications[index]
        let mutation: ((M720JournalCIDEntry?) throws -> M720JournalCIDEntry?)?
        switch classification.decision {
        case .clearThenReconcile:
            mutation = { existing in
                guard existing == classification.entry else {
                    throw M720JournalRepositoryError.mismatchedCID
                }
                return nil
            }
        case .setAppliedThenKeep, .setAppliedThenRestore:
            mutation = { existing in
                guard var existing, existing == classification.entry else {
                    throw M720JournalRepositoryError.mismatchedCID
                }
                existing.phase = .applied
                return existing
            }
        case .keepApplied, .restore, .conflict:
            mutation = nil
        }
        guard let mutation else {
            applyRecoveryMutation(
                index: index + 1,
                lifecycle: lifecycle,
                operation: operation
            )
            return
        }
        journalRepository.mutateCID(
            for: deviceKey,
            cid: classification.entry.cid,
            mutation: mutation,
            commitPermission: shutdownJournalCommitPermission
        ) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.continuationIsCurrent(
                    lifecycle: lifecycle,
                    operation: operation,
                    state: .discovering
                ) else { return }
                switch result {
                case let .success(journal):
                    self.journalSnapshot = journal
                    self.applyRecoveryMutation(
                        index: index + 1,
                        lifecycle: lifecycle,
                        operation: operation
                    )
                case let .failure(error):
                    self.handleJournalMutationFailure(
                        error,
                        lifecycle: lifecycle,
                        operation: operation,
                        state: .discovering
                    )
                }
            }
        }
    }

    private func finishRecoveryClassification() {
        let kept = recoveryHadConflict
            ? Set<UInt16>()
            : recoveryOwnedCIDs.intersection(requiredCIDs)
        let restore = recoveryHadConflict
            ? recoveryOwnedCIDs
            : recoveryOwnedCIDs.subtracting(kept)
        takeoverSeedCIDs = kept
        guard !restore.isEmpty else {
            recoveryInProgress = false
            if recoveryHadConflict {
                if terminalIntent == .shutdown {
                    finalizeShutdown(reason: .conflict)
                } else {
                    operationGeneration &+= 1
                    transition(to: .conflict)
                }
            } else if terminalIntent == .shutdown {
                finalizeShutdown()
            } else {
                finishRecoveredOwnership(kept)
            }
            return
        }

        closeEventGate()
        operationGeneration &+= 1
        let lifecycle = lifecycleGeneration
        let operation = operationGeneration
        appliedCIDs = recoveryOwnedCIDs
        knownWrittenCIDs = recoveryOwnedCIDs
        rollbackCIDs = restore.sorted()
        rollbackResolvedCIDs.removeAll()
        rollbackHadConflict = recoveryHadConflict
        rollbackOutcome = terminalIntent == .shutdown ? .shutdown : .finishRecovery(kept)
        recoveryRollbackActive = true
        refreshRecoveryRollbackPlan()
        recoveryInProgress = false
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

    private func finishRecoveredOwnership(_ kept: Set<UInt16>) {
        appliedCIDs = kept
        takeoverSeedCIDs = kept
        if requiredCIDs.isEmpty {
            transition(to: .nativeReady)
        } else if requiredCIDs == kept {
            activateOwnership()
        } else {
            transition(to: .nativeReady)
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
        takeoverSeedCIDs = appliedCIDs.intersection(requiredCIDs)
        takeoverPreflightStates.removeAll(keepingCapacity: true)
        intendedStates = Dictionary(uniqueKeysWithValues: frozenRequiredCIDs.compactMap { cid in
            if takeoverSeedCIDs.contains(cid), let intended = journalEntriesForThisDevice()[cid]?.intended {
                return (cid, intended)
            }
            return originalStates[cid].map { (cid, $0.changingDivert(to: true)) }
        })
        preparedCIDs.removeAll()
        touchedCIDs.removeAll()
        knownWrittenCIDs = takeoverSeedCIDs
        transactionAppliedCIDs = takeoverSeedCIDs
        externallyOwnedCIDs.removeAll()
        confirmedNotOwnedCIDs.removeAll()
        appliedCIDs = takeoverSeedCIDs
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
                latchPreflightMismatches()
                if takeoverSeedCIDs.isEmpty {
                    operationGeneration &+= 1
                    transition(to: .conflict)
                } else {
                    beginRollback(outcome: .conflict)
                }
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
        return frozenRequiredCIDs.allSatisfy { cid in
            guard let value = takeoverPreflightStates[cid],
                  let baseline = originalStates[cid]
            else { return false }
            if takeoverSeedCIDs.contains(cid) {
                return intendedStates[cid] == value
            }
            let cleanBaseline = value == baseline && !value.isDiverted
            return cleanBaseline
        }
    }

    private func latchPreflightMismatches() {
        for cid in frozenRequiredCIDs {
            guard let value = takeoverPreflightStates[cid] else { continue }
            if takeoverSeedCIDs.contains(cid) {
                if intendedStates[cid] != value {
                    externallyOwnedCIDs.insert(cid)
                }
            } else if value != originalStates[cid] || value.isDiverted {
                externallyOwnedCIDs.insert(cid)
            }
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
        if takeoverSeedCIDs.contains(cid) {
            persistPrepared(
                index: index + 1,
                lifecycle: lifecycle,
                operation: operation,
                policy: policy
            )
            return
        }
        guard let original = originalStates[cid], let intended = intendedStates[cid] else {
            enterInvalid(.protocol)
            return
        }
        journalRepository.mutateCID(
            for: deviceKey,
            cid: cid,
            mutation: { existing in
                guard existing == nil else {
                    throw M720JournalRepositoryError.mismatchedCID
                }
                return M720JournalCIDEntry(
                    cid: cid,
                    original: original,
                    intended: intended,
                    phase: .prepared
                )
            },
            commitPermission: shutdownJournalCommitPermission
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
        guard let expected = journalEntriesForThisDevice()[cid],
              expected.phase == .prepared
        else {
            beginRollbackAfterTakeoverFailure(.protocol)
            return
        }
        journalRepository.mutateCID(
            for: deviceKey,
            cid: cid,
            mutation: { existing in
                guard var existing, existing == expected else {
                    throw M720JournalRepositoryError.mismatchedCID
                }
                existing.phase = .applied
                return existing
            },
            commitPermission: shutdownJournalCommitPermission
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
        activateOwnership()
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
        pipeline.beginNewLifecycle()
        let lifecycle = lifecycleGeneration
        let operation = operationGeneration
        rollbackCIDs = Set(
            appliedCIDs
                .union(preparedCIDs)
                .union(touchedCIDs)
                .union(knownWrittenCIDs)
                .union(transactionAppliedCIDs)
        ).sorted()
        rollbackResolvedCIDs.removeAll()
        rollbackHadConflict = false
        rollbackOutcome = outcome
        recoveryRollbackActive = false
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

    private func closeEventGate(preservingWakeOverlay: Bool = false) {
        gateOpen = false
        eventGeneration &+= 1
        activeEpoch &+= 1
        pipeline.onEvent = nil
        pipeline.onForeignResponse = nil
        cancelScheduledVerifications()
        verificationInFlight = false
        pendingVerification = nil
        if !preservingWakeOverlay {
            sleepSuspended = false
            wakeRequested = false
            sleepCancelCompleted = true
            wakeReadbackCompleted = true
            activeSleepCycle = nil
        }
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

    private func activateOwnership() {
        gateOpen = true
        sleepSuspended = false
        wakeRequested = false
        sleepCancelCompleted = true
        wakeReadbackCompleted = true
        activeSleepCycle = nil
        activeEpoch &+= 1
        cancelScheduledVerifications()
        lastVerificationSequenceStart = -Double.infinity
        verificationInFlight = false
        pendingVerification = nil
        transition(to: .active)
        installEventHandler()
        installForeignResponseHandler()
        startVerificationSequence()
        if !didScanInitialOwnershipAgents {
            didScanInitialOwnershipAgents = true
            if initialOwnershipAgentScan() {
                startVerificationSequence()
            }
        }
    }

    private func installForeignResponseHandler() {
        let lifecycle = lifecycleGeneration
        let operation = operationGeneration
        let epoch = activeEpoch
        pipeline.onForeignResponse = { [weak self] identity in
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      identity.featureIndex == self.discoveredFeatureIndex,
                      identity.function == ReprogControlsV4.Function.setCidReporting.rawValue,
                      self.lifecycleGeneration == lifecycle,
                      self.operationGeneration == operation,
                      self.activeEpoch == epoch,
                      self.state == .active,
                      !self.sleepSuspended
                else { return }
                self.startVerificationSequence()
            }
        }
    }

    private func startVerificationSequence(allowDuringWake: Bool = false) {
        guard state == .active,
              terminalIntent == .none,
              (!sleepSuspended || (allowDuringWake && wakeRequested)),
              scheduler.now - lastVerificationSequenceStart >= 2.0
        else { return }
        lastVerificationSequenceStart = scheduler.now
        let lifecycle = lifecycleGeneration
        let operation = operationGeneration
        let epoch = activeEpoch
        for delay in [0.0, 0.25, 2.0, 10.0] {
            let timerToken = nextVerificationTimerToken
            nextVerificationTimerToken &+= 1
            verificationTimerTokens.insert(timerToken)
            let cancellation = scheduler.schedule(after: delay) { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard let self,
                          self.verificationTimerTokens.remove(timerToken) != nil
                    else { return }
                    self.verificationCancellations.removeValue(forKey: timerToken)
                    guard
                          self.lifecycleGeneration == lifecycle,
                          self.operationGeneration == operation,
                          self.activeEpoch == epoch,
                          self.state == .active
                    else { return }
                    self.enqueueVerificationCheck(
                        wakeAuthoritative: self.sleepSuspended && self.wakeRequested
                    )
                }
            }
            if verificationTimerTokens.contains(timerToken) {
                verificationCancellations[timerToken] = cancellation
            } else {
                cancellation.cancel()
            }
        }
    }

    private func enqueueVerificationCheck(wakeAuthoritative: Bool = false) {
        guard state == .active,
              terminalIntent == .none,
              wakeAuthoritative
                ? (sleepSuspended && wakeRequested)
                : !sleepSuspended
        else { return }
        if wakeAuthoritative {
            wakeReadbackCompleted = false
        }
        let cids = requiredCIDs.sorted()
        guard !cids.isEmpty else { return }
        let intended = Dictionary(uniqueKeysWithValues: cids.compactMap { cid in
            intendedStates[cid].map { (cid, $0) }
        })
        guard intended.count == cids.count else {
            beginRollback(outcome: .invalid(.protocol))
            return
        }
        let snapshot = VerificationSnapshot(
            lifecycle: lifecycleGeneration,
            operation: operationGeneration,
            activeEpoch: activeEpoch,
            cids: cids,
            intended: intended,
            wakeAuthoritative: wakeAuthoritative,
            sleepCycle: wakeAuthoritative ? activeSleepCycle : nil
        )
        if verificationInFlight {
            pendingVerification = snapshot
            return
        }
        verificationInFlight = true
        requestVerificationCurrentState(index: 0, snapshot: snapshot)
    }

    private func requestVerificationCurrentState(
        index: Int,
        snapshot: VerificationSnapshot
    ) {
        guard verificationIsCurrent(snapshot) else { return }
        guard index < snapshot.cids.count else {
            finishVerificationCheck(snapshot)
            return
        }
        guard let featureIndex = discoveredFeatureIndex else {
            verificationFailed(.protocol)
            return
        }
        let cid = snapshot.cids[index]
        pipeline.perform(
            featureIndex: featureIndex,
            function: ReprogControlsV4.Function.getCidReporting.rawValue,
            parameters: bigEndian(cid)
        ) { [weak self] result in
            guard let self, self.verificationIsCurrent(snapshot) else { return }
            switch result {
            case let .success(parameters):
                do {
                    let current = try ReprogControlsV4.decodeReportingState(parameters)
                    guard current.cid == cid, let intended = snapshot.intended[cid] else {
                        self.verificationFailed(.protocol)
                        return
                    }
                    guard current == intended else {
                        self.verificationInFlight = false
                        self.pendingVerification = nil
                        if self.originalStates[cid] == current {
                            self.confirmedNotOwnedCIDs.insert(cid)
                            if snapshot.wakeAuthoritative {
                                self.beginRollback(outcome: .reconcilePolicy)
                                return
                            }
                        } else {
                            self.externallyOwnedCIDs.insert(cid)
                        }
                        self.beginRollback(outcome: .conflict)
                        return
                    }
                    self.requestVerificationCurrentState(
                        index: index + 1,
                        snapshot: snapshot
                    )
                } catch {
                    self.verificationFailed(.protocol)
                }
            case let .failure(error):
                self.verificationFailed(self.stableCode(for: error))
            }
        }
    }

    private func finishVerificationCheck(_ snapshot: VerificationSnapshot) {
        guard verificationIsCurrent(snapshot) else { return }
        verificationInFlight = false
        if snapshot.wakeAuthoritative {
            if let pending = pendingVerification,
               verificationIsCurrent(pending) {
                pendingVerification = nil
                verificationInFlight = true
                requestVerificationCurrentState(index: 0, snapshot: pending)
                return
            }
            pendingVerification = nil
            wakeReadbackCompleted = true
            maybeCompleteWakeOverlay(sleepCycle: snapshot.sleepCycle)
            return
        }
        guard let pending = pendingVerification else { return }
        pendingVerification = nil
        guard verificationIsCurrent(pending) else { return }
        verificationInFlight = true
        requestVerificationCurrentState(index: 0, snapshot: pending)
    }

    private func verificationFailed(_ code: M720StableErrorCode) {
        verificationInFlight = false
        pendingVerification = nil
        beginRollback(outcome: .invalid(code))
    }

    private func verificationIsCurrent(_ snapshot: VerificationSnapshot) -> Bool {
        state == .active &&
            terminalIntent == .none &&
            lifecycleGeneration == snapshot.lifecycle &&
            operationGeneration == snapshot.operation &&
            activeEpoch == snapshot.activeEpoch &&
            requiredCIDs == Set(snapshot.cids) &&
            snapshot.cids.allSatisfy { intendedStates[$0] == snapshot.intended[$0] } &&
            (snapshot.wakeAuthoritative
                ? (sleepSuspended &&
                    wakeRequested &&
                    snapshot.sleepCycle == activeSleepCycle)
                : !sleepSuspended)
    }

    private func maybeCompleteWakeOverlay(sleepCycle: UInt64?) {
        guard state == .active,
              terminalIntent == .none,
              let sleepCycle,
              activeSleepCycle == sleepCycle,
              sleepSuspended,
              wakeRequested,
              sleepCancelCompleted,
              wakeReadbackCompleted,
              requiredCIDs == appliedCIDs
        else { return }
        sleepSuspended = false
        wakeRequested = false
        activeSleepCycle = nil
        gateOpen = true
        installEventHandler()
        installForeignResponseHandler()
    }

    private func cancelScheduledVerifications() {
        for cancellation in verificationCancellations.values {
            cancellation.cancel()
        }
        verificationCancellations.removeAll()
        verificationTimerTokens.removeAll()
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
        refreshRecoveryRollbackPlan()
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
        guard let expected = journalEntriesForThisDevice()[cid] else {
            enterInvalid(.protocol)
            return
        }
        journalRepository.mutateCID(
            for: deviceKey,
            cid: cid,
            mutation: { existing in
                guard var existing, existing == expected else {
                    throw M720JournalRepositoryError.mismatchedCID
                }
                existing.phase = .restoring
                return existing
            },
            commitPermission: shutdownJournalCommitPermission
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
        guard let expected = journalEntriesForThisDevice()[cid] else {
            enterInvalid(.protocol)
            return
        }
        journalRepository.mutateCID(
            for: deviceKey,
            cid: cid,
            mutation: { existing in
                guard existing == expected else {
                    throw M720JournalRepositoryError.mismatchedCID
                }
                return nil
            },
            commitPermission: shutdownJournalCommitPermission
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
                    self.rollbackResolvedCIDs.insert(cid)
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
        if rollbackHadConflict {
            appliedCIDs.removeAll()
            recoveryRollbackActive = false
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
            appliedCIDs.removeAll()
            transition(to: .nativeReady)
            if !requiredCIDs.isEmpty {
                beginTakeover()
            }
        case .finishRecovery:
            let latestKept = recoveryOwnedCIDs
                .intersection(requiredCIDs)
                .subtracting(rollbackResolvedCIDs)
            recoveryRollbackActive = false
            finishRecoveredOwnership(latestKept)
        case .conflict:
            appliedCIDs.removeAll()
            recoveryRollbackActive = false
            operationGeneration &+= 1
            transition(to: .conflict)
        case let .invalid(code):
            appliedCIDs.removeAll()
            recoveryRollbackActive = false
            operationGeneration &+= 1
            transition(to: .invalid(code))
        case .shutdown:
            appliedCIDs.removeAll()
            recoveryRollbackActive = false
            finalizeShutdown(reason: .cancelled)
        }
    }

    private func refreshRecoveryRollbackPlan() {
        guard recoveryRollbackActive else { return }
        let mustRestore: Set<UInt16>
        if rollbackHadConflict || terminalIntent == .shutdown || !requiredPolicyIsSupported {
            mustRestore = recoveryOwnedCIDs
        } else {
            mustRestore = recoveryOwnedCIDs.subtracting(requiredCIDs)
        }
        let alreadyPlanned = Set(rollbackCIDs).union(rollbackResolvedCIDs)
        rollbackCIDs.append(contentsOf: mustRestore.subtracting(alreadyPlanned).sorted())
    }

    private func finalizeShutdown(reason: M720StableErrorCode = .cancelled) {
        guard terminalIntent == .shutdown, !terminalFinished else { return }
        terminalShutdownReason = reason
        beginTerminalFinalization()
    }

    private func finalizeRemoval() {
        guard terminalIntent == .removal, !terminalFinished else { return }
        beginTerminalFinalization()
    }

    private func beginTerminalFinalization() {
        guard !terminalFinalizationStarted else { return }
        terminalFinalizationStarted = true
        lifecycleGeneration &+= 1
        operationGeneration &+= 1
        pipeline.invalidate { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.completeTerminalFinalization()
            }
        }
    }

    private func completeTerminalFinalization() {
        guard terminalFinalizationStarted,
              !terminalFinished,
              terminalIntent != .none
        else { return }
        terminalFinished = true
        switch terminalIntent {
        case .removal:
            transition(to: .invalid(.disconnected))
        case .shutdown:
            transition(to: .invalid(terminalShutdownReason))
        case .none:
            preconditionFailure("Terminal drain completed without an intent")
        }
        let shutdowns = shutdownWaiters
        let removals = removalWaiters
        shutdownWaiters.removeAll()
        removalWaiters.removeAll()
        for waiter in removals { waiter() }
        for waiter in shutdowns { waiter() }
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
        journalIdentityUsable &&
            !deviceKey.serialNumber.isEmpty &&
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
                    if expectedState == .takingOver,
                       !self.touchedCIDs
                        .union(self.knownWrittenCIDs)
                        .union(self.transactionAppliedCIDs)
                        .isEmpty {
                        self.reconcilePreparedClaimsAfterUncertainReload()
                        self.beginRollbackAfterTakeoverFailure(.protocol)
                        return
                    }
                }
                self.enterInvalid(.protocol)
            }
        }
    }

    private func reconcilePreparedClaimsAfterUncertainReload() {
        let entries = journalEntriesForThisDevice()
        for cid in frozenRequiredCIDs where !touchedCIDs.contains(cid) {
            guard let original = originalStates[cid],
                  let intended = intendedStates[cid]
            else { continue }
            let expected = M720JournalCIDEntry(
                cid: cid,
                original: original,
                intended: intended,
                phase: .prepared
            )
            if entries[cid] == expected {
                preparedCIDs.insert(cid)
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

    private func isQuarantinedJournalError(_ error: Error) -> Bool {
        guard let error = error as? M720JournalStoreError else { return false }
        return error == .quarantined || error == .corruptFileQuarantined
    }

    private func enterInvalid(_ code: M720StableErrorCode) {
        recoveryInProgress = false
        operationGeneration &+= 1
        transition(to: .invalid(code))
        if terminalIntent == .shutdown {
            finalizeShutdown(reason: code)
        }
    }

    private func transition(to newState: M720SessionState) {
        guard state != newState else { return }
        state = newState
        if newState == .conflict {
            explicitRetryRequired = true
        }
        let observer = onStateChange
        if let observer {
            DispatchQueue.main.async { observer(newState) }
        }
        guard retryInProgress else { return }
        let completesRetry: Bool
        switch newState {
        case .active, .conflict, .invalid:
            completesRetry = true
        case .nativeReady:
            completesRetry = requiredCIDs.isEmpty
        case .discovering, .takingOver, .restoring:
            completesRetry = false
        }
        guard completesRetry else { return }
        retryInProgress = false
        retryPath = nil
    }
}
