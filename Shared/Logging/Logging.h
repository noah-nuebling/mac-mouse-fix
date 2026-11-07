//
// --------------------------------------------------------------------------
// Logging.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#pragma once
#import <Foundation/Foundation.h>
#import "SharedMacros.h"
#import <os/log.h>

#define LOG_LEVEL_DEF ddLogLevel
@import CocoaLumberjack;

#if DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#endif

NS_ASSUME_NONNULL_BEGIN

__attribute__((overloadable)) static inline NSString *MFLogFormat(const char *s) {
    return [NSString stringWithUTF8String:s] ?: @"";
}

__attribute__((overloadable)) static inline NSString *MFLogFormat(NSString *s) {
    return s;
}

#undef DDLogError
#undef DDLogWarn
#undef DDLogInfo
#undef DDLogDebug
#undef DDLogVerbose

#define DDLogError(frmt, ...)    LOG_MAYBE(NO,                LOG_LEVEL_DEF, DDLogFlagError,   0, nil, __PRETTY_FUNCTION__, MFLogFormat(frmt), ##__VA_ARGS__)
#define DDLogWarn(frmt, ...)     LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagWarning, 0, nil, __PRETTY_FUNCTION__, MFLogFormat(frmt), ##__VA_ARGS__)
#define DDLogInfo(frmt, ...)     LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagInfo,    0, nil, __PRETTY_FUNCTION__, MFLogFormat(frmt), ##__VA_ARGS__)
#define DDLogDebug(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagDebug,   0, nil, __PRETTY_FUNCTION__, MFLogFormat(frmt), ##__VA_ARGS__)
#define DDLogVerbose(frmt, ...)  LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagVerbose, 0, nil, __PRETTY_FUNCTION__, MFLogFormat(frmt), ##__VA_ARGS__)

@interface Logging : NSObject
+ (void)setUpDDLog;
@end

/// mfassert() and mfrequire()
#define mfassert(condition, reason...) \
    ({ if (mfunlikely(!(condition))) _mfassertrequire_failure(false, #condition, [NSString stringWithFormat: @"" reason], __FILE_NAME__, __LINE__, __FUNCTION__); })

#define mfrequire(condition, reason...) \
    ({ if (mfunlikely(!(condition))) { _mfassertrequire_failure(true, #condition, [NSString stringWithFormat: @"" reason], __FILE_NAME__, __LINE__, __FUNCTION__); abort(); } })

static inline void _mfassertrequire_failure(bool require, const char *conditionStr, NSString * _Nullable reason, const char *file, int line, const char *function) {
    DDLogError(
        @"mfassert() or mfrequire() failed."
        "\n  Condition: %s"
        "\n  Reason:    %@"
        "\n  Location:  %s:%d (inside %s)"
        "\n  Callers: %@",
        conditionStr,
        reason.length ? reason : @"<>",
        file, line, function,
        [NSThread callStackSymbols]
    );
    #if NDEBUG
        if (require) abort();
    #else
        abort();
    #endif
}

static inline bool runningDebugMode(void) {
    return os_log_debug_enabled(OS_LOG_DEFAULT);
}

bool runningPrereleaseBuild(void);
static inline bool runningPreRelease(void) {
    return runningPrereleaseBuild();
}

NS_ASSUME_NONNULL_END
