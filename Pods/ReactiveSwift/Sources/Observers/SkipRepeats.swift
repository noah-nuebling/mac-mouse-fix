extension Operators {
	internal final class SkipRepeats<Value, Error: Swift.Error>: Observer<Value, Error> {
		let downstream: Observer<Value, Error>
		let isEquivalent: (Value, Value) -> Bool

		var previous: Value? = nil

		init(downstream: Observer<Value, Error>, isEquivalent: @escaping (Value, Value) -> Bool) {
			self.downstream = downstream
			self.isEquivalent = isEquivalent
		}

		override func receive(_ value: Value) {
			let isRepeating = previous.map { isEquivalent($0, value) } ?? false
			previous = value

			if !isRepeating {
				downstream.receive(value)
			}
		}

		override func terminate(_ termination: Termination<Error>) {
			downstream.terminate(termination)
		}
	}
}
