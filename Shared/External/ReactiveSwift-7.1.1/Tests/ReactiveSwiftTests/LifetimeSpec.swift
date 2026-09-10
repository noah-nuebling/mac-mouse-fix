import Quick
import Nimble
import ReactiveSwift

final class LifetimeSpec: QuickSpec {
	override func spec() {
		describe("Lifetime") {
			it("should complete its lifetime ended signal when the token deinitializes") {
				let object = MutableReference(TestObject())

				var isCompleted = false

				object.value!.lifetime.ended.observeCompleted { isCompleted = true }
				expect(isCompleted) == false

				object.value = nil
				expect(isCompleted) == true
			}

			it("should complete its lifetime ended signal when the token is disposed of") {
				let object = MutableReference(TestObject())

				var isCompleted = false

				object.value!.lifetime.ended.observeCompleted { isCompleted = true }
				expect(isCompleted) == false

				object.value!.disposeToken()
				expect(isCompleted) == true
			}

			it("should complete its lifetime ended signal even if the lifetime object is being retained") {
				let object = MutableReference(TestObject())
				let lifetime = object.value!.lifetime

				var isCompleted = false

				lifetime.ended.observeCompleted { isCompleted = true }
				expect(isCompleted) == false

				object.value = nil
				expect(isCompleted) == true
			}

			it("should provide a convenience factory method") {
				let lifetime: Lifetime
				var token: Lifetime.Token

				(lifetime, token) = Lifetime.make()

				var isEnded = false
				lifetime.observeEnded { isEnded = true }

				token = Lifetime.Token()
				_ = token

				expect(isEnded) == true
			}

			it("should notify its observers when the underlying token deinitializes") {
				let object = MutableReference(TestObject())

				var isEnded = false

				object.value!.lifetime.observeEnded { isEnded = true }
				expect(isEnded) == false

				object.value = nil
				expect(isEnded) == true
			}

			it("should notify its observers of the deinitialization of the underlying token even if the `Lifetime` object is retained") {
				let object = MutableReference(TestObject())
				let lifetime = object.value!.lifetime

				var isEnded = false

				lifetime.observeEnded { isEnded = true }
				expect(isEnded) == false

				object.value = nil
				expect(isEnded) == true
			}

			it("should notify its observers of its deinitialization if it has already ended") {
				var isEnded = false

				Lifetime.empty.observeEnded { isEnded = true }
				expect(isEnded) == true
			}
		}
	}
}

internal final class MutableReference<Value: AnyObject> {
	var value: Value?
	init(_ value: Value?) {
		self.value = value
	}
}

internal final class TestObject {
	private let token = Lifetime.Token()
	var lifetime: Lifetime { return Lifetime(token) }

	func disposeToken() {
		token.dispose()
	}
}
