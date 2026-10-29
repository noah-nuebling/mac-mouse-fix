# RxSwift to ReactiveSwift Cheatsheet
This is a Cheatsheet for [RxSwift](https://github.com/ReactiveX/RxSwift) developers migrating to projects using [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift).

Inspired by the [RxSwift to Combine cheatsheet](https://github.com/CombineCommunity/rxswift-to-combine-cheatsheet)

## Basics

|                       | RxSwift                          | ReactiveSwift                              |
|-----------------------|----------------------------------|--------------------------------------------|
| Deployment Target     | iOS 9.0+                         | iOS 11.0+
| Platforms supported   | iOS, macOS, tvOS, watchOS, Linux | iOS, macOS, tvOS, watchOS, Linux
| Spec                  | Reactive Extensions (ReactiveX)  | Originally ReactiveX, with significant divergence
| Framework Consumption | Third-party                      | Third-party
| Maintained by         | Open-Source / Community          | Open-Source / Community
| UI Bindings           | RxCocoa                          | ReactiveCocoa


## Core Components

| RxSwift                   | ReactiveSwift                   | Notes                                                                                                                                                           |
|---------------------------|---------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| AnyObserver               | Signal.Observer                 | In practice, since there are no different Observer types, the AnyObserver concept is redundant in ReactiveSwift
| BehaviorRelay             | Property / MutableProperty      | Since `MutableProperty` can never have errors, we don't need a Relay specific version.
| BehaviorSubject           | Property / MutableProperty      |
| Completable               | Signal / SignalProducer         | A `Signal` or `SignalProducer` where `Value == Never` can only complete or emit an error event
| CompositeDisposable       | CompositeDisposable             |
| ConnectableObservableType | ❌                              |
| Disposable                | Disposable                      | In ReactiveSwift you rarely have to keep hold of Disposables or manage their lifetime manually, it's mostly automatic.
| DisposeBag                | CompositeDisposable             | The concepte of a DisposeBag is not really needed in ReactiveSwift, see above.
| Driver                    | ❌                              |
| Maybe                     | ❌                              | Trivial to create using `take(first: 1)`
| Observable                | Signal / SignalProducer         | Signal is a "hot" observable, and SignalProducer is a "cold" observable that will only emit values once a subscription is started
| Observer                  | Signal.Observer                 |
| PublishRelay              | ❌                              | Could be recreated easily in ReactiveSwift using the `flatMapError` operator on a Signal.pipe()
| PublishSubject            | Signal.pipe()                   | There is no Subject type, but `Signal.pipe()` returns a tuple of `(output: Signal, input: Signal.Observer)` which you use to both observe and send values
| ReplaySubject             | ❌                              | Can be created using the `replayLazily(upTo:)` operator
| ScheduledDisposable       | ❌                              |
| SchedulerType             | Scheduler                       |
| SerialDisposable          | SerialDisposable                |
| Signal                    | ❌                              | Not to be confused with ReactiveSwift `Signal` which is completely different
| Single                    | ❌                              | Could easily be created as an initializer for `SignalProducer`
| SubjectType               | Signal.pipe()                   | There is no Subject type, but `Signal.pipe()` returns a tuple of `(output: Signal, input: Signal.Observer)` which you use to both observe and send values
| TestScheduler             | TestScheduler                   |


## Operators

| RxSwift               | ReactiveSwift                                  | Notes                                                                                                    |
|-----------------------|------------------------------------------|----------------------------------------------------------------------------------------------------------|
| amb()                 | flatten(.race)                           |
| asObservable()        | ❌                                       | Not required in ReactiveSwift, although `Property.producer` and `Property.signal` are similar
| asObserver()          | ❌                                       |
| bind(to:)             | <~ operator (BindingTargets)             |
| buffer                | ❌                                       | (it used to exist, but was removed)
| catchError            | flatMapError                             |
| catchErrorJustReturn  | ❌                                       | Easy to create as `flatMapError { _ in SignalProducer<Value, Never> (value: value) }`
| combineLatest         | combineLatest                            |
| compactMap            | compactMap                               |
| concat                | concat / prefix                          |
| concatMap             | ❌                                       |
| create                | SignalProducer.init { }                  |
| debounce              | debounce                                 |
| debug                 | logEvents                                |
| deferred              | ❌                                       | Trivial to create
| delay                 | delay                                    |
| delaySubscription     | ❌                                       |
| dematerialize         | dematerialize                            |
| distinctUntilChanged  | skipRepeats                              |
| do                    | on                                       |
| elementAt             | ❌                                       |
| empty                 | SignalProducer.empty                     |
| enumerated            | ❌                                       |
| error                 | SignalProducer.init(error:)              |
| filter                | filter                                   |
| first                 | take(first:)                             | See also `take(last:)`
| flatMap               | flatMap(.merge)                          |
| flatMapFirst          | flatMap(.throttle)                       |
| flatMapLatest         | flatMap(.latest)                         |
| from(optional:)       | ❌                                       | Easy to create using `.init(.value: Value?).skipNil()`
| groupBy               | ❌                                       |
| ifEmpty(default:)     | ❌                                       |
| ifEmpty(switchTo:)    | ❌                                       |
| ignoreElements        | ❌                                       | Easy to create
| interval              | ❌                                       |
| just                  | SignalProducer.init(value:)              |
| map                   | map                                      |
| materialize           | materialize                              |
| merge                 | merge                                    |
| merge(maxConcurrent:) | ❌                                       |
| multicast             | replayLazily(upTo:)                      |
| never                 | SignalProducer.never                     |
| observeOn             | observe(on:)                             |
| of                    | SignalProducer.init(_ values:)           |
| publish               | ❌                                       |
| range                 | ❌                                       |
| reduce                | reduce                                   |
| refCount              | ❌                                       | Not meaningful in ReactiveSwift
| repeatElement         | repeat                                   |
| retry, retry(3)       | retry(upTo:)                             |
| retryWhen             | ❌                                       |
| sample                | sample(on:), sample(with:)               |
| scan                  | scan                                     |
| share                 | replayLazily(upTo:)                      |
| skip                  | skip(first:)                             |
| skipUntil             | skip(until:)                             |
| skipWhile             | skip(while:)                             |
| startWith             | prefix                                   |
| subscribe             | startWithValues / observeValues          |
| subscribeOn           | start(on:) / observe(on:)                |
| takeLast              | take(last:)                              |
| takeUntil             | take(until:)                             |
| throttle              | throttle                                 |
| timeout               | timeout                                  |
| timer                 | SignalProducer.timer                     |
| toArray               | collect                                  |
| window                | ❌                                       |
| withLatestFrom        | combineLatest                            |
| zip                   | zip                                      |
