//
// --------------------------------------------------------------------------
// Threads.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

@_transparent func assertRunLoop(_ runLoop: CFRunLoop) {
    mfassert(CFRunLoopGetCurrent() == (runLoop), "assertRunLoop failure.");
}

final class UpdateDepth { var updateDepth: Int = 0 } /// [Sep 2026] Use wrapper class around state since Swift can't do pointers. (& won't work says Opus 5.5)
@_transparent func assertNoNestedUpdate_Begin(_ updateDepth: UpdateDepth, file: StaticString = #file, line: UInt = #line) {
    mfassert(updateDepth.updateDepth == 0, "assertNoNestedUpdate failure.", file: file, line: line)
    updateDepth.updateDepth += 1;
}
@_transparent func assertNoNestedUpdate_End(_ updateDepth: UpdateDepth) {
    updateDepth.updateDepth -= 1;
}

@_transparent func allowNestedUpdate_Begin(_ updateDepth: UpdateDepth) { updateDepth.updateDepth -= 1; }
@_transparent func allowNestedUpdate_End(_ updateDepth: UpdateDepth) { updateDepth.updateDepth += 1; }
