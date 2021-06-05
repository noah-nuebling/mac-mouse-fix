extension Operators {
	internal final class Filter<Value, Error: Swift.Error>: Observer<Value, Error> {
		let downstream: Observer<Value, Error>
		let predicate: (Value) -> Bool
		
		init(downstream: Observer<Value, Error>, predicate: @escaping (Value) -> Bool) {
			self.downstream = downstream
			self.predicate = predicate
		}
		
		override func receive(_ value: Value) {
			if predicate(value) {
				downstream.receive(value)
			}
		}
		
		override func terminate(_ termination: Termination<Error>) {
			downstream.terminate(termination)
		}
	}
}
