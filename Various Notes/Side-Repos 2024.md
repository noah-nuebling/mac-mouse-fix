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
        - Context: 
            - Originally an eventLogger I hacked together for a MMF user named Brad. But sorta evolved into a playground for CGEvents.
            - In 2024, here we developed a new Keyboard-Shortcut-Simulator
                We waited to merge it into MMF since MMF's master branch had diverted from the feature-strings-catalog branch.
                But in [Apr 2025] we merged the master and feature-strings-catalog branch and can now merge the Keyboard-Shortcut-Simulator.
            - Also developed a lotta macros here, ...
        
