import Foundation

extension Operators {
	internal final class Delay<Value, Error: Swift.Error>: UnaryAsyncOperator<Value, Value, Error> {
		let interval: TimeInterval
		let targetWithClock: DateScheduler

		init(
			downstream: Observer<Value, Error>,
			downstreamLifetime: Lifetime,
			target: DateScheduler,
			interval: TimeInterval
		) {
			precondition(interval >= 0)

			self.interval = interval
			self.targetWithClock = target
			super.init(downstream: downstream, downstreamLifetime: downstreamLifetime, target: target)
		}

		
		override func receive(_ value: Value) {
			guard isActive else { return }

			targetWithClock.schedule(after: computeNextDate()) {
				self.unscheduledSend(value)
			}
		}

		override func terminate(_ termination: Termination<Error>) {
			if case .completed = termination {
				targetWithClock.schedule(after: computeNextDate()) {
					super.terminate(.completed)
				}
			} else {
				super.terminate(termination)
			}
		}

		private func computeNextDate() -> Date {
			targetWithClock.currentDate.addingTimeInterval(interval)
		}
	}
}
