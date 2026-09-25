//
// --------------------------------------------------------------------------
// Threads.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

func assertRunLoop(_ runLoop: CFRunLoop) {
    mfassert(CFRunLoopGetCurrent() == (runLoop), "assertRunLoop failure.");
}
