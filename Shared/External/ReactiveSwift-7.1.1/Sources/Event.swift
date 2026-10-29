import Foundation
import Dispatch

extension Signal {
	/// Represents a signal event.
	///
	/// Signals must conform to the grammar:
	/// `value* (failed | completed | interrupted)?`
	@frozen
	public enum Event {
		/// A value provided by the signal.
		case value(Value)

		/// The signal terminated because of an error. No further events will be
		/// received.
		case failed(Error)

		/// The signal successfully terminated. No further events will be received.
		case completed

		/// Event production on the signal has been interrupted. No further events
		/// will be received.
		///
		/// - important: This event does not signify the successful or failed
		///              completion of the signal.
		case interrupted

		/// Whether this event is a completed event.
		public var isCompleted: Bool {
			switch self {
			case .completed:
				return true

			case .value, .failed, .interrupted:
				return false
			}
		}

		/// Whether this event indicates signal termination (i.e., that no further
		/// events will be received).
		public var isTerminating: Bool {
			switch self {
			case .value:
				return false

			case .failed, .completed, .interrupted:
				return true
			}
		}

		/// Lift the given closure over the event's value.
		///
		/// - important: The closure is called only on `value` type events.
		///
		/// - parameters:
		///   - f: A closure that accepts a value and returns a new value
		///
		/// - returns: An event with function applied to a value in case `self` is a
		///            `value` type of event.
		public func map<U>(_ f: (Value) -> U) -> Signal<U, Error>.Event {
			switch self {
			case let .value(value):
				return .value(f(value))

			case let .failed(error):
				return .failed(error)

			case .completed:
				return .completed

			case .interrupted:
				return .interrupted
			}
		}

		/// Lift the given closure over the event's error.
		///
		/// - important: The closure is called only on failed type event.
		///
		/// - parameters:
		///   - f: A closure that accepts an error object and returns
		///        a new error object
		///
		/// - returns: An event with function applied to an error object in case
		///            `self` is a `.Failed` type of event.
		public func mapError<F>(_ f: (Error) -> F) -> Signal<Value, F>.Event {
			switch self {
			case let .value(value):
				return .value(value)

			case let .failed(error):
				return .failed(f(error))

			case .completed:
				return .completed

			case .interrupted:
				return .interrupted
			}
		}

		/// Unwrap the contained `value` value.
		public var value: Value? {
			if case let .value(value) = self {
				return value
			} else {
				return nil
			}
		}

		/// Unwrap the contained `Error` value.
		public var error: Error? {
			if case let .failed(error) = self {
				return error
			} else {
				return nil
			}
		}
	}
}

extension Signal.Event where Value: Equatable, Error: Equatable {
	public static func == (lhs: Signal<Value, Error>.Event, rhs: Signal<Value, Error>.Event) -> Bool {
		switch (lhs, rhs) {
		case let (.value(left), .value(right)):
			return left == right

		case let (.failed(left), .failed(right)):
			return left == right

		case (.completed, .completed):
			return true

		case (.interrupted, .interrupted):
			return true

		default:
			return false
		}
	}
}

extension Signal.Event: Equatable where Value: Equatable, Error: Equatable {}

extension Signal.Event: CustomStringConvertible {
	public var description: String {
		switch self {
		case let .value(value):
			return "VALUE \(value)"

		case let .failed(error):
			return "FAILED \(error)"

		case .completed:
			return "COMPLETED"

		case .interrupted:
			return "INTERRUPTED"
		}
	}
}

/// Event protocol for constraining signal extensions
public protocol EventProtocol {
	/// The value type of an event.
	associatedtype Value
	/// The error type of an event. If errors aren't possible then `Never` can
	/// be used.
	associatedtype Error: Swift.Error
	/// Extracts the event from the receiver.
	var event: Signal<Value, Error>.Event { get }
}

extension Signal.Event: EventProtocol {
	public var event: Signal<Value, Error>.Event {
		return self
	}
}

// Event Transformations
//
// Operators backed by event transformations have such characteristics:
//
// 1. Unary
//    The operator applies to only one stream.
//
// 2. Serial
//    The outcome need not be synchronously emitted, but all events must be delivered in
//    serial order.
//
// 3. No side effect upon interruption.
//    The operator must not perform any side effect upon receving `interrupted`.
//
// Examples of ineligible operators (for now):
//
// 1. `timeout`
//    This operator forwards the `failed` event on a different scheduler.
//
// 2. `combineLatest`
//    This operator applies to two or more streams.
//
// 3. `SignalProducer.then`
//    This operator starts a second stream when the first stream completes.
//
// 4. `on`
//    This operator performs side effect upon interruption.

extension Signal.Event {
	internal typealias Transformation<U, E: Swift.Error> = (ReactiveSwift.Observer<U, E>, Lifetime) -> ReactiveSwift.Observer<Value, Error>

	internal static func filter(_ isIncluded: @escaping (Value) -> Bool) -> Transformation<Value, Error> {
		return { downstream, _ in
			Operators.Filter(downstream: downstream, predicate: isIncluded)
		}
	}

	internal static func compactMap<U>(_ transform: @escaping (Value) -> U?) -> Transformation<U, Error> {
		return { downstream, _ in
			Operators.CompactMap(downstream: downstream, transform: transform)
		}
	}

	internal static func map<U>(_ transform: @escaping (Value) -> U) -> Transformation<U, Error> {
		return { downstream, _ in
			Operators.Map(downstream: downstream, transform: transform)
		}
	}

	internal static func mapError<E>(_ transform: @escaping (Error) -> E) -> Transformation<Value, E> {
		return { downstream, _ in
			Operators.MapError(downstream: downstream, transform: transform)
		}
	}

	internal static var materialize: Transformation<Signal<Value, Error>.Event, Never> {
		return { downstream, _ in
			Operators.Materialize(downstream: downstream)
		}
	}

	internal static var materializeResults: Transformation<Result<Value, Error>, Never> {
		return { downstream, _ in
			Operators.MaterializeAsResult(downstream: downstream)
		}
	}

	internal static func attemptMap<U>(_ transform: @escaping (Value) -> Result<U, Error>) -> Transformation<U, Error> {
		return { downstream, _ in
			Operators.AttemptMap(downstream: downstream, transform: transform)
		}
	}

	internal static func attempt(_ action: @escaping (Value) -> Result<(), Error>) -> Transformation<Value, Error> {
		return attemptMap { value -> Result<Value, Error> in
			return action(value).map { _ in value }
		}
	}
}

extension Signal.Event where Error == Swift.Error {
	internal static func attempt(_ action: @escaping (Value) throws -> Void) -> Transformation<Value, Error> {
		return attemptMap { value in
			try action(value)
			return value
		}
	}

	internal static func attemptMap<U>(_ transform: @escaping (Value) throws -> U) -> Transformation<U, Error> {
		return attemptMap { value in
			Result { try transform(value) }
		}
	}
}

extension Signal.Event {
	internal static func take(first count: Int) -> Transformation<Value, Error> {
		return { downstream, _ in
			Operators.TakeFirst(downstream: downstream, count: count)
		}
	}

	internal static func take(last count: Int) -> Transformation<Value, Error> {
		return { downstream, _ in
			Operators.TakeLast(downstream: downstream, count: count)
		}
	}

	internal static func take(while shouldContinue: @escaping (Value) -> Bool) -> Transformation<Value, Error> {
		return { downstream, _ in
			Operators.TakeWhile(downstream: downstream, shouldContinue: shouldContinue)
		}
	}
	
	internal static func take(until shouldContinue: @escaping (Value) -> Bool) -> Transformation<Value, Error> {
		return { downstream, _ in
			Operators.TakeUntil(downstream: downstream, shouldContinue: shouldContinue)
		}
	}

	internal static func skip(first count: Int) -> Transformation<Value, Error> {
		return { downstream, _ in
			Operators.SkipFirst(downstream: downstream, count: count)
		}
	}

	internal static func skip(while shouldContinue: @escaping (Value) -> Bool) -> Transformation<Value, Error> {
		return { downstream, _ in
			Operators.SkipWhile(downstream: downstream, shouldContinueToSkip: shouldContinue)
		}
	}
}

extension Signal.Event where Value: EventProtocol, Error == Never {
	internal static var dematerialize: Transformation<Value.Value, Value.Error> {
		return { downstream, _ in
			Operators.Dematerialize(downstream: downstream)
		}
	}
}

extension Signal.Event where Value: ResultProtocol, Error == Never {
	internal static var dematerializeResults: Transformation<Value.Success, Value.Failure> {
		return { downstream, _ in
			Operators.DematerializeResults(downstream: downstream)
		}
	}
}

extension Signal.Event where Value: OptionalProtocol {
	internal static var skipNil: Transformation<Value.Wrapped, Error> {
		return compactMap { $0.optional }
	}
}

extension Signal.Event {
	internal static var collect: Transformation<[Value], Error> {
		return collect { _, _ in false }
	}

	internal static func collect(count: Int) -> Transformation<[Value], Error> {
		precondition(count > 0)
		return collect { values in values.count == count }
	}

	internal static func collect(_ shouldEmit: @escaping (_ collectedValues: [Value]) -> Bool) -> Transformation<[Value], Error> {
		return { downstream, _ in
			Operators.Collect(downstream: downstream, shouldEmit: shouldEmit)
		}
	}

	internal static func collect(_ shouldEmit: @escaping (_ collected: [Value], _ latest: Value) -> Bool) -> Transformation<[Value], Error> {
		return { downstream, _ in
			Operators.Collect(downstream: downstream, shouldEmit: shouldEmit)
		}
	}

	/// Implementation detail of `combinePrevious`. A default argument of a `nil` initial
	/// is deliberately avoided, since in the case of `Value` being an optional, the
	/// `nil` literal would be materialized as `Optional<Value>.none` instead of `Value`,
	/// thus changing the semantic.
	internal static func combinePrevious(initial: Value?) -> Transformation<(Value, Value), Error> {
		return { downstream, _ in
			Operators.CombinePrevious(downstream: downstream, initial: initial)
		}
	}

	internal static func skipRepeats(_ isEquivalent: @escaping (Value, Value) -> Bool) -> Transformation<Value, Error> {
		return { downstream, _ in
			Operators.SkipRepeats(downstream: downstream, isEquivalent: isEquivalent)
		}
	}

	internal static func uniqueValues<Identity: Hashable>(_ transform: @escaping (Value) -> Identity) -> Transformation<Value, Error> {
		return { downstream, _ in
			Operators.UniqueValues(downstream: downstream, extract: transform)
		}
	}

	internal static func reduce<U>(into initialResult: U, _ nextPartialResult: @escaping (inout U, Value) -> Void) -> Transformation<U, Error> {
		return { downstream, _ in
			Operators.Reduce(downstream: downstream, initial: initialResult, nextPartialResult: nextPartialResult)
		}
	}

	internal static func reduce<U>(_ initialResult: U, _ nextPartialResult: @escaping (U, Value) -> U) -> Transformation<U, Error> {
		return reduce(into: initialResult) { $0 = nextPartialResult($0, $1) }
	}

	internal static func scan<U>(into initialResult: U, _ nextPartialResult: @escaping (inout U, Value) -> Void) -> Transformation<U, Error> {
		return self.scanMap(into: initialResult, { result, value -> U in
			nextPartialResult(&result, value)
			return result
		})
	}

	internal static func scan<U>(_ initialResult: U, _ nextPartialResult: @escaping (U, Value) -> U) -> Transformation<U, Error> {
		return scan(into: initialResult) { $0 = nextPartialResult($0, $1) }
	}

	internal static func scanMap<State, U>(into initialState: State, _ next: @escaping (inout State, Value) -> U) -> Transformation<U, Error> {
		return { downstream, _ in
			Operators.ScanMap(downstream: downstream, initial: initialState, next: next)
		}
	}

	internal static func scanMap<State, U>(_ initialState: State, _ next: @escaping (State, Value) -> (State, U)) -> Transformation<U, Error> {
		return scanMap(into: initialState) { state, value in
			let new = next(state, value)
			state = new.0
			return new.1
		}
	}

	internal static func observe(on scheduler: Scheduler) -> Transformation<Value, Error> {
		return { downstream, lifetime in
			Operators.ObserveOn(downstream: downstream, downstreamLifetime: lifetime, target: scheduler)
		}
	}

	internal static func lazyMap<U>(on scheduler: Scheduler, transform: @escaping (Value) -> U) -> Transformation<U, Error> {
		return { downstream, lifetime in
			Operators.LazyMap(downstream: downstream, downstreamLifetime: lifetime, target: scheduler, transform: transform)
		}
	}

	internal static func delay(_ interval: TimeInterval, on scheduler: DateScheduler) -> Transformation<Value, Error> {
		return { downstream, lifetime in
			Operators.Delay(downstream: downstream, downstreamLifetime: lifetime, target: scheduler, interval: interval)
		}
	}

	internal static func throttle(_ interval: TimeInterval, on scheduler: DateScheduler) -> Transformation<Value, Error> {
		return { downstream, lifetime in
			Operators.Throttle(downstream: downstream, downstreamLifetime: lifetime, target: scheduler, interval: interval)
		}
	}

	internal static func debounce(_ interval: TimeInterval, on scheduler: DateScheduler, discardWhenCompleted: Bool) -> Transformation<Value, Error> {
		return { downstream, lifetime in
			Operators.Debounce(
				downstream: downstream,
				downstreamLifetime: lifetime,
				target: scheduler,
				interval: interval,
				discardWhenCompleted: discardWhenCompleted
			)
		}
	}
	
	internal static func collect(every interval: DispatchTimeInterval, on scheduler: DateScheduler, skipEmpty: Bool, discardWhenCompleted: Bool) -> Transformation<[Value], Error> {
		return { downstream, lifetime in
			Operators.CollectEvery(
				downstream: downstream,
				downstreamLifetime: lifetime,
				target: scheduler,
				interval: interval,
				skipEmpty: skipEmpty,
				discardWhenCompleted: discardWhenCompleted
			)
		}
	}
}


extension Signal.Event where Error == Never {
	internal static func promoteError<F>(_: F.Type) -> Transformation<Value, F> {
		return { action, _ in
			return Signal.Observer { event in
				switch event {
				case let .value(value):
					action(.value(value))
				case .failed:
					fatalError("Never is impossible to construct")
				case .completed:
					action(.completed)
				case .interrupted:
					action(.interrupted)
				}
			}
		}
	}
}

extension Signal.Event where Value == Never {
	internal static func promoteValue<U>(_: U.Type) -> Transformation<U, Error> {
		return { action, _ in
			return Signal.Observer { event in
				action(event.promoteValue())
			}
		}
	}
}

extension Signal.Event where Value == Never {
	internal func promoteValue<U>() -> Signal<U, Error>.Event {
        switch event {
        case .value:
            fatalError("Never is impossible to construct")
        case let .failed(error):
            return .failed(error)
        case .completed:
            return .completed
        case .interrupted:
            return .interrupted
        }
    }
}
