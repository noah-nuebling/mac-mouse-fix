import Dispatch
import Foundation

/// A SignalProducer creates Signals that can produce values of type `Value`
/// and/or fail with errors of type `Error`. If no failure should be possible,
/// `Never` can be specified for `Error`.
///
/// SignalProducers can be used to represent operations or tasks, like network
/// requests, where each invocation of `start()` will create a new underlying
/// operation. This ensures that consumers will receive the results, versus a
/// plain Signal, where the results might be sent before any observers are
/// attached.
///
/// Because of the behavior of `start()`, different Signals created from the
/// producer may see a different version of Events. The Events may arrive in a
/// different order between Signals, or the stream might be completely
/// different!
public struct SignalProducer<Value, Error: Swift.Error> {
	public typealias ProducedSignal = Signal<Value, Error>

	/// `core` is the actual implementation for this `SignalProducer`. It is responsible
	/// of:
	///
	/// 1. handling the single-observer `start`; and
	/// 2. building `Signal`s on demand via its `makeInstance()` method, which produces a
	///    `Signal` with the associated side effect and interrupt handle.
	fileprivate let core: SignalProducerCore<Value, Error>

	/// Convert an entity into its equivalent representation as `SignalProducer`.
	///
	/// - parameters:
	///   - base: The entity to convert from.
	public init<T: SignalProducerConvertible>(_ base: T) where T.Value == Value, T.Error == Error {
		self = base.producer
	}

	/// Initializes a `SignalProducer` that will emit the same events as the
	/// given signal.
	///
	/// If the Disposable returned from `start()` is disposed or a terminating
	/// event is sent to the observer, the given signal will be disposed.
	///
	/// - parameters:
	///   - signal: A signal to observe after starting the producer.
	public init(_ signal: Signal<Value, Error>) {
		self.init { observer, lifetime in
			lifetime += signal.observe(observer)
		}
	}

	/// Initialize a `SignalProducer` which invokes the supplied starting side
	/// effect once upon the creation of every produced `Signal`, or in other
	/// words, for every invocation of `startWithSignal(_:)`, `start(_:)` and
	/// their convenience shorthands.
	///
	/// The supplied starting side effect would be given (1) an input `Observer`
	/// to emit events to the produced `Signal`; and (2) a `Lifetime` to bind
	/// resources to the lifetime of the produced `Signal`.
	///
	/// The `Lifetime` of a produced `Signal` ends when: (1) a terminal event is
	/// sent to the input `Observer`; or (2) when the produced `Signal` is
	/// interrupted via the disposable yielded at the starting call.
	///
	/// - parameters:
	///   - startHandler: The starting side effect.
	public init(_ startHandler: @escaping (Signal<Value, Error>.Observer, Lifetime) -> Void) {
		self.init(SignalCore {
			let disposable = CompositeDisposable()
			let (signal, observer) = Signal<Value, Error>.pipe(disposable: disposable)
			let observerDidSetup = { startHandler(observer, Lifetime(disposable)) }
			let interruptHandle = AnyDisposable(observer.sendInterrupted)

			return SignalProducerCore.Instance(signal: signal,
			                                   observerDidSetup: observerDidSetup,
			                                   interruptHandle: interruptHandle)
		})
	}

	/// Create a SignalProducer.
	///
	/// - parameters:
	///   - core: The `SignalProducer` core.
	internal init(_ core: SignalProducerCore<Value, Error>) {
		self.core = core
	}

	/// Creates a producer for a `Signal` that will immediately send one value
	/// then complete.
	///
	/// - parameters:
	///   - value: A value that should be sent by the `Signal` in a `value`
	///            event.
	public init(value: Value) {
		self.init(GeneratorCore { observer, _ in
			observer.send(value: value)
			observer.sendCompleted()
		})
	}

	/// Creates a producer for a `Signal` that immediately sends one value, then
	/// completes.
	///
	/// This initializer differs from `init(value:)` in that its sole `value`
	/// event is constructed lazily by invoking the supplied `action` when
	/// the `SignalProducer` is started.
	///
	/// - parameters:
	///   - action: A action that yields a value to be sent by the `Signal` as
	///             a `value` event.
	public init(_ action: @escaping () -> Value) {
		self.init(GeneratorCore { observer, _ in
			observer.send(value: action())
			observer.sendCompleted()
		})
	}

	/// Create a `SignalProducer` that will attempt the given operation once for
	/// each invocation of `start()`.
	///
	/// Upon success, the started signal will send the resulting value then
	/// complete. Upon failure, the started signal will fail with the error that
	/// occurred.
	///
	/// - parameters:
	///   - action: A closure that returns instance of `Result`.
	public init(_ action: @escaping () -> Result<Value, Error>) {
		self.init(GeneratorCore { observer, _ in
			switch action() {
			case let .success(value):
				observer.send(value: value)
				observer.sendCompleted()
			case let .failure(error):
				observer.send(error: error)
			}
		})
	}

	/// Creates a producer for a `Signal` that will immediately fail with the
	/// given error.
	///
	/// - parameters:
	///   - error: An error that should be sent by the `Signal` in a `failed`
	///            event.
	public init(error: Error) {
		self.init(GeneratorCore { observer, _ in observer.send(error: error) })
	}

	/// Creates a producer for a Signal that will immediately send one value
	/// then complete, or immediately fail, depending on the given Result.
	///
	/// - parameters:
	///   - result: A `Result` instance that will send either `value` event if
	///             `result` is `success`ful or `failed` event if `result` is a
	///             `failure`.
	public init(result: Result<Value, Error>) {
		switch result {
		case let .success(value):
			self.init(value: value)

		case let .failure(error):
			self.init(error: error)
		}
	}

	/// Creates a producer for a Signal that will immediately send the values
	/// from the given sequence, then complete.
	///
	/// - parameters:
	///   - values: A sequence of values that a `Signal` will send as separate
	///             `value` events and then complete.
	public init<S: Sequence>(_ values: S) where S.Iterator.Element == Value {
		self.init(GeneratorCore(isDisposable: true) { observer, disposable in
			for value in values {
				observer.send(value: value)

				if disposable.isDisposed {
					break
				}
			}

			observer.sendCompleted()
		})
	}

	/// Creates a producer for a Signal that will immediately send the values
	/// from the given sequence, then complete.
	///
	/// - parameters:
	///   - first: First value for the `Signal` to send.
	///   - second: Second value for the `Signal` to send.
	///   - tail: Rest of the values to be sent by the `Signal`.
	public init(values first: Value, _ second: Value, _ tail: Value...) {
		self.init([ first, second ] + tail)
	}

	/// A producer for a Signal that immediately completes without sending any values.
	public static var empty: SignalProducer {
		return SignalProducer(GeneratorCore { observer, _ in observer.sendCompleted() })
	}

	/// A producer for a Signal that immediately interrupts when started, without
	/// sending any values.
	internal static var interrupted: SignalProducer {
		return SignalProducer(GeneratorCore { observer, _ in observer.sendInterrupted() })
	}

	/// A producer for a Signal that never sends any events to its observers.
	public static var never: SignalProducer {
		return self.init { observer, lifetime in
			lifetime.observeEnded { _ = observer }
		}
	}

	/// Create a `Signal` from `self`, pass it into the given closure, and start the
	/// associated work on the produced `Signal` as the closure returns.
	///
	/// - parameters:
	///   - setup: A closure to be invoked before the work associated with the produced
	///            `Signal` commences. Both the produced `Signal` and an interrupt handle
	///            of the signal would be passed to the closure.
	/// - returns: The return value of the given setup closure.
	@discardableResult
	public func startWithSignal<Result>(_ setup: (_ signal: Signal<Value, Error>, _ interruptHandle: Disposable) -> Result) -> Result {
		let instance = core.makeInstance()
		let result = setup(instance.signal, instance.interruptHandle)
		if !instance.interruptHandle.isDisposed {
			instance.observerDidSetup()
		}
		return result
	}
}

/// `SignalProducerCore` is the actual implementation of a `SignalProducer`.
///
/// While `SignalProducerCore` still requires all subclasses to be able to produce
/// instances of `Signal`s, the abstraction enables room of optimization for common
/// compositional and single-observer use cases.
internal class SignalProducerCore<Value, Error: Swift.Error> {
	/// `Instance` represents an instance of `Signal` created from a
	/// `SignalProducer`. In addition to the `Signal` itself, it includes also the
	/// starting side effect and an interrupt handle for this particular instance.
	///
	/// It is the responsibility of the `Instance` consumer to ensure the
	/// starting side effect is invoked exactly once, and is invoked after observations
	/// has properly setup.
	struct Instance {
		let signal: Signal<Value, Error>
		let observerDidSetup: () -> Void
		let interruptHandle: Disposable
	}

	func makeInstance() -> Instance {
		fatalError()
	}

	/// Start the producer with an observer created by the given generator.
	///
	/// The created observer **must** manaully dispose of the given upstream interrupt
	/// handle iff it performs any event transformation that might result in a terminal
	/// event.
	///
	/// - parameters:
	///   - generator: The closure to generate an observer.
	///
	/// - returns: A disposable to interrupt the started producer instance.
	@discardableResult
	func start(_ generator: (_ upstreamInterruptHandle: Disposable) -> Signal<Value, Error>.Observer) -> Disposable {
		fatalError()
	}

	/// Perform an action upon every event from `self`. The action may generate zero or
	/// more events.
	///
	/// - precondition: The action must be synchronous.
	///
	/// - parameters:
	///   - transform: A closure that creates the said action from the given event
	///                closure.
	///
	/// - returns: A producer that forwards events yielded by the action.
	internal func flatMapEvent<U, E>(_ transform: @escaping Signal<Value, Error>.Event.Transformation<U, E>) -> SignalProducer<U, E> {
		return SignalProducer<U, E>(TransformerCore(source: self, transform: transform))
	}
}

private final class SignalCore<Value, Error: Swift.Error>: SignalProducerCore<Value, Error> {
	private let _make: () -> Instance

	init(_ action: @escaping () -> Instance) {
		self._make = action
	}

	@discardableResult
	override func start(_ generator: (Disposable) -> Signal<Value, Error>.Observer) -> Disposable {
		let instance = makeInstance()
		instance.signal.observe(generator(instance.interruptHandle))
		instance.observerDidSetup()
		return instance.interruptHandle
	}

	override func makeInstance() -> Instance {
		return _make()
	}
}

/// `TransformerCore` composes event transforms, and is intended to back synchronous
/// `SignalProducer` operators in general via the core-level operator `Core.flatMapEvent`.
///
/// It takes advantage of the deferred, single-observer nature of SignalProducer. For
/// example, when we do:
///
/// ```
/// upstream.map(transform).compactMap(filteringTransform).start()
/// ```
///
/// It is contractually guaranteed that these operators would always end up producing a
/// chain of streams, each with a _single and persistent_ observer to its upstream. The
/// multicasting & detaching capabilities of Signal is useless in these scenarios.
///
/// So TransformerCore builds on top of this very fact, and composes directly at the
/// level of event transforms, without any `Signal` in between.
///
/// - note: This core does not use `Signal` unless it is requested via `makeInstance()`.
private final class TransformerCore<Value, Error: Swift.Error, SourceValue, SourceError: Swift.Error>: SignalProducerCore<Value, Error> {
	private let source: SignalProducerCore<SourceValue, SourceError>
	private let transform: Signal<SourceValue, SourceError>.Event.Transformation<Value, Error>

	init(source: SignalProducerCore<SourceValue, SourceError>, transform: @escaping Signal<SourceValue, SourceError>.Event.Transformation<Value, Error>) {
		self.source = source
		self.transform = transform
	}

	@discardableResult
	internal override func start(_ generator: (Disposable) -> Signal<Value, Error>.Observer) -> Disposable {
		// Collect all resources related to this transformed producer instance.
		let disposables = CompositeDisposable()

		source.start { upstreamInterrupter in
			// Backpropagate the terminal event, if any, to the upstream.
			disposables += upstreamInterrupter

			var hasDeliveredTerminalEvent = false

			// Generate the output sink that receives transformed output.
			let output = generator(disposables)

			// Wrap the output sink to enforce the "no event beyond the terminal
			// event" contract, and the disposal upon termination.
			let wrappedOutput = Signal<Value, Error>.Observer { event in
				if !hasDeliveredTerminalEvent {
					output.send(event)

					if event.isTerminating {
						// Mark that a terminal event has already been
						// delivered.
						hasDeliveredTerminalEvent = true

						// Disposed of all associated resources, and notify
						// the upstream too.
						disposables.dispose()
					}
				}
			}

			// Create an input sink whose events would go through the given
			// event transformation, and have the resulting events propagated
			// to the output sink above.
			let input = transform(wrappedOutput, Lifetime(disposables))

			// Return the input sink to the source producer core.
			return input.assumeUnboundDemand()
		}

		// Manual interruption disposes of `disposables`, which in turn notifies
		// the event transformation side effects, and the upstream instance.
		return disposables
	}

	internal override func flatMapEvent<U, E>(_ transform: @escaping Signal<Value, Error>.Event.Transformation<U, E>) -> SignalProducer<U, E> {
		return SignalProducer<U, E>(TransformerCore<U, E, SourceValue, SourceError>(source: source) { [innerTransform = self.transform] action, lifetime in
			return innerTransform(transform(action, lifetime), lifetime)
		})
	}

	internal override func makeInstance() -> Instance {
		let disposable = SerialDisposable()
		let (signal, observer) = Signal<Value, Error>.pipe(disposable: disposable)

		func observerDidSetup() {
			start { interrupter in
				disposable.inner = interrupter
				return observer
			}
		}

		return Instance(signal: signal,
		                observerDidSetup: observerDidSetup,
		                interruptHandle: disposable)
	}
}

/// `GeneratorCore` wraps a generator closure that would be invoked upon a produced
/// `Signal` when started. The generator closure is passed only the input observer and the
/// cancel disposable.
///
/// It is intended for constant `SignalProducers`s that synchronously emits all events
/// without escaping the `Observer`.
///
/// - note: This core does not use `Signal` unless it is requested via `makeInstance()`.
private final class GeneratorCore<Value, Error: Swift.Error>: SignalProducerCore<Value, Error> {
	private let isDisposable: Bool
	private let generator: (Signal<Value, Error>.Observer, Disposable) -> Void

	init(isDisposable: Bool = false, _ generator: @escaping (Signal<Value, Error>.Observer, Disposable) -> Void) {
		self.isDisposable = isDisposable
		self.generator = generator
	}

	@discardableResult
	internal override func start(_ observerGenerator: (Disposable) -> Signal<Value, Error>.Observer) -> Disposable {
		// Object allocation is a considerable overhead. So unless the core is configured
		// to be disposable, we would reuse the already-disposed, shared `NopDisposable`.
		let d: Disposable = isDisposable ? _SimpleDisposable() : NopDisposable.shared
		generator(observerGenerator(d), d)
		return d
	}

	internal override func makeInstance() -> Instance {
		let (signal, observer) = Signal<Value, Error>.pipe()
		let d = AnyDisposable(observer.sendInterrupted)

		return Instance(signal: signal,
		                             observerDidSetup: { self.generator(observer, d) },
		                             interruptHandle: d)
	}
}

extension SignalProducer where Error == Never {
	/// Creates a producer for a `Signal` that will immediately send one value
	/// then complete.
	///
	/// - parameters:
	///   - value: A value that should be sent by the `Signal` in a `value`
	///            event.
	public init(value: Value) {
		self.init(GeneratorCore { observer, _ in
			observer.send(value: value)
			observer.sendCompleted()
		})
	}

	/// Creates a producer for a Signal that will immediately send the values
	/// from the given sequence, then complete.
	///
	/// - parameters:
	///   - values: A sequence of values that a `Signal` will send as separate
	///             `value` events and then complete.
	public init<S: Sequence>(_ values: S) where S.Iterator.Element == Value {
		self.init(GeneratorCore(isDisposable: true) { observer, disposable in
			for value in values {
				observer.send(value: value)

				if disposable.isDisposed {
					break
				}
			}

			observer.sendCompleted()
		})
	}

	/// Creates a producer for a Signal that will immediately send the values
	/// from the given sequence, then complete.
	///
	/// - parameters:
	///   - first: First value for the `Signal` to send.
	///   - second: Second value for the `Signal` to send.
	///   - tail: Rest of the values to be sent by the `Signal`.
	public init(values first: Value, _ second: Value, _ tail: Value...) {
		self.init([ first, second ] + tail)
	}
}

extension SignalProducer where Error == Swift.Error {
	/// Create a `SignalProducer` that will attempt the given failable operation once for
	/// each invocation of `start()`.
	///
	/// Upon success, the started producer will send the resulting value then
	/// complete. Upon failure, the started signal will fail with the error that
	/// occurred.
	///
	/// - parameters:
	///   - operation: A failable closure.
	public init(_ action: @escaping () throws -> Value) {
		self.init {
			return Result {
				return try action()
			}
		}
	}
}

/// Represents reactive primitives that can be represented by `SignalProducer`.
public protocol SignalProducerConvertible {
	/// The type of values being sent by `self`.
	associatedtype Value

	/// The type of error that can occur on `self`.
	associatedtype Error: Swift.Error

	/// The `SignalProducer` representation of `self`.
	var producer: SignalProducer<Value, Error> { get }
}

/// A protocol for constraining associated types to `SignalProducer`.
public protocol SignalProducerProtocol {
	/// The type of values being sent by `self`.
	associatedtype Value

	/// The type of error that can occur on `self`.
	associatedtype Error: Swift.Error

	/// The materialized `self`.
	var producer: SignalProducer<Value, Error> { get }
}

extension SignalProducer: SignalProducerConvertible, SignalProducerProtocol {
	public var producer: SignalProducer {
		return self
	}
}

extension SignalProducer {
	/// Create a `Signal` from `self`, and observe it with the given observer.
	///
	/// - parameters:
	///   - observer: An observer to attach to the produced `Signal`.
	///
	/// - returns: A disposable to interrupt the produced `Signal`.
	@discardableResult
	public func start(_ observer: Signal<Value, Error>.Observer = .init()) -> Disposable {
		return core.start { _ in observer }
	}

	/// Create a `Signal` from `self`, and observe the `Signal` for all events
	/// being emitted.
	///
	/// - parameters:
	///   - action: A closure to be invoked with every event from `self`.
	///
	/// - returns: A disposable to interrupt the produced `Signal`.
	@discardableResult
	public func start(_ action: @escaping Signal<Value, Error>.Observer.Action) -> Disposable {
		return start(Signal.Observer(action))
	}

	/// Create a `Signal` from `self`, and observe the `Signal` for all values being
	/// emitted, and if any, its failure.
	///
	/// - parameters:
	///   - action: A closure to be invoked with values from `self`, or the propagated
	///             error should any `failed` event is emitted.
	///
	/// - returns: A disposable to interrupt the produced `Signal`.
	@discardableResult
	public func startWithResult(_ action: @escaping (Result<Value, Error>) -> Void) -> Disposable {
		return start(
			Signal.Observer(
				value: { action(.success($0)) },
				failed: { action(.failure($0)) }
			)
		)
	}

	/// Create a `Signal` from `self`, and observe its completion.
	///
	/// - parameters:
	///   - action: A closure to be invoked when a `completed` event is emitted.
	///
	/// - returns: A disposable to interrupt the produced `Signal`.
	@discardableResult
	public func startWithCompleted(_ action: @escaping () -> Void) -> Disposable {
		return start(Signal.Observer(completed: action))
	}

	/// Create a `Signal` from `self`, and observe its failure.
	///
	/// - parameters:
	///   - action: A closure to be invoked with the propagated error, should any
	///             `failed` event is emitted.
	///
	/// - returns: A disposable to interrupt the produced `Signal`.
	@discardableResult
	public func startWithFailed(_ action: @escaping (Error) -> Void) -> Disposable {
		return start(Signal.Observer(failed: action))
	}

	/// Create a `Signal` from `self`, and observe its interruption.
	///
	/// - parameters:
	///   - action: A closure to be invoked when an `interrupted` event is emitted.
	///
	/// - returns: A disposable to interrupt the produced `Signal`.
	@discardableResult
	public func startWithInterrupted(_ action: @escaping () -> Void) -> Disposable {
		return start(Signal.Observer(interrupted: action))
	}

	/// Creates a `Signal` from the producer.
	///
	/// This is equivalent to `SignalProducer.startWithSignal`, but it has 
	/// the downside that any values emitted synchronously upon starting will 
	/// be missed by the observer, because it won't be able to subscribe in time.
	/// That's why we don't want this method to be exposed as `public`, 
	/// but it's useful internally.
	internal func startAndRetrieveSignal() -> Signal<Value, Error> {
		var result: Signal<Value, Error>!
		self.startWithSignal { signal, _ in
			result = signal
		}

		return result
	}

	/// Create a `Signal` from `self` in the manner described by `startWithSignal`, and
	/// put the interrupt handle into the given `CompositeDisposable`.
	///
	/// - parameters:
	///   - lifetime: The `Lifetime` the interrupt handle to be added to.
	///   - setup: A closure that accepts the produced `Signal`.
	fileprivate func startWithSignal(during lifetime: Lifetime, setup: (Signal<Value, Error>) -> Void) {
		startWithSignal { signal, interruptHandle in
			lifetime += interruptHandle
			setup(signal)
		}
	}
}

extension SignalProducer where Error == Never {
	/// Create a `Signal` from `self`, and observe the `Signal` for all values being
	/// emitted.
	///
	/// - parameters:
	///   - action: A closure to be invoked with values from the produced `Signal`.
	///
	/// - returns: A disposable to interrupt the produced `Signal`.
	@discardableResult
	public func startWithValues(_ action: @escaping (Value) -> Void) -> Disposable {
		return start(Signal.Observer(value: action))
	}
}

extension SignalProducer {
	/// Lift an unary Signal operator to operate upon SignalProducers instead.
	///
	/// In other words, this will create a new `SignalProducer` which will apply
	/// the given `Signal` operator to _every_ created `Signal`, just as if the
	/// operator had been applied to each `Signal` yielded from `start()`.
	///
	/// - parameters:
	///   - transform: An unary operator to lift.
	///
	/// - returns: A signal producer that applies signal's operator to every
	///            created signal.
	public func lift<U, F>(_ transform: @escaping (Signal<Value, Error>) -> Signal<U, F>) -> SignalProducer<U, F> {
		return SignalProducer<U, F> { observer, lifetime in
			self.startWithSignal { signal, interrupter in
				lifetime += interrupter
				lifetime += transform(signal).observe(observer)
			}
		}
	}

	/// Lift a binary Signal operator to operate upon SignalProducers.
	///
	/// The left producer would first be started. When both producers are synchronous this
	/// order can be important depending on the operator to generate correct results.
	///
	/// - returns: A factory that creates a SignalProducer with the given operator
	///            applied. `self` would be the LHS, and the factory input would
	///            be the RHS.
	internal func liftLeft<U, F, V, G>(_ transform: @escaping (Signal<Value, Error>) -> (Signal<U, F>) -> Signal<V, G>) -> (SignalProducer<U, F>) -> SignalProducer<V, G> {
		return { right in
			return SignalProducer<V, G> { observer, lifetime in
				right.startWithSignal { rightSignal, rightInterrupter in
					lifetime += rightInterrupter

					self.startWithSignal { leftSignal, leftInterrupter in
						lifetime += leftInterrupter
						lifetime += transform(leftSignal)(rightSignal).observe(observer)
					}
				}
			}
		}
	}

	/// Lift a binary Signal operator to operate upon SignalProducers.
	///
	/// The right producer would first be started. When both producers are synchronous
	/// this order can be important depending on the operator to generate correct results.
	///
	/// - returns: A factory that creates a SignalProducer with the given operator
	///            applied. `self` would be the LHS, and the factory input would
	///            be the RHS.
	internal func liftRight<U, F, V, G>(_ transform: @escaping (Signal<Value, Error>) -> (Signal<U, F>) -> Signal<V, G>) -> (SignalProducer<U, F>) -> SignalProducer<V, G> {
		return { right in
			return SignalProducer<V, G> { observer, lifetime in
				self.startWithSignal { leftSignal, leftInterrupter in
					lifetime += leftInterrupter

					right.startWithSignal { rightSignal, rightInterrupter in
						lifetime += rightInterrupter
						lifetime += transform(leftSignal)(rightSignal).observe(observer)
					}
				}
			}
		}
	}

	/// Lift a binary Signal operator to operate upon SignalProducers instead.
	///
	/// In other words, this will create a new `SignalProducer` which will apply
	/// the given `Signal` operator to _every_ `Signal` created from the two
	/// producers, just as if the operator had been applied to each `Signal`
	/// yielded from `start()`.
	///
	/// - note: starting the returned producer will start the receiver of the
	///         operator, which may not be adviseable for some operators.
	///
	/// - parameters:
	///   - transform: A binary operator to lift.
	///
	/// - returns: A binary operator that operates on two signal producers.
	public func lift<U, F, V, G>(_ transform: @escaping (Signal<Value, Error>) -> (Signal<U, F>) -> Signal<V, G>) -> (SignalProducer<U, F>) -> SignalProducer<V, G> {
		return liftRight(transform)
	}
}

/// Start the producers in the argument order.
///
/// - parameters:
///   - disposable: The `CompositeDisposable` to collect the interrupt handles of all
///                 produced `Signal`s.
///   - setup: The closure to accept all produced `Signal`s at once.
private func flattenStart<A, B, Error>(_ lifetime: Lifetime, _ a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ setup: (Signal<A, Error>, Signal<B, Error>) -> Void) {
	b.startWithSignal(during: lifetime) { b in
		a.startWithSignal(during: lifetime) { setup($0, b) }
	}
}

/// Start the producers in the argument order.
///
/// - parameters:
///   - disposable: The `CompositeDisposable` to collect the interrupt handles of all
///                 produced `Signal`s.
///   - setup: The closure to accept all produced `Signal`s at once.
private func flattenStart<A, B, C, Error>(_ lifetime: Lifetime, _ a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ setup: (Signal<A, Error>, Signal<B, Error>, Signal<C, Error>) -> Void) {
	c.startWithSignal(during: lifetime) { c in
		flattenStart(lifetime, a, b) { setup($0, $1, c) }
	}
}

/// Start the producers in the argument order.
///
/// - parameters:
///   - disposable: The `CompositeDisposable` to collect the interrupt handles of all
///                 produced `Signal`s.
///   - setup: The closure to accept all produced `Signal`s at once.
private func flattenStart<A, B, C, D, Error>(_ lifetime: Lifetime, _ a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ setup: (Signal<A, Error>, Signal<B, Error>, Signal<C, Error>, Signal<D, Error>) -> Void) {
	d.startWithSignal(during: lifetime) { d in
		flattenStart(lifetime, a, b, c) { setup($0, $1, $2, d) }
	}
}

/// Start the producers in the argument order.
///
/// - parameters:
///   - disposable: The `CompositeDisposable` to collect the interrupt handles of all
///                 produced `Signal`s.
///   - setup: The closure to accept all produced `Signal`s at once.
private func flattenStart<A, B, C, D, E, Error>(_ lifetime: Lifetime, _ a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ setup: (Signal<A, Error>, Signal<B, Error>, Signal<C, Error>, Signal<D, Error>, Signal<E, Error>) -> Void) {
	e.startWithSignal(during: lifetime) { e in
		flattenStart(lifetime, a, b, c, d) { setup($0, $1, $2, $3, e) }
	}
}

/// Start the producers in the argument order.
///
/// - parameters:
///   - disposable: The `CompositeDisposable` to collect the interrupt handles of all
///                 produced `Signal`s.
///   - setup: The closure to accept all produced `Signal`s at once.
private func flattenStart<A, B, C, D, E, F, Error>(_ lifetime: Lifetime, _ a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ setup: (Signal<A, Error>, Signal<B, Error>, Signal<C, Error>, Signal<D, Error>, Signal<E, Error>, Signal<F, Error>) -> Void) {
	f.startWithSignal(during: lifetime) { f in
		flattenStart(lifetime, a, b, c, d, e) { setup($0, $1, $2, $3, $4, f) }
	}
}

/// Start the producers in the argument order.
///
/// - parameters:
///   - disposable: The `CompositeDisposable` to collect the interrupt handles of all
///                 produced `Signal`s.
///   - setup: The closure to accept all produced `Signal`s at once.
private func flattenStart<A, B, C, D, E, F, G, Error>(_ lifetime: Lifetime, _ a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ setup: (Signal<A, Error>, Signal<B, Error>, Signal<C, Error>, Signal<D, Error>, Signal<E, Error>, Signal<F, Error>, Signal<G, Error>) -> Void) {
	g.startWithSignal(during: lifetime) { g in
		flattenStart(lifetime, a, b, c, d, e, f) { setup($0, $1, $2, $3, $4, $5, g) }
	}
}

/// Start the producers in the argument order.
///
/// - parameters:
///   - disposable: The `CompositeDisposable` to collect the interrupt handles of all
///                 produced `Signal`s.
///   - setup: The closure to accept all produced `Signal`s at once.
private func flattenStart<A, B, C, D, E, F, G, H, Error>(_ lifetime: Lifetime, _ a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ h: SignalProducer<H, Error>, _ setup: (Signal<A, Error>, Signal<B, Error>, Signal<C, Error>, Signal<D, Error>, Signal<E, Error>, Signal<F, Error>, Signal<G, Error>, Signal<H, Error>) -> Void) {
	h.startWithSignal(during: lifetime) { h in
		flattenStart(lifetime, a, b, c, d, e, f, g) { setup($0, $1, $2, $3, $4, $5, $6, h) }
	}
}

/// Start the producers in the argument order.
///
/// - parameters:
///   - disposable: The `CompositeDisposable` to collect the interrupt handles of all
///                 produced `Signal`s.
///   - setup: The closure to accept all produced `Signal`s at once.
private func flattenStart<A, B, C, D, E, F, G, H, I, Error>(_ lifetime: Lifetime, _ a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ h: SignalProducer<H, Error>, _ i: SignalProducer<I, Error>, _ setup: (Signal<A, Error>, Signal<B, Error>, Signal<C, Error>, Signal<D, Error>, Signal<E, Error>, Signal<F, Error>, Signal<G, Error>, Signal<H, Error>, Signal<I, Error>) -> Void) {
	i.startWithSignal(during: lifetime) { i in
		flattenStart(lifetime, a, b, c, d, e, f, g, h) { setup($0, $1, $2, $3, $4, $5, $6, $7, i) }
	}
}

/// Start the producers in the argument order.
///
/// - parameters:
///   - disposable: The `CompositeDisposable` to collect the interrupt handles of all
///                 produced `Signal`s.
///   - setup: The closure to accept all produced `Signal`s at once.
private func flattenStart<A, B, C, D, E, F, G, H, I, J, Error>(_ lifetime: Lifetime, _ a: SignalProducer<A, Error>, _ b: SignalProducer<B, Error>, _ c: SignalProducer<C, Error>, _ d: SignalProducer<D, Error>, _ e: SignalProducer<E, Error>, _ f: SignalProducer<F, Error>, _ g: SignalProducer<G, Error>, _ h: SignalProducer<H, Error>, _ i: SignalProducer<I, Error>, _ j: SignalProducer<J, Error>, _ setup: (Signal<A, Error>, Signal<B, Error>, Signal<C, Error>, Signal<D, Error>, Signal<E, Error>, Signal<F, Error>, Signal<G, Error>, Signal<H, Error>, Signal<I, Error>, Signal<J, Error>) -> Void) {
	j.startWithSignal(during: lifetime) { j in
		flattenStart(lifetime, a, b, c, d, e, f, g, h, i) { setup($0, $1, $2, $3, $4, $5, $6, $7, $8, j) }
	}
}

extension SignalProducer {
	/// Map each value in the producer to a new value.
	///
	/// - parameters:
	///   - transform: A closure that accepts a value and returns a different
	///                value.
	///
	/// - returns: A signal producer that, when started, will send a mapped
	///            value of `self.`
	public func map<U>(_ transform: @escaping (Value) -> U) -> SignalProducer<U, Error> {
		return core.flatMapEvent(Signal.Event.map(transform))
	}
	
	/// Map each value in the producer to a new constant value.
	///
	/// - parameters:
	///   - value: A new value.
	///
	/// - returns: A signal producer that, when started, will send a mapped
	///            value of `self`.
	public func map<U>(value: U) -> SignalProducer<U, Error> {
		return lift { $0.map(value: value) }
	}

	/// Map each value in the producer to a new value by applying a key path.
	///
	/// - parameters:
	///   - keyPath: A key path relative to the producer's `Value` type.
	///
	/// - returns: A producer that will send new values.
	public func map<U>(_ keyPath: KeyPath<Value, U>) -> SignalProducer<U, Error> {
		return core.flatMapEvent(Signal.Event.compactMap { $0[keyPath: keyPath] })
	}

	/// Map errors in the producer to a new error.
	///
	/// - parameters:
	///   - transform: A closure that accepts an error object and returns a
	///                different error.
	///
	/// - returns: A producer that emits errors of new type.
	public func mapError<F>(_ transform: @escaping (Error) -> F) -> SignalProducer<Value, F> {
		return core.flatMapEvent(Signal.Event.mapError(transform))
	}

	/// Maps each value in the producer to a new value, lazily evaluating the
	/// supplied transformation on the specified scheduler.
	///
	/// - important: Unlike `map`, there is not a 1-1 mapping between incoming 
	///              values, and values sent on the returned producer. If 
	///              `scheduler` has not yet scheduled `transform` for 
	///              execution, then each new value will replace the last one as 
	///              the parameter to `transform` once it is finally executed.
	///
	/// - parameters:
	///   - transform: The closure used to obtain the returned value from this
	///                producer's underlying value.
	///
	/// - returns: A producer that, when started, sends values obtained using 
	///            `transform` as this producer sends values.
	public func lazyMap<U>(on scheduler: Scheduler, transform: @escaping (Value) -> U) -> SignalProducer<U, Error> {
		return core.flatMapEvent(Signal.Event.lazyMap(on: scheduler, transform: transform))
	}

	/// Preserve only values which pass the given closure.
	///
	/// - parameters:
	///   - isIncluded: A closure to determine whether a value from `self` should be
	///                 included in the produced `Signal`.
	///
	/// - returns: A producer that, when started, forwards the values passing the given
	///            closure.
	public func filter(_ isIncluded: @escaping (Value) -> Bool) -> SignalProducer<Value, Error> {
		return core.flatMapEvent(Signal.Event.filter(isIncluded))
	}

	/// Applies `transform` to values from the producer and forwards values with non `nil` results unwrapped.
	/// - parameters:
	///   - transform: A closure that accepts a value from the `value` event and
	///                returns a new optional value.
	///
	/// - returns: A producer that will send new values, that are non `nil` after the transformation.
	public func compactMap<U>(_ transform: @escaping (Value) -> U?) -> SignalProducer<U, Error> {
		return core.flatMapEvent(Signal.Event.compactMap(transform))
	}

	/// Applies `transform` to values from the producer and forwards values with non `nil` results unwrapped.
	/// - parameters:
	///   - transform: A closure that accepts a value from the `value` event and
	///                returns a new optional value.
	///
	/// - returns: A producer that will send new values, that are non `nil` after the transformation.
	@available(*, deprecated, renamed: "compactMap")
	public func filterMap<U>(_ transform: @escaping (Value) -> U?) -> SignalProducer<U, Error> {
		return core.flatMapEvent(Signal.Event.compactMap(transform))
	}

	/// Yield the first `count` values from the input producer.
	///
	/// - precondition: `count` must be non-negative number.
	///
	/// - parameters:
	///   - count: A number of values to take from the signal.
	///
	/// - returns: A producer that, when started, will yield the first `count`
	///            values from `self`.
	public func take(first count: Int) -> SignalProducer<Value, Error> {
		guard count >= 1 else { return .interrupted }
		return core.flatMapEvent(Signal.Event.take(first: count))
	}

	/// Yield an array of values when `self` completes.
	///
	/// - note: When `self` completes without collecting any value, it will send
	///         an empty array of values.
	///
	/// - returns: A producer that, when started, will yield an array of values
	///            when `self` completes.
	public func collect() -> SignalProducer<[Value], Error> {
		return core.flatMapEvent(Signal.Event.collect)
	}

	/// Yield an array of values until it reaches a certain count.
	///
	/// - precondition: `count` must be greater than zero.
	///
	/// - note: When the count is reached the array is sent and the signal
	///         starts over yielding a new array of values.
	///
	/// - note: When `self` completes any remaining values will be sent, the
	///         last array may not have `count` values. Alternatively, if were
	///         not collected any values will sent an empty array of values.
	///
	/// - returns: A producer that, when started, collects at most `count`
	///            values from `self`, forwards them as a single array and
	///            completes.
	public func collect(count: Int) -> SignalProducer<[Value], Error> {
		return core.flatMapEvent(Signal.Event.collect(count: count))
	}

	/// Collect values from `self`, and emit them if the predicate passes.
	///
	/// When `self` completes any remaining values will be sent, regardless of the
	/// collected values matching `shouldEmit` or not.
	///
	/// If `self` completes without having emitted any value, an empty array would be
	/// emitted, followed by the completion of the produced `Signal`.
	///
	/// ````
	/// let (producer, observer) = SignalProducer<Int, Never>.buffer(1)
	///
	/// producer
	///     .collect { values in values.reduce(0, combine: +) == 8 }
	///     .startWithValues { print($0) }
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
	///                 whether the collected values should be emitted.
	///
	/// - returns: A producer of arrays of values, as instructed by the `shouldEmit`
	///            closure.
	public func collect(_ shouldEmit: @escaping (_ values: [Value]) -> Bool) -> SignalProducer<[Value], Error> {
		return core.flatMapEvent(Signal.Event.collect(shouldEmit))
	}

	/// Collect values from `self`, and emit them if the predicate passes.
	///
	/// When `self` completes any remaining values will be sent, regardless of the
	/// collected values matching `shouldEmit` or not.
	///
	/// If `self` completes without having emitted any value, an empty array would be
	/// emitted, followed by the completion of the produced `Signal`.
	///
	/// ````
	/// let (producer, observer) = SignalProducer<Int, Never>.buffer(1)
	///
	/// producer
	///     .collect { values, value in value == 7 }
	///     .startWithValues { print($0) }
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
	/// - returns: A producer of arrays of values, as instructed by the `shouldEmit`
	///            closure.
	public func collect(_ shouldEmit: @escaping (_ collected: [Value], _ latest: Value) -> Bool) -> SignalProducer<[Value], Error> {
		return core.flatMapEvent(Signal.Event.collect(shouldEmit))
	}

	/// Forward the latest values on `scheduler` every `interval`.
	///
	/// - note: If `self` terminates while values are being accumulated,
	///         the behaviour will be determined by `discardWhenCompleted`.
	///         If `true`, the values will be discarded and the returned producer
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
	/// - returns: A producer that sends all values that are sent from `self`
	///            at `interval` seconds apart.
	public func collect(every interval: DispatchTimeInterval, on scheduler: DateScheduler, skipEmpty: Bool = false, discardWhenCompleted: Bool = true) -> SignalProducer<[Value], Error> {
		return core.flatMapEvent(Signal.Event.collect(every: interval, on: scheduler, skipEmpty: skipEmpty, discardWhenCompleted: discardWhenCompleted))
	}

	/// Forward all events onto the given scheduler, instead of whichever
	/// scheduler they originally arrived upon.
	///
	/// - parameters:
	///   - scheduler: A scheduler to deliver events on.
	///
	/// - returns: A producer that, when started, will yield `self` values on
	///            provided scheduler.
	public func observe(on scheduler: Scheduler) -> SignalProducer<Value, Error> {
		return core.flatMapEvent(Signal.Event.observe(on: scheduler))
	}

	/// Combine the latest value of the receiver with the latest value from the
	/// given producer.
	///
	/// - note: The returned producer will not send a value until both inputs
	///         have sent at least one value each. 
	///
	/// - note: If either producer is interrupted, the returned producer will
	///         also be interrupted.
	///
	/// - note: The returned producer will not complete until both inputs
	///         complete.
	///
	/// - parameters:
	///   - other: A producer to combine `self`'s value with.
	///
	/// - returns: A producer that, when started, will yield a tuple containing
	///            values of `self` and given producer.
	public func combineLatest<U>(with other: SignalProducer<U, Error>) -> SignalProducer<(Value, U), Error> {
		return SignalProducer.combineLatest(self, other)
	}
	
	/// Combine the latest value of the receiver with the latest value from the
	/// given producer.
	///
	/// - note: The returned producer will not send a value until both inputs
	///         have sent at least one value each.
	///
	/// - note: If either producer is interrupted, the returned producer will
	///         also be interrupted.
	///
	/// - note: The returned producer will not complete until both inputs
	///         complete.
	///
	/// - parameters:
	///   - other: A producer to combine `self`'s value with.
	///
	/// - returns: A producer that, when started, will yield a tuple containing
	///            values of `self` and given producer.
	public func combineLatest<Other: SignalProducerConvertible>(with other: Other) -> SignalProducer<(Value, Other.Value), Error> where Other.Error == Error {
		return combineLatest(with: other.producer)
	}

	/// Merge the given producer into a single `SignalProducer` that will emit all
	/// values from both of them, and complete when all of them have completed.
	///
	/// - parameters:
	///   - other: A producer to merge `self`'s value with.
	///
	/// - returns: A producer that sends all values of `self` and given producer.
	public func merge(with other: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
		return SignalProducer.merge(self, other)
	}

	/// Merge the given producer into a single `SignalProducer` that will emit all
	/// values from both of them, and complete when all of them have completed.
	///
	/// - parameters:
	///   - other: A producer to merge `self`'s value with.
	///
	/// - returns: A producer that sends all values of `self` and given producer.
	public func merge<Other: SignalProducerConvertible>(with other: Other) -> SignalProducer<Value, Error> where Other.Value == Value, Other.Error == Error {
		return merge(with: other.producer)
	}

	/// Delay `value` and `completed` events by the given interval, forwarding
	/// them on the given scheduler.
	///
	/// - note: `failed` and `interrupted` events are always scheduled
	///         immediately.
	///
	/// - parameters:
	///   - interval: Interval to delay `value` and `completed` events by.
	///   - scheduler: A scheduler to deliver delayed events on.
	///
	/// - returns: A producer that, when started, will delay `value` and
	///            `completed` events and will yield them on given scheduler.
	public func delay(_ interval: TimeInterval, on scheduler: DateScheduler) -> SignalProducer<Value, Error> {
		return core.flatMapEvent(Signal.Event.delay(interval, on: scheduler))
	}

	/// Skip the first `count` values, then forward everything afterward.
	///
	/// - parameters:
	///   - count: A number of values to skip.
	///
	/// - returns:  A producer that, when started, will skip the first `count`
	///             values, then forward everything afterward.
	public func skip(first count: Int) -> SignalProducer<Value, Error> {
		guard count != 0 else { return self }
		return core.flatMapEvent(Signal.Event.skip(first: count))
	}

	/// Treats all Events from the input producer as plain values, allowing them
	/// to be manipulated just like any other value.
	///
	/// In other words, this brings Events “into the monad.”
	///
	/// - note: When a Completed or Failed event is received, the resulting
	///         producer will send the Event itself and then complete. When an
	///         `interrupted` event is received, the resulting producer will
	///         send the `Event` itself and then interrupt.
	///
	/// - returns: A producer that sends events as its values.
	public func materialize() -> SignalProducer<ProducedSignal.Event, Never> {
		return core.flatMapEvent(Signal.Event.materialize)
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
	public func materializeResults() -> SignalProducer<Result<Value, Error>, Never> {
		return core.flatMapEvent(Signal.Event.materializeResults)
	}

	/// Forward the latest value from `self` with the value from `sampler` as a
	/// tuple, only when `sampler` sends a `value` event.
	///
	/// - note: If `sampler` fires before a value has been observed on `self`,
	///         nothing happens.
	///
	/// - parameters:
	///   - sampler: A producer that will trigger the delivery of `value` event
	///              from `self`.
	///
	/// - returns: A producer that will send values from `self` and `sampler`,
	///            sampled (possibly multiple times) by `sampler`, then complete
	///            once both input producers have completed, or interrupt if
	///            either input producer is interrupted.
	public func sample<U>(with sampler: SignalProducer<U, Never>) -> SignalProducer<(Value, U), Error> {
		return liftLeft(Signal.sample(with:))(sampler)
	}

	/// Forward the latest value from `self` with the value from `sampler` as a
	/// tuple, only when `sampler` sends a `value` event.
	///
	/// - note: If `sampler` fires before a value has been observed on `self`,
	///         nothing happens.
	///
	/// - parameters:
	///   - sampler: A producer that will trigger the delivery of `value` event
	///              from `self`.
	///
	/// - returns: A producer that will send values from `self` and `sampler`,
	///            sampled (possibly multiple times) by `sampler`, then complete
	///            once both input producers have completed, or interrupt if
	///            either input producer is interrupted.
	public func sample<Sampler: SignalProducerConvertible>(with sampler: Sampler) -> SignalProducer<(Value, Sampler.Value), Error> where Sampler.Error == Never {
		return sample(with: sampler.producer)
	}

	/// Forward the latest value from `self` whenever `sampler` sends a `value`
	/// event.
	///
	/// - note: If `sampler` fires before a value has been observed on `self`,
	///         nothing happens.
	///
	/// - parameters:
	///   - sampler: A producer that will trigger the delivery of `value` event
	///              from `self`.
	///
	/// - returns: A producer that, when started, will send values from `self`,
	///            sampled (possibly multiple times) by `sampler`, then complete
	///            once both input producers have completed, or interrupt if
	///            either input producer is interrupted.
	public func sample(on sampler: SignalProducer<(), Never>) -> SignalProducer<Value, Error> {
		return liftLeft(Signal.sample(on:))(sampler)
	}

	/// Forward the latest value from `self` whenever `sampler` sends a `value`
	/// event.
	///
	/// - note: If `sampler` fires before a value has been observed on `self`,
	///         nothing happens.
	///
	/// - parameters:
	///   - sampler: A producer that will trigger the delivery of `value` event
	///              from `self`.
	///
	/// - returns: A producer that, when started, will send values from `self`,
	///            sampled (possibly multiple times) by `sampler`, then complete
	///            once both input producers have completed, or interrupt if
	///            either input producer is interrupted.
	public func sample<Sampler: SignalProducerConvertible>(on sampler: Sampler) -> SignalProducer<Value, Error> where Sampler.Value == (), Sampler.Error == Never {
		return sample(on: sampler.producer)
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
	/// - returns: A producer that will send values from `self` and `samplee`,
	///            sampled (possibly multiple times) by `self`, then terminate
	///            once `self` has terminated. **`samplee`'s terminated events
	///            are ignored**.
	public func withLatest<U>(from samplee: SignalProducer<U, Never>) -> SignalProducer<(Value, U), Error> {
		return liftRight(Signal.withLatest)(samplee.producer)
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
	/// - returns: A producer that will send values from `self` and `samplee`,
	///            sampled (possibly multiple times) by `self`, then terminate
	///            once `self` has terminated. **`samplee`'s terminated events
	///            are ignored**.
	public func withLatest<Samplee: SignalProducerConvertible>(from samplee: Samplee) -> SignalProducer<(Value, Samplee.Value), Error> where Samplee.Error == Never {
		return withLatest(from: samplee.producer)
	}

	/// Forwards events from `self` until `lifetime` ends, at which point the
	/// returned producer will complete.
	///
	/// - parameters:
	///   - lifetime: A lifetime whose `ended` signal will cause the returned
	///               producer to complete.
	///
	/// - returns: A producer that will deliver events until `lifetime` ends.
	public func take(during lifetime: Lifetime) -> SignalProducer<Value, Error> {
		return lift { $0.take(during: lifetime) }
	}

	/// Forward events from `self` until `trigger` sends a `value` or `completed`
	/// event, at which point the returned producer will complete.
	///
	/// - parameters:
	///   - trigger: A producer whose `value` or `completed` events will stop the
	///              delivery of `value` events from `self`.
	///
	/// - returns: A producer that will deliver events until `trigger` sends
	///            `value` or `completed` events.
	public func take(until trigger: SignalProducer<(), Never>) -> SignalProducer<Value, Error> {
		return liftRight(Signal.take(until:))(trigger)
	}

	/// Forward events from `self` until `trigger` sends a `value` or `completed`
	/// event, at which point the returned producer will complete.
	///
	/// - parameters:
	///   - trigger: A producer whose `value` or `completed` events will stop the
	///              delivery of `value` events from `self`.
	///
	/// - returns: A producer that will deliver events until `trigger` sends
	///            `value` or `completed` events.
	public func take<Trigger: SignalProducerConvertible>(until trigger: Trigger) -> SignalProducer<Value, Error> where Trigger.Value == (), Trigger.Error == Never {
		return take(until: trigger.producer)
	}

	/// Do not forward any values from `self` until `trigger` sends a `value`
	/// or `completed`, at which point the returned producer behaves exactly
	/// like `producer`.
	///
	/// - parameters:
	///   - trigger: A producer whose `value` or `completed` events will start
	///              the deliver of events on `self`.
	///
	/// - returns: A producer that will deliver events once the `trigger` sends
	///            `value` or `completed` events.
	public func skip(until trigger: SignalProducer<(), Never>) -> SignalProducer<Value, Error> {
		return liftRight(Signal.skip(until:))(trigger)
	}

	/// Do not forward any values from `self` until `trigger` sends a `value`
	/// or `completed`, at which point the returned producer behaves exactly
	/// like `producer`.
	///
	/// - parameters:
	///   - trigger: A producer whose `value` or `completed` events will start
	///              the deliver of events on `self`.
	///
	/// - returns: A producer that will deliver events once the `trigger` sends
	///            `value` or `completed` events.
	public func skip<Trigger: SignalProducerConvertible>(until trigger: Trigger) -> SignalProducer<Value, Error> where Trigger.Value == (), Trigger.Error == Never {
		return skip(until: trigger.producer)
	}

	/// Forward events from `self` with history: values of the returned producer
	/// are a tuples whose first member is the previous value and whose second member
	/// is the current value. `initial` is supplied as the first member when `self`
	/// sends its first value.
	///
	/// - parameters:
	///   - initial: A value that will be combined with the first value sent by
	///              `self`.
	///
	/// - returns: A producer that sends tuples that contain previous and current
	///            sent values of `self`.
	public func combinePrevious(_ initial: Value) -> SignalProducer<(Value, Value), Error> {
		return core.flatMapEvent(Signal.Event.combinePrevious(initial: initial))
	}

	/// Forward events from `self` with history: values of the produced signal
	/// are a tuples whose first member is the previous value and whose second member
	/// is the current value.
	///
	/// The produced `Signal` would not emit any tuple until it has received at least two
	/// values.
	///
	/// - returns: A producer that sends tuples that contain previous and current
	///            sent values of `self`.
	public func combinePrevious() -> SignalProducer<(Value, Value), Error> {
		return core.flatMapEvent(Signal.Event.combinePrevious(initial: nil))
	}

	/// Combine all values from `self`, and forward the final result.
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
	/// - returns: A producer that sends the final result as `self` completes.
	public func reduce<U>(_ initialResult: U, _ nextPartialResult: @escaping (U, Value) -> U) -> SignalProducer<U, Error> {
		return core.flatMapEvent(Signal.Event.reduce(initialResult, nextPartialResult))
	}

	/// Combine all values from `self`, and forward the final result.
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
	/// - returns: A producer that sends the final value as `self` completes.
	public func reduce<U>(into initialResult: U, _ nextPartialResult: @escaping (inout U, Value) -> Void) -> SignalProducer<U, Error> {
		return core.flatMapEvent(Signal.Event.reduce(into: initialResult, nextPartialResult))
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
	/// - returns: A producer that sends the partial results of the accumuation, and the
	///            final result as `self` completes.
	public func scan<U>(_ initialResult: U, _ nextPartialResult: @escaping (U, Value) -> U) -> SignalProducer<U, Error> {
		return core.flatMapEvent(Signal.Event.scan(initialResult, nextPartialResult))
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
	/// - returns: A producer that sends the partial results of the accumuation, and the
	///            final result as `self` completes.
	public func scan<U>(into initialResult: U, _ nextPartialResult: @escaping (inout U, Value) -> Void) -> SignalProducer<U, Error> {
		return core.flatMapEvent(Signal.Event.scan(into: initialResult, nextPartialResult))
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
	public func scanMap<State, U>(_ initialState: State, _ next: @escaping (State, Value) -> (State, U)) -> SignalProducer<U, Error> {
		return core.flatMapEvent(Signal.Event.scanMap(initialState, next))
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
	public func scanMap<State, U>(into initialState: State, _ next: @escaping (inout State, Value) -> U) -> SignalProducer<U, Error> {
		return core.flatMapEvent(Signal.Event.scanMap(into: initialState, next))
	}

	/// Forward only values from `self` that are not considered equivalent to its
	/// immediately preceding value.
	///
	/// - note: The first value is always forwarded.
	///
	/// - parameters:
	///   - isEquivalent: A closure to determine whether two values are equivalent.
	///
	/// - returns: A producer which conditionally forwards values from `self`
	public func skipRepeats(_ isEquivalent: @escaping (Value, Value) -> Bool) -> SignalProducer<Value, Error> {
		return core.flatMapEvent(Signal.Event.skipRepeats(isEquivalent))
	}

	/// Do not forward any value from `self` until `shouldContinue` returns `false`, at
	/// which point the returned signal starts to forward values from `self`, including
	/// the one leading to the toggling.
	///
	/// - parameters:
	///   - shouldContinue: A closure to determine whether the skipping should continue.
	///
	/// - returns: A producer which conditionally forwards values from `self`.
	public func skip(while shouldContinue: @escaping (Value) -> Bool) -> SignalProducer<Value, Error> {
		return core.flatMapEvent(Signal.Event.skip(while: shouldContinue))
	}

	/// Forwards events from `self` until `replacement` begins sending events.
	///
	/// - parameters:
	///   - replacement: A producer to wait to wait for values from and start
	///                  sending them as a replacement to `self`'s values.
	///
	/// - returns: A producer which passes through `value`, `failed`, and
	///            `interrupted` events from `self` until `replacement` sends an
	///            event, at which point the returned producer will send that
	///            event and switch to passing through events from `replacement`
	///            instead, regardless of whether `self` has sent events
	///            already.
	public func take(untilReplacement replacement: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
		return liftRight(Signal.take(untilReplacement:))(replacement)
	}

	/// Forwards events from `self` until `replacement` begins sending events.
	///
	/// - parameters:
	///   - replacement: A producer to wait to wait for values from and start
	///                  sending them as a replacement to `self`'s values.
	///
	/// - returns: A producer which passes through `value`, `failed`, and
	///            `interrupted` events from `self` until `replacement` sends an
	///            event, at which point the returned producer will send that
	///            event and switch to passing through events from `replacement`
	///            instead, regardless of whether `self` has sent events
	///            already.
	public func take<Replacement: SignalProducerConvertible>(untilReplacement replacement: Replacement) -> SignalProducer<Value, Error> where Replacement.Value == Value, Replacement.Error == Error {
		return take(untilReplacement: replacement.producer)
	}

	/// Wait until `self` completes and then forward the final `count` values
	/// on the returned producer.
	///
	/// - parameters:
	///   - count: Number of last events to send after `self` completes.
	///
	/// - returns: A producer that receives up to `count` values from `self`
	///            after `self` completes.
	public func take(last count: Int) -> SignalProducer<Value, Error> {
		return core.flatMapEvent(Signal.Event.take(last: count))
	}

	/// Forward any values from `self` until `shouldContinue` returns `false`, at which
	/// point the produced `Signal` would complete.
	///
	/// - parameters:
	///   - shouldContinue: A closure to determine whether the forwarding of values should
	///                     continue.
	///
	/// - returns: A producer which conditionally forwards values from `self`.
	public func take(while shouldContinue: @escaping (Value) -> Bool) -> SignalProducer<Value, Error> {
		return core.flatMapEvent(Signal.Event.take(while: shouldContinue))
	}

	/// Zip elements of two producers into pairs. The elements of any Nth pair
	/// are the Nth elements of the two input producers.
	///
	/// - parameters:
	///   - other: A producer to zip values with.
	///
	/// - returns: A producer that sends tuples of `self` and `otherProducer`.
	public func zip<U>(with other: SignalProducer<U, Error>) -> SignalProducer<(Value, U), Error> {
		return SignalProducer.zip(self, other)
	}

	/// Zip elements of two producers into pairs. The elements of any Nth pair
	/// are the Nth elements of the two input producers.
	///
	/// - parameters:
	///   - other: A producer to zip values with.
	///
	/// - returns: A producer that sends tuples of `self` and `otherProducer`.
	public func zip<Other: SignalProducerConvertible>(with other: Other) -> SignalProducer<(Value, Other.Value), Error> where Other.Error == Error {
		return zip(with: other.producer)
	}

	/// Apply an action to every value from `self`, and forward the value if the action
	/// succeeds. If the action fails with an error, the produced `Signal` would propagate
	/// the failure and terminate.
	///
	/// - parameters:
	///   - action: An action which yields a `Result`.
	///
	/// - returns: A producer which forwards the values from `self` until the given action
	///            fails.
	public func attempt(_ action: @escaping (Value) -> Result<(), Error>) -> SignalProducer<Value, Error> {
		return core.flatMapEvent(Signal.Event.attempt(action))
	}

	/// Apply a transform to every value from `self`, and forward the transformed value
	/// if the action succeeds. If the action fails with an error, the produced `Signal`
	/// would propagate the failure and terminate.
	///
	/// - parameters:
	///   - action: A transform which yields a `Result` of the transformed value or the
	///             error.
	///
	/// - returns: A producer which forwards the transformed values.
	public func attemptMap<U>(_ action: @escaping (Value) -> Result<U, Error>) -> SignalProducer<U, Error> {
		return core.flatMapEvent(Signal.Event.attemptMap(action))
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
	///         value will be discarded and the returned producer will terminate
	///         immediately.
	///
	/// - note: If the device time changed backwards before previous date while
	///         a value is being throttled, and if there is a new value sent,
	///         the new value will be passed anyway.
	///
	/// - parameters:
	///   - interval: Number of seconds to wait between sent values.
	///   - scheduler: A scheduler to deliver events on.
	///
	/// - returns: A producer that sends values at least `interval` seconds
	///            appart on a given scheduler.
	public func throttle(_ interval: TimeInterval, on scheduler: DateScheduler) -> SignalProducer<Value, Error> {
		return core.flatMapEvent(Signal.Event.throttle(interval, on: scheduler))
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
	/// - returns: A producer that sends values only while `shouldThrottle` is false.
	public func throttle<P: PropertyProtocol>(while shouldThrottle: P, on scheduler: Scheduler) -> SignalProducer<Value, Error>
		where P.Value == Bool
	{
		// Using `Property.init(_:)` avoids capturing a strong reference
		// to `shouldThrottle`, so that we don't extend its lifetime.
		let shouldThrottle = Property(shouldThrottle)

		return lift { $0.throttle(while: shouldThrottle, on: scheduler) }
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
	/// - parameters:
	///   - interval: A number of seconds to wait before sending a value.
	///   - scheduler: A scheduler to send values on.
	///   - discardWhenCompleted: A boolean to indicate if the latest value
	///                             should be discarded on completion.
	///
	/// - returns: A producer that sends values that are sent from `self` at
	///            least `interval` seconds apart.
	public func debounce(_ interval: TimeInterval, on scheduler: DateScheduler, discardWhenCompleted: Bool = true) -> SignalProducer<Value, Error> {
		return core.flatMapEvent(Signal.Event.debounce(interval, on: scheduler, discardWhenCompleted: discardWhenCompleted))
	}

	/// Forward events from `self` until `interval`. Then if producer isn't
	/// completed yet, fails with `error` on `scheduler`.
	///
	/// - note: If the interval is 0, the timeout will be scheduled immediately.
	///         The producer must complete synchronously (or on a faster 
	///         scheduler) to avoid the timeout.
	///
	/// - parameters:
	///   - interval: Number of seconds to wait for `self` to complete.
	///   - error: Error to send with `failed` event if `self` is not completed
	///            when `interval` passes.
	///   - scheduler: A scheduler to deliver error on.
	///
	/// - returns: A producer that sends events for at most `interval` seconds,
	///            then, if not `completed` - sends `error` with `failed` event
	///            on `scheduler`.
	public func timeout(after interval: TimeInterval, raising error: Error, on scheduler: DateScheduler) -> SignalProducer<Value, Error> {
		return lift { $0.timeout(after: interval, raising: error, on: scheduler) }
	}
}

extension SignalProducer where Value: OptionalProtocol {
	/// Unwraps non-`nil` values and forwards them on the returned signal, `nil`
	/// values are dropped.
	///
	/// - returns: A producer that sends only non-nil values.
	public func skipNil() -> SignalProducer<Value.Wrapped, Error> {
		return core.flatMapEvent(Signal.Event.skipNil)
	}
}

extension SignalProducer where Value: EventProtocol, Error == Never {
	/// The inverse of materialize(), this will translate a producer of `Event`
	/// _values_ into a producer of those events themselves.
	///
	/// - returns: A producer that sends values carried by `self` events.
	public func dematerialize() -> SignalProducer<Value.Value, Value.Error> {
		return core.flatMapEvent(Signal.Event.dematerialize)
	}
}

extension SignalProducer where Error == Never {
	/// The inverse of materializeResults(), this will translate a producer of `Result`
	/// _values_ into a producer of those events themselves.
	///
	/// - returns: A producer that sends values carried by `self` results.
	public func dematerializeResults<Success, Failure>() -> SignalProducer<Success, Failure> where Value == Result<Success, Failure> {
		return core.flatMapEvent(Signal.Event.dematerializeResults)
	}
}

extension SignalProducer where Error == Never {
	/// Promote a producer that does not generate failures into one that can.
	///
	/// - note: This does not actually cause failers to be generated for the
	///         given producer, but makes it easier to combine with other
	///         producers that may fail; for example, with operators like
	///         `combineLatestWith`, `zipWith`, `flatten`, etc.
	///
	/// - parameters:
	///   - _ An `ErrorType`.
	///
	/// - returns: A producer that has an instantiatable `ErrorType`.
	public func promoteError<F>(_: F.Type = F.self) -> SignalProducer<Value, F> {
		return core.flatMapEvent(Signal.Event.promoteError(F.self))
	}

	/// Promote a producer that does not generate failures into one that can.
	///
	/// - note: This does not actually cause failers to be generated for the
	///         given producer, but makes it easier to combine with other
	///         producers that may fail; for example, with operators like
	///         `combineLatestWith`, `zipWith`, `flatten`, etc.
	///
	/// - parameters:
	///   - _ An `ErrorType`.
	///
	/// - returns: A producer that has an instantiatable `ErrorType`.
	public func promoteError(_: Error.Type = Error.self) -> SignalProducer<Value, Error> {
		return self
	}

	/// Forward events from `self` until `interval`. Then if producer isn't
	/// completed yet, fails with `error` on `scheduler`.
	///
	/// - note: If the interval is 0, the timeout will be scheduled immediately.
	///         The producer must complete synchronously (or on a faster
	///         scheduler) to avoid the timeout.
	///
	/// - parameters:
	///   - interval: Number of seconds to wait for `self` to complete.
	///   - error: Error to send with `failed` event if `self` is not completed
	///            when `interval` passes.
	///   - scheudler: A scheduler to deliver error on.
	///
	/// - returns: A producer that sends events for at most `interval` seconds,
	///            then, if not `completed` - sends `error` with `failed` event
	///            on `scheduler`.
	public func timeout<NewError>(
		after interval: TimeInterval,
		raising error: NewError,
		on scheduler: DateScheduler
	) -> SignalProducer<Value, NewError> {
		return lift { $0.timeout(after: interval, raising: error, on: scheduler) }
	}

	/// Apply a throwable action to every value from `self`, and forward the values
	/// if the action succeeds. If the action throws an error, the produced `Signal`
	/// would propagate the failure and terminate.
	///
	/// - parameters:
	///   - action: A throwable closure to perform an arbitrary action on the value.
	///
	/// - returns: A producer which forwards the successful values of the given action.
	public func attempt(_ action: @escaping (Value) throws -> Void) -> SignalProducer<Value, Swift.Error> {
		return self
			.promoteError(Swift.Error.self)
			.attempt(action)
	}

	/// Apply a throwable action to every value from `self`, and forward the results
	/// if the action succeeds. If the action throws an error, the produced `Signal`
	/// would propagate the failure and terminate.
	///
	/// - parameters:
	///   - action: A throwable closure to perform an arbitrary action on the value, and
	///             yield a result.
	///
	/// - returns: A producer which forwards the successful results of the given action.
	public func attemptMap<U>(_ action: @escaping (Value) throws -> U) -> SignalProducer<U, Swift.Error> {
		return self
			.promoteError(Swift.Error.self)
			.attemptMap(action)
	}
}

extension SignalProducer where Error == Swift.Error {
	/// Apply a throwable action to every value from `self`, and forward the values
	/// if the action succeeds. If the action throws an error, the produced `Signal`
	/// would propagate the failure and terminate.
	///
	/// - parameters:
	///   - action: A throwable closure to perform an arbitrary action on the value.
	///
	/// - returns: A producer which forwards the successful values of the given action.
	public func attempt(_ action: @escaping (Value) throws -> Void) -> SignalProducer<Value, Error> {
		return core.flatMapEvent(Signal.Event.attempt(action))
	}

	/// Apply a throwable transform to every value from `self`, and forward the results
	/// if the action succeeds. If the transform throws an error, the produced `Signal`
	/// would propagate the failure and terminate.
	///
	/// - parameters:
	///   - transform: A throwable transform.
	///
	/// - returns: A producer which forwards the successfully transformed values.
	public func attemptMap<U>(_ transform: @escaping (Value) throws -> U) -> SignalProducer<U, Error> {
		return core.flatMapEvent(Signal.Event.attemptMap(transform))
	}
}

extension SignalProducer where Value == Never {
	/// Promote a producer that does not generate values, as indicated by `Never`,
	/// to be a producer of the given type of value.
	///
	/// - note: The promotion does not result in any value being generated.
	///
	/// - parameters:
	///   - _ The type of value to promote to.
	///
	/// - returns: A producer that forwards all terminal events from `self`.
	public func promoteValue<U>(_: U.Type = U.self) -> SignalProducer<U, Error> {
		return core.flatMapEvent(Signal.Event.promoteValue(U.self))
	}

	/// Promote a producer that does not generate values, as indicated by `Never`,
	/// to be a producer of the given type of value.
	///
	/// - note: The promotion does not result in any value being generated.
	///
	/// - parameters:
	///   - _ The type of value to promote to.
	///
	/// - returns: A producer that forwards all terminal events from `self`.
	public func promoteValue(_: Value.Type = Value.self) -> SignalProducer<Value, Error> {
		return self
	}
}

extension SignalProducer where Value: Equatable {
	/// Forward only values from `self` that are not equal to its immediately preceding
	/// value.
	///
	/// - note: The first value is always forwarded.
	///
	/// - returns: A producer which conditionally forwards values from `self`.
	public func skipRepeats() -> SignalProducer<Value, Error> {
		return core.flatMapEvent(Signal.Event.skipRepeats(==))
	}
}

extension SignalProducer {
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
	/// - returns: A producer that sends unique values during its lifetime.
	public func uniqueValues<Identity: Hashable>(_ transform: @escaping (Value) -> Identity) -> SignalProducer<Value, Error> {
		return core.flatMapEvent(Signal.Event.uniqueValues(transform))
	}
}

extension SignalProducer where Value: Hashable {
	/// Forward only those values from `self` that are unique across the set of
	/// all values that have been seen.
	///
	/// - note: This causes the values to be retained to check for uniqueness.
	///         Providing a function that returns a unique value for each sent
	///         value can help you reduce the memory footprint.
	///
	/// - returns: A producer that sends unique values during its lifetime.
	public func uniqueValues() -> SignalProducer<Value, Error> {
		return uniqueValues { $0 }
	}
}

extension SignalProducer {
	/// Injects side effects to be performed upon the specified producer events.
	///
	/// - note: In a composed producer, `starting` is invoked in the reverse
	///         direction of the flow of events.
	///
	/// - parameters:
	///   - starting: A closure that is invoked before the producer is started.
	///   - started: A closure that is invoked after the producer is started.
	///   - event: A closure that accepts an event and is invoked on every
	///            received event.
	///   - failed: A closure that accepts error object and is invoked for
	///             `failed` event.
	///   - completed: A closure that is invoked for `completed` event.
	///   - interrupted: A closure that is invoked for `interrupted` event.
	///   - terminated: A closure that is invoked for any terminating event.
	///   - disposed: A closure added as disposable when signal completes.
	///   - value: A closure that accepts a value from `value` event.
	///
	/// - returns: A producer with attached side-effects for given event cases.
	public func on(
		starting: (() -> Void)? = nil,
		started: (() -> Void)? = nil,
		event: ((ProducedSignal.Event) -> Void)? = nil,
		failed: ((Error) -> Void)? = nil,
		completed: (() -> Void)? = nil,
		interrupted: (() -> Void)? = nil,
		terminated: (() -> Void)? = nil,
		disposed: (() -> Void)? = nil,
		value: ((Value) -> Void)? = nil
	) -> SignalProducer<Value, Error> {
		return SignalProducer(SignalCore {
			let instance = self.core.makeInstance()
			let signal = instance.signal.on(event: event,
			                                failed: failed,
			                                completed: completed,
			                                interrupted: interrupted,
			                                terminated: terminated,
			                                disposed: disposed,
			                                value: value)

			return .init(signal: signal,
			             observerDidSetup: { starting?(); instance.observerDidSetup(); started?() },
			             interruptHandle: instance.interruptHandle)
		})
	}

	/// Start the returned producer on the given `Scheduler`.
	///
	/// - note: This implies that any side effects embedded in the producer will
	///         be performed on the given scheduler as well.
	///
	/// - note: Events may still be sent upon other schedulers — this merely
	///         affects where the `start()` method is run.
	///
	/// - parameters:
	///   - scheduler: A scheduler to deliver events on.
	///
	/// - returns: A producer that will deliver events on given `scheduler` when
	///            started.
	public func start(on scheduler: Scheduler) -> SignalProducer<Value, Error> {
		return SignalProducer { observer, lifetime in
			lifetime += scheduler.schedule {
				self.startWithSignal { signal, signalDisposable in
					lifetime += signalDisposable
					signal.observe(observer)
				}
			}
		}
	}
}

extension SignalProducer {
	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: SignalProducerConvertible, B: SignalProducerConvertible>(_ a: A, _ b: B) -> SignalProducer<(Value, B.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer) { Signal.combineLatest($0, $1).observe(observer) }
		}
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C) -> SignalProducer<(Value, B.Value, C.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer) { Signal.combineLatest($0, $1, $2).observe(observer) }
		}
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D) -> SignalProducer<(Value, B.Value, C.Value, D.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error, D.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer, d.producer) { Signal.combineLatest($0, $1, $2, $3).observe(observer) }
		}
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> SignalProducer<(Value, B.Value, C.Value, D.Value, E.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error, D.Error == Error, E.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer, d.producer, e.producer) { Signal.combineLatest($0, $1, $2, $3, $4).observe(observer) }
		}
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible, F: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> SignalProducer<(Value, B.Value, C.Value, D.Value, E.Value, F.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error, D.Error == Error, E.Error == Error, F.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer, d.producer, e.producer, f.producer) { Signal.combineLatest($0, $1, $2, $3, $4, $5).observe(observer) }
		}
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible, F: SignalProducerConvertible, G: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> SignalProducer<(Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error, D.Error == Error, E.Error == Error, F.Error == Error, G.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer, d.producer, e.producer, f.producer, g.producer) { Signal.combineLatest($0, $1, $2, $3, $4, $5, $6).observe(observer) }
		}
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible, F: SignalProducerConvertible, G: SignalProducerConvertible, H: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> SignalProducer<(Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error, D.Error == Error, E.Error == Error, F.Error == Error, G.Error == Error, H.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer, d.producer, e.producer, f.producer, g.producer, h.producer) { Signal.combineLatest($0, $1, $2, $3, $4, $5, $6, $7).observe(observer) }
		}
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible, F: SignalProducerConvertible, G: SignalProducerConvertible, H: SignalProducerConvertible, I: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> SignalProducer<(Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error, D.Error == Error, E.Error == Error, F.Error == Error, G.Error == Error, H.Error == Error, I.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer, d.producer, e.producer, f.producer, g.producer, h.producer, i.producer) { Signal.combineLatest($0, $1, $2, $3, $4, $5, $6, $7, $8).observe(observer) }
		}
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatest(with:)`.
	public static func combineLatest<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible, F: SignalProducerConvertible, G: SignalProducerConvertible, H: SignalProducerConvertible, I: SignalProducerConvertible, J: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> SignalProducer<(Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value, J.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error, D.Error == Error, E.Error == Error, F.Error == Error, G.Error == Error, H.Error == Error, I.Error == Error, J.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer, d.producer, e.producer, f.producer, g.producer, h.producer, i.producer, j.producer) { Signal.combineLatest($0, $1, $2, $3, $4, $5, $6, $7, $8, $9).observe(observer) }
		}
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatest(with:)`. Will return an empty `SignalProducer` if the sequence is empty.
	public static func combineLatest<S: Sequence>(_ producers: S) -> SignalProducer<[Value], Error> where S.Iterator.Element: SignalProducerConvertible, S.Iterator.Element.Value == Value, S.Iterator.Element.Error == Error {
		return start(producers, Signal.combineLatest)
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `combineLatest(with:)`. If no producer is given, the resulting producer will constantly return `emptySentinel`.
	public static func combineLatest<S: Sequence>(_ producers: S, emptySentinel: [S.Iterator.Element.Value]) -> SignalProducer<[Value], Error> where S.Iterator.Element: SignalProducerConvertible, S.Iterator.Element.Value == Value, S.Iterator.Element.Error == Error {
		return start(producers, emptySentinel: emptySentinel, Signal.combineLatest)
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: SignalProducerConvertible, B: SignalProducerConvertible>(_ a: A, _ b: B) -> SignalProducer<(Value, B.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer) { Signal.zip($0, $1).observe(observer) }
		}
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C) -> SignalProducer<(Value, B.Value, C.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer) { Signal.zip($0, $1, $2).observe(observer) }
		}
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D) -> SignalProducer<(Value, B.Value, C.Value, D.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error, D.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer, d.producer) { Signal.zip($0, $1, $2, $3).observe(observer) }
		}
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> SignalProducer<(Value, B.Value, C.Value, D.Value, E.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error, D.Error == Error, E.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer, d.producer, e.producer) { Signal.zip($0, $1, $2, $3, $4).observe(observer) }
		}
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible, F: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> SignalProducer<(Value, B.Value, C.Value, D.Value, E.Value, F.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error, D.Error == Error, E.Error == Error, F.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer, d.producer, e.producer, f.producer) { Signal.zip($0, $1, $2, $3, $4, $5).observe(observer) }
		}
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible, F: SignalProducerConvertible, G: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> SignalProducer<(Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error, D.Error == Error, E.Error == Error, F.Error == Error, G.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer, d.producer, e.producer, f.producer, g.producer) { Signal.zip($0, $1, $2, $3, $4, $5, $6).observe(observer) }
		}
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible, F: SignalProducerConvertible, G: SignalProducerConvertible, H: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> SignalProducer<(Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error, D.Error == Error, E.Error == Error, F.Error == Error, G.Error == Error, H.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer, d.producer, e.producer, f.producer, g.producer, h.producer) { Signal.zip($0, $1, $2, $3, $4, $5, $6, $7).observe(observer) }
		}
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible, F: SignalProducerConvertible, G: SignalProducerConvertible, H: SignalProducerConvertible, I: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> SignalProducer<(Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error, D.Error == Error, E.Error == Error, F.Error == Error, G.Error == Error, H.Error == Error, I.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer, d.producer, e.producer, f.producer, g.producer, h.producer, i.producer) { Signal.zip($0, $1, $2, $3, $4, $5, $6, $7, $8).observe(observer) }
		}
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zip(with:)`.
	public static func zip<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible, F: SignalProducerConvertible, G: SignalProducerConvertible, H: SignalProducerConvertible, I: SignalProducerConvertible, J: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> SignalProducer<(Value, B.Value, C.Value, D.Value, E.Value, F.Value, G.Value, H.Value, I.Value, J.Value), Error> where A.Value == Value, A.Error == Error, B.Error == Error, C.Error == Error, D.Error == Error, E.Error == Error, F.Error == Error, G.Error == Error, H.Error == Error, I.Error == Error, J.Error == Error {
		return .init { observer, lifetime in
			flattenStart(lifetime, a.producer, b.producer, c.producer, d.producer, e.producer, f.producer, g.producer, h.producer, i.producer, j.producer) { Signal.zip($0, $1, $2, $3, $4, $5, $6, $7, $8, $9).observe(observer) }
		}
	}

	/// Zips the values of all the given producers, in the manner described by
	/// `zipWith`. Will return an empty `SignalProducer` if the sequence is empty.
	public static func zip<S: Sequence>(_ producers: S) -> SignalProducer<[Value], Error> where S.Iterator.Element: SignalProducerConvertible, S.Iterator.Element.Value == Value, S.Iterator.Element.Error == Error {
		return start(producers, Signal.zip)
	}

	/// Combines the values of all the given producers, in the manner described by
	/// `zip(with:)`. If no producer is given, the resulting producer will constantly return `emptySentinel`.
	public static func zip<S: Sequence>(_ producers: S, emptySentinel: [S.Iterator.Element.Value]) -> SignalProducer<[Value], Error> where S.Iterator.Element: SignalProducerConvertible, S.Iterator.Element.Value == Value, S.Iterator.Element.Error == Error {
		return start(producers, emptySentinel: emptySentinel, Signal.zip)
	}

	private static func start<S: Sequence>(
		_ producers: S,
		emptySentinel: [S.Iterator.Element.Value]? = nil,
		_ transform: @escaping (AnySequence<Signal<Value, Error>>) -> Signal<[Value], Error>
	) -> SignalProducer<[Value], Error>
		where S.Iterator.Element: SignalProducerConvertible, S.Iterator.Element.Value == Value, S.Iterator.Element.Error == Error
	{
		return SignalProducer<[Value], Error> { observer, lifetime in
			let setup = producers.map {
				(producer: $0.producer, pipe: Signal<Value, Error>.pipe())
			}
			
			guard !setup.isEmpty else {
				if let emptySentinel = emptySentinel {
					observer.send(value: emptySentinel)
				}

				observer.sendCompleted()
				return
			}

			lifetime += transform(AnySequence(setup.lazy.map { $0.pipe.output })).observe(observer)
			
			for (producer, pipe) in setup {
				lifetime += producer.start(pipe.input)
			}
		}
	}
}

extension SignalProducer {
	/// Repeat `self` a total of `count` times. In other words, start producer
	/// `count` number of times, each one after previously started producer
	/// completes.
	///
	/// - note: Repeating `1` time results in an equivalent signal producer.
	///
	/// - note: Repeating `0` times results in a producer that instantly
	///         completes.
	///
	/// - precondition: `count` must be non-negative integer.
	///
	/// - parameters:
	///   - count: Number of repetitions.
	///
	/// - returns: A signal producer start sequentially starts `self` after
	///            previously started producer completes.
	public func `repeat`(_ count: Int) -> SignalProducer<Value, Error> {
		precondition(count >= 0)

		if count == 0 {
			return .empty
		} else if count == 1 {
			return producer
		}

		return SignalProducer { observer, lifetime in
			let serialDisposable = SerialDisposable()
			lifetime += serialDisposable

			func iterate(_ current: Int) {
				self.startWithSignal { signal, signalDisposable in
					serialDisposable.inner = signalDisposable

					signal.observe { event in
						if case .completed = event {
							let remainingTimes = current - 1
							if remainingTimes > 0 {
								iterate(remainingTimes)
							} else {
								observer.sendCompleted()
							}
						} else {
							observer.send(event)
						}
					}
				}
			}

			iterate(count)
		}
	}

	/// Ignore failures up to `count` times.
	///
	/// - precondition: `count` must be non-negative integer.
	///
	/// - parameters:
	///   - count: Number of retries.
	///
	/// - returns: A signal producer that restarts up to `count` times.
	public func retry(upTo count: Int) -> SignalProducer<Value, Error> {
		precondition(count >= 0)

		if count == 0 {
			return producer
		} else {
			return flatMapError { _ in
				self.retry(upTo: count - 1)
			}
		}
	}

	/// Delays retrying on failure by `interval` up to `count` attempts.
	///
	/// - precondition: `count` must be non-negative integer.
	///
	/// - parameters:
	///   - count: Number of retries.
	///   - interval: An interval between invocations.
	///   - scheduler: A scheduler to deliver events on.
	///
	/// - returns: A signal producer that restarts up to `count` times.
	public func retry(upTo count: Int, interval: TimeInterval, on scheduler: DateScheduler) -> SignalProducer<Value, Error> {
		precondition(count >= 0)

		if count == 0 {
			return producer
		}

		var retries = count

		return flatMapError { error -> SignalProducer<Value, Error> in
				// The final attempt shouldn't defer the error if it fails
				var producer = SignalProducer<Value, Error>(error: error)
				if retries > 0 {
					producer = SignalProducer.empty
						.delay(interval, on: scheduler)
						.concat(producer)
				}

				retries -= 1
				return producer
			}
			.retry(upTo: count)
	}

	/// Wait for completion of `self`, *then* forward all events from
	/// `replacement`. Any failure or interruption sent from `self` is
	/// forwarded immediately, in which case `replacement` will not be started,
	/// and none of its events will be be forwarded.
	///
	/// - note: All values sent from `self` are ignored.
	///
	/// - parameters:
	///   - replacement: A producer to start when `self` completes.
	///
	/// - returns: A producer that sends events from `self` and then from
	///            `replacement` when `self` completes.
	public func then<U>(_ replacement: SignalProducer<U, Never>) -> SignalProducer<U, Error> {
		return _then(replacement.promoteError(Error.self))
	}

	/// Wait for completion of `self`, *then* forward all events from
	/// `replacement`. Any failure or interruption sent from `self` is
	/// forwarded immediately, in which case `replacement` will not be started,
	/// and none of its events will be be forwarded.
	///
	/// - note: All values sent from `self` are ignored.
	///
	/// - parameters:
	///   - replacement: A producer to start when `self` completes.
	///
	/// - returns: A producer that sends events from `self` and then from
	///            `replacement` when `self` completes.
	public func then<Replacement: SignalProducerConvertible>(_ replacement: Replacement) -> SignalProducer<Replacement.Value, Error> where Replacement.Error == Never {
		return then(replacement.producer)
	}

	/// Wait for completion of `self`, *then* forward all events from
	/// `replacement`. Any failure or interruption sent from `self` is
	/// forwarded immediately, in which case `replacement` will not be started,
	/// and none of its events will be be forwarded.
	///
	/// - note: All values sent from `self` are ignored.
	///
	/// - parameters:
	///   - replacement: A producer to start when `self` completes.
	///
	/// - returns: A producer that sends events from `self` and then from
	///            `replacement` when `self` completes.
	public func then<U>(_ replacement: SignalProducer<U, Error>) -> SignalProducer<U, Error> {
		return _then(replacement)
	}

	/// Wait for completion of `self`, *then* forward all events from
	/// `replacement`. Any failure or interruption sent from `self` is
	/// forwarded immediately, in which case `replacement` will not be started,
	/// and none of its events will be be forwarded.
	///
	/// - note: All values sent from `self` are ignored.
	///
	/// - parameters:
	///   - replacement: A producer to start when `self` completes.
	///
	/// - returns: A producer that sends events from `self` and then from
	///            `replacement` when `self` completes.
	public func then<Replacement: SignalProducerConvertible>(_ replacement: Replacement) -> SignalProducer<Replacement.Value, Error> where Replacement.Error == Error {
		return then(replacement.producer)
	}

	// NOTE: The overload below is added to disambiguate compile-time selection of
	//       `then(_:)`.

	/// Wait for completion of `self`, *then* forward all events from
	/// `replacement`. Any failure or interruption sent from `self` is
	/// forwarded immediately, in which case `replacement` will not be started,
	/// and none of its events will be be forwarded.
	///
	/// - note: All values sent from `self` are ignored.
	///
	/// - parameters:
	///   - replacement: A producer to start when `self` completes.
	///
	/// - returns: A producer that sends events from `self` and then from
	///            `replacement` when `self` completes.
	public func then(_ replacement: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
		return _then(replacement)
	}

	/// Wait for completion of `self`, *then* forward all events from
	/// `replacement`. Any failure or interruption sent from `self` is
	/// forwarded immediately, in which case `replacement` will not be started,
	/// and none of its events will be be forwarded.
	///
	/// - note: All values sent from `self` are ignored.
	///
	/// - parameters:
	///   - replacement: A producer to start when `self` completes.
	///
	/// - returns: A producer that sends events from `self` and then from
	///            `replacement` when `self` completes.
	public func then<Replacement: SignalProducerConvertible>(_ replacement: Replacement) -> SignalProducer<Value, Error> where Replacement.Value == Value, Replacement.Error == Error {
		return then(replacement.producer)
	}

	// NOTE: The method below is the shared implementation of `then(_:)`. The underscore
	//       prefix is added to avoid self referencing in `then(_:)` overloads with
	//       regard to the most specific rule of overload selection in Swift.

	internal func _then<Replacement: SignalProducerConvertible>(_ replacement: Replacement) -> SignalProducer<Replacement.Value, Error> where Replacement.Error == Error {
		return SignalProducer<Replacement.Value, Error> { observer, lifetime in
			self.startWithSignal { signal, signalDisposable in
				lifetime += signalDisposable

				signal.observe { event in
					switch event {
					case let .failed(error):
						observer.send(error: error)
					case .completed:
						lifetime += replacement.producer.start(observer)
					case .interrupted:
						observer.sendInterrupted()
					case .value:
						break
					}
				}
			}
		}
	}
}

extension SignalProducer where Error == Never {
	/// Wait for completion of `self`, *then* forward all events from
	/// `replacement`.
	///
	/// - note: All values sent from `self` are ignored.
	///
	/// - parameters:
	///   - replacement: A producer to start when `self` completes.
	///
	/// - returns: A producer that sends events from `self` and then from
	///            `replacement` when `self` completes.
	public func then<U, F>(_ replacement: SignalProducer<U, F>) -> SignalProducer<U, F> {
		return promoteError(F.self)._then(replacement)
	}

	/// Wait for completion of `self`, *then* forward all events from
	/// `replacement`.
	///
	/// - note: All values sent from `self` are ignored.
	///
	/// - parameters:
	///   - replacement: A producer to start when `self` completes.
	///
	/// - returns: A producer that sends events from `self` and then from
	///            `replacement` when `self` completes.
	public func then<Replacement: SignalProducerConvertible>(_ replacement: Replacement) -> SignalProducer<Replacement.Value, Replacement.Error> {
		return then(replacement.producer)
	}

	// NOTE: The overload below is added to disambiguate compile-time selection of
	//       `then(_:)`.

	/// Wait for completion of `self`, *then* forward all events from
	/// `replacement`.
	///
	/// - note: All values sent from `self` are ignored.
	///
	/// - parameters:
	///   - replacement: A producer to start when `self` completes.
	///
	/// - returns: A producer that sends events from `self` and then from
	///            `replacement` when `self` completes.
	public func then<U>(_ replacement: SignalProducer<U, Never>) -> SignalProducer<U, Never> {
		return _then(replacement)
	}

	/// Wait for completion of `self`, *then* forward all events from
	/// `replacement`.
	///
	/// - note: All values sent from `self` are ignored.
	///
	/// - parameters:
	///   - replacement: A producer to start when `self` completes.
	///
	/// - returns: A producer that sends events from `self` and then from
	///            `replacement` when `self` completes.
	public func then<Replacement: SignalProducerConvertible>(_ replacement: Replacement) -> SignalProducer<Replacement.Value, Never> where Replacement.Error == Never {
		return then(replacement.producer)
	}

	/// Wait for completion of `self`, *then* forward all events from
	/// `replacement`.
	///
	/// - note: All values sent from `self` are ignored.
	///
	/// - parameters:
	///   - replacement: A producer to start when `self` completes.
	///
	/// - returns: A producer that sends events from `self` and then from
	///            `replacement` when `self` completes.
	public func then(_ replacement: SignalProducer<Value, Never>) -> SignalProducer<Value, Never> {
		return _then(replacement)
	}

	/// Wait for completion of `self`, *then* forward all events from
	/// `replacement`.
	///
	/// - note: All values sent from `self` are ignored.
	///
	/// - parameters:
	///   - replacement: A producer to start when `self` completes.
	///
	/// - returns: A producer that sends events from `self` and then from
	///            `replacement` when `self` completes.
	public func then<Replacement: SignalProducerConvertible>(_ replacement: Replacement) -> SignalProducer<Value, Never> where Replacement.Value == Value, Replacement.Error == Never {
		return then(replacement.producer)
	}
}

extension SignalProducer {
	/// Start the producer, then block, waiting for the first value.
	///
	/// When a single value or error is sent, the returned `Result` will
	/// represent those cases. However, when no values are sent, `nil` will be
	/// returned.
	///
	/// - returns: Result when single `value` or `failed` event is received.
	///            `nil` when no events are received.
	public func first() -> Result<Value, Error>? {
		return take(first: 1).single()
	}

	/// Start the producer, then block, waiting for events: `value` and
	/// `completed`.
	///
	/// When a single value or error is sent, the returned `Result` will
	/// represent those cases. However, when no values are sent, or when more
	/// than one value is sent, `nil` will be returned.
	///
	/// - returns: Result when single `value` or `failed` event is received.
	///            `nil` when 0 or more than 1 events are received.
	public func single() -> Result<Value, Error>? {
		let semaphore = DispatchSemaphore(value: 0)
		var result: Result<Value, Error>?

		take(first: 2).start { event in
			switch event {
			case let .value(value):
				if result != nil {
					// Move into failure state after recieving another value.
					result = nil
					return
				}
				result = .success(value)
			case let .failed(error):
				result = .failure(error)
				semaphore.signal()
			case .completed, .interrupted:
				semaphore.signal()
			}
		}

		semaphore.wait()
		return result
	}

	/// Start the producer, then block, waiting for the last value.
	///
	/// When a single value or error is sent, the returned `Result` will
	/// represent those cases. However, when no values are sent, `nil` will be
	/// returned.
	///
	/// - returns: Result when single `value` or `failed` event is received.
	///            `nil` when no events are received.
	public func last() -> Result<Value, Error>? {
		return take(last: 1).single()
	}

	/// Starts the producer, then blocks, waiting for completion.
	///
	/// When a completion or error is sent, the returned `Result` will represent
	/// those cases.
	///
	/// - returns: Result when single `completion` or `failed` event is
	///            received.
	public func wait() -> Result<(), Error> {
		return then(SignalProducer<(), Error>(value: ())).last() ?? .success(())
	}

	/// Creates a new `SignalProducer` that will multicast values emitted by
	/// the underlying producer, up to `capacity`.
	/// This means that all clients of this `SignalProducer` will see the same
	/// version of the emitted values/errors.
	///
	/// The underlying `SignalProducer` will not be started until `self` is
	/// started for the first time. When subscribing to this producer, all
	/// previous values (up to `capacity`) will be emitted, followed by any new
	/// values.
	///
	/// If you find yourself needing *the current value* (the last buffered
	/// value) you should consider using `PropertyType` instead, which, unlike
	/// this operator, will guarantee at compile time that there's always a
	/// buffered value. This operator is not recommended in most cases, as it
	/// will introduce an implicit relationship between the original client and
	/// the rest, so consider alternatives like `PropertyType`, or representing
	/// your stream using a `Signal` instead.
	///
	/// This operator is only recommended when you absolutely need to introduce
	/// a layer of caching in front of another `SignalProducer`.
	///
	/// - precondition: `capacity` must be non-negative integer.
	///
	/// - parameters:
	///   - capacity: Number of values to hold.
	///
	/// - returns: A caching producer that will hold up to last `capacity`
	///            values.
	public func replayLazily(upTo capacity: Int) -> SignalProducer<Value, Error> {
		precondition(capacity >= 0, "Invalid capacity: \(capacity)")

		// This will go "out of scope" when the returned `SignalProducer` goes
		// out of scope. This lets us know when we're supposed to dispose the
		// underlying producer. This is necessary because `struct`s don't have
		// `deinit`.
		let lifetimeToken = Lifetime.Token()
		let lifetime = Lifetime(lifetimeToken)

		let state = Atomic(ReplayState<Value, Error>(upTo: capacity))

		let start: Atomic<(() -> Void)?> = Atomic {
			// Start the underlying producer.
			self
				.take(during: lifetime)
				.start { event in
					let observers: Bag<Signal<Value, Error>.Observer>? = state.modify { state in
						defer { state.enqueue(event) }
						return state.observers
					}
					observers?.forEach { $0.send(event) }
				}
		}

		return SignalProducer { observer, lifetime in
			// Don't dispose of the original producer until all observers
			// have terminated.
			lifetime.observeEnded { _ = lifetimeToken }

			while true {
				var result: Result<Bag<Signal<Value, Error>.Observer>.Token?, ReplayError<Value>>!
				state.modify {
					result = $0.observe(observer)
				}

				switch result! {
				case let .success(token):
					if let token = token {
						lifetime.observeEnded {
							state.modify {
								$0.removeObserver(using: token)
							}
						}
					}

					// Start the underlying producer if it has never been started.
					start.swap(nil)?()

					// Terminate the replay loop.
					return

				case let .failure(error):
					error.values.forEach(observer.send(value:))
				}
			}
		}
	}
}

extension SignalProducer where Value == Bool {
	/// Create a producer that computes a logical NOT in the latest values of `self`.
	///
	/// - returns: A producer that emits the logical NOT results.
	public func negate() -> SignalProducer<Value, Error> {
		return map(!)
	}

	/// Create a producer that computes a logical AND between the latest values of `self`
	/// and `producer`.
	///
	/// - parameters:
	///   - booleans: A producer of booleans to be combined with `self`.
	///
	/// - returns: A producer that emits the logical AND results.
	public func and(_ booleans: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
		return type(of: self).all([self, booleans])
	}

	/// Create a producer that computes a logical AND between the latest values of `self`
	/// and `producer`.
	///
	/// - parameters:
	///   - booleans: A producer of booleans to be combined with `self`.
	///
	/// - returns: A producer that emits the logical AND results.
	public func and<Booleans: SignalProducerConvertible>(_ booleans: Booleans) -> SignalProducer<Value, Error> where Booleans.Value == Value, Booleans.Error == Error {
		return and(booleans.producer)
	}
	
	/// Create a producer that computes a logical AND between the latest values of `booleans`.
	///
	/// If no producer is given in `booleans`, the resulting producer constantly emits `true`.
	///
	/// - parameters:
	///   - booleans: A collection of boolean producers to be combined.
	///
	/// - returns: A producer that emits the logical AND results.
	public static func all<BooleansCollection: Collection>(_ booleans: BooleansCollection) -> SignalProducer<Value, Error> where BooleansCollection.Element == SignalProducer<Value, Error> {
		return combineLatest(booleans, emptySentinel: []).map { $0.reduce(true) { $0 && $1 } }
	}
    
    /// Create a producer that computes a logical AND between the latest values of `booleans`.
    ///
    /// If no producer is given in `booleans`, the resulting producer constantly emits `true`.
    ///
    /// - parameters:
    ///   - booleans: Boolean producers to be combined.
    ///
    /// - returns: A producer that emits the logical AND results.
    public static func all(_ booleans: SignalProducer<Value, Error>...) -> SignalProducer<Value, Error> {
        return .all(booleans)
    }
	
	/// Create a producer that computes a logical AND between the latest values of `booleans`.
    ///
    /// If no producer is given in `booleans`, the resulting producer constantly emits `true`.
	///
	/// - parameters:
	///   - booleans: A collection of boolean producers to be combined.
	///
	/// - returns: A producer that emits the logical AND results.
	public static func all<Booleans: SignalProducerConvertible, BooleansCollection: Collection>(_ booleans: BooleansCollection) -> SignalProducer<Value, Error> where Booleans.Value == Value, Booleans.Error == Error, BooleansCollection.Element == Booleans {
		return all(booleans.map { $0.producer })
	}

	/// Create a producer that computes a logical OR between the latest values of `self`
	/// and `producer`.
	///
	/// - parameters:
	///   - booleans: A producer of booleans to be combined with `self`.
	///
	/// - returns: A producer that emits the logical OR results.
	public func or(_ booleans: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
		return type(of: self).any([self, booleans])
	}

	/// Create a producer that computes a logical OR between the latest values of `self`
	/// and `producer`.
	///
	/// - parameters:
	///   - booleans: A producer of booleans to be combined with `self`.
	///
	/// - returns: A producer that emits the logical OR results.
	public func or<Booleans: SignalProducerConvertible>(_ booleans: Booleans) -> SignalProducer<Value, Error> where Booleans.Value == Value, Booleans.Error == Error {
		return or(booleans.producer)
	}
	
	/// Create a producer that computes a logical OR between the latest values of `booleans`.
	///
	/// If no producer is given in `booleans`, the resulting producer constantly emits `false`.
	///
	/// - parameters:
	///   - booleans: A collection of boolean producers to be combined.
	///
	/// - returns: A producer that emits the logical OR results.
	public static func any<BooleansCollection: Collection>(_ booleans: BooleansCollection) -> SignalProducer<Value, Error> where BooleansCollection.Element == SignalProducer<Value, Error> {
		return combineLatest(booleans, emptySentinel: []).map { $0.reduce(false) { $0 || $1 } }
	}
    
    /// Create a producer that computes a logical OR between the latest values of `booleans`.
    ///
    /// If no producer is given in `booleans`, the resulting producer constantly emits `false`.
    ///
    /// - parameters:
    ///   - booleans: Boolean producers to be combined.
    ///
    /// - returns: A producer that emits the logical OR results.
    public static func any(_ booleans: SignalProducer<Value, Error>...) -> SignalProducer<Value, Error> {
        return .any(booleans)
    }
	
	/// Create a producer that computes a logical OR between the latest values of `booleans`.
	///
	/// If no producer is given in `booleans`, the resulting producer constantly emits `false`.
	///
	/// - parameters:
	///   - booleans: A collection of boolean producers to be combined.
	///
	/// - returns: A producer that emits the logical OR results.
	public static func any<Booleans: SignalProducerConvertible, BooleansCollection: Collection>(_ booleans: BooleansCollection) -> SignalProducer<Value, Error> where Booleans.Value == Value, Booleans.Error == Error, BooleansCollection.Element == Booleans {
		return any(booleans.map { $0.producer })
	}
}

/// Represents a recoverable error of an observer not being ready for an
/// attachment to a `ReplayState`, and the observer should replay the supplied
/// values before attempting to observe again.
private struct ReplayError<Value>: Error {
	/// The values that should be replayed by the observer.
	let values: [Value]
}

private struct ReplayState<Value, Error: Swift.Error> {
	let capacity: Int

	/// All cached values.
	var values: [Value] = []

	/// A termination event emitted by the underlying producer.
	///
	/// This will be nil if termination has not occurred.
	var terminationEvent: Signal<Value, Error>.Event?

	/// The observers currently attached to the caching producer, or `nil` if the
	/// caching producer was terminated.
	var observers: Bag<Signal<Value, Error>.Observer>? = Bag()

	/// The set of in-flight replay buffers.
	var replayBuffers: [ObjectIdentifier: [Value]] = [:]

	/// Initialize the replay state.
	///
	/// - parameters:
	///   - capacity: The maximum amount of values which can be cached by the
	///               replay state.
	init(upTo capacity: Int) {
		self.capacity = capacity
	}

	/// Attempt to observe the replay state.
	///
	/// - warning: Repeatedly observing the replay state with the same observer
	///            should be avoided.
	///
	/// - parameters:
	///   - observer: The observer to be registered.
	///
	/// - returns: If the observer is successfully attached, a `Result.success`
	///            with the corresponding removal token would be returned.
	///            Otherwise, a `Result.failure` with a `ReplayError` would be
	///            returned.
	mutating func observe(_ observer: Signal<Value, Error>.Observer) -> Result<Bag<Signal<Value, Error>.Observer>.Token?, ReplayError<Value>> {
		// Since the only use case is `replayLazily`, which always creates a unique
		// `Observer` for every produced signal, we can use the ObjectIdentifier of
		// the `Observer` to track them directly.
		let id = ObjectIdentifier(observer)

		switch replayBuffers[id] {
		case .none where !values.isEmpty:
			// No in-flight replay buffers was found, but the `ReplayState` has one or
			// more cached values in the `ReplayState`. The observer should replay
			// them before attempting to observe again.
			replayBuffers[id] = []
			return .failure(ReplayError(values: values))

		case let .some(buffer) where !buffer.isEmpty:
			// An in-flight replay buffer was found with one or more buffered values.
			// The observer should replay them before attempting to observe again.
			defer { replayBuffers[id] = [] }
			return .failure(ReplayError(values: buffer))

		case let .some(buffer) where buffer.isEmpty:
			// Since an in-flight but empty replay buffer was found, the observer is
			// ready to be attached to the `ReplayState`.
			replayBuffers.removeValue(forKey: id)

		default:
			// No values has to be replayed. The observer is ready to be attached to
			// the `ReplayState`.
			break
		}

		if let event = terminationEvent {
			observer.send(event)
		}

		return .success(observers?.insert(observer))
	}

	/// Enqueue the supplied event to the replay state.
	///
	/// - parameter:
	///   - event: The event to be cached.
	mutating func enqueue(_ event: Signal<Value, Error>.Event) {
		switch event {
		case let .value(value):
			for key in replayBuffers.keys {
				replayBuffers[key]!.append(value)
			}

			switch capacity {
			case 0:
				// With a capacity of zero, `state.values` can never be filled.
				break

			case 1:
				values = [value]

			default:
				values.append(value)

				let overflow = values.count - capacity
				if overflow > 0 {
					values.removeFirst(overflow)
				}
			}

		case .completed, .failed, .interrupted:
			// Disconnect all observers and prevent future attachments.
			terminationEvent = event
			observers = nil
		}
	}

	/// Remove the observer represented by the supplied token.
	///
	/// - parameters:
	///   - token: The token of the observer to be removed.
	mutating func removeObserver(using token: Bag<Signal<Value, Error>.Observer>.Token) {
		observers?.remove(using: token)
	}
}

extension SignalProducer where Value == Date, Error == Never {
	/// Create a repeating timer of the given interval, with a reasonable default
	/// leeway, sending updates on the given scheduler.
	///
	/// - note: This timer will never complete naturally, so all invocations of
	///         `start()` must be disposed to avoid leaks.
	///
	/// - precondition: `interval` must be non-negative number.
	///
	///	- note: If you plan to specify an `interval` value greater than 200,000
	///			seconds, use `timer(interval:on:leeway:)` instead
	///			and specify your own `leeway` value to avoid potential overflow.
	///
	/// - parameters:
	///   - interval: An interval between invocations.
	///   - scheduler: A scheduler to deliver events on.
	///
	/// - returns: A producer that sends `Date` values every `interval` seconds.
	public static func timer(interval: DispatchTimeInterval, on scheduler: DateScheduler) -> SignalProducer<Value, Error> {
		// Apple's "Power Efficiency Guide for Mac Apps" recommends a leeway of
		// at least 10% of the timer interval.
		return timer(interval: interval, on: scheduler, leeway: interval * 0.1)
	}

	/// Creates a repeating timer of the given interval, sending updates on the
	/// given scheduler.
	///
	/// - note: This timer will never complete naturally, so all invocations of
	///         `start()` must be disposed to avoid leaks.
	///
	/// - precondition: `interval` must be non-negative number.
	///
	/// - precondition: `leeway` must be non-negative number.
	///
	/// - parameters:
	///   - interval: An interval between invocations.
	///   - scheduler: A scheduler to deliver events on.
	///   - leeway: Interval leeway. Apple's "Power Efficiency Guide for Mac Apps"
	///             recommends a leeway of at least 10% of the timer interval.
	///
	/// - returns: A producer that sends `Date` values every `interval` seconds.
	public static func timer(interval: DispatchTimeInterval, on scheduler: DateScheduler, leeway: DispatchTimeInterval) -> SignalProducer<Value, Error> {
		precondition(interval.timeInterval >= 0)
		precondition(leeway.timeInterval >= 0)

		return SignalProducer { observer, lifetime in
			lifetime += scheduler.schedule(
				after: scheduler.currentDate.addingTimeInterval(interval),
				interval: interval,
				leeway: leeway,
				action: { observer.send(value: scheduler.currentDate) }
			)
		}
	}
}

extension SignalProducer where Error == Never {
	/// Creates a producer that will send the values from the given sequence
	/// separated by the given time interval.
	///
	/// - note: If `values` is an infinite sequeence this `SignalProducer` will never complete naturally,
	///         so all invocations of `start()` must be disposed to avoid leaks.
	///
	/// - precondition: `interval` must be non-negative number.
	///
	/// - parameters:
	///   - values: A sequence of values that will be sent as separate
	///             `value` events and then complete.
	///   - interval: An interval between value events.
	///   - scheduler: A scheduler to deliver events on.
	///
	/// - returns: A producer that sends the next value from the sequence every `interval` seconds.
	public static func interval<S: Sequence>(
		_ values: S,
		interval: DispatchTimeInterval,
		on scheduler: DateScheduler
	) -> SignalProducer<S.Element, Error> where S.Iterator.Element == Value {

		return SignalProducer { observer, lifetime in
			var iterator = values.makeIterator()

			lifetime += scheduler.schedule(
				after: scheduler.currentDate.addingTimeInterval(interval),
				interval: interval,
				// Apple's "Power Efficiency Guide for Mac Apps" recommends a leeway of
				// at least 10% of the timer interval.
				leeway: interval * 0.1,
				action: {
					switch iterator.next() {
					case let .some(value):
						observer.send(value: value)
					case .none:
						observer.sendCompleted()
					}
				}
			)
		}
	}

	/// Creates a producer that will send the sequence of all integers
	/// from 0 to infinity, or until disposed.
	///
	/// - note: This timer will never complete naturally, so all invocations of
	///         `start()` must be disposed to avoid leaks.
	///
	/// - precondition: `interval` must be non-negative number.
	///
	/// - parameters:
	///   - interval: An interval between value events.
	///   - scheduler: A scheduler to deliver events on.
	///
	/// - returns: A producer that sends a sequential `Int` value every `interval` seconds.
	public static func interval(
		_ interval: DispatchTimeInterval,
		on scheduler: DateScheduler
	) -> SignalProducer where Value == Int {
		.interval(0..., interval: interval, on: scheduler)
	}
}
