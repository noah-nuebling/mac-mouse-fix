//
// --------------------------------------------------------------------------
// Logging.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#if !REPLACE_COCOALUMBERJACK

/// 1. Import CocoaLumberjackSwift across the entire target

@_exported import CocoaLumberjackSwift

/// 2. Set Swift's logLevel (the global variable `dynamicLogLevel`) to the level defined for objc in Logging.h
///     This method is dynamically looked up and called by -[Logging setUpDDLogging]

@objc private class LoggingSwift: Logging {
    @objc private class func setUpDDLogSwift() {
        #if DEBUG
        dynamicLogLevel = .debug
        #else
        dynamicLogLevel = .info
        #endif
    }
}

#elseif REPLACE_COCOALUMBERJACK

/// Define replacements for DDLogXYZ
///     This is separate from the C implementation because Swift can't import varargs properly

func DDLogError(_ format: String, _ args: any CVarArg...) {
    NSLog("Error: " + format, args)
}
func DDLogWarn(_ format: String, _ args: any CVarArg...) {
    NSLog("Warn: " + format, args)
}
func DDLogInfo(_ format: String, _ args: any CVarArg...) {
    NSLog("Info: " + format, args)
}
func DDLogDebug(_ format: String, _ args: any CVarArg...) {
    NSLog("Debug: " + format, args)
}
func DDLogVerbose(_ format: String, _ args: any CVarArg...) {
    NSLog("Verbose: " + format, args)
}

#endif

/// Wrap mfassert() and mfrequire() for Swift
@inline(__always) func mfassert(_ condition: @autoclosure () -> Bool, _ reason: @autoclosure () -> String? = nil, file: String = #fileID, line: Int = #line, function: String = #function) {
    if _slowPath(!condition()) { _mfassertrequire_failure(false, "<swift>", reason() ?? "", file, Int32(line), function) }
}

@inline(__always) func mfrequire(_ condition: @autoclosure () -> Bool, _ reason: @autoclosure () -> String? = nil, file: String = #fileID, line: Int = #line, function: String = #function) {
    if _slowPath(!condition()) { _mfassertrequire_failure(true, "<swift>", reason() ?? "", file, Int32(line), function) }
}
