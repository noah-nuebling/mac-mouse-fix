extension Operators {
	internal final class MaterializeAsResult<Value, Error: Swift.Error>: Observer<Value, Error> {
		let downstream: Observer<Result<Value, Error>, Never>

		init(downstream: Observer<Result<Value, Error>, Never>) {
			self.downstream = downstream
		}

		override func receive(_ value: Value) {
			downstream.receive(.success(value))
		}

		override func terminate(_ termination: Termination<Error>) {
			switch termination {
			case .completed:
				downstream.terminate(.completed)
			case let .failed(error):
				downstream.receive(.failure(error))
				downstream.terminate(.completed)
			case .interrupted:
				downstream.terminate(.interrupted)
			}
		}
	}
}
