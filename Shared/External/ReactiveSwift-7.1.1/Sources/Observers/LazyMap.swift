extension Operators {
	internal final class LazyMap<Value, NewValue, Error: Swift.Error>: UnaryAsyncOperator<Value, NewValue, Error> {
		let transform: (Value) -> NewValue
		let box = Atomic<Value?>(nil)
	  let valueDisposable = SerialDisposable()

		init(
			downstream: Observer<NewValue, Error>,
			downstreamLifetime: Lifetime,
			target: Scheduler,
			transform: @escaping (Value) -> NewValue
		) {
			self.transform = transform
			super.init(downstream: downstream, downstreamLifetime: downstreamLifetime, target: target)

			downstreamLifetime += valueDisposable
		}

		override func receive(_ value: Value) {
			// Schedule only when there is no prior outstanding value.
			if box.swap(value) == nil {
				valueDisposable.inner = target.schedule {
					if let value = self.box.swap(nil) {
						self.unscheduledSend(self.transform(value))
					}
				}
			}
		}

		override func terminate(_ termination: Termination<Error>) {
			if case .interrupted = termination {
				// `interrupted` immediately cancels any scheduled value.
				//
				// On the other hand, completion and failure does not cancel anything, and is scheduled to run after any
				// scheduled value. `valueDisposable` will naturally be disposed by `downstreamLifetime` as soon as the
				// downstream has processed the termination.
				valueDisposable.dispose()
			}

			super.terminate(termination)
		}
	}
}
