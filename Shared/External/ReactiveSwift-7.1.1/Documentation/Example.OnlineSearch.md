# Example: Online Searching

Let’s say you have a text field, and whenever the user types something into it,
you want to make a network request which searches for that query.

_Please note that the following examples use Cocoa extensions in [ReactiveCocoa][] for illustration._

#### Observing text edits

The first step is to observe edits to the text field, using a RAC extension to
`UITextField` specifically for this purpose:

```swift
let searchStrings = textField.reactive.continuousTextValues
```

This gives us a [Signal][] which sends values of type `String?`.

#### Making network requests

With each string, we want to execute a network request. ReactiveSwift offers an
`URLSession` extension for doing exactly that:

```swift
let searchResults = searchStrings
    .flatMap(.latest) { (query: String?) -> SignalProducer<(Data, URLResponse), AnyError> in
        let request = self.makeSearchRequest(escapedQuery: query)
        return URLSession.shared.reactive.data(with: request)
    }
    .map { (data, response) -> [SearchResult] in
        let string = String(data: data, encoding: .utf8)!
        return self.searchResults(fromJSONString: string)
    }
    .observe(on: UIScheduler())
```

This has transformed our producer of `String`s into a producer of `Array`s
containing the search results, which will be forwarded on the main thread
(using the [`UIScheduler`][Schedulers]).

Additionally, [`flatMap(.latest)`][flatMapLatest] here ensures that _only one search_—the
latest—is allowed to be running. If the user types another character while the
network request is still in flight, it will be cancelled before starting a new
one. Just think of how much code that would take to do by hand!

#### Receiving the results

Since the source of search strings is a `Signal` which has a hot signal semantic,
the transformations we applied are automatically evaluated whenever new values are
emitted from `searchStrings`.

Therefore, we can simply observe the signal using `Signal.observe(_:)`:

```swift
searchResults.observe { event in
    switch event {
    case let .value(results):
        print("Search results: \(results)")

    case let .failed(error):
        print("Search error: \(error)")

    case .completed, .interrupted:
        break
    }
}
```

Here, we watch for the `Value` [event][Events], which contains our results, and
just log them to the console. This could easily do something else instead, like
update a table view or a label on screen.

#### Handling failures

In this example so far, any network error will generate a `Failed`
[event][Events], which will terminate the event stream. Unfortunately, this
means that future queries won’t even be attempted.

To remedy this, we need to decide what to do with failures that occur. The
quickest solution would be to log them, then ignore them:

```swift
    .flatMap(.latest) { (query: String) -> SignalProducer<(Data, URLResponse), AnyError> in
        let request = self.makeSearchRequest(escapedQuery: query)

        return URLSession.shared.reactive
            .data(with: request)
            .flatMapError { error in
                print("Network error occurred: \(error)")
                return SignalProducer.empty
            }
    }
```

By replacing failures with the `empty` event stream, we’re able to effectively
ignore them.

However, it’s probably more appropriate to retry at least a couple of times
before giving up. Conveniently, there’s a [`retry`][retry] operator to do exactly that!

Our improved `searchResults` producer might look like this:

```swift
let searchResults = searchStrings
    .flatMap(.latest) { (query: String) -> SignalProducer<(Data, URLResponse), AnyError> in
        let request = self.makeSearchRequest(escapedQuery: query)

        return URLSession.shared.reactive
            .data(with: request)
            .retry(upTo: 2)
            .flatMapError { error in
                print("Network error occurred: \(error)")
                return SignalProducer.empty
            }
    }
    .map { (data, response) -> [SearchResult] in
        let string = String(data: data, encoding: .utf8)!
        return self.searchResults(fromJSONString: string)
    }
    .observe(on: UIScheduler())
```

#### Throttling requests

Now, let’s say you only want to actually perform the search periodically,
to minimize traffic.

ReactiveCocoa has a declarative `throttle` operator that we can apply to our
search strings:

```swift
let searchStrings = textField.reactive.continuousTextValues
    .throttle(0.5, on: QueueScheduler.main)
```

This prevents values from being sent less than 0.5 seconds apart.

To do this manually would require significant state, and end up much harder to
read! With ReactiveCocoa, we can use just one operator to incorporate _time_ into
our event stream.

#### Debugging event streams

Due to its nature, a stream's stack trace might have dozens of frames, which, more often than not, can make debugging a very frustrating activity.
A naive way of debugging, is by injecting side effects into the stream, like so:

```swift
let searchString = textField.reactive.continuousTextValues
    .throttle(0.5, on: QueueScheduler.main)
    .on(event: { print ($0) }) // the side effect
```

This will print the stream's [events][Events], while preserving the original stream behaviour. Both [`SignalProducer`][SignalProducer]
and [`Signal`][Signal] provide the `logEvents` operator, that will do this automatically for you:

```swift
let searchString = textField.reactive.continuousTextValues
    .throttle(0.5, on: QueueScheduler.main)
    .logEvents()
```

For more information and advance usage, check the [Debugging Techniques][] document.

[SignalProducer]: ReactivePrimitives.md#signalproducer-deferred-work-that-creates-a-stream-of-values
[Schedulers]: FrameworkOverview.md#Schedulers
[Signal]: ReactivePrimitives.md#signal-a-unidirectional-stream-of-events
[Events]: ReactivePrimitives.md#event-the-basic-transfer-unit-of-an-event-stream
[Debugging Techniques]: DebuggingTechniques.md

[retry]: BasicOperators.md#retrying
[flatMapLatest]: BasicOperators.md#combining-latest-values

[ReactiveCocoa]: https://github.com/ReactiveCocoa/ReactiveCocoa/#readme