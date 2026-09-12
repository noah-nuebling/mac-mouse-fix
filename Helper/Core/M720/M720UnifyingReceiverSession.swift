import Foundation

final class M720UnifyingReceiverSession: M720SessionControlling {
    typealias ChildFactory = (
        M720UnifyingReceiverDevice,
        HIDPPTransport
    ) -> M720SessionControlling?

    private final class Child {
        let device: M720UnifyingReceiverDevice
        let session: M720SessionControlling
        var removalStarted = false

        init(
            device: M720UnifyingReceiverDevice,
            session: M720SessionControlling
        ) {
            self.device = device
            self.session = session
        }
    }

    private enum TerminalIntent {
        case none
        case shutdown
        case removal
    }

    private(set) var state: M720SessionState = .discovering
    private(set) var requiredCIDs: Set<UInt16> = []
    private(set) var isPolicyParticipant = false
    var onStateChange: ((M720SessionState) -> Void)?

    private let receiverDevice: Device
    private let manager: UnifyingReceiverManaging
    private let childFactory: ChildFactory
    private var children: [UInt8: Child] = [:]
    private var started = false
    private var rescanInFlight = false
    private var rescanPending = false
    private var pendingOnlineSlots: Set<UInt8> = []
    private var terminalIntent: TerminalIntent = .none
    private var terminalFinished = false
    private var terminalWaiters: [() -> Void] = []

    init(
        receiverDevice: Device,
        manager: UnifyingReceiverManaging,
        childFactory: @escaping ChildFactory
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.receiverDevice = receiverDevice
        self.manager = manager
        self.childFactory = childFactory
    }

    func start() {
        performOnMain { [weak self] in
            guard let self,
                  !started,
                  terminalIntent == .none
            else { return }
            started = true
            manager.onLinkEvent = { [weak self] event in
                self?.performOnMain { [weak self] in self?.handleLinkEvent(event) }
            }
            rescan(requestConnectionSnapshot: true)
        }
    }

    func setRequiredCIDs(_ cids: Set<UInt16>) {
        performOnMain { [weak self] in
            guard let self, terminalIntent == .none else { return }
            requiredCIDs = cids
            children.values.forEach { $0.session.setRequiredCIDs(cids) }
        }
    }

    func markJournalIdentityUnusable() {
        performOnMain { [weak self] in
            self?.children.values.forEach { $0.session.markJournalIdentityUnusable() }
        }
    }

    func prepareForSleep(completion: @escaping () -> Void) {
        performOnMain { [weak self] in
            guard let self else {
                completion()
                return
            }
            runAcrossChildren(
                operation: { $0.prepareForSleep(completion: $1) },
                completion: completion
            )
        }
    }

    func reconcileAfterWake() {
        performOnMain { [weak self] in
            self?.children.values.forEach { $0.session.reconcileAfterWake() }
        }
    }

    func knownOwnershipAgentDidLaunch() {
        performOnMain { [weak self] in
            self?.children.values.forEach {
                $0.session.knownOwnershipAgentDidLaunch()
            }
        }
    }

    func shutdown(completion: @escaping () -> Void) {
        beginTerminal(.shutdown, completion: completion)
    }

    func shutdownDeadlineReached() {
        precondition(Thread.isMainThread)
        children.values.forEach { $0.session.shutdownDeadlineReached() }
    }

    func invalidateForRemoval(completion: @escaping () -> Void) {
        beginTerminal(.removal, completion: completion)
    }

    @discardableResult
    func retryAfterConflict(requestID: UUID?) -> Bool {
        precondition(Thread.isMainThread)
        guard terminalIntent == .none else { return false }
        var accepted = false
        for child in children.values {
            accepted = child.session.retryAfterConflict(requestID: requestID) || accepted
        }
        return accepted
    }

    func diagnosticSnapshot(deviceToken: UUID) -> M720DiagnosticSessionSnapshot {
        precondition(Thread.isMainThread)
        if let child = children.values.sorted(by: {
            $0.device.slot < $1.device.slot
        }).first {
            return child.session.diagnosticSnapshot(deviceToken: deviceToken)
        }
        return M720DiagnosticSessionSnapshot(
            deviceToken: deviceToken,
            state: .discovering,
            generation: 0,
            requiredCIDs: requiredCIDs,
            appliedCIDs: [],
            pressedCIDs: [],
            sentCounts: [],
            recentRequests: []
        )
    }

    private func rescan(requestConnectionSnapshot: Bool) {
        guard terminalIntent == .none else { return }
        guard !rescanInFlight else {
            rescanPending = true
            return
        }
        rescanInFlight = true
        manager.prepare { [weak self] result in
            self?.performOnMain { [weak self] in
                guard let self else { return }
                rescanInFlight = false
                guard terminalIntent == .none else { return }
                switch result {
                case let .success(devices):
                    installMissingChildren(devices)
                case let .failure(error):
                    updatePublishedState(
                        error == .timeout ? .invalid(.timeout) : .invalid(.protocol)
                    )
                }
                if requestConnectionSnapshot {
                    manager.requestConnectionSnapshot { _ in }
                }
                if rescanPending {
                    rescanPending = false
                    rescan(requestConnectionSnapshot: false)
                }
            }
        }
    }

    private func installMissingChildren(
        _ devices: [M720UnifyingReceiverDevice]
    ) {
        guard terminalIntent == .none else { return }
        for device in devices.sorted(by: { $0.slot < $1.slot }) {
            guard children[device.slot] == nil,
                  let transport = manager.makeSlotTransport(slot: device.slot),
                  let session = childFactory(device, transport)
            else { continue }

            let child = Child(device: device, session: session)
            children[device.slot] = child
            session.onStateChange = { [weak self, weak child] _ in
                self?.performOnMain { [weak self, weak child] in
                    guard let self,
                          let child,
                          children[child.device.slot] === child,
                          terminalIntent == .none
                    else { return }
                    publishAggregateState()
                }
            }
            session.setRequiredCIDs(requiredCIDs)
        }

        publishAggregateState()
        for child in children.values.sorted(by: {
            $0.device.slot < $1.device.slot
        }) where child.session.state == .discovering {
            child.session.start()
        }
    }

    private func handleLinkEvent(_ event: UnifyingReceiverLinkEvent) {
        guard terminalIntent == .none else { return }
        switch event {
        case let .linkChanged(slot, wirelessProductID, online):
            guard wirelessProductID == M720Profile.unifyingWirelessProductID else {
                return
            }
            if online {
                if let child = children[slot] {
                    if child.removalStarted {
                        pendingOnlineSlots.insert(slot)
                    }
                    return
                }
                pendingOnlineSlots.remove(slot)
                rescan(requestConnectionSnapshot: false)
            } else {
                pendingOnlineSlots.remove(slot)
                removeChild(slot: slot)
            }
        case let .unpaired(slot):
            pendingOnlineSlots.remove(slot)
            removeChild(slot: slot)
        }
    }

    private func removeChild(slot: UInt8) {
        guard let child = children[slot], !child.removalStarted else { return }
        child.removalStarted = true
        child.session.onStateChange = nil
        child.session.invalidateForRemoval { [weak self, weak child] in
            self?.performOnMain { [weak self, weak child] in
                guard let self,
                      let child,
                      children[slot] === child,
                      terminalIntent == .none
                else { return }
                children.removeValue(forKey: slot)
                publishAggregateState()
                if pendingOnlineSlots.remove(slot) != nil {
                    rescan(requestConnectionSnapshot: false)
                }
            }
        }
    }

    private func publishAggregateState() {
        let sessions = children.values.map(\.session)
        let aggregate: M720SessionState
        if sessions.isEmpty {
            aggregate = .discovering
        } else if sessions.allSatisfy({ $0.state == .active }) {
            aggregate = .active
        } else if sessions.allSatisfy({ $0.state == .nativeReady }) {
            aggregate = .nativeReady
        } else if sessions.contains(where: { $0.state == .conflict }) {
            aggregate = .conflict
        } else if let code = sessions.compactMap({ session -> M720StableErrorCode? in
            if case let .invalid(code) = session.state { return code }
            return nil
        }).first {
            aggregate = .invalid(code)
        } else if sessions.contains(where: { $0.state == .restoring }) {
            aggregate = .restoring
        } else if sessions.contains(where: { $0.state == .takingOver }) {
            aggregate = .takingOver
        } else {
            aggregate = .discovering
        }

        let participant = !sessions.isEmpty
        let participationChanged = participant != isPolicyParticipant
        let stateChanged = aggregate != state
        isPolicyParticipant = participant
        state = aggregate
        if participationChanged || stateChanged {
            onStateChange?(aggregate)
        }
        if participationChanged {
            receiverDevice.setM720UnifyingIdentityActive(participant)
        }
    }

    private func updatePublishedState(_ newState: M720SessionState) {
        guard newState != state else { return }
        state = newState
        onStateChange?(newState)
    }

    private func beginTerminal(
        _ intent: TerminalIntent,
        completion: @escaping () -> Void
    ) {
        performOnMain { [weak self] in
            guard let self else {
                completion()
                return
            }
            if terminalFinished {
                DispatchQueue.main.async(execute: completion)
                return
            }
            terminalWaiters.append(completion)
            guard terminalIntent == .none else { return }
            terminalIntent = intent
            manager.onLinkEvent = nil

            let operation: (M720SessionControlling, @escaping () -> Void) -> Void
            switch intent {
            case .shutdown:
                operation = { $0.shutdown(completion: $1) }
            case .removal:
                operation = { $0.invalidateForRemoval(completion: $1) }
            case .none:
                return
            }
            runAcrossChildren(operation: operation) { [weak self] in
                guard let self else { return }
                manager.invalidate { [weak self] in
                    self?.performOnMain { [weak self] in self?.finishTerminal() }
                }
            }
        }
    }

    private func runAcrossChildren(
        operation: @escaping (
            M720SessionControlling,
            @escaping () -> Void
        ) -> Void,
        completion: @escaping () -> Void
    ) {
        let sessions = children.values.map(\.session)
        guard !sessions.isEmpty else {
            completion()
            return
        }
        var remaining = sessions.count
        var completed = false
        for session in sessions {
            operation(session) { [weak self] in
                self?.performOnMain {
                    guard !completed else { return }
                    remaining -= 1
                    guard remaining == 0 else { return }
                    completed = true
                    completion()
                }
            }
        }
    }

    private func finishTerminal() {
        guard !terminalFinished else { return }
        terminalFinished = true
        pendingOnlineSlots.removeAll()
        let wasParticipant = isPolicyParticipant
        isPolicyParticipant = false
        state = terminalIntent == .removal
            ? .invalid(.disconnected)
            : .invalid(.cancelled)
        if wasParticipant {
            onStateChange?(state)
            receiverDevice.setM720UnifyingIdentityActive(false)
        }
        let waiters = terminalWaiters
        terminalWaiters.removeAll()
        waiters.forEach { $0() }
    }

    private func performOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
