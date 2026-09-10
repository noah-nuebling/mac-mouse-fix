import Dispatch
import Foundation

/// `Action` represents a repeatable work like `SignalProducer`. But on top of the
/// isolation of produced `Signal`s from a `SignalProducer`, `Action` provides
/// higher-order features like availability and mutual exclusion.
///
/// Similar to a produced `Signal` from a `SignalProducer`, each unit of the repreatable
/// work may output zero or more values, and terminate with or without an error at some
/// point.
///
/// The core of `Action` is the `execute` closure it created with. For every execution
/// attempt with a varying input, if the `Action` is enabled, it would request from the
/// `execute` closure a customized unit of work — represented by a `SignalProducer`.
/// Specifically, the `execute` closure would be supplied with the latest state of
/// `Action` and the external input from `apply()`.
///
/// `Action` enforces serial execution, and disables the `Action` during the execution.
public final class Action<Input, Output, Error: Swift.Error> {
	private struct ActionState<Value> {
		var isEnabled: Bool {
			return isUserEnabled && !isExecuting
		}

		var isUserEnabled: Bool
		var isExecuting: Bool
		var value: Value
	}

	private let execute: (Action<Input, Output, Error>, Input) -> SignalProducer<Output, ActionError<Error>>
	private let eventsObserver: Signal<Signal<Output, Error>.Event, Never>.Observer
	private let disabledErrorsObserver: Signal<(), Never>.Observer

	private let deinitToken: Lifetime.Token

	/// The lifetime of the `Action`.
	public let lifetime: Lifetime

	/// A signal of all events generated from all units of work of the `Action`.
	///
	/// In other words, this sends every `Event` from every unit of work that the `Action`
	/// executes.
	public let events: Signal<Signal<Output, Error>.Event, Never>

	/// A signal of all values generated from all units of work of the `Action`.
	///
	/// In other words, this sends every value from every unit of work that the `Action`
	/// executes.
	public let values: Signal<Output, Never>

	/// A signal of all errors generated from all units of work of the `Action`.
	///
	/// In other words, this sends every error from every unit of work that the `Action`
	/// executes.
	public let errors: Signal<Error, Never>

	/// A signal of all failed attempts to start a unit of work of the `Action`.
	public let disabledErrors: Signal<(), Never>

	/// A signal of all completed events generated from applications of the action.
	///
	/// In other words, this will send completed events from every signal generated
	/// by each SignalProducer returned from apply().
	public let completed: Signal<(), Never>

	/// Whether the action is currently executing.
	public let isExecuting: Property<Bool>

	/// Whether the action is currently enabled.
	public let isEnabled: Property<Bool>

	/// Initializes an `Action` that would be conditionally enabled depending on its
	/// state.
	///
	/// When the `Action` is asked to start the execution with an input value, a unit of
	/// work — represented by a `SignalProducer` — would be created by invoking
	/// `execute` with the latest state and the input value.
	///
	/// - note: `Action` guarantees that changes to `state` are observed in a
	///         thread-safe way. Thus, the value passed to `isEnabled` will
	///         always be identical to the value passed to `execute`, for each
	///         application of the action.
	///
	/// - note: This initializer should only be used if you need to provide
	///         custom input can also influence whether the action is enabled.
	///         The various convenience initializers should cover most use cases.
	///
	/// - parameters:
	///   - state: A property to be the state of the `Action`.
	///   - isEnabled: A predicate which determines the availability of the `Action`,
	///                given the latest `Action` state.
	///   - execute: A closure that produces a unit of work, as `SignalProducer`, to be
	///              executed by the `Action`.
	public init<State: PropertyProtocol>(state: State, enabledIf isEnabled: @escaping (State.Value) -> Bool, execute: @escaping (State.Value, Input) -> SignalProducer<Output, Error>) {
		let isUserEnabled = isEnabled

		(lifetime, deinitToken) = Lifetime.make()

		// `Action` retains its state property.
		lifetime.observeEnded { _ = state }

		(events, eventsObserver) = Signal<Signal<Output, Error>.Event, Never>.pipe()
		(disabledErrors, disabledErrorsObserver) = Signal<(), Never>.pipe()

		values = events.compactMap { $0.value }
		errors = events.compactMap { $0.error }
		completed = events.compactMap { $0.isCompleted ? () : nil }

		let actionState = MutableProperty(ActionState<State.Value>(isUserEnabled: true, isExecuting: false, value: state.value))

		// `isEnabled` and `isExecuting` have their own backing so that when the observers
		// of these synchronously affects the action state, the signal of the action state
		// does not deadlock due to the recursion.
		let isExecuting = MutableProperty(false)
		self.isExecuting = Property(capturing: isExecuting)
		let isEnabled = MutableProperty(actionState.value.isEnabled)
		self.isEnabled = Property(capturing: isEnabled)

		func modifyActionState<Result>(_ action: (inout ActionState<State.Value>) throws -> Result) rethrows -> Result {
			return try actionState.begin { storage in
				let oldState = storage.value
				defer {
					let newState = storage.value
					if oldState.isEnabled != newState.isEnabled {
						isEnabled.value = newState.isEnabled
					}
					if oldState.isExecuting != newState.isExecuting {
						isExecuting.value = newState.isExecuting
					}
				}
				return try storage.modify(action)
			}
		}

		lifetime += state.producer.startWithValues { value in
			modifyActionState { state in
				state.value = value
				state.isUserEnabled = isUserEnabled(value)
			}
		}

		self.execute = { action, input in
			return SignalProducer { observer, lifetime in
				let latestState: State.Value? = modifyActionState { state in
					guard state.isEnabled else {
						return nil
					}

					state.isExecuting = true
					return state.value
				}

				guard let state = latestState else {
					observer.send(error: .disabled)
					action.disabledErrorsObserver.send(value: ())
					return
				}

				let interruptHandle = execute(state, input).start { event in
					observer.send(event.mapError(ActionError.producerFailed))
					action.eventsObserver.send(value: event)
				}

				lifetime.observeEnded {
					interruptHandle.dispose()
					modifyActionState { $0.isExecuting = false }
				}
			}
		}
	}

	/// Initializes an `Action` that uses a property as its state.
	///
	/// When the `Action` is asked to start the execution, a unit of work — represented by
	/// a `SignalProducer` — would be created by invoking `execute` with the latest value
	/// of the state.
	///
	/// - parameters:
	///   - state: A property to be the state of the `Action`.
	///   - execute: A closure that produces a unit of work, as `SignalProducer`, to
	///              be executed by the `Action`.
	public convenience init<P: PropertyProtocol>(state: P, execute: @escaping (P.Value, Input) -> SignalProducer<Output, Error>) {
		self.init(state: state, enabledIf: { _ in true }, execute: execute)
	}

	/// Initializes an `Action` that would be conditionally enabled.
	///
	/// When the `Action` is asked to start the execution with an input value, a unit of
	/// work — represented by a `SignalProducer` — would be created by invoking
	/// `execute` with the input value.
	///
	/// - parameters:
	///   - isEnabled: A property which determines the availability of the `Action`.
	///   - execute: A closure that produces a unit of work, as `SignalProducer`, to be
	///              executed by the `Action`.
	public convenience init<P: PropertyProtocol>(enabledIf isEnabled: P, execute: @escaping (Input) -> SignalProducer<Output, Error>) where P.Value == Bool {
		self.init(state: isEnabled, enabledIf: { $0 }) { _, input in
			execute(input)
		}
	}

	/// Initializes an `Action` that uses a property of optional as its state.
	///
	/// When the `Action` is asked to start executing, a unit of work (represented by
	/// a `SignalProducer`) is created by invoking `execute` with the latest value
	/// of the state and the `input` that was passed to `apply()`.
	///
	/// If the property holds a `nil`, the `Action` would be disabled until it is not
	/// `nil`.
	///
	/// - parameters:
	///   - state: A property of optional to be the state of the `Action`.
	///   - execute: A closure that produces a unit of work, as `SignalProducer`, to
	///              be executed by the `Action`.
	public convenience init<P: PropertyProtocol, T>(unwrapping state: P, execute: @escaping (T, Input) -> SignalProducer<Output, Error>) where P.Value == T? {
		self.init(state: state, enabledIf: { $0 != nil }) { state, input in
			execute(state!, input)
		}
	}

	/// Initializes an `Action` that uses a `ValidatingProperty` as its state.
	///
	/// When the `Action` is asked to start executing, a unit of work (represented by
	/// a `SignalProducer`) is created by invoking `execute` with the latest value
	/// of the state and the `input` that was passed to `apply()`.
	///
	/// If the `ValidatingProperty` does not hold a valid value, the `Action` would be
	/// disabled until it's valid.
	///
	/// - parameters:
	///   - state: A `ValidatingProperty` to be the state of the `Action`.
	///   - execute: A closure that produces a unit of work, as `SignalProducer`, to
	///              be executed by the `Action`.
	public convenience init<T, E>(validated state: ValidatingProperty<T, E>, execute: @escaping (T, Input) -> SignalProducer<Output, Error>) {
		self.init(unwrapping: state.result.map { $0.value }, execute: execute)
	}
	

	/// Initializes an `Action` that would always be enabled.
	///
	/// When the `Action` is asked to start the execution with an input value, a unit of
	/// work — represented by a `SignalProducer` — would be created by invoking
	/// `execute` with the input value.
	///
	/// - parameters:
	///   - execute: A closure that produces a unit of work, as `SignalProducer`, to be
	///              executed by the `Action`.
	public convenience init(execute: @escaping (Input) -> SignalProducer<Output, Error>) {
		self.init(enabledIf: Property(value: true), execute: execute)
	}

	deinit {
		eventsObserver.sendCompleted()
		disabledErrorsObserver.sendCompleted()
	}

	/// Create a `SignalProducer` that would attempt to create and start a unit of work of
	/// the `Action`. The `SignalProducer` would forward only events generated by the unit
	/// of work it created.
	///
	/// If the execution attempt is failed, the producer would fail with
	/// `ActionError.disabled`.
	///
	/// - parameters:
	///   - input: A value to be used to create the unit of work.
	///
	/// - returns: A producer that forwards events generated by its started unit of work,
	///            or emits `ActionError.disabled` if the execution attempt is failed.
	public func apply(_ input: Input) -> SignalProducer<Output, ActionError<Error>> {
		return execute(self, input)
	}
}

extension Action: BindingTargetProvider {
	public var bindingTarget: BindingTarget<Input> {
		return BindingTarget(lifetime: lifetime) { [weak self] in self?.apply($0).start() }
	}
}

extension Action where Input == Void {
	/// Create a `SignalProducer` that would attempt to create and start a unit of work of
	/// the `Action`. The `SignalProducer` would forward only events generated by the unit
	/// of work it created.
	///
	/// If the execution attempt is failed, the producer would fail with
	/// `ActionError.disabled`.
	///
	/// - returns: A producer that forwards events generated by its started unit of work,
	///            or emits `ActionError.disabled` if the execution attempt is failed.
	public func apply() -> SignalProducer<Output, ActionError<Error>> {
		return apply(())
	}

	/// Initializes an `Action` that uses a property of optional as its state.
	///
	/// When the `Action` is asked to start the execution, a unit of work — represented by
	/// a `SignalProducer` — would be created by invoking `execute` with the latest value
	/// of the state.
	///
	/// If the property holds a `nil`, the `Action` would be disabled until it is not
	/// `nil`.
	///
	/// - parameters:
	///   - state: A property of optional to be the state of the `Action`.
	///   - execute: A closure that produces a unit of work, as `SignalProducer`, to
	///              be executed by the `Action`.
	public convenience init<P: PropertyProtocol, T>(unwrapping state: P, execute: @escaping (T) -> SignalProducer<Output, Error>) where P.Value == T? {
		self.init(unwrapping: state) { state, _ in
			execute(state)
		}
	}
	
	/// Initializes an `Action` that uses a `ValidatingProperty` as its state.
	///
	/// When the `Action` is asked to start executing, a unit of work (represented by
	/// a `SignalProducer`) is created by invoking `execute` with the latest value
	/// of the state and the `input` that was passed to `apply()`.
	///
	/// If the `ValidatingProperty` does not hold a valid value, the `Action` would be
	/// disabled until it's valid.
	///
	/// - parameters:
	///   - state: A `ValidatingProperty` to be the state of the `Action`.
	///   - execute: A closure that produces a unit of work, as `SignalProducer`, to
	///              be executed by the `Action`.
	public convenience init<T, E>(validated state: ValidatingProperty<T, E>, execute: @escaping (T) -> SignalProducer<Output, Error>) {
		self.init(validated: state) { state, _ in
			execute(state)
		}
	}

	/// Initializes an `Action` that uses a property as its state.
	///
	/// When the `Action` is asked to start the execution, a unit of work — represented by
	/// a `SignalProducer` — would be created by invoking `execute` with the latest value
	/// of the state.
	///
	/// - parameters:
	///   - state: A property to be the state of the `Action`.
	///   - execute: A closure that produces a unit of work, as `SignalProducer`, to
	///              be executed by the `Action`.
	public convenience init<P: PropertyProtocol, T>(state: P, execute: @escaping (T) -> SignalProducer<Output, Error>) where P.Value == T {
		self.init(state: state) { state, _ in
			execute(state)
		}
	}
}

/// `ActionError` represents the error that could be emitted by a unit of work of a
/// certain `Action`.
public enum ActionError<Error: Swift.Error>: Swift.Error {
	/// The execution attempt was failed, since the `Action` was disabled.
	case disabled

	/// The unit of work emitted an error.
	case producerFailed(Error)
}

extension ActionError where Error: Equatable {
	public static func == (lhs: ActionError<Error>, rhs: ActionError<Error>) -> Bool {
		switch (lhs, rhs) {
		case (.disabled, .disabled):
			return true

		case let (.producerFailed(left), .producerFailed(right)):
			return left == right

		default:
			return false
		}
	}
}

extension ActionError: Equatable where Error: Equatable {}

