extension Operators {
	internal final class SkipFirst<Value, Error: Swift.Error>: Observer<Value, Error> {
		let downstream: Observer<Value, Error>
		let count: Int
		var skipped: Int = 0

		init(downstream: Observer<Value, Error>, count: Int) {
			precondition(count >= 1)

			self.downstream = downstream
			self.count = count
		}

		override func receive(_ value: Value) {
			if skipped < count {
				skipped += 1
			} else {
				downstream.receive(value)
			}
		}

		override func terminate(_ termination: Termination<Error>) {
			downstream.terminate(termination)
		}
	}
}
