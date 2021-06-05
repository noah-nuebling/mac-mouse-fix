/// Describes a provider of reactive extensions.
///
/// - note: `ReactiveExtensionsProvider` does not indicate whether a type is
///         reactive. It is intended for extensions to types that are not owned
///         by the module in order to avoid name collisions and return type
///         ambiguities.
public protocol ReactiveExtensionsProvider {}

extension ReactiveExtensionsProvider {
	/// A proxy which hosts reactive extensions for `self`.
	public var reactive: Reactive<Self> {
		return Reactive(self)
	}

	/// A proxy which hosts static reactive extensions for the type of `self`.
	public static var reactive: Reactive<Self>.Type {
		return Reactive<Self>.self
	}
}

/// A proxy which hosts reactive extensions of `Base`.
public struct Reactive<Base> {
	/// The `Base` instance the extensions would be invoked with.
	public let base: Base

	/// Construct a proxy
	///
	/// - parameters:
	///   - base: The object to be proxied.
	fileprivate init(_ base: Base) {
		self.base = base
	}
}
