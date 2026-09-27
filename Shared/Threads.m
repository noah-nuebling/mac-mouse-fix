//
// --------------------------------------------------------------------------
// Threads.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#if IS_MAIN_APP
    int _enableRunLoopAsserts = 1;
#elif IS_HELPER
    int _enableRunLoopAsserts = 0; /// See where this enabled in the Helper's entry point.
#endif
