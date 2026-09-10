import Foundation

extension Operators {
	internal final class Debounce<Value, Error: Swift.Error>: UnaryAsyncOperator<Value, Value, Error> {
		let interval: TimeInterval
		let discardWhenCompleted: Bool
		let targetWithClock: DateScheduler

		private let state: Atomic<DebounceState<Value>> = Atomic(DebounceState())
		private let schedulerDisposable = SerialDisposable()

		init(
			downstream: Observer<Value, Error>,
			downstreamLifetime: Lifetime,
			target: DateScheduler,
			interval: TimeInterval,
			discardWhenCompleted: Bool
		) {
			precondition(interval >= 0)

			self.interval = interval
			self.discardWhenCompleted = discardWhenCompleted
			self.targetWithClock = target

			super.init(downstream: downstream, downstreamLifetime: downstreamLifetime, target: target)

			downstreamLifetime += schedulerDisposable
		}

		override func receive(_ value: Value) {
			let now = targetWithClock.currentDate

			state.modify { state in
				state.lastUpdated = now
				state.pendingValue = value
			}
			let targetDate = now.addingTimeInterval(interval)
			schedulerDisposable.inner = targetWithClock.schedule(after: targetDate) {
				if let pendingValue = self.state.modify({ $0.retrieve() }) {
					self.unscheduledSend(pendingValue)
				}
			}
		}

		override func terminate(_ termination: Termination<Error>) {
			guard isActive else { return }
			schedulerDisposable.dispose()

			if case .completed = termination {
				let pending: (value: Value?, lastUpdated: Date) = state.modify { state in
					return (state.retrieve(), state.lastUpdated)
				}

				if !discardWhenCompleted, let pendingValue = pending.value {
					targetWithClock.schedule(after: pending.lastUpdated.addingTimeInterval(interval)) {
						self.unscheduledSend(pendingValue)
						super.terminate(.completed)
					}
				} else {
					super.terminate(.completed)
				}
			} else {
				super.terminate(termination)
			}
		}
	}
}

private struct DebounceState<Value> {
	var lastUpdated: Date = .distantPast
	var pendingValue: Value?

	mutating func retrieve() -> Value? {
		defer { pendingValue = nil }
		return pendingValue
	}
}
