//
// --------------------------------------------------------------------------
// Logging.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// How to use:
///     Swift:
///       Import `Logging.h` in your target's Swift bridging header
///       Add Logging.swift as a member of your target target. (It will import CocoaLumberjackSwift everywhere)
///     objc:
///       Import `Logging.h` at the top of your files
///     Swift & objc:
///       Call `-[Logging setupDDLog]` at the entry point of your target. Afterwards, DDLogXYZ statements will work.
///     Other:
///       Set the `REPLACE_COCOALUMBERJACK=1` preprocessor flag (For swift and objc) to make DDLogXYZ calls simply call NSLog().
///         If you do this, you won't have to include the CocoaLumberjack framework  in your target, and  `[Logging setupDDLog]` will be unavailable.
///     Note:
///     You shouldn't have to manually import CocoaLumberjack or CocoaLumberjackSwift anywhere. Just import Logging.h.
///

/// Explanations:
///     The way you set the logLevel in CocoaLumberjack is totally different for objc and Swift.
///
///     `In objc`:
///         things are simpler to set up: First, you define the name of the C variable which holds the log level by defining `LOG_LEVEL_DEF`
///         then you just create a static c variable with that name holding the logLevel, and then the logLevel will be used by DDLogXYZ statements.
///         If you make the c variable `const` that allows the compiler to strip out dead DDLog calls. Not sure of the performance impact.

///     `In swift`
///         There are two ways to change the logLevel in swift afaiu:
///         1.  `DD_LOG_LEVEL` is a preprocessor macro defined in C which will be assigned to the `DDDefaultLogLevel` C constant which itself is used in swift code. Using it allows the compiler to strip out dead DDLogXYZ calls.
///             -> From a CocoaLumberjack GitHub discussion: "[DD_LOG_LEVEL] ... needs to be defined either via the `GCC_PREPROCESSOR_DEFINITIONS` build setting, or using a #define in a bridging header of a Swift target." --- Update: I tried defining `DD_LOG_LEVEL` in the prefix header and it didn't work.
///         2. `dynamicLogLevel` is a global Swift variable that can be set at runtime from a Swift file.

///         We're first setting up the log level for objc in this header file, and then synchronizing the Swift `dynamicLogLevel` in our -[Logging setUpDDLog] route.

///     Note:
///     - I think `LOG_LEVEL_DEF` needs to be defined before importing CocoaLumberjack, so that the preprocessor replaces occurences of `LOG_LEVEL_DEF` inside the framework imports.
///         This is also why we're splitting the objc logLevel setup into 2 parts.
///     - There is no documentation for the swift stuff. This information is based on the discussions linked from the "Improve documentation #960" issue on the CocoaLumberjack repo.

///
/// History:
///     We initially tried to setup CocoaLumberjack using a prefix header (PrefixHeader.pch) but we couldn't get it to work properly, so we moved to using Logging.h
///
///     Old notes from WannabePrefixHeader.h:
///         General note on my use of CocoaLumberjack:
///         I plan on not using the verbose channel for logging at all because it doesn't make sense for me to differentiate it from the debug channel. I probably won't use Error and Warn either because it's too much work to migrate all my old NSLog Statements into all these different categories. So I'll just use Info and Debug channels. At least for now.
///          And therefore the only interesting log _levels_ are also Info and Debug
///          Edit: I've since started using Error and Warn in some places.
///
///     Even older notes from PrefixHeader.pch:
///         I created this for CocoaLumberjack
///         Here' an explanation of prefix headers (I think that's the same as precompiled headers), as well as why they can be misused and why they've been replaced by 'modules'.
///          https://useyourloaf.com/blog/modules-and-precompiled-headers/
///          The gist is -> This makes sense for CocoaLumberjack but don't overuse it because you're too lazy to import stuff. Really think and consider before using this.
///
///         Include any system framework and library headers here that should be included in all compilation units.
///         You will also need to set the Prefix Header build setting of one or more of your targets to reference this file.
///         -> All targets reference this file
///
///         Setup CocoaLumberjack
///
///         I moved all the CocoaLumberjack setup from this file to WannabePrefixHeader.h.
///         For some reason there was a cryptic error saying "Could not build module 'CocoaLumberjack'" along with over 30 of other errors like "Unknown type name 'NSString' - NSObjcRuntime.h" as soon as I   imported <CocoaLumberjack/CocoaLumberjack.h> here. I could not Google these errors at all
///          So instead I moved the CocoaLumberjack setup to WannabePrefixHeader.h, until I can get this to work
///
///         The rest of CocoaLumberjack setup is done in `setupBasicCocoaLumberjackLogging`

#if !REPLACE_COCOALUMBERJACK

/// Set up Cocoa lumberjack normally

/// 1. Setup logLevel pt 1
///     -> Define the variableName for the logLevel that the CocoaLumberjack import should use. (I think this has to be done before the import, but not sure.)
#define LOG_LEVEL_DEF ddLogLevel

/// 2. Import CocoaLumberjack
@import CocoaLumberjack;

/// 3. Setup logLevel pt 2
///     -> Set logLevel
///     Think about moving to using `runningPreRelease()` instead of `#if DEBUG` to set logLevel.
#if DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelDebug;
#else
static const DDLogLevel ddLogLevel = DDLogLevelInfo;
#endif

/// 4. Declare helper class
///     Which contains -[setUpDDLog] helper method.
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface Logging : NSObject
+ (void)setUpDDLog;
@end
NS_ASSUME_NONNULL_END

#elif REPLACE_COCOALUMBERJACK

/// Replace CocoaLumberjack
///     Replace DDLogXYZ macros with custom macros
///     > I'm making this for the LocalizationScreenshotTaker target because for that target, we don't want to keep it dependency-free, since it might worsen compile times and be annoying, but we want to import code that calls DDLogXYZ().
///     Notes:
///     - ddLogLevel won't have any effect when compiling with REPLACE_COCOALUMBERJACK.

#import <Foundation/Foundation.h>

#define DDLogError(__format, __args...)    NSLog(@"Error: "     __format, ## __args) /// `##` Deletes the `,` if `__args` is empty
#define DDLogWarn(__format, __args...)     NSLog(@"Warn: "      __format, ## __args)
#define DDLogInfo(__format, __args...)     NSLog(@"Info: "      __format, ## __args)
#define DDLogDebug(__format, __args...)    NSLog(@"Debug: "     __format, ## __args)
#define DDLogVerbose(__format, __args...)  NSLog(@"Verbose: "   __format, ## __args)

#endif
