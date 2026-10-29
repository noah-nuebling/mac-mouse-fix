internal class UnaryAsyncOperator<InputValue, OutputValue, Error: Swift.Error>: Observer<InputValue, Error> {
	let downstreamLifetime: Lifetime
	let target: Scheduler

	/// Whether or not the downstream observer can still receive values or termination.
	///
	/// - note: This is a thread-safe atomic read. So you can use it in any part of `receive(_:)` or `terminate(_:)` to
	///         attempt to early out before expensive scheduling or computation.
	var isActive: Bool { state.is(.active) }

	// Direct access is discouraged for subclasses by keeping this private.
	private let downstream: Observer<OutputValue, Error>
	private let state: UnsafeAtomicState<AsyncOperatorState>

	public init(
		downstream: Observer<OutputValue, Error>,
		downstreamLifetime: Lifetime,
		target: Scheduler
	) {
		self.downstream = downstream
		self.downstreamLifetime = downstreamLifetime
		self.target = target
		self.state = UnsafeAtomicState(.active)

		super.init()

		downstreamLifetime.observeEnded {
			if self.state.tryTransition(from: .active, to: .terminated) {
				target.schedule {
						downstream.terminate(.interrupted)
				}
			}
		}
	}

	deinit {
		state.deinitialize()
	}

	open override func receive(_ value: InputValue) { fatalError() }

	/// Send a value to the downstream without any implicit scheduling on `target`.
	///
	/// - important: Subclasses must invoke this only after having hopped onto the target scheduler.
	final func unscheduledSend(_ value: OutputValue) {
		downstream.receive(value)
	}

	/// Signal termination to the downstream without any implicit scheduling on `target`.
	///
	/// - important: Subclasses must invoke this only after having hopped onto the target scheduler.
	final func unscheduledTerminate(_ termination: Termination<Error>) {
		if self.state.tryTransition(from: .active, to: .terminated) {
			if case .completed = termination {
				self.onCompleted()
			}

			self.downstream.terminate(termination)
		}
	}

	open override func terminate(_ termination: Termination<Error>) {
		// The atomic transition here must happen **after** we hop onto the target scheduler. This is to preserve the timing
		// behaviour observed in previous versions of ReactiveSwift.

		target.schedule {
			self.unscheduledTerminate(termination)
		}
	}

	open func onCompleted() {}
}

private enum AsyncOperatorState: Int32 {
	case active
	case terminated
}
