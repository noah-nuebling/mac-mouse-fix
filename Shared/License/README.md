#  License Readme

## Fallback File

    Keep the `fallback_licenseinfo_config.json` file in sync with /licenseinfo/config.json on the mmf website.

## Async/Await

[Jun 25 2025]
    For the licensing code in MMF, we want to use async/await, but we also want *everything* to always run on the main thread.
    
    For MMF 3.0.4, I tried to do that with code like this `Task.detached(priority: .background), operation: { @MainActor in ...`
        However, this does NOT work, at all. This code is not guaranteed to execute on the main thread.
        
    Instead, there are 2 things we need to do:
    1. Make sure the initial entry into Swift Concurrency runs on the main thread
        - The internet says you can use `Task { await MainActor.run { ...` or `Task { @MainActor in ...` for this. However, ppl on the internet also said that `Task.detached { @MainActor in` works and I just observed that *not* working.
    2. Make sure that whenever `await` is used, the awaited code runs on the main thread.
        - Awaited code decides where it runs [1], so the only way to have it run on the main thread is to annotate *all* the async functions with @MainActor
            - Tip: you can also annotate the parent struct/class with @MainActor and all children will inherit @MainActor.

    Sidenote:
        - It seems that @MainActor has two effects: 
            1. On async functions, it causes them to be run on the main thread 
            2. On normal functions, it turns on some compiler checks to prevent you from calling it from a non-main thread. 

    References:
        - [1] Core rules for where things run and how @MainActor works: https://forums.swift.org/t/determining-whether-an-async-function-will-run-on-the-main-actor/60749/2
        - [2] Task.detached article: https://www.hackingwithswift.com/quick-start/concurrency/whats-the-difference-between-a-task-and-a-detached-task
    
    REMEMBER:
        - Do not use `Task.detached`
        - Annotate everything with `@MainActor`
        - Validate using `assert(Thread.isMainThread)`
