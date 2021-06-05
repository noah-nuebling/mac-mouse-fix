//
//  FoundationExtensions.swift
//  ReactiveSwift
//
//  Created by Justin Spahr-Summers on 2014-10-19.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import Dispatch

#if os(Linux)
	import let CDispatch.NSEC_PER_USEC
	import let CDispatch.NSEC_PER_SEC
#endif

extension NotificationCenter: ReactiveExtensionsProvider {}

extension Reactive where Base: NotificationCenter {
	/// Returns a Signal to observe posting of the specified notification.
	///
	/// - parameters:
	///   - name: name of the notification to observe
	///   - object: an instance which sends the notifications
	///
	/// - returns: A Signal of notifications posted that match the given criteria.
	///
	/// - note: The signal does not terminate naturally. Observers must be
	///         explicitly disposed to avoid leaks.
	public func notifications(forName name: Notification.Name?, object: AnyObject? = nil) -> Signal<Notification, Never> {
		return Signal { [base = self.base] observer, lifetime in
			let notificationObserver = base.addObserver(forName: name, object: object, queue: nil) { notification in
				observer.send(value: notification)
			}

			lifetime.observeEnded {
				base.removeObserver(notificationObserver)
			}
		}
	}
}

private let defaultSessionError = NSError(domain: "org.reactivecocoa.ReactiveSwift.Reactivity.URLSession.dataWithRequest",
                                          code: 1,
                                          userInfo: nil)

extension URLSession: ReactiveExtensionsProvider {}

extension Reactive where Base: URLSession {
	/// Returns a SignalProducer which performs the work associated with an
	/// `NSURLSession`
	///
	/// - parameters:
	///   - request: A request that will be performed when the producer is
	///              started
	///
	/// - returns: A producer that will execute the given request once for each
	///            invocation of `start()`.
	///
	/// - note: This method will not send an error event in the case of a server
	///         side error (i.e. when a response with status code other than
	///         200...299 is received).
	public func data(with request: URLRequest) -> SignalProducer<(Data, URLResponse), Error> {
		return SignalProducer { [base = self.base] observer, lifetime in
			let task = base.dataTask(with: request) { data, response, error in
				if let data = data, let response = response {
					observer.send(value: (data, response))
					observer.sendCompleted()
				} else {
					observer.send(error: error ?? defaultSessionError)
				}
			}

			lifetime.observeEnded(task.cancel)
			task.resume()
		}
	}
}

extension Date {
	internal func addingTimeInterval(_ interval: DispatchTimeInterval) -> Date {
		return addingTimeInterval(interval.timeInterval)
	}
}

extension DispatchTimeInterval {
	internal var timeInterval: TimeInterval {
		switch self {
		case let .seconds(s):
			return TimeInterval(s)
		case let .milliseconds(ms):
			return TimeInterval(TimeInterval(ms) / 1000.0)
		case let .microseconds(us):
			return TimeInterval(Int64(us)) * TimeInterval(NSEC_PER_USEC) / TimeInterval(NSEC_PER_SEC)
		case let .nanoseconds(ns):
			return TimeInterval(ns) / TimeInterval(NSEC_PER_SEC)
		case .never:
			return .infinity
		@unknown default:
			return .infinity
		}
	}

	// This was added purely so that our test scheduler to "go backwards" in
	// time. See `TestScheduler.rewind(by interval: DispatchTimeInterval)`.
	internal static prefix func -(lhs: DispatchTimeInterval) -> DispatchTimeInterval {
		switch lhs {
		case let .seconds(s):
			return .seconds(-s)
		case let .milliseconds(ms):
			return .milliseconds(-ms)
		case let .microseconds(us):
			return .microseconds(-us)
		case let .nanoseconds(ns):
			return .nanoseconds(-ns)
		case .never:
			return .never
		@unknown default:
			return .never
		}
	}

	/// Scales a time interval by the given scalar specified in `rhs`.
	///
	/// - returns: Scaled interval in minimal appropriate unit
	internal static func *(lhs: DispatchTimeInterval, rhs: Double) -> DispatchTimeInterval {
		let seconds = lhs.timeInterval * rhs
		var result: DispatchTimeInterval = .never
		if let integerTimeInterval = Int(exactly: (seconds * 1000 * 1000 * 1000).rounded()) {
			result = .nanoseconds(integerTimeInterval)
		} else if let integerTimeInterval = Int(exactly: (seconds * 1000 * 1000).rounded()) {
			result = .microseconds(integerTimeInterval)
		} else if let integerTimeInterval = Int(exactly: (seconds * 1000).rounded()) {
			result = .milliseconds(integerTimeInterval)
		} else if let integerTimeInterval = Int(exactly: (seconds).rounded()) {
			result = .seconds(integerTimeInterval)
		}
		return result
	}
}
