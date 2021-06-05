extension Operators {
	internal final class Dematerialize<Event>: Observer<Event, Never> where Event: EventProtocol {
		let downstream: Observer<Event.Value, Event.Error>

		init(downstream: Observer<Event.Value, Event.Error>) {
			self.downstream = downstream
		}

		override func receive(_ event: Event) {
			switch event.event {
			case let .value(value):
				downstream.receive(value)
			case .completed:
				downstream.terminate(.completed)
			case .interrupted:
				downstream.terminate(.interrupted)
			case let .failed(error):
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
