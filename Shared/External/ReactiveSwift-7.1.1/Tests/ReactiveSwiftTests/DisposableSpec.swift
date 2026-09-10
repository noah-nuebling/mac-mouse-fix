//
//  DisposableSpec.swift
//  ReactiveSwift
//
//  Created by Justin Spahr-Summers on 2014-07-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Nimble
import Quick
import ReactiveSwift

class DisposableSpec: QuickSpec {
	override func spec() {
		describe("SimpleDisposable") {
			it("should set disposed to true") {
				let disposable = AnyDisposable()
				expect(disposable.isDisposed) == false

				disposable.dispose()
				expect(disposable.isDisposed) == true
			}
		}

		describe("ActionDisposable") {
			it("should run the given action upon disposal") {
				var didDispose = false
				let disposable = AnyDisposable {
					didDispose = true
				}

				expect(didDispose) == false
				expect(disposable.isDisposed) == false

				disposable.dispose()
				expect(didDispose) == true
				expect(disposable.isDisposed) == true
			}
		}

		describe("CompositeDisposable") {
			var disposable = CompositeDisposable()

			beforeEach {
				disposable = CompositeDisposable()
			}

			it("should ignore the addition of nil") {
				disposable.add(nil)
				return
			}

			it("should dispose of added disposables") {
				let simpleDisposable = AnyDisposable()
				disposable += simpleDisposable

				var didDispose = false
				disposable += {
					didDispose = true
				}

				expect(simpleDisposable.isDisposed) == false
				expect(didDispose) == false
				expect(disposable.isDisposed) == false

				disposable.dispose()
				expect(simpleDisposable.isDisposed) == true
				expect(didDispose) == true
				expect(disposable.isDisposed) == true
			}

			it("should not dispose of removed disposables") {
				let simpleDisposable = AnyDisposable()
				let handle = disposable += simpleDisposable

				// We should be allowed to call this any number of times.
				handle?.dispose()
				handle?.dispose()
				expect(simpleDisposable.isDisposed) == false

				disposable.dispose()
				expect(simpleDisposable.isDisposed) == false
			}
			
			it("should create with initial disposables") {
				let disposable1 = AnyDisposable()
				let disposable2 = AnyDisposable()
				let disposable3 = AnyDisposable()

				let compositeDisposable = CompositeDisposable([disposable1, disposable2, disposable3])

				expect(disposable1.isDisposed) == false
				expect(disposable2.isDisposed) == false
				expect(disposable3.isDisposed) == false

				compositeDisposable.dispose()
				
				expect(disposable1.isDisposed) == true
				expect(disposable2.isDisposed) == true
				expect(disposable3.isDisposed) == true
			}
		}

		describe("ScopedDisposable") {
			it("should be initialized with an instance of `Disposable` protocol type") {
				let d: Disposable = AnyDisposable()
				let scoped = ScopedDisposable(d)
				expect(type(of: scoped) == ScopedDisposable<AnyDisposable>.self) == true
			}

			it("should dispose of the inner disposable upon deinitialization") {
				let simpleDisposable = AnyDisposable()

				func runScoped() {
					let scopedDisposable = ScopedDisposable(simpleDisposable)
					expect(simpleDisposable.isDisposed) == false
					expect(scopedDisposable.isDisposed) == false
				}

				expect(simpleDisposable.isDisposed) == false

				runScoped()
				expect(simpleDisposable.isDisposed) == true
			}
		}

		describe("SerialDisposable") {
			var disposable: SerialDisposable!

			beforeEach {
				disposable = SerialDisposable()
			}

			it("should dispose of the inner disposable") {
				let simpleDisposable = AnyDisposable()
				disposable.inner = simpleDisposable

				expect(disposable.inner).notTo(beNil())
				expect(simpleDisposable.isDisposed) == false
				expect(disposable.isDisposed) == false

				disposable.dispose()
				expect(disposable.inner).to(beNil())
				expect(simpleDisposable.isDisposed) == true
				expect(disposable.isDisposed) == true
			}

			it("should dispose of the previous disposable when swapping innerDisposable") {
				let oldDisposable = AnyDisposable()
				let newDisposable = AnyDisposable()

				disposable.inner = oldDisposable
				expect(oldDisposable.isDisposed) == false
				expect(newDisposable.isDisposed) == false

				disposable.inner = newDisposable
				expect(oldDisposable.isDisposed) == true
				expect(newDisposable.isDisposed) == false
				expect(disposable.isDisposed) == false

				disposable.inner = nil
				expect(newDisposable.isDisposed) == true
				expect(disposable.isDisposed) == false
			}
		}
	}
}
