extension Operators {
	internal final class ObserveOn<Value, Error: Swift.Error>: UnaryAsyncOperator<Value, Value, Error> {
		override func receive(_ value: Value) {
			target.schedule {
				guard !self.downstreamLifetime.hasEnded else { return }
				self.unscheduledSend(value)
			}
		}
	}
}
