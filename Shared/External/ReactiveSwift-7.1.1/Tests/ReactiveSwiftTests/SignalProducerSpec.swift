//
//  SignalProducerSpec.swift
//  ReactiveSwift
//
//  Created by Justin Spahr-Summers on 2015-01-23.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Dispatch
import Foundation

import Nimble
import Quick
@testable import ReactiveSwift

class SignalProducerSpec: QuickSpec {
	override func spec() {
		describe("init") {
			it("should run the handler once per start()") {
				var handlerCalledTimes = 0
				let signalProducer = SignalProducer<String, NSError> { _, _ in
					handlerCalledTimes += 1

					return
				}

				signalProducer.start()
				signalProducer.start()

				expect(handlerCalledTimes) == 2
			}

			it("should not release signal observers when given disposable is disposed") {
				var lifetime: Lifetime!
				_ = lifetime

				let producer = SignalProducer<Int, Never> { observer, innerLifetime in
					lifetime = innerLifetime

					innerLifetime.observeEnded {
						// This is necessary to keep the observer long enough to
						// even test the memory management.
						observer.send(value: 0)
					}
				}

				weak var objectRetainedByObserver: NSObject?

				var disposable: Disposable!
				producer.startWithSignal { signal, interruptHandle in
					disposable = interruptHandle

					let object = NSObject()
					objectRetainedByObserver = object
					signal.observeValues { _ in _ = object }
				}

				expect(objectRetainedByObserver).toNot(beNil())

				disposable.dispose()
				expect(objectRetainedByObserver).to(beNil())
			}

			it("should dispose of added disposables upon completion") {
				let addedDisposable = AnyDisposable()
				var observer: Signal<(), Never>.Observer!

				let producer = SignalProducer<(), Never> { incomingObserver, lifetime in
					lifetime += addedDisposable
					observer = incomingObserver
				}

				producer.start()
				expect(addedDisposable.isDisposed) == false

				observer.sendCompleted()
				expect(addedDisposable.isDisposed) == true
			}

			it("should dispose of added disposables upon error") {
				let addedDisposable = AnyDisposable()
				var observer: Signal<(), TestError>.Observer!

				let producer = SignalProducer<(), TestError> { incomingObserver, lifetime in
					lifetime += addedDisposable
					observer = incomingObserver
				}

				producer.start()
				expect(addedDisposable.isDisposed) == false

				observer.send(error: .default)
				expect(addedDisposable.isDisposed) == true
			}

			it("should dispose of added disposables upon interruption") {
				let addedDisposable = AnyDisposable()
				var observer: Signal<(), Never>.Observer!

				let producer = SignalProducer<(), Never> { incomingObserver, lifetime in
					lifetime += addedDisposable
					observer = incomingObserver
				}

				producer.start()
				expect(addedDisposable.isDisposed) == false

				observer.sendInterrupted()
				expect(addedDisposable.isDisposed) == true
			}

			it("should dispose of added disposables upon start() disposal") {
				let addedDisposable = AnyDisposable()

				let producer = SignalProducer<(), TestError> { _, lifetime in
					lifetime += addedDisposable
					return
				}

				let startDisposable = producer.start()
				expect(addedDisposable.isDisposed) == false

				startDisposable.dispose()
				expect(addedDisposable.isDisposed) == true
			}

			it("should deliver the interrupted event with respect to the asynchronous operator applied to an alive upstream with a signal product") {
				let scheduler = TestScheduler()
				var isInterrupted = false

				let (signal, _) = Signal<Int, Never>.pipe()

				let disposable = SignalProducer(signal)
					.observe(on: scheduler)
					.startWithSignal { signal, disposable -> Disposable in
						signal.observeInterrupted {
							isInterrupted = true
						}
						return disposable
					}

				disposable.dispose()
				expect(isInterrupted) == false

				scheduler.run()
				expect(isInterrupted) == true
			}

			it("should deliver the interrupted event with respect to the asynchronous operator applied to a terminated upstream with a signal product") {
				let scheduler = TestScheduler()
				var isInterrupted = false

				let disposable: Disposable = SignalProducer<Int, Never>.empty
					.observe(on: scheduler)
					.startWithSignal { signal, disposable in
						signal.observeInterrupted {
							isInterrupted = true
						}
						return disposable
					}

				disposable.dispose()
				expect(isInterrupted) == false

				scheduler.run()
				expect(isInterrupted) == true
			}

			it("should deliver the interrupted event with respect to the asynchronous operator applied to an alive upstream with a direct observation") {
				let scheduler = TestScheduler()
				var isInterrupted = false

				let (signal, _) = Signal<Int, Never>.pipe()

				let disposable = SignalProducer(signal)
					.observe(on: scheduler)
					.startWithInterrupted {
						isInterrupted = true
					}

				disposable.dispose()
				expect(isInterrupted) == false

				scheduler.run()
				expect(isInterrupted) == true
			}

			it("should deliver the interrupted event with respect to the asynchronous operator applied to a terminated upstream with a direct observation") {
				let scheduler = TestScheduler()
				var isInterrupted = false

				let disposable = SignalProducer<Int, Never>.empty
					.observe(on: scheduler)
					.startWithInterrupted {
						isInterrupted = true
					}

				disposable.dispose()
				expect(isInterrupted) == false

				scheduler.run()
				expect(isInterrupted) == true
			}
		}

		describe("init(signal:)") {
			var signal: Signal<Int, TestError>!
			var observer: Signal<Int, TestError>.Observer!

			beforeEach {
				// Cannot directly assign due to compiler crash on Xcode 7.0.1
				let (signalTemp, observerTemp) = Signal<Int, TestError>.pipe()
				signal = signalTemp
				observer = observerTemp
			}

			it("should emit values then complete") {
				let producer = SignalProducer<Int, TestError>(signal)

				var values: [Int] = []
				var error: TestError?
				var completed = false
				producer.start { event in
					switch event {
					case let .value(value):
						values.append(value)
					case let .failed(err):
						error = err
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(values) == []
				expect(error).to(beNil())
				expect(completed) == false

				observer.send(value: 1)
				expect(values) == [ 1 ]
				observer.send(value: 2)
				observer.send(value: 3)
				expect(values) == [ 1, 2, 3 ]

				observer.sendCompleted()
				expect(completed) == true
			}

			it("should emit error") {
				let producer = SignalProducer<Int, TestError>(signal)

				var error: TestError?
				let sentError = TestError.default

				producer.start { event in
					switch event {
					case let .failed(err):
						error = err
					default:
						break
					}
				}

				expect(error).to(beNil())

				observer.send(error: sentError)
				expect(error) == sentError
			}
		}

		describe("init(value:)") {
			it("should immediately send the value then complete") {
				let producerValue = "StringValue"
				let signalProducer = SignalProducer<String, NSError>(value: producerValue)

				expect(signalProducer).to(sendValue(producerValue, sendError: nil, complete: true))
			}
		}

		describe("init closure overloading") {
			it("should be inferred and overloaded without ambiguity") {
				let action: () -> String = { "" }
				let throwableAction: () throws -> String = { "" }
				let resultAction1: () -> Result<String, Never> = { .success("") }
				let resultAction2: () -> Result<String, Error> = { .success("") }
				let throwableResultAction: () throws -> Result<String, Never> = { .success("") }

				expect(type(of: SignalProducer(action))) == SignalProducer<String, Error>.self
				expect(type(of: SignalProducer<String, Never>(action))) == SignalProducer<String, Never>.self
				expect(type(of: SignalProducer<String, TestError>(action))) == SignalProducer<String, TestError>.self

				expect(type(of: SignalProducer(resultAction1))) == SignalProducer<String, Never>.self
				expect(type(of: SignalProducer(resultAction2))) == SignalProducer<String, Error>.self

				expect(type(of: SignalProducer(throwableAction))) == SignalProducer<String, Error>.self
				expect(type(of: SignalProducer(throwableResultAction))) == SignalProducer<Result<String, Never>, Error>.self
			}
		}

		describe("init(_:) lazy value") {
			it("should not evaluate the supplied closure until started") {
				var evaluated: Bool = false
				func lazyGetter() -> String {
					evaluated = true
					return "🎃"
				}

				let lazyProducer = SignalProducer<String, Never>(lazyGetter)

				expect(evaluated).to(beFalse())

				expect(lazyProducer).to(sendValue("🎃", sendError: nil, complete: true))
				expect(evaluated).to(beTrue())
			}
		}

		describe("init(error:)") {
			it("should immediately send the error") {
				let producerError = NSError(domain: "com.reactivecocoa.errordomain", code: 4815, userInfo: nil)
				let signalProducer = SignalProducer<Int, NSError>(error: producerError)

				expect(signalProducer).to(sendValue(nil, sendError: producerError, complete: false))
			}
		}

		describe("init(result:)") {
			it("should immediately send the value then complete") {
				let producerValue = "StringValue"
				let producerResult = .success(producerValue) as Result<String, NSError>
				let signalProducer = SignalProducer(result: producerResult)

				expect(signalProducer).to(sendValue(producerValue, sendError: nil, complete: true))
			}

			it("should immediately send the error") {
				let producerError = NSError(domain: "com.reactivecocoa.errordomain", code: 4815, userInfo: nil)
				let producerResult = .failure(producerError) as Result<String, NSError>
				let signalProducer = SignalProducer(result: producerResult)

				expect(signalProducer).to(sendValue(nil, sendError: producerError, complete: false))
			}
		}

		describe("init(values:)") {
			it("should immediately send the sequence of values") {
				let sequenceValues = [1, 2, 3]
				let signalProducer = SignalProducer<Int, NSError>(sequenceValues)

				expect(signalProducer).to(sendValues(sequenceValues, sendError: nil, complete: true))
			}
		}

		describe("SignalProducer.empty") {
			it("should immediately complete") {
				let signalProducer = SignalProducer<Int, NSError>.empty

				expect(signalProducer).to(sendValue(nil, sendError: nil, complete: true))
			}
		}

		describe("SignalProducer.never") {
			it("should not send any events while still being alive") {
				let signalProducer = SignalProducer<Int, NSError>.never

				var numberOfEvents = 0
				var isDisposed = false

				func scope() -> Disposable {
					defer {
						expect(numberOfEvents) == 0
						expect(isDisposed) == false
					}
					return signalProducer.on(disposed: { isDisposed = true }).start { _ in numberOfEvents += 1 }
				}

				let d = scope()
				expect(numberOfEvents) == 0
				expect(isDisposed) == false

				d.dispose()
				expect(numberOfEvents) == 1
				expect(isDisposed) == true
			}

			it("should not send any events while still being alive even if the interrupt handle deinitializes") {
				let signalProducer = SignalProducer<Int, NSError>.never

				var numberOfEvents = 0
				var isDisposed = false

				func scope() {
					signalProducer.on(disposed: { isDisposed = false }).start { _ in numberOfEvents += 1 }
					expect(numberOfEvents) == 0
					expect(isDisposed) == false
				}

				scope()
				expect(numberOfEvents) == 0
				expect(isDisposed) == false
			}
		}

		describe("trailing closure") {
			it("receives next values") {
				let (producer, observer) = SignalProducer<Int, Never>.pipe()

				var values = [Int]()
				producer.startWithValues { value in
					values.append(value)
				}

				observer.send(value: 1)
				expect(values) == [1]
			}
		}

		describe("init(_:) lazy result") {
			it("should run the operation once per start()") {
				var operationRunTimes = 0
				let operation: () -> Result<String, NSError> = {
					operationRunTimes += 1

					return .success("OperationValue")
				}

				SignalProducer(operation).start()
				SignalProducer(operation).start()

				expect(operationRunTimes) == 2
			}

			it("should send the value then complete") {
				let operationReturnValue = "OperationValue"
				let operation: () -> Result<String, NSError> = {
					return .success(operationReturnValue)
				}

				let signalProducer = SignalProducer(operation)

				expect(signalProducer).to(sendValue(operationReturnValue, sendError: nil, complete: true))
			}

			it("should send the error") {
				let operationError = NSError(domain: "com.reactivecocoa.errordomain", code: 4815, userInfo: nil)
				let operation: () -> Result<String, NSError> = {
					return .failure(operationError)
				}

				let signalProducer = SignalProducer(operation)

				expect(signalProducer).to(sendValue(nil, sendError: operationError, complete: false))
			}
		}

		describe("init(_:) throwable lazy value") {
			it("should send a successful value then complete") {
				let operationReturnValue = "OperationValue"

				let signalProducer = SignalProducer<String, Error> { () throws -> String in
					operationReturnValue
				}

				var error: Error?
				signalProducer.startWithFailed {
					error = $0
				}

				expect(error).to(beNil())
			}

			it("should send the error") {
				let operationError = TestError.default

				let signalProducer = SignalProducer<String, Error> { () throws -> String in
					throw operationError
				}

				var error: TestError?
				signalProducer.startWithFailed {
					error = $0 as? TestError
				}

				expect(error) == operationError
			}
		}
		
		describe("Result.producer") {
			it("should send a successful value then complete") {
				let operationReturnValue = "OperationValue"
				
				let signalProducer = SignalProducer<String, Error>(Result.success(operationReturnValue))
				
				var value: String?
				var error: Error?
				var completed = false
				signalProducer
					.on(failed: {
						error = $0
					}, completed: {
						completed = true
					}, value: {
						value = $0
					})
					.start()
				
				expect(value) == operationReturnValue
				expect(error).to(beNil())
				expect(completed).to(beTrue())
			}
			
			it("should send the error") {
				let operationError = TestError.default
				
				let signalProducer = SignalProducer<String, TestError>(Result.failure(operationError))
				
				var value: String?
				var error: TestError?
				signalProducer
					.on(failed: {
						error = $0
					}, value: {
						value = $0
					})
					.start()
				
				expect(value).to(beNil())
				expect(error) == operationError
			}
		}

		describe("startWithSignal") {
			it("should invoke the closure before any effects or events") {
				var started = false
				var value: Int?

				SignalProducer<Int, Never>(value: 42)
					.on(started: {
						started = true
					}, value: {
						value = $0
					})
					.startWithSignal { _, _ in
						expect(started) == false
						expect(value).to(beNil())
					}

				expect(started) == true
				expect(value) == 42
			}

			it("should dispose of added disposables if disposed") {
				let addedDisposable = AnyDisposable()
				var disposable: Disposable!

				let producer = SignalProducer<Int, Never> { _, lifetime in
					lifetime += addedDisposable
					return
				}

				producer.startWithSignal { signal, innerDisposable in
					signal.observe { _ in }
					disposable = innerDisposable
				}

				expect(addedDisposable.isDisposed) == false

				disposable.dispose()
				expect(addedDisposable.isDisposed) == true
			}

			it("should send interrupted if disposed") {
				var interrupted = false
				var disposable: Disposable!

				SignalProducer<Int, Never>(value: 42)
					.start(on: TestScheduler())
					.startWithSignal { signal, innerDisposable in
						signal.observeInterrupted {
							interrupted = true
						}

						disposable = innerDisposable
					}

				expect(interrupted) == false

				disposable.dispose()
				expect(interrupted) == true
			}

			it("should release signal observers if disposed") {
				weak var objectRetainedByObserver: NSObject?
				var disposable: Disposable!

				let producer = SignalProducer<Int, Never>.never
				producer.startWithSignal { signal, innerDisposable in
					let object = NSObject()
					objectRetainedByObserver = object
					signal.observeValues { _ in _ = object.description }
					disposable = innerDisposable
				}

				expect(objectRetainedByObserver).toNot(beNil())

				disposable.dispose()
				expect(objectRetainedByObserver).to(beNil())
			}

			it("should not trigger effects if disposed before closure return") {
				var started = false
				var value: Int?

				SignalProducer<Int, Never>(value: 42)
					.on(started: {
						started = true
					}, value: {
						value = $0
					})
					.startWithSignal { _, disposable in
						expect(started) == false
						expect(value).to(beNil())

						disposable.dispose()
					}

				expect(started) == false
				expect(value).to(beNil())
			}

			it("should send interrupted if disposed before closure return") {
				var interrupted = false

				SignalProducer<Int, Never>(value: 42)
					.startWithSignal { signal, disposable in
						expect(interrupted) == false

						signal.observeInterrupted {
							interrupted = true
						}

						disposable.dispose()
					}

				expect(interrupted) == true
			}

			it("should dispose of added disposables upon completion") {
				let addedDisposable = AnyDisposable()
				var observer: Signal<Int, TestError>.Observer!

				let producer = SignalProducer<Int, TestError> { incomingObserver, lifetime in
					lifetime += addedDisposable
					observer = incomingObserver
				}

				producer.start()
				expect(addedDisposable.isDisposed) == false

				observer.sendCompleted()
				expect(addedDisposable.isDisposed) == true
			}

			it("should dispose of added disposables upon error") {
				let addedDisposable = AnyDisposable()
				var observer: Signal<Int, TestError>.Observer!

				let producer = SignalProducer<Int, TestError> { incomingObserver, lifetime in
					lifetime += addedDisposable
					observer = incomingObserver
				}

				producer.start()
				expect(addedDisposable.isDisposed) == false

				observer.send(error: .default)
				expect(addedDisposable.isDisposed) == true
			}

			it("should dispose of the added disposable if the signal is unretained and unobserved upon exiting the scope") {
				let addedDisposable = AnyDisposable()

				let producer = SignalProducer<Int, TestError> { _, lifetime in
					lifetime += addedDisposable
				}

				var started = false
				var disposed = false

				producer
					.on(started: { started = true }, disposed: { disposed = true })
					.startWithSignal { _, _ in }

				expect(started) == true
				expect(disposed) == true
				expect(addedDisposable.isDisposed) == true
			}

			it("should return whatever value is returned by the setup closure") {
				let producer = SignalProducer<Never, Never>.empty
				expect(producer.startWithSignal { _, _ in "Hello" }) == "Hello"
			}

			it("should dispose of the upstream when the downstream producer terminates") {
				var iterationCount = 0

				let loop = SignalProducer<Int, Never> { observer, lifetime in
					for i in 0 ..< 100 where !lifetime.hasEnded {
						observer.send(value: i)
						iterationCount += 1
					}
					observer.sendCompleted()
				}

				var results: [Int] = []

				waitUntil { done in
					loop
						.lift { $0.take(first: 5) }
						.on(disposed: done)
						.startWithValues { results.append($0) }
				}

				expect(iterationCount) == 5
				expect(results) == [0, 1, 2, 3, 4]
			}
		}

		describe("start") {
			it("should immediately begin sending events") {
				let producer = SignalProducer<Int, Never>([1, 2])

				var values: [Int] = []
				var completed = false
				producer.start { event in
					switch event {
					case let .value(value):
						values.append(value)
					case .completed:
						completed = true
					default:
						break
					}
				}

				expect(values) == [1, 2]
				expect(completed) == true
			}

			it("should send interrupted if disposed") {
				let producer = SignalProducer<(), Never>.never

				var interrupted = false
				let disposable = producer.startWithInterrupted {
					interrupted = true
				}

				expect(interrupted) == false

				disposable.dispose()
				expect(interrupted) == true
			}

			it("should release observer when disposed") {
				weak var objectRetainedByObserver: NSObject?
				var disposable: Disposable!
				let test = {
					let producer = SignalProducer<Int, Never>.never
					let object = NSObject()
					objectRetainedByObserver = object
					disposable = producer.startWithValues { _ in _ = object }
				}

				test()
				expect(objectRetainedByObserver).toNot(beNil())

				disposable.dispose()
				expect(objectRetainedByObserver).to(beNil())
			}

			describe("trailing closure") {
				it("receives next values") {
					let (producer, observer) = SignalProducer<Int, Never>.pipe()

					var values = [Int]()
					producer.startWithValues { value in
						values.append(value)
					}

					observer.send(value: 1)
					observer.send(value: 2)
					observer.send(value: 3)

					observer.sendCompleted()

					expect(values) == [1, 2, 3]
				}

				it("receives results") {
					let (producer, observer) = SignalProducer<Int, TestError>.pipe()

					var results: [Result<Int, TestError>] = []
					producer.startWithResult { results.append($0) }

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
		}

		describe("lift") {
			describe("over unary operators") {
				it("should invoke transformation once per started signal") {
					let baseProducer = SignalProducer<Int, Never>([1, 2])

					var counter = 0
					let transform = { (signal: Signal<Int, Never>) -> Signal<Int, Never> in
						counter += 1
						return signal
					}

					let producer = baseProducer.lift(transform)
					expect(counter) == 0

					producer.start()
					expect(counter) == 1

					producer.start()
					expect(counter) == 2
				}

				it("should not miss any events") {
					let baseProducer = SignalProducer<Int, Never>([1, 2, 3, 4])

					let producer = baseProducer.lift { signal in
						return signal.map { $0 * $0 }
					}
					let result = producer.collect().single()

					expect(result?.value) == [1, 4, 9, 16]
				}

				it("should interrupt all intermediate signals when the upstream is terminated") {
					let baseProducer = SignalProducer<Int, Never>.empty

					var lastEvent: Signal<Int, Never>.Event?

					var isNeverEndingSignalDisposed = false

					let disposable = baseProducer
						.lift { _ in Signal.never.on(disposed: { isNeverEndingSignalDisposed = true }) }
						.start { event in
							lastEvent = event
						}

					expect(lastEvent).to(beNil())
					expect(isNeverEndingSignalDisposed) == false

					disposable.dispose()
					expect(lastEvent) == .interrupted
					expect(isNeverEndingSignalDisposed) == true
				}
			}

			describe("over binary operators") {
				var isNeverEndingSignalDisposed = false

				let binaryLiftTransform = { (_: Signal<Int, Never>) -> (Signal<Int, Never>) -> Signal<Int, Never> in
					{ (_: Signal<Int, Never>) in
						Signal<Int, Never>.never.on(disposed: { isNeverEndingSignalDisposed = true })
					}
				}

				beforeEach { isNeverEndingSignalDisposed = false }

				it("should invoke transformation once per started signal") {
					let baseProducer = SignalProducer<Int, Never>([1, 2])
					let otherProducer = SignalProducer<Int, Never>([3, 4])

					var counter = 0
					let transform = { (signal: Signal<Int, Never>) -> (Signal<Int, Never>) -> Signal<(Int, Int), Never> in
						return { otherSignal in
							counter += 1
							return Signal.zip(signal, otherSignal)
						}
					}

					let producer = baseProducer.lift(transform)(otherProducer)
					expect(counter) == 0

					producer.start()
					expect(counter) == 1

					producer.start()
					expect(counter) == 2
				}

				it("should not miss any events") {
					let baseProducer = SignalProducer<Int, Never>([1, 2, 3])
					let otherProducer = SignalProducer<Int, Never>([4, 5, 6])

					let transform = { (signal: Signal<Int, Never>) -> (Signal<Int, Never>) -> Signal<Int, Never> in
						return { otherSignal in
							return Signal.zip(signal, otherSignal).map { $0.0 + $0.1 }
						}
					}

					let producer = baseProducer.lift(transform)(otherProducer)
					let result = producer.collect().single()

					expect(result?.value) == [5, 7, 9]
				}

				it("[left associative] should interrupt all intermediate signals when the upstream is terminated") {
					let baseProducer = SignalProducer<Int, Never>.empty

					var lastEvent: Signal<Int, Never>.Event?

					let disposable = baseProducer
						.liftLeft(binaryLiftTransform)(.empty)
						.start { event in
							lastEvent = event
						}

					expect(lastEvent).to(beNil())
					expect(isNeverEndingSignalDisposed) == false

					disposable.dispose()
					expect(lastEvent) == .interrupted
					expect(isNeverEndingSignalDisposed) == true
				}

				it("[right associative] should interrupt all intermediate signals when the upstream is terminated") {
					let baseProducer = SignalProducer<Int, Never>.empty

					var lastEvent: Signal<Int, Never>.Event?

					let disposable = baseProducer
						.liftRight(binaryLiftTransform)(.empty)
						.start { event in
							lastEvent = event
						}

					expect(lastEvent).to(beNil())
					expect(isNeverEndingSignalDisposed) == false

					disposable.dispose()
					expect(lastEvent) == .interrupted
					expect(isNeverEndingSignalDisposed) == true
				}
			}

			describe("over binary operators with signal") {
				it("should invoke transformation once per started signal") {
					let baseProducer = SignalProducer<Int, Never>([1, 2])
					let (otherSignal, otherSignalObserver) = Signal<Int, Never>.pipe()

					var counter = 0
					let transform = { (signal: Signal<Int, Never>) -> (Signal<Int, Never>) -> Signal<(Int, Int), Never> in
						return { otherSignal in
							counter += 1
							return Signal.zip(signal, otherSignal)
						}
					}

					let producer = baseProducer.lift(transform)(SignalProducer(otherSignal))
					expect(counter) == 0

					producer.start()
					otherSignalObserver.send(value: 1)
					expect(counter) == 1

					producer.start()
					otherSignalObserver.send(value: 2)
					expect(counter) == 2
				}

				it("should not miss any events") {
					let baseProducer = SignalProducer<Int, Never>([ 1, 2, 3 ])
					let (otherSignal, otherSignalObserver) = Signal<Int, Never>.pipe()

					let transform = { (signal: Signal<Int, Never>) -> (Signal<Int, Never>) -> Signal<Int, Never> in
						return { otherSignal in
							return Signal.zip(signal, otherSignal).map { $0.0 + $0.1 }
						}
					}

					let producer = baseProducer.lift(transform)(SignalProducer(otherSignal))
					var result: [Int] = []
					var completed: Bool = false

					producer.start { event in
						switch event {
						case .value(let value): result.append(value)
						case .completed: completed = true
						default: break
						}
					}

					otherSignalObserver.send(value: 4)
					expect(result) == [ 5 ]

					otherSignalObserver.send(value: 5)
					expect(result) == [ 5, 7 ]

					otherSignalObserver.send(value: 6)
					expect(result) == [ 5, 7, 9 ]
					expect(completed) == true
				}
			}
		}

		describe("combineLatest") {
			it("should emit the empty sentinel when no producer is given") {
				let producer = SignalProducer<String, Never>.combineLatest(
					EmptyCollection<SignalProducer<String, Never>>(),
					emptySentinel: ["empty"]
				)

				var values = [[String]]()
				var isCompleted = false

				producer.start { event in
					switch event {
					case let .value(value):
						values.append(value)
					case .completed:
						isCompleted = true
					case .interrupted, .failed:
						break
					}
				}

				expect(values) == [["empty"]]
				expect(isCompleted) == true
			}

			it("should combine the events to one array") {
				let (producerA, observerA) = SignalProducer<Int, Never>.pipe()
				let (producerB, observerB) = SignalProducer<Int, Never>.pipe()

				let producer = SignalProducer.combineLatest([producerA, producerB])

				var values = [[Int]]()
				producer.startWithValues { value in
					values.append(value)
				}

				observerA.send(value: 1)
				observerB.send(value: 2)
				observerA.send(value: 3)
				observerA.sendCompleted()
				observerB.sendCompleted()

				expect(values._bridgeToObjectiveC()) == [[1, 2], [3, 2]]
			}

			it("should start signal producers in order as defined") {
				var ids = [Int]()
				let createProducer = { (id: Int) -> SignalProducer<Int, Never> in
					return SignalProducer { observer, _ in
						ids.append(id)

						observer.send(value: id)
						observer.sendCompleted()
					}
				}

				let producerA = createProducer(1)
				let producerB = createProducer(2)

				let producer = SignalProducer.combineLatest([producerA, producerB])

				var values = [[Int]]()
				producer.startWithValues { value in
					values.append(value)
				}

				expect(ids) == [1, 2]
				expect(values._bridgeToObjectiveC()) == [[1, 2]]._bridgeToObjectiveC()
			}
			
			it("can deal with hundreds of producers") {
				let scheduler = QueueScheduler(qos: .default, name: "RACScheduler", targeting: nil)
				
				let producers = (0..<700).map { _ -> SignalProducer<Void, Never> in
					return SignalProducer(value: ())
				}
				
				waitUntil { done in
					SignalProducer
						.combineLatest(producers)
						.start(on: scheduler)
						.startWithCompleted {
							done()
					}
				}
			}
		}

		describe("zip") {
			it("should emit the empty sentinel when no producer is given") {
				let producer = SignalProducer<String, Never>.zip(
					EmptyCollection<SignalProducer<String, Never>>(),
					emptySentinel: ["empty"]
				)

				var values = [[String]]()
				var isCompleted = false

				producer.start { event in
					switch event {
					case let .value(value):
						values.append(value)
					case .completed:
						isCompleted = true
					case .interrupted, .failed:
						break
					}
				}

				expect(values) == [["empty"]]
				expect(isCompleted) == true
			}

			it("should zip the events to one array") {
				let producerA = SignalProducer<Int, Never>([ 1, 2 ])
				let producerB = SignalProducer<Int, Never>([ 3, 4 ])

				let producer = SignalProducer.zip([producerA, producerB])
				let result = producer.collect().single()

				expect(result?.value.map { $0._bridgeToObjectiveC() }) == [[1, 3], [2, 4]]._bridgeToObjectiveC()
			}

			it("should start signal producers in order as defined") {
				var ids = [Int]()
				let createProducer = { (id: Int) -> SignalProducer<Int, Never> in
					return SignalProducer { observer, _ in
						ids.append(id)

						observer.send(value: id)
						observer.sendCompleted()
					}
				}

				let producerA = createProducer(1)
				let producerB = createProducer(2)

				let producer = SignalProducer.zip([producerA, producerB])

				var values = [[Int]]()
				producer.startWithValues { value in
					values.append(value)
				}

				expect(ids) == [1, 2]
				expect(values._bridgeToObjectiveC()) == [[1, 2]]._bridgeToObjectiveC()
			}
			
			it("can deal with hundreds of producers") {
				let scheduler = TestScheduler()
				
				let producers = (0..<1024).map { _ -> SignalProducer<UInt, Never> in
					return SignalProducer(value: .max)
				}

				var values: [[UInt]] = []
				var isCompleted = false
				
				SignalProducer
					.zip(producers)
					.start(on: scheduler)
					.on(completed: { isCompleted = true }, value: { values.append($0) })
					.start()

				expect(values) == []
				expect(isCompleted) == false

				scheduler.advance()

				expect(values) == [Array(repeating: .max, count: 1024)]
				expect(isCompleted) == true
			}
		}

		describe("timer") {
			it("should send the current date at the given interval") {
				let scheduler = TestScheduler()
				let producer = SignalProducer.timer(interval: .seconds(1), on: scheduler, leeway: .seconds(0))

				let startDate = scheduler.currentDate
				let tick1 = startDate.addingTimeInterval(1)
				let tick2 = startDate.addingTimeInterval(2)
				let tick3 = startDate.addingTimeInterval(3)

				var dates: [Date] = []
				producer.startWithValues { dates.append($0) }

				scheduler.advance(by: .milliseconds(900))
				expect(dates) == []

				scheduler.advance(by: .seconds(1))
				expect(dates) == [tick1]

				scheduler.advance()
				expect(dates) == [tick1]

				scheduler.advance(by: .milliseconds(200))
				expect(dates) == [tick1, tick2]

				scheduler.advance(by: .seconds(1))
				expect(dates) == [tick1, tick2, tick3]
			}

			it("shouldn't overflow on a real scheduler") {
				let scheduler = QueueScheduler.makeForTesting()
				let producer = SignalProducer.timer(interval: .seconds(3), on: scheduler)
				producer
					.start()
					.dispose()
			}

			it("should dispose of the signal when disposed") {
				let scheduler = TestScheduler()
				let producer = SignalProducer.timer(interval: .seconds(1), on: scheduler, leeway: .seconds(0))
				var interrupted = false

				var isDisposed = false
				weak var weakSignal: Signal<Date, Never>?
				producer.startWithSignal { signal, disposable in
					weakSignal = signal
					scheduler.schedule {
						disposable.dispose()
					}
					signal.on(disposed: { isDisposed = true }).observeInterrupted { interrupted = true }
				}

				expect(weakSignal).to(beNil())
				expect(isDisposed) == false
				expect(interrupted) == false

				scheduler.run()
				expect(weakSignal).to(beNil())
				expect(isDisposed) == true
				expect(interrupted) == true
			}
		}

		describe("interval") {
			it("should send the next sequence value at the given interval") {
				let scheduler = TestScheduler()
				let producer = SignalProducer.interval("abc", interval: .seconds(1), on: scheduler)

				var isDisposed = false
				var values: [Character] = []
				producer
					.on(disposed: { isDisposed = true })
					.startWithValues { values.append($0) }

				scheduler.advance(by: .milliseconds(900))
				expect(values) == []

				scheduler.advance(by: .seconds(1))
				expect(values) == ["a"]

				scheduler.advance()
				expect(values) == ["a"]

				scheduler.advance(by: .milliseconds(200))
				expect(values) == ["a", "b"]

				scheduler.advance(by: .seconds(1))
				expect(values) == ["a", "b", "c"]

				scheduler.advance(by: .seconds(1))
				expect(isDisposed) == true
			}

			it("shouldn't overflow on a real scheduler") {
				let scheduler = QueueScheduler.makeForTesting()
				let testSequence = repeatElement(Character("a"), count: 1_000_000)
				let producer = SignalProducer.interval(testSequence, interval: .seconds(3), on: scheduler)
				producer
					.start()
					.dispose()
			}

			it("should dispose of the signal when disposed") {
				let scheduler = TestScheduler()
				let producer = SignalProducer.interval("abc", interval: .seconds(1), on: scheduler)
				var interrupted = false

				var isDisposed = false
				weak var weakSignal: Signal<Character, Never>?
				producer.startWithSignal { signal, disposable in
					weakSignal = signal
					scheduler.schedule {
						disposable.dispose()
					}
					signal.on(disposed: { isDisposed = true }).observeInterrupted { interrupted = true }
				}

				expect(weakSignal).to(beNil())
				expect(isDisposed) == false
				expect(interrupted) == false

				scheduler.run()
				expect(weakSignal).to(beNil())
				expect(isDisposed) == true
				expect(interrupted) == true
			}
		}

		describe("throttle while") {
			var scheduler: ImmediateScheduler!
			var shouldThrottle: MutableProperty<Bool>!
			var observer: Signal<Int, Never>.Observer!
			var producer: SignalProducer<Int, Never>!

			beforeEach {
				scheduler = ImmediateScheduler()
				shouldThrottle = MutableProperty(false)

				let (baseSignal, baseObserver) = Signal<Int, Never>.pipe()
				observer = baseObserver

				producer = SignalProducer(baseSignal)
					.throttle(while: shouldThrottle, on: scheduler)

				expect(producer).notTo(beNil())
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
			var producer: SignalProducer<Int, Never>!

			beforeEach {
				scheduler = TestScheduler()

				let (baseSignal, baseObserver) = Signal<Int, Never>.pipe()
				observer = baseObserver

				producer = SignalProducer(baseSignal)
					.debounce(0.1, on: scheduler)

				expect(producer).notTo(beNil())
			}

			it("should send values on the given scheduler once the interval has passed since the last value was sent") {
				var values: [Int] = []
				producer.startWithValues { value in
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

				producer.on(event: { event in
					switch event {
					case let .value(value):
						values.append(value)
					case .completed:
						completed = true
					default:
						break
					}
				}).start()

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

			context("starting the producer twice") {
				it("should deviver the same values") {
					var values1: [Int] = []
					var values2: [Int] = []
					producer.startWithValues { value in
						values1.append(value)
					}
					producer.startWithValues { value in
						values2.append(value)
					}

					expect(values1) == []
					expect(values2) == []

					observer.send(value: 1)
					observer.send(value: 2)

					scheduler.advance(by: .milliseconds(1500))
					expect(values1) == [ 2 ]
					expect(values2) == [ 2 ]

					observer.send(value: 3)
					scheduler.advance(by: .milliseconds(1500))
					expect(values1) == [ 2, 3 ]
					expect(values2) == [ 2, 3 ]

					observer.send(value: 4)
					observer.sendCompleted()
					scheduler.run()

					expect(values1) == [ 2, 3 ]
					expect(values2) == [ 2, 3 ]
				}
			}
		}

		describe("debounce without discarding the latest value when terminated") {
			var scheduler: TestScheduler!
			var observer: Signal<Int, Never>.Observer!
			var producer: SignalProducer<Int, Never>!

			beforeEach {
				scheduler = TestScheduler()

				let (baseSignal, baseObserver) = Signal<Int, Never>.pipe()
				observer = baseObserver

				producer = SignalProducer(baseSignal)
					.debounce(0.1, on: scheduler, discardWhenCompleted: false)

				expect(producer).notTo(beNil())
			}

			it("should send values on the given scheduler once the interval has passed since the last value was sent") {
				var values: [Int] = []
				producer.startWithValues { value in
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

				producer.on(event: { event in
					switch event {
					case let .value(value):
						values.append(value)
					case .completed:
						completed = true
					default:
						break
					}
				}).start()

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

				producer.on(event: { event in
					switch event {
					case .completed:
						completed = true
					default:
						break
					}
				}).start()

				observer.sendCompleted()
				expect(completed) == false
				scheduler.advance()
				expect(completed) == true
			}

			context("starting the producer twice") {
				it("should deviver the same values") {
					var values1: [Int] = []
					var values2: [Int] = []
					producer.startWithValues { value in
						values1.append(value)
					}
					producer.startWithValues { value in
						values2.append(value)
					}

					expect(values1) == []
					expect(values2) == []

					observer.send(value: 1)
					observer.send(value: 2)

					scheduler.advance(by: .milliseconds(1500))
					expect(values1) == [ 2 ]
					expect(values2) == [ 2 ]

					observer.send(value: 3)
					scheduler.advance(by: .milliseconds(1500))
					expect(values1) == [ 2, 3 ]
					expect(values2) == [ 2, 3 ]

					observer.send(value: 4)
					observer.sendCompleted()
					scheduler.run()

					expect(values1) == [ 2, 3, 4 ]
					expect(values2) == [ 2, 3, 4 ]
				}
			}
		}

		describe("on") {
			it("should attach event handlers to each started signal") {
				let (baseProducer, observer) = SignalProducer<Int, TestError>.pipe()

				var starting = 0
				var started = 0
				var event = 0
				var value = 0
				var completed = 0
				var terminated = 0

				let producer = baseProducer
					.on(starting: {
						starting += 1
					}, started: {
						started += 1
					}, event: { _ in
						event += 1
					}, completed: {
						completed += 1
					}, terminated: {
						terminated += 1
					}, value: { _ in
						value += 1
					})

				producer.start()
				expect(starting) == 1
				expect(started) == 1

				producer.start()
				expect(starting) == 2
				expect(started) == 2

				observer.send(value: 1)
				expect(event) == 2
				expect(value) == 2

				observer.sendCompleted()
				expect(event) == 4
				expect(completed) == 2
				expect(terminated) == 2
			}

			it("should attach event handlers for disposal") {
				let (baseProducer, observer) = SignalProducer<Int, TestError>.pipe()

				withExtendedLifetime(observer) {
					var disposed: Bool = false

					let producer = baseProducer
						.on(disposed: { disposed = true })

					let disposable = producer.start()

					expect(disposed) == false
					disposable.dispose()
					expect(disposed) == true
				}
			}

			it("should invoke the `started` action of the inner producer first") {
				let (baseProducer, _) = SignalProducer<Int, TestError>.pipe()

				var numbers = [Int]()

				_ = baseProducer
					.on(started: { numbers.append(1) })
					.on(started: { numbers.append(2) })
					.on(started: { numbers.append(3) })
					.start()

				expect(numbers) == [1, 2, 3]
			}

			it("should invoke the `starting` action of the outer producer first") {
				let (baseProducer, _) = SignalProducer<Int, TestError>.pipe()

				var numbers = [Int]()

				_ = baseProducer
					.on(starting: { numbers.append(1) })
					.on(starting: { numbers.append(2) })
					.on(starting: { numbers.append(3) })
					.start()

				expect(numbers) == [3, 2, 1]
			}
		}

		describe("startOn") {
			it("should invoke effects on the given scheduler") {
				let scheduler = TestScheduler()
				var invoked = false

				let producer = SignalProducer<Int, Never> { _, _ in
					invoked = true
				}

				producer.start(on: scheduler).start()
				expect(invoked) == false

				scheduler.advance()
				expect(invoked) == true
			}

			it("should forward events on their original scheduler") {
				let startScheduler = TestScheduler()
				let testScheduler = TestScheduler()

				let producer = SignalProducer.timer(interval: .seconds(2), on: testScheduler, leeway: .seconds(0))

				var value: Date?
				producer.start(on: startScheduler).startWithValues { value = $0 }

				startScheduler.advance(by: .seconds(2))
				expect(value).to(beNil())

				testScheduler.advance(by: .seconds(1))
				expect(value).to(beNil())

				testScheduler.advance(by: .seconds(1))
				expect(value) == testScheduler.currentDate
			}
		}

		describe("flatMapError") {
			it("should invoke the handler and start new producer for an error") {
				let (baseProducer, baseObserver) = SignalProducer<Int, TestError>.pipe()

				var values: [Int] = []
				var completed = false

				baseProducer
					.flatMapError { (error: TestError) -> SignalProducer<Int, TestError> in
						expect(error) == TestError.default
						expect(values) == [1]

						return .init(value: 2)
					}
					.start { event in
						switch event {
						case let .value(value):
							values.append(value)
						case .completed:
							completed = true
						default:
							break
						}
					}

				baseObserver.send(value: 1)
				baseObserver.send(error: .default)

				expect(values) == [1, 2]
				expect(completed) == true
			}

			it("should interrupt the replaced producer on disposal") {
				let (baseProducer, baseObserver) = SignalProducer<Int, TestError>.pipe()

				var (disposed, interrupted) = (false, false)
				let disposable = baseProducer
					.flatMapError { (_: TestError) -> SignalProducer<Int, TestError> in
						return SignalProducer<Int, TestError> { _, lifetime in
							lifetime.observeEnded { disposed = true }
						}
					}
					.startWithInterrupted { interrupted = true }

				baseObserver.send(error: .default)
				disposable.dispose()

				expect(interrupted) == true
				expect(disposed) == true
			}

			it("should be able to fallback to SignalProducer for contextual lookups") {
				_ = SignalProducer<Int, TestError>.empty
					.flatMapError { _ in .init(value: 0) }
			}
		}

		describe("flatten") {
			describe("FlattenStrategy.concat") {
				describe("sequencing") {
					var completePrevious: (() -> Void)!
					var sendSubsequent: (() -> Void)!
					var completeOuter: (() -> Void)!

					var subsequentStarted = false

					beforeEach {
						let (outerProducer, outerObserver) = SignalProducer<SignalProducer<Int, Never>, Never>.pipe()
						let (previousProducer, previousObserver) = SignalProducer<Int, Never>.pipe()

						subsequentStarted = false
						let subsequentProducer = SignalProducer<Int, Never> { _, _ in
							subsequentStarted = true
						}

						completePrevious = { previousObserver.sendCompleted() }
						sendSubsequent = { outerObserver.send(value: subsequentProducer) }
						completeOuter = { outerObserver.sendCompleted() }

						outerProducer.flatten(.concat).start()
						outerObserver.send(value: previousProducer)
					}

					it("should immediately start subsequent inner producer if previous inner producer has already completed") {
						completePrevious()
						sendSubsequent()
						expect(subsequentStarted) == true
					}

					context("with queued producers") {
						beforeEach {
							// Place the subsequent producer into `concat`'s queue.
							sendSubsequent()
							expect(subsequentStarted) == false
						}

						it("should start subsequent inner producer upon completion of previous inner producer") {
							completePrevious()
							expect(subsequentStarted) == true
						}

						it("should start subsequent inner producer upon completion of previous inner producer and completion of outer producer") {
							completeOuter()
							completePrevious()
							expect(subsequentStarted) == true
						}
					}
				}

				it("should forward an error from an inner producer") {
					let errorProducer = SignalProducer<Int, TestError>(error: TestError.default)
					let outerProducer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: errorProducer)

					var error: TestError?
					(outerProducer.flatten(.concat)).startWithFailed { e in
						error = e
					}

					expect(error) == TestError.default
				}

				it("should forward an error from the outer producer") {
					let (outerProducer, outerObserver) = SignalProducer<SignalProducer<Int, TestError>, TestError>.pipe()

					var error: TestError?
					outerProducer.flatten(.concat).startWithFailed { e in
						error = e
					}

					outerObserver.send(error: TestError.default)
					expect(error) == TestError.default
				}

				it("should not overflow the stack if inner producers complete immediately") {
					typealias Inner = SignalProducer<(), Never>

					let depth = 10000
					let inner: Inner = SignalProducer(value: ())
					let (first, firstObserver) = SignalProducer<(), Never>.pipe()
					let (outer, outerObserver) = SignalProducer<Inner, Never>.pipe()

					var value = 0
					outer
						.flatten(.concat)
						.startWithValues { _ in
							value += 1
						}

					outerObserver.send(value: first)
					for _ in 0..<depth { outerObserver.send(value: inner) }
					firstObserver.sendCompleted()
					expect(value) == depth
				}

				describe("completion") {
					var completeOuter: (() -> Void)!
					var completeInner: (() -> Void)!

					var completed = false

					beforeEach {
						let (outerProducer, outerObserver) = SignalProducer<SignalProducer<Int, Never>, Never>.pipe()
						let (innerProducer, innerObserver) = SignalProducer<Int, Never>.pipe()

						completeOuter = { outerObserver.sendCompleted() }
						completeInner = { innerObserver.sendCompleted() }

						completed = false
						outerProducer.flatten(.concat).startWithCompleted {
							completed = true
						}

						outerObserver.send(value: innerProducer)
					}

					it("should complete when inner producers complete, then outer producer completes") {
						completeInner()
						expect(completed) == false

						completeOuter()
						expect(completed) == true
					}

					it("should complete when outer producers completes, then inner producers complete") {
						completeOuter()
						expect(completed) == false

						completeInner()
						expect(completed) == true
					}
				}
			}

			describe("FlattenStrategy.merge") {
				describe("behavior") {
					var completeA: (() -> Void)!
					var sendA: (() -> Void)!
					var completeB: (() -> Void)!
					var sendB: (() -> Void)!

					var outerObserver: Signal<SignalProducer<Int, Never>, Never>.Observer!
					var outerCompleted = false

					var recv = [Int]()

					beforeEach {
						let (outerProducer, _outerObserver) = SignalProducer<SignalProducer<Int, Never>, Never>.pipe()
						outerObserver = _outerObserver

						let (producerA, observerA) = SignalProducer<Int, Never>.pipe()
						let (producerB, observerB) = SignalProducer<Int, Never>.pipe()

						completeA = { observerA.sendCompleted() }
						completeB = { observerB.sendCompleted() }

						var a = 0
						sendA = { observerA.send(value: a); a += 1 }

						var b = 100
						sendB = { observerB.send(value: b); b += 1 }

						outerProducer.flatten(.merge).start { event in
							switch event {
							case let .value(i):
								recv.append(i)
							case .completed:
								outerCompleted = true
							default:
								break
							}
						}

						outerObserver.send(value: producerA)
						outerObserver.send(value: producerB)

						outerObserver.sendCompleted()
					}

					afterEach {
						(completeA, completeB) = (nil, nil)
						(sendA, sendB) = (nil, nil)
						outerObserver = nil

						outerCompleted = false
						recv = []
					}

					it("should forward values from any inner signals") {
						sendA()
						sendA()
						sendB()
						sendA()
						sendB()
						expect(recv) == [0, 1, 100, 2, 101]
					}

					it("should complete when all signals have completed") {
						completeA()
						expect(outerCompleted) == false
						completeB()
						expect(outerCompleted) == true
					}
				}

				describe("error handling") {
					it("should forward an error from an inner signal") {
						let errorProducer = SignalProducer<Int, TestError>(error: TestError.default)
						let outerProducer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: errorProducer)

						var error: TestError?
						outerProducer.flatten(.merge).startWithFailed { e in
							error = e
						}
						expect(error) == TestError.default
					}

					it("should forward an error from the outer signal") {
						let (outerProducer, outerObserver) = SignalProducer<SignalProducer<Int, TestError>, TestError>.pipe()

						var error: TestError?
						outerProducer.flatten(.merge).startWithFailed { e in
							error = e
						}

						outerObserver.send(error: TestError.default)
						expect(error) == TestError.default
					}
				}
			}

			describe("FlattenStrategy.latest") {
				it("should forward values from the latest inner signal") {
					let (outer, outerObserver) = SignalProducer<SignalProducer<Int, TestError>, TestError>.pipe()
					let (firstInner, firstInnerObserver) = SignalProducer<Int, TestError>.pipe()
					let (secondInner, secondInnerObserver) = SignalProducer<Int, TestError>.pipe()

					var receivedValues: [Int] = []
					var errored = false
					var completed = false

					outer.flatten(.latest).start { event in
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

					outerObserver.send(value: SignalProducer(value: 0))
					outerObserver.send(value: firstInner)
					firstInnerObserver.send(value: 1)
					outerObserver.send(value: secondInner)
					secondInnerObserver.send(value: 2)
					outerObserver.sendCompleted()

					expect(receivedValues) == [ 0, 1, 2 ]
					expect(errored) == false
					expect(completed) == false

					firstInnerObserver.send(value: 3)
					firstInnerObserver.sendCompleted()
					secondInnerObserver.send(value: 4)
					secondInnerObserver.sendCompleted()

					expect(receivedValues) == [ 0, 1, 2, 4 ]
					expect(errored) == false
					expect(completed) == true
				}

				it("should forward an error from an inner signal") {
					let inner = SignalProducer<Int, TestError>(error: .default)
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: inner)

					let result = outer.flatten(.latest).first()
					expect(result?.error) == TestError.default
				}

				it("should forward an error from the outer signal") {
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(error: .default)

					let result = outer.flatten(.latest).first()
					expect(result?.error) == TestError.default
				}

				it("should complete when the original and latest signals have completed") {
					let inner = SignalProducer<Int, TestError>.empty
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: inner)

					var completed = false
					outer.flatten(.latest).startWithCompleted {
						completed = true
					}

					expect(completed) == true
				}

				it("should complete when the outer signal completes before sending any signals") {
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>.empty

					var completed = false
					outer.flatten(.latest).startWithCompleted {
						completed = true
					}

					expect(completed) == true
				}

				it("should not deadlock") {
					let producer = SignalProducer<Int, Never>(value: 1)
						.flatMap(.latest) { _ in SignalProducer(value: 10) }

					let result = producer.take(first: 1).last()
					expect(result?.value) == 10
				}
			}

			describe("FlattenStrategy.race") {
				it("should forward values from the first inner producer to send an event") {
					let (outer, outerObserver) = SignalProducer<SignalProducer<Int, TestError>, TestError>.pipe()
					let (firstInner, firstInnerObserver) = SignalProducer<Int, TestError>.pipe()
					let (secondInner, secondInnerObserver) = SignalProducer<Int, TestError>.pipe()

					var receivedValues: [Int] = []
					var errored = false
					var completed = false

					outer.flatten(.race).start { event in
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

					outerObserver.send(value: firstInner)
					outerObserver.send(value: secondInner)
					firstInnerObserver.send(value: 1)
					secondInnerObserver.send(value: 2)
					outerObserver.sendCompleted()

					expect(receivedValues) == [ 1 ]
					expect(errored) == false
					expect(completed) == false

					secondInnerObserver.send(value: 3)
					secondInnerObserver.sendCompleted()

					expect(receivedValues) == [ 1 ]
					expect(errored) == false
					expect(completed) == false

					firstInnerObserver.send(value: 4)
					firstInnerObserver.sendCompleted()

					expect(receivedValues) == [ 1, 4 ]
					expect(errored) == false
					expect(completed) == true
				}

				it("should forward an error from the first inner producer to send an error") {
					let inner = SignalProducer<Int, TestError>(error: .default)
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: inner)

					let result = outer.flatten(.race).first()
					expect(result?.error) == TestError.default
				}

				it("should forward an error from the outer producer") {
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(error: .default)

					let result = outer.flatten(.race).first()
					expect(result?.error) == TestError.default
				}

				it("should complete when the 'outer producer' and 'first inner producer to send an event' have completed") {
					let inner = SignalProducer<Int, TestError>.empty
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: inner)

					var completed = false
					outer.flatten(.race).startWithCompleted {
						completed = true
					}

					expect(completed) == true
				}

				it("should complete when the outer producer completes before sending any inner producers") {
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>.empty

					var completed = false
					outer.flatten(.race).startWithCompleted {
						completed = true
					}

					expect(completed) == true
				}

				it("should not complete when the outer producer completes after sending an inner producer but it doesn't send an event") {
					let inner = SignalProducer<Int, TestError>.never
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: inner)

					var completed = false
					outer.flatten(.race).startWithCompleted {
						completed = true
					}

					expect(completed) == false
				}

				it("should not deadlock") {
					let producer = SignalProducer<Int, Never>(value: 1)
						.flatMap(.race) { _ in SignalProducer(value: 10) }

					let result = producer.take(first: 1).last()
					expect(result?.value) == 10
				}
			}

			describe("FlattenStrategy.throttle") {
				it("should forward values from the first and third inner producer to send an event") {
					let (outer, outerObserver) = SignalProducer<SignalProducer<Int, TestError>, TestError>.pipe()
					let (firstInner, firstInnerObserver) = SignalProducer<Int, TestError>.pipe()
					let (secondInner, secondInnerObserver) = SignalProducer<Int, TestError>.pipe()
					let (thirdInner, thirdInnerObserver) = SignalProducer<Int, TestError>.pipe()

					var receivedValues: [Int] = []
					var errored = false
					var completed = false

					outer.flatten(.throttle).start { event in
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

					outerObserver.send(value: firstInner)
					outerObserver.send(value: secondInner)

					firstInnerObserver.send(value: 1)
					secondInnerObserver.send(value: 2)

					expect(receivedValues) == [ 1 ]
					expect(errored) == false
					expect(completed) == false

					secondInnerObserver.send(value: 3)
					secondInnerObserver.sendCompleted()

					expect(receivedValues) == [ 1 ]
					expect(errored) == false
					expect(completed) == false

					firstInnerObserver.sendCompleted()

					expect(receivedValues) == [ 1 ]
					expect(errored) == false
					expect(completed) == false

					outerObserver.send(value: thirdInner)
					thirdInnerObserver.send(value: 4)

					// NOTE:
					// `4` will be observed because `firstInner` is completed then `thirdInner` is emitted,
					// which is also considered as "first" producer.
					expect(receivedValues) == [ 1, 4 ]
					expect(errored) == false
					expect(completed) == false

					outerObserver.sendCompleted()

					expect(receivedValues) == [ 1, 4 ]
					expect(errored) == false
					expect(completed) == false

					thirdInnerObserver.sendCompleted()

					expect(receivedValues) == [ 1, 4 ]
					expect(errored) == false
					expect(completed) == true
				}

				it("should forward an error from the first inner producer to send an error") {
					let inner = SignalProducer<Int, TestError>(error: .default)
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: inner)

					let result = outer.flatten(.throttle).first()
					expect(result?.error) == TestError.default
				}

				it("should forward an error from the outer producer") {
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(error: .default)

					let result = outer.flatten(.throttle).first()
					expect(result?.error) == TestError.default
				}

				it("should complete when the 'outer producer' and 'first inner producer to send an event' have completed") {
					let inner = SignalProducer<Int, TestError>.empty
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: inner)

					var completed = false
					outer.flatten(.throttle).startWithCompleted {
						completed = true
					}

					expect(completed) == true
				}

				it("should complete when the outer producer completes before sending any inner producers") {
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>.empty

					var completed = false
					outer.flatten(.throttle).startWithCompleted {
						completed = true
					}

					expect(completed) == true
				}

				it("should not complete when the outer producer completes after sending an inner producer but it doesn't send an event") {
					let inner = SignalProducer<Int, TestError>.never
					let outer = SignalProducer<SignalProducer<Int, TestError>, TestError>(value: inner)

					var completed = false
					outer.flatten(.throttle).startWithCompleted {
						completed = true
					}

					expect(completed) == false
				}

				it("should not deadlock") {
					let producer = SignalProducer<Int, Never>(value: 1)
						.flatMap(.throttle) { _ in SignalProducer(value: 10) }

					let result = producer.take(first: 1).last()
					expect(result?.value) == 10
				}
			}

			describe("interruption") {
				var innerObserver: Signal<(), Never>.Observer!
				var outerObserver: Signal<SignalProducer<(), Never>, Never>.Observer!
				var execute: ((FlattenStrategy) -> Void)!

				var interrupted = false
				var completed = false

				beforeEach {
					let (innerProducer, incomingInnerObserver) = SignalProducer<(), Never>.pipe()
					let (outerProducer, incomingOuterObserver) = SignalProducer<SignalProducer<(), Never>, Never>.pipe()

					innerObserver = incomingInnerObserver
					outerObserver = incomingOuterObserver

					execute = { strategy in
						interrupted = false
						completed = false

						outerProducer
							.flatten(strategy)
							.start { event in
								switch event {
								case .interrupted:
									interrupted = true
								case .completed:
									completed = true
								default:
									break
								}
							}
					}

					incomingOuterObserver.send(value: innerProducer)
				}

				describe("Concat") {
					it("should drop interrupted from an inner producer") {
						execute(.concat)

						innerObserver.sendInterrupted()
						expect(interrupted) == false
						expect(completed) == false

						outerObserver.sendCompleted()
						expect(completed) == true
					}

					it("should forward interrupted from the outer producer") {
						execute(.concat)
						outerObserver.sendInterrupted()
						expect(interrupted) == true
					}
				}

				describe("Latest") {
					it("should drop interrupted from an inner producer") {
						execute(.latest)

						innerObserver.sendInterrupted()
						expect(interrupted) == false
						expect(completed) == false

						outerObserver.sendCompleted()
						expect(completed) == true
					}

					it("should forward interrupted from the outer producer") {
						execute(.latest)
						outerObserver.sendInterrupted()
						expect(interrupted) == true
					}
				}

				describe("Merge") {
					it("should drop interrupted from an inner producer") {
						execute(.merge)

						innerObserver.sendInterrupted()
						expect(interrupted) == false
						expect(completed) == false

						outerObserver.sendCompleted()
						expect(completed) == true
					}

					it("should forward interrupted from the outer producer") {
						execute(.merge)
						outerObserver.sendInterrupted()
						expect(interrupted) == true
					}
				}
			}

			describe("disposal") {
				var completeOuter: (() -> Void)!
				var disposeOuter: (() -> Void)!
				var execute: ((FlattenStrategy) -> Void)!

				var innerDisposable = AnyDisposable()
				var isInnerInterrupted = false
				var isInnerDisposed = false
				var interrupted = false

				beforeEach {
					execute = { strategy in
						let (outerProducer, outerObserver) = SignalProducer<SignalProducer<Int, Never>, Never>.pipe()

						innerDisposable = AnyDisposable()
						isInnerInterrupted = false
						isInnerDisposed = false
						let innerProducer = SignalProducer<Int, Never> { $1 += innerDisposable }
							.on(interrupted: { isInnerInterrupted = true }, disposed: { isInnerDisposed = true })

						interrupted = false
						let outerDisposable = outerProducer.flatten(strategy).startWithInterrupted {
							interrupted = true
						}

						completeOuter = outerObserver.sendCompleted
						disposeOuter = outerDisposable.dispose

						outerObserver.send(value: innerProducer)
					}
				}

				describe("Concat") {
					it("should cancel inner work when disposed before the outer producer completes") {
						execute(.concat)

						expect(innerDisposable.isDisposed) == false
						expect(interrupted) == false
						expect(isInnerInterrupted) == false
						expect(isInnerDisposed) == false

						disposeOuter()

						expect(innerDisposable.isDisposed) == true
						expect(interrupted) == true
						expect(isInnerInterrupted) == true
						expect(isInnerDisposed) == true
					}

					it("should cancel inner work when disposed after the outer producer completes") {
						execute(.concat)

						completeOuter()

						expect(innerDisposable.isDisposed) == false
						expect(interrupted) == false
						expect(isInnerInterrupted) == false
						expect(isInnerDisposed) == false

						disposeOuter()

						expect(innerDisposable.isDisposed) == true
						expect(interrupted) == true
						expect(isInnerInterrupted) == true
						expect(isInnerDisposed) == true
					}
				}

				describe("Latest") {
					it("should cancel inner work when disposed before the outer producer completes") {
						execute(.latest)

						expect(innerDisposable.isDisposed) == false
						expect(interrupted) == false
						expect(isInnerInterrupted) == false
						expect(isInnerDisposed) == false

						disposeOuter()

						expect(innerDisposable.isDisposed) == true
						expect(interrupted) == true
						expect(isInnerInterrupted) == true
						expect(isInnerDisposed) == true
					}

					it("should cancel inner work when disposed after the outer producer completes") {
						execute(.latest)

						completeOuter()

						expect(innerDisposable.isDisposed) == false
						expect(interrupted) == false
						expect(isInnerInterrupted) == false
						expect(isInnerDisposed) == false

						disposeOuter()

						expect(innerDisposable.isDisposed) == true
						expect(interrupted) == true
						expect(isInnerInterrupted) == true
						expect(isInnerDisposed) == true
					}
				}

				describe("Merge") {
					it("should cancel inner work when disposed before the outer producer completes") {
						execute(.merge)

						expect(innerDisposable.isDisposed) == false
						expect(interrupted) == false
						expect(isInnerInterrupted) == false
						expect(isInnerDisposed) == false

						disposeOuter()

						expect(innerDisposable.isDisposed) == true
						expect(interrupted) == true
						expect(isInnerInterrupted) == true
						expect(isInnerDisposed) == true

					}

					it("should cancel inner work when disposed after the outer producer completes") {
						execute(.merge)

						completeOuter()

						expect(innerDisposable.isDisposed) == false
						expect(interrupted) == false
						expect(isInnerInterrupted) == false
						expect(isInnerDisposed) == false

						disposeOuter()

						expect(innerDisposable.isDisposed) == true
						expect(interrupted) == true
						expect(isInnerInterrupted) == true
						expect(isInnerDisposed) == true
					}
				}
			}
		}

		describe("times") {
			it("should start a signal N times upon completion") {
				let original = SignalProducer<Int, Never>([ 1, 2, 3 ])
				let producer = original.repeat(3)

				let result = producer.collect().single()
				expect(result?.value) == [ 1, 2, 3, 1, 2, 3, 1, 2, 3 ]
			}

			it("should produce an equivalent signal producer if count is 1") {
				let original = SignalProducer<Int, Never>(value: 1)
				let producer = original.repeat(1)

				let result = producer.collect().single()
				expect(result?.value) == [ 1 ]
			}

			it("should produce an empty signal if count is 0") {
				let original = SignalProducer<Int, Never>(value: 1)
				let producer = original.repeat(0)

				let result = producer.first()
				expect(result).to(beNil())
			}

			it("should not repeat upon error") {
				let results: [Result<Int, TestError>] = [
					.success(1),
					.success(2),
					.failure(.default),
				]

				let original = SignalProducer.attemptWithResults(results)
				let producer = original.repeat(3)

				let events = producer
					.materialize()
					.collect()
					.single()
				let result = events?.value

				let expectedEvents: [Signal<Int, TestError>.Event] = [
					.value(1),
					.value(2),
					.failed(.default),
				]

				// TODO: if let result = result where result.count == expectedEvents.count
				if result?.count != expectedEvents.count {
					fail("Invalid result: \(String(describing: result))")
				} else {
					// Can't test for equality because Array<T> is not Equatable,
					// and neither is Signal<Value, Error>.Event.
					expect(result![0] == expectedEvents[0]) == true
					expect(result![1] == expectedEvents[1]) == true
					expect(result![2] == expectedEvents[2]) == true
				}
			}

			it("should evaluate lazily") {
				let original = SignalProducer<Int, Never>(value: 1)
				let producer = original.repeat(Int.max)

				let result = producer.take(first: 1).single()
				expect(result?.value) == 1
			}
		}

		describe("retry") {
			it("should start a signal N times upon error") {
				let results: [Result<Int, TestError>] = [
					.failure(.error1),
					.failure(.error2),
					.success(1),
				]

				let original = SignalProducer.attemptWithResults(results)
				let producer = original.retry(upTo: 2)

				let result = producer.single()

				expect(result?.value) == 1
			}

			it("should forward errors that occur after all retries") {
				let results: [Result<Int, TestError>] = [
					.failure(.default),
					.failure(.error1),
					.failure(.error2),
				]

				let original = SignalProducer.attemptWithResults(results)
				let producer = original.retry(upTo: 2)

				let result = producer.single()

				expect(result?.error) == TestError.error2
			}

			it("should not retry upon completion") {
				let results: [Result<Int, TestError>] = [
					.success(1),
					.success(2),
					.success(3),
				]

				let original = SignalProducer.attemptWithResults(results)
				let producer = original.retry(upTo: 2)

				let result = producer.single()
				expect(result?.value) == 1
			}
			
			context("with interval") {
				
				it("should send values at the given interval") {
					
					let scheduler = TestScheduler()
					var count = 0

					let original = SignalProducer<Int, TestError> { observer, _ in
						
						if count < 2 {
							scheduler.schedule { observer.send(value: count) }
							scheduler.schedule { observer.send(error: .default) }
						} else {
							scheduler.schedule { observer.sendCompleted() }
						}
						count += 1
					}

					var values: [Int] = []
					var completed = false
					
					original.retry(upTo: Int.max, interval: 1, on: scheduler)
						.start { event in
							switch event {
							case let .value(value):
								values.append(value)
							case .completed:
								completed = true
							default:
								break
							}
					}
					
					expect(count) == 1
					expect(values) == []
					
					scheduler.advance()
					expect(count) == 1
					expect(values) == [1]
					expect(completed) == false
					
					scheduler.advance(by: .seconds(1))
					expect(count) == 2
					expect(values) == [1, 2]
					expect(completed) == false
					
					scheduler.advance(by: .seconds(1))
					expect(count) == 3
					expect(values) == [1, 2]
					expect(completed) == true
				}
				
				it("should not send values after hitting the limitation") {
					
					let scheduler = TestScheduler()
					var count = 0
					var values: [Int] = []
					var errors: [TestError] = []
					
					let original = SignalProducer<Int, TestError> { observer, _ in
						scheduler.schedule { observer.send(value: count) }
						scheduler.schedule { observer.send(error: .default) }
						count += 1
					}
					
					original.retry(upTo: 2, interval: 1, on: scheduler)
						.start { event in
							switch event {
							case let .value(value):
								values.append(value)
							case let .failed(error):
								errors.append(error)
							default:
								break
							}
					}
					
					scheduler.advance()
					expect(count) == 1
					expect(values) == [1]
					expect(errors) == []
					
					scheduler.advance(by: .seconds(1))
					expect(count) == 2
					expect(values) == [1, 2]
					expect(errors) == []
					
					scheduler.advance(by: .seconds(1))
					expect(count) == 3
					expect(values) == [1, 2, 3]
					expect(errors) == [.default]
					
					scheduler.advance(by: .seconds(1))
					expect(count) == 3
					expect(values) == [1, 2, 3]
					expect(errors) == [.default]
				}

				it("should not share retry counter across produced signals") {
					let scheduler = TestScheduler()
					var failuresReceived = 0
					
					let original = SignalProducer<Int, TestError> { observer, _ in
						scheduler.schedule { observer.send(error: .default) }
					}
					let retryDelay: DispatchTimeInterval = .seconds(1)
					let retriable = original
						.retry(upTo: 1, interval: retryDelay.timeInterval, on: scheduler)
						.on(failed: { _ in failuresReceived += 1 })
					
					// 1st produced signal
					retriable.start()
					
					scheduler.advance()
					expect(failuresReceived) == 0

					scheduler.advance(by: retryDelay)
					expect(failuresReceived) == 1

					// 2nd produced signal
					retriable.start()
					
					scheduler.advance()
					// Shared retry counter had caused the second produced signal not to defer the failed event as expected.
					// (https://github.com/ReactiveCocoa/ReactiveSwift/pull/829)
					// Assert that we did not receive the 2th final failure at this point, which should always be delayed until
					// at least `retryDelay` has elapsed.
					expect(failuresReceived) == 1

					scheduler.advance(by: retryDelay)
					expect(failuresReceived) == 2
				}
			}
			
		}

		describe("then") {
			it("should start the subsequent producer after the completion of the original") {
				let (original, observer) = SignalProducer<Int, Never>.pipe()

				var subsequentStarted = false
				let subsequent = SignalProducer<Int, Never> { _, _ in
					subsequentStarted = true
				}

				let producer = original.then(subsequent)
				producer.start()
				expect(subsequentStarted) == false

				observer.sendCompleted()
				expect(subsequentStarted) == true
			}

			it("should forward errors from the original producer") {
				let original = SignalProducer<Int, TestError>(error: .default)
				let subsequent = SignalProducer<Int, TestError>.empty

				let result = original.then(subsequent).first()
				expect(result?.error) == TestError.default
			}

			it("should forward errors from the subsequent producer") {
				let original = SignalProducer<Int, TestError>.empty
				let subsequent = SignalProducer<Int, TestError>(error: .default)

				let result = original.then(subsequent).first()
				expect(result?.error) == TestError.default
			}

			it("should forward interruptions from the original producer") {
				let (original, observer) = SignalProducer<Int, Never>.pipe()

				var subsequentStarted = false
				let subsequent = SignalProducer<Int, Never> { _, _ in
					subsequentStarted = true
				}

				var interrupted = false
				let producer = original.then(subsequent)
				producer.startWithInterrupted {
					interrupted = true
				}
				expect(subsequentStarted) == false

				observer.sendInterrupted()
				expect(interrupted) == true
			}

			it("should complete when both inputs have completed") {
				let (original, originalObserver) = SignalProducer<Int, Never>.pipe()
				let (subsequent, subsequentObserver) = SignalProducer<String, Never>.pipe()

				let producer = original.then(subsequent)

				var completed = false
				producer.startWithCompleted {
					completed = true
				}

				originalObserver.sendCompleted()
				expect(completed) == false

				subsequentObserver.sendCompleted()
				expect(completed) == true
			}

			it("works with Never and TestError") {
				let producer: SignalProducer<Int, TestError> = SignalProducer<Int, Never>.empty
					.then(SignalProducer<Int, TestError>.empty)

				_ = producer
			}

			it("works with TestError and Never") {
				let producer: SignalProducer<Int, TestError> = SignalProducer<Int, TestError>.empty
					.then(SignalProducer<Int, Never>.empty)

				_ = producer
			}

			it("works with Never and Never") {
				let producer: SignalProducer<Int, Never> = SignalProducer<Int, Never>.empty
					.then(SignalProducer<Int, Never>.empty)

				_ = producer
			}

			it("should not be ambiguous") {
				let a = SignalProducer<Int, Never>.empty.then(SignalProducer<Int, Never>.empty)
				expect(type(of: a)) == SignalProducer<Int, Never>.self

				let b = SignalProducer<Int, Never>.empty.then(SignalProducer<Double, Never>.empty)
				expect(type(of: b)) == SignalProducer<Double, Never>.self

				let c = SignalProducer<Int, Never>.empty.then(SignalProducer<Int, TestError>.empty)
				expect(type(of: c)) == SignalProducer<Int, TestError>.self

				let d = SignalProducer<Int, Never>.empty.then(SignalProducer<Double, TestError>.empty)
				expect(type(of: d)) == SignalProducer<Double, TestError>.self

				let e = SignalProducer<Int, TestError>.empty.then(SignalProducer<Int, TestError>.empty)
				expect(type(of: e)) == SignalProducer<Int, TestError>.self

				let f = SignalProducer<Int, TestError>.empty.then(SignalProducer<Int, Never>.empty)
				expect(type(of: f)) == SignalProducer<Int, TestError>.self

				let g = SignalProducer<Int, TestError>.empty.then(SignalProducer<Double, TestError>.empty)
				expect(type(of: g)) == SignalProducer<Double, TestError>.self

				let h = SignalProducer<Int, TestError>.empty.then(SignalProducer<Double, Never>.empty)
				expect(type(of: h)) == SignalProducer<Double, TestError>.self
			}

			it("should be able to fallback to SignalProducer for contextual lookups without explicit value and error type parameters, given an upstream of arbitrary error type") {
				_ = SignalProducer<Int, TestError>.empty
					.then(.empty)
			}

			it("should be able to fallback to SignalProducer for contextual lookups with explicit value and error type parameters, given an upstream of arbitary error type") {
				_ = SignalProducer<Int, TestError>.empty
					.then(.init(result: Result<String, TestError>(success: "")))
			}

			it("should be able to fallback to SignalProducer for contextual lookups without explicit error type parameter") {
				_ = SignalProducer<Int, TestError>.empty
					.then(.init(value: ""))
			}

			it("should be able to fallback to SignalProducer for contextual lookups without explicit value and error type parameters, given a Never upstream") {
				_ = SignalProducer<Int, Never>.empty
					.then(.empty)
			}

			it("should be able to fallback to SignalProducer for contextual lookups without explicit error type parameter") {
				_ = SignalProducer<Int, Never>.empty
					.then(.init(value: ""))
			}

			it("should be able to fallback to SignalProducer for contextual lookups with explicit value and error type parameters, given a Never upstream") {
				_ = SignalProducer<Int, Never>.empty
					.then(.init(result: Result<String, TestError>(success: "")))
			}
		}

		describe("first") {
			it("should start a signal then block on the first value") {
				let (_signal, observer) = Signal<Int, Never>.pipe()

				let forwardingScheduler = QueueScheduler.makeForTesting()

				let producer = SignalProducer(_signal.delay(0.1, on: forwardingScheduler))

				let observingScheduler = QueueScheduler.makeForTesting()

				var result: Int?

				observingScheduler.schedule {
					result = producer.first()?.value
				}

				expect(result).to(beNil())

				observer.send(value: 1)
				expect(result).toEventually(equal(1), timeout: .seconds(5))
			}

			it("should return a nil result if no values are sent before completion") {
				let result = SignalProducer<Int, Never>.empty.first()
				expect(result).to(beNil())
			}

			it("should return the first value if more than one value is sent") {
				let result = SignalProducer<Int, Never>([ 1, 2 ]).first()
				expect(result?.value) == 1
			}

			it("should return an error if one occurs before the first value") {
				let result = SignalProducer<Int, TestError>(error: .default).first()
				expect(result?.error) == TestError.default
			}
		}

		describe("single") {
			it("should start a signal then block until completion") {
				let (_signal, observer) = Signal<Int, Never>.pipe()

				let forwardingScheduler = QueueScheduler.makeForTesting()

				let producer = SignalProducer(_signal.delay(0.1, on: forwardingScheduler))

				let observingScheduler = QueueScheduler.makeForTesting()

				var result: Int?

				observingScheduler.schedule {
					result = producer.single()?.value
				}
				expect(result).to(beNil())

				observer.send(value: 1)

				Thread.sleep(forTimeInterval: 3.0)
				expect(result).to(beNil())

				observer.sendCompleted()
				expect(result).toEventually(equal(1))
			}

			it("should return a nil result if no values are sent before completion") {
				let result = SignalProducer<Int, Never>.empty.single()
				expect(result).to(beNil())
			}

			it("should return a nil result if more than one value is sent before completion") {
				let result = SignalProducer<Int, Never>([ 1, 2 ]).single()
				expect(result).to(beNil())
			}

			it("should return an error if one occurs") {
				let result = SignalProducer<Int, TestError>(error: .default).single()
				expect(result?.error) == TestError.default
			}
		}

		describe("last") {
			it("should start a signal then block until completion") {
				let (_signal, observer) = Signal<Int, Never>.pipe()
				let scheduler = QueueScheduler.makeForTesting()
				let producer = SignalProducer(_signal.delay(0.1, on: scheduler))

				var result: Result<Int, Never>?

				let group = DispatchGroup()
				let globalQueue = DispatchQueue.global()

				globalQueue.async(group: group, flags: []) {
					result = producer.last()
				}
				expect(result).to(beNil())

				observer.send(value: 1)
				observer.send(value: 2)
				expect(result).to(beNil())

				observer.sendCompleted()
				group.wait()

				expect(result?.value) == 2
			}

			it("should return a nil result if no values are sent before completion") {
				let result = SignalProducer<Int, Never>.empty.last()
				expect(result).to(beNil())
			}

			it("should return the last value if more than one value is sent") {
				let result = SignalProducer<Int, Never>([ 1, 2 ]).last()
				expect(result?.value) == 2
			}

			it("should return an error if one occurs") {
				let result = SignalProducer<Int, TestError>(error: .default).last()
				expect(result?.error) == TestError.default
			}
		}

		describe("wait") {
			it("should start a signal then block until completion") {
				let (_signal, observer) = Signal<Int, Never>.pipe()
				let scheduler = QueueScheduler.makeForTesting()
				let producer = SignalProducer(_signal.delay(0.1, on: scheduler))

				var result: Result<(), Never>?

				let group = DispatchGroup()
				let globalQueue = DispatchQueue.global()

				globalQueue.async(group: group, flags: []) {
					result = producer.wait()
				}

				expect(result).to(beNil())

				observer.sendCompleted()
				group.wait()

				expect(result?.value).toNot(beNil())
			}

			it("should return an error if one occurs") {
				let result = SignalProducer<Int, TestError>(error: .default).wait()
				expect(result.error) == TestError.default
			}
		}

		describe("observeOn") {
			it("should immediately cancel upstream producer's work when disposed") {
				var upstreamLifetime: Lifetime!
				let producer = SignalProducer<(), Never>{ _, innerLifetime in
					upstreamLifetime = innerLifetime
				}

				var downstreamDisposable: Disposable!
				producer
					.observe(on: TestScheduler())
					.startWithSignal { signal, innerDisposable in
						signal.observe { _ in }
						downstreamDisposable = innerDisposable
					}

				expect(upstreamLifetime.hasEnded) == false

				downstreamDisposable.dispose()
				expect(upstreamLifetime.hasEnded) == true
			}
		}

		describe("take") {
			it("Should not start concat'ed producer if the first one sends a value when using take(1)") {
				let scheduler = QueueScheduler.makeForTesting()

				// Delaying producer1 from sending a value to test whether producer2 is started in the mean-time.
				let producer1 = SignalProducer<Int, Never> { handler, _ in
					handler.send(value: 1)
					handler.sendCompleted()
				}.start(on: scheduler)

				var started = false
				let producer2 = SignalProducer<Int, Never> { handler, _ in
					started = true
					handler.send(value: 2)
					handler.sendCompleted()
				}

				let result = producer1.concat(producer2).take(first: 1).collect().first()

				expect(result?.value) == [1]
				expect(started) == false
			}
		}

		describe("replayLazily") {
			var producer: SignalProducer<Int, TestError>!
			var observer: SignalProducer<Int, TestError>.ProducedSignal.Observer!

			var replayedProducer: SignalProducer<Int, TestError>!

			beforeEach {
				let (producerTemp, observerTemp) = SignalProducer<Int, TestError>.pipe()
				producer = producerTemp
				observer = observerTemp

				replayedProducer = producer.replayLazily(upTo: 2)
			}

			context("subscribing to underlying producer") {
				it("emits new values") {
					var last: Int?

					replayedProducer
						.assumeNoErrors()
						.startWithValues { last = $0 }

					expect(last).to(beNil())

					observer.send(value: 1)
					expect(last) == 1

					observer.send(value: 2)
					expect(last) == 2
				}

				it("emits errors") {
					var error: TestError?

					replayedProducer.startWithFailed { error = $0 }
					expect(error).to(beNil())

					observer.send(error: .default)
					expect(error) == TestError.default
				}
			}

			context("buffers past values") {
				it("emits last value upon subscription") {
					let disposable = replayedProducer
						.start()

					observer.send(value: 1)
					disposable.dispose()

					var last: Int?

					replayedProducer
						.assumeNoErrors()
						.startWithValues { last = $0 }
					expect(last) == 1
				}

				it("emits previous failure upon subscription") {
					let disposable = replayedProducer
						.start()

					observer.send(error: .default)
					disposable.dispose()

					var error: TestError?

					replayedProducer
						.startWithFailed { error = $0 }
					expect(error) == TestError.default
				}

				it("emits last n values upon subscription") {
					var disposable = replayedProducer
						.start()

					observer.send(value: 1)
					observer.send(value: 2)
					observer.send(value: 3)
					observer.send(value: 4)
					disposable.dispose()

					var values: [Int] = []

					disposable = replayedProducer
						.assumeNoErrors()
						.startWithValues { values.append($0) }
					expect(values) == [ 3, 4 ]

					observer.send(value: 5)
					expect(values) == [ 3, 4, 5 ]

					disposable.dispose()
					values = []

					replayedProducer
						.assumeNoErrors()
						.startWithValues { values.append($0) }
					expect(values) == [ 4, 5 ]
				}
			}

			context("starting underying producer") {
				it("starts lazily") {
					var started = false

					let producer = SignalProducer<Int, Never>(value: 0)
						.on(started: { started = true })
					expect(started) == false

					let replayedProducer = producer
						.replayLazily(upTo: 1)
					expect(started) == false

					replayedProducer.start()
					expect(started) == true
				}

				it("shares a single subscription") {
					var startedTimes = 0

					let producer = SignalProducer<Int, Never>.never
						.on(started: { startedTimes += 1 })
					expect(startedTimes) == 0

					let replayedProducer = producer
						.replayLazily(upTo: 1)
					expect(startedTimes) == 0

					replayedProducer.start()
					expect(startedTimes) == 1

					replayedProducer.start()
					expect(startedTimes) == 1
				}

				it("does not start multiple times when subscribing multiple times") {
					var startedTimes = 0

					let producer = SignalProducer<Int, Never>(value: 0)
						.on(started: { startedTimes += 1 })

					let replayedProducer = producer
						.replayLazily(upTo: 1)

					expect(startedTimes) == 0
					replayedProducer.start().dispose()
					expect(startedTimes) == 1
					replayedProducer.start().dispose()
					expect(startedTimes) == 1
				}

				it("does not start again if it finished") {
					var startedTimes = 0

					let producer = SignalProducer<Int, Never>.empty
						.on(started: { startedTimes += 1 })
					expect(startedTimes) == 0

					let replayedProducer = producer
						.replayLazily(upTo: 1)
					expect(startedTimes) == 0

					replayedProducer.start()
					expect(startedTimes) == 1

					replayedProducer.start()
					expect(startedTimes) == 1
				}
			}

			context("lifetime") {
				it("does not dispose underlying subscription if the replayed producer is still in memory") {
					var disposed = false

					let producer = SignalProducer<Int, Never>.never
						.on(disposed: { disposed = true })

					let replayedProducer = producer
						.replayLazily(upTo: 1)

					expect(disposed) == false
					let disposable = replayedProducer.start()
					expect(disposed) == false

					disposable.dispose()
					expect(disposed) == false
				}

				it("does not dispose if it has active subscriptions") {
					var disposed = false

					let producer = SignalProducer<Int, Never>.never
						.on(disposed: { disposed = true })

					var replayedProducer = Optional(producer.replayLazily(upTo: 1))

					expect(disposed) == false
					let disposable1 = replayedProducer?.start()
					let disposable2 = replayedProducer?.start()
					expect(disposed) == false

					replayedProducer = nil
					expect(disposed) == false

					disposable1?.dispose()
					expect(disposed) == false

					disposable2?.dispose()
					expect(disposed) == true
				}

				it("disposes underlying producer when the producer is deallocated") {
					var disposed = false

					let producer = SignalProducer<Int, Never>.never
						.on(disposed: { disposed = true })

					var replayedProducer = Optional(producer.replayLazily(upTo: 1))

					expect(disposed) == false
					let disposable = replayedProducer?.start()
					expect(disposed) == false

					disposable?.dispose()
					expect(disposed) == false

					replayedProducer = nil
					expect(disposed) == true
				}

				it("does not leak buffered values") {
					final class Value {
						private let deinitBlock: () -> Void

						init(deinitBlock: @escaping () -> Void) {
							self.deinitBlock = deinitBlock
						}

						deinit {
							self.deinitBlock()
						}
					}

					var deinitValues = 0

					var producer: SignalProducer<Value, Never>! = SignalProducer(value: Value {
						deinitValues += 1
					})
					expect(deinitValues) == 0

					var replayedProducer: SignalProducer<Value, Never>! = producer
						.replayLazily(upTo: 1)

					let disposable = replayedProducer
						.start()

					disposable.dispose()

					withExtendedLifetime(producer) {
						expect(deinitValues) == 0
					}

					producer = nil

					withExtendedLifetime(replayedProducer) {
						expect(deinitValues) == 0
					}

					replayedProducer = nil
					expect(deinitValues) == 1
				}
			}

			describe("log events") {
				it("should output the correct event") {
					let expectations: [(String) -> Void] = [
						{ event in expect(event).to(equal("[] starting")) },
						{ event in expect(event).to(equal("[] started")) },
						{ event in expect(event).to(equal("[] value 1")) },
						{ event in expect(event).to(equal("[] completed")) },
						{ event in expect(event).to(equal("[] terminated")) },
						{ event in expect(event).to(equal("[] disposed")) },
					]

					let logger = TestLogger(expectations: expectations)

					let (producer, observer) = SignalProducer<Int, TestError>.pipe()
					producer
						.logEvents(logger: logger.logEvent)
						.start()

					observer.send(value: 1)
					observer.sendCompleted()
				}
			}

			describe("init(values) ambiguity") {
				it("should not be a SignalProducer<SignalProducer<Int, Never>, Never>") {

					let producer1 = SignalProducer<Int, Never>.empty
					let producer2 = SignalProducer<Int, Never>.empty

					// This expression verifies at compile time that the type is as expected.
					let _: SignalProducer<Int, Never> = SignalProducer([producer1, producer2])
						.flatten(.merge)
				}
			}
		}

		describe("take(during:)") {
			it("completes a signal when the lifetime ends") {
				let (signal, observer) = Signal<Int, Never>.pipe()
				let object = MutableReference(TestObject())

				let output = signal.take(during: object.value!.lifetime)

				var results: [Int] = []
				output.observeValues { results.append($0) }

				observer.send(value: 1)
				observer.send(value: 2)
				object.value = nil
				observer.send(value: 3)

				expect(results) == [1, 2]
			}

			it("completes a signal producer when the lifetime ends") {
				let (producer, observer) = Signal<Int, Never>.pipe()
				let object = MutableReference(TestObject())

				let output = producer.take(during: object.value!.lifetime)

				var results: [Int] = []
				output.observeValues { results.append($0) }

				observer.send(value: 1)
				observer.send(value: 2)
				object.value = nil
				observer.send(value: 3)

				expect(results) == [1, 2]
			}
		}

		describe("negated attribute") {
			it("should return the negate of a value in a Boolean producer") {
				let producer = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: true)
					observer.sendCompleted()
				}

				producer.negate().startWithValues { value in
					expect(value).to(beFalse())
				}
			}
		}

		describe("and attribute") {
			it("should emit true when both producers emits the same value") {
				let producer1 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: true)
					observer.sendCompleted()
				}
				let producer2 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: true)
					observer.sendCompleted()
				}

				producer1.and(producer2).startWithValues { value in
					expect(value).to(beTrue())
				}
			}

			it("should emit false when both producers emits opposite values") {
				let producer1 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: true)
					observer.sendCompleted()
				}
				let producer2 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: false)
					observer.sendCompleted()
				}

				producer1.and(producer2).startWithValues { value in
					expect(value).to(beFalse())
				}
			}

			it("should work the same way when using signal instead of a producer") {
				let producer1 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: true)
					observer.sendCompleted()
				}
				let (signal2, observer2) = Signal<Bool, Never>.pipe()
				producer1.and(signal2).startWithValues { value in
					expect(value).to(beTrue())
				}
				observer2.send(value: true)

				observer2.sendCompleted()
			}

			it("should be able to fallback to SignalProducer for contextual lookups") {
				_ = SignalProducer<Bool, Never>.empty
					.and(.init(value: true))
				_ = SignalProducer<Bool, Never>.and(.init(value: true))
			}
		}

		describe("all attribute") {
			it("should emit true when no producer is given") {
				let producer = SignalProducer<Bool, Never>.all(
					EmptyCollection<SignalProducer<Bool, Never>>()
				)

				var values = [Bool]()
				var isCompleted = false

				producer.start { event in
					switch event {
					case let .value(value):
						values.append(value)
					case .completed:
						isCompleted = true
					case .interrupted, .failed:
						break
					}
				}

				expect(values) == [true]
				expect(isCompleted) == true
			}

			it("should emit true when all producers emit the same value") {
				let producer1 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: true)
					observer.sendCompleted()
				}
				let producer2 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: true)
					observer.sendCompleted()
				}
				let producer3 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: true)
					observer.sendCompleted()
				}

				SignalProducer.all([producer1, producer2, producer3]).startWithValues { value in
					expect(value).to(beTrue())
				}
			}

			it("should emit false when all producers emit opposite values") {
				let producer1 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: true)
					observer.sendCompleted()
				}
				let producer2 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: false)
					observer.sendCompleted()
				}
				let producer3 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: false)
					observer.sendCompleted()
				}

				SignalProducer.all([producer1, producer2, producer3]).startWithValues { value in
					expect(value).to(beFalse())
				}
			}

			it("should work the same way when using array of signals instead of an array of producers") {
				let (signal1, observer1) = Signal<Bool, Never>.pipe()
				let (signal2, observer2) = Signal<Bool, Never>.pipe()
				let (signal3, observer3) = Signal<Bool, Never>.pipe()
				SignalProducer.all([signal1, signal2, signal3]).startWithValues { value in
					expect(value).to(beTrue())
				}
				observer1.send(value: true)
				observer1.sendCompleted()
				observer2.send(value: true)
				observer2.sendCompleted()
				observer3.send(value: true)
				observer3.sendCompleted()
			}
		}

		describe("or attribute") {
			it("should emit true when at least one of the producers emits true") {
				let producer1 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: true)
					observer.sendCompleted()
				}
				let producer2 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: false)
					observer.sendCompleted()
				}

				producer1.or(producer2).startWithValues { value in
					expect(value).to(beTrue())
				}
			}

			it("should emit false when both producers emits false") {
				let producer1 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: false)
					observer.sendCompleted()
				}
				let producer2 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: false)
					observer.sendCompleted()
				}

				producer1.or(producer2).startWithValues { value in
					expect(value).to(beFalse())
				}
			}

			it("should work the same way when using signal instead of a producer") {
				let producer1 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: true)
					observer.sendCompleted()
				}
				let (signal2, observer2) = Signal<Bool, Never>.pipe()
				producer1.or(signal2).startWithValues { value in
					expect(value).to(beTrue())
				}
				observer2.send(value: true)

				observer2.sendCompleted()
			}

			it("should be able to fallback to SignalProducer for contextual lookups") {
				_ = SignalProducer<Bool, Never>.empty
					.or(.init(value: true))
				_ = SignalProducer<Bool, Never>.or(.init(value: true))
			}
		}

		describe("any attribute") {
			it("should emit false when no producer is given") {
				let producer = SignalProducer<Bool, Never>.any(
					EmptyCollection<SignalProducer<Bool, Never>>()
				)

				var values = [Bool]()
				var isCompleted = false

				producer.start { event in
					switch event {
					case let .value(value):
						values.append(value)
					case .completed:
						isCompleted = true
					case .interrupted, .failed:
						break
					}
				}

				expect(values) == [false]
				expect(isCompleted) == true
			}

			it("should emit true when at least one of the producers in array emits true") {
				let producer1 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: true)
					observer.sendCompleted()
				}
				let producer2 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: false)
					observer.sendCompleted()
				}
				let producer3 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: false)
					observer.sendCompleted()
				}

				SignalProducer.any([producer1, producer2, producer3]).startWithValues { value in
					expect(value).to(beTrue())
				}
			}
			
			it("should emit false when all producers emit false") {
				let producer1 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: false)
					observer.sendCompleted()
				}
				let producer2 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: false)
					observer.sendCompleted()
				}
				let producer3 = SignalProducer<Bool, Never> { observer, _ in
					observer.send(value: false)
					observer.sendCompleted()
				}

				SignalProducer.any(producer1, producer2, producer3).startWithValues { value in
					expect(value).to(beFalse())
				}
			}
			
			it("should work the same way when using array of signals instead of an array of producers") {
				let (signal1, observer1) = Signal<Bool, Never>.pipe()
				let (signal2, observer2) = Signal<Bool, Never>.pipe()
				let (signal3, observer3) = Signal<Bool, Never>.pipe()
				let arrayOfSignals = [signal1, signal2, signal3]

				SignalProducer.any(arrayOfSignals).startWithValues { value in
					expect(value).to(beTrue())
				}
				observer1.send(value: true)
				observer1.sendCompleted()
				observer2.send(value: true)
				observer2.sendCompleted()
				observer3.send(value: true)
				observer3.sendCompleted()
			}
		}

		describe("promoteError") {
			it("should infer the error type from the context") {
				let combined: Any = SignalProducer
					.combineLatest(SignalProducer<Int, Never>.never.promoteError(),
					               SignalProducer<Double, TestError>.never,
					               SignalProducer<Float, Never>.never.promoteError(),
					               SignalProducer<UInt, POSIXError>.never.flatMapError { _ in .empty })

				expect(combined is SignalProducer<(Int, Double, Float, UInt), TestError>) == true
			}
		}
	}
}

// MARK: - Helpers

private func == <T>(left: Expectation<T.Type>, right: Any.Type) {
	left.to(Predicate { expression in
		PredicateResult(
			bool: try expression.evaluate()! == right,
			message: ExpectationMessage.expectedActualValueTo("equal to")
		)
	}.requireNonNil)
}

extension SignalProducer {
	internal static func pipe() -> (SignalProducer, ProducedSignal.Observer) {
		let (signal, observer) = ProducedSignal.pipe()
		let producer = SignalProducer(signal)
		return (producer, observer)
	}

	/// Creates a producer that can be started as many times as elements in `results`.
	/// Each signal will immediately send either a value or an error.
	fileprivate static func attemptWithResults<C: Collection>(_ results: C) -> SignalProducer<Value, Error> where C.Iterator.Element == Result<Value, Error> {
		let resultCount = results.count
		var operationIndex = 0

		precondition(resultCount > 0)

		let operation: () -> Result<Value, Error> = {
			if operationIndex < resultCount {
				defer {
					operationIndex += 1
				}

				return results[results.index(results.startIndex, offsetBy: operationIndex)]
			} else {
				fail("Operation started too many times")

				return results[results.startIndex]
			}
		}

		return SignalProducer(operation)
	}
}
