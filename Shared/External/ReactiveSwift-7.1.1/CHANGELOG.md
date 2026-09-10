# master
*Please add new entries at the top.*

# 7.1.1
1. Bumped deployment target to iOS 11, tvOS 11, watchOS 4, macOS 10.13, per Xcode 14 warnings (#865, kudos to @lickel)
1. Explicitly declare `APPLICATION_EXTENSION_API_ONLY` for CocoaPods (#866, kudos to @lickel)

# 7.1.0
1. Add CI Release jobs on tag push (#862, kudos to @p4checo)
1. Fix some issues related to locking, bumped min OS versions to iOS 10, macOS 10.12, tvOS 10, watchOS 3 (#859, kudos to @mluisbrown)
1. Add `async` helpers to Schedulers (#857, kudos to @p4checo)
1. Add primary associated types to SignalProducerConvertible & SignalProducerProtocol (#855, kudos to @braker1nine)
2. Refactor Github Actions to cover more swift versions (#858, kudos to @braker1nine)
1. Use `OSAllocatedUnfairLock` instead of `os_unfair_lock` on supported Apple platforms (#856, kudos to @mluisbrown)

# 7.0.0
1. The UnidirectionalBinding operator `<~` returns non optional values. (#834, kudos to @NicholasTD07)

1. Fixed issue where `SingalProducer.try(upTo:interval:count:)` shares state between invocation of `start` on the same producer. (#829, kudos to @sebastiangrail)

1. `Signal.Event` is now marked as frozen enum. (#841, kudos to @NachoSoto)

# 6.7.0
# 6.7.0-rc1

1. New operator `SignalProducer.Type.interval(_:interval:on:)` for emitting elements from a given sequence regularly. (#810, kudos to @mluisbrown)

1. `Signal` offers two special variants for advanced users: unserialized and reentrant-unserialized. (#797)

   The input observer of these variants assume that mutual exclusion has been enforced by its callers.

   You can create these variants through four `Signal` static methods: `unserialized(_:)`, `unserializedPipe(_:)`, `reentrantUnserialized(_:)` and `reentrantUnserializedPipe(_:)`. These would be adopted by ReactiveCocoa UIKit bindings to improve interoperability with Loop, to tackle some legitimate recursive delivery scenarios (e.g. around first responder management), and also to reduce fine-grained locking in ReactiveCocoa.

   Note that the default behavior of `Signal` has not been changed — event serialization remains the default behavior.

1. `SignalProducer` offers an unserialized variant via `SignalProducer.unserialized(_:)`. (#797)

1. `TestScheduler` can now advanced its clock by `TimeInterval`. (#828, kudos to @carsten-wenderdel)

1. `Signal` and Properties now use fewer locks, which should translate into minor performance improvements. (#797)

1. Fixed spelling error in `Lifetime.Token` class documentation. (#835, kudos to @ansonj)

1. As a continued refactoring effort since ReactiveSwift 6.6.0, all unary `Signal` and `SignalProducer` operators have been migrated to a new internal representation.

    When debugging your application, the call stacks involving ReactiveSwift may now look cleaner, without the clutter of compiler-generated reabstraction thunks. See #799 for an example.

1. New operator `SignalProducer.take(until:)` that forwards any values until `shouldContinue` returns `false`. Equivalent to `take(while:)`, except it also forwards the last value that failed the check. (#839, kudos to @nachosoto)

# 6.6.1
1. Updated Carthage xcconfig dependency to 1.1 for proper building arm64 macOS variants. (#826, kudos to @MikeChugunov)

1. Fixed issue with `SignalProducer.Type.interval()` making Swift 5.3 a requirement. (#823 kudos to @mluisbrown)

# 6.6.0

1. Added the `SignalProducer.Type.interval()` operator for emitting values on a regular schedule. (#810, kudos to @mluisbrown)

1. When debugging your application, the call stacks involving ReactiveSwift may start to look cleaner and less cryptic. This is an on-going refactoring effort to improve the developer experience. See #799 for an example.

1. Bumped deployment target to iOS 9.0, per Xcode 12 warnings. (#818, kudos to @harleyjcooper)

1. Fixed a few deprecation warning when the project is being built. (#819, kudos to @apps4everyone)

# 6.5.0

1. Add `ExpressibleByNilLiteral` constraint to `OptionalProtocol` (#805, kudos to @nkristek)

1. Fixed a `SignalProducer.lift` issue which may leak intermediate signals. (#808)

1. Add variadic sugar for boolean static methods such as `Property.any(boolProperty1, boolProperty2, boolProperty3)` (#801, kudos to @fortmarek)


# 6.4.0
1. Bump min. deployment target to iOS 9 when using swift packages to silence Xcode 12 warnings. Update Quick & Nibmle to the latest version when using swift packages.

1. Fix a debug assertion in `Lock.try()` that could be raised in earlier OS versions (< iOS 10.0, < macOS 10.12). (#747, #788)

   Specifically, ReactiveSwift now recognizes `EDEADLK` as expected error code from `pthread_mutex_trylock` alongside `0`, `EBUSY` and `EAGAIN`.

# 6.3.0
1. `Property` and `MutableProperty` can now be used as property wrapper. Note that they remain a reference type container, so it may not be appropriate to use them in types requiring value semantics. (#781)
   ```swift
   class ViewModel {
     @MutableProperty var count: Int = 0

     func subscribe() {
       self.$count.producer.startWithValues {
         print("`count` has changed to \(count)")
       }
     }

     func increment() {
       print("count prior to increment: \(count)")
       self.$count.modify { $0 += 1 }
     }
   }
   ```

1. When `combineLatest` or `zip` over a sequence of `SignalProducer`s or `Property`s, you can now specify an optional `emptySentinel` parameter, which would be used when the sequence is empty.

   This becomes relevant, when the sequence of producers is calculated from some other Signal and the signal resulting from the joined producers is observed. If no value is sent when the sequence is empty, the observer gets terminated silently, and, e.g., the UI would not be updated.

  (#774, kudos to @rocketnik)

# 6.2.1

1. Improved performance of joining signals by a factor of around 5. This enables joining of 1000 and more signals in a reasonable amount of time.
1. Fixed `SignalProducer.debounce` operator that, when started more than once, would not deliver values on producers started after the first time. (#772, kudos to @gpambrozio)
1. `FlattenStrategy.throttle` is introduced. (#713, kudos to @inamiy)
1. Updated `README.md` to reflect Swift 5.1 compatibility and point snippets to 6.1.0 (#763, kudos to @Marcocanc)
1. Update travis to Xcode 11.1 and Swift 5.1 (#764, kudos @petrpavlik)
1. [SwiftPM] Add platforms (#761, kudos to @ikesyo)
1. Renamed `filterMap` to `compactMap` and deprecated `filterMap` (#746, kudos to @Marcocanc)

# 6.1.0

1. add possibility to use `all` and `any` operators with array of arguments (#735, kudos to @olejnjak)
   ```swift
   let property = Property.any([boolProperty1, boolProperty2, boolProperty3])
   ```
1. Fixed Result extensions ambiguity (#733, kudos to @nekrich)
1. Add `<~` binding operator to `Signal.Observer` (#635, kudos to @Marcocanc)

# 6.0.0

1. Dropped support for Swift 4.2 (Xcode 9)
2. Removed dependency on https://github.com/antitypical/Result (#702, kudos to @NachoSoto and @mdiep)

**Upgrade to 6.0.0**

* If you have used `Result` only as dependency of `ReactiveSwift`, remove all instances of `import Result`, `import enum Result.NoError` or `import struct Result.AnyError` and remove the `Result` Framework from your project.
* Replace all cases where `NoError` was used in a `Signal` or `SignalProducer` with `Never`
* Replace all cases where `AnyError` was used in a `Signal` or `SignalProducer` with `Swift.Error`

# 5.0.1

1. Fix warnings in Xcode 10.2

# 5.0.0

1. Support Swift 5.0 (Xcode 10.2) (#711, kudos to @ikesyo)
1. Dropped support for Swift 4.1 (Xcode 9)
1. Migrated from `hashValue` to `hash(into:)`, fixing deprecation warning in Swift 5 (#707, kudos to @ChristopherRogers)
1. New operator `materializeResults` and `dematerializeResults` (#679, kudos to @ra1028)
1. New convenience initializer for `Action` that takes a `ValidatingProperty` as its state (#637, kudos to @Marcocanc)
1. Fix legacy date implementation. (#683, kudos to @shoheiyokoyama)
1. New operator `scanMap`. (#695, kudos to @inamiy)

# 4.0.0

1. When unfair locks from libplatform are unavailable, ReactiveSwift now fallbacks to error checking Pthread mutexes instead of the default. Mitigations regarding issues with `pthread_mutex_trylock` have also been applied. (#654, kudos to @andersio)
1. Fix some documentation errors about Carthage usage (#655)
1. [CocoaPods] CocoaPods 1.4.0 is the minimum required version. (#651, kudos to @ikesyo)
1. `<~` bindings now works with optional left-hand-side operands. (#642, kudos to @andersio and @Ankit-Aggarwal)

   ```swift
   let nilTarget: BindingTarget<Int>? = nil

   // This is now a valid binding. Previously required manual
   // unwrapping in ReactiveSwift 3.x.
   nilTarget <~ notifications.map { $0.count }
   ```

# 4.0.0-rc.2

1. Support Swift 4.2 (Xcode 10) (#644, kudos to @ikesyo)

# 4.0.0-rc.1

1. `Lifetime` may now be manually ended using `Lifetime.Token.dispose()`, in addition to the existing when-token-deinitializes semantic. (#641, kudos to @andersio)
1. For Swift 4.1 and above, `BindingSource` conformances are required to have `Error` parameterized as exactly `NoError`. As a result, `Signal` and `SignalProducer` are now conditionally `BindingSource`. (#590, kudos to @NachoSoto and @andersio)
1. For Swift 4.1 and above, `Signal.Event` and `ActionError` are now conditionally `Equatable`. (#590, kudos to @NachoSoto and @andersio)
1. New method `collect(every:on:skipEmpty:discardWhenCompleted:)` which delivers all values that occurred during a time interval (#619, kudos to @Qata)
1. `debounce` now offers an opt-in behaviour to preserve the pending value when the signal or producer completes. You may enable it by specifying `discardWhenCompleted` as false (#287, kudos to @Qata)
1. Result now interoperates with SignalProducer n-ary operators as a constant producer (#606, kudos to @Qata)
1. New property operator: `filter` (#586, kudos to @iv-mexx)
1. New operator `merge(with:)` (#600, kudos to @ra1028)
1. New operator `map(value:)` (#601, kudos to @ra1028)
1. `SignalProducer.merge(with:)`, `SignalProducer.concat`, `SignalProducer.prefix`, `SignalProducer.then`, `SignalProducer.and`, `SignalProducer.or`, `SignalProducer.zip(with:)`, `SignalProducer.sample(with:)`, `SignalProducer.sample(on:)`, `SignalProducer.take(until:)`, `SignalProducer.take(untilReplacement:)`, `SignalProducer.skip(until:)`, `SignalProducer.flatMap`, `SignalProducer.flatMapError`, `SignalProducer.combineLatest(with:)`, `Signal.flatMap`, `Signal.flatMapError`, `Signal.withLatest(from:)` and `Property.init(initial:then:)` now accept `SignalProducerConvertible` conforming types (#610, #611, kudos to @1028)
1. Bag can be created with the initial elements now (#609, kudos to @ra1028)
1. Non-class types now can be conforms to ReactiveExtensionProvider (#636, kudos to @ra1028)

# 3.1.0
1. Fixed `schedule(after:interval:leeway:)` being cancelled when the returned `Disposable` is not retained. (#584, kudos to @jjoelson)

# 3.1.0-rc.1
1. Fixed a scenario of downstream interruptions being dropped. (#577, kudos to @andersio)

   Manual interruption of time shifted producers, including `delay`, `observe(on:)`, `throttle`, `debounce` and `lazyMap`, should discard outstanding events at best effort ASAP.

   But in ReactiveSwift 2.0 to 3.0, the manual interruption is ignored if the upstream producer has terminated. For example:

   ```swift
   // Completed upstream + `delay`.
   SignalProducer.empty
       .delay(10.0, on: QueueScheduler.main)
       .startWithCompleted { print("Value should have been discarded!") }
       .dispose()

   // Console(t+10): Value should have been discarded!
   ```

   The expected behavior has now been restored.

   Please note that, since ReactiveSwift 2.0, while the interruption is handled immediately, the `interrupted` event delivery is not synchronous — it generally respects the closest asynchronous operator applied, and delivers on that scheduler.

1. `SignalProducer.concat` now has an overload that accepts an error. (#564, kudos to @nmccann)

1. Fix some documentation errors (#560, kudos to @ikesyo)

# 3.0.0
1. Code Coverage is reenabled. (#553)
   For Carthage users, version 0.26.0 and later is required for building App Store compatible binaries.

# 3.0.0-rc.1
1. Fixed integer overflow for `DispatchTimeInterval` in FoundationExtensions.swift (#506)

# 3.0.0-alpha.1
1. `Signal` now uses `Lifetime` for resource management. (#404, kudos to @andersio)

   The `Signal` initialzer now accepts a generator closure that is passed with the input `Observer` and the `Lifetime` as its arguments. The original variant accepting a single-argument generator closure is now obselete. This is a source breaking change.

   ```swift
   // New: Add `Disposable`s to the `Lifetime`.
   let candies = Signal<U, E> { (observer: Signal<U, E>.Observer, lifetime: Lifetime) in
      lifetime += trickOrTreat.observe(observer)
   }

   // Obsolete: Returning a `Disposable`.
   let candies = Signal { (observer: Signal<U, E>.Observer) -> Disposable? in
      return trickOrTreat.observe(observer)
   }
   ```

1. `SignalProducer.startWithSignal` now returns the value of the setup closure. (#533, kudos to @Burgestrand)

# 2.1.0-alpha.2
1. Disabled code coverage data to allow app submissions with Xcode 9.0 (see https://github.com/Carthage/Carthage/issues/2056, kudos to @NachoSoto)

# 2.1.0-alpha.1
1. `Signal.Observer.action` has been deprecated. Use `Signal.Observer.send` instead. (#515)

1. Workaround an unexpected EGAGIN error being returned by pthread in 32-bit ARM debug builds. (#508)

1. The `SignalProducer` internals have undergone a significant refactoring, which bootstraps the effort to reduce the overhead of constant producers and producer compositions. (#487, kudos to @andersio)

# 2.0.1
1. Addressed the exceptionally high build time. (#495)

1. New method ``retry(upTo:interval:on:)``. This delays retrying on failure by `interval` until hitting the `upTo` limitation.

# 2.0.0-rc.3
1. `Lifetime.+=` which ties a `Disposable` to a `Lifetime`, is now part of the public API and is no longer deprecated.

1. Feedbacks from `isEnabled` to the state of the same `Action` no longer deadlocks if it does not constitute an infinite feedback loop. (#481, kudos to @andersio)

   Note that `isExecuting` already supports `Action` state feedback, and legitimate feedback loops would still deadlock.

# 2.0.0-rc.2
1. Fixed a deadlock upon disposal when combining operators, i.e. `zip` and `combineLatest`, are used. (#471, kudos to @stevebrambilla for catching the bug)

# 2.0.0-rc.1
1. If the input observer of a `Signal` deinitializes while the `Signal` has not yet terminated, an `interrupted` event would now be automatically sent. (#463, kudos to @andersio)

1. `ValidationResult` and `ValidatorOutput` have been renamed to `ValidatingProperty.Result` and `ValidatingProperty.Decision`, respectively. (#443)

1. Mitigated a race condition related to ARC in the `Signal` internal. (#456, kudos to @andersio)

1. Added new convenience initialisers to `Action` that make creating actions with state input properties easier. When creating an `Action` that is conditionally enabled based on an optional property, use the renamed `Action.init(unwrapping:execute:)` initialisers. (#455, kudos to @sharplet)

# 2.0.0-alpha.3
1. `combinePrevious` for `Signal` and `SignalProducer` no longer requires an initial value. The first tuple would be emitted as soon as the second value is received by the operator if no initial value is given. (#445, kudos to @andersio)

1. Fixed an impedance mismatch in the `Signal` internals that caused heap corruptions. (#449, kudos to @gparker42)

1. In Swift 3.2 or later, you may create `BindingTarget` for a key path of a specific object. (#440, kudos to @andersio)

# 2.0.0-alpha.2
1. In Swift 3.2 or later, you can use `map()` with the new Smart Key Paths. (#435, kudos to @sharplet)

1. When composing `Signal` and `SignalProducer` of inhabitable types, e.g. `Never` or `NoError`, ReactiveSwift now warns about operators that are illogical to use, and traps at runtime when such operators attempt to instantiate an instance. (#429, kudos to @andersio)

1. N-ary `SignalProducer` operators are now generic and accept any type that can be expressed as `SignalProducer`. (#410, kudos to @andersio)
   Types may conform to `SignalProducerConvertible` to be an eligible operand.

1. The performance of `SignalProducer` has been improved significantly. (#140, kudos to @andersio)

   All lifted `SignalProducer` operators no longer yield an extra `Signal`. As a result, the calling overhead of event delivery is generally reduced proportionally to the level of chaining of lifted operators.

1. `interrupted` now respects `observe(on:)`. (#140)

   When a produced `Signal` is interrupted, if `observe(on:)` is the last applied operator, `interrupted` would now be delivered on the `Scheduler` passed to `observe(on:)` just like other events.

1. Feedbacks from `isExecuting` to the state of the same `Action`, including all `enabledIf` convenience initializers, no longer deadlocks. (#400, kudos to @andersio)

1. `MutableProperty` now enforces exclusivity of access. (#419, kudos to @andersio)

   In other words, nested modification in `MutableProperty.modify` is now prohibited. Generally speaking, it should have extremely limited impact as in most cases the `MutableProperty` would have been deadlocked already.

1. `promoteError` can now infer the new error type from the context. (#413, kudos to @andersio)

# 2.0.0-alpha.1
This is the first alpha release of ReactiveSwift 2.0. It requires Swift 3.1 (Xcode 8.3).

## Changes
### Modified `Signal` lifetime semantics (#355)
The `Signal` lifetime semantics is modified to improve interoperability with memory debugging tools. ReactiveSwift 2.0 adopted a new `Signal` internal which does not exploit deliberate retain cycles that consequentially confuse memory debugging tools.

A `Signal` is now automatically and silently disposed of, when:

1. the `Signal`  is not retained and has no active observer; or
1.  **(New)** both the `Signal`  and its input observer are not retained.

It is expected that memory debugging tools would no longer report irrelevant negative leaks that were once caused by the ReactiveSwift internals.

### `SignalProducer` resource management (#334)
`SignalProducer` now uses `Lifetime` for resource management. You may observe the `Lifetime` for the disposal of the produced `Signal`.

```swift
let producer = SignalProducer<Int, NoError> { observer, lifetime in
    if let disposable = numbers.observe(observer) {
        lifetime.observeEnded(disposable.dispose)
    }
}
```

Two `Disposable`-accepting methods `Lifetime.Type.+=` and `Lifetime.add` are provided to aid migration, and are subject to removal in a future release.

### Signal and SignalProducer
1. All `Signal` and `SignalProducer` operators now belongs to the respective concrete types. (#304)

   Custom operators should extend the concrete types directly. `SignalProtocol` and `SignalProducerProtocol` should be used only for constraining associated types.

1. `combineLatest` and `zip` are optimised to have a constant overhead regardless of arity, mitigating the possibility of stack overflow. (#345)

1. `flatMap(_:transform:)` is renamed to `flatMap(_:_:)`. (#339)

1. `promoteErrors(_:)`is renamed to `promoteError(_:)`. (#408)

1. `Event` is renamed to `Signal.Event`. (#376)

1. `Observer` is renamed to `Signal.Observer`. (#376)

### Action

1. `Action(input:_:)`, `Action(_:)`, `Action(enabledIf:_:)` and `Action(state:enabledIf:_:)` are renamed to `Action(state:execute:)`, `Action(execute:)`, `Action(enabledIf:execute:)` and `Action(state:enabledIf:execute:)` respectively. (#325)

### Properties
1. The memory overhead of property composition has been considerably reduced. (#340)

### Bindings
1. The `BindingSource` now requires only a producer representation of `self`. (#359)

1. The `<~` operator overloads are now provided by `BindingTargetProvider`. (#359)

### Disposables
1. `SimpleDisposable` and `ActionDisposable` has been folded into `AnyDisposable`. (#412)

1. `CompositeDisposable.DisposableHandle` is replaced by `Disposable?`. (#363)

1. The `+=` operator overloads for `CompositeDisposable` are now hosted inside the concrete types. (#412)

### Bag

1. Improved the performance of `Bag`. (#354)

1. `RemovalToken` is renamed to `Bag.Token`. (#354)

### Schedulers

1. `Scheduler` gains a class bound. (#333)

### Lifetime

1. `Lifetime.ended` now uses the inhabitable `Never` as its value type. (#392)

### Atomic

1. `Signal` and `Atomic` now use `os_unfair_lock` when it is available. (#342)

## Additions
1. `FlattenStrategy.race` is introduced. (#233, kudos to @inamiy)

   `race` flattens whichever inner signal that first sends an event, and ignores the rest.

1. `FlattenStrategy.concurrent` is introduced. (#298, kudos to @andersio)

   `concurrent` starts and flattens inner signals according to the specified concurrency limit. If an inner signal is received after the limit is reached, it would be queued and drained later as the in-flight inner signals terminate.

1. New operators: `reduce(into:)` and `scan(into:)`. (#365, kudos to @ikesyo)

   These variants pass to the closure an `inout` reference to the accumulator, which helps the performance when a large value type is used, e.g. collection.

1. `Property(initial:then:)` gains overloads that accept a producer or signal of the wrapped value type when the value type is an `Optional`. (#396)

## Deprecations and Removals
1. The requirement `BindingSource.observe(_:during:)` and the implementations have been removed.

1. All Swift 2 (ReactiveCocoa 4) obsolete symbols have been removed.

1. All deprecated methods and protocols in ReactiveSwift 1.1.x are no longer available.

## Acknowledgement

Thank you to all of @ReactiveCocoa/reactiveswift and all our contributors, but especially to @andersio, @calebd, @eimantas, @ikesyo, @inamiy, @Marcocanc, @mdiep, @NachoSoto, @sharplet and @tjnet. ReactiveSwift is only possible due to the many hours of work that these individuals have volunteered. ❤️

# 1.1.3
## Deprecation
1. `observe(_:during:)` is now deprecated. It would be removed in ReactiveSwift 2.0.
    Use `take(during:)` and the relevant observation API of `Signal`, `SignalProducer` and `Property` instead. (#374)

# 1.1.2
## Changes
1. Fixed a rare occurrence of `interrupted` events being emitted by a `Property`. (#362)

# 1.1.1
## Changes
1. The properties `Signal.negated`, `SignalProducer.negated` and `Property.negated` are deprecated. Use its operator form `negate()` instead.

# 1.1
## Additions

#### General
1. New boolean operators: `and`, `or` and `negated`; available on `Signal<Bool, E>`, `SignalProducer<Bool, E>` and `Property<Bool, E>` types. (#160, kudos to @cristianames92)
2. New operator `filterMap`. (#232, kudos to @RuiAAPeres)
3. New operator `lazyMap(on:_:)`. It coalesces `value` events when they are emitted at a rate faster than the rate the given scheduler can handle. The transform is applied on only the coalesced and the uncontended values. (#240, kudos to @liscio)
4. New protocol `BindingTargetProvider`, which replaces `BindingTargetProtocol`. (#254, kudos to @andersio)

#### SignalProducer
5. New initializer `SignalProducer(_:)`, which takes a `@escaping () -> Value` closure. It is similar to `SignalProducer(value:)`, but it lazily evaluates the value every time the producer is started. (#240, kudos to @liscio)

#### Lifetime
6. New method `Lifetime.observeEnded(self:)`. This is now the recommended way to explicitly observe the end of a `Lifetime`. Use `Lifetime.ended` only if composition is needed. (#229, kudos to @andersio)
7. New factory method `Lifetime.make()`, which returns a tuple of `Lifetime` and `Lifetime.Token`. (#236, kudos to @sharplet)

#### Properties
8. `ValidatingProperty`: A mutable property that validates mutations before committing them. (#182, kudos to @andersio).
9. A new interactive UI playground: `ReactiveSwift-UIExamples.playground`. It demonstrates how `ValidatingProperty` can be used in an interactive form UI. (#182)

## Changes
1. Flattening a signal of `Sequence` no longer requires an explicit `FlattenStrategy`. (#199, kudos to @dmcrodrigues)
2. `BindingSourceProtocol` has been renamed to `BindingSource`. (#254)
3. `SchedulerProtocol` and `DateSchedulerProtocol` has been renamed to `Scheduler` and `DateScheduler`, respectively. (#257)
4. `take(during:)` now handles ended `Lifetime` properly. (#229)

## Deprecations
1. `AtomicProtocol` has been deprecated. (#279)
2. `ActionProtocol` has been deprecated. (#284)
3. `ObserverProtocol` has been deprecated. (#262)
4. `BindingTargetProtocol` has been deprecated. (#254)

# 1.0.1
## Changes
1. Fixed a couple of infinite feedback loops in `Action`. (#221)
2. Fixed a race condition of `Signal` which might result in a deadlock when a signal is sent a terminal event as a result of an observer of it being released. (#267)

Kudos to @mdiep, @sharplet and @andersio who helped review the pull requests.

# 1.0

This is the first major release of ReactiveSwift, a multi-platform, pure-Swift functional reactive programming library spun off from [ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa). As Swift continues to expand beyond Apple’s platforms, we hope that ReactiveSwift will see broader adoption. To learn more, please refer to ReactiveCocoa’s [CHANGELOG](https://github.com/ReactiveCocoa/ReactiveCocoa/blob/master/CHANGELOG.md).

Major changes since ReactiveCocoa 4 include:
- **Updated for Swift 3**

  APIs have been updated and renamed to adhere to the Swift 3 [API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).
- **Signal Lifetime Semantics**

  `Signal`s now live and continue to emit events only while either (a) they have observers or (b) they are retained. This clears up a number of unexpected cases and makes Signals much less dangerous.
- **Reactive Proxies**

  Types can now declare conformance to `ReactiveExtensionsProvider` to expose a `reactive` property that’s generic over `self`. This property hosts reactive extensions to the type, such as the ones provided on `NotificationCenter` and `URLSession`.
- **Property Composition**

  `Property`s can now be composed. They expose many of the familiar operators from `Signal` and `SignalProducer`, including `map`, `flatMap`, `combineLatest`, etc.
- **Binding Primitives**

  `BindingTargetProtocol` and `BindingSourceProtocol` have been introduced to allow binding of observable instances to targets. `BindingTarget` is a new concrete type that can be used to wrap a settable but non-observable property.
- **Lifetime**

  `Lifetime` is introduced to represent the lifetime of any arbitrary reference type. This can be used with the new `take(during:)` operator, but also forms part of the new binding APIs.
- **Race-free Action**

   A new `Action` initializer `Action(state:enabledIf:_:)` has been introduced. It allows the latest value of any arbitrary property to be supplied to the execution closure in addition to the input from `apply(_:)`, while having the availability being derived from the property.

   This eliminates a data race in ReactiveCocoa 4.x, when both the `enabledIf` predicate and the execution closure depend on an overlapping set of properties.

Extensive use of Swift’s `@available` declaration has been used to ease migration from ReactiveCocoa 4. Xcode should have fix-its for almost all changes from older APIs.

Thank you to all of @ReactiveCocoa/ReactiveSwift and all our contributors, but especially to @andersio, @liscio, @mdiep, @nachosoto, and @sharplet. ReactiveSwift is only possible due to the many hours of work that these individuals have volunteered. ❤️
