//
//  SignalSpec.swift
//  ReactiveSwift
//
//  Created by Justin Spahr-Summers on 2015-01-23.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Foundation
import Dispatch

import Nimble
import Quick
@testable import ReactiveSwift

class SignalSpec: QuickSpec {
	override func spec() {
		describe("init") {
			var testScheduler: TestScheduler!

			beforeEach {
				testScheduler = TestScheduler()
			}

			it("should run the generator immediately") {
				var didRunGenerator = false
				_ = Signal<AnyObject, Never> { observer, _ in
					didRunGenerator = true
				}

				expect(didRunGenerator) == true
			}

			it("should forward events to observers") {
				let numbers = [ 1, 2, 5 ]

				let signal: Signal<Int, Never> = Signal { observer, _ in
					testScheduler.schedule {
						for number in numbers {
							observer.send(value: number)
						}
						observer.sendCompleted()
					}
				}

				var fromSignal: [Int] = []
				var completed = false

				signal.observe { event in
					switch event {
					case let .value(number):
						fromSignal.append(number)
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(completed) == false
				expect(fromSignal).to(beEmpty())

				testScheduler.run()

				expect(completed) == true
				expect(fromSignal) == numbers
			}

			it("should dispose of returned disposable upon error") {
				let disposable = AnyDisposable()

				let signal: Signal<AnyObject, TestError> = Signal { observer, lifetime in
					testScheduler.schedule {
						observer.send(error: TestError.default)
					}
					lifetime += disposable
				}

				var errored = false

				signal.observeFailed { _ in errored = true }

				expect(errored) == false
				expect(disposable.isDisposed) == false

				testScheduler.run()

				expect(errored) == true
				expect(disposable.isDisposed) == true
			}

			it("should dispose of returned disposable upon completion") {
				let disposable = AnyDisposable()
				
				let signal: Signal<AnyObject, Never> = Signal { observer, lifetime in
					testScheduler.schedule {
						observer.sendCompleted()
					}
					lifetime += disposable
				}

				var completed = false

				signal.observeCompleted { completed = true }

				expect(completed) == false
				expect(disposable.isDisposed) == false

				testScheduler.run()

				expect(completed) == true
				expect(disposable.isDisposed) == true
			}

			it("should dispose of returned disposable upon interrupted") {
				let disposable = AnyDisposable()

				let signal: Signal<AnyObject, Never> = Signal { observer, lifetime in
					testScheduler.schedule {
						observer.sendInterrupted()
					}
					lifetime += disposable
				}

				var interrupted = false
				signal.observeInterrupted {
					interrupted = true
				}

				expect(interrupted) == false
				expect(disposable.isDisposed) == false

				testScheduler.run()

				expect(interrupted) == true
				expect(disposable.isDisposed) == true
			}

			it("should dispose of the returned disposable if the signal has interrupted in the generator") {
				let disposable = AnyDisposable()

				let signal: Signal<AnyObject, Never> = Signal { observer, lifetime in
					observer.sendInterrupted()
					expect(disposable.isDisposed) == false
					lifetime += disposable
				}

				withExtendedLifetime(signal) {
					expect(disposable.isDisposed) == true
				}
			}

			it("should dispose of the returned disposable if the signal has completed in the generator") {
				let disposable = AnyDisposable()

				let signal: Signal<AnyObject, Never> = Signal { observer, lifetime in
					observer.sendCompleted()
					expect(disposable.isDisposed) == false
					lifetime += disposable
				}

				withExtendedLifetime(signal) {
					expect(disposable.isDisposed) == true
				}
			}

			it("should dispose of the returned disposable if the signal has failed in the generator") {
				let disposable = AnyDisposable()

				let signal: Signal<AnyObject, TestError> = Signal { observer, lifetime in
					observer.send(error: .default)
					expect(disposable.isDisposed) == false
					lifetime += disposable
				}

				withExtendedLifetime(signal) {
					expect(disposable.isDisposed) == true
				}
			}
		}

		describe("Signal.empty") {
			it("should interrupt its observers without emitting any value") {
				let signal = Signal<(), Never>.empty

				var hasUnexpectedEventsEmitted = false
				var signalInterrupted = false

				signal.observe { event in
					switch event {
					case .value, .failed, .completed:
						hasUnexpectedEventsEmitted = true
					case .interrupted:
						signalInterrupted = true
					}
				}

				expect(hasUnexpectedEventsEmitted) == false
				expect(signalInterrupted) == true
			}
		}

		describe("reentrantUnserialized") {
			#if arch(x86_64) && canImport(Darwin)
			it("should not crash") {
				let (signal, observer) = Signal<Int, Never>.reentrantUnserializedPipe()
				var values: [Int] = []

				signal
					.take(first: 5)
					.map { $0 + 1 }
					.on { values.append($0) }
					.observeValues(observer.send(value:))

				expect {
					observer.send(value: 1)
				}.toNot(throwAssertion())

				expect(values) == [2, 3, 4, 5, 6]
			}
			#endif

			it("should drain enqueued values in submission order after the observer callout has completed") {
				let (signal, observer) = Signal<Int, Never>.reentrantUnserializedPipe()
				var values: [Int] = []

				signal
					.take(first: 1)
					.observeValues { _ in
						observer.send(value: 10)
						observer.send(value: 100)
				}

				signal
					.take(first: 1)
					.observeValues { _ in
						observer.send(value: 20)
						observer.send(value: 200)
				}

				signal.observeValues { values.append($0) }

				observer.send(value: 0)
				expect(values) == [0, 10, 100, 20, 200]
			}
		}

		describe("Signal.pipe") {
			it("should forward events to observers") {
				let (signal, observer) = Signal<Int, Never>.pipe()

				var fromSignal: [Int] = []
				var completed = false

				signal.observe { event in
					switch event {
					case let .value(number):
						fromSignal.append(number)
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(fromSignal).to(beEmpty())
				expect(completed) == false

				observer.send(value: 1)
				expect(fromSignal) == [ 1 ]

				observer.send(value: 2)
				expect(fromSignal) == [ 1, 2 ]

				expect(completed) == false
				observer.sendCompleted()
				expect(completed) == true
			}

			it("should dispose the supplied disposable when the signal terminates") {
				let disposable = AnyDisposable()
				let (signal, observer) = Signal<(), Never>.pipe(disposable: disposable)

				withExtendedLifetime(signal) {
					expect(disposable.isDisposed) == false

					observer.sendCompleted()
					expect(disposable.isDisposed) == true
				}
			}

			context("memory") {
				it("should not crash allocating memory with a few observers") {
					let (signal, observer) = Signal<Int, Never>.pipe()

					#if os(Linux)
						func autoreleasepool(invoking code: () -> Void) {
							code()
						}
					#endif

					withExtendedLifetime(observer) {
						for _ in 0..<50 {
							autoreleasepool {
								let disposable = signal.observe { _ in }

								disposable!.dispose()
							}
						}
					}
				}
			}
		}

		describe("interruption") {
			it("should not send events after sending an interrupted event") {
				let queue = DispatchQueue.global(qos: .userInitiated)

				let (signal, observer) = Signal<Int, Never>.pipe()

				var hasSlept = false
				var events: [Signal<Int, Never>.Event] = []

				// Used to synchronize the `interrupt` sender to only act after the
				// chosen observer has started sending its event, but before it is done.
				let semaphore = DispatchSemaphore(value: 0)

				signal.observe { event in
					if !hasSlept {
						semaphore.signal()
						// 100000 us = 0.1 s
						usleep(100000)
						hasSlept = true
					}
					events.append(event)
				}

				let group = DispatchGroup()

				DispatchQueue.concurrentPerform(iterations: 10) { index in
					queue.async(group: group) {
						observer.send(value: index)
					}

					if index == 0 {
						semaphore.wait()
						observer.sendInterrupted()
					}
				}

				group.wait()

				expect(events.count) == 2
				expect(events.first?.value).toNot(beNil())
				expect(events.last?.isTerminating) == true
			}

			it("should interrupt concurrently") {
				let queue = DispatchQueue.global(qos: .userInitiated)
				let counter = Atomic<Int>(0)
				let executionCounter = Atomic<Int>(0)

				let iterations = 1000
				let group = DispatchGroup()

				queue.async(group: group) {
					DispatchQueue.concurrentPerform(iterations: iterations) { _ in
						let (signal, observer) = Signal<(), Never>.pipe()

						signal.observeInterrupted { counter.modify { $0 += 1 } }

						// Used to synchronize the `value` sender and the `interrupt`
						// sender, giving a slight priority to the former.
						let semaphore = DispatchSemaphore(value: 0)

						queue.async(group: group) {
							semaphore.signal()
							observer.send(value: ())
							executionCounter.modify { $0 += 1 }
						}

						queue.async(group: group) {
							semaphore.wait()
							observer.sendInterrupted()
							executionCounter.modify { $0 += 1 }
						}
					}
				}

				group.wait()

				expect(executionCounter.value) == iterations * 2
				expect(counter.value).toEventually(equal(iterations), timeout: .seconds(5))
			}
		}

		describe("observe") {
			var testScheduler: TestScheduler!

			beforeEach {
				testScheduler = TestScheduler()
			}

			it("should stop forwarding events when disposed") {
				let disposable = AnyDisposable()

				let signal: Signal<Int, Never> = Signal { observer, lifetime in
					testScheduler.schedule {
						for number in [ 1, 2 ] {
							observer.send(value: number)
						}
						observer.sendCompleted()
						observer.send(value: 4)
					}
					lifetime += disposable
				}

				var fromSignal: [Int] = []
				signal.observeValues { number in
					fromSignal.append(number)
				}

				expect(disposable.isDisposed) == false
				expect(fromSignal).to(beEmpty())

				testScheduler.run()

				expect(disposable.isDisposed) == true
				expect(fromSignal) == [ 1, 2 ]
			}

			it("should not trigger side effects") {
				var runCount = 0
				let signal: Signal<(), Never> = Signal { observer, _ in
					runCount += 1
				}

				expect(runCount) == 1

				signal.observe(Signal<(), Never>.Observer())
				expect(runCount) == 1
			}

			it("should release observer after termination") {
				weak var testStr: NSMutableString?
				let (signal, observer) = Signal<Int, Never>.pipe()

				let test = {
					let innerStr = NSMutableString(string: "")
					signal.observeValues { value in
						innerStr.append("\(value)")
					}
					testStr = innerStr
				}
				test()

				observer.send(value: 1)
				expect(testStr) == "1"
				observer.send(value: 2)
				expect(testStr) == "12"

				observer.sendCompleted()
				expect(testStr).to(beNil())
			}

			it("should release observer after interruption") {
				weak var testStr: NSMutableString?
				let (signal, observer) = Signal<Int, Never>.pipe()

				let test = {
					let innerStr = NSMutableString(string: "")
					signal.observeValues { value in
						innerStr.append("\(value)")
					}

					testStr = innerStr
				}

				test()

				observer.send(value: 1)
				expect(testStr) == "1"

				observer.send(value: 2)
				expect(testStr) == "12"

				observer.sendInterrupted()
				expect(testStr).to(beNil())
			}
		}

		describe("trailing closure") {
			it("receives next values") {
				var values = [Int]()
				let (signal, observer) = Signal<Int, Never>.pipe()

				signal.observeValues { value in
					values.append(value)
				}

				observer.send(value: 1)
				expect(values) == [1]
			}

			it("receives results") {
				let (signal, observer) = Signal<Int, TestError>.pipe()

				var results: [Result<Int, TestError>] = []
				signal.observeResult { results.append($0) }

				observer.send(value: 1)
				observer.send(value: 2)
				observer.send(value: 3)
				observer.send(error: .default)

				observer.sendCompleted()

				expect(results).to(haveCount(4))
				expect(results[0].value) == 1
				expect(results[1].value) == 2
				expect(results[2].value) == 3
				expect(results[3].error) == .default
			}
		}

		describe("map") {
			it("should transform the values of the signal") {
				let (signal, observer) = Signal<Int, Never>.pipe()
				let mappedSignal = signal.map { String($0 + 1) }

				var lastValue: String?

				mappedSignal.observeValues {
					lastValue = $0
					return
				}

				expect(lastValue).to(beNil())

				observer.send(value: 0)
				expect(lastValue) == "1"

				observer.send(value: 1)
				expect(lastValue) == "2"
			}

			it("should replace the values of the signal to constant new value") {
				let (signal, observer) = Signal<String, Never>.pipe()
				let mappedSignal = signal.map(value: 1)

				var lastValue: Int?
				mappedSignal.observeValues {
					lastValue = $0
				}

				expect(lastValue).to(beNil())

				observer.send(value: "foo")
				expect(lastValue) == 1

				observer.send(value: "foobar")
				expect(lastValue) == 1
			}
			
			it("should support key paths") {
				let (signal, observer) = Signal<String, Never>.pipe()
				let mappedSignal = signal.map(\String.count)
				
				var lastValue: Int?
				mappedSignal.observeValues {
					lastValue = $0
				}
				
				expect(lastValue).to(beNil())
				
				observer.send(value: "foo")
				expect(lastValue) == 3
				
				observer.send(value: "foobar")
				expect(lastValue) == 6
			}
		}

		describe("mapError") {
			it("should transform the errors of the signal") {
				let (signal, observer) = Signal<Int, TestError>.pipe()
				let producerError = NSError(domain: "com.reactivecocoa.errordomain", code: 100, userInfo: nil)
				var error: NSError?

				signal
					.mapError { _ in producerError }
					.observeFailed { err in error = err }

				expect(error).to(beNil())

				observer.send(error: TestError.default)
				expect(error) == producerError
			}
		}

		describe("lazyMap") {
			describe("with a scheduled binding") {
				var token: Lifetime.Token!
				var lifetime: Lifetime!
				var destination: [String] = []
				var tupleSignal: Signal<(character: String, other: Int), Never>!
				var tupleObserver: Signal<(character: String, other: Int), Never>.Observer!
				var theLens: Signal<String, Never>!
				var getterCounter: Int = 0
				var lensScheduler: TestScheduler!
				var targetScheduler: TestScheduler!
				var target: BindingTarget<String>!

				beforeEach {
					destination = []
					token = Lifetime.Token()
					lifetime = Lifetime(token)

					let (producer, observer) = Signal<(character: String, other: Int), Never>.pipe()
					tupleSignal = producer
					tupleObserver = observer

					lensScheduler = TestScheduler()
					targetScheduler = TestScheduler()

					getterCounter = 0
					theLens = tupleSignal.lazyMap(on: lensScheduler) { (tuple: (character: String, other: Int)) -> String in
						getterCounter += 1
						return tuple.character
					}

					target = BindingTarget<String>(on: targetScheduler, lifetime: lifetime) {
						destination.append($0)
					}

					target <~ theLens
				}

				it("should not propagate values until scheduled") {
					// Send a value along
					tupleObserver.send(value: (character: "🎃", other: 42))

					// The destination should not change value, and the getter
					// should not have evaluated yet, as neither has been scheduled
					expect(destination) == []
					expect(getterCounter) == 0

					// Advance both schedulers
					lensScheduler.advance()
					targetScheduler.advance()

					// The destination receives the previously-sent value, and the
					// getter obviously evaluated
					expect(destination) == ["🎃"]
					expect(getterCounter) == 1
				}

				it("should evaluate the getter only when scheduled") {
					// Send a value along
					tupleObserver.send(value: (character: "🎃", other: 42))

					// The destination should not change value, and the getter
					// should not have evaluated yet, as neither has been scheduled
					expect(destination) == []
					expect(getterCounter) == 0

					// When the getter's scheduler advances, the getter should
					// be evaluated, but the destination still shouldn't accept
					// the new value
					lensScheduler.advance()
					expect(getterCounter) == 1
					expect(destination) == []

					// Sending other values along shouldn't evaluate the getter
					tupleObserver.send(value: (character: "😾", other: 42))
					tupleObserver.send(value: (character: "🍬", other: 13))
					tupleObserver.send(value: (character: "👻", other: 17))
					expect(getterCounter) == 1
					expect(destination) == []

					// Push the scheduler along for the lens, and the getter
					// should evaluate
					lensScheduler.advance()
					expect(getterCounter) == 2

					// ...but the destination still won't receive the value
					expect(destination) == []

					// Finally, pushing the target scheduler along will
					// propagate only the first and last values
					targetScheduler.advance()
					expect(getterCounter) == 2
					expect(destination) == ["🎃", "👻"]
				}
			}
		}

		describe("filter") {
			it("should omit values from the signal") {
				let (signal, observer) = Signal<Int, Never>.pipe()
				let mappedSignal = signal.filter { $0 % 2 == 0 }

				var lastValue: Int?

				mappedSignal.observeValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.send(value: 0)
				expect(lastValue) == 0

				observer.send(value: 1)
				expect(lastValue) == 0

				observer.send(value: 2)
				expect(lastValue) == 2
			}
		}

		describe("compactMap") {
			it("should omit values from the signal that are nil after the transformation") {
				let (signal, observer) = Signal<String, Never>.pipe()
				let mappedSignal: Signal<Int, Never> = signal.compactMap(Int.init)

				var lastValue: Int?

				mappedSignal.observeValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.send(value: "0")
				expect(lastValue) == 0

				observer.send(value: "1")
				expect(lastValue) == 1

				observer.send(value: "A")
				expect(lastValue) == 1
			}

			it("should stop emiting values after an error") {
				let (signal, observer) = Signal<String, TestError>.pipe()
				let mappedSignal: Signal<Int, TestError> = signal.compactMap(Int.init)

				var lastValue: Int?

				mappedSignal.observeResult { result in
					if let value = result.value {
						lastValue = value
					}
				}

				expect(lastValue).to(beNil())

				observer.send(value: "0")
				expect(lastValue) == 0

				observer.send(error: .default)

				observer.send(value: "1")
				expect(lastValue) == 0
			}

			it("should stop emiting values after a complete") {
				let (signal, observer) = Signal<String, Never>.pipe()
				let mappedSignal: Signal<Int, Never> = signal.compactMap(Int.init)

				var lastValue: Int?

				mappedSignal.observeValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.send(value: "0")
				expect(lastValue) == 0

				observer.sendCompleted()

				observer.send(value: "1")
				expect(lastValue) == 0
			}

			it("should send completed") {
				let (signal, observer) = Signal<String, Never>.pipe()
				let mappedSignal: Signal<Int, Never> = signal.compactMap(Int.init)

				var completed: Bool = false

				mappedSignal.observeCompleted { completed = true }
				observer.sendCompleted()

				expect(completed) == true
			}

			it("should send failure") {
				let (signal, observer) = Signal<String, TestError>.pipe()
				let mappedSignal: Signal<Int, TestError> = signal.compactMap(Int.init)

				var failure: TestError?

				mappedSignal.observeFailed { failure = $0 }
				observer.send(error: .error1)

				expect(failure) == .error1
			}
		}

		describe("skipNil") {
			it("should forward only non-nil values") {
				let (signal, observer) = Signal<Int?, Never>.pipe()
				let mappedSignal = signal.skipNil()

				var lastValue: Int?

				mappedSignal.observeValues { lastValue = $0 }
				expect(lastValue).to(beNil())

				observer.send(value: nil)
				expect(lastValue).to(beNil())

				observer.send(value: 1)
				expect(lastValue) == 1

				observer.send(value: nil)
				expect(lastValue) == 1

				observer.send(value: 2)
				expect(lastValue) == 2
			}
		}

		describe("scan(_:_:)") {
			it("should incrementally accumulate a value") {
				let (baseSignal, observer) = Signal<String, Never>.pipe()
				let signal = baseSignal.scan("", +)

				var lastValue: String?

				signal.observeValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.send(value: "a")
				expect(lastValue) == "a"

				observer.send(value: "bb")
				expect(lastValue) == "abb"
			}
		}

		describe("scan(into:_:)") {
			it("should incrementally accumulate a value") {
				let (baseSignal, observer) = Signal<String, Never>.pipe()
				let signal = baseSignal.scan(into: "") { $0 += $1 }

				var lastValue: String?

				signal.observeValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.send(value: "a")
				expect(lastValue) == "a"

				observer.send(value: "bb")
				expect(lastValue) == "abb"
			}
		}

		describe("scanMap(_:_:)") {
			it("should update state and output separately") {
				let (baseSignal, observer) = Signal<Int, Never>.pipe()
				let signal = baseSignal.scanMap(false) { state, value -> (Bool, String) in
					return (true, state ? "\(value)" : "initial")
				}

				var lastValue: String?

				signal.observeValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.send(value: 1)
				expect(lastValue) == "initial"

				observer.send(value: 2)
				expect(lastValue) == "2"

				observer.send(value: 3)
				expect(lastValue) == "3"
			}
		}

		describe("scanMap(into:_:)") {
			it("should update state and output separately") {
				let (baseSignal, observer) = Signal<Int, Never>.pipe()
				let signal = baseSignal.scanMap(into: false) { (state: inout Bool, value: Int) -> String in
					defer { state = true }
					return state ? "\(value)" : "initial"
				}

				var lastValue: String?

				signal.observeValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.send(value: 1)
				expect(lastValue) == "initial"

				observer.send(value: 2)
				expect(lastValue) == "2"

				observer.send(value: 3)
				expect(lastValue) == "3"
			}
		}

		describe("reduce(_:_:)") {
			it("should accumulate one value") {
				let (baseSignal, observer) = Signal<Int, Never>.pipe()
				let signal = baseSignal.reduce(1, +)

				var lastValue: Int?
				var completed = false

				signal.observe { event in
					switch event {
					case let .value(value):
						lastValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(lastValue).to(beNil())

				observer.send(value: 1)
				expect(lastValue).to(beNil())

				observer.send(value: 2)
				expect(lastValue).to(beNil())

				expect(completed) == false
				observer.sendCompleted()
				expect(completed) == true

				expect(lastValue) == 4
			}

			it("should send the initial value if none are received") {
				let (baseSignal, observer) = Signal<Int, Never>.pipe()
				let signal = baseSignal.reduce(1, +)

				var lastValue: Int?
				var completed = false

				signal.observe { event in
					switch event {
					case let .value(value):
						lastValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(lastValue).to(beNil())
				expect(completed) == false

				observer.sendCompleted()

				expect(lastValue) == 1
				expect(completed) == true
			}
		}

		describe("reduce(into:_:)") {
			it("should accumulate one value") {
				let (baseSignal, observer) = Signal<Int, Never>.pipe()
				let signal = baseSignal.reduce(into: 1) { $0 += $1 }

				var lastValue: Int?
				var completed = false

				signal.observe { event in
					switch event {
					case let .value(value):
						lastValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(lastValue).to(beNil())

				observer.send(value: 1)
				expect(lastValue).to(beNil())

				observer.send(value: 2)
				expect(lastValue).to(beNil())

				expect(completed) == false
				observer.sendCompleted()
				expect(completed) == true

				expect(lastValue) == 4
			}

			it("should send the initial value if none are received") {
				let (baseSignal, observer) = Signal<Int, Never>.pipe()
				let signal = baseSignal.reduce(into: 1) { $0 += $1 }

				var lastValue: Int?
				var completed = false

				signal.observe { event in
					switch event {
					case let .value(value):
						lastValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(lastValue).to(beNil())
				expect(completed) == false

				observer.sendCompleted()

				expect(lastValue) == 1
				expect(completed) == true
			}
		}

		describe("skip") {
			it("should skip initial values") {
				let (baseSignal, observer) = Signal<Int, Never>.pipe()
				let signal = baseSignal.skip(first: 1)

				var lastValue: Int?
				signal.observeValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.send(value: 1)
				expect(lastValue).to(beNil())

				observer.send(value: 2)
				expect(lastValue) == 2
			}

			it("should not skip any values when 0") {
				let (baseSignal, observer) = Signal<Int, Never>.pipe()
				let signal = baseSignal.skip(first: 0)

				var lastValue: Int?
				signal.observeValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.send(value: 1)
				expect(lastValue) == 1

				observer.send(value: 2)
				expect(lastValue) == 2
			}
		}

		describe("skipRepeats") {
			it("should skip duplicate Equatable values") {
				let (baseSignal, observer) = Signal<Bool, Never>.pipe()
				let signal = baseSignal.skipRepeats()

				var values: [Bool] = []
				signal.observeValues { values.append($0) }

				expect(values) == []

				observer.send(value: true)
				expect(values) == [ true ]

				observer.send(value: true)
				expect(values) == [ true ]

				observer.send(value: false)
				expect(values) == [ true, false ]

				observer.send(value: true)
				expect(values) == [ true, false, true ]
			}

			it("should skip values according to a predicate") {
				let (baseSignal, observer) = Signal<String, Never>.pipe()
				let signal = baseSignal.skipRepeats { $0.count == $1.count }

				var values: [String] = []
				signal.observeValues { values.append($0) }

				expect(values) == []

				observer.send(value: "a")
				expect(values) == [ "a" ]

				observer.send(value: "b")
				expect(values) == [ "a" ]

				observer.send(value: "cc")
				expect(values) == [ "a", "cc" ]

				observer.send(value: "d")
				expect(values) == [ "a", "cc", "d" ]
			}

			it("should not store strong reference to previously passed items") {
				var disposedItems: [Bool] = []

				struct Item {
					let payload: Bool
					let disposable: ScopedDisposable<AnyDisposable>
				}

				func item(_ payload: Bool) -> Item {
					return Item(
						payload: payload,
						disposable: ScopedDisposable(AnyDisposable { disposedItems.append(payload) })
					)
				}

				let (baseSignal, observer) = Signal<Item, Never>.pipe()
				baseSignal.skipRepeats { $0.payload == $1.payload }.observeValues { _ in }

				observer.send(value: item(true))
				expect(disposedItems) == []

				observer.send(value: item(false))
				expect(disposedItems) == [ true ]

				observer.send(value: item(false))
				expect(disposedItems) == [ true, false ]

				observer.send(value: item(true))
				expect(disposedItems) == [ true, false, false ]

				observer.sendCompleted()
				expect(disposedItems) == [ true, false, false, true ]
			}
		}

		describe("uniqueValues") {
			it("should skip values that have been already seen") {
				let (baseSignal, observer) = Signal<String, Never>.pipe()
				let signal = baseSignal.uniqueValues()

				var values: [String] = []
				signal.observeValues { values.append($0) }

				expect(values) == []

				observer.send(value: "a")
				expect(values) == [ "a" ]

				observer.send(value: "b")
				expect(values) == [ "a", "b" ]

				observer.send(value: "a")
				expect(values) == [ "a", "b" ]

				observer.send(value: "b")
				expect(values) == [ "a", "b" ]

				observer.send(value: "c")
				expect(values) == [ "a", "b", "c" ]

				observer.sendCompleted()
				expect(values) == [ "a", "b", "c" ]
			}
		}

		describe("skipWhile") {
			var signal: Signal<Int, Never>!
			var observer: Signal<Int, Never>.Observer!

			var lastValue: Int?

			beforeEach {
				let (baseSignal, incomingObserver) = Signal<Int, Never>.pipe()

				signal = baseSignal.skip { $0 < 2 }
				observer = incomingObserver
				lastValue = nil

				signal.observeValues { lastValue = $0 }
			}

			it("should skip while the predicate is true") {
				expect(lastValue).to(beNil())

				observer.send(value: 1)
				expect(lastValue).to(beNil())

				observer.send(value: 2)
				expect(lastValue) == 2

				observer.send(value: 0)
				expect(lastValue) == 0
			}

			it("should not skip any values when the predicate starts false") {
				expect(lastValue).to(beNil())

				observer.send(value: 3)
				expect(lastValue) == 3

				observer.send(value: 1)
				expect(lastValue) == 1
			}
		}

		describe("skipUntil") {
			var signal: Signal<Int, Never>!
			var observer: Signal<Int, Never>.Observer!
			var triggerObserver: Signal<(), Never>.Observer!

			var lastValue: Int? = nil

			beforeEach {
				let (baseSignal, incomingObserver) = Signal<Int, Never>.pipe()
				let (triggerSignal, incomingTriggerObserver) = Signal<(), Never>.pipe()

				signal = baseSignal.skip(until: triggerSignal)
				observer = incomingObserver
				triggerObserver = incomingTriggerObserver

				lastValue = nil

				signal.observe { event in
					switch event {
					case let .value(value):
						lastValue = value
					default:
						break
					}
				}
			}

			it("should skip values until the trigger fires") {
				expect(lastValue).to(beNil())

				observer.send(value: 1)
				expect(lastValue).to(beNil())

				observer.send(value: 2)
				expect(lastValue).to(beNil())

				triggerObserver.send(value: ())
				observer.send(value: 0)
				expect(lastValue) == 0
			}

			it("should skip values until the trigger completes") {
				expect(lastValue).to(beNil())

				observer.send(value: 1)
				expect(lastValue).to(beNil())

				observer.send(value: 2)
				expect(lastValue).to(beNil())

				triggerObserver.sendCompleted()
				observer.send(value: 0)
				expect(lastValue) == 0
			}
		}

		describe("take") {
			it("should take initial values") {
				let (baseSignal, observer) = Signal<Int, Never>.pipe()
				let signal = baseSignal.take(first: 2)

				var lastValue: Int?
				var completed = false
				signal.observe { event in
					switch event {
					case let .value(value):
						lastValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(lastValue).to(beNil())
				expect(completed) == false

				observer.send(value: 1)
				expect(lastValue) == 1
				expect(completed) == false

				observer.send(value: 2)
				expect(lastValue) == 2
				expect(completed) == true
			}

			it("should complete immediately after taking given number of values") {
				let numbers = [ 1, 2, 4, 4, 5 ]
				let testScheduler = TestScheduler()

				var signal: Signal<Int, Never> = Signal { observer, _ in
					testScheduler.schedule {
						for number in numbers {
							observer.send(value: number)
						}
					}
				}

				var completed = false

				signal = signal.take(first: numbers.count)
				signal.observeCompleted { completed = true }

				expect(completed) == false
				testScheduler.run()
				expect(completed) == true
			}

			it("should interrupt when 0") {
				let numbers = [ 1, 2, 4, 4, 5 ]
				let testScheduler = TestScheduler()

				let signal: Signal<Int, Never> = Signal { observer, _ in
					testScheduler.schedule {
						for number in numbers {
							observer.send(value: number)
						}
					}
				}

				var result: [Int] = []
				var interrupted = false

				signal
				.take(first: 0)
				.observe { event in
					switch event {
					case let .value(number):
						result.append(number)
					case .interrupted:
						interrupted = true
					default:
						break
					}
				}

				expect(interrupted) == true

				testScheduler.run()
				expect(result).to(beEmpty())
			}
		}

		describe("collect") {
			it("should collect all values") {
				let (original, observer) = Signal<Int, Never>.pipe()
				let signal = original.collect()
				let expectedResult = [ 1, 2, 3 ]

				var result: [Int]?

				signal.observeValues { value in
					expect(result).to(beNil())
					result = value
				}

				for number in expectedResult {
					observer.send(value: number)
				}

				expect(result).to(beNil())
				observer.sendCompleted()
				expect(result) == expectedResult
			}

			it("should complete with an empty array if there are no values") {
				let (original, observer) = Signal<Int, Never>.pipe()
				let signal = original.collect()

				var result: [Int]?

				signal.observeValues { result = $0 }

				expect(result).to(beNil())
				observer.sendCompleted()
				expect(result) == []
			}

			it("should forward errors") {
				let (original, observer) = Signal<Int, TestError>.pipe()
				let signal = original.collect()

				var error: TestError?

				signal.observeFailed { error = $0 }

				expect(error).to(beNil())
				observer.send(error: .default)
				expect(error) == TestError.default
			}

			it("should collect an exact count of values") {
				let (original, observer) = Signal<Int, Never>.pipe()

				let signal = original.collect(count: 3)

				var observedValues: [[Int]] = []

				signal.observeValues { value in
					observedValues.append(value)
				}

				var expectation: [[Int]] = []

				for i in 1...7 {
					observer.send(value: i)

					if i % 3 == 0 {
						expectation.append([Int]((i - 2)...i))
						expect(observedValues._bridgeToObjectiveC()) == expectation._bridgeToObjectiveC()
					} else {
						expect(observedValues._bridgeToObjectiveC()) == expectation._bridgeToObjectiveC()
					}
				}

				observer.sendCompleted()

				expectation.append([7])
				expect(observedValues._bridgeToObjectiveC()) == expectation._bridgeToObjectiveC()
			}

			it("should collect values until it matches a certain value") {
				let (original, observer) = Signal<Int, Never>.pipe()

				let signal = original.collect { _, value in value != 5 }

				var expectedValues = [
					[5, 5],
					[42, 5],
				]

				signal.observeValues { value in
					expect(value) == expectedValues.removeFirst()
				}

				signal.observeCompleted {
					expect(expectedValues._bridgeToObjectiveC()) == []
				}

				expectedValues
					.flatMap { $0 }
					.forEach(observer.send(value:))

				observer.sendCompleted()
			}

			it("should collect values until it matches a certain condition on values") {
				let (original, observer) = Signal<Int, Never>.pipe()

				let signal = original.collect { values in values.reduce(0, +) == 10 }

				var expectedValues = [
					[1, 2, 3, 4],
					[5, 6, 7, 8, 9],
				]

				signal.observeValues { value in
					expect(value) == expectedValues.removeFirst()
				}

				signal.observeCompleted {
					expect(expectedValues._bridgeToObjectiveC()) == []
				}

				expectedValues
					.flatMap { $0 }
					.forEach(observer.send(value:))

				observer.sendCompleted()
			}
		}

		describe("takeUntil") {
			var signal: Signal<Int, Never>!
			var observer: Signal<Int, Never>.Observer!
			var triggerObserver: Signal<(), Never>.Observer!

			var lastValue: Int? = nil
			var completed: Bool = false

			beforeEach {
				let (baseSignal, incomingObserver) = Signal<Int, Never>.pipe()
				let (triggerSignal, incomingTriggerObserver) = Signal<(), Never>.pipe()

				signal = baseSignal.take(until: triggerSignal)
				observer = incomingObserver
				triggerObserver = incomingTriggerObserver

				lastValue = nil
				completed = false

				signal.observe { event in
					switch event {
					case let .value(value):
						lastValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}
			}

			it("should take values until the trigger fires") {
				expect(lastValue).to(beNil())

				observer.send(value: 1)
				expect(lastValue) == 1

				observer.send(value: 2)
				expect(lastValue) == 2

				expect(completed) == false
				triggerObserver.send(value: ())
				expect(completed) == true
			}

			it("should take values until the trigger completes") {
				expect(lastValue).to(beNil())

				observer.send(value: 1)
				expect(lastValue) == 1

				observer.send(value: 2)
				expect(lastValue) == 2

				expect(completed) == false
				triggerObserver.sendCompleted()
				expect(completed) == true
			}

			it("should complete if the trigger fires immediately") {
				expect(lastValue).to(beNil())
				expect(completed) == false

				triggerObserver.send(value: ())

				expect(completed) == true
				expect(lastValue).to(beNil())
			}
		}

		describe("takeUntilReplacement") {
			var signal: Signal<Int, Never>!
			var observer: Signal<Int, Never>.Observer!
			var replacementObserver: Signal<Int, Never>.Observer!

			var lastValue: Int? = nil
			var completed: Bool = false

			beforeEach {
				let (baseSignal, incomingObserver) = Signal<Int, Never>.pipe()
				let (replacementSignal, incomingReplacementObserver) = Signal<Int, Never>.pipe()

				signal = baseSignal.take(untilReplacement: replacementSignal)
				observer = incomingObserver
				replacementObserver = incomingReplacementObserver

				lastValue = nil
				completed = false

				signal.observe { event in
					switch event {
					case let .value(value):
						lastValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}
			}

			it("should take values from the original then the replacement") {
				expect(lastValue).to(beNil())
				expect(completed) == false

				observer.send(value: 1)
				expect(lastValue) == 1

				observer.send(value: 2)
				expect(lastValue) == 2

				replacementObserver.send(value: 3)

				expect(lastValue) == 3
				expect(completed) == false

				observer.send(value: 4)

				expect(lastValue) == 3
				expect(completed) == false

				replacementObserver.send(value: 5)
				expect(lastValue) == 5

				expect(completed) == false
				replacementObserver.sendCompleted()
				expect(completed) == true
			}
		}

		describe("takeWhile") {
			var signal: Signal<Int, Never>!
			var observer: Signal<Int, Never>.Observer!

			beforeEach {
				let (baseSignal, incomingObserver) = Signal<Int, Never>.pipe()
				signal = baseSignal.take(while: { $0 <= 4 })
				observer = incomingObserver
			}

			it("should take while the predicate is true") {
				var latestValue: Int!
				var completed = false

				signal.observe { event in
					switch event {
					case let .value(value):
						latestValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}

				for value in -1...4 {
					observer.send(value: value)
					expect(latestValue) == value
					expect(completed) == false
				}

				observer.send(value: 5)
				expect(latestValue) == 4
				expect(completed) == true
			}

			it("should complete if the predicate starts false") {
				var latestValue: Int?
				var completed = false

				signal.observe { event in
					switch event {
					case let .value(value):
						latestValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}

				observer.send(value: 5)
				expect(latestValue).to(beNil())
				expect(completed) == true
			}
		}
		
		describe("takeUntil") {
			var signal: Signal<Int, Never>!
			var observer: Signal<Int, Never>.Observer!
			
			beforeEach {
				let (baseSignal, incomingObserver) = Signal<Int, Never>.pipe()
				signal = baseSignal.take(until: { $0 <= 4 })
				observer = incomingObserver
			}
			
			it("should take until the predicate is true") {
				var latestValue: Int!
				var completed = false
				
				signal.observe { event in
					switch event {
					case let .value(value):
						latestValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}
				
				for value in -1...4 {
					observer.send(value: value)
					expect(latestValue) == value
					expect(completed) == false
				}
				
				observer.send(value: 5)
				expect(latestValue) == 5
				expect(completed) == true
				
				observer.send(value: 6)
				expect(latestValue) == 5
			}
			
			it("should take and then complete if the predicate starts false") {
				var latestValue: Int?
				var completed = false
				
				signal.observe { event in
					switch event {
					case let .value(value):
						latestValue = value
					case .completed:
						completed = true
					default:
						break
					}
				}
				
				observer.send(value: 5)
				expect(latestValue) == 5
				expect(completed) == true
			}
		}

		describe("observeOn") {
			it("should send events on the given scheduler") {
				let testScheduler = TestScheduler()
				let (signal, observer) = Signal<Int, Never>.pipe()

				var result: [Int] = []

				signal
					.observe(on: testScheduler)
					.observeValues { result.append($0) }

				observer.send(value: 1)
				observer.send(value: 2)
				expect(result).to(beEmpty())

				testScheduler.run()
				expect(result) == [ 1, 2 ]
			}
		}

		describe("delay") {
			it("should send events on the given scheduler after the interval") {
				let testScheduler = TestScheduler()
				let signal: Signal<Int, Never> = Signal { observer, _ in
					testScheduler.schedule {
						observer.send(value: 1)
					}
					testScheduler.schedule(after: .seconds(5)) {
						observer.send(value: 2)
						observer.sendCompleted()
					}
				}

				var result: [Int] = []
				var completed = false

				signal
					.delay(10, on: testScheduler)
					.observe { event in
						switch event {
						case let .value(number):
							result.append(number)
						case .completed:
							completed = true
						default:
							break
						}
					}

				testScheduler.advance(by: .seconds(4)) // send initial value
				expect(result).to(beEmpty())

				testScheduler.advance(by: .seconds(10)) // send second value and receive first
				expect(result) == [ 1 ]
				expect(completed) == false

				testScheduler.advance(by: .seconds(10)) // send second value and receive first
				expect(result) == [ 1, 2 ]
				expect(completed) == true
			}

			it("should schedule errors immediately") {
				let testScheduler = TestScheduler()
				let signal: Signal<Int, TestError> = Signal { observer, _ in
					testScheduler.schedule {
						observer.send(error: TestError.default)
					}
				}

				var errored = false

				signal
					.delay(10, on: testScheduler)
					.observeFailed { _ in errored = true }

				testScheduler.advance()
				expect(errored) == true
			}
		}

		describe("throttle") {
			var scheduler: TestScheduler!
			var observer: Signal<Int, Never>.Observer!
			var signal: Signal<Int, Never>!

			beforeEach {
				scheduler = TestScheduler()

				let (baseSignal, baseObserver) = Signal<Int, Never>.pipe()
				observer = baseObserver

				signal = baseSignal.throttle(1, on: scheduler)
				expect(signal).notTo(beNil())
			}

			it("should send values on the given scheduler at no less than the interval") {
				var values: [Int] = []
				signal.observeValues { value in
					values.append(value)
				}

				expect(values) == []

				observer.send(value: 0)
				expect(values) == []

				scheduler.advance()
				expect(values) == [ 0 ]

				observer.send(value: 1)
				observer.send(value: 2)
				expect(values) == [ 0 ]

				scheduler.advance(by: .milliseconds(1500))
				expect(values) == [ 0, 2 ]

				scheduler.advance(by: .seconds(3))
				expect(values) == [ 0, 2 ]

				observer.send(value: 3)
				expect(values) == [ 0, 2 ]

				scheduler.advance()
				expect(values) == [ 0, 2, 3 ]

				observer.send(value: 4)
				observer.send(value: 5)
				scheduler.advance()
				expect(values) == [ 0, 2, 3 ]

				scheduler.rewind(by: .seconds(2))
				expect(values) == [ 0, 2, 3 ]

				observer.send(value: 6)
				scheduler.advance()
				expect(values) == [ 0, 2, 3, 6 ]

				observer.send(value: 7)
				observer.send(value: 8)
				scheduler.advance()
				expect(values) == [ 0, 2, 3, 6 ]

				scheduler.run()
				expect(values) == [ 0, 2, 3, 6, 8 ]
			}

			it("should schedule completion immediately") {
				var values: [Int] = []
				var completed = false

				signal.observe { event in
					switch event {
					case let .value(value):
						values.append(value)
					case .completed:
						completed = true
					default:
						break
					}
				}

				observer.send(value: 0)
				scheduler.advance()
				expect(values) == [ 0 ]

				observer.send(value: 1)
				observer.sendCompleted()
				expect(completed) == false

				scheduler.advance()
				expect(values) == [ 0 ]
				expect(completed) == true

				scheduler.run()
				expect(values) == [ 0 ]
				expect(completed) == true
			}
		}

		describe("throttle while") {
			var scheduler: ImmediateScheduler!
			var shouldThrottle: MutableProperty<Bool>!
			var observer: Signal<Int, Never>.Observer!
			var signal: Signal<Int, Never>!

			beforeEach {
				scheduler = ImmediateScheduler()
				shouldThrottle = MutableProperty(false)

				let (baseSignal, baseObserver) = Signal<Int, Never>.pipe()
				observer = baseObserver

				signal = baseSignal.throttle(while: shouldThrottle, on: scheduler)
				expect(signal).notTo(beNil())
			}

			it("passes through unthrottled values") {
				var values: [Int] = []
				signal.observeValues { values.append($0) }

				observer.send(value: 1)
				observer.send(value: 2)
				observer.send(value: 3)

				expect(values) == [1, 2, 3]
			}

			it("emits the latest throttled value when resumed") {
				var values: [Int] = []
				signal.observeValues { values.append($0) }

				shouldThrottle.value = true
				observer.send(value: 1)
				observer.send(value: 2)
				shouldThrottle.value = false

				expect(values) == [2]
			}

			it("continues sending values after being resumed") {
				var values: [Int] = []
				signal.observeValues { values.append($0) }

				shouldThrottle.value = true
				observer.send(value: 1)
				shouldThrottle.value = false
				observer.send(value: 2)
				observer.send(value: 3)

				expect(values) == [1, 2, 3]
			}

			it("stays throttled if the property completes while throttled") {
				var values: [Int] = []
				signal.observeValues { values.append($0) }

				shouldThrottle.value = false
				observer.send(value: 1)
				shouldThrottle.value = true
				observer.send(value: 2)
				shouldThrottle = nil
				observer.send(value: 3)

				expect(values) == [1]
			}

			it("stays resumed if the property completes while resumed") {
				var values: [Int] = []
				signal.observeValues { values.append($0) }

				shouldThrottle.value = true
				observer.send(value: 1)
				shouldThrottle.value = false
				observer.send(value: 2)
				shouldThrottle = nil
				observer.send(value: 3)

				expect(values) == [1, 2, 3]
			}

			it("doesn't extend the lifetime of the throttle property") {
				var completed = false
				shouldThrottle.lifetime.observeEnded { completed = true }

				observer.send(value: 1)
				shouldThrottle = nil

				expect(completed) == true
			}
		}

		describe("debounce discarding the latest value when terminated") {
			var scheduler: TestScheduler!
			var observer: Signal<Int, Never>.Observer!
			var signal: Signal<Int, Never>!

			beforeEach {
				scheduler = TestScheduler()

				let (baseSignal, baseObserver) = Signal<Int, Never>.pipe()
				observer = baseObserver

				signal = baseSignal.debounce(1, on: scheduler, discardWhenCompleted: true)
				expect(signal).notTo(beNil())
			}

			it("should send values on the given scheduler once the interval has passed since the last value was sent") {
				var values: [Int] = []
				signal.observeValues { value in
					values.append(value)
				}

				expect(values) == []

				observer.send(value: 0)
				expect(values) == []

				scheduler.advance()
				expect(values) == []

				observer.send(value: 1)
				observer.send(value: 2)
				expect(values) == []

				scheduler.advance(by: .milliseconds(1500))
				expect(values) == [ 2 ]

				scheduler.advance(by: .seconds(3))
				expect(values) == [ 2 ]

				observer.send(value: 3)
				expect(values) == [ 2 ]

				scheduler.advance()
				expect(values) == [ 2 ]

				observer.send(value: 4)
				observer.send(value: 5)
				scheduler.advance()
				expect(values) == [ 2 ]

				scheduler.run()
				expect(values) == [ 2, 5 ]
			}

			it("should schedule completion immediately") {
				var values: [Int] = []
				var completed = false

				signal.observe { event in
					switch event {
					case let .value(value):
						values.append(value)
					case .completed:
						completed = true
					default:
						break
					}
				}

				observer.send(value: 0)
				scheduler.advance()
				expect(values) == []

				observer.send(value: 1)
				observer.sendCompleted()
				expect(completed) == false

				scheduler.advance()
				expect(values) == []
				expect(completed) == true

				scheduler.run()
				expect(values) == []
				expect(completed) == true
			}
		}
		
		describe("debounce without discarding the latest value when terminated") {
			var scheduler: TestScheduler!
			var observer: Signal<Int, Never>.Observer!
			var signal: Signal<Int, Never>!
			
			beforeEach {
				scheduler = TestScheduler()
				
				let (baseSignal, baseObserver) = Signal<Int, Never>.pipe()
				observer = baseObserver
				
				signal = baseSignal.debounce(1, on: scheduler, discardWhenCompleted: false)
				expect(signal).notTo(beNil())
			}
			
			it("should send values on the given scheduler once the interval has passed since the last value was sent") {
				var values: [Int] = []
				signal.observeValues { value in
					values.append(value)
				}
				
				expect(values) == []
				
				observer.send(value: 0)
				expect(values) == []
				
				scheduler.advance()
				expect(values) == []
				
				observer.send(value: 1)
				observer.send(value: 2)
				expect(values) == []
				
				scheduler.advance(by: .milliseconds(1500))
				expect(values) == [ 2 ]
				
				scheduler.advance(by: .seconds(3))
				expect(values) == [ 2 ]
				
				observer.send(value: 3)
				expect(values) == [ 2 ]
				
				scheduler.advance()
				expect(values) == [ 2 ]
				
				observer.send(value: 4)
				observer.send(value: 5)
				scheduler.advance()
				expect(values) == [ 2 ]
				observer.sendCompleted()
				
				scheduler.run()
				expect(values) == [ 2, 5 ]
				
			}
			
			it("should schedule completion after sending the last value") {
				var values: [Int] = []
				var completed = false
				
				signal.observe { event in
					switch event {
					case let .value(value):
						values.append(value)
					case .completed:
						completed = true
					default:
						break
					}
				}
				
				observer.send(value: 0)
				scheduler.advance()
				expect(values) == []
				
				observer.send(value: 1)
				scheduler.advance()
				observer.sendCompleted()
				expect(completed) == false
				
				scheduler.advance()
				expect(values) == []
				expect(completed) == false
				
				scheduler.run()
				expect(values) == [1]
				expect(completed) == true
			}
			
			it("should schedule completion immediately if there is no pending value") {
				var completed = false
				
				signal.observe { event in
					switch event {
					case .completed:
						completed = true
					default:
						break
					}
				}
				
				observer.sendCompleted()
				expect(completed) == false
				scheduler.advance()
				expect(completed) == true
			}
		}
		
		
		describe("collect(every:on:skipEmpty:discardWhenCompleted:) where skipEmpty is false, discardWhenCompleted is false") {
			var scheduler: TestScheduler!
			var observer: Signal<Int, Never>.Observer!
			var signal: Signal<[Int], Never>!
			
			beforeEach {
				scheduler = TestScheduler()
				
				let (baseSignal, baseObserver) = Signal<Int, Never>.pipe()
				observer = baseObserver
				
				signal = baseSignal.collect(every: .seconds(1), on: scheduler, skipEmpty: false, discardWhenCompleted: false)
				expect(signal).notTo(beNil())
			}
			
			it("should send accumulated values on the given scheduler every interval") {
				var values: [[Int]] = []
				signal.observeValues { value in
					values.append(value)
				}
				
				expect(values.count) == 0
				
				observer.send(value: 0)
				expect(values.count) == 0
				
				scheduler.advance()
				expect(values.count) == 0
				
				observer.send(value: 1)
				observer.send(value: 2)
				expect(values.count) == 0
				
				scheduler.advance(by: .milliseconds(1500))
				expect(values.count) == 1
				expect(values[0]) == [ 0, 1, 2 ]
				
				scheduler.advance(by: .seconds(2))
				expect(values.count) == 3
				expect(values[0]) == [ 0, 1, 2 ]
				expect(values[1]) == [ ]
				expect(values[2]) == [ ]
				
				observer.send(value: 3)
				expect(values.count) == 3
				
				scheduler.advance()
				expect(values.count) == 3
				
				observer.send(value: 4)
				observer.send(value: 5)
				scheduler.advance()
				expect(values.count) == 3
				
				scheduler.advance(by: .milliseconds(500))
				expect(values.count) == 4
				expect(values.first) == [ 0, 1, 2 ]
				expect(values.last) == [ 3, 4, 5 ]
				
				observer.sendCompleted()
				expect(values.last) == [ 3, 4, 5 ]
				scheduler.advance(by: .seconds(1))
				expect(values.count) == 5
				expect(values.last) == []
			}
			
			it("should schedule completion correctly") {
				var values: [[Int]] = []
				var completed = false
				
				signal.observe { event in
					switch event {
					case let .value(value):
						values.append(value)
					case .completed:
						completed = true
					default:
						break
					}
				}
				
				observer.send(value: 0)
				scheduler.advance()
				expect(values.count) == 0
				
				observer.send(value: 1)
				observer.sendCompleted()
				expect(completed) == false
				
				scheduler.advance()
				expect(values.count) == 0
				expect(completed) == false
				
				scheduler.advance(by: .seconds(1))
				expect(values.count) == 1
				expect(values.first) == [ 0, 1 ]
				expect(completed) == true
			}
		}
		
		describe("collect(every:on:skipEmpty:discardWhenCompleted:) where skipEmpty is false, discardWhenCompleted is true") {
			var scheduler: TestScheduler!
			var observer: Signal<Int, Never>.Observer!
			var signal: Signal<[Int], Never>!
			
			beforeEach {
				scheduler = TestScheduler()
				
				let (baseSignal, baseObserver) = Signal<Int, Never>.pipe()
				observer = baseObserver
				
				signal = baseSignal.collect(every: .seconds(1), on: scheduler, skipEmpty: false, discardWhenCompleted: true)
				expect(signal).notTo(beNil())
			}
			
			it("should send accumulated values on the given scheduler every interval") {
				var values: [[Int]] = []
				signal.observeValues { value in
					values.append(value)
				}
				
				expect(values.count) == 0
				
				observer.send(value: 0)
				expect(values.count) == 0
				
				scheduler.advance()
				expect(values.count) == 0
				
				observer.send(value: 1)
				observer.send(value: 2)
				expect(values.count) == 0
				
				scheduler.advance(by: .milliseconds(1500))
				expect(values.count) == 1
				expect(values[0]) == [ 0, 1, 2 ]
				
				scheduler.advance(by: .seconds(2))
				expect(values.count) == 3
				expect(values[0]) == [ 0, 1, 2 ]
				expect(values[1]) == [ ]
				expect(values[2]) == [ ]
				
				observer.send(value: 3)
				expect(values.count) == 3
				
				scheduler.advance()
				expect(values.count) == 3
				
				observer.send(value: 4)
				observer.send(value: 5)
				scheduler.advance()
				expect(values.count) == 3
				
				scheduler.advance(by: .milliseconds(500))
				expect(values.count) == 4
				expect(values.first) == [ 0, 1, 2 ]
				expect(values.last) == [ 3, 4, 5 ]
				
				observer.sendCompleted()
				expect(values.last) == [ 3, 4, 5 ]
				scheduler.run()
				expect(values.count) == 4
				expect(values.last) == [ 3, 4, 5 ]
			}
			
			it("should schedule completion correctly") {
				var values: [[Int]] = []
				var completed = false
				
				signal.observe { event in
					switch event {
					case let .value(value):
						values.append(value)
					case .completed:
						completed = true
					default:
						break
					}
				}
				
				observer.send(value: 0)
				scheduler.advance()
				expect(values.count) == 0
				
				observer.send(value: 1)
				observer.sendCompleted()
				expect(completed) == false
				
				scheduler.advance()
				expect(values.count) == 0
				expect(completed) == true
				
				scheduler.run()
				expect(values.count) == 0
				expect(completed) == true
			}
		}
		
		describe("collect(every:on:skipEmpty:discardWhenCompleted:) where skipEmpty is true, discardWhenCompleted is false") {
			var scheduler: TestScheduler!
			var observer: Signal<Int, Never>.Observer!
			var signal: Signal<[Int], Never>!
			
			beforeEach {
				scheduler = TestScheduler()
				
				let (baseSignal, baseObserver) = Signal<Int, Never>.pipe()
				observer = baseObserver
				
				signal = baseSignal.collect(every: .seconds(1), on: scheduler, skipEmpty: true, discardWhenCompleted: false)
				expect(signal).notTo(beNil())
			}
			
			it("should send accumulated values on the given scheduler every interval") {
				var values: [[Int]] = []
				signal.observeValues { value in
					values.append(value)
				}
				
				expect(values.count) == 0
				
				observer.send(value: 0)
				expect(values.count) == 0
				
				scheduler.advance()
				expect(values.count) == 0
				
				observer.send(value: 1)
				observer.send(value: 2)
				expect(values.count) == 0
				
				scheduler.advance(by: .milliseconds(1500))
				expect(values.count) == 1
				expect(values[0]) == [ 0, 1, 2 ]
				
				scheduler.advance(by: .seconds(2))
				expect(values.count) == 1
				expect(values[0]) == [ 0, 1, 2 ]
				
				observer.send(value: 3)
				expect(values.count) == 1
				
				scheduler.advance()
				expect(values.count) == 1
				
				observer.send(value: 4)
				observer.send(value: 5)
				scheduler.advance()
				expect(values.count) == 1
				
				scheduler.advance(by: .seconds(100))
				expect(values.count) == 2
				expect(values[0]) == [ 0, 1, 2 ]
				expect(values[1]) == [ 3, 4, 5 ]
			}
			
			it("should schedule completion correctly") {
				var values: [[Int]] = []
				var completed = false
				
				signal.observe { event in
					switch event {
					case let .value(value):
						values.append(value)
					case .completed:
						completed = true
					default:
						break
					}
				}
				
				observer.send(value: 0)
				scheduler.advance()
				expect(values.count) == 0
				
				observer.send(value: 1)
				observer.sendCompleted()
				expect(completed) == false
				
				scheduler.advance()
				expect(values.count) == 0
				expect(completed) == false
				
				scheduler.run()
				expect(values.count) == 1
				expect(values.last) == [ 0, 1 ]
				expect(completed) == true
			}
		}
		
		describe("collect(every:on:skipEmpty:) where skipEmpty is true, discardWhenCompleted is true") {
			var scheduler: TestScheduler!
			var observer: Signal<Int, Never>.Observer!
			var signal: Signal<[Int], Never>!
			
			beforeEach {
				scheduler = TestScheduler()
				
				let (baseSignal, baseObserver) = Signal<Int, Never>.pipe()
				observer = baseObserver
				
				signal = baseSignal.collect(every: .seconds(1), on: scheduler, skipEmpty: true, discardWhenCompleted: true)
				expect(signal).notTo(beNil())
			}
			
			it("should send accumulated values on the given scheduler every interval") {
				var values: [[Int]] = []
				signal.observeValues { value in
					values.append(value)
				}
				
				expect(values.count) == 0
				
				observer.send(value: 0)
				expect(values.count) == 0
				
				scheduler.advance()
				expect(values.count) == 0
				
				observer.send(value: 1)
				observer.send(value: 2)
				expect(values.count) == 0
				
				scheduler.advance(by: .milliseconds(1500))
				expect(values.count) == 1
				expect(values[0]) == [ 0, 1, 2 ]
				
				scheduler.advance(by: .seconds(2))
				expect(values.count) == 1
				expect(values[0]) == [ 0, 1, 2 ]
				
				observer.send(value: 3)
				expect(values.count) == 1
				
				scheduler.advance()
				expect(values.count) == 1
				
				observer.send(value: 4)
				observer.send(value: 5)
				scheduler.advance()
				expect(values.count) == 1
				
				scheduler.advance(by: .seconds(100))
				expect(values.count) == 2
				expect(values[0]) == [ 0, 1, 2 ]
				expect(values[1]) == [ 3, 4, 5 ]
			}
			
			it("should schedule completion correctly") {
				var values: [[Int]] = []
				var completed = false
				
				signal.observe { event in
					switch event {
					case let .value(value):
						values.append(value)
					case .completed:
						completed = true
					default:
						break
					}
				}
				
				observer.send(value: 0)
				scheduler.advance()
				expect(values.count) == 0
				
				observer.send(value: 1)
				observer.sendCompleted()
				expect(completed) == false
				
				scheduler.advance()
				expect(values.count) == 0
				expect(completed) == true
				
				scheduler.run()
				expect(values.count) == 0
				expect(completed) == true
			}
		}

		describe("sampleWith") {
			var sampledSignal: Signal<(Int, String), Never>!
			var observer: Signal<Int, Never>.Observer!
			var samplerObserver: Signal<String, Never>.Observer!

			beforeEach {
				let (signal, incomingObserver) = Signal<Int, Never>.pipe()
				let (sampler, incomingSamplerObserver) = Signal<String, Never>.pipe()
				sampledSignal = signal.sample(with: sampler)
				observer = incomingObserver
				samplerObserver = incomingSamplerObserver
			}

			it("should forward the latest value when the sampler fires") {
				var result: [String] = []
				sampledSignal.observeValues { result.append("\($0.0)\($0.1)") }

				observer.send(value: 1)
				observer.send(value: 2)
				samplerObserver.send(value: "a")
				expect(result) == [ "2a" ]
			}

			it("should do nothing if sampler fires before signal receives value") {
				var result: [String] = []
				sampledSignal.observeValues { result.append("\($0.0)\($0.1)") }

				samplerObserver.send(value: "a")
				expect(result).to(beEmpty())
			}

			it("should send lates value with sampler value multiple times when sampler fires multiple times") {
				var result: [String] = []
				sampledSignal.observeValues { result.append("\($0.0)\($0.1)") }

				observer.send(value: 1)
				samplerObserver.send(value: "a")
				samplerObserver.send(value: "b")
				expect(result) == [ "1a", "1b" ]
			}

			it("should complete when both inputs have completed") {
				var completed = false
				sampledSignal.observeCompleted { completed = true }

				observer.sendCompleted()
				expect(completed) == false

				samplerObserver.sendCompleted()
				expect(completed) == true
			}
		}

		describe("sampleOn") {
			var sampledSignal: Signal<Int, Never>!
			var observer: Signal<Int, Never>.Observer!
			var samplerObserver: Signal<(), Never>.Observer!

			beforeEach {
				let (signal, incomingObserver) = Signal<Int, Never>.pipe()
				let (sampler, incomingSamplerObserver) = Signal<(), Never>.pipe()
				sampledSignal = signal.sample(on: sampler)
				observer = incomingObserver
				samplerObserver = incomingSamplerObserver
			}

			it("should forward the latest value when the sampler fires") {
				var result: [Int] = []
				sampledSignal.observeValues { result.append($0) }

				observer.send(value: 1)
				observer.send(value: 2)
				samplerObserver.send(value: ())
				expect(result) == [ 2 ]
			}

			it("should do nothing if sampler fires before signal receives value") {
				var result: [Int] = []
				sampledSignal.observeValues { result.append($0) }

				samplerObserver.send(value: ())
				expect(result).to(beEmpty())
			}

			it("should send lates value multiple times when sampler fires multiple times") {
				var result: [Int] = []
				sampledSignal.observeValues { result.append($0) }

				observer.send(value: 1)
				samplerObserver.send(value: ())
				samplerObserver.send(value: ())
				expect(result) == [ 1, 1 ]
			}

			it("should complete when both inputs have completed") {
				var completed = false
				sampledSignal.observeCompleted { completed = true }

				observer.sendCompleted()
				expect(completed) == false

				samplerObserver.sendCompleted()
				expect(completed) == true
			}
		}

		describe("withLatest(from: signal)") {
			var withLatestSignal: Signal<(Int, String), Never>!
			var observer: Signal<Int, Never>.Observer!
			var sampleeObserver: Signal<String, Never>.Observer!

			beforeEach {
				let (signal, incomingObserver) = Signal<Int, Never>.pipe()
				let (samplee, incomingSampleeObserver) = Signal<String, Never>.pipe()
				withLatestSignal = signal.withLatest(from: samplee)
				observer = incomingObserver
				sampleeObserver = incomingSampleeObserver
			}

			it("should forward the latest value when the receiver fires") {
				var result: [String] = []
				withLatestSignal.observeValues { result.append("\($0.0)\($0.1)") }

				sampleeObserver.send(value: "a")
				sampleeObserver.send(value: "b")
				observer.send(value: 1)
				expect(result) == [ "1b" ]
			}

			it("should do nothing if receiver fires before samplee sends value") {
				var result: [String] = []
				withLatestSignal.observeValues { result.append("\($0.0)\($0.1)") }

				observer.send(value: 1)
				expect(result).to(beEmpty())
			}

			it("should send latest value with samplee value multiple times when receiver fires multiple times") {
				var result: [String] = []
				withLatestSignal.observeValues { result.append("\($0.0)\($0.1)") }

				sampleeObserver.send(value: "a")
				observer.send(value: 1)
				observer.send(value: 2)
				expect(result) == [ "1a", "2a" ]
			}

			it("should complete when receiver has completed") {
				var completed = false
				withLatestSignal.observeCompleted { completed = true }

				sampleeObserver.sendCompleted()
				expect(completed) == false

				observer.sendCompleted()
				expect(completed) == true
			}

			it("should not affect when samplee has completed") {
				var event: Signal<(Int, String), Never>.Event? = nil
				withLatestSignal.observe { event = $0 }

				sampleeObserver.sendCompleted()
				expect(event).to(beNil())
			}

			it("should not affect when samplee has interrupted") {
				var event: Signal<(Int, String), Never>.Event? = nil
				withLatestSignal.observe { event = $0 }

				sampleeObserver.sendInterrupted()
				expect(event).to(beNil())
			}
		}

		describe("withLatest(from: producer)") {
			var withLatestSignal: Signal<(Int, String), Never>!
			var observer: Signal<Int, Never>.Observer!
			var sampleeObserver: Signal<String, Never>.Observer!

			beforeEach {
				let (signal, incomingObserver) = Signal<Int, Never>.pipe()
				let (samplee, incomingSampleeObserver) = SignalProducer<String, Never>.pipe()
				withLatestSignal = signal.withLatest(from: samplee)
				observer = incomingObserver
				sampleeObserver = incomingSampleeObserver
			}

			it("should forward the latest value when the receiver fires") {
				var result: [String] = []
				withLatestSignal.observeValues { result.append("\($0.0)\($0.1)") }

				sampleeObserver.send(value: "a")
				sampleeObserver.send(value: "b")
				observer.send(value: 1)
				expect(result) == [ "1b" ]
			}

			it("should do nothing if receiver fires before samplee sends value") {
				var result: [String] = []
				withLatestSignal.observeValues { result.append("\($0.0)\($0.1)") }

				observer.send(value: 1)
				expect(result).to(beEmpty())
			}

			it("should send latest value with samplee value multiple times when receiver fires multiple times") {
				var result: [String] = []
				withLatestSignal.observeValues { result.append("\($0.0)\($0.1)") }

				sampleeObserver.send(value: "a")
				observer.send(value: 1)
				observer.send(value: 2)
				expect(result) == [ "1a", "2a" ]
			}

			it("should complete when receiver has completed") {
				var completed = false
				withLatestSignal.observeCompleted { completed = true }

				observer.sendCompleted()
				expect(completed) == true
			}

			it("should not affect when samplee has completed") {
				var event: Signal<(Int, String), Never>.Event? = nil
				withLatestSignal.observe { event = $0 }

				sampleeObserver.sendCompleted()
				expect(event).to(beNil())
			}

			it("should not affect when samplee has interrupted") {
				var event: Signal<(Int, String), Never>.Event? = nil
				withLatestSignal.observe { event = $0 }

				sampleeObserver.sendInterrupted()
				expect(event).to(beNil())
			}

			it("should be able to fallback to SignalProducer for contextual lookups") {
				_ = Signal<Int, Never>.empty
					.withLatest(from: .init(value: 0))
			}
		}

		describe("combineLatestWith") {
			var combinedSignal: Signal<(Int, Double), Never>!
			var observer: Signal<Int, Never>.Observer!
			var otherObserver: Signal<Double, Never>.Observer!

			beforeEach {
				let (signal, incomingObserver) = Signal<Int, Never>.pipe()
				let (otherSignal, incomingOtherObserver) = Signal<Double, Never>.pipe()
				combinedSignal = signal.combineLatest(with: otherSignal)
				observer = incomingObserver
				otherObserver = incomingOtherObserver
			}

			it("should forward the latest values from both inputs") {
				var latest: (Int, Double)?
				combinedSignal.observeValues { latest = $0 }

				observer.send(value: 1)
				expect(latest).to(beNil())

				// is there a better way to test tuples?
				otherObserver.send(value: 1.5)
				expect(latest?.0) == 1
				expect(latest?.1) == 1.5

				observer.send(value: 2)
				expect(latest?.0) == 2
				expect(latest?.1) == 1.5
			}

			it("should complete when both inputs have completed") {
				var completed = false
				combinedSignal.observeCompleted { completed = true }

				observer.sendCompleted()
				expect(completed) == false

				otherObserver.sendCompleted()
				expect(completed) == true
			}
		}

		describe("zipWith") {
			var leftObserver: Signal<Int, Never>.Observer!
			var rightObserver: Signal<String, Never>.Observer!
			var zipped: Signal<(Int, String), Never>!

			beforeEach {
				let (leftSignal, incomingLeftObserver) = Signal<Int, Never>.pipe()
				let (rightSignal, incomingRightObserver) = Signal<String, Never>.pipe()

				leftObserver = incomingLeftObserver
				rightObserver = incomingRightObserver
				zipped = leftSignal.zip(with: rightSignal)
			}

			it("should combine pairs") {
				var result: [String] = []
				zipped.observeValues { result.append("\($0.0)\($0.1)") }

				leftObserver.send(value: 1)
				leftObserver.send(value: 2)
				expect(result) == []

				rightObserver.send(value: "foo")
				expect(result) == [ "1foo" ]

				leftObserver.send(value: 3)
				rightObserver.send(value: "bar")
				expect(result) == [ "1foo", "2bar" ]

				rightObserver.send(value: "buzz")
				expect(result) == [ "1foo", "2bar", "3buzz" ]

				rightObserver.send(value: "fuzz")
				expect(result) == [ "1foo", "2bar", "3buzz" ]

				leftObserver.send(value: 4)
				expect(result) == [ "1foo", "2bar", "3buzz", "4fuzz" ]
			}

			it("should complete when the shorter signal has completed") {
				var result: [String] = []
				var completed = false

				zipped.observe { event in
					switch event {
					case let .value((left, right)):
						result.append("\(left)\(right)")
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(completed) == false

				leftObserver.send(value: 0)
				leftObserver.sendCompleted()
				expect(completed) == false
				expect(result) == []

				rightObserver.send(value: "foo")
				expect(completed) == true
				expect(result) == [ "0foo" ]
			}

			it("should complete when both signal have completed") {
				var result: [String] = []
				var completed = false

				zipped.observe { event in
					switch event {
					case let .value((left, right)):
						result.append("\(left)\(right)")
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(completed) == false

				leftObserver.send(value: 0)
				leftObserver.sendCompleted()
				expect(completed) == false
				expect(result) == []

				rightObserver.sendCompleted()
				expect(result) == [ ]
			}

			it("should complete and drop unpaired pending values when both signal have completed") {
				var result: [String] = []
				var completed = false

				zipped.observe { event in
					switch event {
					case let .value((left, right)):
						result.append("\(left)\(right)")
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(completed) == false

				leftObserver.send(value: 0)
				leftObserver.send(value: 1)
				leftObserver.send(value: 2)
				leftObserver.send(value: 3)
				leftObserver.sendCompleted()
				expect(completed) == false
				expect(result) == []

				rightObserver.send(value: "foo")
				rightObserver.send(value: "bar")
				rightObserver.sendCompleted()
				expect(result) == ["0foo", "1bar"]
			}
		}

		describe("materialize") {
			it("should reify events from the signal") {
				let (signal, observer) = Signal<Int, TestError>.pipe()
				var latestEvent: Signal<Int, TestError>.Event?
				signal
					.materialize()
					.observeValues { latestEvent = $0 }

				observer.send(value: 2)

				expect(latestEvent).toNot(beNil())
				if let latestEvent = latestEvent {
					switch latestEvent {
					case let .value(value):
						expect(value) == 2
					default:
						fail()
					}
				}

				observer.send(error: TestError.default)
				if let latestEvent = latestEvent {
					switch latestEvent {
					case .failed:
						()
					default:
						fail()
					}
				}
			}
		}

		describe("dematerialize") {
			typealias IntEvent = Signal<Int, TestError>.Event
			var observer: Signal<IntEvent, Never>.Observer!
			var dematerialized: Signal<Int, TestError>!

			beforeEach {
				let (signal, incomingObserver) = Signal<IntEvent, Never>.pipe()
				observer = incomingObserver
				dematerialized = signal.dematerialize()
			}

			it("should send values for Value events") {
				var result: [Int] = []
				dematerialized
					.assumeNoErrors()
					.observeValues { result.append($0) }

				expect(result).to(beEmpty())

				observer.send(value: .value(2))
				expect(result) == [ 2 ]

				observer.send(value: .value(4))
				expect(result) == [ 2, 4 ]
			}

			it("should error out for Error events") {
				var errored = false
				dematerialized.observeFailed { _ in errored = true }

				expect(errored) == false

				observer.send(value: .failed(TestError.default))
				expect(errored) == true
			}

			it("should complete early for Completed events") {
				var completed = false
				dematerialized.observeCompleted { completed = true }

				expect(completed) == false
				observer.send(value: IntEvent.completed)
				expect(completed) == true
			}
		}

		describe("materializeResults") {
			it("should reify results from the signal") {
				let (signal, observer) = Signal<Int, TestError>.pipe()
				var latestResult: Result<Int, TestError>?
				signal
					.materializeResults()
					.observeValues { latestResult = $0 }

				observer.send(value: 2)

				expect(latestResult).toNot(beNil())
				if let latestResult = latestResult {
					switch latestResult {
					case .success(let value):
						expect(value) == 2

					case .failure:
						fail()
					}
				}

				observer.send(error: TestError.default)
				if let latestResult = latestResult {
					switch latestResult {
					case .failure(let error):
						expect(error) == TestError.default

					case .success:
						fail()
					}
				}
			}
		}

		describe("dematerializeResults") {
			typealias IntResult = Result<Int, TestError>
			var observer: Signal<IntResult, Never>.Observer!
			var dematerialized: Signal<Int, TestError>!

			beforeEach {
				let (signal, incomingObserver) = Signal<IntResult, Never>.pipe()
				observer = incomingObserver
				dematerialized = signal.dematerializeResults()
			}

			it("should send values for Value results") {
				var result: [Int] = []
				dematerialized
					.assumeNoErrors()
					.observeValues { result.append($0) }

				expect(result).to(beEmpty())

				observer.send(value: .success(2))
				expect(result) == [ 2 ]

				observer.send(value: .success(4))
				expect(result) == [ 2, 4 ]
			}

			it("should error out for Error results") {
				var errored = false
				dematerialized.observeFailed { _ in errored = true }

				expect(errored) == false

				observer.send(value: .failure(TestError.default))
				expect(errored) == true
			}
		}

		describe("takeLast") {
			var observer: Signal<Int, TestError>.Observer!
			var lastThree: Signal<Int, TestError>!

			beforeEach {
				let (signal, incomingObserver) = Signal<Int, TestError>.pipe()
				observer = incomingObserver
				lastThree = signal.take(last: 3)
			}

			it("should send the last N values upon completion") {
				var result: [Int] = []
				lastThree
					.assumeNoErrors()
					.observeValues { result.append($0) }

				observer.send(value: 1)
				observer.send(value: 2)
				observer.send(value: 3)
				observer.send(value: 4)
				expect(result).to(beEmpty())

				observer.sendCompleted()
				expect(result) == [ 2, 3, 4 ]
			}

			it("should send less than N values if not enough were received") {
				var result: [Int] = []
				lastThree
					.assumeNoErrors()
					.observeValues { result.append($0) }

				observer.send(value: 1)
				observer.send(value: 2)
				observer.sendCompleted()
				expect(result) == [ 1, 2 ]
			}

			it("should send nothing when errors") {
				var result: [Int] = []
				var errored = false
				lastThree.observe { event in
					switch event {
					case let .value(value):
						result.append(value)
					case .failed:
						errored = true
					default:
						break
					}
				}

				observer.send(value: 1)
				observer.send(value: 2)
				observer.send(value: 3)
				expect(errored) == false

				observer.send(error: TestError.default)
				expect(errored) == true
				expect(result).to(beEmpty())
			}
		}

		describe("timeoutWithError") {
			var testScheduler: TestScheduler!
			var signal: Signal<Int, TestError>!
			var observer: Signal<Int, TestError>.Observer!

			beforeEach {
				testScheduler = TestScheduler()
				let (baseSignal, incomingObserver) = Signal<Int, TestError>.pipe()
				signal = baseSignal.timeout(after: 2, raising: TestError.default, on: testScheduler)
				observer = incomingObserver
			}

			it("should complete if within the interval") {
				var completed = false
				var errored = false
				signal.observe { event in
					switch event {
					case .completed:
						completed = true
					case .failed:
						errored = true
					default:
						break
					}
				}

				testScheduler.schedule(after: .seconds(1)) {
					observer.sendCompleted()
				}

				expect(completed) == false
				expect(errored) == false

				testScheduler.run()
				expect(completed) == true
				expect(errored) == false
			}

			it("should error if not completed before the interval has elapsed") {
				var completed = false
				var errored = false
				signal.observe { event in
					switch event {
					case .completed:
						completed = true
					case .failed:
						errored = true
					default:
						break
					}
				}

				testScheduler.schedule(after: .seconds(3)) {
					observer.sendCompleted()
				}

				expect(completed) == false
				expect(errored) == false

				testScheduler.run()
				expect(completed) == false
				expect(errored) == true
			}

			it("should be available for Never") {
				let signal: Signal<Int, TestError> = Signal<Int, Never>.never
					.timeout(after: 2, raising: TestError.default, on: testScheduler)

				_ = signal
			}
		}

		describe("attempt") {
			it("should forward original values upon success") {
				let (baseSignal, observer) = Signal<Int, TestError>.pipe()
				let signal = baseSignal.attempt { _ in
					return .success(())
				}

				var current: Int?
				signal
					.assumeNoErrors()
					.observeValues { value in
						current = value
					}

				for value in 1...5 {
					observer.send(value: value)
					expect(current) == value
				}
			}

			it("should error if an attempt fails") {
				let (baseSignal, observer) = Signal<Int, TestError>.pipe()
				let signal = baseSignal.attempt { _ in
					return .failure(.default)
				}

				var error: TestError?
				signal.observeFailed { err in
					error = err
				}

				observer.send(value: 42)
				expect(error) == TestError.default
			}
		}

		describe("attempt throws") {
			it("should forward original values upon success") {
				let (baseSignal, observer) = Signal<Int, Error>.pipe()
				let signal = baseSignal.attempt { _ in
					_ = try operation(value: 1)
				}

				var current: Int?
				signal
					.assumeNoErrors()
					.observeValues { value in
						current = value
					}

				for value in 1...5 {
					observer.send(value: value)
					expect(current) == value
				}
			}

			it("should error if an attempt fails") {
				let (baseSignal, observer) = Signal<Int, Never>.pipe()
				let signal = baseSignal.attempt { _ in
					_ = try operation(value: nil) as Int
				}

				var error: TestError?
				signal.observeFailed { err in
					error = err as? TestError
				}

				observer.send(value: 42)
				expect(error) == TestError.default
			}

			it("should allow throwing closures with Never") {
				let (baseSignal, observer) = Signal<Int, Never>.pipe()
				let signal = baseSignal.attempt { _ in
					_ = try operation(value: 1)
				}

				var value: Int?
				signal.observeResult { value = $0.value }

				observer.send(value: 42)
				expect(value) == 42
			}
		}

		describe("attemptMap") {
			it("should forward mapped values upon success") {
				let (baseSignal, observer) = Signal<Int, TestError>.pipe()
				let signal = baseSignal.attemptMap { num -> Result<Bool, TestError> in
					return .success(num % 2 == 0)
				}

				var even: Bool?
				signal
					.assumeNoErrors()
					.observeValues { value in
						even = value
					}

				observer.send(value: 1)
				expect(even) == false

				observer.send(value: 2)
				expect(even) == true
			}

			it("should error if a mapping fails") {
				let (baseSignal, observer) = Signal<Int, TestError>.pipe()
				let signal = baseSignal.attemptMap { _ -> Result<Bool, TestError> in
					return .failure(.default)
				}

				var error: TestError?
				signal.observeFailed { err in
					error = err
				}

				observer.send(value: 42)
				expect(error) == TestError.default
			}
		}

		describe("attemptMap throws") {
			it("should forward mapped values upon success") {
				let (baseSignal, observer) = Signal<Int, Error>.pipe()
				let signal = baseSignal.attemptMap { num -> Bool in
					try operation(value: num % 2 == 0)
				}

				var even: Bool?
				signal
					.assumeNoErrors()
					.observeValues { value in
						even = value
					}

				observer.send(value: 1)
				expect(even) == false

				observer.send(value: 2)
				expect(even) == true
			}

			it("should error if a mapping fails") {
				let (baseSignal, observer) = Signal<Int, Error>.pipe()
				let signal = baseSignal.attemptMap { _ -> Bool in
					try operation(value: nil)
				}

				var error: TestError?
				signal.observeFailed { err in
					error = err as? TestError
				}

				observer.send(value: 42)
				expect(error) == TestError.default
			}

			it("should allow throwing closures with Never") {
				let (baseSignal, observer) = Signal<Int, Never>.pipe()
				let signal = baseSignal.attemptMap { num in
					try operation(value: num % 2 == 0)
				}

				var value: Bool?
				signal.observeResult { value = $0.value }

				observer.send(value: 2)
				expect(value) == true
			}
		}

		describe("combinePrevious") {
			var signal: Signal<Int, Never>!
			var observer: Signal<Int, Never>.Observer!
			let initialValue: Int = 0
			var latestValues: (Int, Int)?

			beforeEach {
				latestValues = nil

				let (baseSignal, baseObserver) = Signal<Int, Never>.pipe()
				(signal, observer) = (baseSignal, baseObserver)
			}

			it("should forward the latest value with previous value with an initial value") {
				signal.combinePrevious(initialValue).observeValues { latestValues = $0 }

				expect(latestValues).to(beNil())

				observer.send(value: 1)
				expect(latestValues?.0) == initialValue
				expect(latestValues?.1) == 1

				observer.send(value: 2)
				expect(latestValues?.0) == 1
				expect(latestValues?.1) == 2
			}

			it("should forward the latest value with previous value without any initial value") {
				signal.combinePrevious().observeValues { latestValues = $0 }

				expect(latestValues).to(beNil())

				observer.send(value: 1)
				expect(latestValues).to(beNil())

				observer.send(value: 2)
				expect(latestValues?.0) == 1
				expect(latestValues?.1) == 2
			}
		}

		describe("AggregateBuilder") {
			it("should not deadlock upon disposal") {
				let (a, aObserver) = Signal<(), Never>.pipe()
				let (b, bObserver) = Signal<(), Never>.pipe()

				Signal.zip(a, b)
					.take(first: 1)
					.observeValues { _ in }

				aObserver.send(value: ())
				bObserver.send(value: ())
			}

			it("should not deadlock upon recursive completion of the sources") {
				let (a, aObserver) = Signal<(), Never>.pipe()
				let (b, bObserver) = Signal<(), Never>.pipe()

				Signal.zip(a, b)
					.observeValues { _ in
						aObserver.sendCompleted()
					}

				aObserver.send(value: ())
				bObserver.send(value: ())
			}

			it("should not deadlock upon recursive interruption of the sources") {
				let (a, aObserver) = Signal<(), Never>.pipe()
				let (b, bObserver) = Signal<(), Never>.pipe()

				Signal.zip(a, b)
					.observeResult { _ in
						aObserver.sendInterrupted()
					}

				aObserver.send(value: ())
				bObserver.send(value: ())
			}

			it("should not deadlock upon recursive failure of the sources") {
				let (a, aObserver) = Signal<(), TestError>.pipe()
				let (b, bObserver) = Signal<(), TestError>.pipe()

				Signal.zip(a, b)
					.observeResult { _ in
						aObserver.send(error: .default)
					}

				aObserver.send(value: ())
				bObserver.send(value: ())
			}

			it("should not deadlock upon disposal") {
				let (a, aObserver) = Signal<(), Never>.pipe()
				let (b, bObserver) = Signal<(), Never>.pipe()

				Signal.combineLatest(a, b)
					.take(first: 1)
					.observeValues { _ in }

				aObserver.send(value: ())
				bObserver.send(value: ())
			}

			it("should not deadlock upon recursive completion of the sources") {
				let (a, aObserver) = Signal<(), Never>.pipe()
				let (b, bObserver) = Signal<(), Never>.pipe()

				Signal.combineLatest(a, b)
					.observeValues { _ in
						aObserver.sendCompleted()
				}

				aObserver.send(value: ())
				bObserver.send(value: ())
			}

			it("should not deadlock upon recursive interruption of the sources") {
				let (a, aObserver) = Signal<(), Never>.pipe()
				let (b, bObserver) = Signal<(), Never>.pipe()

				Signal.combineLatest(a, b)
					.observeResult { _ in
						aObserver.sendInterrupted()
				}

				aObserver.send(value: ())
				bObserver.send(value: ())
			}

			it("should not deadlock upon recursive failure of the sources") {
				let (a, aObserver) = Signal<(), TestError>.pipe()
				let (b, bObserver) = Signal<(), TestError>.pipe()

				Signal.combineLatest(a, b)
					.observeResult { _ in
						aObserver.send(error: .default)
				}

				aObserver.send(value: ())
				bObserver.send(value: ())
			}
		}

		describe("combineLatest") {
			var signalA: Signal<Int, Never>!
			var signalB: Signal<Int, Never>!
			var signalC: Signal<Int, Never>!
			var observerA: Signal<Int, Never>.Observer!
			var observerB: Signal<Int, Never>.Observer!
			var observerC: Signal<Int, Never>.Observer!

			var combinedValues: [Int]?
			var completed: Bool!

			beforeEach {
				combinedValues = nil
				completed = false

				let (baseSignalA, baseObserverA) = Signal<Int, Never>.pipe()
				let (baseSignalB, baseObserverB) = Signal<Int, Never>.pipe()
				let (baseSignalC, baseObserverC) = Signal<Int, Never>.pipe()

				signalA = baseSignalA
				signalB = baseSignalB
				signalC = baseSignalC

				observerA = baseObserverA
				observerB = baseObserverB
				observerC = baseObserverC
			}

			let combineLatestExampleName = "combineLatest examples"
			sharedExamples(combineLatestExampleName) {
				it("should forward the latest values from all inputs"){
					expect(combinedValues).to(beNil())

					observerA.send(value: 0)
					observerB.send(value: 1)
					observerC.send(value: 2)
					expect(combinedValues) == [0, 1, 2]

					observerA.send(value: 10)
					expect(combinedValues) == [10, 1, 2]
				}

				it("should not forward the latest values before all inputs"){
					expect(combinedValues).to(beNil())

					observerA.send(value: 0)
					expect(combinedValues).to(beNil())

					observerB.send(value: 1)
					expect(combinedValues).to(beNil())

					observerC.send(value: 2)
					expect(combinedValues) == [0, 1, 2]
				}

				it("should complete when all inputs have completed"){
					expect(completed) == false

					observerA.sendCompleted()
					observerB.sendCompleted()
					expect(completed) == false

					observerC.sendCompleted()
					expect(completed) == true
				}
			}

			describe("tuple") {
				beforeEach {
					Signal.combineLatest(signalA, signalB, signalC)
						.observe { event in
							switch event {
							case let .value(value):
								combinedValues = [value.0, value.1, value.2]
							case .completed:
								completed = true
							default:
								break
							}
						}
				}

				itBehavesLike(combineLatestExampleName)
			}

			describe("sequence") {
				beforeEach {
					Signal.combineLatest([signalA, signalB, signalC])
					.observe { event in
						switch event {
						case let .value(values):
							combinedValues = values
						case .completed:
							completed = true
						default:
							break
						}
					}
				}

				itBehavesLike(combineLatestExampleName)
			}
		}

		describe("zip") {
			var signalA: Signal<Int, Never>!
			var signalB: Signal<Int, Never>!
			var signalC: Signal<Int, Never>!
			var observerA: Signal<Int, Never>.Observer!
			var observerB: Signal<Int, Never>.Observer!
			var observerC: Signal<Int, Never>.Observer!

			var zippedValues: [Int]?
			var completed: Bool!

			beforeEach {
				zippedValues = nil
				completed = false

				let (baseSignalA, baseObserverA) = Signal<Int, Never>.pipe()
				let (baseSignalB, baseObserverB) = Signal<Int, Never>.pipe()
				let (baseSignalC, baseObserverC) = Signal<Int, Never>.pipe()

				signalA = baseSignalA
				signalB = baseSignalB
				signalC = baseSignalC

				observerA = baseObserverA
				observerB = baseObserverB
				observerC = baseObserverC
			}

			let zipExampleName = "zip examples"
			sharedExamples(zipExampleName) {
				it("should combine all set"){
					expect(zippedValues).to(beNil())

					observerA.send(value: 0)
					expect(zippedValues).to(beNil())

					observerB.send(value: 1)
					expect(zippedValues).to(beNil())

					observerC.send(value: 2)
					expect(zippedValues) == [0, 1, 2]

					observerA.send(value: 10)
					expect(zippedValues) == [0, 1, 2]

					observerA.send(value: 20)
					expect(zippedValues) == [0, 1, 2]

					observerB.send(value: 11)
					expect(zippedValues) == [0, 1, 2]

					observerC.send(value: 12)
					expect(zippedValues) == [10, 11, 12]
				}

				it("should complete when the shorter signal has completed"){
					expect(completed) == false

					observerB.send(value: 1)
					observerC.send(value: 2)
					observerB.sendCompleted()
					observerC.sendCompleted()
					expect(completed) == false

					observerA.send(value: 0)
					expect(completed) == true
				}
			}

			describe("tuple") {
				beforeEach {
					Signal.zip(signalA, signalB, signalC)
						.observe { event in
							switch event {
							case let .value(value):
								zippedValues = [value.0, value.1, value.2]
							case .completed:
								completed = true
							default:
								break
							}
						}
				}

				itBehavesLike(zipExampleName)
			}

			describe("sequence") {
				beforeEach {
					Signal.zip([signalA, signalB, signalC])
						.observe { event in
							switch event {
							case let .value(values):
								zippedValues = values
							case .completed:
								completed = true
							default:
								break
							}
						}
				}

				itBehavesLike(zipExampleName)
			}

			describe("log events") {
				it("should output the correct event without identifier") {
					let expectations: [(String) -> Void] = [
						{ event in expect(event).to(equal("[] value 1")) },
						{ event in expect(event).to(equal("[] completed")) },
						{ event in expect(event).to(equal("[] terminated")) },
						{ event in expect(event).to(equal("[] disposed")) },
					]

					let logger = TestLogger(expectations: expectations)

					let (signal, observer) = Signal<Int, Never>.pipe()
					signal
						.logEvents(logger: logger.logEvent)
						.observe { _ in }

					observer.send(value: 1)
					observer.sendCompleted()
				}

				it("should output the correct event with identifier") {
					let expectations: [(String) -> Void] = [
						{ event in expect(event).to(equal("[test.rac] value 1")) },
						{ event in expect(event).to(equal("[test.rac] failed error1")) },
						{ event in expect(event).to(equal("[test.rac] terminated")) },
						{ event in expect(event).to(equal("[test.rac] disposed")) },
					]

					let logger = TestLogger(expectations: expectations)

					let (signal, observer) = Signal<Int, TestError>.pipe()
					signal
						.logEvents(identifier: "test.rac", logger: logger.logEvent)
						.observe { _ in }

					observer.send(value: 1)
					observer.send(error: .error1)
				}

				it("should only output the events specified in the `events` parameter") {
					let expectations: [(String) -> Void] = [
						{ event in expect(event) == "[test.rac] failed error1" },
					]

					let logger = TestLogger(expectations: expectations)

					let (signal, observer) = Signal<Int, TestError>.pipe()
					signal
						.logEvents(identifier: "test.rac", events: [.failed], logger: logger.logEvent)
						.observe { _ in }

					observer.send(value: 1)
					observer.send(error: .error1)
				}
			}
		}

		describe("negated attribute") {
			it("should return the negate of a value in a Boolean signal") {
				let (signal, observer) = Signal<Bool, Never>.pipe()
				signal.negate().observeValues { value in
					expect(value).to(beFalse())
				}
				observer.send(value: true)
				observer.sendCompleted()
			}
		}

		describe("and attribute") {
			it("should emit true when both signals emits the same value") {
				let (signal1, observer1) = Signal<Bool, Never>.pipe()
				let (signal2, observer2) = Signal<Bool, Never>.pipe()
				signal1.and(signal2).observeValues { value in
					expect(value).to(beTrue())
				}
				observer1.send(value: true)
				observer2.send(value: true)

				observer1.sendCompleted()
				observer2.sendCompleted()
			}

			it("should emit false when both signals emits opposite values") {
				let (signal1, observer1) = Signal<Bool, Never>.pipe()
				let (signal2, observer2) = Signal<Bool, Never>.pipe()
				signal1.and(signal2).observeValues { value in
					expect(value).to(beFalse())
				}
				observer1.send(value: false)
				observer2.send(value: true)

				observer1.sendCompleted()
				observer2.sendCompleted()
			}
		}
		
		describe("all attribute") {
			it("should emit false when any signal emits opposite values") {
				let (signal1, observer1) = Signal<Bool, Never>.pipe()
				let (signal2, observer2) = Signal<Bool, Never>.pipe()
				let (signal3, observer3) = Signal<Bool, Never>.pipe()
				Signal.all([signal1, signal2, signal3]).observeValues { value in
					expect(value).to(beFalse())
				}
				observer1.send(value: false)
				observer2.send(value: true)
				observer3.send(value: false)

				observer1.sendCompleted()
				observer2.sendCompleted()
				observer3.sendCompleted()
			}

			it("should emit true when all signals emit the same value") {
				let (signal1, observer1) = Signal<Bool, Never>.pipe()
				let (signal2, observer2) = Signal<Bool, Never>.pipe()
				let (signal3, observer3) = Signal<Bool, Never>.pipe()
				Signal.all([signal1, signal2, signal3]).observeValues { value in
					expect(value).to(beTrue())
				}
				observer1.send(value: true)
				observer2.send(value: true)
				observer3.send(value: true)

				observer1.sendCompleted()
				observer2.sendCompleted()
				observer3.sendCompleted()
			}
		}

		describe("or attribute") {
			it("should emit true when at least one of the signals emits true") {
				let (signal1, observer1) = Signal<Bool, Never>.pipe()
				let (signal2, observer2) = Signal<Bool, Never>.pipe()
				signal1.or(signal2).observeValues { value in
					expect(value).to(beTrue())
				}
				observer1.send(value: true)
				observer2.send(value: false)

				observer1.sendCompleted()
				observer2.sendCompleted()
			}

			it("should emit false when both signals emits false") {
				let (signal1, observer1) = Signal<Bool, Never>.pipe()
				let (signal2, observer2) = Signal<Bool, Never>.pipe()
				signal1.or(signal2).observeValues { value in
					expect(value).to(beFalse())
				}
				observer1.send(value: false)
				observer2.send(value: false)

				observer1.sendCompleted()
				observer2.sendCompleted()
			}
		}

		describe("any attribute") {
			it("should emit true when at least one of the signals in array emits true") {
				let (signal1, observer1) = Signal<Bool, Never>.pipe()
				let (signal2, observer2) = Signal<Bool, Never>.pipe()
				let (signal3, observer3) = Signal<Bool, Never>.pipe()
				Signal.any([signal1, signal2, signal3]).observeValues { value in
					expect(value).to(beTrue())
				}
				observer1.send(value: true)
				observer2.send(value: false)
				observer3.send(value: false)

				observer1.sendCompleted()
				observer2.sendCompleted()
				observer3.sendCompleted()
			}
			
			it("should emit false when all signals emits false") {
				let (signal1, observer1) = Signal<Bool, Never>.pipe()
				let (signal2, observer2) = Signal<Bool, Never>.pipe()
				let (signal3, observer3) = Signal<Bool, Never>.pipe()
				Signal.any(signal1, signal2, signal3).observeValues { value in
					expect(value).to(beFalse())
				}
				observer1.send(value: false)
				observer2.send(value: false)
				observer3.send(value: false)

				observer1.sendCompleted()
				observer2.sendCompleted()
				observer3.sendCompleted()
			}
		}

		describe("promoteError") {
			it("should infer the error type from the context") {
				let combined: Any = Signal
					.combineLatest(Signal<Int, Never>.never.promoteError(),
					               Signal<Double, TestError>.never,
					               Signal<Float, Never>.never.promoteError(),
					               Signal<UInt, POSIXError>.never.flatMapError { _ in .empty })

				expect(combined is Signal<(Int, Double, Float, UInt), TestError>) == true
			}
		}

		describe("promoteValue") {
			it("should infer the value type from the context") {
				let completable = Signal<Never, Never>.never
				let producer: Signal<Int, Never> = Signal<Int, Never>.never
					.flatMap(.latest) { _ in completable.promoteValue() }

				expect((producer as Any) is Signal<Int, Never>) == true
			}
		}
	}
}

private func operation<T>(value: T?) throws -> T {
	guard let value = value else { throw TestError.default }
	return value
}
