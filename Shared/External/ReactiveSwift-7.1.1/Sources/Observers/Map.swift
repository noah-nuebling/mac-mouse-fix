extension Operators {
	internal final class Map<InputValue, OutputValue, Error: Swift.Error>: Observer<InputValue, Error> {
		let downstream: Observer<OutputValue, Error>
		let transform: (InputValue) -> OutputValue

		init(downstream: Observer<OutputValue, Error>, transform: @escaping (InputValue) -> OutputValue) {
			self.downstream = downstream
			self.transform = transform
		}

		override func receive(_ value: InputValue) {
			downstream.receive(transform(value))
		}

		override func terminate(_ termination: Termination<Error>) {
			downstream.terminate(termination)
		}
	}
}
