//
// --------------------------------------------------------------------------
// Threads.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

@_transparent func assertRunLoop(_ runLoop: CFRunLoop) {
    if (_enableRunLoopAsserts != 0) {
        mfassert(CFRunLoopGetCurrent() == (runLoop), "assertRunLoop failure.");
    }
}

/// Nested read/write protection
///     Swift version of the macros in Threads.h (See there for explanation) [Sep 2026]
///     Usage example:
///         ```
///         readsState_Begin(tracker); defer { readsState_End(tracker) }
///         ...
///         allowNestedReadOrWrite_Begin(from: .readsState, tracker)
///         callback()
///         allowNestedReadOrWrite_End(from: .readsState, tracker)
///         ```

final class MFReadWriteTracker { var readerCount: Int = 0; var writerCount: Int = 0 }
enum MFReadWriteAccessType { case readsState; case readsAndWritesState }

@_transparent func readsState_Begin(_ tracker: MFReadWriteTracker, file: StaticString = #file, line: UInt = #line) {
    mfassert(tracker.writerCount == 0, "Nested read while state is being written.", file: file, line: line)
    tracker.readerCount += 1
}
@_transparent func readsState_End(_ tracker: MFReadWriteTracker) { tracker.readerCount -= 1 }

@_transparent func readsAndWritesState_Begin(_ tracker: MFReadWriteTracker, file: StaticString = #file, line: UInt = #line) {
    mfassert(tracker.readerCount == 0 && tracker.writerCount == 0, "Nested write while state is being read or written.", file: file, line: line)
    tracker.writerCount += 1
}
@_transparent func readsAndWritesState_End(_ tracker: MFReadWriteTracker) { tracker.writerCount -= 1 }

@_transparent func allowNestedReadOrWrite_Begin(from: MFReadWriteAccessType, _ tracker: MFReadWriteTracker) {
    if from == .readsState { tracker.readerCount -= 1 } else { tracker.writerCount -= 1 }
}
@_transparent func allowNestedReadOrWrite_End(from: MFReadWriteAccessType, _ tracker: MFReadWriteTracker) {
    if from == .readsState { tracker.readerCount += 1 } else { tracker.writerCount += 1 }
}
