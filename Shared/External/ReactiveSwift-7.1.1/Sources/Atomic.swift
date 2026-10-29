//
//  Atomic.swift
//  ReactiveSwift
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import os
import MachO
#endif

/// A simple, generic lock-free finite state machine.
///
/// - warning: `deinitialize` must be called to dispose of the consumed memory.
internal struct UnsafeAtomicState<State: RawRepresentable> where State.RawValue == Int32 {
	internal typealias Transition = (expected: State, next: State)
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
	private let value: UnsafeMutablePointer<Int32>

	/// Create a finite state machine with the specified initial state.
	///
	/// - parameters:
	///   - initial: The desired initial state.
	internal init(_ initial: State) {
		value = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
		value.initialize(to: initial.rawValue)
	}

	/// Deinitialize the finite state machine.
	internal func deinitialize() {
		value.deinitialize(count: 1)
		value.deallocate()
	}

	/// Compare the current state with the specified state.
	///
	/// - parameters:
	///   - expected: The expected state.
	///
	/// - returns: `true` if the current state matches the expected state.
	///            `false` otherwise.
	internal func `is`(_ expected: State) -> Bool {
		return expected.rawValue == value.pointee
	}

	/// Try to transition from the expected current state to the specified next
	/// state.
	///
	/// - parameters:
	///   - expected: The expected state.
	///   - next: The state to transition to.
	///
	/// - returns: `true` if the transition succeeds. `false` otherwise.
	internal func tryTransition(from expected: State, to next: State) -> Bool {
		return OSAtomicCompareAndSwap32Barrier(expected.rawValue,
											   next.rawValue,
											   value)
	}
#else
	private let value: Atomic<Int32>

	/// Create a finite state machine with the specified initial state.
	///
	/// - parameters:
	///   - initial: The desired initial state.
	internal init(_ initial: State) {
		value = Atomic(initial.rawValue)
	}

	/// Deinitialize the finite state machine.
	internal func deinitialize() {}

	/// Compare the current state with the specified state.
	///
	/// - parameters:
	///   - expected: The expected state.
	///
	/// - returns: `true` if the current state matches the expected state.
	///            `false` otherwise.
	internal func `is`(_ expected: State) -> Bool {
		return value.value == expected.rawValue
	}

	/// Try to transition from the expected current state to the specified next
	/// state.
	///
	/// - parameters:
	///   - expected: The expected state.
	///
	/// - returns: `true` if the transition succeeds. `false` otherwise.
	internal func tryTransition(from expected: State, to next: State) -> Bool {
		return value.modify { value in
			if value == expected.rawValue {
				value = next.rawValue
				return true
			}
			return false
		}
	}
#endif
}

/// `Lock` exposes `os_unfair_lock` or `OSAllocatedUnfairLock`
/// on supported platforms, with pthread mutex as the
/// fallback.
internal class Lock: LockProtocol {
	#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
	internal final class UnfairLock: Lock {
		private let _lock: os_unfair_lock_t

		override init() {
			_lock = .allocate(capacity: 1)
			_lock.initialize(to: os_unfair_lock())
			super.init()
		}

		override func lock() {
			os_unfair_lock_lock(_lock)
		}

		override func unlock() {
			os_unfair_lock_unlock(_lock)
		}

		override func `try`() -> Bool {
			return os_unfair_lock_trylock(_lock)
		}

		deinit {
			_lock.deinitialize(count: 1)
			_lock.deallocate()
		}
	}
	#endif

	#if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
		#if swift(>=5.7)
		@available(iOS 16.0, *)
		@available(macOS 13.0, *)
		@available(tvOS 16.0, *)
		@available(watchOS 9.0, *)
		internal final class AllocatedUnfairLock: Lock {
			private let _lock = OSAllocatedUnfairLock()

			override init() {
				super.init()
			}

			override func lock() {
				_lock.lock()
			}

			override func unlock() {
				_lock.unlock()
			}

			override func `try`() -> Bool {
				_lock.lockIfAvailable()
			}
		}
		#endif
	#endif

	internal final class PthreadLock: Lock {
		private let _lock: UnsafeMutablePointer<pthread_mutex_t>

		init(recursive: Bool = false) {
			_lock = .allocate(capacity: 1)
			_lock.initialize(to: pthread_mutex_t())

			let attr = UnsafeMutablePointer<pthread_mutexattr_t>.allocate(capacity: 1)
			attr.initialize(to: pthread_mutexattr_t())
			pthread_mutexattr_init(attr)

			defer {
				pthread_mutexattr_destroy(attr)
				attr.deinitialize(count: 1)
				attr.deallocate()
			}

			pthread_mutexattr_settype(attr, Int32(recursive ? PTHREAD_MUTEX_RECURSIVE : PTHREAD_MUTEX_ERRORCHECK))

			let status = pthread_mutex_init(_lock, attr)
			assert(status == 0, "Unexpected pthread mutex error code: \(status)")

			super.init()
		}

		override func lock() {
			let status = pthread_mutex_lock(_lock)
			assert(status == 0, "Unexpected pthread mutex error code: \(status)")
		}

		override func unlock() {
			let status = pthread_mutex_unlock(_lock)
			assert(status == 0, "Unexpected pthread mutex error code: \(status)")
		}

		override func `try`() -> Bool {
			let status = pthread_mutex_trylock(_lock)
			switch status {
			case 0:
				return true
			case EBUSY, EAGAIN, EDEADLK:
				return false
			default:
				assertionFailure("Unexpected pthread mutex error code: \(status)")
				return false
			}
		}

		deinit {
			let status = pthread_mutex_destroy(_lock)
			assert(status == 0, "Unexpected pthread mutex error code: \(status)")

			_lock.deinitialize(count: 1)
			_lock.deallocate()
		}
	}

	static func make() -> Self {
		#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
			#if swift(>=5.7)
			guard #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) else {
				return UnfairLock() as! Self
			}

			return AllocatedUnfairLock() as! Self
			#else
				return UnfairLock() as! Self
			#endif
		#else
			return PthreadLock() as! Self
		#endif
	}

	private init() {}

	func lock() { fatalError() }
	func unlock() { fatalError() }
	func `try`() -> Bool { fatalError() }
}

internal protocol LockProtocol {
	static func make() -> Self

	func lock()
	func unlock()
	func `try`() -> Bool
}

internal struct NoLock: LockProtocol {
	static func make() -> NoLock { NoLock() }

	func lock() {}
	func unlock() {}
	func `try`() -> Bool { true }
}

/// An atomic variable.
public final class Atomic<Value> {
	private let lock: Lock
	private var _value: Value

	/// Atomically get or set the value of the variable.
	public var value: Value {
		get {
			return withValue { $0 }
		}

		set(newValue) {
			swap(newValue)
		}
	}

	/// Initialize the variable with the given initial value.
	///
	/// - parameters:
	///   - value: Initial value for `self`.
	public init(_ value: Value) {
		_value = value
		lock = Lock.make()
	}

	/// Atomically modifies the variable.
	///
	/// - parameters:
	///   - action: A closure that takes the current value.
	///
	/// - returns: The result of the action.
	@discardableResult
	public func modify<Result>(_ action: (inout Value) throws -> Result) rethrows -> Result {
		lock.lock()
		defer { lock.unlock() }

		return try action(&_value)
	}

	/// Atomically perform an arbitrary action using the current value of the
	/// variable.
	///
	/// - parameters:
	///   - action: A closure that takes the current value.
	///
	/// - returns: The result of the action.
	@discardableResult
	public func withValue<Result>(_ action: (Value) throws -> Result) rethrows -> Result {
		lock.lock()
		defer { lock.unlock() }

		return try action(_value)
	}

	/// Atomically replace the contents of the variable.
	///
	/// - parameters:
	///   - newValue: A new value for the variable.
	///
	/// - returns: The old value.
	@discardableResult
	public func swap(_ newValue: Value) -> Value {
		return modify { (value: inout Value) in
			let oldValue = value
			value = newValue
			return oldValue
		}
	}
}
