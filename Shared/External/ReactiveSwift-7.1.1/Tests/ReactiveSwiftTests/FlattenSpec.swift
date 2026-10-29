//
//  FlattenSpec.swift
//  ReactiveSwift
//
//  Created by Oleg Shnitko on 1/22/16.
//  Copyright © 2016 GitHub. All rights reserved.
//

import Nimble
import Quick
@testable import ReactiveSwift
import Dispatch

private extension Signal {
	typealias Pipe = (output: Signal<Value, Error>, input: Signal<Value, Error>.Observer)
}

private typealias Pipe = Signal<SignalProducer<Int, TestError>, TestError>.Pipe

class FlattenSpec: QuickSpec {
	override func spec() {
		func describeSignalFlattenDisposal(_ flattenStrategy: FlattenStrategy, name: String) {
			describe(name) {
				var pipe: Pipe!
				var disposable: Disposable?

				beforeEach {
					pipe = Signal.pipe()
					disposable = pipe.output
						.flatten(flattenStrategy)
						.observe { _ in }
				}

				afterEach {
					disposable?.dispose()
				}

				context("disposal") {
					var disposed = false

					beforeEach {
						disposed = false
						pipe.input.send(value: SignalProducer<Int, TestError> { _, lifetime in
							lifetime.observeEnded { disposed = true }
						})
					}

					it("should dispose inner signals when outer signal interrupted") {
						pipe.input.sendInterrupted()
						expect(disposed) == true
					}

					it("should dispose inner signals when outer signal failed") {
						pipe.input.send(error: .default)
						expect(disposed) == true
					}

					it("should not dispose inner signals when outer signal completed") {
						pipe.input.sendCompleted()
						expect(disposed) == false
					}
				}
			}
		}

		context("Signal") {
			describeSignalFlattenDisposal(.latest, name: "switchToLatest")
			describeSignalFlattenDisposal(.merge, name: "merge")
			describeSignalFlattenDisposal(.concat, name: "concat")
			describeSignalFlattenDisposal(.concurrent(limit: 1024), name: "concurrent(limit: 1024)")
			describeSignalFlattenDisposal(.race, name: "race")
		}

		func describeSignalProducerFlattenDisposal(_ flattenStrategy: FlattenStrategy, name: String) {
			describe(name) {
				it("disposes original signal when result signal interrupted") {
					var disposed = false

					let disposable = SignalProducer<SignalProducer<(), Never>, Never> { _, lifetime in
						lifetime.observeEnded { disposed = true }
					}
						.flatten(flattenStrategy)
						.start()

					disposable.dispose()
					expect(disposed) == true
				}
			}
		}

		context("SignalProducer") {
			describeSignalProducerFlattenDisposal(.latest, name: "switchToLatest")
			describeSignalProducerFlattenDisposal(.merge, name: "merge")
			describeSignalProducerFlattenDisposal(.concat, name: "concat")
			describeSignalProducerFlattenDisposal(.concurrent(limit: 1024), name: "concurrent(limit: 1024)")
			describeSignalProducerFlattenDisposal(.race, name: "race")
		}

		describe("Signal.flatten()") {
			it("works with TestError and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = Signal<Inner, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.assumeNoErrors()
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = Signal<Inner, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.assumeNoErrors()
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a Never Signal") {
				typealias Inner = Signal<Int, Never>
				typealias Outer = Signal<Inner, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with TestError and a Never Signal") {
				typealias Inner = Signal<Int, Never>
				typealias Outer = Signal<Inner, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.assumeNoErrors()
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with TestError and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = Signal<Inner, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.assumeNoErrors()
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = Signal<Inner, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.assumeNoErrors()
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a Never SignalProducer") {
				typealias Inner = SignalProducer<Int, Never>
				typealias Outer = Signal<Inner, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with TestError and a Never SignalProducer") {
				typealias Inner = SignalProducer<Int, Never>
				typealias Outer = Signal<Inner, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.assumeNoErrors()
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Sequence as a value") {
				let (signal, innerObserver) = Signal<[Int], Never>.pipe()
				let sequence = [1, 2, 3]
				var observedValues = [Int]()

				signal
					.flatten()
					.observeValues { value in
						observedValues.append(value)
					}

				innerObserver.send(value: sequence)
				expect(observedValues) == sequence
			}

			it("works with Sequence as a value and any arbitrary error") {
				_ = Signal<[Int], TestError>.empty
					.flatten()
			}

			it("works with Property and any arbitrary error") {
				_ = Signal<Property<Int>, TestError>.empty
					.flatten(.latest)
			}

			it("works with Property and Never") {
				_ = Signal<Property<Int>, Never>.empty
					.flatten(.latest)
			}
		}

		describe("SignalProducer.flatten()") {
			it("works with TestError and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = SignalProducer<Inner, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.assumeNoErrors()
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = SignalProducer<Inner, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.assumeNoErrors()
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a Never Signal") {
				typealias Inner = Signal<Int, Never>
				typealias Outer = SignalProducer<Inner, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with TestError and a Never Signal") {
				typealias Inner = Signal<Int, Never>
				typealias Outer = SignalProducer<Inner, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.assumeNoErrors()
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with TestError and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = SignalProducer<Inner, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.assumeNoErrors()
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = SignalProducer<Inner, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.assumeNoErrors()
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a Never SignalProducer") {
				typealias Inner = SignalProducer<Int, Never>
				typealias Outer = SignalProducer<Inner, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with TestError and a Never SignalProducer") {
				typealias Inner = SignalProducer<Int, Never>
				typealias Outer = SignalProducer<Inner, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatten(.latest)
					.assumeNoErrors()
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: inner)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Sequence as a value") {
				let sequence = [1, 2, 3]
				var observedValues = [Int]()

				let producer = SignalProducer<[Int], Never>(value: sequence)
				producer
					.flatten()
					.startWithValues { value in
						observedValues.append(value)
					}

				expect(observedValues) == sequence
			}

			it("works with Sequence as a value and any arbitrary error") {
				_ = SignalProducer<[Int], TestError>.empty
					.flatten()
			}

			it("works with Property and any arbitrary error") {
				_ = SignalProducer<Property<Int>, TestError>.empty
					.flatten(.latest)
			}

			it("works with Property and Never") {
				_ = SignalProducer<Property<Int>, Never>.empty
					.flatten(.latest)
			}
		}

		describe("Signal.flatMap()") {
			it("works with TestError and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = Signal<Int, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.assumeNoErrors()
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = Signal<Int, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.assumeNoErrors()
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a Never Signal") {
				typealias Inner = Signal<Int, Never>
				typealias Outer = Signal<Int, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with TestError and a Never Signal") {
				typealias Inner = Signal<Int, Never>
				typealias Outer = Signal<Int, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.assumeNoErrors()
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with TestError and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = Signal<Int, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.assumeNoErrors()
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = Signal<Int, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.assumeNoErrors()
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a Never SignalProducer") {
				typealias Inner = SignalProducer<Int, Never>
				typealias Outer = Signal<Int, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with TestError and a Never SignalProducer") {
				typealias Inner = SignalProducer<Int, Never>
				typealias Outer = Signal<Int, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.assumeNoErrors()
					.observeValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Property and any arbitrary error") {
				_ = Signal<Int, TestError>.empty
					.flatMap(.latest) { _ in Property(value: 0) }
			}

			it("works with Property and Never") {
				_ = Signal<Int, Never>.empty
					.flatMap(.latest) { _ in Property(value: 0) }
			}

			it("should be able to fallback to SignalProducer for contextual lookups with explicit inner value and error type parameters, given an upstream of arbitrary error type") {
				_ = Signal<Int, TestError>.empty
					.flatMap(.latest) { _ in .init(result: Result<Int, TestError>(failure: .default)) }
			}

			it("should be able to fallback to SignalProducer for contextual lookups with implicit error type parameter") {
				_ = Signal<Int, Never>.empty
					.flatMap(.latest) { _ in .init(value: 0) }
			}

			it("should be able to fallback to SignalProducer for contextual lookups with implicit error type parameter") {
				_ = Signal<Int, TestError>.empty
					.flatMap(.latest) { _ in .init(value: 0) }
			}

// NOTE: These test cases were disabled as the Swift 4.2 type checker apparently
// cannot infer the type paramaters when both are absent.
//			it("should be able to fallback to SignalProducer for contextual lookups without explicit inner value and error type parameters") {
//				_ = Signal<Int, Never>.empty
//					.flatMap(.latest) { _ in .empty }
//			}
//
//			it("should be able to fallback to SignalProducer for contextual lookups without explicit inner value and error type parameters") {
//				_ = Signal<Int, TestError>.empty
//					.flatMap(.latest) { _ in .empty }
//			}

			it("should be able to fallback to SignalProducer for contextual lookups with explicit inner and error type parameters, given a Never upstream") {
				_ = Signal<Int, Never>.empty
					.flatMap(.latest) { _ in .init(result: Result<Int, TestError>.failure(.default)) }
			}
		}

		describe("SignalProducer.flatMap()") {
			it("works with TestError and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = SignalProducer<Int, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.assumeNoErrors()
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a TestError Signal") {
				typealias Inner = Signal<Int, TestError>
				typealias Outer = SignalProducer<Int, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.assumeNoErrors()
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a Never Signal") {
				typealias Inner = Signal<Int, Never>
				typealias Outer = SignalProducer<Int, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with TestError and a Never Signal") {
				typealias Inner = Signal<Int, Never>
				typealias Outer = SignalProducer<Int, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.assumeNoErrors()
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with TestError and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = SignalProducer<Int, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.assumeNoErrors()
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a TestError SignalProducer") {
				typealias Inner = SignalProducer<Int, TestError>
				typealias Outer = SignalProducer<Int, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.assumeNoErrors()
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Never and a Never SignalProducer") {
				typealias Inner = SignalProducer<Int, Never>
				typealias Outer = SignalProducer<Int, Never>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with TestError and a Never SignalProducer") {
				typealias Inner = SignalProducer<Int, Never>
				typealias Outer = SignalProducer<Int, TestError>

				let (inner, innerObserver) = Inner.pipe()
				let (outer, outerObserver) = Outer.pipe()

				var observed: Int? = nil
				outer
					.flatMap(.latest) { _ in inner }
					.assumeNoErrors()
					.startWithValues { value in
						observed = value
					}

				outerObserver.send(value: 4)
				innerObserver.send(value: 4)
				expect(observed) == 4
			}

			it("works with Property and any arbitrary error") {
				_ = SignalProducer<Int, TestError>.empty
					.flatMap(.latest) { _ in Property(value: 0) }
			}

			it("works with Property and Never") {
				_ = SignalProducer<Int, Never>.empty
					.flatMap(.latest) { _ in Property(value: 0) }
			}

			it("should be able to fallback to SignalProducer for contextual lookups with explicit inner value and error type parameters, given an upstream of arbitrary error type") {
				_ = SignalProducer<Int, TestError>.empty
					.flatMap(.latest) { _ in .init(error: .default) } as SignalProducer<Int, TestError>
			}

			it("should be able to fallback to SignalProducer for contextual lookups with implicit inner error type parameter") {
				_ = SignalProducer<Int, Never>.empty
					.flatMap(.latest) { _ in .init(value: 0) }
			}

			it("should be able to fallback to SignalProducer for contextual lookups with implicit inner error type parameter") {
				_ = SignalProducer<Int, TestError>.empty
					.flatMap(.latest) { _ in .init(value: 0) }
			}

// NOTE: These test cases were disabled as the Swift 4.2 type checker apparently
// cannot infer the type paramaters when both are absent.
//			it("should be able to fallback to SignalProducer for contextual lookups without explicit inner value and error type parameters") {
//				_ = SignalProducer<Int, Never>.empty
//					.flatMap(.latest) { _ in .empty }
//			}
//
//			it("should be able to fallback to SignalProducer for contextual lookups without explicit inner value and error type parameters") {
//				_ = SignalProducer<Int, TestError>.empty
//					.flatMap(.latest) { _ in .empty }
//			}

			it("should be able to fallback to SignalProducer for contextual lookups with explicit inner and error type parameters, given a Never upstream.") {
				_ = SignalProducer<Int, Never>.empty
					.flatMap(.latest) { _ in .init(error: .default) } as SignalProducer<Int, TestError>
			}
		}

		describe("Signal.merge()") {
			it("should emit values from all signals") {
				let (signal1, observer1) = Signal<Int, Never>.pipe()
				let (signal2, observer2) = Signal<Int, Never>.pipe()
				let (signal3, observer3) = Signal<Int, Never>.pipe()

				let mergedSignals = Signal.merge([signal1, signal2, signal3])

				var lastValue: Int?
				mergedSignals.observeValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer1.send(value: 1)
				expect(lastValue) == 1

				observer2.send(value: 2)
				expect(lastValue) == 2

				observer3.send(value: 3)
				expect(lastValue) == 3
				
				observer1.send(value: 4)
				expect(lastValue) == 4
			}

			it("should not stop when one signal completes") {
				let (signal1, observer1) = Signal<Int, Never>.pipe()
				let (signal2, observer2) = Signal<Int, Never>.pipe()
				let (signal3, observer3) = Signal<Int, Never>.pipe()

				let mergedSignals = Signal.merge([signal1, signal2, signal3])

				var lastValue: Int?
				mergedSignals.observeValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer1.send(value: 1)
				expect(lastValue) == 1

				observer1.sendCompleted()
				expect(lastValue) == 1

				observer2.send(value: 2)
				expect(lastValue) == 2
				
				observer3.send(value: 3)
				expect(lastValue) == 3
			}

			it("should complete when all signals complete") {
				let (signal1, observer1) = Signal<Int, Never>.pipe()
				let (signal2, observer2) = Signal<Int, Never>.pipe()
				let (signal3, observer3) = Signal<Int, Never>.pipe()

				let mergedSignals = Signal.merge([signal1, signal2, signal3])

				var completed = false
				mergedSignals.observeCompleted { completed = true }

				expect(completed) == false

				observer1.send(value: 1)
				expect(completed) == false

				observer1.sendCompleted()
				expect(completed) == false

				observer2.sendCompleted()
				expect(completed) == false
				
				observer3.sendCompleted()
				expect(completed) == true
			}
		}
		
		describe("Signal.merge(with:)") {
			it("should emit values from both signals") {
				let (signal1, observer1) = Signal<Int, Never>.pipe()
				let (signal2, observer2) = Signal<Int, Never>.pipe()
				
				let mergedSignals = signal1.merge(with: signal2)
				
				var lastValue: Int?
				mergedSignals.observeValues { lastValue = $0 }
				
				expect(lastValue).to(beNil())
				
				observer1.send(value: 1)
				expect(lastValue) == 1
				
				observer2.send(value: 2)
				expect(lastValue) == 2
				
				observer1.send(value: 3)
				expect(lastValue) == 3
			}
			
			it("should not stop when one signal completes") {
				let (signal1, observer1) = Signal<Int, Never>.pipe()
				let (signal2, observer2) = Signal<Int, Never>.pipe()
				
				let mergedSignals = signal1.merge(with: signal2)
				
				var lastValue: Int?
				mergedSignals.observeValues { lastValue = $0 }
				
				expect(lastValue).to(beNil())
				
				observer1.send(value: 1)
				expect(lastValue) == 1
				
				observer1.sendCompleted()
				expect(lastValue) == 1
				
				observer2.send(value: 2)
				expect(lastValue) == 2
			}
			
			it("should complete when both signals complete") {
				let (signal1, observer1) = Signal<Int, Never>.pipe()
				let (signal2, observer2) = Signal<Int, Never>.pipe()
				
				let mergedSignals = signal1.merge(with: signal2)
				
				var completed = false
				mergedSignals.observeCompleted { completed = true }
				
				expect(completed) == false
				
				observer1.send(value: 1)
				expect(completed) == false
				
				observer1.sendCompleted()
				expect(completed) == false
				
				observer2.sendCompleted()
				expect(completed) == true
			}
		}

		describe("SignalProducer.merge()") {
			it("should emit values from all producers") {
				let (producer1, observer1) = SignalProducer<Int, Never>.pipe()
				let (producer2, observer2) = SignalProducer<Int, Never>.pipe()
				let (producer3, observer3) = SignalProducer<Int, Never>.pipe()

				let mergedProducer = SignalProducer.merge([producer1, producer2, producer3])

				var lastValue: Int?
				mergedProducer.startWithValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer1.send(value: 1)
				expect(lastValue) == 1
				
				observer2.send(value: 2)
				expect(lastValue) == 2
				
				observer3.send(value: 3)
				expect(lastValue) == 3
				
				observer1.send(value: 4)
				expect(lastValue) == 4
			}

			it("should not stop when one producer completes") {
				let (producer1, observer1) = SignalProducer<Int, Never>.pipe()
				let (producer2, observer2) = SignalProducer<Int, Never>.pipe()
				let (producer3, observer3) = SignalProducer<Int, Never>.pipe()

				let mergedProducer = SignalProducer.merge([producer1, producer2, producer3])

				var lastValue: Int?
				mergedProducer.startWithValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer1.send(value: 1)
				expect(lastValue) == 1
				
				observer1.sendCompleted()
				expect(lastValue) == 1
				
				observer2.send(value: 2)
				expect(lastValue) == 2
				
				observer3.send(value: 3)
				expect(lastValue) == 3
			}

			it("should complete when all producers complete") {
				let (producer1, observer1) = SignalProducer<Int, Never>.pipe()
				let (producer2, observer2) = SignalProducer<Int, Never>.pipe()
				let (producer3, observer3) = SignalProducer<Int, Never>.pipe()

				let mergedProducer = SignalProducer.merge([producer1, producer2, producer3])

				var completed = false
				mergedProducer.startWithCompleted { completed = true }

				expect(completed) == false
				
				observer1.send(value: 1)
				expect(completed) == false
				
				observer1.sendCompleted()
				expect(completed) == false
				
				observer2.sendCompleted()
				expect(completed) == false
				
				observer3.sendCompleted()
				expect(completed) == true
			}
		}
		
		describe("SignalProducer.merge(with:)") {
			it("should emit values from both producers") {
				let (producer1, observer1) = SignalProducer<Int, Never>.pipe()
				let (producer2, observer2) = SignalProducer<Int, Never>.pipe()
				
				let mergedProducer = producer1.merge(with: producer2)
				
				var lastValue: Int?
				mergedProducer.startWithValues { lastValue = $0 }
				
				expect(lastValue).to(beNil())
				
				observer1.send(value: 1)
				expect(lastValue) == 1
				
				observer2.send(value: 2)
				expect(lastValue) == 2
				
				observer1.send(value: 3)
				expect(lastValue) == 3
			}
			
			it("should not stop when one producer completes") {
				let (producer1, observer1) = SignalProducer<Int, Never>.pipe()
				let (producer2, observer2) = SignalProducer<Int, Never>.pipe()
				
				let mergedProducer = producer1.merge(with: producer2)
				
				var lastValue: Int?
				mergedProducer.startWithValues { lastValue = $0 }
				
				expect(lastValue).to(beNil())
				
				observer1.send(value: 1)
				expect(lastValue) == 1
				
				observer1.sendCompleted()
				expect(lastValue) == 1
				
				observer2.send(value: 2)
				expect(lastValue) == 2
			}
			
			it("should complete when both producers complete") {
				let (producer1, observer1) = SignalProducer<Int, Never>.pipe()
				let (producer2, observer2) = SignalProducer<Int, Never>.pipe()
				
				let mergedProducer = producer1.merge(with: producer2)
				
				var completed = false
				mergedProducer.startWithCompleted { completed = true }
				
				expect(completed) == false
				
				observer1.send(value: 1)
				expect(completed) == false
				
				observer1.sendCompleted()
				expect(completed) == false
				
				observer2.sendCompleted()
				expect(completed) == true
			}

			it("should be able to fallback to SignalProducer for contextual lookups") {
				_ = SignalProducer<Int, Never>.empty
					.merge(with: .init(value: 0))
			}
		}

		describe("SignalProducer.prefix()") {
			it("should emit initial value") {
				let (signal, observer) = SignalProducer<Int, Never>.pipe()

				let mergedSignals = signal.prefix(value: 0)

				var lastValue: Int?
				mergedSignals.startWithValues { lastValue = $0 }

				expect(lastValue) == 0

				observer.send(value: 1)
				expect(lastValue) == 1

				observer.send(value: 2)
				expect(lastValue) == 2

				observer.send(value: 3)
				expect(lastValue) == 3
			}

			it("should emit initial value") {
				let (signal, observer) = SignalProducer<Int, Never>.pipe()

				let mergedSignals = signal.prefix(SignalProducer(value: 0))

				var lastValue: Int?
				mergedSignals.startWithValues { lastValue = $0 }

				expect(lastValue) == 0

				observer.send(value: 1)
				expect(lastValue) == 1

				observer.send(value: 2)
				expect(lastValue) == 2

				observer.send(value: 3)
				expect(lastValue) == 3
			}

			it("should accept SignalProducerConvertible conforming type") {
				let (signal, observer) = SignalProducer<Int, Never>.pipe()

				let mergedSignals = signal.prefix(Property(value: 0))

				var lastValue: Int?
				mergedSignals.startWithValues { lastValue = $0 }

				expect(lastValue) == 0

				observer.send(value: 1)
				expect(lastValue) == 1

				observer.send(value: 2)
				expect(lastValue) == 2

				observer.send(value: 3)
				expect(lastValue) == 3
			}

			it("should be able to fallback to SignalProducer for contextual lookups") {
				_ = SignalProducer<Int, Never>.empty
					.prefix(.init(value: 0))
			}
		}

		describe("SignalProducer.concat()") {
			it("should emit final value") {
				let (signal, observer) = SignalProducer<Int, Never>.pipe()

				let mergedSignals = signal.concat(value: 4)

				var lastValue: Int?
				mergedSignals.startWithValues { lastValue = $0 }

				observer.send(value: 1)
				expect(lastValue) == 1

				observer.send(value: 2)
				expect(lastValue) == 2

				observer.send(value: 3)
				expect(lastValue) == 3

				observer.sendCompleted()
				expect(lastValue) == 4
			}

			it("should emit final value") {
				let (signal, observer) = SignalProducer<Int, Never>.pipe()

				let mergedSignals = signal.concat(SignalProducer(value: 4))

				var lastValue: Int?
				mergedSignals.startWithValues { lastValue = $0 }

				observer.send(value: 1)
				expect(lastValue) == 1

				observer.send(value: 2)
				expect(lastValue) == 2

				observer.send(value: 3)
				expect(lastValue) == 3

				observer.sendCompleted()
				expect(lastValue) == 4
			}

			it("should accept SignalProducerConvertible conforming type") {
				let (signal, observer) = SignalProducer<Int, Never>.pipe()

				let mergedSignals = signal.concat(Property(value: 4))

				var lastValue: Int?
				mergedSignals.startWithValues { lastValue = $0 }

				observer.send(value: 1)
				expect(lastValue) == 1

				observer.send(value: 2)
				expect(lastValue) == 2

				observer.send(value: 3)
				expect(lastValue) == 3

				observer.sendCompleted()
				expect(lastValue) == 4
			}

			it("should emit concatenated error") {
				let (signal, observer) = SignalProducer<Int, TestError>.pipe()

				let mergedSignals = signal.concat(error: TestError.default)

				var results: [Result<Int, TestError>] = []
				mergedSignals.startWithResult { results.append($0) }

				observer.send(value: 1)
				observer.send(value: 2)
				observer.send(value: 3)
				observer.sendCompleted()

				expect(results).to(haveCount(4))
				expect(results[0].value) == 1
				expect(results[1].value) == 2
				expect(results[2].value) == 3
				expect(results[3].error) == .default
			}

			it("should not emit concatenated error for failed producer") {
				let (signal, observer) = SignalProducer<Int, TestError>.pipe()

				let mergedSignals = signal.concat(error: TestError.default)

				var results: [Result<Int, TestError>] = []
				mergedSignals.startWithResult { results.append($0) }

				observer.send(error: TestError.error1)

				expect(results).to(haveCount(1))
				expect(results[0].error) == .error1
			}

			it("should be able to fallback to SignalProducer for contextual lookups") {
				_ = SignalProducer<Int, Never>.empty
					.concat(.init(value: 0))
			}
		}

		describe("FlattenStrategy.concurrent") {
			func run(_ modifier: (SignalProducer<UInt, Never>) -> SignalProducer<UInt, Never>) {
				let concurrentLimit: UInt = 4
				let extra: UInt = 100

				let (outer, outerObserver) = Signal<SignalProducer<UInt, Never>, Never>.pipe()

				var values: [UInt] = []
				outer.flatten(.concurrent(limit: concurrentLimit)).observeValues { values.append($0) }

				var started: [UInt] = []
				var observers: [Signal<UInt, Never>.Observer] = []

				for i in 0 ..< (concurrentLimit + extra) {
					let (signal, observer) = Signal<UInt, Never>.pipe()
					observers.append(observer)

					let producer = modifier(SignalProducer(signal).prefix(value: i).on(started: { started.append(i) }))
					outerObserver.send(value: producer)
				}

				// The producers may be started asynchronously. So these
				// expectations have to be asynchronous too.
				expect(values).toEventually(equal(Array(0 ..< concurrentLimit)))
				expect(started).toEventually(equal(Array(0 ..< concurrentLimit)))

				for i in 0 ..< extra {
					observers[Int(i)].sendCompleted()

					expect(values).toEventually(equal(Array(0 ... (concurrentLimit + i))))
					expect(started).toEventually(equal(Array(0 ... (concurrentLimit + i))))
				}
			}

			it("should synchronously merge up to the stated limit, buffer any subsequent producers and dequeue them in the submission order") {
				run { $0 }
			}

			it("should asynchronously merge up to the stated limit, buffer any subsequent producers and dequeue them in the submission order") {
				let scheduler = QueueScheduler.makeForTesting()
				run { $0.start(on: scheduler) }
			}
		}
	}
}
