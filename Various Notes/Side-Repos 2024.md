# Side-Repos 2024

[Apr 2025] History: 
    In 2024 we created several side-repos, whose interesting code we're now trying to merge into Mac Mouse Fix, so we can forget about those side-repos.
    - `xcode-localization-screenshot-tests` & `xcode-localization-screenshot-fix`
        - Learn more at note `Automatic Localization Screenshots.md`
    - `objc-playground-2024`
        - [x] Merged all interesting code & info
            -> We can forget about this repo
        - Context: 
            This is the origin of `MFDataClass.m`, (our cmark-based) `MarkdownParser.m`, and `MFObserver.m`. 
            We merged `MFDataClass.m` and `MarkdownParser.m` much earlier, but we merged `MFObserver.m` in [Apr 2025].
            Also developed techniques for enabling nullability warnings in Xcode here, which we merged in [Apr 2025]. See `Xcode Nullability Settings.md`.
        - Link: https://github.com/noah-nuebling/objc-playground-2024
            - Readme.md contains more context
    - `EventLoggerForBrad`
        - [ ] Merged new Keyboard-Shortcut-Simulator
        - [x] Merged all the crazy macros
        - [x] Merged PrivateFunctions.m
        - Context: 
            - Originally an eventLogger I hacked together for a MMF user named Brad. But sorta evolved into a playground for CGEvents.
            - In 2024, here we developed a new Keyboard-Shortcut-Simulator, along with crazy macros, and PrivateFunctions.m (custom dynamic linker)
                We waited to merge it into MMF since MMF's master branch had diverted from the feature-strings-catalog branch.
            - [Apr 16 2025] We merged the crazy macros and PrivateFunctions.m. Still need to work on Keyboard-Shortcut-Simulator before merging it.
        
[Jul 2025]
    - In 2025, we created a `swiftui-test-tahoe-beta/` repo where we rewrote the scrolling tab of MMF in the style of macOS System Settings using 3 approaches: SwiftUI, Interface Builder, and pure objc+AppKit. 
        Nothing there is important enough to merge, but the if we rewrite the UI, we should reference this. The`mfl_` objc microframework and the `MFTargetActionObserver.m` implementations demonstrate interesting approaches. 
        Sidenote: In our fork of the Sparkle/modernize-update-alert branch, we reimplemented the SUUpdateAlert using an `sui_` microframework which follows the same idea as the`mfl_` one – maybe we can reference that, too, in the future.
    - Meta: Maybe this shouldn't be called "Side-Repos 2024" anymore now, since it includes a 2025 side-repo.
