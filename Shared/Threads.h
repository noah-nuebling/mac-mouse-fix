//
// --------------------------------------------------------------------------
// Threads.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Logging.h"

/// @noGCDCleanup flesh this out / think this through (Swift version as well)
#define assertRunLoop(runLoop) mfassert(CFRunLoopGetCurrent() == (runLoop), @"assertRunLoop failure.")
