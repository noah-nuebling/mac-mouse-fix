import AppKit
import Foundation

protocol M720AddModeController: AnyObject {
    var onPreparationContextChange: ((M720PreparationContextChange) -> Void)? { get set }
    var onStableStateChange: ((M720ControllerSessionSnapshot) -> Void)? { get set }

    func capturePreparationSnapshot() -> M720PreparationSnapshot
    func beginTemporaryPolicyLease(
        ownerID: UUID,
        snapshot: M720PreparationSnapshot,
        targetCIDs: Set<UInt16>,
        completion: @escaping (M720TemporaryPolicyResult) -> Void
    ) -> Bool
    func restoreTemporaryPolicyLease(
        ownerID: UUID,
        completion: @escaping (M720TemporaryPolicyResult) -> Void
    ) -> Bool
    func updateTemporaryPolicyLeaseToCurrentSaved(
        ownerID: UUID,
        completion: @escaping (M720TemporaryPolicyResult) -> Void
    ) -> Bool
    func clearTemporaryPolicyLease(ownerID: UUID) -> Bool
    func captureStateSnapshots() -> [M720ControllerSessionSnapshot]
    func retryCapture(deviceToken: UUID, requestID: UUID?) -> Bool
}

extension M720HIDPPController: M720AddModeController {}

protocol M720AddModeScheduledTask: AnyObject {
    func cancel()
}

protocol M720AddModeScheduling: AnyObject {
    var now: TimeInterval { get }

    @discardableResult
    func schedule(
        after delay: TimeInterval,
        action: @escaping () -> Void
    ) -> M720AddModeScheduledTask
}

private final class M720AddModeDispatchTask: M720AddModeScheduledTask {
    private let item: DispatchWorkItem

    init(item: DispatchWorkItem) {
        self.item = item
    }

    func cancel() {
        item.cancel()
    }
}

private final class M720AddModeMainScheduler: M720AddModeScheduling {
    var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func schedule(
        after delay: TimeInterval,
        action: @escaping () -> Void
    ) -> M720AddModeScheduledTask {
        let item = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return M720AddModeDispatchTask(item: item)
    }
}

@objc(M720AddModeCoordinator)
final class M720AddModeCoordinator: NSObject {
    typealias StartExecutor = (@escaping () -> Void) -> Void
    typealias MessageSender = (String, NSDictionary) -> Void
    typealias AppTerminationObserver = (@escaping () -> Void) -> Void

    private static let preparationTimeout: TimeInterval = 5
    private static let leaseTimeout: TimeInterval = 5

    private enum Phase {
        case reserved
        case preparing
        case recording
        case rollingBack
        case finishing
        case terminal
    }

    private enum TerminationCause {
        case user
        case superseded
        case environmentChanged
        case deadline
        case leaseExpired
        case appUnavailable
        case deviceSetChanged
        case participant(M720StableErrorCode)

        var preparationOutcome: M720PreparationOutcome {
            switch self {
            case .user, .superseded, .environmentChanged:
                return .cancelled
            case .deadline:
                return .failed(.timeout)
            case .leaseExpired, .appUnavailable:
                return .failed(.appUnavailable)
            case .deviceSetChanged:
                return .failed(.deviceSetChanged)
            case let .participant(error):
                return Self.preparationOutcome(for: error)
            }
        }

        var inactiveReason: M720AddModeInactiveReason {
            switch self {
            case .leaseExpired, .appUnavailable:
                return .appUnavailable
            case .deviceSetChanged:
                return .deviceSetChanged
            case .user, .superseded, .environmentChanged, .deadline, .participant:
                return .cancelled
            }
        }

        static func preparationOutcome(for error: M720StableErrorCode) -> M720PreparationOutcome {
            switch error {
            case .conflict:
                return .conflict
            case .cancelled:
                return .cancelled
            case .unsupported:
                return .failed(.unsupported)
            case .protocol:
                return .failed(.protocol)
            case .timeout:
                return .failed(.timeout)
            case .disconnected:
                return .failed(.disconnected)
            case .deviceSetChanged:
                return .failed(.deviceSetChanged)
            case .appUnavailable:
                return .failed(.appUnavailable)
            }
        }
    }

    private final class Preparation {
        let requestID: UUID
        let ownerID: UUID
        let generation: UInt64
        let snapshot: M720PreparationSnapshot
        var lastRenewal: TimeInterval
        var phase: Phase = .reserved
        var preparationResultWasSent = false
        var inactiveStateWasSent = false
        var feedbackWasSent = false
        var leaseWasEstablished = false
        var rollbackMustRetryAfterContextChange = false
        var finishMustRetryAfterContextChange = false
        var terminationCause: TerminationCause?
        var deadlineTask: M720AddModeScheduledTask?
        var leaseTask: M720AddModeScheduledTask?

        init(
            requestID: UUID,
            ownerID: UUID,
            generation: UInt64,
            snapshot: M720PreparationSnapshot,
            lastRenewal: TimeInterval
        ) {
            self.requestID = requestID
            self.ownerID = ownerID
            self.generation = generation
            self.snapshot = snapshot
            self.lastRenewal = lastRenewal
        }

        var deviceTokens: Set<UUID> {
            Set(snapshot.participants.map(\.deviceToken))
        }

        func cancelTimers() {
            deadlineTask?.cancel()
            deadlineTask = nil
            leaseTask?.cancel()
            leaseTask = nil
        }
    }

    @objc static let shared = M720AddModeCoordinator()

    private let controller: M720AddModeController
    private let scheduler: M720AddModeScheduling
    private let ownerFactory: () -> UUID
    private let enqueueStart: StartExecutor
    private let enableAddMode: () -> Bool
    private let disableAddMode: () -> Void
    private let reloadSavedConfiguration: () -> Void
    private let sendMessage: MessageSender

    private var nextGeneration: UInt64 = 0
    private var active: Preparation?
    private var pending: Preparation?
    private var blockedLeaseError: M720StableErrorCode?
    private var shutdownStarted = false

    private override convenience init() {
        let scheduler = M720AddModeMainScheduler()
        self.init(
            controller: M720HIDPPController.shared,
            scheduler: scheduler,
            ownerFactory: UUID.init,
            enqueueStart: { block in DispatchQueue.main.async(execute: block) },
            enableAddMode: Remap.enableAddMode,
            disableAddMode: { _ = Remap.disableAddMode() },
            reloadSavedConfiguration: Config.loadFileAndUpdateStates,
            sendMessage: { message, payload in
                _ = MFMessagePort.sendMessage(
                    message,
                    withPayload: payload,
                    waitForReply: false
                )
            },
            observeMainAppTermination: { action in
                NSWorkspace.shared.notificationCenter.addObserver(
                    forName: NSWorkspace.didTerminateApplicationNotification,
                    object: nil,
                    queue: .main
                ) { notification in
                    guard
                        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                            as? NSRunningApplication,
                        application.bundleIdentifier == kMFBundleIDApp
                    else { return }
                    action()
                }
            }
        )
    }

    @nonobjc init(
        controller: M720AddModeController,
        scheduler: M720AddModeScheduling,
        ownerFactory: @escaping () -> UUID,
        enqueueStart: @escaping StartExecutor,
        enableAddMode: @escaping () -> Bool,
        disableAddMode: @escaping () -> Void,
        reloadSavedConfiguration: @escaping () -> Void,
        sendMessage: @escaping MessageSender,
        observeMainAppTermination: @escaping AppTerminationObserver
    ) {
        self.controller = controller
        self.scheduler = scheduler
        self.ownerFactory = ownerFactory
        self.enqueueStart = enqueueStart
        self.enableAddMode = enableAddMode
        self.disableAddMode = disableAddMode
        self.reloadSavedConfiguration = reloadSavedConfiguration
        self.sendMessage = sendMessage
        super.init()

        controller.onPreparationContextChange = { [weak self] change in
            self?.handlePreparationContextChange(change)
        }
        controller.onStableStateChange = { [weak self] snapshot in
            self?.publishCaptureState(snapshot)
        }
        observeMainAppTermination { [weak self] in
            self?.handleAppUnavailable()
        }
    }

    @objc(prepareWithPayload:)
    func prepare(withPayload rawPayload: Any?) -> NSDictionary {
        let request: M720IPCRequest
        do {
            request = try M720IPCRequest.decode(rawPayload)
        } catch {
            return M720IPCAcknowledgement.rejected(.protocol).payload
        }
        guard !shutdownStarted else {
            return M720IPCAcknowledgement.rejected(.appUnavailable).payload
        }

        guard !contains(requestID: request.requestID) else {
            return M720IPCAcknowledgement.rejected(.conflict).payload
        }

        let preparation = makePreparation(requestID: request.requestID)
        scheduleTimers(for: preparation)

        if active == nil {
            active = preparation
            enqueueStart { [weak self, weak preparation] in
                guard let self, let preparation else { return }
                self.start(preparation)
            }
        } else {
            if let active {
                establishTerminationIntent(active, cause: .superseded)
            }
            let replaced = pending
            pending = preparation
            if let replaced {
                replaced.phase = .terminal
                replaced.cancelTimers()
                enqueueStart { [weak self] in
                    self?.sendPreparationResult(replaced, outcome: .cancelled)
                }
            }
            enqueueStart { [weak self] in
                self?.supersedeActiveForPendingIfNeeded()
            }
        }

        return M720IPCAcknowledgement.accepted.payload
    }

    @objc(cancelPreparationWithPayload:)
    func cancelPreparation(withPayload rawPayload: Any?) -> NSDictionary {
        guard let request = try? M720IPCRequest.decode(rawPayload) else {
            return M720IPCAcknowledgement.rejected(.protocol).payload
        }
        guard !shutdownStarted else {
            return M720IPCAcknowledgement.rejected(.appUnavailable).payload
        }
        guard let preparation = preparation(requestID: request.requestID) else {
            return M720IPCAcknowledgement.rejected(.cancelled).payload
        }

        guard establishTerminationIntent(preparation, cause: .user) else {
            return M720IPCAcknowledgement.rejected(.cancelled).payload
        }

        enqueueStart { [weak self, weak preparation] in
            guard let self, let preparation else { return }
            if self.pending === preparation {
                self.pending = nil
                preparation.phase = .terminal
                preparation.cancelTimers()
                self.sendPreparationResult(preparation, outcome: .cancelled)
            } else {
                self.requestTermination(preparation, cause: .user)
            }
        }
        return M720IPCAcknowledgement.accepted.payload
    }

    @objc(renewLeaseWithPayload:)
    func renewLease(withPayload rawPayload: Any?) -> NSDictionary {
        guard let request = try? M720IPCRequest.decode(rawPayload) else {
            return M720IPCAcknowledgement.rejected(.protocol).payload
        }
        guard !shutdownStarted else {
            return M720IPCAcknowledgement.rejected(.appUnavailable).payload
        }
        guard let preparation = preparation(requestID: request.requestID),
              preparation.phase == .reserved ||
                preparation.phase == .preparing ||
                preparation.phase == .recording,
              preparation.terminationCause == nil
        else {
            return M720IPCAcknowledgement.rejected(.cancelled).payload
        }
        preparation.lastRenewal = scheduler.now
        scheduleLeaseExpiry(for: preparation)
        return M720IPCAcknowledgement.accepted.payload
    }

    @objc(finishAddModeWithPayload:)
    func finishAddMode(withPayload rawPayload: Any?) -> NSDictionary {
        guard let request = try? M720IPCRequest.decode(rawPayload) else {
            return M720IPCAcknowledgement.rejected(.protocol).payload
        }
        guard !shutdownStarted else {
            return M720IPCAcknowledgement.rejected(.appUnavailable).payload
        }
        guard let preparation = active,
              preparation.requestID == request.requestID,
              preparation.phase == .recording,
              preparation.terminationCause == nil,
              pending == nil
        else {
            return M720IPCAcknowledgement.rejected(.cancelled).payload
        }

        preparation.phase = .finishing
        preparation.deadlineTask?.cancel()
        preparation.deadlineTask = nil
        preparation.leaseTask?.cancel()
        preparation.leaseTask = nil
        enqueueStart { [weak self, weak preparation] in
            guard let self, let preparation else { return }
            self.beginFinish(preparation)
        }
        return M720IPCAcknowledgement.accepted.payload
    }

    @objc(retryCaptureWithPayload:)
    func retryCapture(withPayload rawPayload: Any?) -> NSDictionary {
        guard let request = try? M720RetryCaptureRequest.decode(rawPayload) else {
            return M720IPCAcknowledgement.rejected(.protocol).payload
        }
        guard !shutdownStarted else {
            return M720IPCAcknowledgement.rejected(.appUnavailable).payload
        }
        guard controller.retryCapture(
            deviceToken: request.deviceToken,
            requestID: request.requestID
        ) else {
            return M720IPCAcknowledgement.rejected(.disconnected).payload
        }
        return M720IPCAcknowledgement.accepted.payload
    }

    @objc(captureStatesWithPayload:)
    func captureStates(withPayload rawPayload: Any?) -> NSDictionary {
        guard (try? M720EmptyPayload.decode(rawPayload)) != nil else {
            return M720IPCAcknowledgement.rejected(.protocol).payload
        }
        let states = controller.captureStateSnapshots().compactMap(captureState)
        return M720CaptureStates(states: states).payload
    }

    @objc(submitFeedback:)
    func submitFeedback(_ feedback: NSDictionary) {
        guard !shutdownStarted else { return }
        let copiedFeedback = feedback.copy() as! NSDictionary
        enqueueStart { [weak self] in
            self?.submitFeedbackOnMain(copiedFeedback)
        }
    }

    @objc func beginShutdown() {
        guard !shutdownStarted else { return }
        shutdownStarted = true
        controller.onPreparationContextChange = nil
        controller.onStableStateChange = nil
        disableAddMode()

        let preparations = [active, pending].compactMap { $0 }
        active = nil
        pending = nil
        for preparation in preparations {
            preparation.phase = .terminal
            preparation.cancelTimers()
            sendTerminalForActive(preparation, cause: .appUnavailable)
        }
    }

    private func submitFeedbackOnMain(_ feedback: NSDictionary) {
        guard let preparation = active,
              preparation.phase == .recording,
              preparation.terminationCause == nil,
              !preparation.feedbackWasSent
        else { return }
        let raw: NSDictionary = [
            "requestID": preparation.requestID.uuidString,
            "feedback": feedback,
        ]
        guard let message = try? M720AddModeFeedback.decode(raw) else { return }
        preparation.feedbackWasSent = true
        sendMessage("addModeFeedback", message.payload)
    }

    private func makePreparation(requestID: UUID) -> Preparation {
        nextGeneration &+= 1
        return Preparation(
            requestID: requestID,
            ownerID: ownerFactory(),
            generation: nextGeneration,
            snapshot: controller.capturePreparationSnapshot(),
            lastRenewal: scheduler.now
        )
    }

    private func contains(requestID: UUID) -> Bool {
        active?.requestID == requestID || pending?.requestID == requestID
    }

    private func preparation(requestID: UUID) -> Preparation? {
        if active?.requestID == requestID { return active }
        if pending?.requestID == requestID { return pending }
        return nil
    }

    private func scheduleTimers(for preparation: Preparation) {
        preparation.deadlineTask = scheduler.schedule(
            after: Self.preparationTimeout
        ) { [weak self, weak preparation] in
            guard let self, let preparation else { return }
            self.handlePreparationDeadline(preparation)
        }
        scheduleLeaseExpiry(for: preparation)
    }

    private func scheduleLeaseExpiry(for preparation: Preparation) {
        preparation.leaseTask?.cancel()
        preparation.leaseTask = scheduler.schedule(
            after: Self.leaseTimeout
        ) { [weak self, weak preparation] in
            guard let self, let preparation else { return }
            self.handleLeaseExpiry(preparation)
        }
    }

    private func handlePreparationDeadline(_ preparation: Preparation) {
        if pending === preparation {
            pending = nil
            preparation.phase = .terminal
            preparation.cancelTimers()
            sendPreparationResult(preparation, outcome: .failed(.timeout))
            return
        }
        guard active === preparation,
              preparation.phase == .reserved || preparation.phase == .preparing
        else { return }
        requestTermination(preparation, cause: .deadline)
    }

    private func handleLeaseExpiry(_ preparation: Preparation) {
        if pending === preparation {
            guard preparation.deadlineTask == nil else { return }
            pending = nil
            preparation.phase = .terminal
            preparation.cancelTimers()
            sendPreparationResult(preparation, outcome: .failed(.appUnavailable))
            return
        }
        guard active === preparation,
              preparation.phase != .rollingBack,
              preparation.phase != .terminal
        else { return }
        guard preparation.phase != .reserved, preparation.phase != .preparing else {
            return
        }
        requestTermination(preparation, cause: .leaseExpired)
    }

    private func start(_ preparation: Preparation) {
        guard active === preparation, preparation.phase == .reserved else { return }

        if let blockedLeaseError {
            preparation.phase = .terminal
            preparation.cancelTimers()
            sendPreparationResult(
                preparation,
                outcome: TerminationCause.preparationOutcome(for: blockedLeaseError)
            )
            active = nil
            failLatestPendingBecauseLeaseIsBlocked(blockedLeaseError)
            return
        }

        if let cause = preparation.terminationCause {
            requestTermination(preparation, cause: cause)
            return
        }

        preparation.phase = .preparing
        let accepted = controller.beginTemporaryPolicyLease(
            ownerID: preparation.ownerID,
            snapshot: preparation.snapshot,
            targetCIDs: Set(M720Profile.cidToButton.keys)
        ) { [weak self, weak preparation] result in
            guard let self, let preparation else { return }
            self.handleTakeoverResult(result, for: preparation)
        }
        guard accepted else {
            preparation.phase = .terminal
            preparation.cancelTimers()
            sendPreparationResult(
                preparation,
                outcome: rejectedSnapshotOutcome(for: preparation.snapshot)
            )
            if active === preparation { active = nil }
            startLatestPendingIfPossible()
            return
        }
        preparation.leaseWasEstablished = true
    }

    private func rejectedSnapshotOutcome(
        for frozen: M720PreparationSnapshot
    ) -> M720PreparationOutcome {
        let current = controller.capturePreparationSnapshot()
        if current.deviceSetRevision != frozen.deviceSetRevision ||
            current.participants.map(\.deviceToken) != frozen.participants.map(\.deviceToken) {
            return .failed(.deviceSetChanged)
        }
        if current.environmentEnabled != frozen.environmentEnabled {
            return .cancelled
        }
        return .conflict
    }

    private func handleTakeoverResult(
        _ result: M720TemporaryPolicyResult,
        for preparation: Preparation
    ) {
        guard active === preparation, preparation.phase == .preparing else { return }
        if let cause = preparation.terminationCause {
            requestTermination(preparation, cause: cause)
            return
        }
        switch result {
        case .ready:
            guard preparation.snapshot.environmentEnabled else {
                requestTermination(preparation, cause: .environmentChanged)
                return
            }
            guard enableAddMode() else {
                requestTermination(preparation, cause: .participant(.protocol))
                return
            }
            preparation.phase = .recording
            preparation.deadlineTask?.cancel()
            preparation.deadlineTask = nil
            sendPreparationResult(preparation, outcome: .ready)
        case let .failed(error):
            requestTermination(preparation, cause: .participant(error))
        }
    }

    private func supersedeActiveForPendingIfNeeded() {
        guard pending != nil, let active else { return }
        if let cause = active.terminationCause {
            requestTermination(active, cause: cause)
            return
        }
        switch active.phase {
        case .reserved, .preparing, .recording:
            requestTermination(active, cause: .superseded)
        case .rollingBack, .finishing, .terminal:
            break
        }
    }

    @discardableResult
    private func establishTerminationIntent(
        _ preparation: Preparation,
        cause: TerminationCause
    ) -> Bool {
        guard preparation.terminationCause == nil else { return false }
        switch preparation.phase {
        case .reserved, .preparing, .recording:
            preparation.terminationCause = cause
            preparation.cancelTimers()
            return true
        case .rollingBack, .finishing, .terminal:
            return false
        }
    }

    private func requestTermination(
        _ preparation: Preparation,
        cause: TerminationCause
    ) {
        guard active === preparation else { return }
        switch preparation.phase {
        case .rollingBack, .finishing, .terminal:
            return
        case .reserved:
            preparation.terminationCause = cause
            preparation.phase = .terminal
            preparation.cancelTimers()
            sendTerminalForActive(preparation, cause: cause)
            active = nil
            startLatestPendingIfPossible()
            return
        case .preparing, .recording:
            break
        }

        preparation.terminationCause = cause
        preparation.phase = .rollingBack
        preparation.cancelTimers()
        disableAddMode()

        guard preparation.leaseWasEstablished else {
            finishRollback(preparation, result: .ready)
            return
        }
        beginRollbackRestore(preparation)
    }

    private func beginRollbackRestore(_ preparation: Preparation) {
        guard active === preparation, preparation.phase == .rollingBack else { return }
        let accepted = controller.restoreTemporaryPolicyLease(
            ownerID: preparation.ownerID
        ) { [weak self, weak preparation] result in
            guard let self, let preparation else { return }
            self.handleRollbackResult(result, for: preparation)
        }
        if !accepted {
            finishRollback(preparation, result: .failed(.conflict))
        }
    }

    private func handleRollbackResult(
        _ result: M720TemporaryPolicyResult,
        for preparation: Preparation
    ) {
        guard active === preparation, preparation.phase == .rollingBack else { return }
        switch result {
        case .ready:
            clearOrReconcileCurrentSavedAfterRollback(preparation)
        case let .failed(error):
            handleRollbackOperationFailure(error, for: preparation)
        }
    }

    private func handleRollbackOperationFailure(
        _ error: M720StableErrorCode,
        for preparation: Preparation
    ) {
        guard active === preparation, preparation.phase == .rollingBack else { return }
        if preparation.rollbackMustRetryAfterContextChange,
           error == .deviceSetChanged || error == .cancelled {
            preparation.rollbackMustRetryAfterContextChange = false
            beginRollbackRestore(preparation)
        } else {
            finishRollback(preparation, result: .failed(error))
        }
    }

    private func clearOrReconcileCurrentSavedAfterRollback(_ preparation: Preparation) {
        guard active === preparation, preparation.phase == .rollingBack else { return }
        if controller.clearTemporaryPolicyLease(ownerID: preparation.ownerID) {
            finishRollback(preparation, result: .ready)
            return
        }
        let accepted = controller.updateTemporaryPolicyLeaseToCurrentSaved(
            ownerID: preparation.ownerID
        ) { [weak self, weak preparation] result in
            guard let self, let preparation else { return }
            guard self.active === preparation, preparation.phase == .rollingBack else { return }
            switch result {
            case .ready:
                self.clearOrReconcileCurrentSavedAfterRollback(preparation)
            case let .failed(error):
                self.handleRollbackOperationFailure(error, for: preparation)
            }
        }
        if !accepted {
            finishRollback(preparation, result: .failed(.conflict))
        }
    }

    private func finishRollback(
        _ preparation: Preparation,
        result: M720TemporaryPolicyResult
    ) {
        guard active === preparation, preparation.phase == .rollingBack else { return }
        let cause = preparation.terminationCause ?? .participant(.protocol)
        preparation.phase = .terminal
        preparation.cancelTimers()
        switch result {
        case .ready:
            sendTerminalForActive(preparation, cause: cause)
        case let .failed(error):
            if preparation.preparationResultWasSent {
                sendInactiveState(preparation, reason: cause.inactiveReason)
            } else {
                sendPreparationResult(
                    preparation,
                    outcome: TerminationCause.preparationOutcome(for: error)
                )
            }
        }
        active = nil

        switch result {
        case .ready:
            blockedLeaseError = nil
            startLatestPendingIfPossible()
        case let .failed(error):
            blockedLeaseError = error
            failLatestPendingBecauseLeaseIsBlocked(error)
        }
    }

    private func sendTerminalForActive(
        _ preparation: Preparation,
        cause: TerminationCause
    ) {
        if preparation.preparationResultWasSent {
            sendInactiveState(preparation, reason: cause.inactiveReason)
        } else {
            sendPreparationResult(preparation, outcome: cause.preparationOutcome)
        }
    }

    private func failLatestPendingBecauseLeaseIsBlocked(_ error: M720StableErrorCode) {
        guard let pending else { return }
        self.pending = nil
        pending.phase = .terminal
        pending.cancelTimers()
        sendPreparationResult(
            pending,
            outcome: TerminationCause.preparationOutcome(for: error)
        )
    }

    private func startLatestPendingIfPossible() {
        guard active == nil, let pending else { return }
        self.pending = nil
        active = pending
        start(pending)
    }

    private func beginFinish(_ preparation: Preparation) {
        guard active === preparation, preparation.phase == .finishing else { return }
        disableAddMode()
        reloadSavedConfiguration()
        updateCurrentSavedForFinish(preparation)
    }

    private func updateCurrentSavedForFinish(_ preparation: Preparation) {
        guard active === preparation, preparation.phase == .finishing else { return }
        preparation.finishMustRetryAfterContextChange = false
        let accepted = controller.updateTemporaryPolicyLeaseToCurrentSaved(
            ownerID: preparation.ownerID
        ) { [weak self, weak preparation] result in
            guard let self, let preparation else { return }
            self.handleFinishVerification(result, for: preparation)
        }
        if !accepted {
            blockFinish(preparation, error: .conflict)
        }
    }

    private func handleFinishVerification(
        _ result: M720TemporaryPolicyResult,
        for preparation: Preparation
    ) {
        guard active === preparation, preparation.phase == .finishing else { return }
        switch result {
        case .ready:
            if controller.clearTemporaryPolicyLease(ownerID: preparation.ownerID) {
                preparation.phase = .terminal
                preparation.cancelTimers()
                sendInactiveState(preparation, reason: .saved)
                active = nil
                blockedLeaseError = nil
                startLatestPendingIfPossible()
            } else {
                updateCurrentSavedForFinish(preparation)
            }
        case let .failed(error):
            if preparation.finishMustRetryAfterContextChange,
               error == .deviceSetChanged || error == .cancelled {
                updateCurrentSavedForFinish(preparation)
            } else {
                blockFinish(preparation, error: error)
            }
        }
    }

    private func blockFinish(_ preparation: Preparation, error: M720StableErrorCode) {
        guard active === preparation, preparation.phase == .finishing else { return }
        preparation.phase = .terminal
        preparation.cancelTimers()
        active = nil
        blockedLeaseError = error
        failLatestPendingBecauseLeaseIsBlocked(error)
    }

    private func handlePreparationContextChange(_ change: M720PreparationContextChange) {
        let cause: TerminationCause
        switch change {
        case .deviceSetChanged:
            cause = .deviceSetChanged
        case .environmentChanged:
            cause = .environmentChanged
        }

        if let pending {
            self.pending = nil
            pending.phase = .terminal
            pending.cancelTimers()
            sendPreparationResult(pending, outcome: cause.preparationOutcome)
        }
        if let active {
            if active.phase == .rollingBack {
                active.terminationCause = cause
                active.rollbackMustRetryAfterContextChange = true
            } else if active.phase == .finishing {
                active.finishMustRetryAfterContextChange = true
            } else {
                requestTermination(active, cause: cause)
            }
        }
    }

    private func handleAppUnavailable() {
        if let pending {
            self.pending = nil
            pending.phase = .terminal
            pending.cancelTimers()
            sendPreparationResult(pending, outcome: .failed(.appUnavailable))
        }
        if let active {
            requestTermination(active, cause: .appUnavailable)
        }
    }

    private func sendPreparationResult(
        _ preparation: Preparation,
        outcome: M720PreparationOutcome
    ) {
        guard !preparation.preparationResultWasSent else { return }
        preparation.preparationResultWasSent = true
        sendMessage(
            M720IPCMessage.preparationResult,
            M720PreparationResult(
                requestID: preparation.requestID,
                outcome: outcome,
                deviceTokens: preparation.deviceTokens
            ).payload
        )
    }

    private func sendInactiveState(
        _ preparation: Preparation,
        reason: M720AddModeInactiveReason
    ) {
        guard !preparation.inactiveStateWasSent else { return }
        preparation.inactiveStateWasSent = true
        sendMessage(
            M720IPCMessage.addModeStateChanged,
            M720AddModeStateChange(
                requestID: preparation.requestID,
                reason: reason
            ).payload
        )
    }

    private func publishCaptureState(_ snapshot: M720ControllerSessionSnapshot) {
        guard let state = captureState(snapshot) else { return }
        sendMessage(M720IPCMessage.captureStateChanged, state.payload)
    }

    private func captureState(
        _ snapshot: M720ControllerSessionSnapshot
    ) -> M720CaptureState? {
        let status: M720CaptureStatus
        switch snapshot.state {
        case .discovering:
            status = .discovering
        case .nativeReady:
            status = .nativeReady
        case .takingOver:
            status = .takingOver
        case .active:
            status = .active
        case .restoring:
            status = .restoring
        case .conflict:
            status = .conflict
        case let .invalid(error):
            guard let reason = M720CaptureInvalidReason(stableError: error) else { return nil }
            status = .invalid(reason)
        }
        return M720CaptureState(
            deviceToken: snapshot.deviceToken,
            status: status,
            requiredCIDs: snapshot.requiredCIDs,
            requestID: snapshot.requestID
        )
    }
}
