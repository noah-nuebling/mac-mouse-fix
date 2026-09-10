//
//  EventLogger.swift
//  ReactiveSwift
//
//  Created by Rui Peres on 30/04/2016.
//  Copyright © 2016 GitHub. All rights reserved.
//

import Foundation

/// A namespace for logging event types.
public enum LoggingEvent {
	public enum Signal: String, CaseIterable {
		case value, completed, failed, terminated, disposed, interrupted

		@available(*, deprecated, message:"Use `allCases` instead.")
		public static var allEvents: Set<Signal> { Set(allCases) }
	}

	public enum SignalProducer: String, CaseIterable {
		case starting, started, value, completed, failed, terminated, disposed, interrupted

		@available(*, deprecated, message:"Use `allCases` instead.")
		public static var allEvents: Set<SignalProducer> { Set(allCases) }
	}
}

public func defaultEventLog(identifier: String, event: String, fileName: String, functionName: String, lineNumber: Int) {
	print("[\(identifier)] \(event) fileName: \(fileName), functionName: \(functionName), lineNumber: \(lineNumber)")
}

/// A type that represents an event logging function.
/// Signature is:
///		- identifier 
///		- event
///		- fileName
///		- functionName
///		- lineNumber
public typealias EventLogger = (
	_ identifier: String,
	_ event: String,
	_ fileName: String,
	_ functionName: String,
	_ lineNumber: Int
) -> Void

// See https://bugs.swift.org/browse/SR-6796.
fileprivate struct LogContext<Event: LoggingEventProtocol> {
	let events: Set<Event>
	let identifier: String
	let fileName: String
	let functionName: String
	let lineNumber: Int
	let logger: EventLogger
	
	func log<T>(_ event: Event) -> ((T) -> Void)? {
		return event.logIfNeeded(events: self.events) { event in
			self.logger(self.identifier, event, self.fileName, self.functionName, self.lineNumber)
		}
	}
	
	func log(_ event: Event) -> (() -> Void)? {
		return event.logIfNeededNoArg(events: self.events) { event in
			self.logger(self.identifier, event, self.fileName, self.functionName, self.lineNumber)
		}
	}
}

extension Signal {
	/// Logs all events that the receiver sends. By default, it will print to 
	/// the standard output.
	///
	/// - parameters:
	///   - identifier: a string to identify the Signal firing events.
	///   - events: Types of events to log.
	///   - fileName: Name of the file containing the code which fired the
	///               event.
	///   - functionName: Function where event was fired.
	///   - lineNumber: Line number where event was fired.
	///   - logger: Logger that logs the events.
	///
	/// - returns: Signal that, when observed, logs the fired events.
	public func logEvents(identifier: String = "", events: Set<LoggingEvent.Signal> = Set(LoggingEvent.Signal.allCases), fileName: String = #file, functionName: String = #function, lineNumber: Int = #line, logger: @escaping EventLogger = defaultEventLog) -> Signal<Value, Error> {
		let logContext = LogContext(events: events,
		                            identifier: identifier,
		                            fileName: fileName,
		                            functionName: functionName,
		                            lineNumber: lineNumber,
		                            logger: logger)
		
		return self.on(
			failed: logContext.log(.failed),
			completed: logContext.log(.completed),
			interrupted: logContext.log(.interrupted),
			terminated: logContext.log(.terminated),
			disposed: logContext.log(.disposed),
			value: logContext.log(.value)
		)
	}
}

extension SignalProducer {
	/// Logs all events that the receiver sends. By default, it will print to 
	/// the standard output.
	///
	/// - parameters:
	///   - identifier: a string to identify the SignalProducer firing events.
	///   - events: Types of events to log.
	///   - fileName: Name of the file containing the code which fired the
	///               event.
	///   - functionName: Function where event was fired.
	///   - lineNumber: Line number where event was fired.
	///   - logger: Logger that logs the events.
	///
	/// - returns: Signal producer that, when started, logs the fired events.
	public func logEvents(identifier: String = "",
	                      events: Set<LoggingEvent.SignalProducer> = Set(LoggingEvent.SignalProducer.allCases),
	                      fileName: String = #file,
	                      functionName: String = #function,
	                      lineNumber: Int = #line,
	                      logger: @escaping EventLogger = defaultEventLog
	) -> SignalProducer<Value, Error> {
		let logContext = LogContext(events: events,
		                            identifier: identifier,
		                            fileName: fileName,
		                            functionName: functionName,
		                            lineNumber: lineNumber,
		                            logger: logger)

		return self.on(
			starting: logContext.log(.starting),
			started: logContext.log(.started),
			failed: logContext.log(.failed),
			completed: logContext.log(.completed),
			interrupted: logContext.log(.interrupted),
			terminated: logContext.log(.terminated),
			disposed: logContext.log(.disposed),
			value: logContext.log(.value)
		)
	}
}

private protocol LoggingEventProtocol: Hashable, RawRepresentable {}
extension LoggingEvent.Signal: LoggingEventProtocol {}
extension LoggingEvent.SignalProducer: LoggingEventProtocol {}

private extension LoggingEventProtocol {
	// FIXME: See https://bugs.swift.org/browse/SR-6796 and the discussion in https://github.com/apple/swift/pull/14477.
	//        Due to differences in the type checker, this method cannot
	//        overload the generic `logIfNeeded`, or otherwise it would lead to
	//        infinite recursion with Swift 4.0.x.
	func logIfNeededNoArg(events: Set<Self>, logger: @escaping (String) -> Void) -> (() -> Void)? {
		return (self.logIfNeeded(events: events, logger: logger) as ((()) -> Void)?)
			.map { closure in
				{ closure(()) }
			}
	}
	
	func logIfNeeded<T>(events: Set<Self>, logger: @escaping (String) -> Void) -> ((T) -> Void)? {
		guard events.contains(self) else {
			return nil
		}

		return { value in
			if value is Void {
				logger("\(self.rawValue)")
			} else {
				logger("\(self.rawValue) \(value)")
			}
		}
	}
}
