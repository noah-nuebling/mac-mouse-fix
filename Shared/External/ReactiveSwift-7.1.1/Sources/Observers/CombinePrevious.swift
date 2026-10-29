extension Operators {
	internal final class CombinePrevious<Value, Error: Swift.Error>: Observer<Value, Error> {
		let downstream: Observer<(Value, Value), Error>
		var previous: Value?

		init(downstream: Observer<(Value, Value), Error>, initial: Value?) {
			self.downstream = downstream
			self.previous = initial
		}

		override func receive(_ value: Value) {
			if let previous = previous {
				downstream.receive((previous, value))
			}

			previous = value
		}

		override func terminate(_ termination: Termination<Error>) {
			downstream.terminate(termination)
		}
	}
}
