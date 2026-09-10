open class Observer<Value, Error: Swift.Error> {
	public init() {}

	open func receive(_ value: Value) { fatalError() }
	open func terminate(_ termination: Termination<Error>) { fatalError() }
}

extension Observer {
	internal func assumeUnboundDemand() -> Signal<Value, Error>.Observer {
		Signal.Observer(self.process)
	}

	internal func callAsFunction(_ event: Signal<Value, Error>.Event) {
		process(event)
	}

	fileprivate func process(_ event: Signal<Value, Error>.Event) {
		switch event {
		case let .value(value):
			receive(value)
		case let .failed(error):
			terminate(.failed(error))
		case .completed:
			terminate(.completed)
		case .interrupted:
			terminate(.interrupted)
		}
	}
}

public enum Termination<Error: Swift.Error> {
	case failed(Error)
	case completed
	case interrupted
}

extension Signal.Event {
	init(_ termination: Termination<Error>) {
		switch termination {
		case .completed:
			self = .completed
		case .interrupted:
			self = .interrupted
		case let .failed(error):
			self = .failed(error)
		}
	}
}
