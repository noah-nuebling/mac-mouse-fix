/*:
> # IMPORTANT: To use `ReactiveSwift.playground`, please:

1. Retrieve the project dependencies using one of the following terminal commands from the ReactiveSwift project root directory:
    - `git submodule update --init`
 **OR**, if you have [Carthage](https://github.com/Carthage/Carthage) installed
    - `carthage checkout`
1. Open `ReactiveSwift.xcworkspace`
1. Build `ReactiveSwift-macOS` scheme
1. Finally open the `ReactiveSwift.playground`
1. Choose `View > Show Debug Area`
*/

import ReactiveSwift
import Foundation

/*:
## Signal

A **signal**, represented by the [`Signal`](https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Sources/Signal.swift) type, is any series of [`Event`](https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Sources/Event.swift) values
over time that can be observed.

Signals are generally used to represent event streams that are already “in progress”,
like notifications, user input, etc. As work is performed or data is received,
events are _sent_ on the signal, which pushes them out to any observers.
All observers see the events at the same time.

Users must observe a signal in order to access its events.
Observing a signal does not trigger any side effects. In other words,
signals are entirely producer-driven and push-based, and consumers (observers)
cannot have any effect on their lifetime. While observing a signal, the user
can only evaluate the events in the same order as they are sent on the signal. There
is no random access to values of a signal.

Signals can be manipulated by applying [primitives](https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Documentation/BasicOperators.md) to them.
Typical primitives to manipulate a single signal like `filter`, `map` and
`reduce` are available, as well as primitives to manipulate multiple signals
at once (`zip`). Primitives operate only on the `value` events of a signal.

The lifetime of a signal consists of any number of `value` events, followed by
one terminating event, which may be any one of `failed`, `completed`, or
`interrupted` (but not a combination).
Terminating events are not included in the signal’s values—they must be
handled specially.
*/

/*:
### `Subscription`
A Signal represents and event stream that is already "in progress", sometimes also called "hot". This means, that a subscriber may miss events that have been sent before the subscription.
Furthermore, the subscription to a signal does not trigger any side effects
*/
scopedExample("Subscription") {
	// Signal.pipe is a way to manually control a signal. the returned observer can be used to send values to the signal
	let (signal, observer) = Signal<Int, Never>.pipe()

	let subscriber1 = Signal<Int, Never>.Observer(value: { print("Subscriber 1 received \($0)") } )
	let subscriber2 = Signal<Int, Never>.Observer(value: { print("Subscriber 2 received \($0)") } )

	print("Subscriber 1 subscribes to the signal")
	signal.observe(subscriber1)

	print("Send value `10` on the signal")
	// subscriber1 will receive the value
	observer.send(value: 10)

	print("Subscriber 2 subscribes to the signal")
	// Notice how nothing happens at this moment, i.e. subscriber2 does not receive the previously sent value
	signal.observe(subscriber2)

	print("Send value `20` on the signal")
	// Notice that now, subscriber1 and subscriber2 will receive the value
	observer.send(value: 20)
}

/*:
### `empty`
A Signal that completes immediately without emitting any value.
*/
scopedExample("`empty`") {
	let emptySignal = Signal<Int, Never>.empty

	let observer = Signal<Int, Never>.Observer(
		value: { _ in print("value not called") },
		failed: { _ in print("error not called") },
		completed: { print("completed not called") },
		interrupted: { print("interrupted called") }
	)

	emptySignal.observe(observer)
}

/*:
### `never`
A Signal that never sends any events to its observers.
*/
scopedExample("`never`") {
	let neverSignal = Signal<Int, Never>.never

	let observer = Signal<Int, Never>.Observer(
		value: { _ in print("value not called") },
		failed: { _ in print("error not called") },
		completed: { print("completed not called") },
		interrupted: { print("interrupted not called") }
	)

	neverSignal.observe(observer)
}

/*:
## `Operators`
### `uniqueValues`
Forwards only those values from `self` that are unique across the set of
all values that have been seen.

Note: This causes the values to be retained to check for uniqueness. Providing
a function that returns a unique value for each sent value can help you reduce
the memory footprint.
*/
scopedExample("`uniqueValues`") {
	let (signal, observer) = Signal<Int, Never>.pipe()
	let subscriber = Signal<Int, Never>.Observer(value: { print("Subscriber received \($0)") } )
	let uniqueSignal = signal.uniqueValues()

	uniqueSignal.observe(subscriber)
	observer.send(value: 1)
	observer.send(value: 2)
	observer.send(value: 3)
	observer.send(value: 4)
	observer.send(value: 3)
	observer.send(value: 3)
	observer.send(value: 5)
}

/*:
### `map`
Maps each value in the signal to a new value.
*/
scopedExample("`map`") {
	let (signal, observer) = Signal<Int, Never>.pipe()
	let subscriber = Signal<Int, Never>.Observer(value: { print("Subscriber received \($0)") } )
	let mappedSignal = signal.map { $0 * 2 }

	mappedSignal.observe(subscriber)
	print("Send value `10` on the signal")
	observer.send(value: 10)
}

/*:
### `mapError`
Maps errors in the signal to a new error.
*/
scopedExample("`mapError`") {
	let (signal, observer) = Signal<Int, NSError>.pipe()
	let subscriber = Signal<Int, NSError>.Observer(failed: { print("Subscriber received error: \($0)") } )
	let mappedErrorSignal = signal.mapError { (error:NSError) -> NSError in
		let userInfo = [NSLocalizedDescriptionKey: "🔥"]
		let code = error.code + 10000
		let mappedError = NSError(domain: "com.reactivecocoa.errordomain", code: code, userInfo: userInfo)
		return mappedError
	}

	mappedErrorSignal.observe(subscriber)
	print("Send error `NSError(domain: \"com.reactivecocoa.errordomain\", code: 4815, userInfo: nil)` on the signal")
	observer.send(error: NSError(domain: "com.reactivecocoa.errordomain", code: 4815, userInfo: nil))
}

/*:
### `filter`
Preserves only the values of the signal that pass the given predicate.
*/
scopedExample("`filter`") {
	let (signal, observer) = Signal<Int, Never>.pipe()
	let subscriber = Signal<Int, Never>.Observer(value: { print("Subscriber received \($0)") } )
	// subscriber will only receive events with values greater than 12
	let filteredSignal = signal.filter { $0 > 12 }

	filteredSignal.observe(subscriber)
	observer.send(value: 10)
	observer.send(value: 11)
	observer.send(value: 12)
	observer.send(value: 13)
	observer.send(value: 14)
}

/*:
### `skipNil`
Unwraps non-`nil` values and forwards them on the returned signal, `nil`
values are dropped.
*/
scopedExample("`skipNil`") {
	let (signal, observer) = Signal<Int?, Never>.pipe()
	// note that the signal is of type `Int?` and observer is of type `Int`, given we're unwrapping
	// non-`nil` values
	let subscriber = Signal<Int, Never>.Observer(value: { print("Subscriber received \($0)") } )
	let skipNilSignal = signal.skipNil()

	skipNilSignal.observe(subscriber)
	observer.send(value: 1)
	observer.send(value: nil)
	observer.send(value: 3)
}

/*:
### `take(first:)`
Returns a signal that will yield the first `count` values from `self`
*/
scopedExample("`take(first:)`") {
	let (signal, observer) = Signal<Int, Never>.pipe()
	let subscriber = Signal<Int, Never>.Observer(value: { print("Subscriber received \($0)") } )
	let takeSignal = signal.take(first: 2)

	takeSignal.observe(subscriber)
	observer.send(value: 1)
	observer.send(value: 2)
	observer.send(value: 3)
	observer.send(value: 4)
}

/*:
### `collect`
Returns a signal that will yield an array of values when `self` completes.
- Note: When `self` completes without collecting any value, it will send
an empty array of values.
*/
scopedExample("`collect`") {
	let (signal, observer) = Signal<Int, Never>.pipe()
	// note that the signal is of type `Int` and observer is of type `[Int]` given we're "collecting"
	// `Int` values for the lifetime of the signal
	let subscriber = Signal<[Int], Never>.Observer(value: { print("Subscriber received \($0)") } )
	let collectSignal = signal.collect()

	collectSignal.observe(subscriber)
	observer.send(value: 1)
	observer.send(value: 2)
	observer.send(value: 3)
	observer.send(value: 4)
	observer.sendCompleted()
}
