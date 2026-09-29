//
// --------------------------------------------------------------------------
// Threads.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------

/// @noGCDCleanup move GlobalEventTapThread high level comments here. (Maybe merge files)

#import "Logging.h"

extern int _enableRunLoopAsserts;

/// @noGCDCleanup flesh this out / think this through (Swift version as well)
///     Maybe make these 'require' instead of 'assert'


#define assertRunLoop(runLoop) \
    if (_enableRunLoopAsserts) \
    mfassert(CFRunLoopGetCurrent() == (runLoop), @"assertRunLoop failure.")

/** Nested read/write protection.

    Overview/Explanation: [Sep 2026]
        When a function updates state, it temporarily leaves state invalid. When anything else reads/writes the state during invalid window, you get corruption. (or lost updates if parent update 'caches' state in stack variables or whatever before calling nested update.)
        This problem is also what thread race is. Serializing access (See `assertRunLoop`) mostly fixes this but not completely. Same issue can happen when function accidentally, in middle of its update, recurses into another function that tries to read/write the state.
        That's what the `readsState()` etc macros below are there to check against: They make sure state isn't read or written from a nested call while it may be invalid (and isn't made invalid while someone is still reading it.)
    When to use this / why we added this: [Sep 2026]
        In the core of the Helper like Scroll.m and TouchAnimator.swift, it's not easy to see that this corrupting kind of recursion doesn't happen.
        Historical reason [Sep 2026] After 'No more dispatch queues' refactor, we made a bunch of things that were previously deferred via `dispatch_async` into directly blocking calls.
        This has chance of introducing such recursion corruptions. Since we change so much stuff in the refactor, I thought it's good idea to add checks like this to be confident in correctness.
            However, after the refactor is done and everything works, maybe remove the checks, or feel ok to neglect to update these checks, because of deterministic nature making bugs not so bad anyways and maybe not worth complexity of these annotations:
                (When these corrupting recursions occur, they are deterministic, because everything is already serialized on one thread, and you can probably debug the corruption ok, even without having the readsState() / readsAndWritesState() checks.)
    Practical rules discovered (about when (not) to use this): [Sep 2026]
        - You can omit checks for a module, when you can see that nothing calls out in a way that could recurse during invalid-state window of an update. I think that's most code in MMF.
        - You can annotate any callout with `allowNestedReadOrWrite()` when it appears at the very start / end of an update function (before the update reads anything it relies on, or after its last write).
        - You can annotate any callout to another update function with `allowNestedReadOrWrite()` when the calling update function calls the nested one *directly* - then it's clearly intentional (We're trying to catch the accidental ones, that happen indirectly through recursion)
        - For non trivial cases of `allowNestedReadOrWrite()` explain where the call-tree re-enters the module, and maybe why that's ok here. (Non trivial cases, re-enter module indirectly through non-obvious recursion, and in the middle of another update of the same module.)
        - Every entry point to module that touches the state needs `readsState()` / `readsAndWritesState()` annotation. (Otherwise callouts can come back in without the tracker seeing it.)
            - Private helpers don't need `readsState()` / `readsAndWritesState()` annotation (they can only be called by entry points - where readsState() or readsAndWritesState() guarantees are already held)
        - Almost always use `readsAndWritesState()` (not `readsState()`):
            - Any mutated non-local variable is a 'write' (even caches)
            - All callouts could 'write' somewhere deep in their call-tree - so default to readsAndWritesState(), when there's any callouts unless all callouts are pure/read-only (when it's not obvious why they are pure, explain in comment) (obvious would be: callout to another function that only `readsState()`, logging function, maths routine with no side-effects, ...)
            - (Erring on side of readsAndWritesState() will only produce additional false positives, which you can opt out of with `allowNestedReadOrWrite()`, so should be harmless.)
        - You don't need to add readsState() / readsAndWritesState() to a function that just forwards to another function that is readsAndWritesState() (Leave a comment if non-obvious, we think comment is less cumbersom than `allowNestedReadOrWrite()` ritual as of [Sep 2026])
        What the checks cannot cover:
            If parent update changes state of submodule A, and then calls [submoduleB update] which itself updates submodule A's state again
            (indirectly from parent's perspective) that's basically the same issue, but our checks can't catch it, since the update
            to submodule A through [submoduleB update] doesn't go through parent module's tracker, (doesn't actually recurse back into the parent) even though submodule A's state is logically 'owned' by parent.
            (If you really wanted to prove correctness, it gets really complicated with the submodules - definitely not worth it)
        Alternative:
            - Restructure code such that in all update functions on some state S, you do all callouts before the first read or after the last write (before or after your update) - then it's easy to see that the corrupting recursion can't happen and you don't need the checks.
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
