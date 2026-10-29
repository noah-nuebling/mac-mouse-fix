/*:
 > ## IMPORTANT: To use `ReactiveSwift-UIExamples.playground`, please:

 1. Retrieve the project dependencies using one of the following terminal commands from the ReactiveSwift project root directory:
 - `git submodule update --init`
 **OR**, if you have [Carthage](https://github.com/Carthage/Carthage) installed
 - `carthage checkout`
 1. Open `ReactiveSwift.xcworkspace`
 1. Build `Result-iOS` scheme
 1. Build `ReactiveSwift-iOS` scheme
 1. Finally open the `ReactiveSwift-UIExamples.playground` through the workspace.
 1. Choose `View > Assistant Editor > Show Assistant Editor`
 1. If you cannot see the playground live view, make sure the Timeline view has been selected for the Assistant Editor.
 */
import ReactiveSwift
import UIKit
import PlaygroundSupport

final class ViewModel {
	struct FormError: Error {
		let reason: String

		static let invalidEmail = FormError(reason: "The address must end with `@reactivecocoa.io`.")
		static let mismatchEmail = FormError(reason: "The e-mail addresses do not match.")
		static let usernameUnavailable = FormError(reason: "The username has been taken.")
	}

	let email: ValidatingProperty<String, FormError>
	let emailConfirmation: ValidatingProperty<String, FormError>
	let termsAccepted: MutableProperty<Bool>

	let submit: Action<(), (), FormError>

	let reasons: Signal<String, Never>

	init(userService: UserService) {
        // email: ValidatingProperty<String, FormError>
		email = ValidatingProperty("") { input in
			return input.hasSuffix("@reactivecocoa.io") ? .valid : .invalid(.invalidEmail)
		}

        // emailConfirmation: ValidatingProperty<String, FormError>
		emailConfirmation = ValidatingProperty("", with: email) { input, email in
			return input == email ? .valid : .invalid(.mismatchEmail)
		}

        // termsAccepted: MutableProperty<Bool>
		termsAccepted = MutableProperty(false)

		// `validatedEmail` is a property which holds the validated email address if
		//  the entire form is valid, or it holds `nil` otherwise.
		//
		// The condition used in the `map` transform is:
		// 1. `emailConfirmation` passes validation: `!email.isInvalid`; and
		// 2. `termsAccepted` is asserted: `accepted`.
        let validatedEmail: Property<String?> = Property
            .combineLatest(emailConfirmation.result, termsAccepted)
			.map { email, accepted -> String? in
			      return !email.isInvalid && accepted ? email.value! : nil
			}

		// The action to be invoked when the submit button is pressed.
		//
		// Recall that `submit` is an `Action` with no input, i.e. `Input == ()`.
		// `Action` provides a special initializer in this case: `init(state:)`.
		// It takes a property of optionals — in our case, `validatedEmail` — and
		// would disable whenever the property holds `nil`.
		submit = Action(unwrapping: validatedEmail) { (email: String) in
			let username = email.stripSuffix("@reactivecocoa.io")!

			return userService.canUseUsername(username)
				.promoteError(FormError.self)
				.attemptMap { Result<(), FormError>($0 ? () : nil, failWith: .usernameUnavailable) }
		}

		// `reason` is an aggregate of latest validation error for the UI to display.
		reasons = Property.combineLatest(email.result, emailConfirmation.result)
			.signal
			.debounce(0.1, on: QueueScheduler.main)
			.map { [$0, $1].flatMap { $0.error?.reason }.joined(separator: "\n") }
	}
}

final class ViewController: UIViewController {
	private let viewModel: ViewModel
	private var formView: FormView!

	override func viewDidLoad() {
		super.viewDidLoad()

		// Initialize the interactive controls.
		formView.emailField.text = viewModel.email.value
		formView.emailConfirmationField.text = viewModel.emailConfirmation.value
		formView.termsSwitch.isOn = false

		// Setup bindings with the interactive controls.
		viewModel.email <~ formView.emailField.reactive
			.continuousTextValues.skipNil()

		viewModel.emailConfirmation <~ formView.emailConfirmationField.reactive
			.continuousTextValues.skipNil()

		viewModel.termsAccepted <~ formView.termsSwitch.reactive
			.isOnValues

		// Setup bindings with the invalidation reason label.
		formView.reasonLabel.reactive.text <~ viewModel.reasons

		// Setup the Action binding with the submit button.
		formView.submitButton.reactive.pressed = CocoaAction(viewModel.submit)
	}

	override func loadView() {
		formView = FormView()
		view = formView
	}

	init(_ viewModel: ViewModel) {
		self.viewModel = viewModel
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError()
	}
}

final class UserService {
	let (requestSignal, requestObserver) = Signal<String, Never>.pipe()

	func canUseUsername(_ string: String) -> SignalProducer<Bool, Never> {
		return SignalProducer { observer, disposable in
			self.requestObserver.send(value: string)
			observer.send(value: true)
			observer.sendCompleted()
		}
	}
}

func main() {
	let userService = UserService()
	let viewModel = ViewModel(userService: userService)
	let viewController = ViewController(viewModel)
	let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 350))
	window.rootViewController = viewController

	PlaygroundPage.current.liveView = window
	PlaygroundPage.current.needsIndefiniteExecution = true

	window.makeKeyAndVisible()

	// Setup console messages.
	userService.requestSignal.observeValues {
		print("UserService.requestSignal: Username `\($0)`.")
	}

	viewModel.submit.completed.observeValues {
		print("ViewModel.submit: execution producer has completed.")
	}

	viewModel.email.result.signal.observeValues {
		print("ViewModel.email: Validation result - \($0 != nil ? "\($0!)" : "No validation has ever been performed.")")
	}

	viewModel.emailConfirmation.result.signal.observeValues {
		print("ViewModel.emailConfirmation: Validation result - \($0 != nil ? "\($0!)" : "No validation has ever been performed.")")
	}
}

main()
