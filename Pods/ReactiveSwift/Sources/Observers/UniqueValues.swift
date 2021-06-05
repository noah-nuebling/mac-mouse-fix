extension Operators {
	internal final class UniqueValues<Value, Identity: Hashable, Error: Swift.Error>: Observer<Value, Error> {
		let downstream: Observer<Value, Error>
		let extract: (Value) -> Identity

		var seenIdentities: Set<Identity> = []

		init(downstream: Observer<Value, Error>, extract: @escaping (Value) -> Identity) {
			self.downstream = downstream
			self.extract = extract
		}

		override func receive(_ value: Value) {
			let identity = extract(value)
			let (inserted, _) = seenIdentities.insert(identity)

			if inserted {
				downstream.receive(value)
			}
		}

		override func terminate(_ termination: Termination<Error>) {
			downstream.terminate(termination)
		}
	}
}
