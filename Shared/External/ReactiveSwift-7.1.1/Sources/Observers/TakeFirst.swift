extension Operators {
	internal final class TakeFirst<Value, Error: Swift.Error>: Observer<Value, Error> {
		let downstream: Observer<Value, Error>
		let count: Int
		var taken: Int = 0

		init(downstream: Observer<Value, Error>, count: Int) {
			precondition(count >= 1)

			self.downstream = downstream
			self.count = count
		}

		override func receive(_ value: Value) {
			if taken < count {
				taken += 1
				downstream.receive(value)
			}

			if taken == count {
				downstream.terminate(.completed)
			}
		}

		override func terminate(_ termination: Termination<Error>) {
			downstream.terminate(termination)
		}
	}
}
