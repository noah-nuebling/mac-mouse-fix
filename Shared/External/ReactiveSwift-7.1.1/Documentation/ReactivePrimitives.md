# Core Reactive Primitives

1. [`Signal`](#signal-a-unidirectional-stream-of-events)
1. [`Event`](#event-the-basic-transfer-unit-of-an-event-stream)
1. [`SignalProducer`](#signalproducer-deferred-work-that-creates-a-stream-of-values)
1. [`Property`](#property-an-observable-box-that-always-holds-a-value)
1. [`Action`](#action-a-serialized-worker-with-a-preset-action)
1. [`Lifetime`](#lifetime-limits-the-scope-of-an-observation)

#### `Signal`: a unidirectional stream of events.
The owner of a `Signal` has unilateral control of the event stream. Observers may register their interests in the future events at any time, but the observation would have no side effect on the stream or its owner.

A `Signal` is like a live TV feed — you can observe and react to the content, but you cannot have a side effect on the live feed or the TV station.

```swift
let channel: Signal<Program, Never> = tvStation.channelOne
channel.observeValues { program in ... }
```

*See also: [The `Signal` overview](FrameworkOverview.md#signals), [The `Signal` contract](APIContracts.md#the-signal-contract), [The `Signal` API reference](http://reactivecocoa.io/reactiveswift/docs/latest/Classes/Signal.html)*


#### `Event`: the basic transfer unit of an event stream.
A `Signal` may have any arbitrary number of events carrying a value, followed by an eventual terminal event of a specific reason.

An `Event` is like a frame in a one-time live feed — seas of data frames carry the visual and audio data, but the feed would eventually be terminated with a special frame to indicate "end of stream".

*See also: [The `Event` overview](FrameworkOverview.md#events), [The `Event` contract](APIContracts.md#the-event-contract), [The `Event` API reference](http://reactivecocoa.io/reactiveswift/docs/latest/Classes/Signal/Event.html)*

#### `SignalProducer`: deferred work that creates a stream of values.
`SignalProducer` defers work — of which the output is represented as a stream of values — until it is started. For every invocation to start the `SignalProducer`, a new `Signal` is created and the deferred work is subsequently invoked.

A `SignalProducer` is like an on-demand streaming service — even though the episode is streamed like a live TV feed, you can choose what you watch, when to start watching and when to interrupt it.


```swift
let frames: SignalProducer<VideoFrame, ConnectionError> = vidStreamer.streamAsset(id: tvShowId)
let interrupter = frames.start { frame in ... }
interrupter.dispose()
```

*See also: [The `SignalProducer` overview](FrameworkOverview.md#signal-producers), [The `SignalProducer` contract](APIContracts.md#the-signalproducer-contract), [The `SignalProducer` API reference](http://reactivecocoa.io/reactiveswift/docs/latest/Structs/SignalProducer.html)*

#### `Property`: an observable box that always holds a value.
`Property` is a variable that can be observed for its changes. In other words, it is a stream of values with a stronger guarantee than `Signal` — the latest value is always available, and the stream will never fail.

A `Property` is like the continuously updated current time offset of a video playback — the playback is always at a certain time offset at any time, and it would be updated by the playback logic as the playback continues.

```swift
let currentTime: Property<TimeInterval> = video.currentTime
print("Current time offset: \(currentTime.value)")
currentTime.signal.observeValues { timeBar.timeLabel.text = "\($0)" }
```

*See also: [The `Property` overview](FrameworkOverview.md#properties), [The `Property` contract](APIContracts.md#the-property-contract), [The property API reference](http://reactivecocoa.io/reactiveswift/docs/latest/Property.html)*

#### `Action`: a serialized worker with a preset action.
When invoked with an input, an `Action` applies the input and the latest state to the preset action, and pushes the output to any interested parties.

An `Action` is like an automatic vending machine — after inserting coins and choosing an option, the machine processes the order and eventually outputs your desired snack. Notice that you cannot have the machine serve two customers concurrently.

```swift
// Purchase from the vending machine with a specific option.
vendingMachine.purchase
    .apply(snackId)
    .startWithResult { result
        switch result {
        case let .success(snack):
            print("Snack: \(snack)")

        case let .failure(error):
            // Out of stock? Insufficient fund?
            print("Transaction aborted: \(error)")
        }
    }

// The vending machine.
class VendingMachine {
    let purchase: Action<Int, Snack, VendingMachineError>
    let coins: MutableProperty<Int>

    // The vending machine is connected with a sales recorder.
    init(_ salesRecorder: SalesRecorder) {
        coins = MutableProperty(0)
        purchase = Action(state: coins, enabledIf: { $0 > 0 }) { coins, snackId in
            return SignalProducer { observer, _ in
                // The sales magic happens here.
                // Fetch a snack based on its id
            }
        }

        // The sales recorders are notified for any successful sales.
        purchase.values.observeValues(salesRecorder.record)
    }
}
```

*See also: [The `Action` overview](FrameworkOverview.md#actions), [The `Action` API reference](http://reactivecocoa.io/reactiveswift/docs/latest/Classes/Action.html)*

#### `Lifetime`: limits the scope of an observation
It doesn't make sense for a `Signal` or `SignalProducer` to continue emitting values if there are no longer any observers.
Consider the video stream: once you stop watching the video, the stream can be automatically closed by providing a `Lifetime`:

```swift
class VideoPlayer {
  private let (lifetime, token) = Lifetime.make()

  func play() {
    let frames: SignalProducer<VideoFrame, ConnectionError> = ...
    frames.take(during: lifetime).start { frame in ... }
  }
}
```

*See also: [The `Lifetime` overview](FrameworkOverview.md#lifetimes), [The `Lifetime` API reference](http://reactivecocoa.io/reactiveswift/docs/latest/Classes/Lifetime.html)*
