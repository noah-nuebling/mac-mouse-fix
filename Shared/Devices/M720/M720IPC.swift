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
    private var lastObservedKeyByDevice: [UUID: CaptureAlertKey] = [:]

    mutating func shouldPresent(_ snapshot: M720CaptureState) -> Bool {
        let key = CaptureAlertKey(
            deviceToken: snapshot.deviceToken,
            state: snapshot.state,
            errorCode: snapshot.error
        )
        let previous = lastObservedKeyByDevice.updateValue(
            key,
            forKey: snapshot.deviceToken
        )
        guard snapshot.state == .conflict else { return false }
        return previous != key
    }

    mutating func shouldPresentRetryError(
        deviceToken: UUID,
        errorCode: M720StableErrorCode
    ) -> Bool {
        let key = CaptureAlertKey(
            deviceToken: deviceToken,
            state: .invalid,
            errorCode: errorCode
        )
        let previous = lastObservedKeyByDevice.updateValue(key, forKey: deviceToken)
        return previous != key
    }

    mutating func replaceSnapshot(_ snapshots: [M720CaptureState]) -> [M720CaptureState] {
        let currentTokens = Set(snapshots.map(\.deviceToken))
        lastObservedKeyByDevice = lastObservedKeyByDevice.filter {
            currentTokens.contains($0.key)
        }
        return snapshots.filter { shouldPresent($0) }
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

    private static func cid(_ raw: Any) throws -> UInt16 {
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
        guard (0...Int64(UInt16.max)).contains(value) else {
            throw M720IPCDecodeError.protocolViolation
        }
        return UInt16(value)
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
