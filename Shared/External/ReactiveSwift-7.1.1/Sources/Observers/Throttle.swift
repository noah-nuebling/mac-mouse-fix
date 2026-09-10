import Foundation

extension Operators {
	internal final class Throttle<Value, Error: Swift.Error>: UnaryAsyncOperator<Value, Value, Error> {
		let interval: TimeInterval
		let targetWithClock: DateScheduler

		private let state: Atomic<ThrottleState<Value>> = Atomic(ThrottleState())
		private let schedulerDisposable = SerialDisposable()

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

			downstreamLifetime += schedulerDisposable
		}

		override func receive(_ value: Value) {
			let scheduleDate: Date = state.modify { state in
				state.pendingValue = value

				let proposedScheduleDate: Date
				if let previousDate = state.previousDate, previousDate <= targetWithClock.currentDate {
					proposedScheduleDate = previousDate.addingTimeInterval(interval)
				} else {
					proposedScheduleDate = targetWithClock.currentDate
				}

				return proposedScheduleDate < targetWithClock.currentDate ? targetWithClock.currentDate : proposedScheduleDate
			}

			schedulerDisposable.inner = targetWithClock.schedule(after: scheduleDate) {
				guard self.isActive else { return }

				if let pendingValue = self.state.modify({ $0.retrieveValue(date: scheduleDate) }) {
					self.unscheduledSend(pendingValue)
				}
			}
		}
	}
}

private struct ThrottleState<Value> {
	var previousDate: Date?
	var pendingValue: Value?

	mutating func retrieveValue(date: Date) -> Value? {
		defer {
			if pendingValue != nil {
				pendingValue = nil
				previousDate = date
			}
		}
		return pendingValue
	}
}
