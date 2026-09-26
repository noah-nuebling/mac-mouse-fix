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
#define assertNoNestedUpdate(updateDepthPtr) \
    mfassert(!*(updateDepthPtr), @"assertNoNestedUpdate failure."); \
    *(updateDepthPtr) += 1; /** Counter instead of boolean for more useful errors in release builds where mfassert() doesn't crash. Not sure if useful. [Sep 2026] */\
    __attribute__((cleanup(_decrementUpdateDepth))) int *__updateDepthPtr = (updateDepthPtr)

    static inline void _decrementUpdateDepth(int **updateDepth) { **updateDepth -= 1; }

/// @noGCDCleanup Note about no `break` or `return` inside this (Mention Swift version, too
#define allowNestedUpdate(updateDepthPtr) \
    for (int _once = ({ (*(updateDepthPtr))--; 1; }); _once; _once = ({ (*(updateDepthPtr))++; 0; }))

