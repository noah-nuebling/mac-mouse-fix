#  License Readme

## Fallback File

    Keep the `fallback_licenseinfo_config.json` file in sync with /licenseinfo/config.json on the mmf website.

## Future Plans – Fully Offline Licenses (Bought From Stripe) [Jan 2026]
    (Not sure I wrote about this somewhere else [Jan 2026])
    
    Scheme: 
        First  part of the license key is a license id (counter)
        Second part of the license key is a signature
        (The app itself would contain a public key, that could verify the counter against the signature.)
    
        Length
            - Claude says 128 bits is enough for very good security.
                - Examples / encodings
                    - Hex:        7A3F9C2E8B1D4F6A7C3E9B2D8F1A4C6E            (-> 32 chars, -> Nice)
                    - Emoji:      🦆🌵🔥🎺🦑🌙🍕🎸🐙🪐🦋🎭🌺                (-> 13 chars, -> Fun, -> Recognizable, -> Somewhat hand-enterable)
                    - Braille:    ⠓⠊⠑⠗⠕⠛⠇⠽⠏⠓⠊⠑⠎⠂⠃⠁                          (-> 16 chars, -> Spooky, -> Compact)
                    - Dashes:     7A3F-9C2E-8B1D-4F6A-7C3E-9B2D-8F1A-4C6E     (-> 32 chars, -> hand-typeable, -> Feels too busy at this length)
            - Lower than 128?: If we go lower than 128 it might be somewhat easy to keygen says Claude. Not sure what the right tradeoff is. 
                Thought: Keygen is worse than people uploading cracked app (since cracked app won't get cracked updates)
                Also see: Windows XP discussion below.
                
        Notes: 
            - Windows XP used a similar scheme for their license keys (Says Claude)
                - Length: 25 (XXXXX-XXXXX-XXXXX-XXXXX-XXXXX – I think this is the MS key format to this day)
                - Bits: 55 (Says Claude, I don't really understand)
                - Cracking difficulty: Private keys was computed in "6 hours on a Celeron 800".
                    -> Does that mean we also shouldn't care as much about cracking / keygen? 
                - "Sparsity" stuff: "Microsoft limited the value of the signature to 55 bits in order to reduce the amount of matching product keys"
                    -> I don't understand this. 

        Sources:
            - This Claude conversation: https://claude.ai/share/cc16b141-f206-4c0a-a4f1-07cf5cf74515
                -> At the end, Claude says it was confused the whole time, and was saying wrong things about the length and security of the keys.
            - XPKeygen: https://github.com/Endermanch/XPKeygen

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
