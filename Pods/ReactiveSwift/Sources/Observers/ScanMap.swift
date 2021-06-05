extension Operators {
	internal final class ScanMap<Value, State, Result, Error: Swift.Error>: Observer<Value, Error> {
		let downstream: Observer<Result, Error>
		let next: (inout State, Value) -> Result
		var accumulator: State

		init(downstream: Observer<Result, Error>, initial: State, next: @escaping (inout State, Value) -> Result) {
			self.downstream = downstream
			self.accumulator = initial
			self.next = next
		}

		override func receive(_ value: Value) {
			let result = next(&accumulator, value)
			downstream.receive(result)
		}

		override func terminate(_ termination: Termination<Error>) {
			downstream.terminate(termination)
		}
	}
}
