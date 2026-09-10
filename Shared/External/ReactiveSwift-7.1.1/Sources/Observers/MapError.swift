extension Operators {
	internal final class MapError<Value, InputError: Swift.Error, OutputError: Swift.Error>: Observer<Value, InputError> {
		let downstream: Observer<Value, OutputError>
		let transform: (InputError) -> OutputError

		init(downstream: Observer<Value, OutputError>, transform: @escaping (InputError) -> OutputError) {
			self.downstream = downstream
			self.transform = transform
		}

		override func receive(_ value: Value) {
			downstream.receive(value)
		}

		override func terminate(_ termination: Termination<InputError>) {
			switch termination {
			case .completed:
				downstream.terminate(.completed)
			case let .failed(error):
				downstream.terminate(.failed(transform(error)))
			case .interrupted:
				downstream.terminate(.interrupted)
			}
		}
	}
}
