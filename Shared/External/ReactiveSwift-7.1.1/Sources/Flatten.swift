//
//  Flatten.swift
//  ReactiveSwift
//
//  Created by Neil Pankey on 11/30/15.
//  Copyright © 2015 GitHub. All rights reserved.
//

/// Describes how a stream of inner streams should be flattened into a stream of values.
public struct FlattenStrategy {
	fileprivate enum Kind {
		case concurrent(limit: UInt)
		case latest
		case race
		case throttle
	}

	fileprivate let kind: Kind

	private init(kind: Kind) {
		self.kind = kind
	}

	/// The stream of streams is merged, so that any value sent by any of the inner
	/// streams is forwarded immediately to the flattened stream of values.
	///
	/// The flattened stream of values completes only when the stream of streams, and all
	/// the inner streams it sent, have completed.
	///
	/// Any interruption of inner streams is treated as completion, and does not interrupt
	/// the flattened stream of values.
	///
	/// Any failure from the inner streams is propagated immediately to the flattened
	/// stream of values.
	public static let merge = FlattenStrategy(kind: .concurrent(limit: .max))

	/// The stream of streams is concatenated, so that only values from one inner stream
	/// are forwarded at a time, in the order the inner streams are received.
	///
	/// In other words, if an inner stream is received when a previous inner stream has
	/// yet terminated, the received stream would be enqueued.
	///
	/// The flattened stream of values completes only when the stream of streams, and all
	/// the inner streams it sent, have completed.
	///
	/// Any interruption of inner streams is treated as completion, and does not interrupt
	/// the flattened stream of values.
	///
	/// Any failure from the inner streams is propagated immediately to the flattened
	/// stream of values.
	public static let concat = FlattenStrategy(kind: .concurrent(limit: 1))

	/// The stream of streams is merged with the given concurrency cap, so that any value
	/// sent by any of the inner streams on the fly is forwarded immediately to the
	/// flattened stream of values.
	///
	/// In other words, if an inner stream is received when a previous inner stream has
	/// yet terminated, the received stream would be enqueued.
	///
	/// The flattened stream of values completes only when the stream of streams, and all
	/// the inner streams it sent, have completed.
	///
	/// Any interruption of inner streams is treated as completion, and does not interrupt
	/// the flattened stream of values.
	///
	/// Any failure from the inner streams is propagated immediately to the flattened
	/// stream of values.
	///
	/// - precondition: `limit > 0`.
	public static func concurrent(limit: UInt) -> FlattenStrategy {
		return FlattenStrategy(kind: .concurrent(limit: limit))
	}

	/// Forward only values from the latest inner stream sent by the stream of streams.
	/// The active inner stream is disposed of as a new inner stream is received.
	///
	/// The flattened stream of values completes only when the stream of streams, and all
	/// the inner streams it sent, have completed.
	///
	/// Any interruption of inner streams is treated as completion, and does not interrupt
	/// the flattened stream of values.
	///
	/// Any failure from the inner streams is propagated immediately to the flattened
	/// stream of values.
	public static let latest = FlattenStrategy(kind: .latest)

	/// Forward only events from the first inner stream that sends an event. Any other
	/// in-flight inner streams is disposed of when the winning inner stream is
	/// determined.
	///
	/// The flattened stream of values completes only when the stream of streams, and the
	/// winning inner stream, have completed.
	///
	/// Any interruption of inner streams is propagated immediately to the flattened
	/// stream of values.
	///
	/// Any failure from the inner streams is propagated immediately to the flattened
	/// stream of values.
	public static let race = FlattenStrategy(kind: .race)

	/// Given a first inner stream, all subsequent inner streams sent by the upstream would
	/// be dropped until the first inner stream has completed. The whole process repeats
	/// indefinitely until the upstream terminates. The behavior is akin to `throttle(_:on:)`
	/// except for operating in the domain of streams instead of time.
	///
	/// The flattened stream of values completes only when the stream of streams has completed,
	/// and first inner stream has completed if exists.
	///
	/// Any interruption of inner streams is propagated immediately to the flattened
	/// stream of values.
	///
	/// Any failure from the inner streams is propagated immediately to the flattened
	/// stream of values.
	public static let throttle = FlattenStrategy(kind: .throttle)
}

extension Signal where Value: SignalProducerConvertible, Error == Value.Error {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - note: If `signal` or an active inner producer fails, the returned
	///         signal will forward that failure immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Error> {
		switch strategy.kind {
		case .concurrent(let limit):
			return self.concurrent(limit: limit)

		case .latest:
			return self.switchToLatest()

		case .race:
			return self.race()

		case .throttle:
			return self.throttle()
		}
	}
}

extension Signal where Value: SignalProducerConvertible, Error == Never {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - note: If `signal` or an active inner producer fails, the returned
	///         signal will forward that failure immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Value.Error> {
		return self
			.promoteError(Value.Error.self)
			.flatten(strategy)
	}
}

extension Signal where Value: SignalProducerConvertible, Error == Never, Value.Error == Never {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///   - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Value.Error> {
		switch strategy.kind {
		case .concurrent(let limit):
			return self.concurrent(limit: limit)

		case .latest:
			return self.switchToLatest()

		case .race:
			return self.race()

		case .throttle:
			return self.throttle()
		}
	}
}

extension Signal where Value: SignalProducerConvertible, Value.Error == Never {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - note: If `signal` fails, the returned signal will forward that failure
	///         immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///   - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> Signal<Value.Value, Error> {
		return self.flatMap(strategy) { $0.producer.promoteError(Error.self) }
	}
}

extension SignalProducer where Value: SignalProducerConvertible, Error == Value.Error {
	/// Flattens the inner producers sent upon `producer` (into a single
	/// producer of values), according to the semantics of the given strategy.
	///
	/// - note: If `producer` or an active inner producer fails, the returned
	///         producer will forward that failure immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///   - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Error> {
		switch strategy.kind {
		case .concurrent(let limit):
			return self.concurrent(limit: limit)

		case .latest:
			return self.switchToLatest()

		case .race:
			return self.race()

		case .throttle:
			return self.throttle()
		}
	}
}

extension SignalProducer where Value: SignalProducerConvertible, Error == Never {
	/// Flattens the inner producers sent upon `producer` (into a single
	/// producer of values), according to the semantics of the given strategy.
	///
	/// - note: If an active inner producer fails, the returned producer will
	///         forward that failure immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///   - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Value.Error> {
		return self
			.promoteError(Value.Error.self)
			.flatten(strategy)
	}
}

extension SignalProducer where Value: SignalProducerConvertible, Error == Never, Value.Error == Never {
	/// Flattens the inner producers sent upon `producer` (into a single
	/// producer of values), according to the semantics of the given strategy.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///   - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Value.Error> {
		switch strategy.kind {
		case .concurrent(let limit):
			return self.concurrent(limit: limit)

		case .latest:
			return self.switchToLatest()

		case .race:
			return self.race()

		case .throttle:
			return self.throttle()
		}
	}
}

extension SignalProducer where Value: SignalProducerConvertible, Value.Error == Never {
	/// Flattens the inner producers sent upon `signal` (into a single signal of
	/// values), according to the semantics of the given strategy.
	///
	/// - note: If `signal` fails, the returned signal will forward that failure
	///         immediately.
	///
	/// - warning: `interrupted` events on inner producers will be treated like
	///            `completed` events on inner producers.
	///
	/// - parameters:
	///   - strategy: Strategy used when flattening signals.
	public func flatten(_ strategy: FlattenStrategy) -> SignalProducer<Value.Value, Error> {
		return self.flatMap(strategy) { $0.producer.promoteError(Error.self) }
	}
}

extension Signal where Value: Sequence {
	/// Flattens the `sequence` value sent by `signal`.
	public func flatten() -> Signal<Value.Iterator.Element, Error> {
		return self.flatMap(.merge, SignalProducer.init)
	}
}

extension SignalProducer where Value: Sequence {
	/// Flattens the `sequence` value sent by `signal`.
	public func flatten() -> SignalProducer<Value.Iterator.Element, Error> {
		return self.flatMap(.merge, SignalProducer<Value.Iterator.Element, Never>.init)
	}
}

extension Signal where Value: SignalProducerConvertible, Error == Value.Error {
	fileprivate func concurrent(limit: UInt) -> Signal<Value.Value, Error> {
		precondition(limit > 0, "The concurrent limit must be greater than zero.")

		return Signal<Value.Value, Error> { relayObserver, lifetime in
			lifetime += self.observeConcurrent(relayObserver, limit, lifetime)
		}
	}

	fileprivate func observeConcurrent(_ observer: Signal<Value.Value, Error>.Observer, _ limit: UInt, _ lifetime: Lifetime) -> Disposable? {
		let state = Atomic(ConcurrentFlattenState<Value.Value, Error>(limit: limit))

		func startNextIfNeeded() {
			while let producer = state.modify({ $0.dequeue() }) {
				let producerState = UnsafeAtomicState<ProducerState>(.starting)
				let deinitializer = ScopedDisposable(AnyDisposable(producerState.deinitialize))

				producer.startWithSignal { signal, inner in
					let handle = lifetime += inner

					signal.observe { event in
						switch event {
						case .completed, .interrupted:
							handle?.dispose()

							let shouldComplete: Bool = state.modify { state in
								state.activeCount -= 1
								return state.shouldComplete
							}

							withExtendedLifetime(deinitializer) {
								if shouldComplete {
									observer.sendCompleted()
								} else if producerState.is(.started) {
									startNextIfNeeded()
								}
							}

						case .value, .failed:
							observer.send(event)
						}
					}
				}

				withExtendedLifetime(deinitializer) {
					producerState.setStarted()
				}
			}
		}

		return observe { event in
			switch event {
			case let .value(value):
				state.modify { $0.queue.append(value.producer) }
				startNextIfNeeded()

			case let .failed(error):
				observer.send(error: error)

			case .completed:
				let shouldComplete: Bool = state.modify { state in
					state.isOuterCompleted = true
					return state.shouldComplete
				}

				if shouldComplete {
					observer.sendCompleted()
				}

			case .interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducer where Value: SignalProducerConvertible, Error == Value.Error {
	fileprivate func concurrent(limit: UInt) -> SignalProducer<Value.Value, Error> {
		precondition(limit > 0, "The concurrent limit must be greater than zero.")

		return SignalProducer<Value.Value, Error> { relayObserver, lifetime in
			self.startWithSignal { signal, interruptHandle in
				lifetime += interruptHandle

				_ = signal.observeConcurrent(relayObserver, limit, lifetime)
			}
		}
	}
}

extension SignalProducer {
	/// `concat`s `next` onto `self`.
	///
	/// - parameters:
	///   - next: A follow-up producer to concat `self` with.
	///
	/// - returns: A producer that will start `self` and then on completion of
	///            `self` - will start `next`.
	public func concat(_ next: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
		return SignalProducer<SignalProducer<Value, Error>, Error>([ self, next ]).flatten(.concat)
	}

	/// `concat`s `next` onto `self`.
	///
	/// - parameters:
	///   - next: A follow-up producer to concat `self` with.
	///
	/// - returns: A producer that will start `self` and then on completion of
	///            `self` - will start `next`.
	public func concat<Next: SignalProducerConvertible>(_ next: Next) -> SignalProducer<Value, Error> where Next.Value == Value, Next.Error == Error {
		return concat(next.producer)
	}

	/// `concat`s `value` onto `self`.
	///
	/// - parameters:
	///   - value: A value to concat onto `self`.
	///
	/// - returns: A producer that, when started, will emit own values and on
	///            completion will emit a `value`.
	public func concat(value: Value) -> SignalProducer<Value, Error> {
		return concat(SignalProducer(value: value))
	}

	/// `concat`s `error` onto `self`.
	///
	/// - parameters:
	///   - error: An error to concat onto `self`.
	///
	/// - returns: A producer that, when started, will emit own values and on
	///            completion will emit an `error`.
	public func concat(error: Error) -> SignalProducer<Value, Error> {
		return concat(SignalProducer(error: error))
	}

	/// `concat`s `self` onto initial `previous`.
	///
	/// - parameters:
	///   - previous: A producer to start before `self`.
	///
	/// - returns: A signal producer that, when started, first emits values from
	///            `previous` producer and then from `self`.
	public func prefix(_ previous: SignalProducer<Value, Error>) -> SignalProducer<Value, Error> {
		return previous.concat(self)
	}

	/// `concat`s `self` onto initial `previous`.
	///
	/// - parameters:
	///   - previous: A producer to start before `self`.
	///
	/// - returns: A signal producer that, when started, first emits values from
	///            `previous` producer and then from `self`.
	public func prefix<Previous: SignalProducerConvertible>(_ previous: Previous) -> SignalProducer<Value, Error> where Previous.Value == Value, Previous.Error == Error {
		return prefix(previous.producer)
	}

	/// `concat`s `self` onto initial `value`.
	///
	/// - parameters:
	///   - value: A first value to emit.
	///
	/// - returns: A producer that, when started, first emits `value`, then all
    ///            values emited by `self`.
	public func prefix(value: Value) -> SignalProducer<Value, Error> {
		return prefix(SignalProducer(value: value))
	}
}

private final class ConcurrentFlattenState<Value, Error: Swift.Error> {
	typealias Producer = ReactiveSwift.SignalProducer<Value, Error>

	/// The limit of active producers.
	let limit: UInt

	/// The number of active producers.
	var activeCount: UInt = 0

	/// The producers waiting to be started.
	var queue: [Producer] = []

	/// Whether the outer producer has completed.
	var isOuterCompleted = false

	/// Whether the flattened signal should complete.
	var shouldComplete: Bool {
		return isOuterCompleted && activeCount == 0 && queue.isEmpty
	}

	init(limit: UInt) {
		self.limit = limit
	}

	/// Dequeue the next producer if one should be started.
	///
	/// - returns: The `Producer` to start or `nil` if no producer should be
	///            started.
	func dequeue() -> Producer? {
		if activeCount < limit, !queue.isEmpty {
			activeCount += 1
			return queue.removeFirst()
		} else {
			return nil
		}
	}
}

private enum ProducerState: Int32 {
	case starting
	case started
}

extension UnsafeAtomicState where State == ProducerState {
	fileprivate func setStarted() {
		precondition(tryTransition(from: .starting, to: .started), "The transition is not supposed to fail.")
	}
}

extension Signal {
	/// Merges the given signals into a single `Signal` that will emit all
	/// values from each of them, and complete when all of them have completed.
	///
	/// - parameters:
	///   - signals: A sequence of signals to merge.
	public static func merge<Seq: Sequence>(_ signals: Seq) -> Signal<Value, Error> where Seq.Iterator.Element == Signal<Value, Error>
	{
		return SignalProducer<Signal<Value, Error>, Error>(signals)
			.flatten(.merge)
			.startAndRetrieveSignal()
	}
	
	/// Merges the given signals into a single `Signal` that will emit all
	/// values from each of them, and complete when all of them have completed.
	///
	/// - parameters:
	///   - signals: A list of signals to merge.
	public static func merge(_ signals: Signal<Value, Error>...) -> Signal<Value, Error> {
		return Signal.merge(signals)
	}
}

extension SignalProducer {
 	/// Merges the given producers into a single `SignalProducer` that will emit
	/// all values from each of them, and complete when all of them have
	/// completed.
	///
	/// - parameters:
	///   - producers: A sequence of producers to merge.
	public static func merge<Seq: Sequence>(_ producers: Seq) -> SignalProducer<Value, Error> where Seq.Iterator.Element == SignalProducer<Value, Error>
	{
		return SignalProducer<Seq.Iterator.Element, Never>(producers).flatten(.merge)
	}

	/// Merge the values of all the given producers, in the manner described by `merge(_:)`.
	public static func merge<A: SignalProducerConvertible, B: SignalProducerConvertible>(_ a: A, _ b: B) -> SignalProducer<Value, Error> where A.Value == Value, A.Error == Error, B.Value == Value, B.Error == Error {
		return SignalProducer.merge([a.producer, b.producer])
	}

	/// Merge the values of all the given producers, in the manner described by `merge(_:)`.
	public static func merge<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C) -> SignalProducer<Value, Error> where A.Value == Value, A.Error == Error, B.Value == Value, B.Error == Error, C.Value == Value, C.Error == Error {
		return SignalProducer.merge([a.producer, b.producer, c.producer])
	}

	/// Merge the values of all the given producers, in the manner described by `merge(_:)`.
	public static func merge<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D) -> SignalProducer<Value, Error> where A.Value == Value, A.Error == Error, B.Value == Value, B.Error == Error, C.Value == Value, C.Error == Error, D.Value == Value, D.Error == Error {
		return SignalProducer.merge([a.producer, b.producer, c.producer, d.producer])
	}

	/// Merge the values of all the given producers, in the manner described by `merge(_:)`.
	public static func merge<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> SignalProducer<Value, Error> where A.Value == Value, A.Error == Error, B.Value == Value, B.Error == Error, C.Value == Value, C.Error == Error, D.Value == Value, D.Error == Error, E.Value == Value, E.Error == Error {
		return SignalProducer.merge([a.producer, b.producer, c.producer, d.producer, e.producer])
	}

	/// Merge the values of all the given producers, in the manner described by `merge(_:)`.
	public static func merge<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible, F: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> SignalProducer<Value, Error> where A.Value == Value, A.Error == Error, B.Value == Value, B.Error == Error, C.Value == Value, C.Error == Error, D.Value == Value, D.Error == Error, E.Value == Value, E.Error == Error, F.Value == Value, F.Error == Error {
		return SignalProducer.merge([a.producer, b.producer, c.producer, d.producer, e.producer, f.producer])
	}

	/// Merge the values of all the given producers, in the manner described by `merge(_:)`.
	public static func merge<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible, F: SignalProducerConvertible, G: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> SignalProducer<Value, Error> where A.Value == Value, A.Error == Error, B.Value == Value, B.Error == Error, C.Value == Value, C.Error == Error, D.Value == Value, D.Error == Error, E.Value == Value, E.Error == Error, F.Value == Value, F.Error == Error, G.Value == Value, G.Error == Error {
		return SignalProducer.merge([a.producer, b.producer, c.producer, d.producer, e.producer, f.producer, g.producer])
	}

	/// Merge the values of all the given producers, in the manner described by `merge(_:)`.
	public static func merge<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible, F: SignalProducerConvertible, G: SignalProducerConvertible, H: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> SignalProducer<Value, Error> where A.Value == Value, A.Error == Error, B.Value == Value, B.Error == Error, C.Value == Value, C.Error == Error, D.Value == Value, D.Error == Error, E.Value == Value, E.Error == Error, F.Value == Value, F.Error == Error, G.Value == Value, G.Error == Error, H.Value == Value, H.Error == Error {
		return SignalProducer.merge([a.producer, b.producer, c.producer, d.producer, e.producer, f.producer, g.producer, h.producer])
	}

	/// Merge the values of all the given producers, in the manner described by `merge(_:)`.
	public static func merge<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible, F: SignalProducerConvertible, G: SignalProducerConvertible, H: SignalProducerConvertible, I: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I) -> SignalProducer<Value, Error> where A.Value == Value, A.Error == Error, B.Value == Value, B.Error == Error, C.Value == Value, C.Error == Error, D.Value == Value, D.Error == Error, E.Value == Value, E.Error == Error, F.Value == Value, F.Error == Error, G.Value == Value, G.Error == Error, H.Value == Value, H.Error == Error, I.Value == Value, I.Error == Error {
		return SignalProducer.merge([a.producer, b.producer, c.producer, d.producer, e.producer, f.producer, g.producer, h.producer, i.producer])
	}

	/// Merge the values of all the given producers, in the manner described by `merge(_:)`.
	public static func merge<A: SignalProducerConvertible, B: SignalProducerConvertible, C: SignalProducerConvertible, D: SignalProducerConvertible, E: SignalProducerConvertible, F: SignalProducerConvertible, G: SignalProducerConvertible, H: SignalProducerConvertible, I: SignalProducerConvertible, J: SignalProducerConvertible>(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H, _ i: I, _ j: J) -> SignalProducer<Value, Error> where A.Value == Value, A.Error == Error, B.Value == Value, B.Error == Error, C.Value == Value, C.Error == Error, D.Value == Value, D.Error == Error, E.Value == Value, E.Error == Error, F.Value == Value, F.Error == Error, G.Value == Value, G.Error == Error, H.Value == Value, H.Error == Error, I.Value == Value, I.Error == Error, J.Value == Value, J.Error == Error {
		return SignalProducer.merge([a.producer, b.producer, c.producer, d.producer, e.producer, f.producer, g.producer, h.producer, i.producer, j.producer])
	}
}

extension Signal where Value: SignalProducerConvertible, Error == Value.Error {
	/// Returns a signal that forwards values from the latest signal sent on
	/// `signal`, ignoring values sent on previous inner signal.
	///
	/// - warning: An error sent on `signal` or the latest inner signal will be
	///            sent on the returned signal.
	///
	/// - note: The returned signal completes when `signal` and the latest inner
	///         signal have both completed.
	fileprivate func switchToLatest() -> Signal<Value.Value, Error> {
		return Signal<Value.Value, Error> { observer, lifetime in
			let serial = SerialDisposable()
			lifetime += serial
			lifetime += self.observeSwitchToLatest(observer, serial)
		}
	}

	fileprivate func observeSwitchToLatest(_ observer: Signal<Value.Value, Error>.Observer, _ latestInnerDisposable: SerialDisposable) -> Disposable? {
		let state = Atomic(LatestState<Value, Error>())

		return self.observe { event in
			switch event {
			case let .value(p):
				p.producer.startWithSignal { innerSignal, innerDisposable in
					state.modify {
						// When we replace the disposable below, this prevents
						// the generated Interrupted event from doing any work.
						$0.replacingInnerSignal = true
					}

					latestInnerDisposable.inner = innerDisposable

					state.modify {
						$0.replacingInnerSignal = false
						$0.innerSignalComplete = false
					}

					innerSignal.observe { event in
						switch event {
						case .interrupted:
							// If interruption occurred as a result of a new
							// producer arriving, we don't want to notify our
							// observer.
							let shouldComplete: Bool = state.modify { state in
								if !state.replacingInnerSignal {
									state.innerSignalComplete = true
								}
								return !state.replacingInnerSignal && state.outerSignalComplete
							}

							if shouldComplete {
								observer.sendCompleted()
							}

						case .completed:
							let shouldComplete: Bool = state.modify {
								$0.innerSignalComplete = true
								return $0.outerSignalComplete
							}

							if shouldComplete {
								observer.sendCompleted()
							}

						case .value, .failed:
							observer.send(event)
						}
					}
				}

			case let .failed(error):
				observer.send(error: error)

			case .completed:
				let shouldComplete: Bool = state.modify {
					$0.outerSignalComplete = true
					return $0.innerSignalComplete
				}

				if shouldComplete {
					observer.sendCompleted()
				}

			case .interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducer where Value: SignalProducerConvertible, Error == Value.Error {
	/// - warning: An error sent on `self` or the latest inner producer will be
	///            sent on the returned producer.
	///
	/// - note: The returned producer completes when `self` and the latest inner
	///         producer have both completed.
	///
	/// - returns: A producer that forwards values from the latest producer sent
	///            on `self`, ignoring values sent on previous inner producer.
	fileprivate func switchToLatest() -> SignalProducer<Value.Value, Error> {
		return SignalProducer<Value.Value, Error> { observer, lifetime in
			let latestInnerDisposable = SerialDisposable()
			lifetime += latestInnerDisposable

			self.startWithSignal { signal, signalDisposable in
				lifetime += signalDisposable
				lifetime += signal.observeSwitchToLatest(observer, latestInnerDisposable)
			}
		}
	}
}

private struct LatestState<Value, Error: Swift.Error> {
	var outerSignalComplete: Bool = false
	var innerSignalComplete: Bool = true

	var replacingInnerSignal: Bool = false
}

extension Signal where Value: SignalProducerConvertible, Error == Value.Error {
	/// Returns a signal that forwards values from the "first input signal to send an event"
	/// (winning signal) that is sent on `self`, ignoring values sent from other inner signals.
	///
	/// An error sent on `self` or the winning inner signal will be sent on the
	/// returned signal.
	///
	/// The returned signal completes when `self` and the winning inner signal have both completed.
	fileprivate func race() -> Signal<Value.Value, Error> {
		return Signal<Value.Value, Error> { observer, lifetime in
			let relayDisposable = CompositeDisposable()
			lifetime += relayDisposable
			lifetime += self.observeRace(observer, relayDisposable)
		}
	}

	fileprivate func observeRace(_ observer: Signal<Value.Value, Error>.Observer, _ relayDisposable: CompositeDisposable) -> Disposable? {
		let state = Atomic(RaceState())

		return self.observe { event in
			switch event {
			case let .value(innerProducer):
				// Ignore consecutive `innerProducer`s if any `innerSignal` already sent an event.
				guard !relayDisposable.isDisposed else {
					return
				}

				innerProducer.producer.startWithSignal { innerSignal, innerDisposable in
					state.modify {
						$0.innerSignalComplete = false
					}

					let disposableHandle = relayDisposable.add(innerDisposable)
					var isWinningSignal = false

					innerSignal.observe { event in
						if !isWinningSignal {
							isWinningSignal = state.modify { state in
								guard !state.isActivated else {
									return false
								}

								state.isActivated = true
								return true
							}

							// Ignore non-winning signals.
							guard isWinningSignal else { return }

							// The disposals would be run exactly once immediately after
							// the winning signal flips `state.isActivated`.
							disposableHandle?.dispose()
							relayDisposable.dispose()
						}

						switch event {
						case .completed:
							let shouldComplete: Bool = state.modify { state in
								state.innerSignalComplete = true
								return state.outerSignalComplete
							}

							if shouldComplete {
								observer.sendCompleted()
							}

						case .value, .failed, .interrupted:
							observer.send(event)
						}
					}
				}

			case let .failed(error):
				observer.send(error: error)

			case .completed:
				let shouldComplete: Bool = state.modify { state in
					state.outerSignalComplete = true
					return state.innerSignalComplete
				}

				if shouldComplete {
					observer.sendCompleted()
				}

			case .interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducer where Value: SignalProducerConvertible, Error == Value.Error {
	/// Returns a producer that forwards values from the "first input producer to send an event"
	/// (winning producer) that is sent on `self`, ignoring values sent from other inner producers.
	///
	/// An error sent on `self` or the winning inner producer will be sent on the
	/// returned producer.
	///
	/// The returned producer completes when `self` and the winning inner producer have both completed.
	fileprivate func race() -> SignalProducer<Value.Value, Error> {
		return SignalProducer<Value.Value, Error> { observer, lifetime in
			let relayDisposable = CompositeDisposable()
			lifetime += relayDisposable

			self.startWithSignal { signal, signalDisposable in
				lifetime += signalDisposable
				lifetime += signal.observeRace(observer, relayDisposable)
			}
		}
	}
}

private struct RaceState {
	var outerSignalComplete = false
	var innerSignalComplete = true
	var isActivated = false
}

extension Signal where Value: SignalProducerConvertible, Error == Value.Error {
	/// Returns a signal that forwards values from the "first inner producer" if not exists,
	/// ignoring values sent from other inner producers until first inner producer is completed.
	/// Note that next inner producer after previous completion can become
	/// first inner producer again.
	///
	/// An error sent on `self` or the first inner producer will be sent on the
	/// returned signal.
	///
	/// The returned signal completes when `self` is completed, and also first inner producer
	/// is completed if it exists.
	fileprivate func throttle() -> Signal<Value.Value, Error> {
		return Signal<Value.Value, Error> { observer, lifetime in
			let relayDisposable = CompositeDisposable()
			lifetime += relayDisposable
			lifetime += self.observeThrottle(observer, relayDisposable)
		}
	}

	fileprivate func observeThrottle(_ observer: Signal<Value.Value, Error>.Observer, _ relayDisposable: CompositeDisposable) -> Disposable? {
		let state = Atomic(ThrottleState())

		return self.observe { event in
			switch event {
			case let .value(innerProducer):
				let isFirstInnerProducer: Bool = state.modify { state in
					guard !state.hasFirstInnerProducer else {
						return false
					}

					state.hasFirstInnerProducer = true
					return true
				}

				// Ignore consecutive `innerProducer`s while `isFirstInnerProducer` is true.
				guard isFirstInnerProducer else { return }

				innerProducer.producer.startWithSignal { innerSignal, innerDisposable in
					relayDisposable.add(innerDisposable)

					innerSignal.observe { event in
						switch event {
						case .completed:
							let shouldComplete: Bool = state.modify { state in
								state.hasFirstInnerProducer = false
								return state.outerSignalComplete
							}

							if shouldComplete {
								observer.sendCompleted()
							}

						case .value, .failed, .interrupted:
							observer.send(event)
						}
					}
				}

			case let .failed(error):
				observer.send(error: error)

			case .completed:
				let shouldComplete: Bool = state.modify { state in
					state.outerSignalComplete = true
					return !state.hasFirstInnerProducer
				}

				if shouldComplete {
					observer.sendCompleted()
				}

			case .interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducer where Value: SignalProducerConvertible, Error == Value.Error {
	/// Returns a producer that forwards values from the "first inner producer" if not exists,
	/// ignoring values sent from other inner producers until first inner producer is completed.
	/// Note that next inner producer after previous completion can become first inner producer again.
	///
	/// An error sent on `self` or the first inner producer will be sent on the
	/// returned producer.
	///
	/// The returned signal completes when `self` is completed, and also first inner producer
	/// is completed if it exists.
	fileprivate func throttle() -> SignalProducer<Value.Value, Error> {
		return SignalProducer<Value.Value, Error> { observer, lifetime in
			let relayDisposable = CompositeDisposable()
			lifetime += relayDisposable

			self.startWithSignal { signal, signalDisposable in
				lifetime += signalDisposable
				lifetime += signal.observeThrottle(observer, relayDisposable)
			}
		}
	}
}

private struct ThrottleState {
	var outerSignalComplete = false
	var hasFirstInnerProducer = false
}

extension Signal {
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting producers (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If `signal` or any of the created producers fail, the 
	///            returned signal will forward that failure immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<U>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> SignalProducer<U, Error>) -> Signal<U, Error>{
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting producers (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If `signal` or any of the created producers fail, the
	///            returned signal will forward that failure immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Error> where Inner.Error == Error {
		return flatMap(strategy) { transform($0).producer }
	}

	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting producers (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If `signal` fails, the returned signal will forward that
	///            failure immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<U>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> SignalProducer<U, Never>) -> Signal<U, Error> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting producers (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If `signal` fails, the returned signal will forward that
	///            failure immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Error> where Inner.Error == Never {
		return flatMap(strategy) { transform($0).producer }
	}
}

extension Signal where Error == Never {
	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If any of the created signals emit an error, the returned
	///            signal will forward that error immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<U, F>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> SignalProducer<U, F>) -> Signal<U, F> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If any of the created signals emit an error, the returned
	///            signal will forward that error immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Inner.Error> {
		return flatMap(strategy) { transform($0).producer }
	}

	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<U>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> SignalProducer<U, Never>) -> Signal<U, Never> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `signal` to a new signal, then flattens the
	/// resulting signals (into a signal of values), according to the
	/// semantics of the given strategy.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> Signal<Inner.Value, Never> where Inner.Error == Never {
		return flatMap(strategy) { transform($0).producer }
	}
}

extension SignalProducer {
	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If `self` or any of the created producers fail, the returned
	///            producer will forward that failure immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<U>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> SignalProducer<U, Error>) -> SignalProducer<U, Error> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If `self` or any of the created producers fail, the returned
	///            producer will forward that failure immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Error> where Inner.Error == Error {
		return flatMap(strategy) { transform($0).producer }
	}

	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If `self` fails, the returned producer will forward that
	///            failure immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<U>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> SignalProducer<U, Never>) -> SignalProducer<U, Error> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If `self` fails, the returned producer will forward that
	///            failure immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Error> where Inner.Error == Never {
		return flatMap(strategy) { transform($0).producer }
	}
}

extension SignalProducer where Error == Never {
	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<U>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> SignalProducer<U, Error>) -> SignalProducer<U, Error> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Error> where Inner.Error == Error {
		return flatMap(strategy) { transform($0).producer }
	}

	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If any of the created producers fail, the returned producer
	///            will forward that failure immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<U, F>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> SignalProducer<U, F>) -> SignalProducer<U, F> {
		return map(transform).flatten(strategy)
	}

	/// Maps each event from `self` to a new producer, then flattens the
	/// resulting producers (into a producer of values), according to the
	/// semantics of the given strategy.
	///
	/// - warning: If any of the created producers fail, the returned producer
	///            will forward that failure immediately.
	///
	/// - parameters:
	///	  - strategy: Strategy used when flattening signals.
	///   - transform: A closure that takes a value emitted by `self` and
	///                returns a signal producer with transformed value.
	public func flatMap<Inner: SignalProducerConvertible>(_ strategy: FlattenStrategy, _ transform: @escaping (Value) -> Inner) -> SignalProducer<Inner.Value, Inner.Error> {
		return flatMap(strategy) { transform($0).producer }
	}
}

extension Signal {
	/// Catches any failure that may occur on the input signal, mapping to a new
	/// producer that starts in its place.
	///
	/// - parameters:
	///   - transform: A closure that accepts emitted error and returns a signal
	///                producer with a different type of error.
	public func flatMapError<F>(_ transform: @escaping (Error) -> SignalProducer<Value, F>) -> Signal<Value, F> {
		return Signal<Value, F> { observer, lifetime in
			lifetime += self.observeFlatMapError(transform, observer, SerialDisposable())
		}
	}

	/// Catches any failure that may occur on the input signal, mapping to a new
	/// producer that starts in its place.
	///
	/// - parameters:
	///   - transform: A closure that accepts emitted error and returns a signal
	///                producer with a different type of error.
	public func flatMapError<Inner: SignalProducerConvertible>(_ transform: @escaping (Error) -> Inner) -> Signal<Value, Inner.Error> where Inner.Value == Value {
		return flatMapError { transform($0).producer }
	}

	fileprivate func observeFlatMapError<Inner: SignalProducerConvertible>(
		_ handler: @escaping (Error) -> Inner,
		_ observer: Signal<Value, Inner.Error>.Observer,
		_ serialDisposable: SerialDisposable) -> Disposable? where Inner.Value == Value {
		return self.observe { event in
			switch event {
			case let .value(value):
				observer.send(value: value)
			case let .failed(error):
				handler(error).producer.startWithSignal { signal, disposable in
					serialDisposable.inner = disposable
					signal.observe(observer)
				}
			case .completed:
				observer.sendCompleted()
			case .interrupted:
				observer.sendInterrupted()
			}
		}
	}
}

extension SignalProducer {
	/// Catches any failure that may occur on the input producer, mapping to a
	/// new producer that starts in its place.
	///
	/// - parameters:
	///   - transform: A closure that accepts emitted error and returns a signal
	///                producer with a different type of error.
	public func flatMapError<F>(_ transform: @escaping (Error) -> SignalProducer<Value, F>) -> SignalProducer<Value, F> {
		return SignalProducer<Value, F> { observer, lifetime in
			let serialDisposable = SerialDisposable()
			lifetime += serialDisposable

			self.startWithSignal { signal, signalDisposable in
				serialDisposable.inner = signalDisposable

				_ = signal.observeFlatMapError(transform, observer, serialDisposable)
			}
		}
	}

	/// Catches any failure that may occur on the input producer, mapping to a
	/// new producer that starts in its place.
	///
	/// - parameters:
	///   - transform: A closure that accepts emitted error and returns a signal
	///                producer with a different type of error.
	public func flatMapError<Inner: SignalProducerConvertible>(_ transform: @escaping (Error) -> Inner) -> SignalProducer<Value, Inner.Error> where Inner.Value == Value {
		return flatMapError { transform($0).producer }
	}
}
