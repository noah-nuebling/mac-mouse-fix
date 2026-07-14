import Foundation

protocol M720AddModeClientTimer: AnyObject {
    func cancel()
}

private final class M720AddModeDispatchTimer: M720AddModeClientTimer {
    private let source: DispatchSourceTimer

    init(
        delay: TimeInterval,
        repeats: Bool,
        action: @escaping () -> Void
    ) {
        source = DispatchSource.makeTimerSource(queue: .main)
        if repeats {
            source.schedule(deadline: .now() + delay, repeating: delay)
        } else {
            source.schedule(deadline: .now() + delay)
        }
        source.setEventHandler(handler: action)
        source.resume()
    }

    func cancel() {
        source.setEventHandler {}
        source.cancel()
    }
}

final class M720AddModeClient {
    enum State: Equatable {
        case idle
        case preparing(UUID)
        case recording(UUID)
    }

    typealias MessageSender = (String, NSDictionary?, Bool) -> Any?
    typealias Executor = (@escaping () -> Void) -> Void
    typealias TimerFactory = (
        TimeInterval,
        Bool,
        @escaping () -> Void
    ) -> M720AddModeClientTimer

    private enum AcknowledgementPurpose {
        case prepare
        case renew
        case cancel
        case finish
    }

    private(set) var state: State = .idle
    var onStateChange: ((State) -> Void)?
    var onFailure: ((M720StableErrorCode) -> Void)?
    var onFeedback: ((NSDictionary) -> Void)?

    private var reducer = M720AddModeReducer()
    private var renewalTimer: M720AddModeClientTimer?
    private var deadlineTimer: M720AddModeClientTimer?

    private let requestIDFactory: () -> UUID
    private let now: () -> TimeInterval
    private let sendMessage: MessageSender
    private let executeIPC: Executor
    private let executeMain: Executor
    private let makeTimer: TimerFactory

#if IS_MAIN_APP
    convenience init() {
        let ipcQueue = DispatchQueue(label: "com.nuebling.mac-mouse-fix.m720-add-mode-ipc")
        self.init(
            requestIDFactory: UUID.init,
            now: { ProcessInfo.processInfo.systemUptime },
            sendMessage: { name, payload, waitForReply in
                MFMessagePort.sendMessage(
                    name,
                    withPayload: payload,
                    waitForReply: waitForReply
                )
            },
            executeIPC: { block in ipcQueue.async(execute: block) },
            executeMain: { block in DispatchQueue.main.async(execute: block) },
            makeTimer: { delay, repeats, action in
                M720AddModeDispatchTimer(
                    delay: delay,
                    repeats: repeats,
                    action: action
                )
            }
        )
    }
#endif

    init(
        requestIDFactory: @escaping () -> UUID,
        now: @escaping () -> TimeInterval,
        sendMessage: @escaping MessageSender,
        executeIPC: @escaping Executor,
        executeMain: @escaping Executor,
        makeTimer: @escaping TimerFactory
    ) {
        self.requestIDFactory = requestIDFactory
        self.now = now
        self.sendMessage = sendMessage
        self.executeIPC = executeIPC
        self.executeMain = executeMain
        self.makeTimer = makeTimer
    }

    func begin() {
        stopTimers()
        let requestID = requestIDFactory()
        reducer.begin(requestID, at: now())
        publishReducerState()
        startTimers()
        send(
            M720IPCMessage.prepareAddMode,
            request: M720IPCRequest(requestID: requestID),
            purpose: .prepare
        )
    }

    func cancel() {
        guard let requestID = reducer.currentRequestID else { return }
        stopTimers()
        guard reducer.cancel(requestID) == .handled else { return }
        publishReducerState()
        send(
            M720IPCMessage.cancelPreparation,
            request: M720IPCRequest(requestID: requestID),
            purpose: .cancel
        )
    }

    func handlePreparationResult(_ payload: Any?) {
        guard let result = try? M720PreparationResult.decode(payload) else {
            failMalformedMessageIfCurrent(payload)
            return
        }
        guard reducer.state == .preparing(result.requestID) else { return }

        switch result.outcome {
        case .ready:
            deadlineTimer?.cancel()
            deadlineTimer = nil
        case .failed, .conflict, .cancelled:
            stopTimers()
        }

        guard reducer.receivePreparationResult(
            requestID: result.requestID,
            result: result.outcome
        ) == .handled else { return }
        publishReducerState()

        switch result.outcome {
        case .ready, .cancelled:
            break
        case let .failed(failure):
            onFailure?(failure.stableError)
        case .conflict:
            onFailure?(.conflict)
        }
    }

    func handleFeedback(_ payload: Any?) {
        guard let feedback = try? M720AddModeFeedback.decode(payload) else {
            failMalformedMessageIfCurrent(payload)
            return
        }
        guard reducer.receiveFeedback(requestID: feedback.requestID) == .handled else {
            return
        }
        onFeedback?(feedback.feedback)
    }

    func handleStateChange(_ payload: Any?) {
        guard let change = try? M720AddModeStateChange.decode(payload) else {
            failMalformedMessageIfCurrent(payload)
            return
        }
        guard reducer.currentRequestID == change.requestID else { return }
        stopTimers()
        guard reducer.receiveInactive(requestID: change.requestID) == .handled else { return }
        publishReducerState()
    }

    func finishAfterSaving() {
        guard case let .recording(requestID) = reducer.state else { return }
        stopTimers()
        guard reducer.finishAfterSaving(requestID) == .handled else { return }
        publishReducerState()
        send(
            M720IPCMessage.finishAddMode,
            request: M720IPCRequest(requestID: requestID),
            purpose: .finish
        )
    }

    private func startTimers() {
        renewalTimer = makeTimer(
            M720AddModeReducer.renewalInterval,
            true
        ) { [weak self] in
            self?.renewalTimerFired()
        }
        deadlineTimer = makeTimer(
            M720AddModeReducer.preparationDeadline,
            false
        ) { [weak self] in
            self?.deadlineTimerFired()
        }
    }

    private func stopTimers() {
        renewalTimer?.cancel()
        deadlineTimer?.cancel()
        renewalTimer = nil
        deadlineTimer = nil
    }

    private func renewalTimerFired() {
        switch reducer.timerFired(at: now()) {
        case .none:
            break
        case let .renew(requestID):
            send(
                M720IPCMessage.renewLease,
                request: M720IPCRequest(requestID: requestID),
                purpose: .renew
            )
        case let .deadline(requestID):
            stopTimers()
            publishReducerState()
            onFailure?(.timeout)
            send(
                M720IPCMessage.cancelPreparation,
                request: M720IPCRequest(requestID: requestID),
                purpose: .cancel
            )
        }
    }

    private func deadlineTimerFired() {
        guard case let .preparing(requestID) = reducer.state else { return }
        stopTimers()
        guard reducer.timerFired(at: now()) == .deadline(requestID) else { return }
        publishReducerState()
        onFailure?(.timeout)
        send(
            M720IPCMessage.cancelPreparation,
            request: M720IPCRequest(requestID: requestID),
            purpose: .cancel
        )
    }

    private func send(
        _ name: String,
        request: M720IPCRequest,
        purpose: AcknowledgementPurpose
    ) {
        let requestID = request.requestID
        let payload = request.payload
        executeIPC { [sendMessage, executeMain, weak self] in
            let rawAcknowledgement = sendMessage(name, payload, true)
            executeMain {
                self?.handleAcknowledgement(
                    rawAcknowledgement,
                    requestID: requestID,
                    purpose: purpose
                )
            }
        }
    }

    private func handleAcknowledgement(
        _ raw: Any?,
        requestID: UUID,
        purpose: AcknowledgementPurpose
    ) {
        guard purpose == .prepare || purpose == .renew else { return }
        guard reducer.currentRequestID == requestID else { return }
        guard let acknowledgement = try? M720IPCAcknowledgement.decode(raw) else {
            failCurrent(requestID, error: .protocol)
            return
        }
        guard !acknowledgement.isAccepted, let error = acknowledgement.error else { return }
        failCurrent(requestID, error: error)
    }

    private func failMalformedMessageIfCurrent(_ payload: Any?) {
        guard let requestID = reducer.currentRequestID,
              let dictionary = payload as? NSDictionary
        else { return }
        guard let rawRequestID = dictionary["requestID"] as? String,
              let payloadRequestID = UUID(uuidString: rawRequestID),
              payloadRequestID == requestID
        else { return }
        failCurrent(requestID, error: .protocol)
    }

    private func failCurrent(_ requestID: UUID, error: M720StableErrorCode) {
        guard reducer.currentRequestID == requestID else { return }
        stopTimers()
        reducer.cancel(requestID)
        publishReducerState()
        onFailure?(error)
    }

    private func publishReducerState() {
        switch reducer.state {
        case .idle:
            state = .idle
        case let .preparing(requestID):
            state = .preparing(requestID)
        case let .recording(requestID):
            state = .recording(requestID)
        }
        onStateChange?(state)
    }
}
