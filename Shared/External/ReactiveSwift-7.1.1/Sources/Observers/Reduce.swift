extension Operators {
	internal final class Reduce<Value, Result, Error: Swift.Error>: Observer<Value, Error> {
		let downstream: Observer<Result, Error>
		let nextPartialResult: (inout Result, Value) -> Void
		var accumulator: Result

		init(downstream: Observer<Result, Error>, initial: Result, nextPartialResult: @escaping (inout Result, Value) -> Void) {
			self.downstream = downstream
			self.accumulator = initial
			self.nextPartialResult = nextPartialResult
		}

		override func receive(_ value: Value) {
			nextPartialResult(&accumulator, value)
		}

		override func terminate(_ termination: Termination<Error>) {
			if case .completed = termination {
				downstream.receive(accumulator)
			}

			downstream.terminate(termination)
		}
	}
}
