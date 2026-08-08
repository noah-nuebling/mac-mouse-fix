import Foundation
import IOKit

enum HIDPPRequestError: Error, Equatable {
    case transport(IOReturn)
    case malformed(HIDPPFrameError)
    case device(code: UInt8)
    case timeout
    case softwareIDsExhausted
    case invalidated
}

struct HIDPPRetryPolicy: Equatable {
    let timeout: TimeInterval
    let busyDelays: [TimeInterval]
    let timeoutDelays: [TimeInterval]

    static let m720 = HIDPPRetryPolicy(
        timeout: 1.0,
        busyDelays: [0.05, 0.20],
        timeoutDelays: [0.20]
    )
}

struct HIDPPSentRequest: Equatable {
    let identity: HIDPPRequestIdentity
    let parameters: [UInt8]
    let generation: UInt64
}

final class HIDPPRequestPipeline {
    var onEvent: ((HIDPPInbound) -> Void)?
    var onForeignResponse: ((HIDPPRequestIdentity) -> Void)?
    var onRequestSent: ((HIDPPSentRequest) -> Void)?

    private final class Request {
        let generation: UInt64
        let token: UInt64
        let featureIndex: UInt8
        let function: UInt8
        let parameters: [UInt8]
        let completion: (Result<Data, HIDPPRequestError>) -> Void
        var remainingBusyDelays: [TimeInterval]
        var remainingTimeoutDelays: [TimeInterval]
        var attempt: Attempt?
        var retryToken: UInt64?
        var retryCancellation: HIDPPCancellation?

        init(
            generation: UInt64,
            token: UInt64,
            featureIndex: UInt8,
            function: UInt8,
            parameters: [UInt8],
            retryPolicy: HIDPPRetryPolicy,
            completion: @escaping (Result<Data, HIDPPRequestError>) -> Void
        ) {
            self.generation = generation
            self.token = token
            self.featureIndex = featureIndex
            self.function = function
            self.parameters = parameters
            self.completion = completion
            remainingBusyDelays = retryPolicy.busyDelays
            remainingTimeoutDelays = retryPolicy.timeoutDelays
        }
    }

    private enum AttemptPhase {
        case sending
        case awaitingResponse
    }

    private struct Attempt {
        let token: UInt64
        let identity: HIDPPRequestIdentity
        var phase: AttemptPhase
        var timeoutCancellation: HIDPPCancellation?
    }

    private let transport: HIDPPTransport
    private let scheduler: HIDPPScheduler
    private let retryPolicy: HIDPPRetryPolicy
    private let stateQueue: DispatchQueue
    private let stateQueueKey = DispatchSpecificKey<UInt8>()
    private var pending: [Request] = []
    private var current: Request?
    private var nextSoftwareID: UInt8 = 0x8
    private var quarantinedSoftwareIDs: Set<UInt8> = []
    private var generation: UInt64 = 0
    private var nextRequestToken: UInt64 = 0
    private var nextAttemptToken: UInt64 = 0
    private var nextRetryToken: UInt64 = 0
    private var isInvalidated = false
    private var invalidationDrainFinished = false
    private var invalidationWaiters: [() -> Void] = []
    private var isPumpingRequests = false

    init(
        transport: HIDPPTransport,
        scheduler: HIDPPScheduler,
        retryPolicy: HIDPPRetryPolicy = .m720,
        stateQueue: DispatchQueue = .main
    ) {
        self.transport = transport
        self.scheduler = scheduler
        self.retryPolicy = retryPolicy
        self.stateQueue = stateQueue
        stateQueue.setSpecific(key: stateQueueKey, value: 1)
        transport.onReport = { [weak self] data in
            self?.marshalToStateQueue { [weak self] in self?.handleReport(data) }
        }
    }

    deinit {
        stateQueue.setSpecific(key: stateQueueKey, value: nil)
    }

    func perform(
        featureIndex: UInt8,
        function: UInt8,
        parameters: [UInt8],
        completion: @escaping (Result<Data, HIDPPRequestError>) -> Void
    ) {
        let submissionGeneration: UInt64?
        if DispatchQueue.getSpecific(key: stateQueueKey) != nil {
            submissionGeneration = generation
        } else {
            submissionGeneration = nil
        }

        stateQueue.async {
            guard
                !self.isInvalidated,
                submissionGeneration == nil || submissionGeneration == self.generation
            else {
                completion(.failure(.invalidated))
                return
            }
            let requestToken = self.nextRequestToken
            self.nextRequestToken &+= 1
            self.pending.append(Request(
                generation: self.generation,
                token: requestToken,
                featureIndex: featureIndex,
                function: function,
                parameters: parameters,
                retryPolicy: self.retryPolicy,
                completion: completion
            ))
            self.pumpRequests()
        }
    }

    func beginNewLifecycle() {
        marshalToStateQueue {
            guard !self.isInvalidated else { return }
            self.generation &+= 1
            self.failAllWorkAsInvalidated()
            self.quarantinedSoftwareIDs.removeAll()
        }
    }

    func invalidate() {
        invalidate(completion: {})
    }

    func invalidate(completion: @escaping () -> Void) {
        marshalToStateQueue {
            if self.invalidationDrainFinished {
                self.stateQueue.async(execute: completion)
                return
            }
            self.invalidationWaiters.append(completion)
            guard !self.isInvalidated else { return }
            self.isInvalidated = true
            self.generation &+= 1
            self.failAllWorkAsInvalidated()
            self.quarantinedSoftwareIDs.removeAll()
            self.transport.onReport = nil
            self.transport.invalidate { [self] in
                marshalToStateQueue { [self] in
                    finishInvalidationDrain()
                }
            }
        }
    }

    private func finishInvalidationDrain() {
        guard !invalidationDrainFinished else { return }
        invalidationDrainFinished = true
        let waiters = invalidationWaiters
        invalidationWaiters.removeAll()
        for waiter in waiters {
            waiter()
        }
    }

    private func pumpRequests() {
        guard !isPumpingRequests else { return }

        isPumpingRequests = true
        defer { isPumpingRequests = false }

        while !isInvalidated {
            if current == nil {
                guard !pending.isEmpty else { return }
                current = pending.removeFirst()
            }
            guard
                let request = current,
                request.generation == generation,
                request.attempt == nil,
                request.retryToken == nil
            else {
                return
            }
            startAttempt(for: request)
        }
    }

    private func startAttempt(for request: Request) {
        guard
            !isInvalidated,
            current === request,
            request.generation == generation,
            request.attempt == nil,
            request.retryToken == nil
        else {
            return
        }

        let softwareID: UInt8
        do {
            softwareID = try allocateSoftwareID()
        } catch let error as HIDPPRequestError {
            completeCurrent(.failure(error))
            return
        } catch {
            return
        }
        let identity = HIDPPRequestIdentity(
            featureIndex: request.featureIndex,
            function: request.function,
            softwareID: softwareID
        )
        let attemptToken = nextAttemptToken
        nextAttemptToken &+= 1
        request.attempt = Attempt(token: attemptToken, identity: identity, phase: .sending)
        let requestGeneration = request.generation
        let requestToken = request.token

        let report = HIDPPLongReport.request(
            deviceIndex: transport.deviceIndex,
            featureIndex: identity.featureIndex,
            function: identity.function,
            softwareID: identity.softwareID,
            parameters: request.parameters
        )
        onRequestSent?(HIDPPSentRequest(
            identity: identity,
            parameters: request.parameters,
            generation: requestGeneration
        ))
        transport.send(report.data) { [weak self] result in
            self?.marshalToStateQueue { [weak self] in
                self?.handleSendCompletion(
                    generation: requestGeneration,
                    requestToken: requestToken,
                    attemptToken: attemptToken,
                    identity: identity,
                    result: result
                )
            }
        }
    }

    private func allocateSoftwareID() throws -> UInt8 {
        for _ in 0..<8 {
            let candidate = nextSoftwareID
            nextSoftwareID = candidate == 0xF ? 0x8 : candidate + 1
            if !quarantinedSoftwareIDs.contains(candidate) {
                return candidate
            }
        }
        throw HIDPPRequestError.softwareIDsExhausted
    }

    private func handleSendCompletion(
        generation callbackGeneration: UInt64,
        requestToken: UInt64,
        attemptToken: UInt64,
        identity: HIDPPRequestIdentity,
        result: IOReturn
    ) {
        guard
            !isInvalidated,
            callbackGeneration == generation,
            let request = current,
            request.token == requestToken,
            var attempt = request.attempt,
            attempt.token == attemptToken,
            attempt.identity == identity,
            attempt.phase == .sending
        else {
            return
        }

        guard result == kIOReturnSuccess else {
            completeCurrent(.failure(.transport(result)))
            return
        }

        attempt.phase = .awaitingResponse
        request.attempt = attempt
        let timeoutCancellation = scheduler.schedule(after: retryPolicy.timeout) { [weak self] in
            self?.marshalToStateQueue { [weak self] in
                self?.handleTimeout(
                    generation: callbackGeneration,
                    requestToken: requestToken,
                    attemptToken: attemptToken,
                    identity: identity
                )
            }
        }
        guard
            !isInvalidated,
            callbackGeneration == generation,
            let currentRequest = current,
            currentRequest === request,
            currentRequest.token == requestToken,
            var currentAttempt = currentRequest.attempt,
            currentAttempt.token == attemptToken,
            currentAttempt.identity == identity,
            currentAttempt.phase == .awaitingResponse
        else {
            timeoutCancellation.cancel()
            return
        }
        currentAttempt.timeoutCancellation = timeoutCancellation
        currentRequest.attempt = currentAttempt
    }

    private func handleTimeout(
        generation callbackGeneration: UInt64,
        requestToken: UInt64,
        attemptToken: UInt64,
        identity: HIDPPRequestIdentity
    ) {
        guard
            !isInvalidated,
            callbackGeneration == generation,
            let request = current,
            request.token == requestToken,
            let attempt = request.attempt,
            attempt.token == attemptToken,
            attempt.identity == identity,
            attempt.phase == .awaitingResponse
        else {
            return
        }

        quarantinedSoftwareIDs.insert(identity.softwareID)
        request.attempt = nil
        guard !request.remainingTimeoutDelays.isEmpty else {
            completeCurrent(.failure(.timeout))
            return
        }

        scheduleRetry(for: request, after: request.remainingTimeoutDelays.removeFirst())
    }

    private func scheduleRetry(for request: Request, after delay: TimeInterval) {
        let callbackGeneration = request.generation
        let requestToken = request.token
        let retryToken = nextRetryToken
        nextRetryToken &+= 1
        request.retryToken = retryToken
        let cancellation = scheduler.schedule(after: delay) { [weak self, weak request] in
            self?.marshalToStateQueue { [weak self, weak request] in
                guard
                    let self,
                    let request,
                    !self.isInvalidated,
                    self.generation == callbackGeneration,
                    request.token == requestToken,
                    self.current === request,
                    request.retryToken == retryToken
                else {
                    return
                }
                request.retryToken = nil
                request.retryCancellation = nil
                self.pumpRequests()
            }
        }
        if request.retryToken == retryToken {
            request.retryCancellation = cancellation
        } else {
            cancellation.cancel()
        }
    }

    private func handleReport(_ data: Data) {
        guard !isInvalidated else { return }

        let inbound: HIDPPInbound
        do {
            inbound = try HIDPPLongReport.decode(
                data,
                acceptedDeviceIndices: transport.acceptedResponseDeviceIndices
            )
        } catch let error as HIDPPFrameError {
            guard current?.attempt != nil else { return }
            switch error {
            case .invalidLength, .invalidSoftwareID:
                completeCurrent(.failure(.malformed(error)))
            case .invalidReportID, .invalidDeviceIndex:
                break
            }
            return
        } catch {
            return
        }

        switch inbound {
        case let .response(identity, parameters):
            guard matchingRequest(for: identity) != nil else { return }
            completeCurrent(.success(parameters))
        case let .error(frame):
            guard let request = matchingRequest(for: frame.identity) else { return }
            if frame.code == 0x07, !request.remainingBusyDelays.isEmpty {
                let delay = request.remainingBusyDelays.removeFirst()
                request.attempt?.timeoutCancellation?.cancel()
                request.attempt = nil
                scheduleRetry(for: request, after: delay)
            } else {
                completeCurrent(.failure(.device(code: frame.code)))
            }
        case .event:
            onEvent?(inbound)
        }
    }

    private func matchingRequest(for identity: HIDPPRequestIdentity) -> Request? {
        guard let request = current, let attempt = request.attempt else {
            onForeignResponse?(identity)
            return nil
        }
        guard identity.softwareID == attempt.identity.softwareID else {
            onForeignResponse?(identity)
            return nil
        }
        guard identity == attempt.identity else { return nil }
        return request
    }

    private func completeCurrent(_ result: Result<Data, HIDPPRequestError>) {
        guard let request = current else { return }
        request.attempt?.timeoutCancellation?.cancel()
        request.retryCancellation?.cancel()
        request.attempt = nil
        request.retryToken = nil
        request.retryCancellation = nil
        current = nil
        request.completion(result)
        pumpRequests()
    }

    private func failAllWorkAsInvalidated() {
        let active = current
        let queued = pending
        current = nil
        pending.removeAll()

        active?.attempt?.timeoutCancellation?.cancel()
        active?.retryCancellation?.cancel()
        active?.attempt = nil
        active?.retryToken = nil
        active?.retryCancellation = nil

        active?.completion(.failure(.invalidated))
        for request in queued {
            request.completion(.failure(.invalidated))
        }
    }

    private func marshalToStateQueue(_ block: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: stateQueueKey) != nil {
            block()
        } else {
            stateQueue.async(execute: block)
        }
    }
}
