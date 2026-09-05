import CoreFoundation
import Foundation

enum M720IPCMessage {
    static let prepareAddMode = "prepareAddMode"
    static let preparationResult = "addModePreparationResult"
    static let cancelPreparation = "cancelAddModePreparation"
    static let renewLease = "renewAddModeLease"
    static let finishAddMode = "finishAddMode"
    static let addModeStateChanged = "addModeStateChanged"
    static let retryCapture = "retryM720Capture"
    static let captureStateChanged = "m720CaptureStateChanged"
    static let getCaptureStates = "getM720CaptureStates"
    static let getDiagnosticState = "getM720DiagnosticState"
}

enum M720IPCDecodeError: Error, Equatable {
    case protocolViolation
}

enum M720AddModePreparationState: String, CaseIterable, Equatable {
    case ready
    case failed
    case conflict
    case cancelled
}

enum M720AddModeInactiveReason: String, CaseIterable, Equatable {
    case saved
    case cancelled
    case deviceSetChanged
    case appUnavailable
}

enum M720SessionStateName: String, CaseIterable, Equatable {
    case discovering
    case nativeReady
    case takingOver
    case active
    case restoring
    case conflict
    case invalid
}

struct M720IPCRequest: Equatable {
    let requestID: UUID

    var payload: NSDictionary {
        ["requestID": requestID.uuidString]
    }

    static func decode(_ raw: Any?) throws -> Self {
        let dictionary = try M720IPCDecoder.dictionary(
            raw,
            required: ["requestID"]
        )
        return Self(requestID: try M720IPCDecoder.uuid(dictionary["requestID"]))
    }
}

struct M720RetryCaptureRequest: Equatable {
    let requestID: UUID
    let deviceToken: UUID

    var payload: NSDictionary {
        [
            "requestID": requestID.uuidString,
            "deviceToken": deviceToken.uuidString,
        ]
    }

    static func decode(_ raw: Any?) throws -> Self {
        let dictionary = try M720IPCDecoder.dictionary(
            raw,
            required: ["requestID", "deviceToken"]
        )
        return Self(
            requestID: try M720IPCDecoder.uuid(dictionary["requestID"]),
            deviceToken: try M720IPCDecoder.uuid(dictionary["deviceToken"])
        )
    }
}

struct M720IPCAcknowledgement: Equatable {
    let isAccepted: Bool
    let error: M720StableErrorCode?

    private init(isAccepted: Bool, error: M720StableErrorCode?) {
        self.isAccepted = isAccepted
        self.error = error
    }

    static let accepted = Self(isAccepted: true, error: nil)

    static func rejected(_ error: M720StableErrorCode) -> Self {
        Self(isAccepted: false, error: error)
    }

    var payload: NSDictionary {
        if let error {
            return ["accepted": isAccepted, "error": error.rawValue]
        }
        return ["accepted": isAccepted]
    }

    static func decode(_ raw: Any?) throws -> Self {
        let dictionary = try M720IPCDecoder.dictionary(
            raw,
            required: ["accepted"],
            optional: ["error"]
        )
        let accepted = try M720IPCDecoder.bool(dictionary["accepted"])
        let error = try dictionary["error"].map(M720IPCDecoder.errorCode)
        guard accepted ? error == nil : error != nil else {
            throw M720IPCDecodeError.protocolViolation
        }
        return Self(isAccepted: accepted, error: error)
    }
}

enum M720RetryAcknowledgementOutcome: Equatable {
    case accepted
    case failed(M720StableErrorCode)

    static func classify(_ raw: Any?) -> Self {
        guard let raw else { return .failed(.disconnected) }
        guard let acknowledgement = try? M720IPCAcknowledgement.decode(raw) else {
            return .failed(.protocol)
        }
        guard !acknowledgement.isAccepted else { return .accepted }
        guard let error = acknowledgement.error else { return .failed(.protocol) }
        return .failed(error)
    }
}

enum M720PreparationFailure: String, CaseIterable, Equatable {
    case unsupported
    case `protocol`
    case timeout
    case disconnected
    case deviceSetChanged
    case appUnavailable

    var stableError: M720StableErrorCode {
        switch self {
        case .unsupported: return .unsupported
        case .protocol: return .protocol
        case .timeout: return .timeout
        case .disconnected: return .disconnected
        case .deviceSetChanged: return .deviceSetChanged
        case .appUnavailable: return .appUnavailable
        }
    }

    init?(stableError: M720StableErrorCode) {
        self.init(rawValue: stableError.rawValue)
    }
}

enum M720PreparationOutcome: Equatable {
    case ready
    case failed(M720PreparationFailure)
    case conflict
    case cancelled
}

struct M720PreparationResult: Equatable {
    let requestID: UUID
    let outcome: M720PreparationOutcome
    let deviceTokens: [UUID]

    init(
        requestID: UUID,
        outcome: M720PreparationOutcome,
        deviceTokens: Set<UUID>
    ) {
        self.requestID = requestID
        self.outcome = outcome
        self.deviceTokens = deviceTokens.sorted(by: Self.uuidLessThan)
    }

    var state: M720AddModePreparationState {
        switch outcome {
        case .ready: return .ready
        case .failed: return .failed
        case .conflict: return .conflict
        case .cancelled: return .cancelled
        }
    }

    var error: M720StableErrorCode? {
        switch outcome {
        case .ready: return nil
        case let .failed(failure): return failure.stableError
        case .conflict: return .conflict
        case .cancelled: return .cancelled
        }
    }

    var payload: NSDictionary {
        let result = NSMutableDictionary(dictionary: [
            "requestID": requestID.uuidString,
            "state": state.rawValue,
            "deviceTokens": deviceTokens.map(\.uuidString),
        ])
        if let error {
            result["error"] = error.rawValue
        }
        return result
    }

    static func decode(_ raw: Any?) throws -> Self {
        let dictionary = try M720IPCDecoder.dictionary(
            raw,
            required: ["requestID", "state", "deviceTokens"],
            optional: ["error"]
        )
        let requestID = try M720IPCDecoder.uuid(dictionary["requestID"])
        let state = try M720IPCDecoder.stringEnum(
            dictionary["state"],
            as: M720AddModePreparationState.self
        )
        let error = try dictionary["error"].map(M720IPCDecoder.errorCode)
        let tokens = try M720IPCDecoder.uuidArray(dictionary["deviceTokens"])
        let outcome: M720PreparationOutcome
        switch state {
        case .ready:
            guard error == nil else { throw M720IPCDecodeError.protocolViolation }
            outcome = .ready
        case .failed:
            guard let error,
                  let failure = M720PreparationFailure(stableError: error)
            else { throw M720IPCDecodeError.protocolViolation }
            outcome = .failed(failure)
        case .conflict:
            guard error == .conflict else { throw M720IPCDecodeError.protocolViolation }
            outcome = .conflict
        case .cancelled:
            guard error == .cancelled else { throw M720IPCDecodeError.protocolViolation }
            outcome = .cancelled
        }
        return Self(
            requestID: requestID,
            outcome: outcome,
            deviceTokens: Set(tokens)
        )
    }

    private static func uuidLessThan(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}

struct M720AddModeStateChange: Equatable {
    let requestID: UUID
    let reason: M720AddModeInactiveReason

    var payload: NSDictionary {
        [
            "requestID": requestID.uuidString,
            "state": "inactive",
            "reason": reason.rawValue,
        ]
    }

    static func decode(_ raw: Any?) throws -> Self {
        let dictionary = try M720IPCDecoder.dictionary(
            raw,
            required: ["requestID", "state", "reason"]
        )
        guard try M720IPCDecoder.string(dictionary["state"]) == "inactive" else {
            throw M720IPCDecodeError.protocolViolation
        }
        return Self(
            requestID: try M720IPCDecoder.uuid(dictionary["requestID"]),
            reason: try M720IPCDecoder.stringEnum(
                dictionary["reason"],
                as: M720AddModeInactiveReason.self
            )
        )
    }
}

enum M720CaptureInvalidReason: String, CaseIterable, Equatable {
    case unsupported
    case `protocol`
    case timeout
    case conflict
    case disconnected
    case cancelled

    var stableError: M720StableErrorCode {
        switch self {
        case .unsupported: return .unsupported
        case .protocol: return .protocol
        case .timeout: return .timeout
        case .conflict: return .conflict
        case .disconnected: return .disconnected
        case .cancelled: return .cancelled
        }
    }

    init?(stableError: M720StableErrorCode) {
        self.init(rawValue: stableError.rawValue)
    }
}

enum M720CaptureStatus: Equatable {
    case discovering
    case nativeReady
    case takingOver
    case active
    case restoring
    case conflict
    case invalid(M720CaptureInvalidReason)
}

struct M720CaptureState: Equatable {
    let deviceToken: UUID
    let status: M720CaptureStatus
    let requiredCIDs: [UInt16]
    let requestID: UUID?

    init(
        deviceToken: UUID,
        status: M720CaptureStatus,
        requiredCIDs: Set<UInt16>,
        requestID: UUID?
    ) {
        self.deviceToken = deviceToken
        self.status = status
        self.requiredCIDs = requiredCIDs.sorted()
        self.requestID = requestID
    }

    var state: M720SessionStateName {
        switch status {
        case .discovering: return .discovering
        case .nativeReady: return .nativeReady
        case .takingOver: return .takingOver
        case .active: return .active
        case .restoring: return .restoring
        case .conflict: return .conflict
        case .invalid: return .invalid
        }
    }

    var error: M720StableErrorCode? {
        switch status {
        case .discovering, .nativeReady, .takingOver, .active, .restoring:
            return nil
        case .conflict:
            return .conflict
        case let .invalid(reason):
            return reason.stableError
        }
    }

    var payload: NSDictionary {
        let result = NSMutableDictionary(dictionary: [
            "deviceToken": deviceToken.uuidString,
            "state": state.rawValue,
            "requiredCIDs": requiredCIDs.map { NSNumber(value: $0) },
        ])
        if let error {
            result["error"] = error.rawValue
        }
        if let requestID {
            result["requestID"] = requestID.uuidString
        }
        return result
    }

    static func decode(_ raw: Any?) throws -> Self {
        let dictionary = try M720IPCDecoder.dictionary(
            raw,
            required: ["deviceToken", "state", "requiredCIDs"],
            optional: ["error", "requestID"]
        )
        let state = try M720IPCDecoder.stringEnum(
            dictionary["state"],
            as: M720SessionStateName.self
        )
        let error = try dictionary["error"].map(M720IPCDecoder.errorCode)
        let status: M720CaptureStatus
        switch state {
        case .conflict:
            guard error == .conflict else { throw M720IPCDecodeError.protocolViolation }
            status = .conflict
        case .invalid:
            guard let error,
                  let reason = M720CaptureInvalidReason(stableError: error)
            else { throw M720IPCDecodeError.protocolViolation }
            status = .invalid(reason)
        case .discovering:
            guard error == nil else { throw M720IPCDecodeError.protocolViolation }
            status = .discovering
        case .nativeReady:
            guard error == nil else { throw M720IPCDecodeError.protocolViolation }
            status = .nativeReady
        case .takingOver:
            guard error == nil else { throw M720IPCDecodeError.protocolViolation }
            status = .takingOver
        case .active:
            guard error == nil else { throw M720IPCDecodeError.protocolViolation }
            status = .active
        case .restoring:
            guard error == nil else { throw M720IPCDecodeError.protocolViolation }
            status = .restoring
        }
        return Self(
            deviceToken: try M720IPCDecoder.uuid(dictionary["deviceToken"]),
            status: status,
            requiredCIDs: Set(try M720IPCDecoder.cidArray(dictionary["requiredCIDs"])),
            requestID: try dictionary["requestID"].map(M720IPCDecoder.uuid)
        )
    }
}

struct M720CaptureStates: Equatable {
    let states: [M720CaptureState]

    init(states: [M720CaptureState]) {
        self.states = states.sorted { $0.deviceToken.uuidString < $1.deviceToken.uuidString }
    }

    var payload: NSDictionary {
        ["states": states.map(\.payload)]
    }

    static func decode(_ raw: Any?) throws -> Self {
        let dictionary = try M720IPCDecoder.dictionary(raw, required: ["states"])
        guard let array = dictionary["states"] as? NSArray else {
            throw M720IPCDecodeError.protocolViolation
        }
        let states = try array.map { try M720CaptureState.decode($0) }
        guard Set(states.map(\.deviceToken)).count == states.count else {
            throw M720IPCDecodeError.protocolViolation
        }
        return Self(states: states)
    }
}

struct M720DiagnosticRequestIdentity: Equatable {
    let feature: UInt8
    let function: UInt8
    let cid: UInt16?
    let generation: UInt64

    fileprivate var payload: NSDictionary {
        let result = NSMutableDictionary(dictionary: [
            "feature": NSNumber(value: feature),
            "function": NSNumber(value: function),
            "generation": NSNumber(value: generation),
        ])
        if let cid {
            result["cid"] = NSNumber(value: cid)
        }
        return result
    }

    fileprivate static func decode(_ raw: Any?) throws -> Self {
        let dictionary = try M720IPCDecoder.dictionary(
            raw,
            required: ["feature", "function", "generation"],
            optional: ["cid"]
        )
        return Self(
            feature: try M720IPCDecoder.uint8(dictionary["feature"]),
            function: try M720IPCDecoder.uint8(dictionary["function"]),
            cid: try dictionary["cid"].map(M720IPCDecoder.cid),
            generation: try M720IPCDecoder.uint64(dictionary["generation"])
        )
    }
}

struct M720DiagnosticSentCount: Equatable {
    let feature: UInt8
    let function: UInt8
    let count: UInt64

    fileprivate var payload: NSDictionary {
        [
            "feature": NSNumber(value: feature),
            "function": NSNumber(value: function),
            "count": NSNumber(value: count),
        ]
    }

    fileprivate static func decode(_ raw: Any?) throws -> Self {
        let dictionary = try M720IPCDecoder.dictionary(
            raw,
            required: ["feature", "function", "count"]
        )
        return Self(
            feature: try M720IPCDecoder.uint8(dictionary["feature"]),
            function: try M720IPCDecoder.uint8(dictionary["function"]),
            count: try M720IPCDecoder.uint64(dictionary["count"])
        )
    }
}

struct M720DiagnosticSessionSnapshot: Equatable {
    static let maximumRecentRequestCount = 256

    let deviceToken: UUID
    let state: M720SessionStateName
    let generation: UInt64
    let requiredCIDs: [UInt16]
    let appliedCIDs: [UInt16]
    let pressedCIDs: [UInt16]
    let sentCounts: [M720DiagnosticSentCount]
    let recentRequests: [M720DiagnosticRequestIdentity]

    init(
        deviceToken: UUID,
        state: M720SessionStateName,
        generation: UInt64,
        requiredCIDs: Set<UInt16>,
        appliedCIDs: Set<UInt16>,
        pressedCIDs: Set<UInt16>,
        sentCounts: [M720DiagnosticSentCount],
        recentRequests: [M720DiagnosticRequestIdentity]
    ) {
        self.deviceToken = deviceToken
        self.state = state
        self.generation = generation
        self.requiredCIDs = requiredCIDs.sorted()
        self.appliedCIDs = appliedCIDs.sorted()
        self.pressedCIDs = pressedCIDs.sorted()
        self.sentCounts = sentCounts.sorted {
            ($0.feature, $0.function) < ($1.feature, $1.function)
        }
        self.recentRequests = Array(recentRequests.suffix(Self.maximumRecentRequestCount))
    }

    fileprivate var payload: NSDictionary {
        [
            "deviceToken": deviceToken.uuidString,
            "state": state.rawValue,
            "generation": NSNumber(value: generation),
            "requiredCIDs": requiredCIDs.map { NSNumber(value: $0) },
            "appliedCIDs": appliedCIDs.map { NSNumber(value: $0) },
            "pressedCIDs": pressedCIDs.map { NSNumber(value: $0) },
            "sentCounts": sentCounts.map(\.payload),
            "recentRequests": recentRequests.map(\.payload),
        ]
    }

    fileprivate static func decode(_ raw: Any?) throws -> Self {
        let dictionary = try M720IPCDecoder.dictionary(
            raw,
            required: [
                "deviceToken",
                "state",
                "generation",
                "requiredCIDs",
                "appliedCIDs",
                "pressedCIDs",
                "sentCounts",
                "recentRequests",
            ]
        )
        let sentCounts = try M720IPCDecoder.array(dictionary["sentCounts"]).map(
            M720DiagnosticSentCount.decode
        )
        guard Set(sentCounts.map {
            UInt16($0.feature) << 8 | UInt16($0.function)
        }).count == sentCounts.count else {
            throw M720IPCDecodeError.protocolViolation
        }
        let recentRequests = try M720IPCDecoder.array(dictionary["recentRequests"]).map(
            M720DiagnosticRequestIdentity.decode
        )
        guard recentRequests.count <= maximumRecentRequestCount else {
            throw M720IPCDecodeError.protocolViolation
        }
        return Self(
            deviceToken: try M720IPCDecoder.uuid(dictionary["deviceToken"]),
            state: try M720IPCDecoder.stringEnum(
                dictionary["state"],
                as: M720SessionStateName.self
            ),
            generation: try M720IPCDecoder.uint64(dictionary["generation"]),
            requiredCIDs: Set(try M720IPCDecoder.cidArray(dictionary["requiredCIDs"])),
            appliedCIDs: Set(try M720IPCDecoder.cidArray(dictionary["appliedCIDs"])),
            pressedCIDs: Set(try M720IPCDecoder.cidArray(dictionary["pressedCIDs"])),
            sentCounts: sentCounts,
            recentRequests: recentRequests
        )
    }
}

struct M720HelperDiagnosticState: Equatable {
    let sessions: [M720DiagnosticSessionSnapshot]

    init(sessions: [M720DiagnosticSessionSnapshot]) {
        self.sessions = sessions.sorted { $0.deviceToken.uuidString < $1.deviceToken.uuidString }
    }

    var payload: NSDictionary {
        ["sessions": sessions.map(\.payload)]
    }

    static func decode(_ raw: Any?) throws -> Self {
        let dictionary = try M720IPCDecoder.dictionary(raw, required: ["sessions"])
        let sessions = try M720IPCDecoder.array(dictionary["sessions"]).map(
            M720DiagnosticSessionSnapshot.decode
        )
        guard Set(sessions.map(\.deviceToken)).count == sessions.count else {
            throw M720IPCDecodeError.protocolViolation
        }
        return Self(sessions: sessions)
    }
}

struct M720AddModeFeedback: Equatable {
    let requestID: UUID
    let feedback: NSDictionary

    var payload: NSDictionary {
        ["requestID": requestID.uuidString, "feedback": feedback]
    }

    static func decode(_ raw: Any?) throws -> Self {
        let dictionary = try M720IPCDecoder.dictionary(
            raw,
            required: ["requestID", "feedback"]
        )
        guard let feedback = dictionary["feedback"] as? NSDictionary,
              M720IPCDecoder.isPropertyListValue(feedback)
        else { throw M720IPCDecodeError.protocolViolation }
        return Self(
            requestID: try M720IPCDecoder.uuid(dictionary["requestID"]),
            feedback: feedback
        )
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.requestID == rhs.requestID && lhs.feedback.isEqual(rhs.feedback)
    }
}

struct M720AddModeReducer {
    enum State: Equatable {
        case idle
        case preparing(UUID)
        case recording(UUID)
    }

    enum EventResult: Equatable {
        case handled
        case ignored
    }

    enum TimerAction: Equatable {
        case none
        case renew(UUID)
        case deadline(UUID)
    }

    static let renewalInterval: TimeInterval = 2
    static let preparationDeadline: TimeInterval = 5

    private(set) var state: State = .idle
    private var nextRenewalAt: TimeInterval?
    private var deadlineAt: TimeInterval?

    @discardableResult
    mutating func begin(_ requestID: UUID, at time: TimeInterval = 0) -> EventResult {
        state = .preparing(requestID)
        nextRenewalAt = time + Self.renewalInterval
        deadlineAt = time + Self.preparationDeadline
        return .handled
    }

    @discardableResult
    mutating func cancel(_ requestID: UUID) -> EventResult {
        guard currentRequestID == requestID else { return .ignored }
        transitionToIdle()
        return .handled
    }

    @discardableResult
    mutating func receivePreparationResult(
        requestID: UUID,
        result: M720PreparationOutcome
    ) -> EventResult {
        guard state == .preparing(requestID) else { return .ignored }
        switch result {
        case .ready:
            state = .recording(requestID)
            deadlineAt = nil
        case .failed, .conflict, .cancelled:
            transitionToIdle()
        }
        return .handled
    }

    func receiveFeedback(requestID: UUID) -> EventResult {
        state == .recording(requestID) ? .handled : .ignored
    }

    @discardableResult
    mutating func receiveInactive(requestID: UUID) -> EventResult {
        guard currentRequestID == requestID else { return .ignored }
        transitionToIdle()
        return .handled
    }

    @discardableResult
    mutating func finishAfterSaving(_ requestID: UUID) -> EventResult {
        guard state == .recording(requestID) else { return .ignored }
        transitionToIdle()
        return .handled
    }

    mutating func timerFired(at time: TimeInterval) -> TimerAction {
        guard let requestID = currentRequestID else { return .none }
        if let deadlineAt, time >= deadlineAt {
            transitionToIdle()
            return .deadline(requestID)
        }
        guard let nextRenewalAt, time >= nextRenewalAt else { return .none }
        self.nextRenewalAt = time + Self.renewalInterval
        return .renew(requestID)
    }

    var currentRequestID: UUID? {
        switch state {
        case .idle:
            return nil
        case let .preparing(requestID), let .recording(requestID):
            return requestID
        }
    }

    private mutating func transitionToIdle() {
        state = .idle
        nextRenewalAt = nil
        deadlineAt = nil
    }
}

struct CaptureAlertKey: Equatable {
    let deviceToken: UUID
    let state: M720SessionStateName
    let errorCode: M720StableErrorCode?
}

struct M720CaptureAlertReducer {
    private struct ConflictTicket: Equatable {
        let key: CaptureAlertKey
        let generation: UInt64
    }

    private var nextGeneration: UInt64 = 0
    private var currentTicketByDevice: [UUID: ConflictTicket] = [:]
    private var pendingConflictTickets: [ConflictTicket] = []
    private var presentedGenerationByDevice: [UUID: UInt64] = [:]
    private var lastRetryErrorByDevice: [UUID: M720StableErrorCode] = [:]

    mutating func receive(_ snapshot: M720CaptureState) {
        let key = CaptureAlertKey(
            deviceToken: snapshot.deviceToken,
            state: snapshot.state,
            errorCode: snapshot.error
        )
        guard currentTicketByDevice[snapshot.deviceToken]?.key != key else { return }

        nextGeneration &+= 1
        let ticket = ConflictTicket(key: key, generation: nextGeneration)
        currentTicketByDevice[snapshot.deviceToken] = ticket
        pendingConflictTickets.removeAll { $0.key.deviceToken == snapshot.deviceToken }
        lastRetryErrorByDevice.removeValue(forKey: snapshot.deviceToken)
        if snapshot.state == .conflict {
            pendingConflictTickets.append(ticket)
        }
    }

    mutating func dequeueConflictForPresentation() -> CaptureAlertKey? {
        while !pendingConflictTickets.isEmpty {
            let ticket = pendingConflictTickets.removeFirst()
            let token = ticket.key.deviceToken
            guard ticket.key.state == .conflict,
                  currentTicketByDevice[token] == ticket,
                  presentedGenerationByDevice[token] != ticket.generation
            else { continue }
            presentedGenerationByDevice[token] = ticket.generation
            return ticket.key
        }
        return nil
    }

    mutating func shouldPresentRetryError(
        deviceToken: UUID,
        errorCode: M720StableErrorCode
    ) -> Bool {
        let previous = lastRetryErrorByDevice.updateValue(errorCode, forKey: deviceToken)
        return previous != errorCode
    }

    mutating func replaceSnapshot(_ snapshots: [M720CaptureState]) {
        let currentTokens = Set(snapshots.map(\.deviceToken))
        currentTicketByDevice = currentTicketByDevice.filter {
            currentTokens.contains($0.key)
        }
        presentedGenerationByDevice = presentedGenerationByDevice.filter {
            currentTokens.contains($0.key)
        }
        lastRetryErrorByDevice = lastRetryErrorByDevice.filter {
            currentTokens.contains($0.key)
        }
        pendingConflictTickets.removeAll {
            !currentTokens.contains($0.key.deviceToken)
        }
        for snapshot in snapshots {
            receive(snapshot)
        }
    }
}

struct M720EmptyPayload: Equatable {
    static func decode(_ raw: Any?) throws -> Self {
        guard raw == nil else { throw M720IPCDecodeError.protocolViolation }
        return Self()
    }
}

private enum M720IPCDecoder {
    static func dictionary(
        _ raw: Any?,
        required: Set<String>,
        optional: Set<String> = []
    ) throws -> NSDictionary {
        guard let dictionary = raw as? NSDictionary else {
            throw M720IPCDecodeError.protocolViolation
        }
        let keys = dictionary.allKeys.compactMap { $0 as? String }
        let keySet = Set(keys)
        guard keys.count == dictionary.count,
              required.isSubset(of: keySet),
              keySet.isSubset(of: required.union(optional))
        else { throw M720IPCDecodeError.protocolViolation }
        return dictionary
    }

    static func string(_ raw: Any?) throws -> String {
        guard let value = raw as? String else {
            throw M720IPCDecodeError.protocolViolation
        }
        return value
    }

    static func uuid(_ raw: Any?) throws -> UUID {
        let value = try string(raw)
        guard let uuid = UUID(uuidString: value) else {
            throw M720IPCDecodeError.protocolViolation
        }
        return uuid
    }

    static func bool(_ raw: Any?) throws -> Bool {
        guard let number = raw as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID()
        else { throw M720IPCDecodeError.protocolViolation }
        return number.boolValue
    }

    static func errorCode(_ raw: Any) throws -> M720StableErrorCode {
        guard let result = M720StableErrorCode(rawValue: try string(raw)) else {
            throw M720IPCDecodeError.protocolViolation
        }
        return result
    }

    static func stringEnum<T: RawRepresentable>(
        _ raw: Any?,
        as type: T.Type
    ) throws -> T where T.RawValue == String {
        guard let result = T(rawValue: try string(raw)) else {
            throw M720IPCDecodeError.protocolViolation
        }
        return result
    }

    static func uuidArray(_ raw: Any?) throws -> [UUID] {
        guard let array = raw as? NSArray else {
            throw M720IPCDecodeError.protocolViolation
        }
        let values = try array.map(uuid)
        guard Set(values).count == values.count else {
            throw M720IPCDecodeError.protocolViolation
        }
        return values.sorted { $0.uuidString < $1.uuidString }
    }

    static func array(_ raw: Any?) throws -> [Any] {
        guard let array = raw as? NSArray else {
            throw M720IPCDecodeError.protocolViolation
        }
        return array.map { $0 }
    }

    static func cidArray(_ raw: Any?) throws -> [UInt16] {
        guard let array = raw as? NSArray else {
            throw M720IPCDecodeError.protocolViolation
        }
        let values = try array.map(cid)
        guard Set(values).count == values.count else {
            throw M720IPCDecodeError.protocolViolation
        }
        return values.sorted()
    }

    static func cid(_ raw: Any) throws -> UInt16 {
        let value = try uint64(raw)
        guard value <= UInt64(UInt16.max) else {
            throw M720IPCDecodeError.protocolViolation
        }
        return UInt16(value)
    }

    static func uint8(_ raw: Any?) throws -> UInt8 {
        let value = try uint64(raw)
        guard value <= UInt64(UInt8.max) else {
            throw M720IPCDecodeError.protocolViolation
        }
        return UInt8(value)
    }

    static func uint64(_ raw: Any?) throws -> UInt64 {
        guard let number = raw as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID()
        else { throw M720IPCDecodeError.protocolViolation }
        switch CFNumberGetType(number) {
        case .float32Type, .float64Type, .floatType, .doubleType, .cgFloatType:
            throw M720IPCDecodeError.protocolViolation
        default:
            break
        }
        let value = number.int64Value
        guard value >= 0 else {
            throw M720IPCDecodeError.protocolViolation
        }
        return UInt64(value)
    }

    static func isPropertyListValue(_ raw: Any) -> Bool {
        var walker = PropertyListWalker()
        return walker.visit(raw, depth: 0)
    }

    private struct PropertyListWalker {
        private static let maximumDepth = 32
        private static let maximumNodeCount = 1_024

        private var seenContainers: Set<ObjectIdentifier> = []
        private var nodeCount = 0

        mutating func visit(_ raw: Any, depth: Int) -> Bool {
            guard depth <= Self.maximumDepth,
                  nodeCount < Self.maximumNodeCount
            else { return false }
            nodeCount += 1

            switch raw {
            case is NSString, is NSData, is NSDate:
                return true
            case let number as NSNumber:
                return number.doubleValue.isFinite
            case let array as NSArray:
                guard seenContainers.insert(ObjectIdentifier(array)).inserted else {
                    return false
                }
                for value in array {
                    guard visit(value, depth: depth + 1) else { return false }
                }
                return true
            case let dictionary as NSDictionary:
                guard seenContainers.insert(ObjectIdentifier(dictionary)).inserted else {
                    return false
                }
                for key in dictionary.allKeys {
                    guard key is NSString,
                          visit(key, depth: depth + 1),
                          let value = dictionary[key],
                          visit(value, depth: depth + 1)
                    else { return false }
                }
                return true
            default:
                return false
            }
        }
    }
}
