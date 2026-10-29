import Foundation
import Dispatch

// MARK: Unavailable methods in ReactiveSwift 3.0.
extension Signal {
	@available(*, unavailable, message:"Use the `Signal.init` that accepts a two-argument generator.")
	public convenience init(_ generator: (Observer) -> Disposable?) { fatalError() }
}

extension Lifetime {
	@discardableResult
	@available(*, unavailable, message:"Use `observeEnded(_:)` with a method reference to `dispose()` instead.")
	public func add(_ d: Disposable?) -> Disposable? { fatalError() }
}

// MARK: Deprecated types
