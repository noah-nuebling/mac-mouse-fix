import Foundation
import UIKit
import ReactiveSwift

// These extensions mimics the ReactiveCocoa API, but not in a complete way.
//
// For production use, check the ReactiveCocoa framework:
// https://github.com/ReactiveCocoa/ReactiveCocoa/

private let lifetimeKey = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
private let pressedKey = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)

public final class CocoaTarget {
	let _execute: (Any) -> Void

	init(_ body: @escaping (Any) -> Void) {
		_execute = body
	}

	@objc func execute(_ sender: Any) {
		_execute(sender)
	}
}

public final class CocoaAction {
	let _execute: () -> Void
	let isEnabled: Property<Bool>

	public init<Output, Error: Swift.Error>(_ action: Action<(), Output, Error>) {
		_execute = { action.apply().start() }
		isEnabled = action.isEnabled
	}

	@objc func execute(_ sender: Any) {
		_execute()
	}
}

extension NSObject: ReactiveExtensionsProvider {}

extension Reactive where Base: NSObject {
	public var lifetime: Lifetime {
		if let (lifetime, _) = objc_getAssociatedObject(base, lifetimeKey) as! (Lifetime, Lifetime.Token)? {
			return lifetime
		}

		let token = Lifetime.Token()
		let lifetime = Lifetime(token)
		objc_setAssociatedObject(base, lifetimeKey, (lifetime, token), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

		return lifetime
	}
}

extension Reactive where Base: UILabel {
	public var text: BindingTarget<String?> {
		return BindingTarget(lifetime: lifetime) { [weak base] value in
			base?.text = value
		}
	}
}

extension Reactive where Base: UISwitch {
	public var isOnValues: Signal<Bool, Never> {
		return Signal { observer, lifetime in
			let target = CocoaTarget { observer.send(value: ($0 as! UISwitch).isOn) }
			base.addTarget(target, action: #selector(target.execute), for: .valueChanged)
			lifetime.observeEnded { _ = target }
		}
	}
}

extension Reactive where Base: UITextField {
	public var continuousTextValues: Signal<String?, Never> {
		return Signal { observer, lifetime in
			let target = CocoaTarget { observer.send(value: ($0 as! UITextField).text) }
			base.addTarget(target, action: #selector(target.execute), for: .editingChanged)
			lifetime.observeEnded { _ = target }
		}
	}
}

extension Reactive where Base: UIControl {
	public var isEnabled: BindingTarget<Bool> {
		return BindingTarget(lifetime: lifetime) { [weak base] value in
			base?.isEnabled = value
		}
	}
}

extension Reactive where Base: UIButton {
	public var pressed: CocoaAction? {
		get {
			if let (action, _) = objc_getAssociatedObject(base, pressedKey) as! (CocoaAction?, SerialDisposable)? {
				return action
			}
			return nil
		}

		nonmutating set {
			let disposable: SerialDisposable = {
				if let (_, disposable) = objc_getAssociatedObject(base, pressedKey) as! (CocoaAction?, SerialDisposable)? {
					return disposable
				}

				let d = SerialDisposable()
				objc_setAssociatedObject(base, pressedKey, (nil, d) as (CocoaAction?, SerialDisposable), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
				return d
			}()

			if let newAction = newValue {
				base.addTarget(newAction, action: #selector(newAction.execute), for: .touchUpInside)
				let d = CompositeDisposable()
				d += isEnabled <~ newAction.isEnabled.producer
				d += { _ = newAction }
				disposable.inner = d
			} else {
				disposable.inner = nil
			}
		}
	}
}
