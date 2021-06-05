//
//  Observer.swift
//  ReactiveSwift
//
//  Created by Andy Matuschak on 10/2/15.
//  Copyright © 2015 GitHub. All rights reserved.
//

extension Signal {
	/// An Observer is a simple wrapper around a function which can receive Events
	/// (typically from a Signal).
	public final class Observer: ReactiveSwift.Observer<Value, Error> {
		public typealias Action = (Event) -> Void
		private let _send: Action

		/// Whether the observer should send an `interrupted` event as it deinitializes.
		private let interruptsOnDeinit: Bool

		/// An initializer that accepts a closure accepting an event for the
		/// observer.
		///
		/// - parameters:
		///   - action: A closure to lift over received event.
		///   - interruptsOnDeinit: `true` if the observer should send an `interrupted`
		///                         event as it deinitializes. `false` otherwise.
		internal init(action: @escaping Action, interruptsOnDeinit: Bool) {
			self._send = action
			self.interruptsOnDeinit = interruptsOnDeinit
		}

		/// An initializer that accepts a closure accepting an event for the 
		/// observer.
		///
		/// - parameters:
		///   - action: A closure to lift over received event.
		public init(_ action: @escaping Action) {
			self._send = action
			self.interruptsOnDeinit = false
		}

		/// An initializer that accepts closures for different event types.
		///
		/// - parameters:
		///   - value: Optional closure executed when a `value` event is observed.
		///   - failed: Optional closure that accepts an `Error` parameter when a
		///             failed event is observed.
		///   - completed: Optional closure executed when a `completed` event is
		///                observed.
		///   - interruped: Optional closure executed when an `interrupted` event is
		///                 observed.
		public convenience init(
			value: ((Value) -> Void)? = nil,
			failed: ((Error) -> Void)? = nil,
			completed: (() -> Void)? = nil,
			interrupted: (() -> Void)? = nil
		) {
			self.init { event in
				switch event {
				case let .value(v):
					value?(v)

				case let .failed(error):
					failed?(error)

				case .completed:
					completed?()

				case .interrupted:
					interrupted?()
				}
			}
		}

		internal convenience init(mappingInterruptedToCompleted observer: Signal<Value, Error>.Observer) {
			self.init { event in
				switch event {
				case .value, .completed, .failed:
					observer.send(event)
				case .interrupted:
					observer.sendCompleted()
				}
			}
		}

		deinit {
			if interruptsOnDeinit {
				// Since `Signal` would ensure that only one terminal event would ever be
				// sent for any given `Signal`, we do not need to assert any condition
				// here.
				_send(.interrupted)
			}
		}

		public override func receive(_ value: Value) {
			send(value: value)
		}

		public override func terminate(_ termination: Termination<Error>) {
			switch termination {
			case let .failed(error):
				send(error: error)
			case .completed:
				sendCompleted()
			case .interrupted:
				sendInterrupted()
			}
		}

		/// Puts an event into `self`.
		public func send(_ event: Event) {
			_send(event)
		}

		/// Puts a `value` event into `self`.
		///
		/// - parameters:
		///   - value: A value sent with the `value` event.
		public func send(value: Value) {
			_send(.value(value))
		}

		/// Puts a failed event into `self`.
		///
		/// - parameters:
		///   - error: An error object sent with failed event.
		public func send(error: Error) {
			_send(.failed(error))
		}

		/// Puts a `completed` event into `self`.
		public func sendCompleted() {
			_send(.completed)
		}

		/// Puts an `interrupted` event into `self`.
		public func sendInterrupted() {
			_send(.interrupted)
		}
	}
}

/// FIXME: Cannot be placed in `Deprecations+Removal.swift` if compiling with
///        Xcode 9.2.
extension Signal.Observer {
	/// An action that will be performed upon arrival of the event.
	@available(*, unavailable, renamed:"send(_:)")
	public var action: Action { fatalError() }
}
