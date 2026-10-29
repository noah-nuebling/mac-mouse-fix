extension Operators {
	internal final class TakeUntil<Value, Error: Swift.Error>: Observer<Value, Error> {
		let downstream: Observer<Value, Error>
		let shouldContinue: (Value) -> Bool

		init(downstream: Observer<Value, Error>, shouldContinue: @escaping (Value) -> Bool) {
			self.downstream = downstream
			self.shouldContinue = shouldContinue
		}

		override func receive(_ value: Value) {
			downstream.receive(value)
			
			if !shouldContinue(value) {
				downstream.terminate(.completed)
			}
		}

		override func terminate(_ termination: Termination<Error>) {
			downstream.terminate(termination)
		}
	}
}
