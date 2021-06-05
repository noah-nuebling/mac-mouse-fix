/// A mutable property that validates mutations before committing them.
///
/// If the property wraps an arbitrary mutable property, changes originated from
/// the inner property are monitored, and would be automatically validated.
/// Note that these would still appear as committed values even if they fail the
/// validation.
///
/// ```
/// let root = MutableProperty("Valid")
/// let outer = ValidatingProperty(root) {
///   $0 == "Valid" ? .valid : .invalid(.outerInvalid)
/// }
///
/// outer.result.value        // `.valid("Valid")
///
/// root.value = "🎃"
/// outer.result.value        // `.invalid("🎃", .outerInvalid)`
/// ```
public final class ValidatingProperty<Value, ValidationError: Swift.Error>: MutablePropertyProtocol {
	private let getter: () -> Value
	private let setter: (Value) -> Void

	/// The result of the last attempted edit of the root property.
	public let result: Property<Result>

	/// The current value of the property.
	///
	/// The value could have failed the validation. Refer to `result` for the
	/// latest validation result.
	public var value: Value {
		get { return getter() }
		set { setter(newValue) }
	}

	/// A producer for Signals that will send the property's current value,
	/// followed by all changes over time, then complete when the property has
	/// deinitialized.
	public let producer: SignalProducer<Value, Never>

	/// A signal that will send the property's changes over time,
	/// then complete when the property has deinitialized.
	public let signal: Signal<Value, Never>

	/// The lifetime of the property.
	public let lifetime: Lifetime

	/// Create a `ValidatingProperty` that presents a mutable validating
	/// view for an inner mutable property.
	///
	/// The proposed value is only committed when `valid` is returned by the
	/// `validator` closure.
	///
	/// - note: `inner` is retained by the created property.
	///
	/// - parameters:
	///   - inner: The inner property which validated values are committed to.
	///   - validator: The closure to invoke for any proposed value to `self`.
	public init<Inner: ComposableMutablePropertyProtocol>(
		_ inner: Inner,
		_ validator: @escaping (Value) -> Decision
	) where Inner.Value == Value {
		getter = { inner.value }
		producer = inner.producer
		signal = inner.signal
		lifetime = inner.lifetime

		// This flag temporarily suspends the monitoring on the inner property for
		// writebacks that are triggered by successful validations.
		var isSettingInnerValue = false

		(result, setter) = inner.withValue { initial in
			let mutableResult = MutableProperty(Result(initial, validator(initial)))

			mutableResult <~ inner.signal
				.filter { _ in !isSettingInnerValue }
				.map { Result($0, validator($0)) }

			return (Property(capturing: mutableResult), { input in
				// Acquire the lock of `inner` to ensure no modification happens until
				// the validation logic here completes.
				inner.withValue { _ in
					let writebackValue: Value? = mutableResult.modify { result in
						result = Result(input, validator(input))
						return result.value
					}

					if let value = writebackValue {
						isSettingInnerValue = true
						inner.value = value
						isSettingInnerValue = false
					}
				}
			})
		}
	}

	/// Create a `ValidatingProperty` that validates mutations before
	/// committing them.
	///
	/// The proposed value is only committed when `valid` is returned by the
	/// `validator` closure.
	///
	/// - parameters:
	///   - initial: The initial value of the property. It is not required to
	///              pass the validation as specified by `validator`.
	///   - validator: The closure to invoke for any proposed value to `self`.
	public convenience init(
		_ initial: Value,
		_ validator: @escaping (Value) -> Decision
	) {
		self.init(MutableProperty(initial), validator)
	}

	/// Create a `ValidatingProperty` that presents a mutable validating
	/// view for an inner mutable property.
	///
	/// The proposed value is only committed when `valid` is returned by the
	/// `validator` closure.
	///
	/// - note: `inner` is retained by the created property.
	///
	/// - parameters:
	///   - inner: The inner property which validated values are committed to.
	///   - other: The property that `validator` depends on.
	///   - validator: The closure to invoke for any proposed value to `self`.
	public convenience init<Other: PropertyProtocol>(
		_ inner: MutableProperty<Value>,
		with other: Other,
		_ validator: @escaping (Value, Other.Value) -> Decision
	) {
		// Capture a copy that reflects `other` without influencing the lifetime of
		// `other`.
		let other = Property(other)

		self.init(inner) { input in
			return validator(input, other.value)
		}

		// When `other` pushes out a new value, the resulting property would react 
		// by revalidating itself with its last attempted value, regardless of
		// success or failure.
		other.signal
			.take(during: lifetime)
			.observeValues { [weak self] _ in
				guard let s = self else { return }

				switch s.result.value {
				case let .invalid(value, _):
					s.value = value

				case let .coerced(_, value, _):
					s.value = value

				case let .valid(value):
					s.value = value
				}
		}
	}

	/// Create a `ValidatingProperty` that validates mutations before
	/// committing them.
	///
	/// The proposed value is only committed when `valid` is returned by the
	/// `validator` closure.
	///
	/// - parameters:
	///   - initial: The initial value of the property. It is not required to
	///              pass the validation as specified by `validator`.
	///   - other: The property that `validator` depends on.
	///   - validator: The closure to invoke for any proposed value to `self`.
	public convenience init<Other: PropertyProtocol>(
		_ initial: Value,
		with other: Other,
		_ validator: @escaping (Value, Other.Value) -> Decision
	) {
		self.init(MutableProperty(initial), with: other, validator)
	}
	
	/// Create a `ValidatingProperty` which validates mutations before
	/// committing them.
	///
	/// The proposed value is only committed when `valid` is returned by the
	/// `validator` closure.
	///
	/// - note: `inner` is retained by the created property.
	///
	/// - parameters:
	///   - initial: The initial value of the property. It is not required to
	///              pass the validation as specified by `validator`.
	///   - other: The property that `validator` depends on.
	///   - validator: The closure to invoke for any proposed value to `self`.
	public convenience init<U, E>(
		_ initial: Value,
		with other: ValidatingProperty<U, E>,
		_ validator: @escaping (Value, U) -> Decision
	) {
		self.init(MutableProperty(initial), with: other, validator)
	}

	/// Create a `ValidatingProperty` that presents a mutable validating
	/// view for an inner mutable property.
	///
	/// The proposed value is only committed when `valid` is returned by the
	/// `validator` closure.
	///
	/// - parameters:
	///   - inner: The inner property which validated values are committed to.
	///   - other: The property that `validator` depends on.
	///   - validator: The closure to invoke for any proposed value to `self`.
	public convenience init<U, E>(
		_ inner: MutableProperty<Value>,
		with other: ValidatingProperty<U, E>,
		_ validator: @escaping (Value, U) -> Decision
	) {
		// Capture only `other.result` but not `other`.
		let otherValidations = other.result

		self.init(inner) { input in
			let otherValue: U

			switch otherValidations.value {
			case let .valid(value):
				otherValue = value

			case let .coerced(_, value, _):
				otherValue = value

			case let .invalid(value, _):
				otherValue = value
			}

			return validator(input, otherValue)
		}

		// When `other` pushes out a new validation result, the resulting property
		// would react by revalidating itself with its last attempted value,
		// regardless of success or failure.
		otherValidations.signal
			.take(during: lifetime)
			.observeValues { [weak self] _ in
				guard let s = self else { return }

				switch s.result.value {
				case let .invalid(value, _):
					s.value = value

				case let .coerced(_, value, _):
					s.value = value

				case let .valid(value):
					s.value = value
				}
			}
	}

	/// Represents a decision of a validator of a validating property made on a
	/// proposed value.
	public enum Decision {
		/// The proposed value is valid.
		case valid

		/// The proposed value is invalid, but the validator coerces it into a
		/// replacement which it deems valid.
		case coerced(Value, ValidationError?)

		/// The proposed value is invalid.
		case invalid(ValidationError)
	}

	/// Represents the result of the validation performed by a validating property.
	public enum Result {
		/// The proposed value is valid.
		case valid(Value)

		/// The proposed value is invalid, but the validator was able to coerce it
		/// into a replacement which it deemed valid.
		case coerced(replacement: Value, proposed: Value, error: ValidationError?)

		/// The proposed value is invalid.
		case invalid(Value, ValidationError)

		/// Whether the value is invalid.
		public var isInvalid: Bool {
			if case .invalid = self {
				return true
			} else {
				return false
			}
		}

		/// Extract the valid value, or `nil` if the value is invalid.
		public var value: Value? {
			switch self {
			case let .valid(value):
				return value
			case let .coerced(value, _, _):
				return value
			case .invalid:
				return nil
			}
		}

		/// Extract the error if the value is invalid.
		public var error: ValidationError? {
			if case let .invalid(_, error) = self {
				return error
			} else {
				return nil
			}
		}

		fileprivate init(_ value: Value, _ decision: Decision) {
			switch decision {
			case .valid:
				self = .valid(value)

			case let .coerced(replacement, error):
				self = .coerced(replacement: replacement, proposed: value, error: error)

			case let .invalid(error):
				self = .invalid(value, error)
			}
		}
	}
}
