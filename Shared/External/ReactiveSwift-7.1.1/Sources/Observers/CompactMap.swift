extension Operators {
	internal final class CompactMap<InputValue, OutputValue, Error: Swift.Error>: Observer<InputValue, Error> {
		let downstream: Observer<OutputValue, Error>
		let transform: (InputValue) -> OutputValue?
		
		init(downstream: Observer<OutputValue, Error>, transform: @escaping (InputValue) -> OutputValue?) {
			self.downstream = downstream
			self.transform = transform
		}
		
		override func receive(_ value: InputValue) {
			if let output = transform(value) {
				downstream.receive(output)
			}
		}
		
		override func terminate(_ termination: Termination<Error>) {
			downstream.terminate(termination)
		}
	}
}
