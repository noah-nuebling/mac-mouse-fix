//
// --------------------------------------------------------------------------
// Logging.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Define DDLogXYZ
///     This is separate from the C implementation because Swift can't import function-like C macros
///     This is slow:
///         Would be more efficient to have `message` be the format string instead of `"%{public}s"`, but that's not possible since this needs to be a drop-in replacement for CocoaLumberjack which uses string interpolation. So we do the @autoclosure stuff to keep it somewhat efficient.
///             When I did the equivalent for objc, (Calling [NSString stringWithFormat:] and passing the result into oslog) gestures became very unresponsive (On M4) and CPU usage tripled.
///             I think the only way CocoaLumberjack kept this responsive is by using a background thread.
///             Doing the inefficient thing in Swift seems ok in practise. I suppose we don't use it much on hot paths.


@inlinable func DDLogError(_ message: @autoclosure () -> String)   { if OSLog.default.isEnabled(type: .fault)     { os_log(.fault,   log: OSLog.default, "%{public}s", message()); } }
@inlinable func DDLogWarn(_ message: @autoclosure () -> String)    { if OSLog.default.isEnabled(type: .error)     { os_log(.error,   log: OSLog.default, "%{public}s", message()); } }
@inlinable func DDLogInfo(_ message: @autoclosure () -> String)    { if OSLog.default.isEnabled(type: .info)      { os_log(.info,    log: OSLog.default, "%{public}s", message()); } }
@inlinable func DDLogDebug(_ message: @autoclosure () -> String)   { if OSLog.default.isEnabled(type: .debug)     { os_log(.debug,   log: OSLog.default, "%{public}s", message()); } }
@inlinable func DDLogVerbose(_ message: @autoclosure () -> String) { if OSLog.default.isEnabled(type: .default)   { os_log(.default, log: OSLog.default, "%{public}s", message()); } }
