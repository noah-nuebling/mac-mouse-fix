import Foundation
import Dispatch

precedencegroup BindingPrecedence {
	associativity: right

	// Binds tighter than assignment but looser than everything else
	higherThan: AssignmentPrecedence
}

infix operator <~ : BindingPrecedence

/// Describes a source which can be bound.
public protocol BindingSource: SignalProducerConvertible where Error == Never {}
extension Signal: BindingSource where Error == Never {}
extension SignalProducer: BindingSource where Error == Never {}

/// Describes an entity which be bond towards.
public protocol BindingTargetProvider {
	associatedtype Value

	var bindingTarget: BindingTarget<Value> { get }
}

extension BindingTargetProvider {
	/// Binds a source to a target, updating the target's value to the latest
	/// value sent by the source.
	///
	/// - note: The binding will automatically terminate when the target is
	///         deinitialized, or when the source sends a `completed` event.
	///
	/// ````
	/// let property = MutableProperty(0)
	/// let signal = Signal({ /* do some work after some time */ })
	/// property <~ signal
	/// ````
	///
	/// ````
	/// let property = MutableProperty(0)
	/// let signal = Signal({ /* do some work after some time */ })
	/// let disposable = property <~ signal
	/// ...
	/// // Terminates binding before property dealloc or signal's
	/// // `completed` event.
	/// disposable.dispose()
	/// ````
	///
	/// - parameters:
	///   - target: A target to be bond to.
	///   - source: A source to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of the target or the source's `completed`
	///            event.
	@discardableResult
	public static func <~
		<Source: BindingSource>
		(provider: Self, source: Source) -> Disposable?
		where Source.Value == Value
	{
		return source.producer
			.take(during: provider.bindingTarget.lifetime)
			.startWithValues(provider.bindingTarget.action)
	}

	/// Binds a source to a target, updating the target's value to the latest
	/// value sent by the source.
	///
	/// - note: The binding will automatically terminate when the target is
	///         deinitialized, or when the source sends a `completed` event.
	///
	/// ````
	/// let property = MutableProperty(0)
	/// let signal = Signal({ /* do some work after some time */ })
	/// property <~ signal
	/// ````
	///
	/// ````
	/// let property = MutableProperty(0)
	/// let signal = Signal({ /* do some work after some time */ })
	/// let disposable = property <~ signal
	/// ...
	/// // Terminates binding before property dealloc or signal's
	/// // `completed` event.
	/// disposable.dispose()
	/// ````
	///
	/// - parameters:
	///   - target: A target to be bond to.
	///   - source: A source to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of the target or the source's `completed`
	///            event.
	@discardableResult
	public static func <~
		<Source: BindingSource>
		(provider: Self, source: Source) -> Disposable?
		where Value == Source.Value?
	{
		return provider <~ source.producer.optionalize()
	}
}

extension Signal.Observer {
	/// Binds a source to a target, updating the target's value to the latest
	/// value sent by the source.
	///
	/// - note: Only `value` events will be forwarded to the Observer.
	///         The binding will automatically terminate when the target is
	///         deinitialized, or when the source sends a `completed` event.
	///
	/// - parameters:
	///   - target: A target to be bond to.
	///   - source: A source to bind.
	///
	/// - returns: A disposable that can be used to terminate binding before the
	///            deinitialization of the target or the source's `completed`
	///            event.
	@discardableResult
	public static func <~
		<Source: BindingSource>
		(observer: Signal<Value, Error>.Observer, source: Source) -> Disposable
		where Source.Value == Value
	{
		return source.producer.startWithValues { [weak observer] in
			observer?.send(value: $0)
		}
	}
}

/// A binding target that can be used with the `<~` operator.
public struct BindingTarget<Value>: BindingTargetProvider {
	public let lifetime: Lifetime
	public let action: (Value) -> Void

	public var bindingTarget: BindingTarget<Value> {
		return self
	}

	/// Creates a binding target which consumes values on the specified scheduler.
	///
	/// If no scheduler is specified, the binding target would consume the value
	/// immediately.
	///
	/// - parameters:
	///   - scheduler: The scheduler on which the `action` consumes the values.
	///   - lifetime: The expected lifetime of any bindings towards `self`.
	///   - action: The action to consume values.
	public init(on scheduler: Scheduler = ImmediateScheduler(), lifetime: Lifetime, action: @escaping (Value) -> Void) {
		self.lifetime = lifetime

		if scheduler is ImmediateScheduler {
			self.action = action
		} else {
			self.action = { value in
				scheduler.schedule {
					action(value)
				}
			}
		}
	}

	/// Creates a binding target which consumes values on the specified scheduler.
	///
	/// If no scheduler is specified, the binding target would consume the value
	/// immediately.
	///
	/// - parameters:
	///   - scheduler: The scheduler on which the key path consumes the values.
	///   - lifetime: The expected lifetime of any bindings towards `self`.
	///   - object: The object to consume values.
	///   - keyPath: The key path of the object that consumes values.
	public init<Object: AnyObject>(on scheduler: Scheduler = ImmediateScheduler(), lifetime: Lifetime, object: Object, keyPath: WritableKeyPath<Object, Value>) {
		self.init(on: scheduler, lifetime: lifetime) { [weak object] in object?[keyPath: keyPath] = $0 }
	}
}

extension Optional: BindingTargetProvider where Wrapped: BindingTargetProvider {
	public typealias Value = Wrapped.Value

	public var bindingTarget: BindingTarget<Wrapped.Value> {
		switch self {
		case let .some(provider):
			return provider.bindingTarget
		case .none:
			return BindingTarget(lifetime: .empty, action: { _ in })
		}
	}
}
