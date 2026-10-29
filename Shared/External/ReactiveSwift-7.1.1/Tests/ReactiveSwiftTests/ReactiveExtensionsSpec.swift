import Nimble
import Quick
@testable import ReactiveSwift

private final class TestExtensionProvider: ReactiveExtensionsProvider {
	let instanceProperty = "instance"
	static let staticProperty = "static"
}

extension Reactive where Base: TestExtensionProvider {
	var instanceProperty: SignalProducer<String, Never> {
		return SignalProducer(value: base.instanceProperty)
	}

	static var staticProperty: SignalProducer<String, Never> {
		return SignalProducer(value: Base.staticProperty)
	}
}

final class ReactiveExtensionsSpec: QuickSpec {
	override func spec() {
		describe("ReactiveExtensions") {
			it("allows reactive extensions of instances") {
				expect(TestExtensionProvider().reactive.instanceProperty.first()?.value) == "instance"
			}

			it("allows reactive extensions of types") {
				expect(TestExtensionProvider.reactive.staticProperty.first()?.value) == "static"
			}
		}
	}
}
