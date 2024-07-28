//
// --------------------------------------------------------------------------
// Logging.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#pragma mark - Discussion

/// How to use:
/// Swift:
///   Import `Logging.h` in your target's Swift bridging header
///   Add Logging.swift as a member of your target target. (It will import CocoaLumberjackSwift everywhere)
/// objc:
///   Import `Logging.h` at the top of your files
/// Swift & objc:
///   Call `[Logging setupDDLog]` at the entry point of your target. Afterwards, DDLogXYZ statements will work.
/// Other:
///   Set the `REPLACE_COCOALUMBERJACK=1` preprocessor flag to make DDLogXYZ calls simply call NSLog().
///     If you do this, you won't have to include the CocoaLumberjack framework  in your target, and  `[Logging setupDDLog]` will be unavailable.
///
/// Note:
///     You shouldn't need to manually import CocoaLumberjack or CocoaLumberjackSwift anywhere. Just import Logging.h. (???)
///

#pragma mark - Define global logLevel (Swift & Objc)

/// Here we're defining a global `mfLogLevel` which we'll then set as the CocoaLumberjack logLevel for objc and Swift.
/// Notes:
/// - Setting logLevel in Cocoalumberjack works totally differently for Swift vs objc, so we're defining a unified log level here.
/// -  Think about moving to using `runningPreRelease()` instead of `#if DEBUG` to set logLevel.
///

#if DEBUG
#define mfLogLevel DDLogLevelDebug
#else
#define mfLogLevel DDLogLevelInfo
#endif

#pragma mark - Setup Swift logLevel

/// Explanation:
///     - There are two ways to change the logLevel in swift afaiu:
///         1.  `DD_LOG_LEVEL` is a preprocessor macro defined in C which will be assigned to the `DDDefaultLogLevel` C constant which itself is used in swift code. Using it allows the compiler to strip out dead DDLogXYZ calls.
///             -> From a CocoaLumberjack GitHub discussion: "[DD_LOG_LEVEL] ... needs to be defined either via the `GCC_PREPROCESSOR_DEFINITIONS` build setting, or using a #define in a bridging header of a Swift target."
///         2. `dynamicLogLevel` (formerly defaultDebugLevel) is a global Swift variable that can be set at runtime from a Swift file (but it will only work up to `DD_LOG_LEVEL`, since that stuff is stripped out by the compiler)
///     - There is no documentation for this stuff. This here is based on the discussions linked from the "Improve documentation #960" issue on the CocoaLumberjack repo.
/// Notes:
///     - I think this will only work if the swift preprocessor parses this file (which it finds inside the bridging header I think) before importing CocoaLumberjackSwift. Not sure if that's always true.

#define DD_LOG_LEVEL mfLogLevel

#pragma mark - Setup objc logLevel pt 1

/// Explanation:
///     In objc things are simpler to set up: First, you define the name of the C variable which holds the log level by defining `LOG_LEVEL_DEF`
///         then you just create a static c variable with that name holding the logLevel, and then the logLevel will be used by DDLogXYZ statements.
/// Note:
///     I think `LOG_LEVEL_DEF` needs to be defined before importing CocoaLumberjack, so that the preprocessor replaces occurences of `LOG_LEVEL_DEF` inside the framework imports.
///         This is also why we're splitting the objc logLevel setup into 2 parts.

#define LOG_LEVEL_DEF ddLogLevel

#pragma mark - Import / replace CocoaLumberjack

#if !REPLACE_COCOALUMBERJACK

/// Import CocoaLumberjack
@import CocoaLumberjack;

#else

/// Replace CocoaLumberjack
///     Replace DDLogXYZ macros with custom implementations (which just call NSLog)
///     > I'm making this for the LocalizationScreenshotRunner target because for that target, we don't want to build the whole CocoaLumberjack framework, since it might worsen compile times and be annoying.
///     Notes:
///     - It would be nicer to just define macros that map to NSLog() but function-like macros don't import into swift, so we're defining c-functions instead.
///     - ddLogLevel won't have any effect when compiling with REPLACE_COCOALUMBERJACK.

#import <Foundation/Foundation.h>

void DDLogError(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
void DDLogWarn(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
void DDLogInfo(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
void DDLogDebug(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
void DDLogVerbose(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);

#define DDLogLevel int

#define DDLogLevelOff 0
#define DDLogLevelError 0
#define DDLogLevelWarning 0
#define DDLogLevelInfo 0
#define DDLogLevelDebug 0
#define DDLogLevelVerbose 0
#define DDLogLevelAll 0

#endif

#pragma mark - Setup objc logLevel pt 2

/// Set logLevel
///     `const` allows the compiler to strip out dead DDLog calls. But also disallows dynamic overriding of the value. Not sure what the performance is like.
static const DDLogLevel ddLogLevel = mfLogLevel;

#pragma mark - Declare setup method

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

#if !REPLACE_COCOALUMBERJACK
@interface Logging : NSObject
+ (void)setUpDDLog;
@end
#endif

NS_ASSUME_NONNULL_END
