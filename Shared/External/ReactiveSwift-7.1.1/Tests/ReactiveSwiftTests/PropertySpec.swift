//
//  PropertySpec.swift
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

private let initialPropertyValue = "InitialValue"
private let subsequentPropertyValue = "SubsequentValue"
private let finalPropertyValue = "FinalValue"

private let initialOtherPropertyValue = "InitialOtherValue"
private let subsequentOtherPropertyValue = "SubsequentOtherValue"
private let finalOtherPropertyValue = "FinalOtherValue"

class PropertySpec: QuickSpec {
	override func spec() {
		describe("MutableProperty") {
			it("should have the value given at initialization") {
				let mutableProperty = MutableProperty(initialPropertyValue)

				expect(mutableProperty.value) == initialPropertyValue
			}

			it("should yield a producer that sends the current value then all changes") {
				let mutableProperty = MutableProperty(initialPropertyValue)
				var sentValue: String?

				mutableProperty.producer.startWithValues { sentValue = $0 }

				expect(sentValue) == initialPropertyValue

				mutableProperty.value = subsequentPropertyValue
				expect(sentValue) == subsequentPropertyValue

				mutableProperty.value = finalPropertyValue
				expect(sentValue) == finalPropertyValue
			}

			it("should yield a producer that sends the current value then all changes, even if the value actually remains unchanged") {
				let mutableProperty = MutableProperty(initialPropertyValue)
				var count = 0

				mutableProperty.producer.startWithValues { _ in count = count + 1 }

				expect(count) == 1

				mutableProperty.value = initialPropertyValue
				expect(count) == 2

				mutableProperty.value = initialPropertyValue
				expect(count) == 3
			}

			it("should yield a signal that emits subsequent changes to the value") {
				let mutableProperty = MutableProperty(initialPropertyValue)
				var sentValue: String?

				mutableProperty.signal.observeValues { sentValue = $0 }

				expect(sentValue).to(beNil())

				mutableProperty.value = subsequentPropertyValue
				expect(sentValue) == subsequentPropertyValue

				mutableProperty.value = finalPropertyValue
				expect(sentValue) == finalPropertyValue
			}

			it("should yield a signal that emits subsequent changes to the value, even if the value actually remains unchanged") {
				let mutableProperty = MutableProperty(initialPropertyValue)
				var count = 0

				mutableProperty.signal.observeValues { _ in count = count + 1 }

				expect(count) == 0

				mutableProperty.value = initialPropertyValue
				expect(count) == 1

				mutableProperty.value = initialPropertyValue
				expect(count) == 2
			}

			it("should complete its producer when deallocated") {
				var mutableProperty: MutableProperty? = MutableProperty(initialPropertyValue)
				var producerCompleted = false

				mutableProperty!.producer.startWithCompleted { producerCompleted = true }

				mutableProperty = nil
				expect(producerCompleted) == true
			}

			it("should complete its signal when deallocated") {
				var mutableProperty: MutableProperty? = MutableProperty(initialPropertyValue)
				var signalCompleted = false

				withExtendedLifetime(mutableProperty) {
					_ = $0!.signal.observeCompleted { signalCompleted = true }
				}

				mutableProperty = nil
				expect(mutableProperty).to(beNil())
				expect(signalCompleted) == true
			}

			it("should yield a producer which emits the latest value and complete even if the property is deallocated") {
				var mutableProperty: MutableProperty? = MutableProperty(initialPropertyValue)
				let producer = mutableProperty!.producer

				var producerCompleted = false
				var hasUnanticipatedEvent = false
				var latestValue = mutableProperty?.value

				mutableProperty!.value = subsequentPropertyValue
				mutableProperty = nil

				producer.start { event in
					switch event {
					case let .value(value):
						latestValue = value
					case .completed:
						producerCompleted = true
					case .interrupted, .failed:
						hasUnanticipatedEvent = true
					}
				}

				expect(hasUnanticipatedEvent) == false
				expect(producerCompleted) == true
				expect(latestValue) == subsequentPropertyValue
			}

			it("should modify the value atomically") {
				let property = MutableProperty(initialPropertyValue)

				property.modify { $0 = subsequentPropertyValue }
				expect(property.value) == subsequentPropertyValue
			}

			it("should modify the value atomically and subsquently send out a Value event with the new value") {
				let property = MutableProperty(initialPropertyValue)
				var value: String?

				property.producer.startWithValues {
					value = $0
				}

				expect(value) == initialPropertyValue

				property.modify { $0 = subsequentPropertyValue }
				expect(property.value) == subsequentPropertyValue
				expect(value) == subsequentPropertyValue
			}

			it("should swap the value atomically") {
				let property = MutableProperty(initialPropertyValue)

				expect(property.swap(subsequentPropertyValue)) == initialPropertyValue
				expect(property.value) == subsequentPropertyValue
			}

			it("should swap the value atomically and subsquently send out a Value event with the new value") {
				let property = MutableProperty(initialPropertyValue)
				var value: String?

				property.producer.startWithValues {
					value = $0
				}

				expect(value) == initialPropertyValue
				expect(property.swap(subsequentPropertyValue)) == initialPropertyValue

				expect(property.value) == subsequentPropertyValue
				expect(value) == subsequentPropertyValue
			}

			it("should perform an action with the value") {
				let property = MutableProperty(initialPropertyValue)

				let result: Bool = property.withValue { $0.isEmpty }

				expect(result) == false
				expect(property.value) == initialPropertyValue
			}

			it("should not deadlock on recursive value access") {
				let (producer, observer) = SignalProducer<Int, Never>.pipe()
				let property = MutableProperty(0)
				var value: Int?

				property <~ producer
				property.producer.startWithValues { _ in
					value = property.value
				}

				observer.send(value: 10)
				expect(value) == 10
			}

			it("should not deadlock on recursive value access with a closure") {
				let (producer, observer) = SignalProducer<Int, Never>.pipe()
				let property = MutableProperty(0)
				var value: Int?

				property <~ producer
				property.producer.startWithValues { _ in
					value = property.withValue { $0 + 1 }
				}

				observer.send(value: 10)
				expect(value) == 11
			}

			it("should not deadlock on recursive observation") {
				let property = MutableProperty(0)

				var value: Int?
				property.producer.startWithValues { _ in
					property.producer.startWithValues { x in value = x }
				}

				expect(value) == 0

				property.value = 1
				expect(value) == 1
			}

			it("should not deadlock on recursive ABA observation") {
				let propertyA = MutableProperty(0)
				let propertyB = MutableProperty(0)

				var value: Int?
				propertyA.producer.startWithValues { _ in
					propertyB.producer.startWithValues { _ in
						propertyA.producer.startWithValues { x in value = x }
					}
				}

				expect(value) == 0

				propertyA.value = 1
				expect(value) == 1
			}

			it("should expose a lifetime that ends upon its deinitialization") {
				var property = Optional(MutableProperty<Int>(1))

				var isEnded = false

				withExtendedLifetime(property!) { property in
					property.lifetime.observeEnded {
						isEnded = true
					}

					expect(isEnded) == false

					property.value = 2
					expect(isEnded) == false
				}

				property = nil
				expect(isEnded) == true
			}

			it("should not deadlock") {
				let queue = DispatchQueue.global(qos: .userInteractive)
				let setup = DispatchGroup()
				let workers = DispatchGroup()

				queue.async(group: setup) {
					for _ in 0 ..< 1000 {
						let source = MutableProperty(1)
						var target = Optional(MutableProperty(1))

						target! <~ source

						// Ensure everything before this iteration has been
						// completed.
						queue.async(group: workers, flags: .barrier) {}

						queue.async(group: workers) {
							source.value = 2
						}

						queue.async(group: workers) {
							target = nil
						}
					}
				}

				waitUntil { done in
					setup.notify(queue: queue) {
						workers.notify(queue: .main, execute: done)
					}
				}
			}

			it("can be used as property wrapper") {
				struct Container {
					@MutableProperty var counter = 0
				}

				let container = Container()
				expect(container.counter) == 0

				container.counter += 1
				expect(container.counter) == 1

				container.$counter.modify { $0 += 2 }
				expect(container.counter) == 3
			}
		}

		describe("Property") {
			it("can be used as property wrapper") {
				struct Container {
					@Property var counter: Int
				}

				let mutableCounter = MutableProperty(0)
				let container = Container(counter: Property(capturing: mutableCounter))
				expect(container.counter) == 0

				mutableCounter.value = 1
				expect(container.counter) == 1

				mutableCounter.modify { $0 += 2 }
				expect(container.counter) == 3
			}

			describe("constant property") {
				it("should have the value given at initialization") {
					let constantProperty = Property(value: initialPropertyValue)

					expect(constantProperty.value) == initialPropertyValue
				}

				it("should yield a signal that interrupts observers without emitting any value.") {
					let constantProperty = Property(value: initialPropertyValue)

					var signalInterrupted = false
					var hasUnexpectedEventsEmitted = false

					constantProperty.signal.observe { event in
						switch event {
						case .interrupted:
							signalInterrupted = true
						case .value, .failed, .completed:
							hasUnexpectedEventsEmitted = true
						}
					}

					expect(signalInterrupted) == true
					expect(hasUnexpectedEventsEmitted) == false
				}

				it("should yield a producer that sends the current value then completes") {
					let constantProperty = Property(value: initialPropertyValue)

					var sentValue: String?
					var signalCompleted = false
					var hasUnexpectedEventsEmitted = false

					constantProperty.producer.start { event in
						switch event {
						case let .value(value):
							sentValue = value
						case .completed:
							signalCompleted = true
						case .failed, .interrupted:
							hasUnexpectedEventsEmitted = true
						}
					}

					expect(sentValue) == initialPropertyValue
					expect(signalCompleted) == true
					expect(hasUnexpectedEventsEmitted) == false
				}
			}

			describe("existential property") {
				describe("Property(capturing:)") {
					it("should pass through behaviors of the wrapped property") {
						let constantProperty = Property(value: initialPropertyValue)
						let property = Property(capturing: constantProperty)

						var sentValue: String?
						var producerCompleted = false
						var signalInterrupted = false
						var hasUnexpectedEventsEmitted = false

						property.producer.start { event in
							switch event {
							case let .value(value):
								sentValue = value
							case .completed:
								producerCompleted = true
							case .failed, .interrupted:
								hasUnexpectedEventsEmitted = true
							}
						}

						property.signal.observe { event in
							switch event {
							case .interrupted:
								signalInterrupted = true
							case .value, .failed, .completed:
								hasUnexpectedEventsEmitted = true
							}
						}

						expect(sentValue) == initialPropertyValue
						expect(producerCompleted) == true
						expect(signalInterrupted) == true
						expect(hasUnexpectedEventsEmitted) == false
					}

					it("should retain the wrapped property") {
						var property = Optional(MutableProperty(1))
						weak var weakProperty = property
						var existential = Optional(Property(capturing: property!))
						_ = existential

						expect(weakProperty).toNot(beNil())

						property = nil
						expect(weakProperty).toNot(beNil())

						existential = nil
						expect(weakProperty).to(beNil())
					}
				}
			}

			describe("composed properties") {
				describe("Property(_:)") {
					it("should pass through behaviors of the wrapped property") {
						let constantProperty = Property(value: initialPropertyValue)
						let property = Property(constantProperty)

						var sentValue: String?
						var producerCompleted = false
						var signalInterrupted = false
						var hasUnexpectedEventsEmitted = false

						property.producer.start { event in
							switch event {
							case let .value(value):
								sentValue = value
							case .completed:
								producerCompleted = true
							case .failed, .interrupted:
								hasUnexpectedEventsEmitted = true
							}
						}

						property.signal.observe { event in
							switch event {
							case .interrupted:
								signalInterrupted = true
							case .value, .failed, .completed:
								hasUnexpectedEventsEmitted = true
							}
						}

						expect(sentValue) == initialPropertyValue
						expect(producerCompleted) == true
						expect(signalInterrupted) == true
						expect(hasUnexpectedEventsEmitted) == false
					}

					it("should not retain the wrapped property, and remain accessible after its the property being reflected has deinitialized.") {
						var property = Optional(MutableProperty(initialPropertyValue))
						weak var weakProperty = property
						let reflected = Property(property!)

						expect(weakProperty).toNot(beNil())

						property!.value = subsequentPropertyValue
						expect(reflected.value) == subsequentPropertyValue

						property = nil
						expect(weakProperty).to(beNil())
						expect(reflected.value) == subsequentPropertyValue

						var hasUnexpectedEvents = false
						var completed = false
						var latestValue: String?

						reflected.producer.start { event in
							switch event {
							case let .value(value):
								latestValue = value

							case .completed:
								completed = true

							case .interrupted, .failed:
								hasUnexpectedEvents = true
							}
						}

						expect(latestValue) == subsequentPropertyValue
						expect(completed) == true
						expect(hasUnexpectedEvents) == false
					}
				}

				describe("from properties") {
					it("should have the latest value available before sending any value") {
						var latestValue: Int!

						let property = MutableProperty(1)
						let mappedProperty = property.map { $0 + 1 }
						mappedProperty.producer.startWithValues { _ in latestValue = mappedProperty.value }

						expect(latestValue) == 2

						property.value = 2
						expect(latestValue) == 3

						property.value = 3
						expect(latestValue) == 4
					}

					it("should not retain its source property") {
						var property = Optional(MutableProperty(1))
						weak var weakProperty = property

						let mapped = Optional(property!.map { $0 + 2 })

						// Suppress the "written to but never read" warning on `secondMappedProperty`.
						_ = mapped

						property = nil
						expect(weakProperty).to(beNil())
					}

					it("should transform property from a property that has a terminated producer") {
						let property = Property(value: 1)
						let transformedProperty = property.map { $0 + 1 }

						expect(transformedProperty.value) == 2
					}

					it("should return a producer and a signal which respect the lifetime of the source property instead of the read-only view itself") {
						var signalCompleted = 0
						var producerCompleted = 0

						var property = Optional(MutableProperty(1))
						var firstMappedProperty = Optional(property!.map { $0 + 1 })
						var secondMappedProperty = Optional(firstMappedProperty!.map { $0 + 2 })
						var thirdMappedProperty = Optional(secondMappedProperty!.map { $0 + 2 })

						firstMappedProperty!.signal.observeCompleted { signalCompleted += 1	}
						secondMappedProperty!.signal.observeCompleted { signalCompleted += 1 }
						thirdMappedProperty!.signal.observeCompleted { signalCompleted += 1	}

						firstMappedProperty!.producer.startWithCompleted { producerCompleted += 1 }
						secondMappedProperty!.producer.startWithCompleted { producerCompleted += 1 }
						thirdMappedProperty!.producer.startWithCompleted { producerCompleted += 1 }

						firstMappedProperty = nil

						withExtendedLifetime(secondMappedProperty) {
							expect(signalCompleted) == 0
							expect(producerCompleted) == 0
						}

						secondMappedProperty = nil

						withExtendedLifetime(property) {
							expect(signalCompleted) == 0
							expect(producerCompleted) == 0
						}

						property = nil

						withExtendedLifetime(thirdMappedProperty!) {
							expect(signalCompleted) == 3
							expect(producerCompleted) == 3
						}

						thirdMappedProperty = nil
						expect(signalCompleted) == 3
						expect(producerCompleted) == 3
					}

					it("should capture no properties") {
						func increment(input: Int) -> Int {
							return input + 1
						}

						weak var weakSourceProperty: MutableProperty<Int>?
						weak var weakPropertyA: Property<Int>?
						weak var weakPropertyB: Property<Int>?
						weak var weakPropertyC: Property<Int>?

						var finalProperty: Property<Int>!

						func scope() {
							let property = MutableProperty(1)
							weakSourceProperty = property

							let propertyA = property.map(increment)
							weakPropertyA = propertyA

							let propertyB = propertyA.map(increment)
							weakPropertyB = propertyB

							let propertyC = propertyB.map(increment)
							weakPropertyC = propertyC

							finalProperty = propertyC.map(increment)
						}

						scope()

						expect(finalProperty.value) == 5
						expect(weakSourceProperty).to(beNil())
						expect(weakPropertyA).to(beNil())
						expect(weakPropertyB).to(beNil())
						expect(weakPropertyC).to(beNil())
					}
				}

				describe("from a value and SignalProducer") {
					it("should initially take on the supplied value") {
						let property = Property(initial: initialPropertyValue,
						                        then: SignalProducer.never)

						expect(property.value) == initialPropertyValue
					}

					it("should take on each value sent on the producer") {
						let property = Property(initial: initialPropertyValue,
						                        then: SignalProducer(value: subsequentPropertyValue))

						expect(property.value) == subsequentPropertyValue
					}

					it("should complete its producer and signal even if the upstream interrupts") {
						let (signal, observer) = Signal<String, Never>.pipe()

						let property = Property(initial: initialPropertyValue, then: SignalProducer(signal))

						var isProducerCompleted = false
						var isSignalCompleted = false

						property.producer.startWithCompleted { isProducerCompleted = true }
						property.signal.observeCompleted { isSignalCompleted = true }
						expect(isProducerCompleted) == false
						expect(isSignalCompleted) == false

						observer.sendInterrupted()
						expect(isProducerCompleted) == true
						expect(isSignalCompleted) == true
					}

					it("should return a producer and a signal that respect the lifetime of its ultimate source") {
						var signalCompleted = false
						var producerCompleted = false
						var signalInterrupted = false

						let (signal, observer) = Signal<Int, Never>.pipe()
						var property: Property<Int>? = Property(initial: 1, then: SignalProducer(signal))
						let propertySignal = property!.signal

						propertySignal.observeCompleted { signalCompleted = true }
						property!.producer.startWithCompleted { producerCompleted = true }

						expect(property!.value) == 1

						observer.send(value: 2)
						expect(property!.value) == 2
						expect(producerCompleted) == false
						expect(signalCompleted) == false

						property = nil
						expect(producerCompleted) == false
						expect(signalCompleted) == false

						observer.sendCompleted()
						expect(producerCompleted) == true
						expect(signalCompleted) == true

						propertySignal.observeInterrupted { signalInterrupted = true }
						expect(signalInterrupted) == true
					}

					it("should be able to fallback to SignalProducer for contextual lookups") {
						_ = Property(initial: 0, then: .init(value: 0))
					}

					it("should be able to fallback to SignalProducer for contextual lookups when an optional value type parameter is involved") {
						_ = Property(initial: Optional(0), then: .init(value: 0))
					}
				}

				describe("from a value and Signal") {
					it("should initially take on the supplied value, then values sent on the signal") {
						let (signal, observer) = Signal<String, Never>.pipe()

						let property = Property(initial: initialPropertyValue, then: signal)

						expect(property.value) == initialPropertyValue

						observer.send(value: subsequentPropertyValue)

						expect(property.value) == subsequentPropertyValue
					}

					it("should complete its producer and signal even if the upstream interrupts") {
						let (signal, observer) = Signal<String, Never>.pipe()

						let property = Property(initial: initialPropertyValue, then: signal)

						var isProducerCompleted = false
						var isSignalCompleted = false

						property.producer.startWithCompleted { isProducerCompleted = true }
						property.signal.observeCompleted { isSignalCompleted = true }
						expect(isProducerCompleted) == false
						expect(isSignalCompleted) == false

						observer.sendInterrupted()
						expect(isProducerCompleted) == true
						expect(isSignalCompleted) == true
					}

					it("should return a producer and a signal that respect the lifetime of its ultimate source") {
						var signalCompleted = false
						var producerCompleted = false
						var signalInterrupted = false

						let (signal, observer) = Signal<Int, Never>.pipe()
						var property: Property<Int>? = Property(initial: 1, then: signal)
						let propertySignal = property!.signal

						propertySignal.observeCompleted { signalCompleted = true }
						property!.producer.startWithCompleted { producerCompleted = true }

						expect(property!.value) == 1

						observer.send(value: 2)
						expect(property!.value) == 2
						expect(producerCompleted) == false
						expect(signalCompleted) == false

						property = nil
						expect(producerCompleted) == false
						expect(signalCompleted) == false

						observer.sendCompleted()
						expect(producerCompleted) == true
						expect(signalCompleted) == true

						propertySignal.observeInterrupted { signalInterrupted = true }
						expect(signalInterrupted) == true
					}
				}
			}
		}

		describe("PropertyProtocol") {
			describe("map") {
				it("should transform the current value and all subsequent values") {
					let property = MutableProperty(1)
					let mappedProperty = property.map { $0 + 1 }
					expect(mappedProperty.value) == 2

					property.value = 2
					expect(mappedProperty.value) == 3
				}
				
				it("should transform the current value and all subsequent values to a constant value") {
					let property = MutableProperty("foo")
					let mappedProperty = property.map(value: 1)
					expect(mappedProperty.value) == 1
					
					property.value = "foobar"
					expect(mappedProperty.value) == 1
				}

				it("should work with key paths") {
					let property = MutableProperty("foo")
					let mappedProperty = property.map(\.count)
					expect(mappedProperty.value) == 3

					property.value = "foobar"
					expect(mappedProperty.value) == 6
				}
			}

			describe("filter") {
				it("should only receive values that pass the predicate")  {
					let property = MutableProperty(1)
					let filteredProperty = property
						.filter(initial: 0) { $0 > 0 }
					expect(filteredProperty.value) == 1

					property.value = 0
					expect(filteredProperty.value) == 1

					property.value = 2
					expect(filteredProperty.value) == 2

					property.value = -5
					expect(filteredProperty.value) == 2

					property.value = 3
					expect(filteredProperty.value) == 3
				}

				it("should behave correctly if the filter excludes the initial value")  {
					let property = MutableProperty(1)
					let filteredProperty = property
						.filter(initial: 0) { $0 < 0 }
					expect(filteredProperty.value) == 0

					property.value = 2
					expect(filteredProperty.value) == 0

					property.value = -2
					expect(filteredProperty.value) == -2

					property.value = 0
					expect(filteredProperty.value) == -2
				}
			}

			describe("combineLatest") {
				var property: MutableProperty<String>!
				var otherProperty: MutableProperty<String>!

				beforeEach {
					property = MutableProperty(initialPropertyValue)
					otherProperty = MutableProperty(initialOtherPropertyValue)
				}

				it("should emit the empty sentinel when no property is given") {
					let property = Property<String>.combineLatest(
						EmptyCollection<Property<String>>(),
						emptySentinel: ["empty"]
					)

					expect(property).toNot(beNil())
					expect(property.value) == ["empty"]
				}

				it("should forward the latest values from both inputs") {
					let combinedProperty = property.combineLatest(with: otherProperty)
					var latest: (String, String)?
					combinedProperty.signal.observeValues { latest = $0 }

					property.value = subsequentPropertyValue
					expect(latest?.0) == subsequentPropertyValue
					expect(latest?.1) == initialOtherPropertyValue

					// is there a better way to test tuples?
					otherProperty.value = subsequentOtherPropertyValue
					expect(latest?.0) == subsequentPropertyValue
					expect(latest?.1) == subsequentOtherPropertyValue

					property.value = finalPropertyValue
					expect(latest?.0) == finalPropertyValue
					expect(latest?.1) == subsequentOtherPropertyValue
				}

				it("should complete when the source properties are deinitialized") {
					var completed = false

					var combinedProperty = Optional(property.combineLatest(with: otherProperty))
					combinedProperty!.signal.observeCompleted { completed = true }

					combinedProperty = nil
					expect(completed) == false

					property = nil
					expect(completed) == false

					otherProperty = nil
					expect(completed) == true
				}

				it("should be consistent between its cached value and its values producer") {
					var firstResult: String!
					var secondResult: String!

					let combined = property.combineLatest(with: otherProperty)
					combined.producer.startWithValues { firstResult = $0.0 + $0.1 }

					func getValue() -> String {
						return combined.value.0 + combined.value.1
					}

					expect(getValue()) == initialPropertyValue + initialOtherPropertyValue
					expect(firstResult) == initialPropertyValue + initialOtherPropertyValue

					property.value = subsequentPropertyValue
					expect(getValue()) == subsequentPropertyValue + initialOtherPropertyValue
					expect(firstResult) == subsequentPropertyValue + initialOtherPropertyValue

					combined.producer.startWithValues { secondResult = $0.0 + $0.1 }
					expect(secondResult) == subsequentPropertyValue + initialOtherPropertyValue

					otherProperty.value = subsequentOtherPropertyValue
					expect(getValue()) == subsequentPropertyValue + subsequentOtherPropertyValue
					expect(firstResult) == subsequentPropertyValue + subsequentOtherPropertyValue
					expect(secondResult) == subsequentPropertyValue + subsequentOtherPropertyValue
				}

				it("should be consistent between nested combined properties") {
					let A = MutableProperty(1)
					let B = MutableProperty(100)
					let C = MutableProperty(10000)

					var firstResult: Int!

					let combined = A.combineLatest(with: B)
					combined.producer.startWithValues { firstResult = $0.0 + $0.1 }

					func getValue() -> Int {
						return combined.value.0 + combined.value.1
					}

					/// Initial states
					expect(getValue()) == 101
					expect(firstResult) == 101

					A.value = 2
					expect(getValue()) == 102
					expect(firstResult) == 102

					B.value = 200
					expect(getValue()) == 202
					expect(firstResult) == 202

					/// Setup
					A.value = 3
					expect(getValue()) == 203
					expect(firstResult) == 203

					/// Zip another property now.
					var secondResult: Int!
					let anotherCombined = combined.combineLatest(with: C)
					anotherCombined.producer.startWithValues { secondResult = ($0.0.0 + $0.0.1) + $0.1 }

					func getAnotherValue() -> Int {
						return (anotherCombined.value.0.0 + anotherCombined.value.0.1) + anotherCombined.value.1
					}

					expect(getAnotherValue()) == 10203
					expect(secondResult) == 10203

					A.value = 4
					expect(getValue()) == 204
					expect(getAnotherValue()) == 10204
					expect(secondResult) == 10204
				}
			}

			describe("zip") {
				var property: MutableProperty<String>!
				var otherProperty: MutableProperty<String>!

				beforeEach {
					property = MutableProperty(initialPropertyValue)
					otherProperty = MutableProperty(initialOtherPropertyValue)
				}

				it("should emit the empty sentinel when no property is given") {
					let property = Property<String>.zip(
						EmptyCollection<Property<String>>(),
						emptySentinel: ["empty"]
					)

					expect(property).toNot(beNil())
					expect(property.value) == ["empty"]
				}

				it("should combine pairs") {
					var result: [String] = []

					let zippedProperty = property.zip(with: otherProperty)
					zippedProperty.producer.startWithValues { result.append("\($0.0)\($0.1)") }

					let firstResult = [ "\(initialPropertyValue)\(initialOtherPropertyValue)" ]
					let secondResult = firstResult + [ "\(subsequentPropertyValue)\(subsequentOtherPropertyValue)" ]
					let thirdResult = secondResult + [ "\(finalPropertyValue)\(finalOtherPropertyValue)" ]
					let finalResult = thirdResult + [ "\(initialPropertyValue)\(initialOtherPropertyValue)" ]

					expect(result) == firstResult

					property.value = subsequentPropertyValue
					expect(result) == firstResult

					otherProperty.value = subsequentOtherPropertyValue
					expect(result) == secondResult

					property.value = finalPropertyValue
					otherProperty.value = finalOtherPropertyValue
					expect(result) == thirdResult

					property.value = initialPropertyValue
					expect(result) == thirdResult

					property.value = subsequentPropertyValue
					expect(result) == thirdResult

					otherProperty.value = initialOtherPropertyValue
					expect(result) == finalResult
				}

				it("should be consistent between its cached value and its values producer") {
					var firstResult: String!
					var secondResult: String!

					let zippedProperty = property.zip(with: otherProperty)
					zippedProperty.producer.startWithValues { firstResult = $0.0 + $0.1 }

					func getValue() -> String {
						return zippedProperty.value.0 + zippedProperty.value.1
					}

					expect(getValue()) == initialPropertyValue + initialOtherPropertyValue
					expect(firstResult) == initialPropertyValue + initialOtherPropertyValue

					property.value = subsequentPropertyValue
					expect(getValue()) == initialPropertyValue + initialOtherPropertyValue
					expect(firstResult) == initialPropertyValue + initialOtherPropertyValue

					// It should still be the tuple with initial property values,
					// since `otherProperty` isn't changed yet.
					zippedProperty.producer.startWithValues { secondResult = $0.0 + $0.1 }
					expect(secondResult) == initialPropertyValue + initialOtherPropertyValue

					otherProperty.value = subsequentOtherPropertyValue
					expect(getValue()) == subsequentPropertyValue + subsequentOtherPropertyValue
					expect(firstResult) == subsequentPropertyValue + subsequentOtherPropertyValue
					expect(secondResult) == subsequentPropertyValue + subsequentOtherPropertyValue
				}

				it("should be consistent between nested zipped properties") {
					let A = MutableProperty(1)
					let B = MutableProperty(100)
					let C = MutableProperty(10000)

					var firstResult: Int!

					let zipped = A.zip(with: B)
					zipped.producer.startWithValues { firstResult = $0.0 + $0.1 }

					func getValue() -> Int {
						return zipped.value.0 + zipped.value.1
					}

					/// Initial states
					expect(getValue()) == 101
					expect(firstResult) == 101

					A.value = 2
					expect(getValue()) == 101
					expect(firstResult) == 101

					B.value = 200
					expect(getValue()) == 202
					expect(firstResult) == 202

					/// Setup
					A.value = 3
					expect(getValue()) == 202
					expect(firstResult) == 202

					/// Zip another property now.
					var secondResult: Int!
					let anotherZipped = zipped.zip(with: C)
					anotherZipped.producer.startWithValues { secondResult = ($0.0.0 + $0.0.1) + $0.1 }

					func getAnotherValue() -> Int {
						return (anotherZipped.value.0.0 + anotherZipped.value.0.1) + anotherZipped.value.1
					}

					/// Since `zipped` is 202 now, and `C` is 10000,
					/// shouldn't this be 10202?

					/// Verify `zipped` again.
					expect(getValue()) == 202
					expect(firstResult) == 202

					/// Then... well, no. Surprise! (Only before #3042)
					/// We get 10203 here.
					///
					/// https://github.com/ReactiveCocoa/ReactiveCocoa/pull/3042
					expect(getAnotherValue()) == 10202
					expect(secondResult) == 10202
				}

				it("should be consistent between combined and nested zipped properties") {
					let A = MutableProperty(1)
					let B = MutableProperty(100)
					let C = MutableProperty(10000)
					let D = MutableProperty(1000000)

					var firstResult: Int!

					let zipped = A.zip(with: B)
					zipped.producer.startWithValues { firstResult = $0.0 + $0.1 }

					func getValue() -> Int {
						return zipped.value.0 + zipped.value.1
					}

					/// Initial states
					expect(getValue()) == 101
					expect(firstResult) == 101

					A.value = 2
					expect(getValue()) == 101
					expect(firstResult) == 101

					B.value = 200
					expect(getValue()) == 202
					expect(firstResult) == 202

					/// Setup
					A.value = 3
					expect(getValue()) == 202
					expect(firstResult) == 202

					/// Zip another property now.
					var secondResult: Int!
					let anotherZipped = zipped.zip(with: C)
					anotherZipped.producer.startWithValues { secondResult = ($0.0.0 + $0.0.1) + $0.1 }

					func getAnotherValue() -> Int {
						return (anotherZipped.value.0.0 + anotherZipped.value.0.1) + anotherZipped.value.1
					}

					/// Verify `zipped` again.
					expect(getValue()) == 202
					expect(firstResult) == 202

					expect(getAnotherValue()) == 10202
					expect(secondResult) == 10202

					/// Zip `D` with `anotherZipped`.
					let yetAnotherZipped = anotherZipped.zip(with: D)

					/// Combine with another property.
					/// (((Int, Int), Int), (((Int, Int), Int), Int))
					let combined = anotherZipped.combineLatest(with: yetAnotherZipped)

					var thirdResult: Int!
					combined.producer.startWithValues {
						let leftResult = $0.0.0.0 + $0.0.0.1 + $0.0.1
						let rightResult = $0.1.0.0.0 + $0.1.0.0.1 + $0.1.0.1 + $0.1.1
						thirdResult = leftResult + rightResult
					}

					expect(thirdResult) == 1020404
				}

				it("should complete its producer only when the source properties are deinitialized") {
					var result: [String] = []
					var completed = false

					var zippedProperty = Optional(property.zip(with: otherProperty))
					zippedProperty!.producer.start { event in
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
					expect(result) == [ "\(initialPropertyValue)\(initialOtherPropertyValue)" ]

					property.value = subsequentPropertyValue
					expect(result) == [ "\(initialPropertyValue)\(initialOtherPropertyValue)" ]

					zippedProperty = nil
					expect(completed) == false

					property = nil
					otherProperty = nil
					expect(completed) == true
				}
			}

			describe("unary operators") {
				var property: MutableProperty<String>!

				beforeEach {
					property = MutableProperty(initialPropertyValue)
				}

				describe("combinePrevious") {
					it("should pack the current value and the previous value a tuple") {
						let transformedProperty = property.combinePrevious(initialPropertyValue)

						expect(transformedProperty.value.0) == initialPropertyValue
						expect(transformedProperty.value.1) == initialPropertyValue

						property.value = subsequentPropertyValue

						expect(transformedProperty.value.0) == initialPropertyValue
						expect(transformedProperty.value.1) == subsequentPropertyValue

						property.value = finalPropertyValue

						expect(transformedProperty.value.0) == subsequentPropertyValue
						expect(transformedProperty.value.1) == finalPropertyValue
					}

					it("should complete its producer only when the source property is deinitialized") {
						var result: (String, String)?
						var completed = false

						var transformedProperty = Optional(property.combinePrevious(initialPropertyValue))
						transformedProperty!.producer.start { event in
							switch event {
							case let .value(tuple):
								result = tuple
							case .completed:
								completed = true
							default:
								break
							}
						}

						expect(result?.0) == initialPropertyValue
						expect(result?.1) == initialPropertyValue

						property.value = subsequentPropertyValue

						expect(result?.0) == initialPropertyValue
						expect(result?.1) == subsequentPropertyValue

						transformedProperty = nil
						expect(completed) == false

						property = nil
						expect(completed) == true
					}
				}

				describe("skipRepeats") {
					it("should not emit events for subsequent equatable values that are the same as the current value") {
						let transformedProperty = property.skipRepeats()

						var counter = 0
						transformedProperty.signal.observeValues { _ in
							counter += 1
						}

						property.value = initialPropertyValue
						property.value = initialPropertyValue
						property.value = initialPropertyValue

						expect(counter) == 0

						property.value = subsequentPropertyValue
						property.value = subsequentPropertyValue
						property.value = subsequentPropertyValue

						expect(counter) == 1

						property.value = finalPropertyValue
						property.value = initialPropertyValue
						property.value = subsequentPropertyValue

						expect(counter) == 4
					}

					it("should not emit events for subsequent values that are regarded as the same as the current value by the supplied closure") {
						var counter = 0
						let transformedProperty = property.skipRepeats { _, newValue in newValue == initialPropertyValue }

						transformedProperty.signal.observeValues { _ in
							counter += 1
						}

						property.value = initialPropertyValue
						expect(counter) == 0

						property.value = subsequentPropertyValue
						expect(counter) == 1

						property.value = finalPropertyValue
						expect(counter) == 2

						property.value = initialPropertyValue
						expect(counter) == 2
					}

					it("should complete its producer only when the source property is deinitialized") {
						var counter = 0
						var completed = false

						var transformedProperty = Optional(property.skipRepeats())
						transformedProperty!.producer.start { event in
							switch event {
							case .value:
								counter += 1
							case .completed:
								completed = true
							default:
								break
							}
						}

						expect(counter) == 1

						property.value = initialPropertyValue
						expect(counter) == 1

						transformedProperty = nil
						expect(completed) == false

						property = nil
						expect(completed) == true
					}
				}

				describe("uniqueValues") {
					it("should emit hashable values that have not been emited before") {
						let transformedProperty = property.uniqueValues()

						var counter = 0
						transformedProperty.signal.observeValues { _ in
							counter += 1
						}

						property.value = initialPropertyValue
						expect(counter) == 0

						property.value = subsequentPropertyValue
						property.value = subsequentPropertyValue

						expect(counter) == 1

						property.value = finalPropertyValue
						property.value = initialPropertyValue
						property.value = subsequentPropertyValue

						expect(counter) == 2
					}

					it("should emit only the values of which the computed identity have not been captured before") {
						let transformedProperty = property.uniqueValues { _ in 0 }

						var counter = 0
						transformedProperty.signal.observeValues { _ in
							counter += 1
						}

						property.value = initialPropertyValue
						property.value = subsequentPropertyValue
						property.value = finalPropertyValue
						expect(counter) == 0
					}

					it("should complete its producer only when the source property is deinitialized") {
						var counter = 0
						var completed = false

						var transformedProperty = Optional(property.uniqueValues())
						transformedProperty!.producer.start { event in
							switch event {
							case .value:
								counter += 1
							case .completed:
								completed = true
							default:
								break
							}
						}

						expect(counter) == 1

						property.value = initialPropertyValue
						expect(counter) == 1

						transformedProperty = nil
						expect(completed) == false

						property = nil
						expect(completed) == true
					}
				}
			}

			describe("flattening") {
				describe("flatten") {
					describe("FlattenStrategy.concat") {
						it("should concatenate the values as the inner property is replaced and deinitialized") {
							var firstProperty = Optional(MutableProperty(0))
							var secondProperty = Optional(MutableProperty(10))
							var thirdProperty = Optional(MutableProperty(20))

							var outerProperty = Optional(MutableProperty(firstProperty!))

							var receivedValues: [Int] = []
							var errored = false
							var completed = false

							let flattenedProperty = outerProperty!.flatten(.concat)

							flattenedProperty.producer.start { event in
								switch event {
								case let .value(value):
									receivedValues.append(value)
								case .completed:
									completed = true
								case .failed:
									errored = true
								case .interrupted:
									break
								}
							}

							expect(receivedValues) == [ 0 ]

							outerProperty!.value = secondProperty!
							secondProperty!.value = 11
							outerProperty!.value = thirdProperty!
							thirdProperty!.value = 21

							withExtendedLifetime(firstProperty) {
								expect(receivedValues) == [ 0 ]
								expect(completed) == false

								secondProperty!.value = 12
								thirdProperty!.value = 22

								expect(receivedValues) == [ 0 ]
								expect(completed) == false
							}

							firstProperty = nil

							withExtendedLifetime(secondProperty) {
								expect(receivedValues) == [ 0, 12 ]
								expect(completed) == false
							}

							secondProperty = nil

							withExtendedLifetime(outerProperty) {
								expect(receivedValues) == [ 0, 12, 22 ]
								expect(completed) == false
							}

							outerProperty = nil

							withExtendedLifetime(thirdProperty) {
								expect(completed) == false
							}

							thirdProperty = nil

							expect(completed) == true
							expect(errored) == false
						}
					}

					describe("FlattenStrategy.merge") {
						it("should merge the values of all inner properties") {
							var firstProperty = Optional(MutableProperty(0))
							var secondProperty = Optional(MutableProperty(10))
							var thirdProperty = Optional(MutableProperty(20))

							var outerProperty = Optional(MutableProperty(firstProperty!))

							var receivedValues: [Int] = []
							var errored = false
							var completed = false

							let flattenedProperty = outerProperty!.flatten(.merge)

							flattenedProperty.producer.start { event in
								switch event {
								case let .value(value):
									receivedValues.append(value)
								case .completed:
									completed = true
								case .failed:
									errored = true
								case .interrupted:
									break
								}
							}

							expect(receivedValues) == [ 0 ]

							outerProperty!.value = secondProperty!
							secondProperty!.value = 11
							outerProperty!.value = thirdProperty!
							thirdProperty!.value = 21

							expect(receivedValues) == [ 0, 10, 11, 20, 21 ]
							expect(completed) == false

							secondProperty!.value = 12
							thirdProperty!.value = 22

							withExtendedLifetime(firstProperty) {
								expect(receivedValues) == [ 0, 10, 11, 20, 21, 12, 22 ]
								expect(completed) == false
							}

							firstProperty = nil

							withExtendedLifetime(secondProperty) {
								expect(receivedValues) == [ 0, 10, 11, 20, 21, 12, 22 ]
								expect(completed) == false
							}

							secondProperty = nil

							withExtendedLifetime(outerProperty) {
								expect(receivedValues) == [ 0, 10, 11, 20, 21, 12, 22 ]
								expect(completed) == false
							}

							outerProperty = nil

							withExtendedLifetime(thirdProperty) {
								expect(completed) == false
							}

							thirdProperty = nil
							expect(completed) == true
							expect(errored) == false
						}
					}

					describe("FlattenStrategy.latest") {
						it("should forward values from the latest inner property") {
							let firstProperty = Optional(MutableProperty(0))
							var secondProperty = Optional(MutableProperty(10))
							var thirdProperty = Optional(MutableProperty(20))

							var outerProperty = Optional(MutableProperty(firstProperty!))

							var receivedValues: [Int] = []
							var errored = false
							var completed = false

							outerProperty!.flatten(.latest).producer.start { event in
								switch event {
								case let .value(value):
									receivedValues.append(value)
								case .completed:
									completed = true
								case .failed:
									errored = true
								case .interrupted:
									break
								}
							}

							expect(receivedValues) == [ 0 ]

							outerProperty!.value = secondProperty!
							secondProperty!.value = 11
							outerProperty!.value = thirdProperty!
							thirdProperty!.value = 21

							expect(receivedValues) == [ 0, 10, 11, 20, 21 ]
							expect(errored) == false
							expect(completed) == false

							secondProperty!.value = 12
							secondProperty = nil
							thirdProperty!.value = 22
							thirdProperty = nil

							withExtendedLifetime(outerProperty) {
								expect(receivedValues) == [ 0, 10, 11, 20, 21, 22 ]
								expect(errored) == false
								expect(completed) == false
							}

							outerProperty = nil
							expect(errored) == false
							expect(completed) == true
						}

						it("should release the old properties when switched or deallocated") {
							var firstProperty = Optional(MutableProperty(0))
							var secondProperty = Optional(MutableProperty(10))
							var thirdProperty = Optional(MutableProperty(20))

							weak var weakFirstProperty = firstProperty
							weak var weakSecondProperty = secondProperty
							weak var weakThirdProperty = thirdProperty

							var outerProperty = Optional(MutableProperty(firstProperty!))
							var flattened = Optional(outerProperty!.flatten(.latest))

							var errored = false
							var completed = false

							flattened!.producer.start { event in
								switch event {
								case .completed:
									completed = true
								case .failed:
									errored = true
								case .interrupted, .value:
									break
								}
							}

							firstProperty = nil
							outerProperty!.value = secondProperty!
							expect(weakFirstProperty).to(beNil())

							secondProperty = nil
							outerProperty!.value = thirdProperty!
							expect(weakSecondProperty).to(beNil())

							thirdProperty = nil
							outerProperty = nil
							flattened = nil
							expect(weakThirdProperty).to(beNil())
							expect(errored) == false
							expect(completed) == true
						}
					}
				}

				describe("flatMap") {
					describe("PropertyFlattenStrategy.latest") {
						it("should forward values from the latest inner transformed property") {
							let firstProperty = Optional(MutableProperty(0))
							var secondProperty = Optional(MutableProperty(10))
							var thirdProperty = Optional(MutableProperty(20))

							var outerProperty = Optional(MutableProperty(firstProperty!))

							var receivedValues: [String] = []
							var errored = false
							var completed = false

							outerProperty!.flatMap(.latest) { $0.map { "\($0)" } }.producer.start { event in
								switch event {
								case let .value(value):
									receivedValues.append(value)
								case .completed:
									completed = true
								case .failed:
									errored = true
								case .interrupted:
									break
								}
							}

							expect(receivedValues) == [ "0" ]

							outerProperty!.value = secondProperty!
							secondProperty!.value = 11
							outerProperty!.value = thirdProperty!
							thirdProperty!.value = 21

							expect(receivedValues) == [ "0", "10", "11", "20", "21" ]
							expect(errored) == false
							expect(completed) == false

							secondProperty!.value = 12
							secondProperty = nil
							thirdProperty!.value = 22
							thirdProperty = nil

							withExtendedLifetime(outerProperty) {
								expect(receivedValues) == [ "0", "10", "11", "20", "21", "22" ]
								expect(errored) == false
								expect(completed) == false
							}

							outerProperty = nil
							expect(errored) == false
							expect(completed) == true
						}
					}
				}
			}

			describe("negated attribute") {
				it("should return the negate of a value in a Boolean property") {
					let property = MutableProperty(true)
					expect(property.negate().value).to(beFalse())
				}
			}

			describe("and attribute") {
				it("should emit true when both properties contains the same value") {
					let property1 = MutableProperty(true)
					let property2 = MutableProperty(true)
					expect(property1.and(property2).value).to(beTrue())
				}

				it("should emit false when both properties contains opposite values") {
					let property1 = MutableProperty(true)
					let property2 = MutableProperty(false)
					expect(property1.and(property2).value).to(beFalse())
				}
			}

			describe("all attribute") {
				it("should return a property with constant true when no producer is given") {
					let property = Property<Bool>.all(
						EmptyCollection<Property<Bool>>()
					)

					expect(property).toNot(beNil())
					expect(property.value) == true
				}

				it("should emit true when all properties contain the same value") {
					let property1 = MutableProperty(true)
					let property2 = MutableProperty(true)
					let property3 = MutableProperty(true)
					expect(Property.all([property1, property2, property3]).value).to(beTrue())
				}

				it("should emit false when all properties contain opposite values") {
					let property1 = MutableProperty(false)
					let property2 = MutableProperty(true)
					let property3 = MutableProperty(true)
					expect(Property.all([property1, property2, property3]).value).to(beFalse())
				}

				it("should emit true when array of properties is empty") {
					expect(Property.all([Property<Bool>]()).value).to(beTrue())
				}
			}

			describe("or attribute") {
				it("should emit true when at least one of the properties contains true") {
					let property1 = MutableProperty(true)
					let property2 = MutableProperty(false)
					expect(property1.or(property2).value).to(beTrue())
				}

				it("should emit false when both properties contains false") {
					let property1 = MutableProperty(false)
					let property2 = MutableProperty(false)
					expect(property1.or(property2).value).to(beFalse())
				}
			}

			describe("any attribute") {
				it("should return a property with constant false when no producer is given") {
					let property = Property<Bool>.any(
						EmptyCollection<Property<Bool>>()
					)

					expect(property).toNot(beNil())
					expect(property.value) == false
				}

				it("should emit true when at least one of the properties in array contains true") {
					let property1 = MutableProperty(true)
					let property2 = MutableProperty(false)
					let property3 = MutableProperty(false)
					expect(Property.any([property1, property2, property3]).value).to(beTrue())
				}

				it("should emit false when all properties contain false") {
					let property1 = MutableProperty(false)
					let property2 = MutableProperty(false)
					let property3 = MutableProperty(false)
					expect(Property.any(property1, property2, property3).value).to(beFalse())
				}

				it("should emit false when array of properties is empty") {
					expect(Property.any([Property<Bool>]()).value).to(beFalse())
				}
			}
		}

		describe("binding") {
			describe("from a Signal") {
				it("should update the property with values sent from the signal") {
					let (signal, observer) = Signal<String, Never>.pipe()

					let mutableProperty = MutableProperty(initialPropertyValue)

					mutableProperty <~ signal

					// Verify that the binding hasn't changed the property value:
					expect(mutableProperty.value) == initialPropertyValue

					observer.send(value: subsequentPropertyValue)
					expect(mutableProperty.value) == subsequentPropertyValue
				}

				it("should tear down the binding when disposed") {
					let (signal, observer) = Signal<String, Never>.pipe()

					let mutableProperty = MutableProperty(initialPropertyValue)

					let bindingDisposable = mutableProperty <~ signal
					bindingDisposable!.dispose()

					observer.send(value: subsequentPropertyValue)
					expect(mutableProperty.value) == initialPropertyValue
				}

				it("should tear down the binding when the property deallocates") {
					var isDisposed = false

					var outerObserver: Signal<String, Never>.Observer!

					var signal: Signal<String, Never>? = {
						let (signal, observer) = Signal<String, Never>.pipe()
						outerObserver = observer
						return signal.on(disposed: { isDisposed = true })
					}()
					weak var weakSignal = signal

					var mutableProperty: MutableProperty<String>? = MutableProperty(initialPropertyValue)

					withExtendedLifetime((mutableProperty!, signal!)) { property, signal -> Void in
						property <~ signal
					}

					signal = nil

					withExtendedLifetime((mutableProperty!, outerObserver!)) {
						// The binding attached an observer to the signal, so it cannot
						// be disposed of.
						expect(weakSignal).to(beNil())
						expect(isDisposed) == false
					}

					// The deinitialization should tear down the binding, which would
					// remove the last observer from the signal, causing it to
					// dispose of itself.
					mutableProperty = nil
					expect(weakSignal).to(beNil())
					expect(isDisposed) == true
				}
			}

			describe("from a SignalProducer") {
				it("should start a signal and update the property with its values") {
					let signalValues = [initialPropertyValue, subsequentPropertyValue]
					let signalProducer = SignalProducer<String, Never>(signalValues)

					let mutableProperty = MutableProperty(initialPropertyValue)

					mutableProperty <~ signalProducer

					expect(mutableProperty.value) == signalValues.last!
				}

				it("should tear down the binding when disposed") {
					let (signalProducer, observer) = SignalProducer<String, Never>.pipe()

					let mutableProperty = MutableProperty(initialPropertyValue)
					let disposable = mutableProperty <~ signalProducer

					disposable?.dispose()

					observer.send(value: subsequentPropertyValue)
					expect(mutableProperty.value) == initialPropertyValue
				}

				it("should tear down the binding when the property deallocates") {
					let (signal, observer) = Signal<String, Never>.pipe()
					let signalProducer = SignalProducer(signal)

					var mutableProperty: MutableProperty<String>? = MutableProperty(initialPropertyValue)

					withExtendedLifetime(observer) {
						var isDisposed = false
						mutableProperty! <~ signalProducer.on(disposed: { isDisposed = true })
						expect(isDisposed) == false

						mutableProperty = nil
						expect(isDisposed) == true
					}
				}
			}

			describe("from another property") {
				it("should take the source property's current value") {
					let sourceProperty = Property(value: initialPropertyValue)

					let destinationProperty = MutableProperty("")

					destinationProperty <~ sourceProperty.producer

					expect(destinationProperty.value) == initialPropertyValue
				}

				it("should update with changes to the source property's value") {
					let sourceProperty = MutableProperty(initialPropertyValue)

					let destinationProperty = MutableProperty("")

					destinationProperty <~ sourceProperty.producer

					sourceProperty.value = subsequentPropertyValue
					expect(destinationProperty.value) == subsequentPropertyValue
				}

				it("should tear down the binding when disposed") {
					let sourceProperty = MutableProperty(initialPropertyValue)

					let destinationProperty = MutableProperty("")

					let bindingDisposable = destinationProperty <~ sourceProperty.producer
					bindingDisposable?.dispose()

					sourceProperty.value = subsequentPropertyValue

					expect(destinationProperty.value) == initialPropertyValue
				}

				it("should tear down the binding when the source property deallocates") {
					var sourceProperty: MutableProperty<String>? = MutableProperty(initialPropertyValue)

					let destinationProperty = MutableProperty("")
					destinationProperty <~ sourceProperty!.producer

					sourceProperty = nil
					// TODO: Assert binding was torn down?
				}

				it("should tear down the binding when the destination property deallocates") {
					let sourceProperty = MutableProperty(initialPropertyValue)
					var destinationProperty: MutableProperty<String>? = MutableProperty("")

					var isDisposed = false

					_ = withExtendedLifetime(destinationProperty) {
						$0! <~ sourceProperty.producer.on(disposed: { isDisposed = true })
					}

					expect(isDisposed) == false

					destinationProperty = nil
					expect(isDisposed) == true
				}
			}
		}
	}
}
