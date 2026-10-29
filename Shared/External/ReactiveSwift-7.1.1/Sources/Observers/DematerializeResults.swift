extension Operators {
	internal final class DematerializeResults<Result>: Observer<Result, Never> where Result: ResultProtocol {
		let downstream: Observer<Result.Success, Result.Failure>

		init(downstream: Observer<Result.Success, Result.Failure>) {
			self.downstream = downstream
		}

		override func receive(_ value: Result) {
			switch value.result {
			case let .success(value):
				downstream.receive(value)
			case let .failure(error):
				downstream.terminate(.failed(error))
			}
		}

		override func terminate(_ termination: Termination<Never>) {
			switch termination {
			case .completed:
				downstream.terminate(.completed)
			case .interrupted:
				downstream.terminate(.interrupted)
			}
		}
	}
}
