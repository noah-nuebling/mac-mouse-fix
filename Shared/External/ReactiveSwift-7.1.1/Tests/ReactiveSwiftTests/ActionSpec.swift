//
//  ActionSpec.swift
//  ReactiveSwift
//
//  Created by Justin Spahr-Summers on 2014-12-11.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
import Dispatch
import Nimble
import Quick
@testable import ReactiveSwift

class ActionSpec: QuickSpec {
	override func spec() {
		describe("Action") {
			var action: Action<Int, String, NSError>!
			var enabled: MutableProperty<Bool>!

			var executionCount = 0
			var completedCount = 0
			var values: [String] = []
			var errors: [NSError] = []

			var scheduler: TestScheduler!
			let testError = NSError(domain: "ActionSpec", code: 1, userInfo: nil)

			beforeEach {
				executionCount = 0
				completedCount = 0
				values = []
				errors = []
				enabled = MutableProperty(false)

				scheduler = TestScheduler()
				action = Action(enabledIf: enabled) { number in
					return SignalProducer { observer, disposable in
						executionCount += 1

						if number % 2 == 0 {
							observer.send(value: "\(number)")
							observer.send(value: "\(number)\(number)")

							disposable += scheduler.schedule {
								observer.sendCompleted()
							}
						} else {
							disposable += scheduler.schedule {
								observer.send(error: testError)
							}
						}
					}
				}

				action.values.observeValues { values.append($0) }
				action.errors.observeValues { errors.append($0) }
				action.completed.observeValues { _ in completedCount += 1 }
			}

			it("should retain the state property") {
				var property: MutableProperty<Bool>? = MutableProperty(false)
				weak var weakProperty = property

				var action: Action<(), (), Never>? = Action(state: property!, enabledIf: { _ in true }) { _, _ in
					return .empty
				}

				expect(weakProperty).toNot(beNil())

				property = nil
				expect(weakProperty).toNot(beNil())

				action = nil
				expect(weakProperty).to(beNil())

				// Mute "unused variable" warning.
				_ = action
			}

			it("should be disabled and not executing after initialization") {
				expect(action.isEnabled.value) == false
				expect(action.isExecuting.value) == false
			}

			it("should error if executed while disabled") {
				var receivedError: ActionError<NSError>?
				var disabledErrorsTriggered = false

				action.disabledErrors.observeValues { _ in
					disabledErrorsTriggered = true
				}

				action.apply(0).startWithFailed {
					receivedError = $0
				}

				expect(receivedError).notTo(beNil())
				expect(disabledErrorsTriggered) == true
				if let error = receivedError {
					let expectedError = ActionError<NSError>.disabled
					expect(error == expectedError) == true
				}
			}

			it("should enable and disable based on the given property") {
				enabled.value = true
				expect(action.isEnabled.value) == true
				expect(action.isExecuting.value) == false

				enabled.value = false
				expect(action.isEnabled.value) == false
				expect(action.isExecuting.value) == false
			}

			it("should not deadlock when its executing state affects its state property without constituting a feedback loop") {
				enabled <~ action.isExecuting.negate()
				expect(enabled.value) == true
				expect(action.isEnabled.value) == true
				expect(action.isExecuting.value) == false

				let disposable = action.apply(0).start()
				expect(enabled.value) == false
				expect(action.isEnabled.value) == false
				expect(action.isExecuting.value) == true

				disposable.dispose()
				expect(enabled.value) == true
				expect(action.isEnabled.value) == true
				expect(action.isExecuting.value) == false
			}

			it("should not deadlock when its enabled state affects its state property without constituting a feedback loop") {
				// Emulate control binding: When a UITextField is the first responder and
				// is being disabled by an `Action`, the control events emitted might
				// feedback into the availability of the `Action` synchronously, e.g.
				// via a `MutableProperty` or `ValidatingProperty`.
				var isFirstResponder = false

				action.isEnabled.producer
					.compactMap { isActionEnabled in !isActionEnabled && isFirstResponder ? () : nil }
					.startWithValues { _ in enabled.value = false }

				enabled.value = true
				expect(enabled.value) == true
				expect(action.isEnabled.value) == true
				expect(action.isExecuting.value) == false

				isFirstResponder = true
				let disposable = action.apply(0).start()
				expect(enabled.value) == false
				expect(action.isEnabled.value) == false
				expect(action.isExecuting.value) == true

				disposable.dispose()
				expect(enabled.value) == false
				expect(action.isEnabled.value) == false
				expect(action.isExecuting.value) == false

				enabled.value = true
				expect(enabled.value) == true
				expect(action.isEnabled.value) == true
				expect(action.isExecuting.value) == false
			}

			it("should not deadlock") {
				final class ViewModel {
					let action2 = Action<(), (), Never> { _ in SignalProducer(value: ()) }
				}

				let action1 = Action<(), ViewModel, Never> { _ in SignalProducer(value: ViewModel()) }

				// Fixed in #267. (https://github.com/ReactiveCocoa/ReactiveSwift/pull/267)
				//
				// The deadlock happened as the observer disposable releases the closure
				// `{ _ in viewModel }` here without releasing the mapped signal's
				// `updateLock` first. The deinitialization of the closure triggered the
				// propagation of terminal event of the `Action`, which eventually hit
				// the mapped signal and attempted to acquire `updateLock` to transition
				// the signal's state.
				action1.values
					.flatMap(.latest) { viewModel in viewModel.action2.values.map { _ in viewModel } }
					.observeValues { _ in }

				action1.apply().start()
				action1.apply().start()
			}

			it("should not loop indefinitely") {
				let condition = MutableProperty(1)
				
				let action = Action<Void, Void, Never>(state: condition, enabledIf: { $0 == 0 }) { _, _ in
					return .empty
				}
				
				var count = 0
				
				action.isExecuting.producer
					.startWithValues { _ in
						condition.value = 10
						
						count += 1
						expect(count) == 1
					}
			}

			describe("completed") {
				beforeEach {
					enabled.value = true
				}

				it("should send a value whenever the producer completes") {
					action.apply(0).start()
					expect(completedCount) == 0

					scheduler.run()
					expect(completedCount) == 1

					action.apply(2).start()
					scheduler.run()
					expect(completedCount) == 2
				}

				it("should not send a value when the producer fails") {
					action.apply(1).start()
					scheduler.run()
					expect(completedCount) == 0
				}

				it("should not send a value when the producer is interrupted") {
					let disposable = action.apply(0).start()
					disposable.dispose()
					scheduler.run()
					expect(completedCount) == 0
				}

				it("should not send a value when the action is disabled") {
					enabled.value = false
					action.apply(0).start()
					scheduler.run()
					expect(completedCount) == 0
				}
			}

			describe("execution") {
				beforeEach {
					enabled.value = true
				}

				it("should execute successfully") {
					var receivedValue: String?

					action.apply(0)
						.assumeNoErrors()
						.startWithValues {
							receivedValue = $0
						}

					expect(executionCount) == 1
					expect(action.isExecuting.value) == true
					expect(action.isEnabled.value) == false

					expect(receivedValue) == "00"
					expect(values) == [ "0", "00" ]
					expect(errors) == []

					scheduler.run()
					expect(action.isExecuting.value) == false
					expect(action.isEnabled.value) == true

					expect(values) == [ "0", "00" ]
					expect(errors) == []
				}

				it("should execute with an error") {
					var receivedError: ActionError<NSError>?

					action.apply(1).startWithFailed {
						receivedError = $0
					}

					expect(executionCount) == 1
					expect(action.isExecuting.value) == true
					expect(action.isEnabled.value) == false

					scheduler.run()
					expect(action.isExecuting.value) == false
					expect(action.isEnabled.value) == true

					expect(receivedError).notTo(beNil())
					if let error = receivedError {
						let expectedError = ActionError<NSError>.producerFailed(testError)
						expect(error == expectedError) == true
					}

					expect(values) == []
					expect(errors) == [ testError ]
				}
			}

			describe("bindings") {
				it("should execute successfully") {
					var receivedValue: String?
					let (signal, observer) = Signal<Int, Never>.pipe()

					action.values.observeValues { receivedValue = $0 }

					action <~ signal

					enabled.value = true

					expect(executionCount) == 0
					expect(action.isExecuting.value) == false
					expect(action.isEnabled.value) == true

					observer.send(value: 0)

					expect(executionCount) == 1
					expect(action.isExecuting.value) == true
					expect(action.isEnabled.value) == false

					expect(receivedValue) == "00"
					expect(values) == [ "0", "00" ]
					expect(errors) == []

					scheduler.run()
					expect(action.isExecuting.value) == false
					expect(action.isEnabled.value) == true

					expect(values) == [ "0", "00" ]
					expect(errors) == []
				}
			}
		}

		describe("using a property as input") {
			let echo: (Int) -> SignalProducer<Int, Never> = SignalProducer.init(value:)

			it("executes the action with the property's current value") {
				let input = MutableProperty(0)
				let action = Action(state: input, execute: echo)

				var values: [Int] = []
				action.values.observeValues { values.append($0) }

				input.value = 1
				action.apply().start()
				input.value = 2
				action.apply().start()
				input.value = 3
				action.apply().start()

				expect(values) == [1, 2, 3]
			}

			it("allows a non-void input type") {
				let state = MutableProperty(1)

				let add = Action<Int, Int, Never>(state: state) { state, input in
					SignalProducer(value: state + input)
				}

				var values: [Int] = []
				add.values.observeValues { values.append($0) }

				add.apply(2).start()
				add.apply(3).start()

				state.value = -1
				add.apply(-10).start()

				expect(values) == [3, 4, -11]
			}

			it("is disabled if the property is nil") {
				let input = MutableProperty<Int?>(1)
				let action = Action(unwrapping: input, execute: echo)

				expect(action.isEnabled.value) == true
				input.value = nil
				expect(action.isEnabled.value) == false
			}

			it("allows a different input type while unwrapping an optional state property") {
				let state = MutableProperty<Int?>(nil)

				let add = Action<String, Int?, Never>(unwrapping: state) { state, input -> SignalProducer<Int?, Never> in
					guard let input = Int(input) else { return SignalProducer(value: nil) }
					return SignalProducer(value: state + input)
				}

				var values: [Int] = []
				add.values.observeValues { output in
					if let output = output {
						values.append(output)
					}
				}

				expect(add.isEnabled.value) == false
				state.value = 1
				expect(add.isEnabled.value) == true

				add.apply("2").start()
				add.apply("3").start()

				state.value = -1
				add.apply("-10").start()

				expect(values) == [3, 4, -11]
			}
			
			it("is disabled if the validating property does not hold a valid value") {
				enum TestValidationError: Error { case generic }
				typealias PropertyType = ValidatingProperty<Int, TestValidationError>
				let decisions: [PropertyType.Decision] = [.valid, .invalid(.generic), .coerced(10, nil)]
				let input = PropertyType(0, { decisions[$0] })
				let action = Action(validated: input, execute: echo)
				expect(action.isEnabled.value) == true
				expect(action.apply().single()?.value) == 0
				input.value = 1
				expect(action.isEnabled.value) == false
				expect(action.apply().single()?.error).toNot(beNil())
				input.value = 2
				expect(action.isEnabled.value) == true
				expect(action.apply().single()?.value) == 10
			}
			
			it("allows a different input type while using a validating property as its state") {
				enum TestValidationError: Error { case generic }
				let state = ValidatingProperty<Int?, TestValidationError>(nil, { $0 != nil ? .valid : .invalid(.generic) })
				
				let add = Action<String, Int?, Never>(validated: state) { state, input -> SignalProducer<Int?, Never> in
					guard let input = Int(input), let state = state else { return SignalProducer(value: nil) }
					return SignalProducer(value: state + input)
				}
				
				var values: [Int] = []
				add.values.observeValues { output in
					if let output = output {
						values.append(output)
					}
				}
				
				expect(add.isEnabled.value) == false
				state.value = 1
				expect(add.isEnabled.value) == true
				
				add.apply("2").start()
				add.apply("3").start()
				
				state.value = -1
				add.apply("-10").start()
				
				expect(values) == [3, 4, -11]
			}
		}
	}
}
