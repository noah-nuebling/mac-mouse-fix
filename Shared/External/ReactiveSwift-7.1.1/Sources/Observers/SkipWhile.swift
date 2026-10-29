extension Operators {
	internal final class SkipWhile<Value, Error: Swift.Error>: Observer<Value, Error> {
		let downstream: Observer<Value, Error>
		let shouldContinueToSkip: (Value) -> Bool
		var isSkipping = true

		init(downstream: Observer<Value, Error>, shouldContinueToSkip: @escaping (Value) -> Bool) {
			self.downstream = downstream
			self.shouldContinueToSkip = shouldContinueToSkip
		}

		override func receive(_ value: Value) {
			isSkipping = isSkipping && shouldContinueToSkip(value)

			if !isSkipping {
				downstream.receive(value)
			}
		}

		override func terminate(_ termination: Termination<Error>) {
			downstream.terminate(termination)
		}
	}
}
