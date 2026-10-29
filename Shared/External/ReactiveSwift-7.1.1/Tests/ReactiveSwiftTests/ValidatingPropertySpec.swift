import Quick
import Nimble
import ReactiveSwift

class ValidatingPropertySpec: QuickSpec {
	override func spec() {
		describe("ValidatingProperty") {
			describe("no dependency") {
				var root: MutableProperty<Int>!
				var validated: ValidatingProperty<Int, TestError>!
				var validationResult: FlattenedResult<Int>?

				beforeEach {
					root = MutableProperty(0)
					validated = ValidatingProperty(root) { $0 >= 0 ? ($0 == 100 ? .coerced(Int.max, .default) : .valid) : .invalid(.default) }

					validated.result.signal.observeValues { validationResult = FlattenedResult($0) }

					expect(validated.value) == 0
					expect(FlattenedResult(validated.result.value)) == FlattenedResult.valid(0)
					expect(validationResult).to(beNil())
				}

				afterEach {
					validationResult = nil

					weak var weakRoot = root
					expect(weakRoot).notTo(beNil())

					root = nil
					expect(weakRoot).notTo(beNil())

					validated = nil
					expect(weakRoot).to(beNil())

				}

				it("should let valid values get through") {
					validated.value = 10

					expect(validated.value) == 10
					expect(validationResult) == .valid(10)
				}

				it("should denote the substitution") {
					validated.value = 100

					expect(validated.value) == Int.max
					expect(validationResult) == .coerced(Int.max, 100, .default)
				}

				it("should block invalid values") {
					validated.value = -10

					expect(validated.value) == 0
					expect(validationResult) == .errorDefault(-10)
				}

				it("should validate changes originated from the root property") {
					root.value = 10

					expect(validated.value) == 10
					expect(validationResult) == .valid(10)

					root.value = -10

					expect(validated.value) == -10
					expect(validationResult) == .errorDefault(-10)
				}
			}

			describe("a MutablePropertyProtocol dependency") {
				var other: MutableProperty<String>!
				var validated: ValidatingProperty<Int, TestError>!
				var validationResult: FlattenedResult<Int>?

				beforeEach {
					other = MutableProperty("")
					validated = ValidatingProperty(0, with: other) { $0 >= 0 && $1 == "🎃" ? ($0 == 100 ? .coerced(Int.max, .default) : .valid) : .invalid(.default) }

					validated.result.signal.observeValues { validationResult = FlattenedResult($0) }

					expect(validated.value) == 0
					expect(FlattenedResult(validated.result.value)) == FlattenedResult.errorDefault(0)
					expect(validationResult).to(beNil())
				}

				afterEach {
					weak var weakOther = other
					expect(weakOther).toNot(beNil())

					other = nil
					expect(weakOther).to(beNil())

					validationResult = nil
				}

				it("should let valid values get through") {
					other.value = "🎃"

					validated.value = 10

					expect(validated.value) == 10
					expect(validationResult) == .valid(10)
				}

				it("should block invalid values") {
					validated.value = -10

					expect(validated.value) == 0
					expect(validationResult) == .errorDefault(-10)
				}

				it("should denote the substitution") {
					other.value = "🎃"
					validated.value = 100

					expect(validated.value) == Int.max
					expect(validationResult) == .coerced(Int.max, 100, .default)
				}

				it("should automatically revalidate the latest failed value if the dependency changes") {
					validated.value = 10

					expect(validated.value) == 0
					expect(validationResult) == .errorDefault(10)

					other.value = "🎃"

					expect(validated.value) == 10
					expect(validationResult) == .valid(10)
				}

				it("should automatically revalidate the latest substituted value if the dependency changes") {
					validated.value = 100

					expect(validated.value) == 0
					expect(validationResult) == .errorDefault(100)

					other.value = "🎃"

					expect(validated.value) == Int.max
					expect(validationResult) == .coerced(Int.max, 100, .default)

					validated.value = -1

					expect(validated.value) == Int.max
					expect(validationResult) == .errorDefault(-1)
				}
			}

			describe("a ValidatingProperty dependency") {
				var other: ValidatingProperty<String, TestError>!
				var validated: ValidatingProperty<Int, TestError>!
				var validationResult: FlattenedResult<Int>?

				beforeEach {
					other = ValidatingProperty("") { $0.hasSuffix("🎃") && $0 != "🎃" ? .valid : .invalid(.error2) }

					validated = ValidatingProperty(0, with: other) { $0 >= 0 && $1.hasSuffix("🎃") ? ($0 == 100 ? .coerced(Int.max, .default) : .valid) : .invalid(.default) }

					validated.result.signal.observeValues { validationResult = FlattenedResult($0) }

					expect(validated.value) == 0
					expect(FlattenedResult(validated.result.value)) == FlattenedResult.errorDefault(0)
					expect(validationResult).to(beNil())
				}

				afterEach {
					weak var weakOther = other
					expect(weakOther).toNot(beNil())

					other = nil
					expect(weakOther).to(beNil())

					validationResult = nil
				}

				it("should let valid values get through even if the dependency fails its validation") {
					other.value = "🎃"

					validated.value = 10

					expect(validated.value) == 10
					expect(validationResult) == .valid(10)
				}

				it("should block invalid values") {
					validated.value = -10

					expect(validated.value) == 0
					expect(validationResult) == .errorDefault(-10)
				}

				it("should denote the substitution") {
					other.value = "🎃"
					validated.value = 100

					expect(validated.value) == Int.max
					expect(validationResult) == .coerced(Int.max, 100, .default)
				}

				it("should automatically revalidate the latest failed value if the dependency changes") {
					validated.value = 10

					expect(validated.value) == 0
					expect(validationResult) == .errorDefault(10)

					other.value = "🎃"

					expect(validated.value) == 10
					expect(validationResult) == .valid(10)
				}

				it("should automatically revalidate the latest substituted value if the dependency changes") {
					validated.value = 100

					expect(validated.value) == 0
					expect(validationResult) == .errorDefault(100)

					other.value = "🎃"

					expect(validated.value) == Int.max
					expect(validationResult) == .coerced(Int.max, 100, .default)

					validated.value = -1

					expect(validated.value) == Int.max
					expect(validationResult) == .errorDefault(-1)
				}

				it("should automatically revalidate the latest failed value whenever the dependency has been proposed a new input") {
					validated.value = 10

					expect(validated.value) == 0
					expect(validationResult) == .errorDefault(10)

					other.value = "🎃"

					expect(other.value) == ""
					expect(FlattenedResult(other.result.value)) == FlattenedResult.error2("🎃")

					expect(validated.value) == 10
					expect(validationResult) == .valid(10)

					other.value = "👻🎃"

					expect(other.value) == "👻🎃"
					expect(FlattenedResult(other.result.value)) == FlattenedResult.valid("👻🎃")

					expect(validated.value) == 10
					expect(validationResult) == .valid(10)
				}
			}
		}
	}
}

private enum FlattenedResult<Value: Equatable>: Equatable {
	case errorDefault(Value)
	case error1(Value)
	case error2(Value)

	case valid(Value)
	case coerced(Value, Value, TestError?)

	init(_ result: ValidatingProperty<Value, TestError>.Result) {
		switch result {
		case let .valid(value):
			self = .valid(value)

		case let .coerced(substitutedValue, proposedValue, error):
			self = .coerced(substitutedValue, proposedValue, error)

		case let .invalid(value, error):
			switch error {
			case .default:
				self = .errorDefault(value)
			case .error1:
				self = .error1(value)
			case .error2:
				self = .error2(value)
			}
		}
	}

	static func ==(left: FlattenedResult<Value>, right: FlattenedResult<Value>) -> Bool {
		switch (left, right) {
		case (let .errorDefault(lhsValue), let .errorDefault(rhsValue)):
			return lhsValue == rhsValue
		case (let .error1(lhsValue), let .error1(rhsValue)):
			return lhsValue == rhsValue
		case (let .error2(lhsValue), let .error2(rhsValue)):
			return lhsValue == rhsValue
		case (let .valid(lhsValue), let .valid(rhsValue)):
			return lhsValue == rhsValue
		case (let .coerced(lhsSubstitution, lhsProposed, lhsError), let .coerced(rhsSubstitution, rhsProposed, rhsError)):
			return lhsSubstitution == rhsSubstitution && lhsProposed == rhsProposed && lhsError == rhsError
		default:
			return false
		}
	}
}
