<p align="center">
	<a href="https://github.com/ReactiveCocoa/ReactiveSwift/"><img src="Logo/PNG/logo-Swift.png" alt="ReactiveSwift" /></a><br /><br />
	Streams of values over time. Tailored for Swift.<br /><br />
	<a href="http://reactivecocoa.io/reactiveswift/docs/latest/"><img src="Logo/PNG/Docs.png" alt="Latest ReactiveSwift Documentation" width="143" height="40" /></a> <a href="http://reactivecocoa.io/slack/"><img src="Logo/PNG/JoinSlack.png" alt="Join the ReactiveSwift Slack community." width="143" height="40" /></a>
</p>
<br />

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](#carthage) [![CocoaPods compatible](https://img.shields.io/cocoapods/v/ReactiveSwift.svg)](#cocoapods) [![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-orange.svg)](#swift-package-manager) [![GitHub release](https://img.shields.io/github/release/ReactiveCocoa/ReactiveSwift.svg)](https://github.com/ReactiveCocoa/ReactiveSwift/releases) ![Swift 5.1](https://img.shields.io/badge/Swift-5.1-orange.svg) ![platforms](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Linux-lightgrey.svg)

🚄 [Release Roadmap](#release-roadmap)

## Getting Started

Learn about the **[Core Reactive Primitives][]** in ReactiveSwift, and **[Basic Operators][]** available offered by these primitives.

### Extended modules

<table>
<tr>
	<th>Module</th>
	<th>Repository</th>
	<th>Description</th>
</tr>
<tr>
	<td>ReactiveCocoa</td>
	<td>
		<a href="https://github.com/ReactiveCocoa/ReactiveCocoa">ReactiveCocoa/ReactiveCocoa</a>
		<br />
		<a href="https://github.com/ReactiveCocoa/ReactiveCocoa/releases"><img src="https://img.shields.io/github/release/ReactiveCocoa/ReactiveCocoa.svg" /><a>
	</td>
	<td><p>Extend Cocoa frameworks and Objective-C runtime APIs with ReactiveSwift bindings and extensions.</p></td>
</tr>
<tr>
	<td>Loop</td>
	<td>
		<a href="https://github.com/ReactiveCocoa/Loop">ReactiveCocoa/Loop</a>
		<br />
		<a href="https://github.com/ReactiveCocoa/Loop/releases"><img src="https://img.shields.io/github/release/ReactiveCocoa/Loop.svg" /><a>
	</td>
	<td><p>Composable unidirectional data flow with ReactiveSwift.</p></td>
</tr>
<tr>
	<td>ReactiveSwift Composable Architecture</td>
	<td>
		<a href="https://github.com/trading-point/reactiveswift-composable-architecture">trading-point/reactiveswift-composable-architecture</a>
		<br />
		<a href="https://github.com/trading-point/reactiveswift-composable-architecture/releases"><img src="https://img.shields.io/github/release/trading-point/reactiveswift-composable-architecture.svg" /><a>
	</td>
	<td><p>The <a href="https://github.com/pointfreeco/swift-composable-architecture">Pointfree Composable Architecture</a> using ReactiveSwift instead of Combine.</p></td>
</tr>
</table>

## What is ReactiveSwift in a nutshell?
__ReactiveSwift__ offers composable, declarative and flexible primitives that are built around the grand concept of ___streams of values over time___.

These primitives can be used to uniformly represent common Cocoa and generic programming patterns that are fundamentally an act of observation, e.g. delegate pattern, callback closures, notifications, control actions, responder chain events, [futures/promises](https://en.wikipedia.org/wiki/Futures_and_promises) and [key-value observing](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/KeyValueObserving/KeyValueObserving.html) (KVO).

Because all of these different mechanisms can be represented in the _same_ way,
it’s easy to declaratively compose them together, with less spaghetti
code and state to bridge the gap.

## References

1. **[API Reference][]**

1. **[API Contracts][]**

   Contracts of the ReactiveSwift primitives, Best Practices with ReactiveSwift, and Guidelines on implementing custom operators.

1. **[Debugging Techniques][]**

1. **[RxSwift Migration Cheatsheet][]**

## Installation

ReactiveSwift supports macOS 10.13+, iOS 11.0+, watchOS 4.0+, tvOS 11.0+ and Linux.

#### Carthage

If you use [Carthage][] to manage your dependencies, simply add
ReactiveSwift to your `Cartfile`:

```
github "ReactiveCocoa/ReactiveSwift" ~> 6.1
```

If you use Carthage to build your dependencies, make sure you have added `ReactiveSwift.framework` to the "_Linked Frameworks and Libraries_" section of your target, and have included them in your Carthage framework copying build phase.

#### CocoaPods

If you use [CocoaPods][] to manage your dependencies, simply add
ReactiveSwift to your `Podfile`:

```
pod 'ReactiveSwift', '~> 6.1'
```

#### Swift Package Manager

If you use Swift Package Manager, simply add ReactiveSwift as a dependency
of your package in `Package.swift`:

```
.package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "6.1.0")
```

#### Git submodule

 1. Add the ReactiveSwift repository as a [submodule][] of your
    application’s repository.
 1. Run `git submodule update --init --recursive` from within the ReactiveCocoa folder.
 1. Drag and drop `ReactiveSwift.xcodeproj` into your application’s Xcode
    project or workspace.
 1. On the “General” tab of your application target’s settings, add
    `ReactiveSwift.framework` to the “Embedded Binaries” section.
 1. If your application target does not contain Swift code at all, you should also
    set the `EMBEDDED_CONTENT_CONTAINS_SWIFT` build setting to “Yes”.

## Playground

We also provide a Playground, so you can get used to ReactiveCocoa's operators. In order to start using it:

 1. Clone the ReactiveSwift repository.
 1. Retrieve the project dependencies using one of the following terminal commands from the ReactiveSwift project root directory:
     - `git submodule update --init --recursive` **OR**, if you have [Carthage][] installed
     - `carthage checkout`
 1. Open `ReactiveSwift.xcworkspace`
 1. Build `ReactiveSwift-macOS` scheme
 1. Finally open the `ReactiveSwift.playground`
 1. Choose `View > Show Debug Area`

## Have a question?
If you need any help, please visit our [GitHub issues][] or [Stack Overflow][]. Feel free to file an issue if you do not manage to find any solution from the archives.

## Release Roadmap
**Current Stable Release:**<br />[![GitHub release](https://img.shields.io/github/release/ReactiveCocoa/ReactiveSwift.svg)](https://github.com/ReactiveCocoa/ReactiveSwift/releases)

### Plan of Record
#### ABI stability release
ReactiveSwift has no plan to declare ABI and module stability at the moment. It will continue to be offered as a source only dependency for the foreseeable future.

[Core Reactive Primitives]: Documentation/ReactivePrimitives.md
[Basic Operators]: Documentation/BasicOperators.md
[How does ReactiveSwift relate to RxSwift?]: Documentation/RxComparison.md
[API Contracts]: Documentation/APIContracts.md
[API Reference]: http://reactivecocoa.io/reactiveswift/docs/latest/
[Debugging Techniques]: Documentation/DebuggingTechniques.md
[RxSwift Migration Cheatsheet]: Documentation/RxCheatsheet.md
[Online Searching]: Documentation/Example.OnlineSearch.md
[_UI Examples_ playground]: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/ReactiveSwift-UIExamples.playground/Pages/ValidatingProperty.xcplaygroundpage/Contents.swift

[`Action`]: Documentation/ReactivePrimitives.md#action-a-serialized-worker-with-a-preset-action
[`SignalProducer`]: Documentation/ReactivePrimitives.md#signalproducer-deferred-work-that-creates-a-stream-of-values
[`Signal`]: Documentation/ReactivePrimitives.md#signal-a-unidirectional-stream-of-events
[`Property`]: Documentation/ReactivePrimitives.md#property-an-observable-box-that-always-holds-a-value

[ReactiveCocoa]: https://github.com/ReactiveCocoa/ReactiveCocoa/#readme

[Carthage]: https://github.com/Carthage/Carthage/#readme
[CocoaPods]: https://cocoapods.org/
[submodule]: https://git-scm.com/docs/git-submodule

[GitHub issues]: https://github.com/ReactiveCocoa/ReactiveSwift/issues?q=is%3Aissue+label%3Aquestion+
[Stack Overflow]: http://stackoverflow.com/questions/tagged/reactive-cocoa

[Looking for the Objective-C API?]: https://github.com/ReactiveCocoa/ReactiveObjC/#readme
[Still using Swift 2.x?]: https://github.com/ReactiveCocoa/ReactiveCocoa/tree/v4.0.0
