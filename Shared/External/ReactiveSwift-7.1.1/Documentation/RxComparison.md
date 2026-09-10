# How does ReactiveSwift relate to RxSwift?
RxSwift is a Swift implementation of the [ReactiveX][] (Rx) APIs. While ReactiveCocoa
was inspired and heavily influenced by Rx, ReactiveSwift is an opinionated
implementation of [functional reactive programming][], and _intentionally_ not a
direct port like [RxSwift][].

ReactiveSwift differs from RxSwift/ReactiveX where doing so:

* Results in a simpler API
* Addresses common sources of confusion
* Matches closely to Swift, and sometimes Cocoa, conventions

The following are a few important differences, along with their rationales.

### Signals and SignalProducers (“hot” and “cold” observables)

One of the most confusing aspects of Rx is that of [“hot”, “cold”, and “warm”
                                                    observables](http://introtorx.com/Content/v1.0.10621.0/14_HotAndColdObservables.html) (event streams).

In short, given just a method or function declaration like this, in C#:

```csharp
IObservable<string> Search(string query)
```

… it is **impossible to tell** whether subscribing to (observing) that
`IObservable` will involve side effects. If it _does_ involve side effects, it’s
also impossible to tell whether _each subscription_ has a side effect, or if only
the first one does.

This example is contrived, but it demonstrates **a real, pervasive problem**
that makes it extremely hard to understand Rx code (and pre-3.0 ReactiveCocoa
code) at a glance.

**ReactiveSwift** addresses this by distinguishing side effects with the separate
[`Signal`][Signal] and [`SignalProducer`][SignalProducer] types. Although this
means there’s another type to learn about, it improves code clarity and helps
communicate intent much better.

In other words, **ReactiveSwift’s changes here are [simple, not
easy](http://www.infoq.com/presentations/Simple-Made-Easy)**.

### Typed errors

When [Signals][Signal] and [SignalProducers][SignalProducer] are allowed to [fail][Events] in ReactiveSwift,
the kind of error must be specified in the type system. For example,
`Signal<Int, AnyError>` is a signal of integer values that may fail with an error
of type `AnyError`.

More importantly, RAC allows the special type `Never` to be used instead,
which _statically guarantees_ that an event stream is not allowed to send a
failure. **This eliminates many bugs caused by unexpected failure events.**

In Rx systems with types, event streams only specify the type of their
values—not the type of their errors—so this sort of guarantee is impossible.

### Naming

In most versions of Rx, Streams over time are known as `Observable`s, which
parallels the `Enumerable` type in .NET. Additionally, most operations in Rx.NET
borrow names from [LINQ](https://msdn.microsoft.com/en-us/library/bb397926.aspx),
which uses terms reminiscent of relational databases, like `Select` and `Where`.

**ReactiveSwift**, on the other hand, focuses on being a native Swift citizen
first and foremost, following the [Swift API Guidelines][] as appropriate. Other
naming differences are typically inspired by significantly better alternatives
from [Haskell](https://www.haskell.org) or [Elm](http://elm-lang.org) (which is the primary source for the “signal” terminology).

### UI programming

Rx is basically agnostic as to how it’s used. Although UI programming with Rx is
very common, it has few features tailored to that particular case.

ReactiveSwift takes a lot of inspiration from [ReactiveUI](http://reactiveui.net/),
including the basis for [Actions][].

Unlike ReactiveUI, which unfortunately cannot directly change Rx to make it more
friendly for UI programming, **ReactiveSwift has been improved many times
specifically for this purpose**—even when it means diverging further from Rx.

[Actions]: FrameworkOverview.md#actions
[Events]: FrameworkOverview.md#events
[Schedulers]: FrameworkOverview.md#schedulers
[SignalProducer]: FrameworkOverview.md#signal-producers
[Signal]: FrameworkOverview.md#signals
[functional reactive programming]: https://en.wikipedia.org/wiki/Functional_reactive_programming
[ReactiveX]: https://reactivex.io/
[RxSwift]: https://github.com/ReactiveX/RxSwift/#readme
[Swift API Guidelines]: https://swift.org/documentation/api-design-guidelines/
