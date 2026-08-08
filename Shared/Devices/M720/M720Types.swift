enum M720StableErrorCode: String, Codable, Equatable {
    case unsupported
    case `protocol`
    case timeout
    case conflict
    case disconnected
    case cancelled
    case deviceSetChanged
    case appUnavailable
}
