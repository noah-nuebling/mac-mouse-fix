extension Result: SignalProducerConvertible {
	public var producer: SignalProducer<Success, Failure> {
		return .init(result: self)
	}
	
	internal var value: Success? {
		switch self {
		case let .success(value): return value
		case .failure: return nil
		}
	}
	
	internal var error: Failure? {
		switch self {
		case .success: return nil
		case let .failure(error): return error
		}
	}
}

/// A protocol that can be used to constrain associated types as `Result`.
internal protocol ResultProtocol {
	associatedtype Success
	associatedtype Failure: Swift.Error
	
	init(success: Success)
	init(failure: Failure)
	
	var result: Result<Success, Failure> { get }
}

extension Result: ResultProtocol {
	internal init(success: Success) {
		self = .success(success)
	}
	
	internal init(failure: Failure) {
		self = .failure(failure)
	}
	
	internal var result: Result<Success, Failure> {
		return self
	}
}
