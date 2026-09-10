import Dispatch

import Nimble
import Quick
@testable import ReactiveSwift

private class Object {
	var value: Int = 0
}

class UnidirectionalBindingSpec: QuickSpec {
	override func spec() {
		describe("BindingTarget") {
			var token: Lifetime.Token!
			var lifetime: Lifetime!

			beforeEach {
				token = Lifetime.Token()
				lifetime = Lifetime(token)
			}

			describe("closure binding target") {
				var target: BindingTarget<Int>?
				var optionalTarget: BindingTarget<Int?>?
				var value: Int?

				beforeEach {
					target = BindingTarget(lifetime: lifetime, action: { value = $0 })
					optionalTarget = BindingTarget(lifetime: lifetime, action: { value = $0 })
					value = nil
				}

				describe("non-optional target") {
					it("should pass through the lifetime") {
						expect(target!.lifetime).to(beIdenticalTo(lifetime))
					}

					it("should trigger the supplied setter") {
						expect(value).to(beNil())

						target!.action(1)
						expect(value) == 1
					}

					it("should accept bindings from properties") {
						expect(value).to(beNil())

						let property = MutableProperty(1)
						target! <~ property
						expect(value) == 1

						property.value = 2
						expect(value) == 2
					}
				}

				describe("target of optional value") {
					it("should pass through the lifetime") {
						expect(optionalTarget!.lifetime).to(beIdenticalTo(lifetime))
					}

					it("should trigger the supplied setter") {
						expect(value).to(beNil())

						optionalTarget!.action(1)
						expect(value) == 1
					}

					it("should accept bindings from properties") {
						expect(value).to(beNil())

						let property = MutableProperty(1)
						optionalTarget! <~ property
						expect(value) == 1

						property.value = 2
						expect(value) == 2
					}
				}

				describe("optional LHS binding with non-nil LHS at runtime") {
					it("should pass through the lifetime") {
						expect(target.bindingTarget.lifetime).to(beIdenticalTo(lifetime))
					}

					it("should accept bindings from properties") {
						expect(value).to(beNil())

						let property = MutableProperty(1)
						optionalTarget <~ property
						expect(value) == 1

						property.value = 2
						expect(value) == 2
					}
				}

				describe("optional LHS binding with nil LHS at runtime") {
					it("should pass through the empty lifetime") {
						let nilTarget: BindingTarget<Int>? = nil
						expect(nilTarget.bindingTarget.lifetime).to(beIdenticalTo(Lifetime.empty))
					}
				}
			}

			describe("key path binding target") {
				var target: BindingTarget<Int>!
				var object: Object!

				beforeEach {
					object = Object()
					target = BindingTarget(lifetime: lifetime, object: object, keyPath: \.value)
				}

				it("should pass through the lifetime") {
					expect(target.lifetime).to(beIdenticalTo(lifetime))
				}

				it("should trigger the supplied setter") {
					expect(object.value) == 0

					target.action(1)
					expect(object.value) == 1
				}

				it("should accept bindings from properties") {
					expect(object.value) == 0

					let property = MutableProperty(1)
					target <~ property
					expect(object.value) == 1

					property.value = 2
					expect(object.value) == 2
				}
			}

			it("should not deadlock on the same queue") {
				var value: Int?

				let target = BindingTarget(on: UIScheduler(),
				                           lifetime: lifetime,
				                           action: { value = $0 })

				let property = MutableProperty(1)
				target <~ property
				expect(value) == 1
			}

			it("should not deadlock on the main thread even if the context was switched to a different queue") {
				var value: Int?

				let queue = DispatchQueue(label: #file)

				let target = BindingTarget(on: UIScheduler(),
				                           lifetime: lifetime,
				                           action: { value = $0 })

				let property = MutableProperty(1)

				queue.sync {
					_ = target <~ property
				}

				expect(value).toEventually(equal(1))
			}

			it("should not deadlock even if the value is originated from the same queue indirectly") {
				var value: Int?

				let key = DispatchSpecificKey<Void>()
				DispatchQueue.main.setSpecific(key: key, value: ())

				let mainQueueCounter = Atomic(0)

				let setter: (Int) -> Void = {
					value = $0
					mainQueueCounter.modify { $0 += DispatchQueue.getSpecific(key: key) != nil ? 1 : 0 }
				}

				let target = BindingTarget(on: UIScheduler(),
				                           lifetime: lifetime,
				                           action: setter)

				let scheduler = QueueScheduler.makeForTesting()

				let property = MutableProperty(1)
				target <~ property.producer
					.start(on: scheduler)
					.observe(on: scheduler)

				expect(value).toEventually(equal(1))
				expect(mainQueueCounter.value).toEventually(equal(1))

				property.value = 2
				expect(value).toEventually(equal(2))
				expect(mainQueueCounter.value).toEventually(equal(2))
			}

			describe("observer binding operator") {
				it("should forward values to observer") {
					let targetPipe = Signal<Int?, Never>.pipe()
					let sourcePipe = Signal<Int?, Never>.pipe()
					let targetProperty = Property<Int?>(initial: nil, then: targetPipe.output)
					targetPipe.input <~ sourcePipe.output
					expect(targetProperty.value).to(beNil())
					sourcePipe.input.send(value: 1)
					expect(targetProperty.value).to(equal(1))
				}
			}
		}
	}
}
