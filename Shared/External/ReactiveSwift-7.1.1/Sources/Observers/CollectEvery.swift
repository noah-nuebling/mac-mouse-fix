import Dispatch

extension Operators {
	internal final class CollectEvery<Value, Error: Swift.Error>: UnaryAsyncOperator<Value, [Value], Error> {
		let interval: DispatchTimeInterval
		let discardWhenCompleted: Bool
		let targetWithClock: DateScheduler

		private let state: Atomic<CollectEveryState<Value>>
		private let timerDisposable = SerialDisposable()

		init(
			downstream: Observer<[Value], Error>,
			downstreamLifetime: Lifetime,
			target: DateScheduler,
			interval: DispatchTimeInterval,
			skipEmpty: Bool,
			discardWhenCompleted: Bool
		) {
			self.interval = interval
			self.discardWhenCompleted = discardWhenCompleted
			self.targetWithClock = target
			self.state = Atomic(CollectEveryState(skipEmpty: skipEmpty))

			super.init(downstream: downstream, downstreamLifetime: downstreamLifetime, target: target)

			downstreamLifetime += timerDisposable

			let initialDate = targetWithClock.currentDate.addingTimeInterval(interval)
			timerDisposable.inner = targetWithClock.schedule(after: initialDate, interval: interval, leeway: interval * 0.1) {
				let (currentValues, isCompleted) = self.state.modify { ($0.collect(), $0.isCompleted) }

				if let currentValues = currentValues {
					self.unscheduledSend(currentValues)
				}

				if isCompleted {
					self.unscheduledTerminate(.completed)
				}
			}
		}

		override func receive(_ value: Value) {
			state.modify { $0.values.append(value) }
		}

		override func terminate(_ termination: Termination<Error>) {
			guard isActive else { return }

			if case .completed = termination, !discardWhenCompleted {
				state.modify { $0.isCompleted = true }
			} else {
				timerDisposable.dispose()
				super.terminate(termination)
			}
		}
	}
}

private struct CollectEveryState<Value> {
	let skipEmpty: Bool
	var values: [Value] = []
	var isCompleted: Bool = false

	init(skipEmpty: Bool) {
		self.skipEmpty = skipEmpty
	}

	var hasValues: Bool {
		return !values.isEmpty || !skipEmpty
	}

	mutating func collect() -> [Value]? {
		guard hasValues else { return nil }
		defer { values.removeAll() }
		return values
	}
}
