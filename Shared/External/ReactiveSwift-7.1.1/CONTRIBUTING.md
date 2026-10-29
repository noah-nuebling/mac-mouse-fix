We love that you're interested in contributing to this project!

To make the process as painless as possible, we have just a couple of guidelines
that should make life easier for everyone involved.

## Prefer Pull Requests

If you know exactly how to implement the feature being suggested or fix the bug
being reported, please open a pull request instead of an issue. Pull requests are easier than
patches or inline code blocks for discussing and merging the changes.

If you can't make the change yourself, please open an issue after making sure
that one isn't already logged. We are also happy to help you in our Slack room (ping [@ReactiveCocoa](https://twitter.com/ReactiveCocoa) for an invitation).

## Contributing Code

Fork this repository, make it awesomer (preferably in a branch named for the
topic), send a pull request!

All code contributions should match our coding conventions ([Objective-c](https://github.com/github/objective-c-conventions) and [Swift](https://github.com/github/swift-style-guide)). If your particular case is not described in the coding convention, check the ReactiveCocoa codebase.

Thanks for contributing! :boom::camel:

## Documenting Code

Please follow these guidelines when documenting code using [Xcode's markup](https://developer.apple.com/library/mac/documentation/Xcode/Reference/xcode_markup_formatting_ref/):

- Expand lines up to 80 characters per line. If the line extends beyond 80 characters the next line must be indented at the previous markup delimiter's colon position + 1 space:

```
/// DO:
/// For the sake of the demonstration we will use the lorem ipsum text here.
/// Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin ullamcorper 
/// tempor dolor a cras amet.
///
/// - returns: Cras a convallis dolor, sed pellentesque mi. Integer suscipit
///            fringilla turpis in bibendum volutpat.
/// ...
/// DON'T
/// Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin ullamcorper tempor dolor a cras amet.
///
/// - returns: Cras a convallis dolor, sed pellentesque mi. Integer suscipit fringilla turpis in bibendum volutpat.
/// ...
/// DON'T II
/// Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin ullamcorper 
/// tempor dolor a cras amet.
///
/// - returns: Cras a convallis dolor, sed pellentesque mi. Integer suscipit
/// fringilla turpis in bibendum volutpat.
```

- Always use the `parameters` delimiter instead of the `parameter` delimiter even if a function has only one parameter:

```
/// DO:
/// - parameters:
///   - foo: Instance of `Foo`.
/// DON'T:
/// - parameter foo: Instance of `Foo`.
```

- Do not add a `return` delimiter to an initializer's markup:

```
/// DO:
/// Initialises instance of `Foo` with given arguments.
init(withBar bar: Bar = Bar.defaultBar()) {
    ...
/// DON'T:
/// Initialises instance of `Foo` with given arguments.
///
/// - returns: Initialized `Foo` with default `Bar`
init(withBar bar: Bar = Bar.defaultBar()) {
    ...
```

- Treat parameter declaration as a separate sentence/paragraph:

```
/// DO:
/// - parameters:
///   - foo: A foo for the function.
/// ...
/// DON'T:
/// - parameters:
///   - foo: foo for the function;
```

- Add one line between markup delimiters and no whitespace lines between a function's `parameters`:

```
/// DO:
/// - note: This is an amazing function.
///
/// - parameters:
///   - foo: Instance of `Foo`.
///   - bar: Instance of `Bar`.
///
/// - returns: Something magical.
/// ...
/// DON'T:
/// - note: Don't forget to breathe, it's important! 😎
/// - parameters:
///   - foo: Instance of `Foo`.
///   - bar: Instance of `Bar`.
/// - returns: Something claustrophobic.
```

- Use code voice to highlight symbols in descriptions, parameter definitions, return statments and elsewhere.

```
/// DO:
/// Create instance of `Foo` by passing it `Bar`.
///
/// - parameters:
///   - bar: Instance of `Bar`.
/// ...
/// DON'T:
/// Create instance of Foo by passing it Bar.
///
/// - parameters:
///   - bar: Instance of Bar.
```

- The `precondition`, `parameters` and `return` delimiters should come last in that order in the markup block before the method's signature.

```
/// DO:
/// Create instance of `Foo` by passing it `Bar`.
///
/// - note: The `foo` is not retained by the receiver.
///
/// - parameters:
///   - foo: Instance of `Foo`.
init(foo: Foo) {
/* ... */
/// DON'T
/// Create counter that will count down from `number`.
///
/// - parameters:
///   - number: Number to count down from.
///
/// - precondition: `number` must be non-negative.
init(count: Int)
```

- Use first person's active voice in present simple tense.

```
/// DO:
/// Do something magical and return pixie dust from `self`.
///
/// DON'T:
/// Does something magical and returns pixie dust from `self`.
```

