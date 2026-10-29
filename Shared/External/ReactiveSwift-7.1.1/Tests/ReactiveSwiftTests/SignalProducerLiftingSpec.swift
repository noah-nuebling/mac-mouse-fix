//
//  SignalProducerLiftingSpec.swift
//  ReactiveSwift
//
//  Created by Neil Pankey on 6/14/15.
//  Copyright © 2015 GitHub. All rights reserved.
//

import Dispatch
import Foundation

@testable import Nimble
import Quick
@testable import ReactiveSwift

class SignalProducerLiftingSpec: QuickSpec {
	override func spec() {
		describe("map") {
			it("should transform the values of the signal") {
				let (producer, observer) = SignalProducer<Int, Never>.pipe()
				let mappedProducer = producer.map { String($0 + 1) }

				var lastValue: String?

				mappedProducer.startWithValues {
					lastValue = $0
					return
				}

				expect(lastValue).to(beNil())

				observer.send(value: 0)
				expect(lastValue) == "1"

				observer.send(value: 1)
				expect(lastValue) == "2"
			}
			
			it("should raplace the values of the signal to constant new value") {
				let (producer, observer) = SignalProducer<String, Never>.pipe()
				let mappedProducer = producer.map(value: 1)
				
				var lastValue: Int?
				
				mappedProducer.startWithValues {
					lastValue = $0
				}
				
				expect(lastValue).to(beNil())
				
				observer.send(value: "foo")
				expect(lastValue) == 1
				
				observer.send(value: "foobar")
				expect(lastValue) == 1
			}
		}

		describe("mapError") {
			it("should transform the errors of the signal") {
				let (producer, observer) = SignalProducer<Int, TestError>.pipe()
				let producerError = NSError(domain: "com.reactivecocoa.errordomain", code: 100, userInfo: nil)
				var error: NSError?

				producer
					.mapError { _ in producerError }
					.startWithFailed { error = $0 }

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
				var tupleProducer: SignalProducer<(character: String, other: Int), Never>!
				var tupleObserver: Signal<(character: String, other: Int), Never>.Observer!
				var theLens: SignalProducer<String, Never>!
				var getterCounter: Int = 0
				var lensScheduler: TestScheduler!
				var targetScheduler: TestScheduler!
				var target: BindingTarget<String>!

				beforeEach {
					destination = []
					token = Lifetime.Token()
					lifetime = Lifetime(token)

					let (producer, observer) = SignalProducer<(character: String, other: Int), Never>.pipe()
					tupleProducer = producer
					tupleObserver = observer

					lensScheduler = TestScheduler()
					targetScheduler = TestScheduler()

					getterCounter = 0
					theLens = tupleProducer.lazyMap(on: lensScheduler) { (tuple: (character: String, other: Int)) -> String in
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

			it("should return the result of the getter on each value change") {
				let initialValue = (character: "🎃", other: 42)
				let nextValue = (character: "😾", other: 74)

				let scheduler = TestScheduler()
				let (tupleProducer, tupleObserver) = SignalProducer<(character: String, other: Int), Never>.pipe()
				let theLens: SignalProducer<String, Never> = tupleProducer.lazyMap(on: scheduler) { $0.character }

				var output: [String] = []
				theLens.startWithValues { value in
					output.append(value)
				}

				tupleObserver.send(value: initialValue)

				scheduler.advance()
				expect(output) == ["🎃"]

				tupleObserver.send(value: nextValue)

				scheduler.advance()
				expect(output) == ["🎃", "😾"]
			}

			it("should evaluate its getter lazily") {
				let initialValue = (character: "🎃", other: 42)
				let nextValue = (character: "😾", other: 74)

				let (tupleProducer, tupleObserver) = SignalProducer<(character: String, other: Int), Never>.pipe()

				let scheduler = TestScheduler()
				var output: [String] = []
				var getterEvaluated = false
				let theLens: SignalProducer<String, Never> = tupleProducer.lazyMap(on: scheduler) { (tuple: (character: String, other: Int)) -> String in
					getterEvaluated = true
					return tuple.character
				}

				// No surprise here, but the getter should not be evaluated
				// since the underlying producer has yet to be started.
				expect(getterEvaluated).to(beFalse())

				// Similarly, sending values won't cause anything to happen.
				tupleObserver.send(value: initialValue)
				expect(output).to(beEmpty())
				expect(getterEvaluated).to(beFalse())

				// Start the signal, appending future values to the output array
				theLens.startWithValues { value in output.append(value) }

				// Even when the producer has yet to start, there should be no
				// evaluation of the getter
				expect(getterEvaluated).to(beFalse())

				// Now we send a value through the producer
				tupleObserver.send(value: initialValue)

				// The getter should still not be evaluated, as it has not yet
				// been scheduled
				expect(getterEvaluated).to(beFalse())

				// Now advance the scheduler to allow things to proceed
				scheduler.advance()

				// Now the getter gets evaluated, and the output is what we'd
				// expect
				expect(getterEvaluated).to(beTrue())
				expect(output) == ["🎃"]

				// And now subsequent values continue to come through
				tupleObserver.send(value: nextValue)
				scheduler.advance()
				expect(output) == ["🎃", "😾"]
			}

			it("should evaluate its getter lazily on a different scheduler") {
				let initialValue = (character: "🎃", other: 42)
				let nextValue = (character: "😾", other: 74)

				let (tupleProducer, tupleObserver) = SignalProducer<(character: String, other: Int), Never>.pipe()

				let scheduler = TestScheduler()

				var output: [String] = []
				var getterEvaluated = false
				let theLens: SignalProducer<String, Never> = tupleProducer.lazyMap(on: scheduler) { (tuple: (character: String, other: Int)) -> String in
					getterEvaluated = true
					return tuple.character
				}

				// No surprise here, but the getter should not be evaluated
				// since the underlying producer has yet to be started.
				expect(getterEvaluated).to(beFalse())

				// Similarly, sending values won't cause anything to happen.
				tupleObserver.send(value: initialValue)
				expect(output).to(beEmpty())
				expect(getterEvaluated).to(beFalse())

				// Start the signal, appending future values to the output array
				theLens.startWithValues { value in output.append(value) }

				// Even when the producer has yet to start, there should be no
				// evaluation of the getter
				expect(getterEvaluated).to(beFalse())

				tupleObserver.send(value: initialValue)

				// The getter should still not get evaluated, as it was not yet
				// scheduled
				expect(getterEvaluated).to(beFalse())
				expect(output).to(beEmpty())

				scheduler.run()

				// Now that the scheduler's run, things can continue to move forward
				expect(getterEvaluated).to(beTrue())
				expect(output) == ["🎃"]

				tupleObserver.send(value: nextValue)

				// Subsequent values should still be held up by the scheduler
				// not getting run
				expect(output) == ["🎃"]

				scheduler.run()

				expect(output) == ["🎃", "😾"]
			}

			it("should evaluate its getter lazily on the scheduler we specify") {
				let initialValue = (character: "🎃", other: 42)

				let (tupleProducer, tupleObserver) = SignalProducer<(character: String, other: Int), Never>.pipe()

				let labelKey = DispatchSpecificKey<String>()
				let testQueue = DispatchQueue(label: "test queue", target: .main)
				testQueue.setSpecific(key: labelKey, value: "test queue")
				testQueue.suspend()
				let testScheduler = QueueScheduler(internalQueue: testQueue)

				var output: [String] = []
				var isOnTestQueue = false
				let theLens = tupleProducer.lazyMap(on: testScheduler) { (tuple: (character: String, other: Int)) -> String in
					isOnTestQueue = DispatchQueue.getSpecific(key: labelKey) == "test queue"
					return tuple.character
				}

				// Start the signal, appending future values to the output array
				theLens.startWithValues { value in output.append(value) }
				testQueue.resume()

				expect(isOnTestQueue).to(beFalse())
				expect(output).to(beEmpty())

				tupleObserver.send(value: initialValue)

				expect(isOnTestQueue).toEventually(beTrue())
				expect(output).toEventually(equal(["🎃"]))
			}

			it("should interrupt ASAP and discard outstanding events") {
				testAsyncASAPInterruption(op: "lazyMap") { $0.lazyMap(on: $1) { $0 } }
			}

			it("should interrupt on the given scheduler") {
				testAsyncInterruptionScheduler(op: "lazyMap") { $0.lazyMap(on: $1) { $0 } }
			}
		}

		describe("filter") {
			it("should omit values from the producer") {
				let (producer, observer) = SignalProducer<Int, Never>.pipe()
				let mappedProducer = producer.filter { $0 % 2 == 0 }

				var lastValue: Int?

				mappedProducer.startWithValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.send(value: 0)
				expect(lastValue) == 0

				observer.send(value: 1)
				expect(lastValue) == 0

				observer.send(value: 2)
				expect(lastValue) == 2
			}
		}

		describe("skipNil") {
			it("should forward only non-nil values") {
				let (producer, observer) = SignalProducer<Int?, Never>.pipe()
				let mappedProducer = producer.skipNil()

				var lastValue: Int?

				mappedProducer.startWithValues { lastValue = $0 }
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
				let (baseProducer, observer) = SignalProducer<String, Never>.pipe()
				let producer = baseProducer.scan("", +)

				var lastValue: String?

				producer.startWithValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.send(value: "a")
				expect(lastValue) == "a"

				observer.send(value: "bb")
				expect(lastValue) == "abb"
			}
		}

		describe("scan(into:_:)") {
			it("should incrementally accumulate a value") {
				let (baseProducer, observer) = SignalProducer<String, Never>.pipe()
				let producer = baseProducer.scan(into: "") { $0 += $1 }

				var lastValue: String?

				producer.startWithValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.send(value: "a")
				expect(lastValue) == "a"

				observer.send(value: "bb")
				expect(lastValue) == "abb"
			}
		}

		describe("scanMap(_:_:)") {
			it("should update state and output separately") {
				let (baseProducer, observer) = SignalProducer<Int, Never>.pipe()
				let producer = baseProducer.scanMap(false) { state, value -> (Bool, String) in
					return (true, state ? "\(value)" : "initial")
				}

				var lastValue: String?

				producer.startWithValues { lastValue = $0 }

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
				let (baseProducer, observer) = SignalProducer<Int, Never>.pipe()
				let producer = baseProducer.scanMap(into: false) { (state: inout Bool, value: Int) -> String in
					defer { state = true }
					return state ? "\(value)" : "initial"
				}

				var lastValue: String?

				producer.startWithValues { lastValue = $0 }

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
				let (baseProducer, observer) = SignalProducer<Int, Never>.pipe()
				let producer = baseProducer.reduce(1, +)

				var lastValue: Int?
				var completed = false

				producer.start { event in
					switch event {
					case let .value(value):
						lastValue = value
					case .completed:
						completed = true
					case .failed, .interrupted:
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
				let (baseProducer, observer) = SignalProducer<Int, Never>.pipe()
				let producer = baseProducer.reduce(1, +)

				var lastValue: Int?
				var completed = false

				producer.start { event in
					switch event {
					case let .value(value):
						lastValue = value
					case .completed:
						completed = true
					case .failed, .interrupted:
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
				let (baseProducer, observer) = SignalProducer<Int, Never>.pipe()
				let producer = baseProducer.reduce(into: 1) { $0 += $1 }

				var lastValue: Int?
				var completed = false

				producer.start { event in
					switch event {
					case let .value(value):
						lastValue = value
					case .completed:
						completed = true
					case .failed, .interrupted:
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
				let (baseProducer, observer) = SignalProducer<Int, Never>.pipe()
				let producer = baseProducer.reduce(into: 1) { $0 += $1 }

				var lastValue: Int?
				var completed = false

				producer.start { event in
					switch event {
					case let .value(value):
						lastValue = value
					case .completed:
						completed = true
					case .failed, .interrupted:
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
				let (baseProducer, observer) = SignalProducer<Int, Never>.pipe()
				let producer = baseProducer.skip(first: 1)

				var lastValue: Int?
				producer.startWithValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.send(value: 1)
				expect(lastValue).to(beNil())

				observer.send(value: 2)
				expect(lastValue) == 2
			}

			it("should not skip any values when 0") {
				let (baseProducer, observer) = SignalProducer<Int, Never>.pipe()
				let producer = baseProducer.skip(first: 0)

				var lastValue: Int?
				producer.startWithValues { lastValue = $0 }

				expect(lastValue).to(beNil())

				observer.send(value: 1)
				expect(lastValue) == 1

				observer.send(value: 2)
				expect(lastValue) == 2
			}
		}

		describe("skipRepeats") {
			it("should skip duplicate Equatable values") {
				let (baseProducer, observer) = SignalProducer<Bool, Never>.pipe()
				let producer = baseProducer.skipRepeats()

				var values: [Bool] = []
				producer.startWithValues { values.append($0) }

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
				let (baseProducer, observer) = SignalProducer<String, Never>.pipe()
				let producer = baseProducer.skipRepeats { $0.count == $1.count }

				var values: [String] = []
				producer.startWithValues { values.append($0) }

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
		}

		describe("skipWhile") {
			var producer: SignalProducer<Int, Never>!
			var observer: Signal<Int, Never>.Observer!

			var lastValue: Int?

			beforeEach {
				let (baseProducer, incomingObserver) = SignalProducer<Int, Never>.pipe()

				producer = baseProducer.skip { $0 < 2 }
				observer = incomingObserver
				lastValue = nil

				producer.startWithValues { lastValue = $0 }
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
			var producer: SignalProducer<Int, Never>!
			var observer: Signal<Int, Never>.Observer!
			var triggerObserver: Signal<(), Never>.Observer!

			var lastValue: Int? = nil

			beforeEach {
				let (baseProducer, baseIncomingObserver) = SignalProducer<Int, Never>.pipe()
				let (triggerProducer, incomingTriggerObserver) = SignalProducer<(), Never>.pipe()

				producer = baseProducer.skip(until: triggerProducer)
				observer = baseIncomingObserver
				triggerObserver = incomingTriggerObserver

				lastValue = nil

				producer.start { event in
					switch event {
					case let .value(value):
						lastValue = value
					case .failed, .completed, .interrupted:
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

			it("should be able to fallback to SignalProducer for contextual lookups") {
				_ = SignalProducer<Int, Never>.empty
					.skip(until: .init(value: ()))
			}
		}

		describe("take") {
			it("should take initial values") {
				let (baseProducer, observer) = SignalProducer<Int, Never>.pipe()
				let producer = baseProducer.take(first: 2)

				var lastValue: Int?
				var completed = false
				producer.start { event in
					switch event {
					case let .value(value):
						lastValue = value
					case .completed:
						completed = true
					case .failed, .interrupted:
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

				let producer: SignalProducer<Int, Never> = SignalProducer { observer, _ in
					// workaround `Class declaration cannot close over value 'observer' defined in outer scope`
					let observer = observer

					testScheduler.schedule {
						for number in numbers {
							observer.send(value: number)
						}
					}
				}

				var completed = false

				producer
					.take(first: numbers.count)
					.startWithCompleted { completed = true }

				expect(completed) == false
				testScheduler.run()
				expect(completed) == true
			}

			it("should interrupt when 0") {
				let numbers = [ 1, 2, 4, 4, 5 ]
				let testScheduler = TestScheduler()

				let producer: SignalProducer<Int, Never> = SignalProducer { observer, _ in
					// workaround `Class declaration cannot close over value 'observer' defined in outer scope`
					let observer = observer

					testScheduler.schedule {
						for number in numbers {
							observer.send(value: number)
						}
					}
				}

				var result: [Int] = []
				var interrupted = false

				producer
				.take(first: 0)
				.start { event in
					switch event {
					case let .value(number):
						result.append(number)
					case .interrupted:
						interrupted = true
					case .failed, .completed:
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
				let (original, observer) = SignalProducer<Int, Never>.pipe()
				let producer = original.collect()
				let expectedResult = [ 1, 2, 3 ]

				var result: [Int]?

				producer.startWithValues { value in
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
				let (original, observer) = SignalProducer<Int, Never>.pipe()
				let producer = original.collect()

				var result: [Int]?

				producer.startWithValues { result = $0 }

				expect(result).to(beNil())
				observer.sendCompleted()
				expect(result) == []
			}

			it("should forward errors") {
				let (original, observer) = SignalProducer<Int, TestError>.pipe()
				let producer = original.collect()

				var error: TestError?

				producer.startWithFailed { error = $0 }

				expect(error).to(beNil())
				observer.send(error: .default)
				expect(error) == TestError.default
			}

			it("should collect an exact count of values") {
				let (original, observer) = SignalProducer<Int, Never>.pipe()

				let producer = original.collect(count: 3)

				var observedValues: [[Int]] = []

				producer.startWithValues { value in
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
				let (original, observer) = SignalProducer<Int, Never>.pipe()

				let producer = original.collect { _, value in value != 5 }

				var expectedValues = [
					[5, 5],
					[42, 5],
				]

				producer.startWithValues { value in
					expect(value) == expectedValues.removeFirst()
				}

				producer.startWithCompleted {
					expect(expectedValues._bridgeToObjectiveC()) == []._bridgeToObjectiveC()
				}

				expectedValues
					.flatMap { $0 }
					.forEach(observer.send(value:))

				observer.sendCompleted()
			}

			it("should collect values until it matches a certain condition on values") {
				let (original, observer) = SignalProducer<Int, Never>.pipe()

				let producer = original.collect { values in values.reduce(0, +) == 10 }

				var expectedValues = [
					[1, 2, 3, 4],
					[5, 6, 7, 8, 9],
				]

				producer.startWithValues { value in
					expect(value) == expectedValues.removeFirst()
				}

				producer.startWithCompleted {
					expect(expectedValues._bridgeToObjectiveC()) == []._bridgeToObjectiveC()
				}

				expectedValues
					.flatMap { $0 }
					.forEach(observer.send(value:))

				observer.sendCompleted()
			}

		}

		describe("takeUntil") {
			var producer: SignalProducer<Int, Never>!
			var observer: Signal<Int, Never>.Observer!
			var triggerObserver: Signal<(), Never>.Observer!

			var lastValue: Int? = nil
			var completed: Bool = false

			beforeEach {
				let (baseProducer, baseIncomingObserver) = SignalProducer<Int, Never>.pipe()
				let (triggerProducer, incomingTriggerObserver) = SignalProducer<(), Never>.pipe()

				producer = baseProducer.take(until: triggerProducer)
				observer = baseIncomingObserver
				triggerObserver = incomingTriggerObserver

				lastValue = nil
				completed = false

				producer.start { event in
					switch event {
					case let .value(value):
						lastValue = value
					case .completed:
						completed = true
					case .failed, .interrupted:
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

			it("should be able to fallback to SignalProducer for contextual lookups") {
				_ = SignalProducer<Int, Never>.empty
					.take(until: .init(value: ()))
			}
		}

		describe("takeUntilReplacement") {
			var producer: SignalProducer<Int, Never>!
			var observer: Signal<Int, Never>.Observer!
			var replacementObserver: Signal<Int, Never>.Observer!

			var lastValue: Int? = nil
			var completed: Bool = false

			beforeEach {
				let (baseProducer, incomingObserver) = SignalProducer<Int, Never>.pipe()
				let (replacementProducer, incomingReplacementObserver) = SignalProducer<Int, Never>.pipe()

				producer = baseProducer.take(untilReplacement: replacementProducer)
				observer = incomingObserver
				replacementObserver = incomingReplacementObserver

				lastValue = nil
				completed = false

				producer.start { event in
					switch event {
					case let .value(value):
						lastValue = value
					case .completed:
						completed = true
					case .failed, .interrupted:
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

			it("should be able to fallback to SignalProducer for contextual lookups") {
				_ = SignalProducer<Int, Never>.empty
					.take(untilReplacement: .init(value: 0))
			}
		}

		describe("takeWhile") {
			var producer: SignalProducer<Int, Never>!
			var observer: Signal<Int, Never>.Observer!

			beforeEach {
				let (baseProducer, incomingObserver) = SignalProducer<Int, Never>.pipe()
				producer = baseProducer.take(while: { $0 <= 4 })
				observer = incomingObserver
			}

			it("should take while the predicate is true") {
				var latestValue: Int!
				var completed = false

				producer.start { event in
					switch event {
					case let .value(value):
						latestValue = value
					case .completed:
						completed = true
					case .failed, .interrupted:
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

				producer.start { event in
					switch event {
					case let .value(value):
						latestValue = value
					case .completed:
						completed = true
					case .failed, .interrupted:
						break
					}
				}

				observer.send(value: 5)
				expect(latestValue).to(beNil())
				expect(completed) == true
			}
		}
		
		describe("takeUntil") {
			var producer: SignalProducer<Int, Never>!
			var observer: Signal<Int, Never>.Observer!
			
			beforeEach {
				let (baseProducer, incomingObserver) = SignalProducer<Int, Never>.pipe()
				producer = baseProducer.take(until: { $0 <= 4 })
				observer = incomingObserver
			}
			
			it("should take until the predicate is true") {
				var latestValue: Int!
				var completed = false
				
				producer.start { event in
					switch event {
					case let .value(value):
						latestValue = value
					case .completed:
						completed = true
					case .failed, .interrupted:
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
				
				producer.start { event in
					switch event {
					case let .value(value):
						latestValue = value
					case .completed:
						completed = true
					case .failed, .interrupted:
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
				let (producer, observer) = SignalProducer<Int, Never>.pipe()

				var result: [Int] = []

				producer
					.observe(on: testScheduler)
					.startWithValues { result.append($0) }

				observer.send(value: 1)
				observer.send(value: 2)
				expect(result).to(beEmpty())

				testScheduler.run()
				expect(result) == [ 1, 2 ]
			}

			it("should interrupt ASAP and discard outstanding events") {
				testAsyncASAPInterruption(op: "observe(on:)") { $0.observe(on: $1) }
			}

			it("should interrupt on the given scheduler") {
				testAsyncInterruptionScheduler(op: "observe(on:)") { $0.observe(on: $1) }
			}
		}

		describe("delay") {
			it("should send events on the given scheduler after the interval") {
				let testScheduler = TestScheduler()
				let producer: SignalProducer<Int, Never> = SignalProducer { observer, _ in
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

				producer
					.delay(10, on: testScheduler)
					.start { event in
						switch event {
						case let .value(number):
							result.append(number)
						case .completed:
							completed = true
						case .failed, .interrupted:
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
				let producer: SignalProducer<Int, TestError> = SignalProducer { observer, _ in
					// workaround `Class declaration cannot close over value 'observer' defined in outer scope`
					let observer = observer

					testScheduler.schedule {
						observer.send(error: TestError.default)
					}
				}

				var errored = false

				producer
					.delay(10, on: testScheduler)
					.startWithFailed { _ in errored = true }

				testScheduler.advance()
				expect(errored) == true
			}

			it("should interrupt ASAP and discard outstanding events") {
				testAsyncASAPInterruption(op: "delay") { $0.delay(10.0, on: $1) }
			}

			it("should interrupt on the given scheduler") {
				testAsyncInterruptionScheduler(op: "delay") { $0.delay(10.0, on: $1) }
			}
		}

		describe("throttle") {
			var scheduler: TestScheduler!
			var observer: Signal<Int, Never>.Observer!
			var producer: SignalProducer<Int, Never>!

			beforeEach {
				scheduler = TestScheduler()

				let (baseProducer, baseObserver) = SignalProducer<Int, Never>.pipe()
				observer = baseObserver

				producer = baseProducer.throttle(1, on: scheduler)
			}

			it("should send values on the given scheduler at no less than the interval") {
				var values: [Int] = []
				producer.startWithValues { value in
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

				producer.start { event in
					switch event {
					case let .value(value):
						values.append(value)
					case .completed:
						completed = true
					case .failed, .interrupted:
						break
					}
				}

				observer.send(value: 0)
				scheduler.advance()
				expect(values) == [ 0 ]

				observer.send(value: 1)
				observer.sendCompleted()
				expect(completed) == false

				scheduler.run()
				expect(values) == [ 0 ]
				expect(completed) == true
			}

			it("should interrupt ASAP and discard outstanding events") {
				testAsyncASAPInterruption(op: "throttle") { $0.throttle(10.0, on: $1) }
			}

			it("should interrupt on the given scheduler") {
				testAsyncInterruptionScheduler(op: "throttle") { $0.throttle(10.0, on: $1) }
			}
		}

		describe("debounce") {
			it("should interrupt ASAP and discard outstanding events") {
				testAsyncASAPInterruption(op: "debounce") { $0.debounce(10.0, on: $1, discardWhenCompleted: true) }
			}
			
			it("should interrupt ASAP and discard outstanding events") {
				testAsyncASAPInterruption(op: "debounce") { $0.debounce(10.0, on: $1, discardWhenCompleted: false) }
			}

			it("should interrupt on the given scheduler") {
				testAsyncInterruptionScheduler(op: "debounce") { $0.debounce(10.0, on: $1, discardWhenCompleted: true) }
			}
			
			it("should interrupt on the given scheduler") {
				testAsyncInterruptionScheduler(op: "debounce") { $0.debounce(10.0, on: $1, discardWhenCompleted: false) }
			}
		}

		describe("sampleWith") {
			var sampledProducer: SignalProducer<(Int, String), Never>!
			var observer: Signal<Int, Never>.Observer!
			var samplerObserver: Signal<String, Never>.Observer!

			beforeEach {
				let (producer, incomingObserver) = SignalProducer<Int, Never>.pipe()
				let (sampler, incomingSamplerObserver) = SignalProducer<String, Never>.pipe()
				sampledProducer = producer.sample(with: sampler)
				observer = incomingObserver
				samplerObserver = incomingSamplerObserver
			}

			it("should forward the latest value when the sampler fires") {
				var result: [String] = []
				sampledProducer.startWithValues { result.append("\($0.0)\($0.1)") }

				observer.send(value: 1)
				observer.send(value: 2)
				samplerObserver.send(value: "a")
				expect(result) == [ "2a" ]
			}

			it("should do nothing if sampler fires before signal receives value") {
				var result: [String] = []
				sampledProducer.startWithValues { result.append("\($0.0)\($0.1)") }

				samplerObserver.send(value: "a")
				expect(result).to(beEmpty())
			}

			it("should send lates value multiple times when sampler fires multiple times") {
				var result: [String] = []
				sampledProducer.startWithValues { result.append("\($0.0)\($0.1)") }

				observer.send(value: 1)
				samplerObserver.send(value: "a")
				samplerObserver.send(value: "b")
				expect(result) == [ "1a", "1b" ]
			}

			it("should complete when both inputs have completed") {
				var completed = false
				sampledProducer.startWithCompleted { completed = true }

				observer.sendCompleted()
				expect(completed) == false

				samplerObserver.sendCompleted()
				expect(completed) == true
			}

			it("should emit an initial value if the sampler is a synchronous SignalProducer") {
				let producer = SignalProducer<Int, Never>([1])
				let sampler = SignalProducer<String, Never>(value: "a")

				let result = producer.sample(with: sampler)

				var valueReceived: String?
				result.startWithValues { valueReceived = "\($0.0)\($0.1)" }

				expect(valueReceived) == "1a"
			}

			it("should be able to fallback to SignalProducer for contextual lookups") {
				_ = SignalProducer<Int, Never>.empty
					.sample(with: .init(value: 0))
			}
		}

		describe("sampleOn") {
			var sampledProducer: SignalProducer<Int, Never>!
			var observer: Signal<Int, Never>.Observer!
			var samplerObserver: Signal<(), Never>.Observer!

			beforeEach {
				let (producer, incomingObserver) = SignalProducer<Int, Never>.pipe()
				let (sampler, incomingSamplerObserver) = SignalProducer<(), Never>.pipe()
				sampledProducer = producer.sample(on: sampler)
				observer = incomingObserver
				samplerObserver = incomingSamplerObserver
			}

			it("should forward the latest value when the sampler fires") {
				var result: [Int] = []
				sampledProducer.startWithValues { result.append($0) }

				observer.send(value: 1)
				observer.send(value: 2)
				samplerObserver.send(value: ())
				expect(result) == [ 2 ]
			}

			it("should do nothing if sampler fires before signal receives value") {
				var result: [Int] = []
				sampledProducer.startWithValues { result.append($0) }

				samplerObserver.send(value: ())
				expect(result).to(beEmpty())
			}

			it("should send lates value multiple times when sampler fires multiple times") {
				var result: [Int] = []
				sampledProducer.startWithValues { result.append($0) }

				observer.send(value: 1)
				samplerObserver.send(value: ())
				samplerObserver.send(value: ())
				expect(result) == [ 1, 1 ]
			}

			it("should complete when both inputs have completed") {
				var completed = false
				sampledProducer.startWithCompleted { completed = true }

				observer.sendCompleted()
				expect(completed) == false

				samplerObserver.sendCompleted()
				expect(completed) == true
			}

			it("should emit an initial value if the sampler is a synchronous SignalProducer") {
				let producer = SignalProducer<Int, Never>([1])
				let sampler = SignalProducer<(), Never>(value: ())

				let result = producer.sample(on: sampler)

				var valueReceived: Int?
				result.startWithValues { valueReceived = $0 }

				expect(valueReceived) == 1
			}

			describe("memory") {
				class Payload {
					let action: () -> Void

					init(onDeinit action: @escaping () -> Void) {
						self.action = action
					}

					deinit {
						action()
					}
				}

				var sampledProducer: SignalProducer<Payload, Never>!
				var samplerObserver: Signal<(), Never>.Observer!
				var observer: Signal<Payload, Never>.Observer!

				// Mitigate the "was written to, but never read" warning.
				_ = samplerObserver

				beforeEach {
					let (producer, incomingObserver) = SignalProducer<Payload, Never>.pipe()
					let (sampler, _samplerObserver) = Signal<(), Never>.pipe()
					sampledProducer = producer.sample(on: sampler)
					samplerObserver = _samplerObserver
					observer = incomingObserver
				}

				it("should free payload when interrupted after complete of incoming producer") {
					var payloadFreed = false

					let disposable = sampledProducer.start()

					observer.send(value: Payload { payloadFreed = true })
					observer.sendCompleted()

					expect(payloadFreed) == false

					disposable.dispose()
					expect(payloadFreed) == true
				}
			}

			it("should be able to fallback to SignalProducer for contextual lookups") {
				_ = SignalProducer<Int, Never>.empty
					.sample(on: .init(value: ()))
			}
		}

		describe("withLatest(from: signal)") {
			var withLatestProducer: SignalProducer<(Int, String), Never>!
			var observer: Signal<Int, Never>.Observer!
			var sampleeObserver: Signal<String, Never>.Observer!

			beforeEach {
				let (producer, incomingObserver) = SignalProducer<Int, Never>.pipe()
				let (samplee, incomingSampleeObserver) = Signal<String, Never>.pipe()
				withLatestProducer = producer.withLatest(from: samplee)
				observer = incomingObserver
				sampleeObserver = incomingSampleeObserver
			}

			it("should forward the latest value when the receiver fires") {
				var result: [String] = []
				withLatestProducer.startWithValues { result.append("\($0.0)\($0.1)") }

				sampleeObserver.send(value: "a")
				sampleeObserver.send(value: "b")
				observer.send(value: 1)
				expect(result) == [ "1b" ]
			}

			it("should do nothing if receiver fires before samplee sends value") {
				var result: [String] = []
				withLatestProducer.startWithValues { result.append("\($0.0)\($0.1)") }

				observer.send(value: 1)
				expect(result).to(beEmpty())
			}

			it("should send latest value with samplee value multiple times when receiver fires multiple times") {
				var result: [String] = []
				withLatestProducer.startWithValues { result.append("\($0.0)\($0.1)") }

				sampleeObserver.send(value: "a")
				observer.send(value: 1)
				observer.send(value: 2)
				expect(result) == [ "1a", "2a" ]
			}

			it("should complete when receiver has completed") {
				var completed = false
				withLatestProducer.startWithCompleted { completed = true }

				observer.sendCompleted()
				expect(completed) == true
			}

			it("should not affect when samplee has completed") {
				var event: Signal<(Int, String), Never>.Event? = nil
				withLatestProducer.start { event = $0 }

				sampleeObserver.sendCompleted()
				expect(event).to(beNil())
			}

			it("should not affect when samplee has interrupted") {
				var event: Signal<(Int, String), Never>.Event? = nil
				withLatestProducer.start { event = $0 }

				sampleeObserver.sendInterrupted()
				expect(event).to(beNil())
			}
		}

		describe("withLatest(from: producer)") {
			var withLatestProducer: SignalProducer<(Int, String), Never>!
			var observer: Signal<Int, Never>.Observer!
			var sampleeObserver: Signal<String, Never>.Observer!

			beforeEach {
				let (producer, incomingObserver) = SignalProducer<Int, Never>.pipe()
				let (samplee, incomingSampleeObserver) = SignalProducer<String, Never>.pipe()
				withLatestProducer = producer.withLatest(from: samplee)
				observer = incomingObserver
				sampleeObserver = incomingSampleeObserver
			}

			it("should forward the latest value when the receiver fires") {
				var result: [String] = []
				withLatestProducer.startWithValues { result.append("\($0.0)\($0.1)") }

				sampleeObserver.send(value: "a")
				sampleeObserver.send(value: "b")
				observer.send(value: 1)
				expect(result) == [ "1b" ]
			}

			it("should do nothing if receiver fires before samplee sends value") {
				var result: [String] = []
				withLatestProducer.startWithValues { result.append("\($0.0)\($0.1)") }

				observer.send(value: 1)
				expect(result).to(beEmpty())
			}

			it("should send latest value with samplee value multiple times when receiver fires multiple times") {
				var result: [String] = []
				withLatestProducer.startWithValues { result.append("\($0.0)\($0.1)") }

				sampleeObserver.send(value: "a")
				observer.send(value: 1)
				observer.send(value: 2)
				expect(result) == [ "1a", "2a" ]
			}

			it("should complete when receiver has completed") {
				var completed = false
				withLatestProducer.startWithCompleted { completed = true }

				observer.sendCompleted()
				expect(completed) == true
			}

			it("should not affect when samplee has completed") {
				var event: Signal<(Int, String), Never>.Event? = nil
				withLatestProducer.start { event = $0 }

				sampleeObserver.sendCompleted()
				expect(event).to(beNil())
			}

			it("should not affect when samplee has interrupted") {
				var event: Signal<(Int, String), Never>.Event? = nil
				withLatestProducer.start { event = $0 }

				sampleeObserver.sendInterrupted()
				expect(event).to(beNil())
			}

			it("should be able to fallback to SignalProducer for contextual lookups") {
				_ = SignalProducer<Int, Never>.empty
					.withLatest(from: .init(value: 0))
			}
		}

		describe("combineLatestWith") {
			var combinedProducer: SignalProducer<(Int, Double), Never>!
			var observer: Signal<Int, Never>.Observer!
			var otherObserver: Signal<Double, Never>.Observer!

			beforeEach {
				let (producer, incomingObserver) = SignalProducer<Int, Never>.pipe()
				let (otherSignal, incomingOtherObserver) = SignalProducer<Double, Never>.pipe()
				combinedProducer = producer.combineLatest(with: otherSignal)
				observer = incomingObserver
				otherObserver = incomingOtherObserver
			}

			it("should forward the latest values from both inputs") {
				var latest: (Int, Double)?
				combinedProducer.startWithValues { latest = $0 }

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
				combinedProducer.startWithCompleted { completed = true }

				observer.sendCompleted()
				expect(completed) == false

				otherObserver.sendCompleted()
				expect(completed) == true
			}

			it("should be able to fallback to SignalProducer for contextual lookups") {
				_ = SignalProducer<Int, Never>.empty
					.combineLatest(with: .init(value: 0))
			}
		}

		describe("zipWith") {
			var leftObserver: Signal<Int, Never>.Observer!
			var rightObserver: Signal<String, Never>.Observer!
			var zipped: SignalProducer<(Int, String), Never>!

			beforeEach {
				let (leftProducer, incomingLeftObserver) = SignalProducer<Int, Never>.pipe()
				let (rightProducer, incomingRightObserver) = SignalProducer<String, Never>.pipe()

				leftObserver = incomingLeftObserver
				rightObserver = incomingRightObserver
				zipped = leftProducer.zip(with: rightProducer)
			}

			it("should combine pairs") {
				var result: [String] = []
				zipped.startWithValues { result.append("\($0.0)\($0.1)") }

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

				zipped.start { event in
					switch event {
					case let .value((left, right)):
						result.append("\(left)\(right)")
					case .completed:
						completed = true
					case .failed, .interrupted:
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

			it("should be able to fallback to SignalProducer for contextual lookups") {
				_ = SignalProducer<Int, Never>.empty
					.zip(with: .init(value: 0))
			}
		}

		describe("materialize") {
			it("should reify events from the signal") {
				let (producer, observer) = SignalProducer<Int, TestError>.pipe()
				var latestEvent: Signal<Int, TestError>.Event?
				producer
					.materialize()
					.startWithValues { latestEvent = $0 }

				observer.send(value: 2)

				expect(latestEvent).toNot(beNil())
				if let latestEvent = latestEvent {
					switch latestEvent {
					case let .value(value):
						expect(value) == 2
					case .failed, .completed, .interrupted:
						fail()
					}
				}

				observer.send(error: TestError.default)
				if let latestEvent = latestEvent {
					switch latestEvent {
					case .failed:
						break
					case .value, .completed, .interrupted:
						fail()
					}
				}
			}
		}

		describe("dematerialize") {
			typealias IntEvent = Signal<Int, TestError>.Event
			var observer: Signal<IntEvent, Never>.Observer!
			var dematerialized: SignalProducer<Int, TestError>!

			beforeEach {
				let (producer, incomingObserver) = SignalProducer<IntEvent, Never>.pipe()
				observer = incomingObserver
				dematerialized = producer.dematerialize()
			}

			it("should send values for Value events") {
				var result: [Int] = []
				dematerialized
					.assumeNoErrors()
					.startWithValues { result.append($0) }

				expect(result).to(beEmpty())

				observer.send(value: .value(2))
				expect(result) == [ 2 ]

				observer.send(value: .value(4))
				expect(result) == [ 2, 4 ]
			}

			it("should error out for Error events") {
				var errored = false
				dematerialized.startWithFailed { _ in errored = true }

				expect(errored) == false

				observer.send(value: .failed(TestError.default))
				expect(errored) == true
			}

			it("should complete early for Completed events") {
				var completed = false
				dematerialized.startWithCompleted { completed = true }

				expect(completed) == false
				observer.send(value: IntEvent.completed)
				expect(completed) == true
			}
		}

		describe("materializeResults") {
			it("should reify results from the signal") {
				let (producer, observer) = SignalProducer<Int, TestError>.pipe()
				var latestResult: Result<Int, TestError>?
				producer
					.materializeResults()
					.startWithValues { latestResult = $0 }

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
			var dematerialized: SignalProducer<Int, TestError>!

			beforeEach {
				let (producer, incomingObserver) = SignalProducer<IntResult, Never>.pipe()
				observer = incomingObserver
				dematerialized = producer.dematerializeResults()
			}

			it("should send values for Value results") {
				var result: [Int] = []
				dematerialized
					.assumeNoErrors()
					.startWithValues { result.append($0) }

				expect(result).to(beEmpty())

				observer.send(value: .success(2))
				expect(result) == [ 2 ]

				observer.send(value: .success(4))
				expect(result) == [ 2, 4 ]
			}

			it("should error out for Error results") {
				var errored = false
				dematerialized.startWithFailed { _ in errored = true }

				expect(errored) == false

				observer.send(value: .failure(TestError.default))
				expect(errored) == true
			}
		}

		describe("takeLast") {
			var observer: Signal<Int, TestError>.Observer!
			var lastThree: SignalProducer<Int, TestError>!

			beforeEach {
				let (producer, incomingObserver) = SignalProducer<Int, TestError>.pipe()
				observer = incomingObserver
				lastThree = producer.take(last: 3)
			}

			it("should send the last N values upon completion") {
				var result: [Int] = []
				lastThree
					.assumeNoErrors()
					.startWithValues { result.append($0) }

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
					.startWithValues { result.append($0) }

				observer.send(value: 1)
				observer.send(value: 2)
				observer.sendCompleted()
				expect(result) == [ 1, 2 ]
			}

			it("should send nothing when errors") {
				var result: [Int] = []
				var errored = false
				lastThree.start { event in
					switch event {
					case let .value(value):
						result.append(value)
					case .failed:
						errored = true
					case .completed, .interrupted:
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
			var producer: SignalProducer<Int, TestError>!
			var observer: Signal<Int, TestError>.Observer!

			beforeEach {
				testScheduler = TestScheduler()
				let (baseProducer, incomingObserver) = SignalProducer<Int, TestError>.pipe()
				producer = baseProducer.timeout(after: 2, raising: TestError.default, on: testScheduler)
				observer = incomingObserver
			}

			it("should complete if within the interval") {
				var completed = false
				var errored = false
				producer.start { event in
					switch event {
					case .completed:
						completed = true
					case .failed:
						errored = true
					case .value, .interrupted:
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
				producer.start { event in
					switch event {
					case .completed:
						completed = true
					case .failed:
						errored = true
					case .value, .interrupted:
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
				let producer: SignalProducer<Int, TestError> = SignalProducer<Int, Never>.never
					.timeout(after: 2, raising: TestError.default, on: testScheduler)

				_ = producer
			}
		}

		describe("attempt") {
			it("should forward original values upon success") {
				let (baseProducer, observer) = SignalProducer<Int, TestError>.pipe()
				let producer = baseProducer.attempt { _ in
					return .success(())
				}

				var current: Int?
				producer
					.assumeNoErrors()
					.startWithValues { value in
						current = value
					}

				for value in 1...5 {
					observer.send(value: value)
					expect(current) == value
				}
			}

			it("should error if an attempt fails") {
				let (baseProducer, observer) = SignalProducer<Int, TestError>.pipe()
				let producer = baseProducer.attempt { _ in
					return .failure(.default)
				}

				var error: TestError?
				producer.startWithFailed { err in
					error = err
				}

				observer.send(value: 42)
				expect(error) == TestError.default
			}
		}

		describe("attemptMap") {
			it("should forward mapped values upon success") {
				let (baseProducer, observer) = SignalProducer<Int, TestError>.pipe()
				let producer = baseProducer.attemptMap { num -> Result<Bool, TestError> in
					return .success(num % 2 == 0)
				}

				var even: Bool?
				producer
					.assumeNoErrors()
					.startWithValues { value in
						even = value
					}

				observer.send(value: 1)
				expect(even) == false

				observer.send(value: 2)
				expect(even) == true
			}

			it("should error if a mapping fails") {
				let (baseProducer, observer) = SignalProducer<Int, TestError>.pipe()
				let producer = baseProducer.attemptMap { _ -> Result<Bool, TestError> in
					return .failure(.default)
				}

				var error: TestError?
				producer.startWithFailed { err in
					error = err
				}

				observer.send(value: 42)
				expect(error) == TestError.default
			}
		}

		describe("combinePrevious") {
			var observer: Signal<Int, Never>.Observer!
			let initialValue: Int = 0
			var latestValues: (Int, Int)?

			beforeEach {
				latestValues = nil

				let (signal, baseObserver) = SignalProducer<Int, Never>.pipe()
				observer = baseObserver
				signal.combinePrevious(initialValue).startWithValues { latestValues = $0 }
			}

			it("should forward the latest value with previous value") {
				expect(latestValues).to(beNil())

				observer.send(value: 1)
				expect(latestValues?.0) == initialValue
				expect(latestValues?.1) == 1

				observer.send(value: 2)
				expect(latestValues?.0) == 1
				expect(latestValues?.1) == 2
			}
		}
	}
}

private func testAsyncInterruptionScheduler(
	op: String,
	file: FileString = #file,
	line: UInt = #line,
	transform: (SignalProducer<Int, Never>, TestScheduler) -> SignalProducer<Int, Never>
) {
	var isInterrupted = false

	let scheduler = TestScheduler()
	let producer = transform(SignalProducer(0 ..< 128), scheduler)

	let failedExpectations = gatherFailingExpectations {
		let disposable = producer.startWithInterrupted { isInterrupted = true }
		expect(isInterrupted) == false

		disposable.dispose()
		expect(isInterrupted) == false

		scheduler.run()
		expect(isInterrupted) == true
	}

	if !failedExpectations.isEmpty {
		fail("The async operator `\(op)` does not interrupt on the appropriate scheduler.",
			 location: SourceLocation(file: file, line: line))
	}
}

private func testAsyncASAPInterruption(
	op: String,
	file: FileString = #file,
	line: UInt = #line,
	transform: (SignalProducer<Int, Never>, TestScheduler) -> SignalProducer<Int, Never>
) {
	var valueCount = 0
	var interruptCount = 0
	var unexpectedEventCount = 0

	let scheduler = TestScheduler()

	let disposable = transform(SignalProducer(0 ..< 128), scheduler)
		.start { event in
			switch event {
			case .value:
				valueCount += 1
			case .interrupted:
				interruptCount += 1
			case .failed, .completed:
				unexpectedEventCount += 1
			}
	}

	expect(interruptCount) == 0
	expect(unexpectedEventCount) == 0
	expect(valueCount) == 0

	disposable.dispose()
	scheduler.run()

	let failedExpectations = gatherFailingExpectations {
		expect(interruptCount) == 1
		expect(unexpectedEventCount) == 0
		expect(valueCount) == 0
	}

	if !failedExpectations.isEmpty {
		fail("The ASAP interruption test of the async operator `\(op)` has failed.",
			 location: SourceLocation(file: file, line: line))
	}
}
