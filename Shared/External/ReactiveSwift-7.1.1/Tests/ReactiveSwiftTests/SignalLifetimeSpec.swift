//
//  SignalLifetimeSpec.swift
//  ReactiveSwift
//
//  Created by Vadim Yelagin on 2015-12-13.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Foundation

import Nimble
import Quick
import ReactiveSwift

class SignalLifetimeSpec: QuickSpec {
	override func spec() {
		describe("init") {
			var testScheduler: TestScheduler!

			beforeEach {
				testScheduler = TestScheduler()
			}

			it("should automatically interrupt if the input observer is not retained") {
				let disposable = AnyDisposable()
				var outerSignal: Signal<Never, Never>!
				_ = outerSignal

				func scope() {
					let (signal, observer) = Signal<Never, Never>.pipe(disposable: disposable)

					withExtendedLifetime(observer) {
						outerSignal = signal
						expect(disposable.isDisposed) == false
					}
				}

				scope()
				expect(disposable.isDisposed) == true
			}

			it("should automatically interrupt if the input observer is not retained, even if there are still one or more active observer") {
				let disposable = AnyDisposable()
				var isInterrupted = false
				var outerSignal: Signal<Never, Never>!
				_ = outerSignal

				func scope() {
					let (signal, observer) = Signal<Never, Never>.pipe(disposable: disposable)

					withExtendedLifetime(observer) {
						outerSignal = signal

						signal.observeInterrupted {
							isInterrupted = true
						}

						expect(isInterrupted) == false
						expect(disposable.isDisposed) == false
					}
				}

				scope()
				expect(isInterrupted) == true
				expect(disposable.isDisposed) == true
			}

			it("should be disposed of if it does not have any observers") {
				var isDisposed = false

				weak var signal: Signal<AnyObject, Never>? = {
					let signal: Signal<AnyObject, Never> = .never
					return signal.on(disposed: { isDisposed = true })
				}()
				expect(signal).to(beNil())
				expect(isDisposed) == true
			}

			it("should be disposed of if no one retains it") {
				var isDisposed = false

				var observer: Signal<AnyObject, Never>.Observer!
				var signal: Signal<AnyObject, Never>? = Signal
					.init { innerObserver, _ in
						observer = innerObserver
					}
					.on(disposed: { isDisposed = true })

				weak var weakSignal = signal

				withExtendedLifetime(observer) {
					expect(weakSignal).toNot(beNil())
					expect(isDisposed) == false

					var reference = signal
					_ = reference

					signal = nil
					expect(weakSignal).toNot(beNil())
					expect(isDisposed) == false

					reference = nil
					expect(weakSignal).to(beNil())
					expect(isDisposed) == true
				}
			}

			it("should be disposed of when the signal shell has deinitialized with no active observer regardless of whether the generator observer is retained or not") {
				var observer: Signal<AnyObject, Never>.Observer?
				var isDisposed = false

				weak var signal: Signal<AnyObject, Never>? = {
					let signal: Signal<AnyObject, Never> = Signal { innerObserver, _ in
						observer = innerObserver

					}
					return signal.on(disposed: { isDisposed = true })
				}()
				expect(observer).toNot(beNil())
				expect(signal).to(beNil())
				expect(isDisposed) == true
			}

			it("should be disposed of when the generator observer has deinitialized even if it has an observer") {
				var inputObserver: Signal<AnyObject, Never>.Observer?
				var disposable: Disposable? = nil
				_ = (inputObserver, disposable)

				var isDisposed = false

				weak var signal: Signal<AnyObject, Never>? = {
					let signal = Signal<AnyObject, Never> { observer, lifetime in
						inputObserver = observer
						lifetime.observeEnded { isDisposed = true }
					}

					disposable = signal.observe(Signal.Observer())
					return signal
				}()

				expect(signal).to(beNil())
				expect(isDisposed) == false

				inputObserver = nil
				expect(isDisposed) == true
			}

			it("should be alive until erroring if it has at least one observer, despite not being explicitly retained") {
				var errored = false
				var isDisposed = false

				weak var signal: Signal<AnyObject, TestError>? = {
					let signal = Signal<AnyObject, TestError> { observer, _ in
						testScheduler.schedule {
							observer.send(error: TestError.default)
						}
					}
					signal.on(disposed: { isDisposed = true }).observeFailed { _ in errored = true }
					return signal
				}()

				expect(errored) == false
				expect(signal).to(beNil())
				expect(isDisposed) == false

				testScheduler.run()

				expect(errored) == true
				expect(signal).to(beNil())
				expect(isDisposed) == true
			}

			it("should be alive until completion if it has at least one observer, despite not being explicitly retained") {
				var completed = false
				var isDisposed = false

				weak var signal: Signal<AnyObject, Never>? = {
					let signal = Signal<AnyObject, Never> { observer, _ in
						testScheduler.schedule {
							observer.sendCompleted()
						}
					}
					signal.on(disposed: { isDisposed = true }).observeCompleted { completed = true }
					return signal
				}()

				expect(completed) == false
				expect(signal).to(beNil())
				expect(isDisposed) == false

				testScheduler.run()

				expect(completed) == true
				expect(signal).to(beNil())
				expect(isDisposed) == true
			}

			it("should be alive until interruption if it has at least one observer, despite not being explicitly retained") {
				var interrupted = false
				var isDisposed = false

				weak var signal: Signal<AnyObject, Never>? = {
					let signal = Signal<AnyObject, Never> { observer, _ in
						testScheduler.schedule {
							observer.sendInterrupted()
						}
					}
					signal.on(disposed: { isDisposed = true }).observeInterrupted { interrupted = true }
					return signal
				}()

				expect(interrupted) == false
				expect(signal).to(beNil())
				expect(isDisposed) == false

				testScheduler.run()

				expect(interrupted) == true
				expect(signal).to(beNil())
				expect(isDisposed) == true
			}
		}

		describe("Signal.pipe") {
			it("should deallocate") {
				weak var signal: AnyObject? = {
					let (signal, _) = Signal<(), Never>.pipe()
					return signal
				}()

				expect(signal).to(beNil())
			}

			it("should be alive until erroring if it has at least one observer, despite not being explicitly retained") {
				let testScheduler = TestScheduler()
				var errored = false
				weak var weakSignal: Signal<(), TestError>?
				var isDisposed = false

				// Use an inner closure to help ARC deallocate things as we
				// expect.
				let test = {
					let (signal, observer) = Signal<(), TestError>.pipe()
					weakSignal = signal
					testScheduler.schedule {
						// Note that the input observer has a weak reference to the signal.
						observer.send(error: TestError.default)
					}
					signal.on(disposed: { isDisposed = true }).observeFailed { _ in errored = true }
				}
				test()

				expect(weakSignal).to(beNil())
				expect(isDisposed) == false
				expect(errored) == false

				testScheduler.run()

				expect(weakSignal).to(beNil())
				expect(isDisposed) == true
				expect(errored) == true
			}

			it("should be alive until completion if it has at least one observer, despite not being explicitly retained") {
				let testScheduler = TestScheduler()
				var completed = false
				weak var weakSignal: Signal<(), TestError>?
				var isDisposed = false

				// Use an inner closure to help ARC deallocate things as we
				// expect.
				let test = {
					let (signal, observer) = Signal<(), TestError>.pipe()
					weakSignal = signal
					testScheduler.schedule {
						// Note that the input observer has a weak reference to the signal.
						observer.sendCompleted()
					}
					signal.on(disposed: { isDisposed = true }).observeCompleted { completed = true }
				}
				test()

				expect(weakSignal).to(beNil())
				expect(isDisposed) == false
				expect(completed) == false

				testScheduler.run()

				expect(weakSignal).to(beNil())
				expect(isDisposed) == true
				expect(completed) == true
			}

			it("should be alive until interruption if it has at least one observer, despite not being explicitly retained") {
				let testScheduler = TestScheduler()
				var interrupted = false
				weak var weakSignal: Signal<(), Never>?
				var isDisposed = false

				let test = {
					let (signal, observer) = Signal<(), Never>.pipe()
					weakSignal = signal

					testScheduler.schedule {
						// Note that the input observer has a weak reference to the signal.
						observer.sendInterrupted()
					}

					signal.on(disposed: { isDisposed = true }).observeInterrupted { interrupted = true }
				}

				test()
				expect(weakSignal).to(beNil())
				expect(isDisposed) == false
				expect(interrupted) == false

				testScheduler.run()

				expect(weakSignal).to(beNil())
				expect(isDisposed) == true
				expect(interrupted) == true
			}
		}

		describe("testTransform") {
			it("should be disposed of") {
				var isDisposed = false
				weak var signal: Signal<AnyObject, Never>? = Signal.never
					.testTransform()
					.on(disposed: { isDisposed = true })

				expect(signal).to(beNil())
				expect(isDisposed) == true
			}

			it("should be disposed of if it is not explicitly retained and its generator observer is not retained") {
				var disposable: Disposable? = nil
				var inputObserver: Signal<AnyObject, Never>.Observer?
				_ = (disposable, inputObserver)

				var isDisposed = false

				weak var signal: Signal<AnyObject, Never>? = {
					let signal = Signal<AnyObject, Never> { observer, lifetime in
						inputObserver = observer
						lifetime.observeEnded { isDisposed = true }
					}

					let transformed = signal.testTransform()
					disposable = transformed.observe(Signal.Observer())
					return transformed
				}()

				expect(signal).to(beNil())
				expect(isDisposed) == false

				inputObserver = nil
				expect(isDisposed) == true
			}

			it("should deallocate if it is unreachable and has no observer") {
				let (sourceSignal, sourceObserver) = Signal<Int, Never>.pipe()

				var firstCounter = 0
				var secondCounter = 0
				var thirdCounter = 0

				func run() {
					_ = sourceSignal
						.map { value -> Int in
							firstCounter += 1
							return value
						}
						.map { value -> Int in
							secondCounter += 1
							return value
						}
						.map { value -> Int in
							thirdCounter += 1
							return value
						}
				}

				run()

				sourceObserver.send(value: 1)
				expect(firstCounter) == 0
				expect(secondCounter) == 0
				expect(thirdCounter) == 0

				sourceObserver.send(value: 2)
				expect(firstCounter) == 0
				expect(secondCounter) == 0
				expect(thirdCounter) == 0
			}

			it("should not deallocate if it is unreachable but still has at least one observer") {
				let (sourceSignal, sourceObserver) = Signal<Int, Never>.pipe()

				var firstCounter = 0
				var secondCounter = 0
				var thirdCounter = 0

				var disposable: Disposable?

				func run() {
					disposable = sourceSignal
						.map { value -> Int in
							firstCounter += 1
							return value
						}
						.map { value -> Int in
							secondCounter += 1
							return value
						}
						.map { value -> Int in
							thirdCounter += 1
							return value
						}
						.observe { _ in }
				}

				run()

				sourceObserver.send(value: 1)
				expect(firstCounter) == 1
				expect(secondCounter) == 1
				expect(thirdCounter) == 1

				sourceObserver.send(value: 2)
				expect(firstCounter) == 2
				expect(secondCounter) == 2
				expect(thirdCounter) == 2

				disposable?.dispose()

				sourceObserver.send(value: 3)
				expect(firstCounter) == 2
				expect(secondCounter) == 2
				expect(thirdCounter) == 2
			}
		}

		describe("observe") {
			var signal: Signal<Int, TestError>!
			var observer: Signal<Int, TestError>.Observer!

			var token: NSObject? = nil
			weak var weakToken: NSObject?

			func expectTokenNotDeallocated() {
				expect(weakToken).toNot(beNil())
			}

			func expectTokenDeallocated() {
				expect(weakToken).to(beNil())
			}

			beforeEach {
				let (signalTemp, observerTemp) = Signal<Int, TestError>.pipe()
				signal = signalTemp
				observer = observerTemp

				token = NSObject()
				weakToken = token

				signal.observe { [token = token] _ in
					_ = token!.description
				}
			}

			it("should deallocate observe handler when signal completes") {
				expectTokenNotDeallocated()

				observer.send(value: 1)
				expectTokenNotDeallocated()

				token = nil
				expectTokenNotDeallocated()

				observer.send(value: 2)
				expectTokenNotDeallocated()

				observer.sendCompleted()
				expectTokenDeallocated()
			}

			it("should deallocate observe handler when signal fails") {
				expectTokenNotDeallocated()

				observer.send(value: 1)
				expectTokenNotDeallocated()

				token = nil
				expectTokenNotDeallocated()

				observer.send(value: 2)
				expectTokenNotDeallocated()

				observer.send(error: .default)
				expectTokenDeallocated()
			}
		}
	}
}

private extension Signal {
	func testTransform() -> Signal<Value, Error> {
		return Signal { observer, lifetime in
			lifetime += self.observe(observer.send)
		}
	}
}
