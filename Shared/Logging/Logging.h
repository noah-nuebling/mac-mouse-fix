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
    ///     Think about moving to using `runningPreRelease()` instead of `#if DEBUG` to set logLevel.
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

@interface Logging : NSObject
    + (void)setUpDDLog;
    + (void)flushLog;
@end

/// Note: I'm not sure logLevels add any utility, but we're already using these everywhere.
#define DDLogError(msg...)      ({ if (os_log_type_enabled(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT))    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT,   msg); })
#define DDLogWarn(msg...)       ({ if (os_log_type_enabled(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR))    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,   msg); })
#define DDLogDebug(msg...)      ({ if (os_log_type_enabled(OS_LOG_DEFAULT, OS_LOG_TYPE_DEBUG))    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEBUG,   msg); })
#define DDLogInfo(msg...)       ({ if (os_log_type_enabled(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO))     os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,    msg); })
//#define DDLogVerbose(msg...)    ({ if (os_log_type_enabled(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT))  os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, msg); }) /// Unused

/// mfassert()
///     Custom assert implementation
///
///     Context: [Apr 2025]
///             This originally came from
///
///     Examples:
///         Usage:
///             `mfassert(string == nil, "Expected 'string' to be nil. But it was '%@'", string);`
///         Output:
///             ```
///             mfassert() failed.
///               Asserted condition:    (string == nil)
///               Reason:                Expected 'string' to be nil. But it was 'ABCDEFG'
///               Location:              AppDelegate.m:62 (inside -[AppDelegate applicationDidFinishLaunching])
///               Callers:               <stack-trace>
///             ```
///         You can also omit the 'reason' and simply type:
///             `mfassert(string == nil);`
///
///     Behavioural details:
///         - Will crash the program on assert-failure - unless the `NDEBUG` preprocessor flag is present (Just like the native `assert()` macro.)
///         - Logging is performed through our standard `DDLogError()` mechanism.
///             Thus, enabling or disabling logging is handled by the logging backend, independent of `NDEBUG`.
///         - The 'reason' string – if provided – is formatted using `-[NSString stringWithFormat:]` –  allowing you to use the `%@` format specifier.
///
///     Alternatives:
///          - Use this over `NSAssert()`, `NSCAssert()`, and `assert()`
///              - Pro: Easy to type, nicer logging output, full control to change behavior in the future, doesn't throw exceptions (like NSAssert does) (Exceptions might be caught instead of crashing the program in some contexts), allows for logging assert-failures even in `NDEBUG` builds.
///              - Contra: Possibly slower than `assert()` because it's not completely optimized out in `NDEBUG` builds – However, I expect the performance difference to be negligible.
///
///     Improvements:
///         - Maybe use `CRSetCrashLogMessage()` for nicer crash reports. Apple's code uses it quite extensively. (abort() also uses it internally I think.) See GitHub search: `CRSetCrashLogMessage (owner:apple OR owner:apple-oss-distributions)`
///
///     Interesting:
///         `__assert_rtn()` implementation: (I think) https://github.com/apple-oss-distributions/Libc/blob/af11da5ca9d527ea2f48bb7efbd0f0f2a4ea4812/gen/FreeBSD/assert.c#L48
///         `__assert()` implementation(s): (I think) https://github.com/apple-oss-distributions/Libc/blob/af11da5ca9d527ea2f48bb7efbd0f0f2a4ea4812/include/_assert.h#L38

#if NDEBUG
    #define __mfassert_NDEBUG_is_present 1
#else
    #define __mfassert_NDEBUG_is_present 0
#endif

#define mfassert(condition, /* failurereason, formatarg1, formatarg2, ... */ ...)   \
({                                                                                  \
    if (mfunlikely(!(condition))) { /** It's unlikely that the assert fails */                      \
        DDLogError(                                                                 \
            "mfassert() failed."                                                   \
            "\n  Asserted condition:    %s"                                         \
            __VA_OPT__(                                                             \
            "\n  Reason:                %@"                                         \
            )                                                                       \
            "\n  Location:              %s:%d (inside %s)"                          \
            "\n  Callers: %@",                                                      \
            #condition,                                                             \
            __VA_OPT__(                                                             \
            [NSString stringWithFormat:__VA_ARGS__],                                \
            )                                                                       \
            __FILE_NAME__, __LINE__, __FUNCTION__,                                  \
            [NSThread callStackSymbols]                                             \
        );                                                                          \
        if (!__mfassert_NDEBUG_is_present) {                                        \
            abort();                                                                \
        }                                                                           \
    }                                                                               \
})
