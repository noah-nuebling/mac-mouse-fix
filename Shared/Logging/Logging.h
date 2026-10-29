//
// --------------------------------------------------------------------------
// Logging.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/**
How to use:
    Old: (Before deleting CocoaLumberjack)
        Swift:
          Import `Logging.h` in your target's Swift bridging header
          Add Logging.swift as a member of your target. (It will import CocoaLumberjackSwift everywhere)
        objc:
          Import `Logging.h` at the top of your files
        Swift & objc:
          Call `-[Logging setupDDLog]` at the entry point of your target. Afterwards, DDLogXYZ statements will not work.
        Other:
          Set the `REPLACE_COCOALUMBERJACK=1` preprocessor flag (For swift and objc) to make DDLogXYZ calls simply call NSLog().
            If you do this, you won't have to include the CocoaLumberjack framework  in your target, and  `[Logging setupDDLog]` will be unavailable.
        Note:
        You shouldn't have to manually import CocoaLumberjack or CocoaLumberjackSwift anywhere. Just import Logging.h.

Old logLevel logic (When we were still using CocoaLumberjack)
    ```
    /// Setup logLevel
    ///     Think about moving to using `runningDebugMode()` instead of `#if DEBUG` to set logLevel.
    #if DEBUG
        static const DDLogLevel ddLogLevel = DDLogLevelDebug;
    #else
        static const DDLogLevel ddLogLevel = DDLogLevelInfo;
    #endif
    ```
    -> We removed instructions to gather logs from MMF Feedback Assistant a while ago. So the logLevels don't matter right now, and it's ok we removed this.
*/


#import <Foundation/Foundation.h>
#import <os/log.h>
#import "SharedMacros.h"

@interface Logging : NSObject
    + (void)setUpDDLog;
    + (void)flushLog;
@end

/// TODO: Once we actually collect logs, make everything {public} by default [Oct 2026]
///     - the app doesn't know anything sensitive except $3 license key,
///         and local logs aren't more accessible than the users's license email anyways,
///     - I wouldn't trust that sysdiagnose contains no private info at all even with {private} redactions, so I'll treat them as confidential. [Oct 2026]
/// Note: The only utility of log levels is that `os_log` persists them differently -> Understand this and simplify API [Oct 2026]
#define DDLogError(msg...)      ({ if (os_log_type_enabled(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT))    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT,   msg); })
#define DDLogWarn(msg...)       ({ if (os_log_type_enabled(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR))    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,   msg); })
#define DDLogDebug(msg...)      ({ if (os_log_type_enabled(OS_LOG_DEFAULT, OS_LOG_TYPE_DEBUG))    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEBUG,   msg); })
#define DDLogInfo(msg...)       ({ if (os_log_type_enabled(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO))     os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,    msg); })
//#define DDLogVerbose(msg...)    ({ if (os_log_type_enabled(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT))  os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, msg); }) /// Unused

/// mfassert() and mfrequire()
///     TODO: Use this consistently
///         -> Replace`NSAssert()`, `NSCAssert()`, `assert()`, `fatalError()`, log+exit(), log+abort(), maybe more I can't think of [Oct 2026]
///             TODO: Also Replace NDEBUG with `!runningDebugMode()` entirely so all behavior is controlled at runtime. [Oct 2026]
///     Improvement ideas:
///         - Maybe use `CRSetCrashLogMessage()` for nicer crash reports. Apple's code uses it quite extensively. (abort() also uses it internally I think.) See GitHub search: `CRSetCrashLogMessage (owner:apple OR owner:apple-oss-distributions)`
///     Interesting:
///         `__assert_rtn()` implementation: (I think) https://github.com/apple-oss-distributions/Libc/blob/af11da5ca9d527ea2f48bb7efbd0f0f2a4ea4812/gen/FreeBSD/assert.c#L48
///         `__assert()` implementation(s): (I think) https://github.com/apple-oss-distributions/Libc/blob/af11da5ca9d527ea2f48bb7efbd0f0f2a4ea4812/include/_assert.h#L38

#define mfassert(condition, reason...) \
    ({ if (mfunlikely(!(condition))) _mfassertrequire_failure(false, #condition, [NSString stringWithFormat: @"" reason], __FILE_NAME__, __LINE__, __FUNCTION__); })

#define mfrequire(condition, reason...) \
    ({ if (mfunlikely(!(condition))) { _mfassertrequire_failure(true, #condition, [NSString stringWithFormat: @"" reason], __FILE_NAME__, __LINE__, __FUNCTION__); abort(); /** Abort inline so the compiler doesn't complain [Oct 2026] */ } })

static inline void _mfassertrequire_failure(bool require, const char *conditionStr, NSString *reason, const char *file, int line, const char *function) { /// Factored like this so Swift can call it (Can't call macros or varargs) [Oct 2026]
    DDLogError( /// Even in release builds, we log failed asserts as errors [Oct 2026]
        "mfassert() or mfrequire() failed."
        "\n  Condition: %s"  /// I feel like this is not actually useful, we just need some unique identifier for the assert, could be reason or location [Oct 2026]
        "\n  Reason:    %@"
        "\n  Location:  %s:%d (inside %s)"
        "\n  Callers: %@",
        conditionStr,
        reason.length ? reason : @"<>",
        file, line, function,
        [NSThread callStackSymbols]
    );
    #if NDEBUG
        if (require) abort(); /// mfrequire aborts even in release builds [Oct 2026]
    #else
        abort();
    #endif
}

/** runningDebugMode()
    Idea: Have user-facing 'debugMode' toggle which: [Oct 2026]
    - Sacrifices performance for more verbose logs
    - Sacrifices robustness/recovery for crashing early (and therefore producing crash-reports)

    The user-facing 'debugMode' toggle is not-yet implemented [Oct 2026]
        However, this is already useful, for attaching `log` clt to release builds and getting all the verbose logs.

    Usage of `runningDebugMode()`:
        We wrap expensive preparation for debug logs in this, to skip the preparation when the debug logs are disabled, anyways. Can't think of any other usages, right now [Oct 2026]
    Caution:
        Don't accidentally use `#if DEBUG` - it can't change it at runtime.
    Also see:
        I think there was some super long old note I wrote about improving debugging of hard-to-reproduce issues, where this idea comes from, but I'm too lazy to look it up [Oct 2026]
            I think it was in my notes repo, or some separate repo, because I didn't have the notes repo, yet [Oct 2026]
    History:
        Previously we used `runningPreRelease()` everywhere which I've now split into `runningDebugMode()` and `runningPrereleaseBuild()` [Oct 2026]
 */

static inline bool runningDebugMode(void) {
    return os_log_debug_enabled(OS_LOG_DEFAULT);
}

/** runningPrereleaseBuild()
    Idea: Detect Alpha/Beta releases. (/ debug builds) See implementation. [Oct 2026]
    Note/History: This one doesn't really belong into Logging.h, but it's here to stay close to `runningDebugMode()` [Oct 2026]
*/
bool runningPrereleaseBuild(void);
