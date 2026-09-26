//
// --------------------------------------------------------------------------
// Threads.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// @noGCDCleanup flesh this out / think this through (Swift version as well)
///     Maybe make these 'require' instead of 'assert'

#import "Logging.h"

#define assertRunLoop(runLoop) mfassert(CFRunLoopGetCurrent() == (runLoop), @"assertRunLoop failure.")

/// @noGCDCleanup explain this here
///     Resources:
///         - Idea: Protect against accidental recursion into other update functions on the same state
///         - Idea: Protects against 'object reentrancy'
///         - Quick version of explanation in commit message 86adac6d8cad72dabd471f60ecbcba140531337d
///         - Claude idea for comment about why we didn't add `assertNoNestedUpdate` checks for 'query' functions: (It's because we want to check 'No more dispatch queues' refactor which couldn't have added new bugs in 'query' functions)
///             [Sep 2026] No `assertNoNestedUpdate` on queries (functions that only return state, without changing it).
///                 Queries can't corrupt state. A nested query can see half-updated state, but that isn't new:
///                 queries were already synchronous before the 'No more dispatch queues' refactor, so their timing didn't change.
///                 (Before, a nested query through the `sync` getters would even have deadlocked, so we know no code does this.)

#define assertNoNestedUpdate(updateDepthPtr) \
    mfassert(!*(updateDepthPtr), @"assertNoNestedUpdate failure."); \
    *(updateDepthPtr) += 1; /** Counter instead of boolean for more useful errors in release builds where mfassert() doesn't crash. Not sure if useful. [Sep 2026] */\
    __attribute__((cleanup(_decrementUpdateDepth))) int *__updateDepthPtr = (updateDepthPtr)

    static inline void _decrementUpdateDepth(int **updateDepth) { **updateDepth -= 1; }

/// @noGCDCleanup Add note about no `break` or `return` inside this (Mention Swift version, too)
#define allowNestedUpdate(updateDepthPtr) \
    for (int _once = ({ (*(updateDepthPtr))--; 1; }); _once; _once = ({ (*(updateDepthPtr))++; 0; }))

