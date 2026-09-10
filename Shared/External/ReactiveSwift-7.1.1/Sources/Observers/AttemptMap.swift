extension Operators {
	internal final class AttemptMap<InputValue, OutputValue, Error: Swift.Error>: Observer<InputValue, Error> {
		let downstream: Observer<OutputValue, Error>
		let transform: (InputValue) -> Result<OutputValue, Error>

		init(downstream: Observer<OutputValue, Error>, transform: @escaping (InputValue) -> Result<OutputValue, Error>) {
			self.downstream = downstream
			self.transform = transform
		}

		override func receive(_ value: InputValue) {
			switch transform(value) {
			case let .success(value):
				downstream.receive(value)
			case let .failure(error):
				downstream.terminate(.failed(error))
			}
		}

		override func terminate(_ termination: Termination<Error>) {
			downstream.terminate(termination)
		}
	}
}
