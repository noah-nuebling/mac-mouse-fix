import Foundation
import Dispatch

/// A push-driven stream that sends Events over time, parameterized by the type
/// of values being sent (`Value`) and the type of failure that can occur
/// (`Error`). If no failures should be possible, Never can be specified for
/// `Error`.
///
/// An observer of a Signal will see the exact same sequence of events as all
/// other observers. In other words, events will be sent to all observers at the
/// same time.
///
/// Signals are generally used to represent event streams that are already “in
/// progress,” like notifications, user input, etc. To represent streams that
/// must first be _started_, see the SignalProducer type.
///
/// A Signal is kept alive until either of the following happens:
///    1. its input observer receives a terminating event; or
///    2. it has no active observers, and is not being retained.
public final class Signal<Value, Error: Swift.Error> {
	/// The `Signal` core which manages the event stream.
	///
	/// A `Signal` is the externally retained shell of the `Signal` core. The separation
	/// enables an explicit metric for the `Signal` self-disposal in case of having no
	/// observer and no external retain.
	///
	/// `Signal` ownership graph from the perspective of an operator.
	/// Note that there is no circular strong reference in the graph.
	/// ```
	///  ------------               --------------                --------
	///  |          |               | endObserve |                |      |
	///  |          | <~~ weak ~~~  | disposable | <== strong === |      |
	///  |          |               --------------                |      | ... downstream(s)
	///  | Upstream |                ------------                 |      |
	///  | Core     | === strong ==> | Observer |  === strong ==> | Core |
	///  ------------ ===\\          ------------                 -------- ===\\
	///                   \\         ------------------              ^^        \\
	///                    \\        | Signal (shell) | === strong ==//         \\
	///                     \\       ------------------                          \\
	///                     || strong                                            || strong
	///                     vv                                                   vv
	///            -------------------                                 -------------------
	///            | Other observers |                                 | Other observers |
	///            -------------------                                 -------------------
	/// ```
	private let core: Core

	private final class Core {
		/// The disposable associated with the signal.
		///
		/// Disposing of `disposable` is assumed to remove the generator
		/// observer from its attached `Signal`, so that the generator observer
		/// as the last +1 retain of the `Signal` core may deinitialize.
		private let disposable: CompositeDisposable

		/// The state of the signal.
		private var state: State

		/// Used to ensure that all state accesses are serialized.
		private let stateLock: Lock

		/// Used to ensure that events are serialized during delivery to observers.
		private let sendLock: Lock

		fileprivate init(_ generator: (Observer, Lifetime) -> Void) {
			state = .alive(Bag(), hasDeinitialized: false)

			stateLock = Lock.make()
			sendLock = Lock.make()
			disposable = CompositeDisposable()

			// The generator observer retains the `Signal` core.
			generator(Observer(action: self.send, interruptsOnDeinit: true), Lifetime(disposable))
		}

		private func send(_ event: Event) {
			if event.isTerminating {
				// Recursive events are disallowed for `value` events, but are permitted
				// for termination events. Specifically:
				//
				// - `interrupted`
				// It can inadvertently be sent by downstream consumers as part of the
				// `SignalProducer` mechanics.
				//
				// - `completed`
				// If a downstream consumer weakly references an object, invocation of
				// such consumer may cause a race condition with its weak retain against
				// the last strong release of the object. If the `Lifetime` of the
				// object is being referenced by an upstream `take(during:)`, a
				// signal recursion might occur.
				//
				// So we would treat termination events specially. If it happens to
				// occur while the `sendLock` is acquired, the observer call-out and
				// the disposal would be delegated to the current sender, or
				// occasionally one of the senders waiting on `sendLock`.

				self.stateLock.lock()

				if case let .alive(observers, _) = state {
					self.state = .terminating(observers, .init(event))
					self.stateLock.unlock()
				} else {
					self.stateLock.unlock()
				}

				tryToCommitTermination()
			} else {
				self.sendLock.lock()
				self.stateLock.lock()

				if case let .alive(observers, _) = self.state {
					self.stateLock.unlock()

					for observer in observers {
						observer.send(event)
					}
				} else {
					self.stateLock.unlock()
				}

				self.sendLock.unlock()

				// Check if the status has been bumped to `terminating` due to a
				// terminal event being sent concurrently or recursively.
				//
				// The check is deliberately made outside of the `sendLock` so that it
				// covers also any potential concurrent terminal event in one shot.
				//
				// Related PR:
				// https://github.com/ReactiveCocoa/ReactiveSwift/pull/112
				//
				// While calling `tryToCommitTermination` is sufficient, this is a fast
				// path for the recurring value delivery.
				//
				// Note that this cannot be `try` since any concurrent observer bag
				// manipulation might then cause the terminating state being missed.
				stateLock.lock()
				if case .terminating = state {
					stateLock.unlock()
					tryToCommitTermination()
				} else {
					stateLock.unlock()
				}
			}
		}

		/// Observe the Signal by sending any future events to the given observer.
		///
		/// - parameters:
		///   - observer: An observer to forward the events to.
		///
		/// - returns: A `Disposable` which can be used to disconnect the observer,
		///            or `nil` if the signal has already terminated.
		fileprivate func observe(_ observer: Observer) -> Disposable? {
			var token: Bag<Observer>.Token?

			stateLock.lock()

			if case let .alive(observers, hasDeinitialized) = state {
				var newObservers = observers
				token = newObservers.insert(observer)
				self.state = .alive(newObservers, hasDeinitialized: hasDeinitialized)
			}

			stateLock.unlock()

			if let token = token {
				return AnyDisposable { [weak self] in
					self?.removeObserver(with: token)
				}
			} else {
				observer.sendInterrupted()
				return nil
			}
		}

		/// Remove the observer associated with the given token.
		///
		/// - parameters:
		///   - token: The token of the observer to remove.
		private func removeObserver(with token: Bag<Observer>.Token) {
			stateLock.lock()

			if case let .alive(observers, hasDeinitialized) = state {
				var newObservers = observers
				let observer = newObservers.remove(using: token)
				self.state = .alive(newObservers, hasDeinitialized: hasDeinitialized)

				// Ensure `observer` is deallocated after `stateLock` is
				// released to avoid deadlocks.
				withExtendedLifetime(observer) {
					// Start the disposal of the `Signal` core if the `Signal` has
					// deinitialized and there is no active observer.
					tryToDisposeSilentlyIfQualified(unlocking: stateLock)
				}
			} else {
				stateLock.unlock()
			}
		}

		/// Try to commit the termination, or in other words transition the signal from a
		/// terminating state to a terminated state.
		///
		/// It fails gracefully if the signal is alive or has terminated. Calling this
		/// method as a result of a false positive `terminating` check is permitted.
		///
		/// - precondition: `stateLock` must not be acquired by the caller.
		private func tryToCommitTermination() {
			// Acquire `stateLock`. If the termination has still not yet been
			// handled, take it over and bump the status to `terminated`.
			stateLock.lock()

			if case let .terminating(observers, terminationKind) = state {
				// Try to acquire the `sendLock`, and fail gracefully since the current
				// lock holder would attempt to commit after it is done anyway.
				if sendLock.try() {
					state = .terminated
					stateLock.unlock()

					if let event = terminationKind.materialize() {
						for observer in observers {
							observer.send(event)
						}
					}

					sendLock.unlock()
					disposable.dispose()
					return
				}
			}

			stateLock.unlock()
		}

		/// Try to dispose of the signal silently if the `Signal` has deinitialized and
		/// has no observer.
		///
		/// It fails gracefully if the signal is terminating or terminated, has one or
		/// more observers, or has not deinitialized.
		///
		/// - precondition: `stateLock` must have been acquired by the caller.
		///
		/// - parameters:
		///   - stateLock: The `stateLock` acquired by the caller.
		private func tryToDisposeSilentlyIfQualified(unlocking stateLock: Lock) {
			assert(!stateLock.try(), "Calling `unconditionallyTerminate` without acquiring `stateLock`.")

			if case let .alive(observers, true) = state, observers.isEmpty {
				// Transition to `terminated` directly only if there is no event delivery
				// on going.
				if sendLock.try() {
					self.state = .terminated
					stateLock.unlock()
					sendLock.unlock()

					disposable.dispose()
					return
				}

				self.state = .terminating(Bag(), .silent)
				stateLock.unlock()

				tryToCommitTermination()
				return
			}

			stateLock.unlock()
		}

		/// Acknowledge the deinitialization of the `Signal`.
		fileprivate func signalDidDeinitialize() {
			stateLock.lock()

			// Mark the `Signal` has now deinitialized.
			if case let .alive(observers, false) = state {
				state = .alive(observers, hasDeinitialized: true)
			}

			// Attempt to start the disposal of the signal if it has no active observer.
			tryToDisposeSilentlyIfQualified(unlocking: stateLock)
		}

		deinit {
			disposable.dispose()
		}
	}

	/// Initialize a Signal that will immediately invoke the given generator,
	/// then forward events sent to the given observer.
	///
	/// - note: The disposable returned from the closure will be automatically
	///         disposed if a terminating event is sent to the observer. The
	///         Signal itself will remain alive until the observer is released.
	///
	/// - parameters:
	///   - generator: A closure that accepts an implicitly created observer
	///                that will act as an event emitter for the signal.
	public init(_ generator: (Observer, Lifetime) -> Void) {
		core = Core(generator)
	}

	/// Observe the Signal by sending any future events to the given observer.
	///
	/// - note: If the Signal has already terminated, the observer will
	///         immediately receive an `interrupted` event.
	///
	/// - parameters:
	///   - observer: An observer to forward the events to.
	///
	/// - returns: A `Disposable` which can be used to disconnect the observer,
	///            or `nil` if the signal has already terminated.
	@discardableResult
	public func observe(_ observer: Observer) -> Disposable? {
		return core.observe(observer)
	}

	deinit {
		core.signalDidDeinitialize()
	}

	/// The state of a `Signal`.
	///
	/// `SignalState` is guaranteed to be laid out as a tagged pointer by the Swift
	/// compiler in the support targets of the Swift 3.0.1 ABI.
	///
	/// The Swift compiler has also an optimization for enums with payloads that are
	/// all reference counted, and at most one no-payload case.
	private enum State {
		// `TerminationKind` is constantly pointer-size large to keep `Signal.Core`
		// allocation size independent of the actual `Value` and `Error` types.
		enum TerminationKind {
			case completed
			case interrupted
			case failed(Swift.Error)
			case silent

			init(_ event: Event) {
				switch event {
				case .value:
					fatalError()
				case .interrupted:
					self = .interrupted
				case let .failed(error):
					self = .failed(error)
				case .completed:
					self = .completed
				}
			}

			func materialize() -> Event? {
				switch self {
				case .completed:
					return .completed
				case .interrupted:
					return .interrupted
				case let .failed(error):
					return .failed(error as! Error)
				case .silent:
					return nil
				}
			}
		}

		/// The `Signal` is alive.
		case alive(Bag<Observer>, hasDeinitialized: Bool)

		/// The `Signal` has received a termination event, and is about to be
		/// terminated.
		case terminating(Bag<Observer>, TerminationKind)

		/// The `Signal` has terminated.
		case terminated
	}
}

extension Signal {
	/// A Signal that never sends any events to its observers.
	public static var never: Signal {
		return self.init { observer, lifetime in
			// If `observer` deinitializes, the `Signal` would interrupt which is
			// undesirable for `Signal.never`.
			lifetime.observeEnded { _ = observer }
		}
	}

	/// A Signal that completes immediately without emitting any value.
	public static var empty: Signal {
		return self.init { observer, _ in
			observer.sendCompleted()
		}
	}

	/// Create a `Signal` that will be controlled by sending events to an
	/// input observer.
	///
	/// - note: The `Signal` will remain alive until a terminating event is sent
	///         to the input observer, or until it has no observers and there
	///         are no strong references to it.
	///
	/// - parameters:
	///   - disposable: An optional disposable to associate with the signal, and
	///                 to be disposed of when the signal terminates.
	///
	/// - returns: A 2-tuple of the output end of the pipe as `Signal`, and the input end
	///            of the pipe as `Signal.Observer`.
	public static func pipe(disposable: Disposable? = nil) -> (output: Signal, input: Observer) {
		var observer: Observer!

		let signal = self.init { innerObserver, lifetime in
			observer = innerObserver
			lifetime += disposable
		}

		return (signal, observer)
	}
}

public protocol SignalProtocol: AnyObject {
	/// The type of values being sent by `self`.
	associatedtype Value

	/// The type of error that can occur on `self`.
	associatedtype Error: Swift.Error

	/// The materialized `self`.
	var signal: Signal<Value, Error> { get }
}

extension Signal: SignalProtocol {
	public var signal: Signal<Value, Error> {
		return self
	}
}

extension Signal: SignalProducerConvertible {
	public var producer: SignalProducer<Value, Error> {
		return SignalProducer(self)
	}
}

extension Signal {
	/// Observe `self` for all events being emitted.
	///
	/// - note: If `self` has terminated, the closure would be invoked with an
	///         `interrupted` event immediately.
	///
	/// - parameters:
	///   - action: A closure to be invoked with every event from `self`.
	///
	/// - returns: A disposable to detach `action` from `self`. `nil` if `self` has
	///            terminated.
	@discardableResult
	public func observe(_ action: @escaping Signal<Value, Error>.Observer.Action) -> Disposable? {
		return observe(Observer(action))
	}

	/// Observe `self` for all values being emitted, and if any, the failure.
	///
	/// - parameters:
	///   - action: A closure to be invoked with values from `self`, or the propagated
	///             error should any `failed` event is emitted.
	///
	/// - returns: A disposable to detach `action` from `self`. `nil` if `self` has
	///            terminated.
	@discardableResult
	public func observeResult(_ action: @escaping (Result<Value, Error>) -> Void) -> Disposable? {
		return observe(
			Observer(
				value: { action(.success($0)) },
				failed: { action(.failure($0)) }
			)
		)
	}

	/// Observe `self` for its completion.
	///
	/// - parameters:
	///   - action: A closure to be invoked when a `completed` event is emitted.
	///
	/// - returns: A disposable to detach `action` from `self`. `nil` if `self` has
	///            terminated.
	@discardableResult
	public func observeCompleted(_ action: @escaping () -> Void) -> Disposable? {
		return observe(Observer(completed: action))
	}

	/// Observe `self` for its failure.
	///
	/// - parameters:
	///   - action: A closure to be invoked with the propagated error, should any
	///             `failed` event is emitted.
	///
	/// - returns: A disposable to detach `action` from `self`. `nil` if `self` has
	///            terminated.
	@discardableResult
	public func observeFailed(_ action: @escaping (Error) -> Void) -> Disposable? {
		return observe(Observer(failed: action))
	}

	/// Observe `self` for its interruption.
	///
	/// - note: If `self` has terminated, the closure would be invoked immediately.
	///
	/// - parameters:
	///   - action: A closure to be invoked when an `interrupted` event is emitted.
	///
	/// - returns: A disposable to detach `action` from `self`. `nil` if `self` has
	///            terminated.
	@discardableResult
	public func observeInterrupted(_ action: @escaping () -> Void) -> Disposable? {
		return observe(Observer(interrupted: action))
	}
}

extension Signal where Error == Never {
	/// Observe `self` for all values being emitted.
	///
	/// - parameters:
	///   - action: A closure to be invoked with values from `self`.
	///
	/// - returns: A disposable to detach `action` from `self`. `nil` if `self` has
	///            terminated.
	@discardableResult
	public func observeValues(_ action: @escaping (Value) -> Void) -> Disposable? {
		return observe(Observer(value: action))
	}
}

extension Signal {
	/// Perform an action upon every event from `self`. The action may generate zero or
	/// more events.
	///
	/// - precondition: The action must be synchronous.
	///
	/// - parameters:
	///   - transform: A closure that creates the said action from the given event
	///                closure.
	///
	/// - returns: A signal that forwards events yielded by the action.
	internal func flatMapEvent<U, E>(_ transform: @escaping Event.Transformation<U, E>) -> Signal<U, E> {
		return Signal<U, E> { output, lifetime in
			// Create an input sink whose events would go through the given
			// event transformation, and have the resulting events propagated
			// to the resulting `Signal`.
			let input = transform(output, lifetime)
			lifetime += self.observe(input.assumeUnboundDemand())
		}
	}

	/// Map each value in the signal to a new value.
	///
	/// - parameters:
	///   - transform: A closure that accepts a value from the `value` event and
	///                returns a new value.
	///
	/// - returns: A signal that will send new values.
	public func map<U>(_ transform: @escaping (Value) -> U) -> Signal<U, Error> {
		return flatMapEvent(Signal.Event.map(transform))
	}
	
	/// Map each value in the signal to a new constant value.
	///
	/// - parameters:
	///   - value: A new value.
	///
	/// - returns: A signal that will send new values.
	public func map<U>(value: U) -> Signal<U, Error> {
		return map { _ in value }
	}

	/// Map each value in the signal to a new value by applying a key path.
	///
	/// - parameters:
	///   - keyPath: A key path relative to the signal's `Value` type.
	///
	/// - returns: A signal that will send new values.
	public func map<U>(_ keyPath: KeyPath<Value, U>) -> Signal<U, Error> {
		return map { $0[keyPath: keyPath] }
	}

	/// Map errors in the signal to a new error.
	///
	/// - parameters:
	///   - transform: A closure that accepts current error object and returns
	///                a new type of error object.
	///
	/// - returns: A signal that will send new type of errors.
	public func mapError<F>(_ transform: @escaping (Error) -> F) -> Signal<Value, F> {
		return flatMapEvent(Signal.Event.mapError(transform))
	}

	/// Maps each value in the signal to a new value, lazily evaluating the
	/// supplied transformation on the specified scheduler.
	///
	/// - important: Unlike `map`, there is not a 1-1 mapping between incoming
	///              values, and values sent on the returned signal. If
	///              `scheduler` has not yet scheduled `transform` for
	///              execution, then each new value will replace the last one as
	///              the parameter to `transform` once it is finally executed.
	///
	/// - parameters:
	///   - transform: The closure used to obtain the returned value from this
	///                signal's underlying value.
	///
	/// - returns: A signal that sends values obtained using `transform` as this 
	///            signal sends values.
	public func lazyMap<U>(on scheduler: Scheduler, transform: @escaping (Value) -> U) -> Signal<U, Error> {
		return flatMapEvent(Signal.Event.lazyMap(on: scheduler, transform: transform))
	}

	/// Preserve only values which pass the given closure.
	///
	/// - parameters:
	///   - isIncluded: A closure to determine whether a value from `self` should be
	///                 included in the returned `Signal`.
	///
	/// - returns: A signal that forwards the values passing the given closure.
	public func filter(_ isIncluded: @escaping (Value) -> Bool) -> Signal<Value, Error> {
		return flatMapEvent(Signal.Event.filter(isIncluded))
	}

	/// Applies `transform` to values from `signal` and forwards values with non `nil` results unwrapped.
	/// - parameters:
	///   - transform: A closure that accepts a value from the `value` event and
	///                returns a new optional value.
	///
	/// - returns: A signal that will send new values, that are non `nil` after the transformation.
	public func compactMap<U>(_ transform: @escaping (Value) -> U?) -> Signal<U, Error> {
		return flatMapEvent(Signal.Event.compactMap(transform))
	}

	/// Applies `transform` to values from `signal` and forwards values with non `nil` results unwrapped.
	/// - parameters:
	///   - transform: A closure that accepts a value from the `value` event and
	///                returns a new optional value.
	///
	/// - returns: A signal that will send new values, that are non `nil` after the transformation.
	@available(*, deprecated, renamed: "compactMap")
	public func filterMap<U>(_ transform: @escaping (Value) -> U?) -> Signal<U, Error> {
		return flatMapEvent(Signal.Event.compactMap(transform))
	}
}

extension Signal where Value: OptionalProtocol {
	/// Unwrap non-`nil` values and forward them on the returned signal, `nil`
	/// values are dropped.
	///
	/// - returns: A signal that sends only non-nil values.
	public func skipNil() -> Signal<Value.Wrapped, Error> {
		return flatMapEvent(Signal.Event.skipNil)
	}
}

extension Signal {
	/// Take up to `n` values from the signal and then complete.
	///
	/// - precondition: `count` must be non-negative number.
	///
	/// - parameters:
	///   - count: A number of values to take from the signal.
	///
	/// - returns: A signal that will yield the first `count` values from `self`
	public func take(first count: Int) -> Signal<Value, Error> {
		precondition(count >= 0)
		guard count >= 1 else { return .empty }
		return flatMapEvent(Signal.Event.take(first: count))
	}

	/// Collect all values sent by the signal then forward them as a single
	/// array and complete.
	///
	/// - note: When `self` completes without collecting any value, it will send
	///         an empty array of values.
	///
	/// - returns: A signal that will yield an array of values when `self`
	///            completes.
	public func collect() -> Signal<[Value], Error> {
		return flatMapEvent(Signal.Event.collect)
	}

	/// Collect at most `count` values from `self`, forward them as a single
	/// array and complete.
	///
	/// - note: When the count is reached the array is sent and the signal
	///         starts over yielding a new array of values.
	///
	/// - note: When `self` completes any remaining values will be sent, the
	///         last array may not have `count` values. Alternatively, if were
	///         not collected any values will sent an empty array of values.
	///
	/// - precondition: `count` should be greater than zero.
	///
	public func collect(count: Int) -> Signal<[Value], Error> {
		return flatMapEvent(Signal.Event.collect(count: count))
	}

	/// Collect values from `self`, and emit them if the predicate passes.
	///
	/// When `self` completes any remaining values will be sent, regardless of the
	/// collected values matching `shouldEmit` or not.
	///
	/// If `self` completes without having emitted any value, an empty array would be
	/// emitted, followed by the completion of the returned `Signal`.
	///
	/// ````
	/// let (signal, observer) = Signal<Int, Never>.pipe()
	///
	/// signal
	///     .collect { values in values.reduce(0, combine: +) == 8 }
	///     .observeValues { print($0) }
	///
	/// observer.send(value: 1)
	/// observer.send(value: 3)
	/// observer.send(value: 4)
	/// observer.send(value: 7)
	/// observer.send(value: 1)
	/// observer.send(value: 5)
	/// observer.send(value: 6)
	/// observer.sendCompleted()
	///
	/// // Output:
	/// // [1, 3, 4]
	/// // [7, 1]
	/// // [5, 6]
	/// ````
	///
	/// - parameters:
	///   - shouldEmit: A closure to determine, when every time a new value is received,
	///                 whether the collected values should be emitted. The new value
	///                 is included in the collected values.
	///
	/// - returns: A signal of arrays of values, as instructed by the `shouldEmit`
	///            closure.
	public func collect(_ shouldEmit: @escaping (_ collectedValues: [Value]) -> Bool) -> Signal<[Value], Error> {
		return flatMapEvent(Signal.Event.collect(shouldEmit))
	}

	/// Collect values from `self`, and emit them if the predicate passes.
	///
	/// When `self` completes any remaining values will be sent, regardless of the
	/// collected values matching `shouldEmit` or not.
	///
	/// If `self` completes without having emitted any value, an empty array would be
	/// emitted, followed by the completion of the returned `Signal`.
	///
	/// ````
	/// let (signal, observer) = Signal<Int, Never>.pipe()
	///
	/// signal
	///     .collect { values, value in value == 7 }
	///     .observeValues { print($0) }
	///
	/// observer.send(value: 1)
	/// observer.send(value: 1)
	/// observer.send(value: 7)
	/// observer.send(value: 7)
	/// observer.send(value: 5)
	/// observer.send(value: 6)
	/// observer.sendCompleted()
	///
	/// // Output:
	/// // [1, 1]
	/// // [7]
	/// // [7, 5, 6]
	/// ````
	///
	/// - parameters:
	///   - shouldEmit: A closure to determine, when every time a new value is received,
	///                 whether the collected values should be emitted. The new value
	///                 is **not** included in the collected values, and is included when
	///                 the next value is received.
	///
	/// - returns: A signal of arrays of values, as instructed by the `shouldEmit`
	///            closure.
	public func collect(_ shouldEmit: @escaping (_ collected: [Value], _ latest: Value) -> Bool) -> Signal<[Value], Error> {
		return flatMapEvent(Signal.Event.collect(shouldEmit))
	}

	/// Forward the latest values on `scheduler` every `interval`.
	///
	/// - note: If `self` terminates while values are being accumulated,
	///         the behaviour will be determined by `discardWhenCompleted`.
	///         If `true`, the values will be discarded and the returned signal
	///         will terminate immediately.
	///         If `false`, that values will be delivered at the next interval.
	///
	/// - parameters:
	///   - interval: A repetition interval.
	///   - scheduler: A scheduler to send values on.
	///   - skipEmpty: Whether empty arrays should be sent if no values were
	///     accumulated during the interval.
	///   - discardWhenCompleted: A boolean to indicate if the latest unsent
	///     values should be discarded on completion.
	///
	/// - returns: A signal that sends all values that are sent from `self` at
	///            `interval` seconds apart.
	public func collect(every interval: DispatchTimeInterval, on scheduler: DateScheduler, skipEmpty: Bool = false, discardWhenCompleted: Bool = true) -> Signal<[Value], Error> {
		return flatMapEvent(Signal.Event.collect(every: interval, on: scheduler, skipEmpty: skipEmpty, discardWhenCompleted: discardWhenCompleted))
	}

	/// Forward all events onto the given scheduler, instead of whichever
	/// scheduler they originally arrived upon.
	///
	/// - parameters:
	///   - scheduler: A scheduler to deliver events on.
	///
	/// - returns: A signal that will yield `self` values on provided scheduler.
	public func observe(on scheduler: Scheduler) -> Signal<Value, Error> {
		return flatMapEvent(Signal.Event.observe(on: scheduler))
	}
}

extension Signal {
	/// Combine the latest value of the receiver with the latest value from the
	/// given signal.
	///
	/// - note: The returned signal will not send a value until both inputs have
	///         sent at least one value each.
	///
	/// - note: If either signal is interrupted, the returned signal will also
	///         be interrupted.
	///
	/// - note: The returned signal will not complete until both inputs
	///         complete.
	///
	/// - parameters:
	///   - otherSignal: A signal to combine `self`'s value with.
	///
	/// - returns: A signal that will yield a tuple containing values of `self`
	///            and given signal.
	public func combineLatest<U>(with other: Signal<U, Error>) -> Signal<(Value, U), Error> {
		return Signal.combineLatest(self, other)
	}
	
	/// Merge the given signal into a single `Signal` that will emit all
	/// values from both of them, and complete when all of them have completed.
	///
	/// - parameters:
	///   - other: A signal to merge `self`'s value with.
	///
	/// - returns: A signal that sends all values of `self` and given signal.
	public func merge(with other: Signal<Value, Error>) -> Signal<Value, Error> {
		return Signal.merge(self, other)
	}

	/// Delay `value` and `completed` events by the given interval, forwarding
	/// them on the given scheduler.
	///
	/// - note: failed and `interrupted` events are always scheduled
	///         immediately.
	///
	/// - precondition: `interval` must be non-negative number.
	///
	/// - parameters:
	///   - interval: Interval to delay `value` and `completed` events by.
	///   - scheduler: A scheduler to deliver delayed events on.
	///
	/// - returns: A signal that will delay `value` and `completed` events and
	///            will yield them on given scheduler.
	public func delay(_ interval: TimeInterval, on scheduler: DateScheduler) -> Signal<Value, Error> {
		return flatMapEvent(Signal.Event.delay(interval, on: scheduler))
	}

	/// Skip first `count` number of values then act as usual.
	///
	/// - precondition: `count` must be non-negative number.
	///
	/// - parameters:
	///   - count: A number of values to skip.
	///
	/// - returns:  A signal that will skip the first `count` values, then
	///             forward everything afterward.
	public func skip(first count: Int) -> Signal<Value, Error> {
		guard count != 0 else { return self }
		return flatMapEvent(Signal.Event.skip(first: count))
	}

	/// Treat all Events from `self` as plain values, allowing them to be
	/// manipulated just like any other value.
	///
	/// In other words, this brings Events “into the monad”.
	///
	/// - note: When a Completed or Failed event is received, the resulting
	///         signal will send the Event itself and then complete. When an
	///         Interrupted event is received, the resulting signal will send
	///         the Event itself and then interrupt.
	///
	/// - returns: A signal that sends events as its values.
	public func materialize() -> Signal<Event, Never> {
		return flatMapEvent(Signal.Event.materialize)
	}

	/// Treats all Results from the input producer as plain values, allowing them
	/// to be manipulated just like any other value.
	///
	/// In other words, this brings Results “into the monad.”
	///
	/// - note: When a Failed event is received, the resulting producer will
	///         send the `Result.failure` itself and then complete.
	///
	/// - returns: A producer that sends results as its values.
	public func materializeResults() -> Signal<Result<Value, Error>, Never> {
		return flatMapEvent(Signal.Event.materializeResults)
	}
}

extension Signal where Value: EventProtocol, Error == Never {
	/// Translate a signal of `Event` _values_ into a signal of those events
	/// themselves.
	///
	/// - returns: A signal that sends values carried by `self` events.
	public func dematerialize() -> Signal<Value.Value, Value.Error> {
		return flatMapEvent(Signal.Event.dematerialize)
	}
}

extension Signal where Error == Never {
	/// Translate a signal of `Result` _values_ into a signal of those events
	/// themselves.
	///
	/// - returns: A signal that sends values carried by `self` events.
	public func dematerializeResults<Success, Failure>() -> Signal<Success, Failure> where Value == Result<Success, Failure> {
		return flatMapEvent(Signal.Event.dematerializeResults)
	}
}

extension Signal {
	/// Inject side effects to be performed upon the specified signal events.
	///
	/// - parameters:
	///   - event: A closure that accepts an event and is invoked on every
	///            received event.
	///   - failed: A closure that accepts error object and is invoked for
	///             failed event.
	///   - completed: A closure that is invoked for `completed` event.
	///   - interrupted: A closure that is invoked for `interrupted` event.
	///   - terminated: A closure that is invoked for any terminating event.
	///   - disposed: A closure added as disposable when signal completes.
	///   - value: A closure that accepts a value from `value` event.
	///
	/// - returns: A signal with attached side-effects for given event cases.
	public func on(
		event: ((Event) -> Void)? = nil,
		failed: ((Error) -> Void)? = nil,
		completed: (() -> Void)? = nil,
		interrupted: (() -> Void)? = nil,
		terminated: (() -> Void)? = nil,
		disposed: (() -> Void)? = nil,
		value: ((Value) -> Void)? = nil
	) -> Signal<Value, Error> {
		return Signal { observer, lifetime in
			if let action = disposed {
				lifetime.observeEnded(action)
			}

			lifetime += signal.observe { receivedEvent in
				event?(receivedEvent)

				switch receivedEvent {
				case let .value(v):
					value?(v)

				case let .failed(error):
					failed?(error)

				case .completed:
					completed?()

				case .interrupted:
					interrupted?()
				}

				if receivedEvent.isTerminating {
					terminated?()
				}

				observer.send(receivedEvent)
			}
		}
	}
}

private struct SampleState<Value> {
	var latestValue: Value?
	var isSignalCompleted: Bool = false
	var isSamplerCompleted: Bool = false
}

extension Signal {
	/// Forward the latest value from `self` with the value from `sampler` as a
	/// tuple, only when`sampler` sends a `value` event.
	///
	/// - note: If `sampler` fires before a value has been observed on `self`, 
	///         nothing happens.
	///
	/// - parameters:
	///   - sampler: A signal that will trigger the delivery of `value` event
	///              from `self`.
	///
	/// - returns: A signal that will send values from `self` and `sampler`, 
	///            sampled (possibly multiple times) by `sampler`, then complete
	///            once both input signals have completed, or interrupt if
	///            either input signal is interrupted.
	public func sample<T>(with sampler: Signal<T, Never>) -> Signal<(Value, T), Error> {
		return Signal<(Value, T), Error> { observer, lifetime in
			let state = Atomic(SampleState<Value>())

			lifetime += self.observe { event in
				switch event {
				case let .value(value):
					state.modify {
						$0.latestValue = value
					}

				case let .failed(error):
					observer.send(error: error)

				case .completed:
					let shouldComplete: Bool = state.modify {
						$0.isSignalCompleted = true
						return $0.isSamplerCompleted
					}

					if shouldComplete {
						observer.sendCompleted()
					}

				case .interrupted:
					observer.sendInterrupted()
				}
			}

			lifetime += sampler.observe { event in
				switch event {
				case .value(let samplerValue):
					if let value = state.value.latestValue {
						observer.send(value: (value, samplerValue))
					}

				case .completed:
					let shouldComplete: Bool = state.modify {
						$0.isSamplerCompleted = true
						return $0.isSignalCompleted
					}

					if shouldComplete {
						observer.sendCompleted()
					}

				case .interrupted:
					observer.sendInterrupted()

				case .failed:
					break
				}
			}
		}
	}

	/// Forward the latest value from `self` whenever `sampler` sends a `value`
	/// event.
	///
	/// - note: If `sampler` fires before a value has been observed on `self`, 
	///         nothing happens.
	///
	/// - parameters:
	///   - sampler: A signal that will trigger the delivery of `value` event
	///              from `self`.
	///
	/// - returns: A signal that will send values from `self`, sampled (possibly
	///            multiple times) by `sampler`, then complete once both input
	///            signals have completed, or interrupt if either input signal
	///            is interrupted.
	public func sample(on sampler: Signal<(), Never>) -> Signal<Value, Error> {
		return sample(with: sampler)
			.map { $0.0 }
	}

	/// Forward the latest value from `samplee` with the value from `self` as a
	/// tuple, only when `self` sends a `value` event.
	/// This is like a flipped version of `sample(with:)`, but `samplee`'s
	/// terminal events are completely ignored.
	///
	/// - note: If `self` fires before a value has been observed on `samplee`,
	///         nothing happens.
	///
	/// - parameters:
	///   - samplee: A signal whose latest value is sampled by `self`.
	///
	/// - returns: A signal that will send values from `self` and `samplee`,
	///            sampled (possibly multiple times) by `self`, then terminate
	///            once `self` has terminated. **`samplee`'s terminated events
	///            are ignored**.
	public func withLatest<U>(from samplee: Signal<U, Never>) -> Signal<(Value, U), Error> {
		return Signal<(Value, U), Error> { observer, lifetime in
			let state = Atomic<U?>(nil)

			lifetime += samplee.observeValues { value in
				state.value = value
			}

			lifetime += self.observe { event in
				switch event {
				case let .value(value):
					if let value2 = state.value {
						observer.send(value: (value, value2))
					}
				case .completed:
					observer.sendCompleted()
				case let .failed(error):
					observer.send(error: error)
				case .interrupted:
					observer.sendInterrupted()
				}
			}
		}
	}

	/// Forward the latest value from `samplee` with the value from `self` as a
	/// tuple, only when `self` sends a `value` event.
	/// This is like a flipped version of `sample(with:)`, but `samplee`'s
	/// terminal events are completely ignored.
	///
	/// - note: If `self` fires before a value has been observed on `samplee`,
	///         nothing happens.
	///
	/// - parameters:
	///   - samplee: A producer whose latest value is sampled by `self`.
	///
	/// - returns: A signal that will send values from `self` and `samplee`,
	///            sampled (possibly multiple times) by `self`, then terminate
	///            once `self` has terminated. **`samplee`'s terminated events
	///            are ignored**.
	public func withLatest<U>(from samplee: SignalProducer<U, Never>) -> Signal<(Value, U), Error> {
		return Signal<(Value, U), Error> { observer, lifetime in
			samplee.startWithSignal { signal, disposable in
				lifetime += disposable
				lifetime += self.withLatest(from: signal).observe(observer)
			}
		}
	}

	/// Forward the latest value from `samplee` with the value from `self` as a
	/// tuple, only when `self` sends a `value` event.
	/// This is like a flipped version of `sample(with:)`, but `samplee`'s
	/// terminal events are completely ignored.
	///
	/// - note: If `self` fires before a value has been observed on `samplee`,
	///         nothing happens.
	///
	/// - parameters:
	///   - samplee: A producer whose latest value is sampled by `self`.
	///
	/// - returns: A signal that will send values from `self` and `samplee`,
	///            sampled (possibly multiple times) by `self`, then terminate
	///            once `self` has terminated. **`samplee`'s terminated events
	///            are ignored**.
	public func withLatest<Samplee: SignalProducerConvertible>(from samplee: Samplee) -> Signal<(Value, Samplee.Value), Error> where Samplee.Error == Never {
		return withLatest(from: samplee.producer)
	}
}

extension Signal {
	/// Forwards events from `self` until `lifetime` ends, at which point the
	/// returned signal will complete.
	///
	/// - parameters:
	///   - lifetime: A lifetime whose `ended` signal will cause the returned
	///               signal to complete.
	///
	/// - returns: A signal that will deliver events until `lifetime` ends.
	public func take(during lifetime: Lifetime) -> Signal<Value, Error> {
		return Signal<Value, Error> { observer, innerLifetime in
			innerLifetime += self.observe(observer)
			innerLifetime += lifetime.observeEnded(observer.sendCompleted)
		}
	}

	/// Forward events from `self` until `trigger` sends a `value` or
	/// `completed` event, at which point the returned signal will complete.
	///
	/// - parameters:
	///   - trigger: A signal whose `value` or `completed` events will stop the
	///              delivery of `value` events from `self`.
	///
	/// - returns: A signal that will deliver events until `trigger` sends
	///            `value` or `completed` events.
	public func take(until trigger: Signal<(), Never>) -> Signal<Value, Error> {
		return Signal<Value, Error> { observer, lifetime in
			lifetime += self.observe(observer)
			lifetime += trigger.observe { event in
				switch event {
				case .value, .completed:
					observer.sendCompleted()

				case .failed, .interrupted:
					break
				}
			}
		}
	}

	/// Do not forward any values from `self` until `trigger` sends a `value` or
	/// `completed` event, at which point the returned signal behaves exactly
	/// like `signal`.
	///
	/// - parameters:
	///   - trigger: A signal whose `value` or `completed` events will start the
	///              deliver of events on `self`.
	///
	/// - returns: A signal that will deliver events once the `trigger` sends
	///            `value` or `completed` events.
	public func skip(until trigger: Signal<(), Never>) -> Signal<Value, Error> {
		return Signal { observer, lifetime in
			let disposable = SerialDisposable()
			lifetime += disposable

			disposable.inner = trigger.observe { event in
				switch event {
				case .value, .completed:
					disposable.inner = self.observe(observer)

				case .failed, .interrupted:
					break
				}
			}
		}
	}

	/// Forward events from `self` with history: values of the returned signal
	/// are a tuples whose first member is the previous value and whose second member
	/// is the current value. `initial` is supplied as the first member when `self`
	/// sends its first value.
	///
	/// - parameters:
	///   - initial: A value that will be combined with the first value sent by
	///              `self`.
	///
	/// - returns: A signal that sends tuples that contain previous and current
	///            sent values of `self`.
	public func combinePrevious(_ initial: Value) -> Signal<(Value, Value), Error> {
		return flatMapEvent(Signal.Event.combinePrevious(initial: initial))
	}

	/// Forward events from `self` with history: values of the returned signal
	/// are a tuples whose first member is the previous value and whose second member
	/// is the current value.
	///
	/// The returned `Signal` would not emit any tuple until it has received at least two
	/// values.
	///
	/// - returns: A signal that sends tuples that contain previous and current
	///            sent values of `self`.
	public func combinePrevious() -> Signal<(Value, Value), Error> {
		return flatMapEvent(Signal.Event.combinePrevious(initial: nil))
	}

	/// Combine all values from `self`, and forward only the final accumulated result.
	///
	/// See `scan(_:_:)` if the resulting producer needs to forward also the partial
	/// results.
	///
	/// - parameters:
	///   - initialResult: The value to use as the initial accumulating value.
	///   - nextPartialResult: A closure that combines the accumulating value and the
	///                        latest value from `self`. The result would be used in the
	///                        next call of `nextPartialResult`, or emit to the returned
	///                        `Signal` when `self` completes.
	///
	/// - returns: A signal that sends the final result as `self` completes.
	public func reduce<U>(_ initialResult: U, _ nextPartialResult: @escaping (U, Value) -> U) -> Signal<U, Error> {
		return flatMapEvent(Signal.Event.reduce(initialResult, nextPartialResult))
	}

	/// Combine all values from `self`, and forward only the final accumulated result.
	///
	/// See `scan(into:_:)` if the resulting producer needs to forward also the partial
	/// results.
	///
	/// - parameters:
	///   - initialResult: The value to use as the initial accumulating value.
	///   - nextPartialResult: A closure that combines the accumulating value and the
	///                        latest value from `self`. The result would be used in the
	///                        next call of `nextPartialResult`, or emit to the returned
	///                        `Signal` when `self` completes.
	///
	/// - returns: A signal that sends the final result as `self` completes.
	public func reduce<U>(into initialResult: U, _ nextPartialResult: @escaping (inout U, Value) -> Void) -> Signal<U, Error> {
		return flatMapEvent(Signal.Event.reduce(into: initialResult, nextPartialResult))
	}

	/// Combine all values from `self`, and forward the partial results and the final
	/// result.
	///
	/// See `reduce(_:_:)` if the resulting producer needs to forward only the final
	/// result.
	///
	/// - parameters:
	///   - initialResult: The value to use as the initial accumulating value.
	///   - nextPartialResult: A closure that combines the accumulating value and the
	///                        latest value from `self`. The result would be forwarded,
	///                        and would be used in the next call of `nextPartialResult`.
	///
	/// - returns: A signal that sends the partial results of the accumuation, and the
	///            final result as `self` completes.
	public func scan<U>(_ initialResult: U, _ nextPartialResult: @escaping (U, Value) -> U) -> Signal<U, Error> {
		return flatMapEvent(Signal.Event.scan(initialResult, nextPartialResult))
	}

	/// Combine all values from `self`, and forward the partial results and the final
	/// result.
	///
	/// See `reduce(into:_:)` if the resulting producer needs to forward only the final
	/// result.
	///
	/// - parameters:
	///   - initialResult: The value to use as the initial accumulating value.
	///   - nextPartialResult: A closure that combines the accumulating value and the
	///                        latest value from `self`. The result would be forwarded,
	///                        and would be used in the next call of `nextPartialResult`.
	///
	/// - returns: A signal that sends the partial results of the accumuation, and the
	///            final result as `self` completes.
	public func scan<U>(into initialResult: U, _ nextPartialResult: @escaping (inout U, Value) -> Void) -> Signal<U, Error> {
		return flatMapEvent(Signal.Event.scan(into: initialResult, nextPartialResult))
	}

	/// Accumulate all values from `self` as `State`, and send the value as `U`.
	///
	/// - parameters:
	///   - initialState: The state to use as the initial accumulating state.
	///   - next: A closure that combines the accumulating state and the latest value
	///           from `self`. The result would be "next state" and "output" where
	///           "output" would be forwarded and "next state" would be used in the
	///           next call of `next`.
	///
	/// - returns: A producer that sends the output that is computed from the accumuation.
	public func scanMap<State, U>(_ initialState: State, _ next: @escaping (State, Value) -> (State, U)) -> Signal<U, Error> {
		return flatMapEvent(Signal.Event.scanMap(initialState, next))
	}

	/// Accumulate all values from `self` as `State`, and send the value as `U`.
	///
	/// - parameters:
	///   - initialState: The state to use as the initial accumulating state.
	///   - next: A closure that combines the accumulating state and the latest value
	///           from `self`. The result would be "next state" and "output" where
	///           "output" would be forwarded and "next state" would be used in the
	///           next call of `next`.
	///
	/// - returns: A producer that sends the output that is computed from the accumuation.
	public func scanMap<State, U>(into initialState: State, _ next: @escaping (inout State, Value) -> U) -> Signal<U, Error> {
		return flatMapEvent(Signal.Event.scanMap(into: initialState, next))
	}
}

extension Signal where Value: Equatable {
	/// Forward only values from `self` that are not equal to its immediately preceding
	/// value.
	///
	/// - note: The first value is always forwarded.
	///
	/// - returns: A signal which conditionally forwards values from `self`.
	public func skipRepeats() -> Signal<Value, Error> {
		return flatMapEvent(Signal.Event.skipRepeats(==))
	}
}

extension Signal {
	/// Forward only values from `self` that are not considered equivalent to its
	/// immediately preceding value.
	///
	/// - note: The first value is always forwarded.
	///
	/// - parameters:
	///   - isEquivalent: A closure to determine whether two values are equivalent.
	///
	/// - returns: A signal which conditionally forwards values from `self`.
	public func skipRepeats(_ isEquivalent: @escaping (Value, Value) -> Bool) -> Signal<Value, Error> {
		return flatMapEvent(Signal.Event.skipRepeats(isEquivalent))
	}

	/// Do not forward any value from `self` until `shouldContinue` returns `false`, at
	/// which point the returned signal starts to forward values from `self`, including
	/// the one leading to the toggling.
	///
	/// - parameters:
	///   - shouldContinue: A closure to determine whether the skipping should continue.
	///
	/// - returns: A signal which conditionally forwards values from `self`.
	public func skip(while shouldContinue: @escaping (Value) -> Bool) -> Signal<Value, Error> {
		return flatMapEvent(Signal.Event.skip(while: shouldContinue))
	}

	/// Forward events from `self` until `replacement` begins sending events.
	///
	/// - parameters:
	///   - replacement: A signal to wait to wait for values from and start
	///                  sending them as a replacement to `self`'s values.
	///
	/// - returns: A signal which passes through `value`, failed, and
	///            `interrupted` events from `self` until `replacement` sends
	///            an event, at which point the returned signal will send that
	///            event and switch to passing through events from `replacement`
	///            instead, regardless of whether `self` has sent events
	///            already.
	public func take(untilReplacement signal: Signal<Value, Error>) -> Signal<Value, Error> {
		return Signal { observer, lifetime in
			let signalDisposable = self.observe { event in
				switch event {
				case .completed:
					break

				case .value, .failed, .interrupted:
					observer.send(event)
				}
			}

			lifetime += signalDisposable
			lifetime += signal.observe { event in
				signalDisposable?.dispose()
				observer.send(event)
			}
		}
	}

	/// Wait until `self` completes and then forward the final `count` values
	/// on the returned signal.
	///
	/// - parameters:
	///   - count: Number of last events to send after `self` completes.
	///
	/// - returns: A signal that receives up to `count` values from `self`
	///            after `self` completes.
	public func take(last count: Int) -> Signal<Value, Error> {
		return flatMapEvent(Signal.Event.take(last: count))
	}

	/// Forward any values from `self` until `shouldContinue` returns `false`, at which
	/// point the returned signal would complete.
	///
	/// - parameters:
	///   - shouldContinue: A closure to determine whether the forwarding of values should
	///                     continue.
	///
	/// - returns: A signal which conditionally forwards values from `self`.
	public func take(while shouldContinue: @escaping (Value) -> Bool) -> Signal<Value, Error> {
		return flatMapEvent(Signal.Event.take(while: shouldContinue))
	}
}

extension Signal {
	/// Zip elements of two signals into pairs. The elements of any Nth pair
	/// are the Nth elements of the two input signals.
	///
	/// - parameters:
	///   - otherSignal: A signal to zip values with.
	///
	/// - returns: A signal that sends tuples of `self` and `otherSignal`.
	public func zip<U>(with other: Signal<U, Error>) -> Signal<(Value, U), Error> {
		return Signal.zip(self, other)
	}

	/// Forward the latest value on `scheduler` after at least `interval`
	/// seconds have passed since *the returned signal* last sent a value.
	///
	/// If `self` always sends values more frequently than `interval` seconds,
	/// then the returned signal will send a value every `interval` seconds.
	///
	/// To measure from when `self` last sent a value, see `debounce`.
	///
	/// - seealso: `debounce`
	///
	/// - note: If multiple values are received before the interval has elapsed,
	///         the latest value is the one that will be passed on.
	///
	/// - note: If `self` terminates while a value is being throttled, that
	///         value will be discarded and the returned signal will terminate
	///         immediately.
	///
	/// - note: If the device time changed backwards before previous date while
	///         a value is being throttled, and if there is a new value sent,
	///         the new value will be passed anyway.
	///
	/// - precondition: `interval` must be non-negative number.
	///
	/// - parameters:
	///   - interval: Number of seconds to wait between sent values.
	///   - scheduler: A scheduler to deliver events on.
	///
	/// - returns: A signal that sends values at least `interval` seconds 
	///            appart on a given scheduler.
	public func throttle(_ interval: TimeInterval, on scheduler: DateScheduler) -> Signal<Value, Error> {
		return flatMapEvent(Signal.Event.throttle(interval, on: scheduler))
	}

	/// Conditionally throttles values sent on the receiver whenever
	/// `shouldThrottle` is true, forwarding values on the given scheduler.
	///
	/// - note: While `shouldThrottle` remains false, values are forwarded on the
	///         given scheduler. If multiple values are received while
	///         `shouldThrottle` is true, the latest value is the one that will
	///         be passed on.
	///
	/// - note: If the input signal terminates while a value is being throttled,
	///         that value will be discarded and the returned signal will
	///         terminate immediately.
	///
	/// - note: If `shouldThrottle` completes before the receiver, and its last
	///         value is `true`, the returned signal will remain in the throttled
	///         state, emitting no further values until it terminates.
	///
	/// - parameters:
	///   - shouldThrottle: A boolean property that controls whether values
	///                     should be throttled.
	///   - scheduler: A scheduler to deliver events on.
	///
	/// - returns: A signal that sends values only while `shouldThrottle` is false.
	public func throttle<P: PropertyProtocol>(while shouldThrottle: P, on scheduler: Scheduler) -> Signal<Value, Error>
		where P.Value == Bool
	{
		return Signal { observer, lifetime in
			let initial: ThrottleWhileState<Value> = .resumed
			let state = Atomic(initial)
			let schedulerDisposable = SerialDisposable()
			lifetime += schedulerDisposable

			lifetime += shouldThrottle.producer
				.skipRepeats()
				.startWithValues { shouldThrottle in
					let valueToSend = state.modify { state -> Value? in
						guard !state.isTerminated else { return nil }

						if shouldThrottle {
							state = .throttled(nil)
						} else {
							defer { state = .resumed }

							if case let .throttled(value?) = state {
								return value
							}
						}

						return nil
					}

					if let value = valueToSend {
						schedulerDisposable.inner = scheduler.schedule {
							observer.send(value: value)
						}
					}
				}

			lifetime += self.observe { event in
				let eventToSend = state.modify { state -> Event? in
					switch event {
					case let .value(value):
						switch state {
						case .throttled:
							state = .throttled(value)
							return nil
						case .resumed:
							return event
						case .terminated:
							return nil
						}

					case .completed, .interrupted, .failed:
						state = .terminated
						return event
					}
				}

				if let event = eventToSend {
					schedulerDisposable.inner = scheduler.schedule {
						observer.send(event)
					}
				}
			}
		}
	}

	/// Forward the latest value on `scheduler` after at least `interval`
	/// seconds have passed since `self` last sent a value.
	///
	/// If `self` always sends values more frequently than `interval` seconds,
	/// then the returned signal will never send any values.
	///
	/// To measure from when the *returned signal* last sent a value, see
	/// `throttle`.
	///
	/// - seealso: `throttle`
	///
	/// - note: If multiple values are received before the interval has elapsed,
	///         the latest value is the one that will be passed on.
	///
	/// - note: If `self` terminates while a value is being debounced,
	///         the behaviour will be determined by `discardWhenCompleted`.
	///         If `true`, that value will be discarded and the returned producer
	///         will terminate immediately.
	///         If `false`, that value will be delivered at the next debounce
	///         interval.
	///
	/// - precondition: `interval` must be non-negative number.
	///
	/// - parameters:
	///   - interval: A number of seconds to wait before sending a value.
	///   - scheduler: A scheduler to send values on.
	///   - discardWhenCompleted: A boolean to indicate if the latest value
	///                             should be discarded on completion.
	///
	/// - returns: A signal that sends values that are sent from `self` at least
	///            `interval` seconds apart.
	public func debounce(_ interval: TimeInterval, on scheduler: DateScheduler, discardWhenCompleted: Bool = true) -> Signal<Value, Error> {
		return flatMapEvent(Signal.Event.debounce(interval, on: scheduler, discardWhenCompleted: discardWhenCompleted))
	}
}

extension Signal {
	/// Forward only those values from `self` that have unique identities across
	/// the set of all values that have been seen.
	///
	/// - note: This causes the identities to be retained to check for 
	///         uniqueness.
	///
	/// - parameters:
	///   - transform: A closure that accepts a value and returns identity 
	///                value.
	///
	/// - returns: A signal that sends unique values during its lifetime.
	public func uniqueValues<Identity: Hashable>(_ transform: @escaping (Value) -> Identity) -> Signal<Value, Error> {
		return flatMapEvent(Signal.Event.uniqueValues(transform))
	}
}

extension Signal where Value: Hashable {
	/// Forward only those values from `self` that are unique across the set of
	/// all values that have been seen.
	///
	/// - note: This causes the values to be retained to check for uniqueness. 
	///         Providing a function that returns a unique value for each sent 
	///         value can help you reduce the memory footprint.
	///
	/// - returns: A signal that sends unique values during its lifetime.
	public func uniqueValues() -> Signal<Value, Error> {
		return uniqueValues { $0 }
	}
}

private enum ThrottleWhileState<Value> {
	case resumed
	case throttled(Value?)
	case terminated

	var isTerminated: Bool {
		switch self {
		case .terminated:
			return true
		case .resumed, .throttled:
			return false
		}
	}
}

private protocol SignalAggregateStrategy: AnyObject {
	/// Update the latest value of the signal at `position` to be `value`.
	///
	/// - parameters:
	///   - value: The latest value emitted by the signal at `position`.
	///   - position: The position of the signal.
	func update(_ value: Any, at position: Int)

	/// Record the completion of the signal at `position`.
	///
	/// - parameters:
	///   - position: The position of the signal.
	func complete(at position: Int)

	init(count: Int, action: @escaping (AggregateStrategyEvent) -> Void)
}

private enum AggregateStrategyEvent {
	case value(ContiguousArray<Any>)
	case completed
}

extension Signal {
	// Threading of `CombineLatestStrategy` and `ZipStrategy`.
	//
	// The threading models of these strategies mirror that of `Signal.Core` to allow
	// recursive termial event from the upstreams that is triggered by the combined
	// values.
	//
	// The strategies do not unique the delivery of `completed`, since `Signal` already
	// guarantees that no event would ever be delivered after a terminal event.

	private final class CombineLatestStrategy: SignalAggregateStrategy {
		private enum Placeholder {
			case none
		}

		var values: ContiguousArray<Any>

		private var _haveAllSentInitial: Bool
		private var haveAllSentInitial: Bool {
			get {
				if _haveAllSentInitial {
					return true
				}

				_haveAllSentInitial = values.allSatisfy { !($0 is Placeholder) }
				return _haveAllSentInitial
			}
		}

		private let count: Int
		private let lock: Lock

		private let completion: Atomic<Int>
		private let action: (AggregateStrategyEvent) -> Void

		func update(_ value: Any, at position: Int) {
			lock.lock()
			values[position] = value

			if haveAllSentInitial {
				action(.value(values))
			}

			lock.unlock()

			if completion.value == self.count, lock.try() {
				action(.completed)
				lock.unlock()
			}
		}

		func complete(at position: Int) {
			let count: Int = completion.modify { count in
				count += 1
				return count
			}

			if count == self.count, lock.try() {
				action(.completed)
				lock.unlock()
			}
		}

		init(count: Int, action: @escaping (AggregateStrategyEvent) -> Void) {
			self.count = count
			self.lock = Lock.make()
			self.values = ContiguousArray(repeating: Placeholder.none, count: count)
			self._haveAllSentInitial = false
			self.completion = Atomic(0)
			self.action = action
		}
	}

	private final class ZipStrategy: SignalAggregateStrategy {
		private let stateLock: Lock
		private let sendLock: Lock

		private var values: ContiguousArray<[Any]>
		private var canEmit: Bool {
			return values.reduce(true) { $0 && !$1.isEmpty }
		}

		private var hasConcurrentlyCompleted: Bool
		private var isCompleted: ContiguousArray<Bool>

		private var hasCompletedAndEmptiedSignal: Bool {
			return Swift.zip(values, isCompleted).contains(where: { $0.0.isEmpty && $0.1 })
		}

		private var areAllCompleted: Bool {
			return isCompleted.reduce(true) { $0 && $1 }
		}

		private let action: (AggregateStrategyEvent) -> Void

		func update(_ value: Any, at position: Int) {
			stateLock.lock()
			values[position].append(value)

			if canEmit {
				var buffer = ContiguousArray<Any>()
				buffer.reserveCapacity(values.count)

				for index in values.indices {
					buffer.append(values[index].removeFirst())
				}

				let shouldComplete = areAllCompleted || hasCompletedAndEmptiedSignal
				sendLock.lock()
				stateLock.unlock()

				action(.value(buffer))

				if shouldComplete {
					action(.completed)
				}

				sendLock.unlock()

				stateLock.lock()

				if hasConcurrentlyCompleted {
					sendLock.lock()
					action(.completed)
					sendLock.unlock()
				}
			}

			stateLock.unlock()
		}

		func complete(at position: Int) {
			stateLock.lock()
			isCompleted[position] = true

			if hasConcurrentlyCompleted || areAllCompleted || hasCompletedAndEmptiedSignal {
				if sendLock.try() {
					stateLock.unlock()

					action(.completed)
					sendLock.unlock()
					return
				}

				hasConcurrentlyCompleted = true
			}

			stateLock.unlock()
		}

		init(count: Int, action: @escaping (AggregateStrategyEvent) -> Void) {
			self.values = ContiguousArray(repeating: [], count: count)
			self.hasConcurrentlyCompleted = false
			self.isCompleted = ContiguousArray(repeating: false, count: count)
			self.action = action
			self.sendLock = Lock.make()
			self.stateLock = Lock.make()
		}
	}

	private final class AggregateBuilder<Strategy: SignalAggregateStrategy> {
		fileprivate var startHandlers: [(_ index: Int, _ strategy: Strategy, _ action: @escaping (Signal<Never, Error>.Event) -> Void) -> Disposable?]

		init() {
			self.startHandlers = []
		}

		@discardableResult
		func add<U>(_ signal: Signal<U, Error>) -> Self {
			startHandlers.append { index, strategy, action in
				return signal.observe { event in
					switch event {
					case let .value(value):
						strategy.update(value, at: index)

					case .completed:
						strategy.complete(at: index)

					case .interrupted:
						action(.interrupted)

					case let .failed(error):
						action(.failed(error))
					}
				}
			}

			return self
		}
	}

	private convenience init<Strategy>(_ builder: AggregateBuilder<Strategy>, _ transform: @escaping (ContiguousArray<Any>) -> Value) {
		self.init { observer, lifetime in
			let strategy = Strategy(count: builder.startHandlers.count) { event in
				switch event {
				case let .value(value):
					observer.send(value: transform(value))
				case .completed:
					observer.sendCompleted()
				}
			}

			for (index, action) in builder.startHandlers.enumerated() where !lifetime.hasEnded {
				lifetime += action(index, strategy) { observer.send($0.promoteValue()) }
			}
		}
	}

	private convenience init<Strategy: SignalAggregateStrategy, U, S: Sequence>(_ strategy: Strategy.Type, _ signals: S) where Value == [U], S.Iterator.Element == Signal<U, Error> {
		self.init(signals.reduce(AggregateBuilder<Strategy>()) { $0.add($1) }) { $0.map { $0 as! U } }
	}

	private convenience init<Strategy: SignalAggregateStrategy, A, B>(_ strategy: Strategy.Type, _ a: Signal<A, Error>, _ b: Signal<B, Error>) where Value == (A, B) {
		self.init(AggregateBuilder<Strategy>().add(a).add(b)) {
			return ($0[0] as! A, $0[1] as! B)
		}
	}

	private convenience init<Strategy: SignalAggregateStrategy, A, B, C>(_ strategy: Strategy.Type, _ a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>) where Value == (A, B, C) {
		self.init(AggregateBuilder<Strategy>().add(a).add(b).add(c)) {
			return ($0[0] as! A, $0[1] as! B, $0[2] as! C)
		}
	}

	private convenience init<Strategy: SignalAggregateStrategy, A, B, C, D>(_ strategy: Strategy.Type, _ a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>) where Value == (A, B, C, D) {
		self.init(AggregateBuilder<Strategy>().add(a).add(b).add(c).add(d)) {
			return ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D)
		}
	}

	private convenience init<Strategy: SignalAggregateStrategy, A, B, C, D, E>(_ strategy: Strategy.Type, _ a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>) where Value == (A, B, C, D, E) {
		self.init(AggregateBuilder<Strategy>().add(a).add(b).add(c).add(d).add(e)) {
			return ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E)
		}
	}

	private convenience init<Strategy: SignalAggregateStrategy, A, B, C, D, E, F>(_ strategy: Strategy.Type, _ a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>) where Value == (A, B, C, D, E, F) {
		self.init(AggregateBuilder<Strategy>().add(a).add(b).add(c).add(d).add(e).add(f)) {
			return ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E, $0[5] as! F)
		}
	}

	private convenience init<Strategy: SignalAggregateStrategy, A, B, C, D, E, F, G>(_ strategy: Strategy.Type, _ a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>) where Value == (A, B, C, D, E, F, G) {
		self.init(AggregateBuilder<Strategy>().add(a).add(b).add(c).add(d).add(e).add(f).add(g)) {
			return ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E, $0[5] as! F, $0[6] as! G)
		}
	}

	private convenience init<Strategy: SignalAggregateStrategy, A, B, C, D, E, F, G, H>(_ strategy: Strategy.Type, _ a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>) where Value == (A, B, C, D, E, F, G, H) {
		self.init(AggregateBuilder<Strategy>().add(a).add(b).add(c).add(d).add(e).add(f).add(g).add(h)) {
			return ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E, $0[5] as! F, $0[6] as! G, $0[7] as! H)
		}
	}

	private convenience init<Strategy: SignalAggregateStrategy, A, B, C, D, E, F, G, H, I>(_ strategy: Strategy.Type, _ a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>, _ i: Signal<I, Error>) where Value == (A, B, C, D, E, F, G, H, I) {
		self.init(AggregateBuilder<Strategy>().add(a).add(b).add(c).add(d).add(e).add(f).add(g).add(h).add(i)) {
			return ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E, $0[5] as! F, $0[6] as! G, $0[7] as! H, $0[8] as! I)
		}
	}

	private convenience init<Strategy: SignalAggregateStrategy, A, B, C, D, E, F, G, H, I, J>(_ strategy: Strategy.Type, _ a: Signal<A, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>, _ i: Signal<I, Error>, _ j: Signal<J, Error>) where Value == (A, B, C, D, E, F, G, H, I, J) {
		self.init(AggregateBuilder<Strategy>().add(a).add(b).add(c).add(d).add(e).add(f).add(g).add(h).add(i).add(j)) {
			return ($0[0] as! A, $0[1] as! B, $0[2] as! C, $0[3] as! D, $0[4] as! E, $0[5] as! F, $0[6] as! G, $0[7] as! H, $0[8] as! I, $0[9] as! J)
		}
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<B>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>) -> Signal<(Value, B), Error> {
		return .init(CombineLatestStrategy.self, a, b)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<B, C>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>) -> Signal<(Value, B, C), Error> {
		return .init(CombineLatestStrategy.self, a, b, c)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<B, C, D>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>) -> Signal<(Value, B, C, D), Error> {
		return .init(CombineLatestStrategy.self, a, b, c, d)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<B, C, D, E>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>) -> Signal<(Value, B, C, D, E), Error> {
		return .init(CombineLatestStrategy.self, a, b, c, d, e)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<B, C, D, E, F>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>) -> Signal<(Value, B, C, D, E, F), Error> {
		return .init(CombineLatestStrategy.self, a, b, c, d, e, f)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<B, C, D, E, F, G>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>) -> Signal<(Value, B, C, D, E, F, G), Error> {
		return .init(CombineLatestStrategy.self, a, b, c, d, e, f, g)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<B, C, D, E, F, G, H>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>) -> Signal<(Value, B, C, D, E, F, G, H), Error> {
		return .init(CombineLatestStrategy.self, a, b, c, d, e, f, g, h)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<B, C, D, E, F, G, H, I>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>, _ i: Signal<I, Error>) -> Signal<(Value, B, C, D, E, F, G, H, I), Error> {
		return .init(CombineLatestStrategy.self, a, b, c, d, e, f, g, h, i)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<B, C, D, E, F, G, H, I, J>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>, _ i: Signal<I, Error>, _ j: Signal<J, Error>) -> Signal<(Value, B, C, D, E, F, G, H, I, J), Error> {
		return .init(CombineLatestStrategy.self, a, b, c, d, e, f, g, h, i, j)
	}

	/// Combines the values of all the given signals, in the manner described by
	/// `combineLatest(with:)`. No events will be sent if the sequence is empty.
	public static func combineLatest<S: Sequence>(_ signals: S) -> Signal<[Value], Error> where S.Iterator.Element == Signal<Value, Error> {
		return .init(CombineLatestStrategy.self, signals)
	}

	/// Zip the values of all the given signals, in the manner described by `zip(with:)`.
	public static func zip<B>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>) -> Signal<(Value, B), Error> {
		return .init(ZipStrategy.self, a, b)
	}

	/// Zip the values of all the given signals, in the manner described by `zip(with:)`.
	public static func zip<B, C>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>) -> Signal<(Value, B, C), Error> {
		return .init(ZipStrategy.self, a, b, c)
	}

	/// Zip the values of all the given signals, in the manner described by `zip(with:)`.
	public static func zip<B, C, D>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>) -> Signal<(Value, B, C, D), Error> {
		return .init(ZipStrategy.self, a, b, c, d)
	}

	/// Zip the values of all the given signals, in the manner described by `zip(with:)`.
	public static func zip<B, C, D, E>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>) -> Signal<(Value, B, C, D, E), Error> {
		return .init(ZipStrategy.self, a, b, c, d, e)
	}

	/// Zip the values of all the given signals, in the manner described by `zip(with:)`.
	public static func zip<B, C, D, E, F>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>) -> Signal<(Value, B, C, D, E, F), Error> {
		return .init(ZipStrategy.self, a, b, c, d, e, f)
	}

	/// Zip the values of all the given signals, in the manner described by `zip(with:)`.
	public static func zip<B, C, D, E, F, G>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>) -> Signal<(Value, B, C, D, E, F, G), Error> {
		return .init(ZipStrategy.self, a, b, c, d, e, f, g)
	}

	/// Zip the values of all the given signals, in the manner described by `zip(with:)`.
	public static func zip<B, C, D, E, F, G, H>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>) -> Signal<(Value, B, C, D, E, F, G, H), Error> {
		return .init(ZipStrategy.self, a, b, c, d, e, f, g, h)
	}

	/// Zip the values of all the given signals, in the manner described by `zip(with:)`.
	public static func zip<B, C, D, E, F, G, H, I>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>, _ i: Signal<I, Error>) -> Signal<(Value, B, C, D, E, F, G, H, I), Error> {
		return .init(ZipStrategy.self, a, b, c, d, e, f, g, h, i)
	}

	/// Zip the values of all the given signals, in the manner described by `zip(with:)`.
	public static func zip<B, C, D, E, F, G, H, I, J>(_ a: Signal<Value, Error>, _ b: Signal<B, Error>, _ c: Signal<C, Error>, _ d: Signal<D, Error>, _ e: Signal<E, Error>, _ f: Signal<F, Error>, _ g: Signal<G, Error>, _ h: Signal<H, Error>, _ i: Signal<I, Error>, _ j: Signal<J, Error>) -> Signal<(Value, B, C, D, E, F, G, H, I, J), Error> {
		return .init(ZipStrategy.self, a, b, c, d, e, f, g, h, i, j)
	}

	/// Zips the values of all the given signals, in the manner described by
	/// `zip(with:)`. No events will be sent if the sequence is empty.
	public static func zip<S: Sequence>(_ signals: S) -> Signal<[Value], Error> where S.Iterator.Element == Signal<Value, Error> {
		return .init(ZipStrategy.self, signals)
	}
}

extension Signal {
	/// Forward events from `self` until `interval`. Then if signal isn't 
	/// completed yet, fails with `error` on `scheduler`.
	///
	/// - note: If the interval is 0, the timeout will be scheduled immediately. 
	///         The signal must complete synchronously (or on a faster
	///         scheduler) to avoid the timeout.
	///
	/// - precondition: `interval` must be non-negative number.
	///
	/// - parameters:
	///   - error: Error to send with failed event if `self` is not completed
	///            when `interval` passes.
	///   - interval: Number of seconds to wait for `self` to complete.
	///   - scheudler: A scheduler to deliver error on.
	///
	/// - returns: A signal that sends events for at most `interval` seconds,
	///            then, if not `completed` - sends `error` with failed event
	///            on `scheduler`.
	public func timeout(after interval: TimeInterval, raising error: Error, on scheduler: DateScheduler) -> Signal<Value, Error> {
		precondition(interval >= 0)

		return Signal { observer, lifetime in
			let date = scheduler.currentDate.addingTimeInterval(interval)

			lifetime += scheduler.schedule(after: date) {
				observer.send(error: error)
			}

			lifetime += self.observe(observer)
		}
	}
}

extension Signal where Error == Never {
	/// Promote a signal that does not generate failures into one that can.
	///
	/// - note: This does not actually cause failures to be generated for the
	///         given signal, but makes it easier to combine with other signals
	///         that may fail; for example, with operators like 
	///         `combineLatestWith`, `zipWith`, `flatten`, etc.
	///
	/// - parameters:
	///   - _ An `ErrorType`.
	///
	/// - returns: A signal that has an instantiatable `ErrorType`.
	public func promoteError<F>(_: F.Type = F.self) -> Signal<Value, F> {
		return flatMapEvent(Signal.Event.promoteError(F.self))
	}

	/// Promote a signal that does not generate failures into one that can.
	///
	/// - note: This does not actually cause failures to be generated for the
	///         given signal, but makes it easier to combine with other signals
	///         that may fail; for example, with operators like
	///         `combineLatestWith`, `zipWith`, `flatten`, etc.
	///
	/// - parameters:
	///   - _ An `ErrorType`.
	///
	/// - returns: A signal that has an instantiatable `ErrorType`.
	public func promoteError(_: Error.Type = Error.self) -> Signal<Value, Error> {
		return self
	}

	/// Forward events from `self` until `interval`. Then if signal isn't
	/// completed yet, fails with `error` on `scheduler`.
	///
	/// - note: If the interval is 0, the timeout will be scheduled immediately.
	///         The signal must complete synchronously (or on a faster
	///         scheduler) to avoid the timeout.
	///
	/// - parameters:
	///   - interval: Number of seconds to wait for `self` to complete.
	///   - error: Error to send with `failed` event if `self` is not completed
	///            when `interval` passes.
	///   - scheudler: A scheduler to deliver error on.
	///
	/// - returns: A signal that sends events for at most `interval` seconds,
	///            then, if not `completed` - sends `error` with `failed` event
	///            on `scheduler`.
	public func timeout<NewError>(
		after interval: TimeInterval,
		raising error: NewError,
		on scheduler: DateScheduler
	) -> Signal<Value, NewError> {
		return self
			.promoteError(NewError.self)
			.timeout(after: interval, raising: error, on: scheduler)
	}
}

extension Signal where Value == Never {
	/// Promote a signal that does not generate values, as indicated by `Never`, to be
	/// a signal of the given type of value.
	///
	/// - note: The promotion does not result in any value being generated.
	///
	/// - parameters:
	///   - _ The type of value to promote to.
	///
	/// - returns: A signal that forwards all terminal events from `self`.
	public func promoteValue<U>(_: U.Type = U.self) -> Signal<U, Error> {
		return flatMapEvent(Signal.Event.promoteValue(U.self))
	}

	/// Promote a signal that does not generate values, as indicated by `Never`, to be
	/// a signal of the given type of value.
	///
	/// - note: The promotion does not result in any value being generated.
	///
	/// - parameters:
	///   - _ The type of value to promote to.
	///
	/// - returns: A signal that forwards all terminal events from `self`.
	public func promoteValue(_: Value.Type = Value.self) -> Signal<Value, Error> {
		return self
	}
}

extension Signal where Value == Bool {
	/// Create a signal that computes a logical NOT in the latest values of `self`.
	///
	/// - returns: A signal that emits the logical NOT results.
	public func negate() -> Signal<Value, Error> {
		return self.map(!)
	}

	/// Create a signal that computes a logical AND between the latest values of `self`
	/// and `signal`.
	///
	/// - parameters:
	///   - signal: Signal to be combined with `self`.
	///
	/// - returns: A signal that emits the logical AND results.
	public func and(_ signal: Signal<Value, Error>) -> Signal<Value, Error> {
		return type(of: self).all([self, signal])
	}
	
	/// Create a signal that computes a logical AND between the latest values of `booleans`.
	///
	/// - parameters:
	///   - booleans: A collection of boolean signals to be combined.
	///
	/// - returns: A signal that emits the logical AND results.
	public static func all<BooleansCollection: Collection>(_ booleans: BooleansCollection) -> Signal<Value, Error> where BooleansCollection.Element == Signal<Value, Error> {
		return combineLatest(booleans).map { $0.reduce(true) { $0 && $1 } }
	}
    
    /// Create a signal that computes a logical AND between the latest values of `booleans`.
    ///
    /// - parameters:
    ///   - booleans: Boolean signals to be combined.
    ///
    /// - returns: A signal that emits the logical AND results.
    public static func all(_ booleans: Signal<Value, Error>...) -> Signal<Value, Error> {
        return .all(booleans)
    }

	/// Create a signal that computes a logical OR between the latest values of `self`
	/// and `signal`.
	///
	/// - parameters:
	///   - signal: Signal to be combined with `self`.
	///
	/// - returns: A signal that emits the logical OR results.
	public func or(_ signal: Signal<Value, Error>) -> Signal<Value, Error> {
		return type(of: self).any([self, signal])
	}
	
	/// Create a signal that computes a logical OR between the latest values of `booleans`.
	///
	/// - parameters:
	///   - booleans: A collection of boolean signals to be combined.
	///
	/// - returns: A signal that emits the logical OR results.
	public static func any<BooleansCollection: Collection>(_ booleans: BooleansCollection) -> Signal<Value, Error> where BooleansCollection.Element == Signal<Value, Error> {
		return combineLatest(booleans).map { $0.reduce(false) { $0 || $1 } }
    }
    
    /// Create a signal that computes a logical OR between the latest values of `booleans`.
    ///
    /// - parameters:
    ///   - booleans: Boolean signals to be combined.
    ///
    /// - returns: A signal that emits the logical OR results.
    public static func any(_ booleans: Signal<Value, Error>...) -> Signal<Value, Error> {
        return .any(booleans)
    }
}

extension Signal {
	/// Apply an action to every value from `self`, and forward the value if the action
	/// succeeds. If the action fails with an error, the returned `Signal` would propagate
	/// the failure and terminate.
	///
	/// - parameters:
	///   - action: An action which yields a `Result`.
	///
	/// - returns: A signal which forwards the values from `self` until the given action
	///            fails.
	public func attempt(_ action: @escaping (Value) -> Result<(), Error>) -> Signal<Value, Error> {
		return flatMapEvent(Signal.Event.attempt(action))
	}

	/// Apply a transform to every value from `self`, and forward the transformed value
	/// if the action succeeds. If the action fails with an error, the returned `Signal`
	/// would propagate the failure and terminate.
	///
	/// - parameters:
	///   - action: A transform which yields a `Result` of the transformed value or the
	///             error.
	///
	/// - returns: A signal which forwards the transformed values.
	public func attemptMap<U>(_ transform: @escaping (Value) -> Result<U, Error>) -> Signal<U, Error> {
		return flatMapEvent(Signal.Event.attemptMap(transform))
	}
}

extension Signal where Error == Never {
	/// Apply a throwable action to every value from `self`, and forward the values
	/// if the action succeeds. If the action throws an error, the returned `Signal`
	/// would propagate the failure and terminate.
	///
	/// - parameters:
	///   - action: A throwable closure to perform an arbitrary action on the value.
	///
	/// - returns: A signal which forwards the successful values of the given action.
	public func attempt(_ action: @escaping (Value) throws -> Void) -> Signal<Value, Swift.Error> {
		return self
			.promoteError(Swift.Error.self)
			.attempt(action)
	}

	/// Apply a throwable transform to every value from `self`, and forward the results
	/// if the action succeeds. If the transform throws an error, the returned `Signal`
	/// would propagate the failure and terminate.
	///
	/// - parameters:
	///   - transform: A throwable transform.
	///
	/// - returns: A signal which forwards the successfully transformed values.
	public func attemptMap<U>(_ transform: @escaping (Value) throws -> U) -> Signal<U, Swift.Error> {
		return self
			.promoteError(Swift.Error.self)
			.attemptMap(transform)
	}
}

extension Signal where Error == Swift.Error {
	/// Apply a throwable action to every value from `self`, and forward the values
	/// if the action succeeds. If the action throws an error, the returned `Signal`
	/// would propagate the failure and terminate.
	///
	/// - parameters:
	///   - action: A throwable closure to perform an arbitrary action on the value.
	///
	/// - returns: A signal which forwards the successful values of the given action.
	public func attempt(_ action: @escaping (Value) throws -> Void) -> Signal<Value, Error> {
		return flatMapEvent(Signal.Event.attempt(action))
	}

	/// Apply a throwable transform to every value from `self`, and forward the results
	/// if the action succeeds. If the transform throws an error, the returned `Signal`
	/// would propagate the failure and terminate.
	///
	/// - parameters:
	///   - transform: A throwable transform.
	///
	/// - returns: A signal which forwards the successfully transformed values.
	public func attemptMap<U>(_ transform: @escaping (Value) throws -> U) -> Signal<U, Error> {
		return flatMapEvent(Signal.Event.attemptMap(transform))
	}
}
