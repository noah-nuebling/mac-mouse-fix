# Basic Operators

This document explains some of the most common operators used in ReactiveCocoa,
and includes examples demonstrating their use.

Note that “operators”, in this context, refers to functions that transform
[`Signal`s][Signal] and [`SignalProducer`s][SignalProducer], _not_ custom Swift operators. In other
words, these are composable primitives provided by ReactiveCocoa for working
with event streams.

This document will use the term “event stream” when dealing with concepts that
apply to both `Signal` and `SignalProducer`. When the distinction matters, the
types will be referred to by name.

**[Performing side effects with event streams](#performing-side-effects-with-event-streams)**

  1. [Observation](#observation)
  1. [Injecting effects](#injecting-effects)

**[Operator composition](#operator-composition)**

  1. [Lifting](#lifting)

**[Transforming event streams](#transforming-event-streams)**

  1. [Mapping](#mapping)
  1. [Filtering](#filtering)
  1. [Aggregating](#aggregating)

**[Combining event streams](#combining-event-streams)**

  1. [Combining latest values](#combining-latest-values)
  1. [Zipping](#zipping)

**[Flattening event streams](#flattening-event-streams)**

  1. [Merging](#merging)
  1. [Concatenating](#concatenating)
  1. [Switching to the latest](#switching-to-the-latest)

**[Working with errors](#working-with-errors)**

  1. [Catching failures](#catching-failures)
  1. [Failable transformations](#failable-transformations)
  1. [Retrying](#retrying)
  1. [Mapping errors](#mapping-errors)
  1. [Promote](#promote)

## Performing side effects with event streams

### Observation

`Signal`s can be observed with the `observe` function.

```Swift
signal.observe { event in
    switch event {
    case let .value(value):
        print("Value: \(value)")
    case let .failed(error):
        print("Failed: \(error)")
    case .completed:
        print("Completed")
    case .interrupted:
        print("Interrupted")
    }
}
```

Alternatively, callbacks for the `value`, `failed`, `completed` and `interrupted` events can be provided which will be called when a corresponding event occurs.

```Swift
signal.observeValues { value in
    print("Value: \(value)")
}

signal.observeFailed { error in
    print("Failed: \(error)")
}

signal.observeCompleted {
    print("Completed")
}

signal.observeInterrupted {
    print("Interrupted")
}
```

### Injecting effects

Side effects can be injected on an event stream with the `on` operator without actually subscribing to it. 

```Swift
let producer = signalProducer
    .on(starting: { 
        print("Starting")
    }, started: { 
        print("Started")
    }, event: { event in
        print("Event: \(event)")
    }, value: { value in
        print("Value: \(value)")
    }, failed: { error in
        print("Failed: \(error)")
    }, completed: { 
        print("Completed")
    }, interrupted: { 
        print("Interrupted")
    }, terminated: { 
        print("Terminated")
    }, disposed: { 
        print("Disposed")
    })
```


Note that it is not necessary to provide all parameters - all of them are optional, you only need to provide callbacks for the events you care about.

Note that nothing will be printed until `producer` is started (possibly somewhere else).

## Operator composition

### Lifting

`Signal` operators can be _lifted_ to operate upon `SignalProducer`s using the
`lift` method.

This will create a new `SignalProducer` which will apply the given operator to
_every_ `Signal` created, just as if the operator had been applied to each
produced `Signal` individually.

## Transforming event streams

These operators transform an event stream into a new stream.

### Mapping

The `map` operator is used to transform the values in an event stream, creating
a new stream with the results.

```Swift
let (signal, observer) = Signal<String, Never>.pipe()

signal
    .map { string in string.uppercased() }
    .observeValues { value in print(value) }

observer.send(value: "a")     // Prints A
observer.send(value: "b")     // Prints B
observer.send(value: "c")     // Prints C
```

[Interactive visualisation of the `map` operator.](http://neilpa.me/rac-marbles/#map)

### Filtering

The `filter` operator is used to only include values in an event stream that
satisfy a predicate.

```Swift
let (signal, observer) = Signal<Int, Never>.pipe()

signal
    .filter { number in number % 2 == 0 }
    .observeValues { value in print(value) }

observer.send(value: 1)     // Not printed
observer.send(value: 2)     // Prints 2
observer.send(value: 3)     // Not printed
observer.send(value: 4)     // prints 4
```

[Interactive visualisation of the `filter` operator.](http://neilpa.me/rac-marbles/#filter)

### Aggregating

The `reduce` operator is used to aggregate a event stream’s values into a single
combined value. Note that the final value is only sent after the input stream
completes.

```Swift
let (signal, observer) = Signal<Int, Never>.pipe()

signal
    .reduce(1) { $0 * $1 }
    .observeValues { value in print(value) }

observer.send(value: 1)     // nothing printed
observer.send(value: 2)     // nothing printed
observer.send(value: 3)     // nothing printed
observer.sendCompleted()   // prints 6
```

The `collect` operator is used to aggregate a event stream’s values into
a single array value. Note that the final value is only sent after the input
stream completes.

```Swift
let (signal, observer) = Signal<Int, Never>.pipe()

signal
    .collect()
    .observeValues { value in print(value) }

observer.send(value: 1)     // nothing printed
observer.send(value: 2)     // nothing printed
observer.send(value: 3)     // nothing printed
observer.sendCompleted()   // prints [1, 2, 3]
```

[Interactive visualisation of the `reduce` operator.](http://neilpa.me/rac-marbles/#reduce)

## Combining event streams

These operators combine values from multiple event streams into a new, unified
stream.

### Combining latest values

The `combineLatest` function combines the latest values of two (or more) event
streams.

The resulting stream will only send its first value after each input has sent at
least one value. After that, new values on any of the inputs will result in
a new value on the output.

```Swift
let (numbersSignal, numbersObserver) = Signal<Int, Never>.pipe()
let (lettersSignal, lettersObserver) = Signal<String, Never>.pipe()

let signal = Signal.combineLatest(numbersSignal, lettersSignal)
signal.observeValues { next in print("Next: \(next)") }
signal.observeCompleted { print("Completed") }

numbersObserver.send(value: 0)      // nothing printed
numbersObserver.send(value: 1)      // nothing printed
lettersObserver.send(value: "A")    // prints (1, A)
numbersObserver.send(value: 2)      // prints (2, A)
numbersObserver.sendCompleted()  // nothing printed
lettersObserver.send(value: "B")    // prints (2, B)
lettersObserver.send(value: "C")    // prints (2, C)
lettersObserver.sendCompleted()  // prints "Completed"
```

The `combineLatest(with:)` operator works in the same way, but as an operator.

[Interactive visualisation of the `combineLatest` operator.](http://neilpa.me/rac-marbles/#combineLatest)

### Zipping

The `zip` function joins values of two (or more) event streams pair-wise. The
elements of any Nth tuple correspond to the Nth elements of the input streams.

That means the Nth value of the output stream cannot be sent until each input
has sent at least N values.

```Swift
let (numbersSignal, numbersObserver) = Signal<Int, Never>.pipe()
let (lettersSignal, lettersObserver) = Signal<String, Never>.pipe()

let signal = Signal.zip(numbersSignal, lettersSignal)
signal.observeValues { next in print("Next: \(next)") }
signal.observeCompleted { print("Completed") }

numbersObserver.send(value: 0)      // nothing printed
numbersObserver.send(value: 1)      // nothing printed
lettersObserver.send(value: "A")    // prints (0, A)
numbersObserver.send(value: 2)      // nothing printed
numbersObserver.sendCompleted()  // nothing printed
lettersObserver.send(value: "B")    // prints (1, B)
lettersObserver.send(value: "C")    // prints (2, C) & "Completed"

```

The `zipWith` operator works in the same way, but as an operator.

[Interactive visualisation of the `zip` operator.](http://neilpa.me/rac-marbles/#zip)

## Flattening event streams

The `flatten` operator transforms a stream-of-streams into a single stream - where values are forwarded from the inner stream in accordance with the provided `FlattenStrategy`. The flattened result becomes that of the outer stream type - i.e. a `SignalProducer`-of-`SignalProducer`s or `SignalProducer`-of-`Signal`s gets flattened to a `SignalProducer`, and likewise a `Signal`-of-`SignalProducer`s or `Signal`-of-`Signal`s gets flattened to a `Signal`.   

To understand why there are different strategies and how they compare to each other, take a look at this example and imagine the column offsets as time:

```Swift
let values = [
// imagine column offset as time
[ 1,    2,      3 ],
   [ 4,      5,     6 ],
         [ 7,     8 ],
]

let merge =
[ 1, 4, 2, 7,5, 3,8,6 ]

let concat = 
[ 1,    2,      3,4,      5,     6,7,     8]

let latest =
[ 1, 4,    7,     8 ]
```

Note, how the values interleave and which values are even included in the resulting array.


### Merging

The `.merge` strategy immediately forwards every value of the inner event streams to the outer event stream. Any failure sent on the outer event stream or any inner event stream is immediately sent on the flattened event stream and terminates it.

```Swift
let (lettersSignal, lettersObserver) = Signal<String, Never>.pipe()
let (numbersSignal, numbersObserver) = Signal<String, Never>.pipe()
let (signal, observer) = Signal<Signal<String, Never>, Never>.pipe()

signal.flatten(.merge).observeValues { print($0) }

observer.send(value: lettersSignal)
observer.send(value: numbersSignal)
observer.sendCompleted()

lettersObserver.send(value: "a")    // prints "a"
numbersObserver.send(value: "1")    // prints "1"
lettersObserver.send(value: "b")    // prints "b"
numbersObserver.send(value: "2")    // prints "2"
lettersObserver.send(value: "c")    // prints "c"
numbersObserver.send(value: "3")    // prints "3"
```

[Interactive visualisation of the `flatten(.merge)` operator.](http://neilpa.me/rac-marbles/#merge)

### Concatenating

The `.concat` strategy is used to serialize events of the inner event streams. The outer event stream is started observed. Each subsequent event stream is not observed until the preceeding one has completed. Failures are immediately forwarded to the flattened event stream.

```Swift
let (lettersSignal, lettersObserver) = Signal<String, Never>.pipe()
let (numbersSignal, numbersObserver) = Signal<String, Never>.pipe()
let (signal, observer) = Signal<Signal<String, Never>, Never>.pipe()

signal.flatten(.concat).observeValues { print($0) }

observer.send(value: lettersSignal)
observer.send(value: numbersSignal)
observer.sendCompleted()

numbersObserver.send(value: "1")    // nothing printed
lettersObserver.send(value: "a")    // prints "a"
lettersObserver.send(value: "b")    // prints "b"
numbersObserver.send(value: "2")    // nothing printed
lettersObserver.send(value: "c")    // prints "c"
lettersObserver.sendCompleted()     // nothing printed
numbersObserver.send(value: "3")    // prints "3"
numbersObserver.sendCompleted()     // nothing printed
```

[Interactive visualisation of the `flatten(.concat)` operator.](http://neilpa.me/rac-marbles/#concat)

### Switching to the latest

The `.latest` strategy forwards only values or a failure from the latest input event stream.

```Swift
let (lettersSignal, lettersObserver) = Signal<String, Never>.pipe()
let (numbersSignal, numbersObserver) = Signal<String, Never>.pipe()
let (signal, observer) = Signal<Signal<String, Never>, Never>.pipe()

signal.flatten(.latest).observeValues { print($0) }

observer.send(value: lettersSignal) // nothing printed
numbersObserver.send(value: "1")    // nothing printed
lettersObserver.send(value: "a")    // prints "a"
lettersObserver.send(value: "b")    // prints "b"
numbersObserver.send(value: "2")    // nothing printed
observer.send(value: numbersSignal) // nothing printed
lettersObserver.send(value: "c")    // nothing printed
numbersObserver.send(value: "3")    // prints "3"
```

## Working with errors

These operators are used to handle failures that might occur on an event stream, or perform operations that might fail on an event stream.

### Catching failures

The `flatMapError` operator catches any failure that may occur on the input event stream, then starts a new `SignalProducer` in its place.

```Swift
let (signal, observer) = Signal<String, NSError>.pipe()
let producer = SignalProducer(signal)

let error = NSError(domain: "domain", code: 0, userInfo: nil)

producer
    .flatMapError { _ in SignalProducer<String, Never>(value: "Default") }
    .startWithValues { print($0) }


observer.send(value: "First")     // prints "First"
observer.send(value: "Second")    // prints "Second"
observer.send(error: error)       // prints "Default"
```

### Failable transformations

`SignalProducer.attempt(_:)` allows you to turn a failable operation into an event stream.
The `attempt(_:)` and `attemptMap(_:)` operators allow you to perform failable operations or transformations on an event stream.

```swift
let dictionaryPath = URL(fileURLWithPath: "/usr/share/dict/words")

// Create a `SignalProducer` that lazily attempts the closure
// whenever it is started
let data = SignalProducer.attempt { try Data(contentsOf: dictionaryPath) }

// Lazily apply a failable transformation
let json = data.attemptMap { try JSONSerialization.jsonObject(with: $0) }

json.startWithResult { result in
    switch result {
    case let .success(words):
        print("Dictionary as JSON:")
        print(words)
    case let .failure(error):
        print("Couldn't parse dictionary as JSON: \(error)")
    }
}
```

### Retrying

The `retry` operator will restart the original `SignalProducer` on failure up to `count` times.

```Swift
var tries = 0
let limit = 2
let error = NSError(domain: "domain", code: 0, userInfo: nil)
let producer = SignalProducer<String, NSError> { (observer, _) in
    tries += 1
    if tries <= limit {
        observer.send(error: error)
    } else {
        observer.send(value: "Success")
        observer.sendCompleted()
    }
}

producer
    .on(failed: {e in print("Failure")})    // prints "Failure" twice
    .retry(upTo: 2)
    .start { event in
        switch event {
        case let .value(next):
            print(next)                     // prints "Success"
        case let .failed(error):
            print("Failed: \(error)")
        case .completed:
            print("Completed")
        case .interrupted:
            print("Interrupted")
        }
}
```

If the `SignalProducer` does not succeed after `count` tries, the resulting `SignalProducer` will fail. E.g., if  `retry(1)` is used in the example above instead of `retry(2)`, `"Failed: Error Domain=domain Code=0 "(null)""` will be printed instead of `"Success"`.

### Mapping errors

The `mapError` operator transforms the error of any failure in an event stream into a new error.

```Swift
enum CustomError: String, Error {
    case foo = "Foo Error"
    case bar = "Bar Error"
    case other = "Other Error"
}

let (signal, observer) = Signal<String, NSError>.pipe()

signal
    .mapError { (error: NSError) -> CustomError in
        switch error.domain {
        case "com.example.foo":
            return .foo
        case "com.example.bar":
            return .bar
        default:
            return .other
        }
    }
    .observeFailed { error in
        print(error.rawValue)
}

observer.send(error: NSError(domain: "com.example.foo", code: 42, userInfo: nil))    // prints "Foo Error"
```

### Promote

The `promoteError` operator promotes an event stream that does not generate failures into one that can.

```Swift
let (numbersSignal, numbersObserver) = Signal<Int, Never>.pipe()
let (lettersSignal, lettersObserver) = Signal<String, NSError>.pipe()

numbersSignal
    .promoteError(NSError.self)
    .combineLatest(with: lettersSignal)
```

The given stream will still not _actually_ generate failures, but this is useful
because some operators to [combine streams](#combining-event-streams) require
the inputs to have matching error types.


[Signal]: ReactivePrimitives.md#signal-a-unidirectional-stream-of-events
[SignalProducer]: ReactivePrimitives.md#signalproducer-deferred-work-that-creates-a-stream-of-values
[Observation]: FrameworkOverview.md#observation

