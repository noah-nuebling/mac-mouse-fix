extension Operators {
	internal final class Materialize<Value, Error: Swift.Error>: Observer<Value, Error> {
		let downstream: Observer<Signal<Value, Error>.Event, Never>

		init(downstream: Observer<Signal<Value, Error>.Event, Never>) {
			self.downstream = downstream
		}

		override func receive(_ value: Value) {
			downstream.receive(.value(value))
		}

		override func terminate(_ termination: Termination<Error>) {
			downstream.receive(Signal<Value, Error>.Event(termination))

			switch termination {
			case .completed, .failed:
				downstream.terminate(.completed)
			case .interrupted:
				downstream.terminate(.interrupted)
			}
		}
	}
}
