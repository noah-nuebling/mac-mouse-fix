//
// --------------------------------------------------------------------------
// Threads.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------


/// @noGCDCleanup flesh this out / think this through (Swift version as well)
///     Maybe make these 'require' instead of 'assert'

#import "Logging.h"

extern int _enableRunLoopAsserts;

#define assertRunLoop(runLoop) \
    if (_enableRunLoopAsserts) \
    mfassert(CFRunLoopGetCurrent() == (runLoop), @"assertRunLoop failure.")

/** Nested read/write protection.

    Overview/Explanation: [Sep 2026]
        When a function updates state, it temporarily leaves state invalid. When anything else reads/writes the state during invalid window, you get corruption. (or lost updates if parent update 'caches' state in stack variables or whatever before calling nested update.)
        This problem is also what thread race is. Serializing access (See `assertRunLoop`) mostly fixes this but not completely. Same issue can happen when function accidentally, in middle of its update, recurses into another function that tries to read/write the state.
        That's what the `readsState()` etc macros below are there to check against: They make sure state isn't read or written from a nested call while it may be invalid (and isn't made invalid while someone is still reading it.)
    When not to use this: [Sep 2026]
        When you can see that nothing calls out in a way that could recurse during invalid-state window of an update, you don't need to use this. I think that's most code in MMF.
        Practical rules discovered (about when not to use this):
            - When a callout is at the very start / end of an update function (before the update reads anything it relies on, or after its last write) it's guaranteed to be fine, and callout can be annotated with `allowNestedReadOrWrite()`.
            - You don't need to add readsState() / readsAndWritesState() to private helper functions that are clearly only called where readsState() or readsAndWritesState() guarantees are already held by all callers.
            - When an update function directly calls another update function, it's clearly intentional and obvious and can be annotated with `allowNestedReadOrWrite()`. (We're trying to catch the accidental ones, that happen indirectly)
        Alternative:
            - Restructure code such that in all update functions on some state, you do all callouts before the first read or after the last write (before or after your update) - then it's easy to see that the corrupting recursion can't happen and you don't need the checks.
    When to use this / why we added this: [Sep 2026]
        In the core of the Helper like Scroll.m and TouchAnimator.swift, it's not easy to see that this corrupting kind of recursion doesn't happen.
        Historical reason [Sep 2026] After 'No more dispatch queues' refactor, we made a bunch of things that were previously deferred via `dispatch_async` into directly blocking calls.
        This has chance of introducing such recursion corruptions. Since we change so much stuff in the refactor, I thought it's good idea to add checks like this to be confident in correctness.
            However, after the refactor is done and everything works, maybe remove the checks, or feel ok to neglect to add them to stuff, because of `deterministic` nature making bugs not so bad anyways and maybe not worth complexity of these annotations:
                (When these corrupting recursions occur, they are deterministic, because everything is serialized on one thread, and you can probably debug the corruption ok, even without having the readsState() / readsAndWritesState() checks.)
 */

NS_SWIFT_UNAVAILABLE("")
typedef struct { int readerCount; int writerCount; } MFReadWriteTracker;

#define readsState(tracker) \
    mfassert(!(tracker)->writerCount, @"Nested read while state is being written."); \
    (tracker)->readerCount += 1; \
    __attribute__((cleanup(__decrementInt))) int *__readerWriterCount = &(tracker)->readerCount

#define readsAndWritesState(tracker) \
    mfassert(!(tracker)->readerCount && !(tracker)->writerCount, @"Nested write while state is being read or written."); \
    (tracker)->writerCount += 1; \
    __attribute__((cleanup(__decrementInt))) int *__readerWriterCount = &(tracker)->writerCount

/// @noGCDCleanup Add note about no `break` or `return` inside this (Mention Swift version, too)
#define allowNestedReadOrWrite() \
    for (int _once = ({ (*__readerWriterCount)--; 1; }); _once; _once = ({ (*__readerWriterCount)++; 0; }))

    NS_SWIFT_UNAVAILABLE("")
    static inline void __decrementInt(int **someInt) { **someInt -= 1; }
