//
// --------------------------------------------------------------------------
// Logging.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Logging.h"

///
/// Notes:
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
///

#if REPLACE_COCOALUMBERJACK

void DDLogError(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSLogv([@"Error: " stringByAppendingString: format], args);
    va_end(args);
}
void DDLogWarn(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSLogv([@"Warn: " stringByAppendingString: format], args);
    va_end(args);
}
void DDLogInfo(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSLogv([@"Info: " stringByAppendingString: format], args);
    va_end(args);
}
void DDLogDebug(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSLogv([@"Debug: " stringByAppendingString: format], args);
    va_end(args);
}
void DDLogVerbose(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSLogv([@"Verbose: " stringByAppendingString: format], args);
    va_end(args);
}

#else

@implementation Logging

+ (void)setUpDDLog {
    
    /// Start logging to console and to Xcode output
    /// Call this at the entry point of an app, so that DDLog statements work.
    
    /// Need to enable Console.app > Action > Include Info Messages & Include Debug Messages to see these messages in Console. See https://stackoverflow.com/questions/65205310/ddoslogger-sharedinstance-logging-only-seems-to-log-error-level-logging-in-conso
    /// Will have to update instructions on Mac Mouse Fix Feedback Assistant when this releases.
    
    [DDLog addLogger:DDOSLogger.sharedInstance]; /// Use os_log // This should log to console and terminal and be faster than the old methods
    
    /// Set logging format
    //    DDOSLogger.sharedInstance.logFormatter = DDLogFormatter.
    
    if ((NO) /*runningPreRelease()*/) {
        
        /// Setup logging  file
        /// Copied this from https://github.com/CocoaLumberjack/CocoaLumberjack/blob/master/Documentation/GettingStarted.md
        /// Haven't thought about whether the exact settings make sense.
        
        DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
        fileLogger.rollingFrequency = 60 * 60 * 24; /// 24 hour rolling
        fileLogger.logFileManager.maximumNumberOfLogFiles = 2;
        
        [DDLog addLogger:fileLogger];
        
        DDLogInfo(@"Logging to directory: \'%@\'", fileLogger.logFileManager.logsDirectory);
    }
}

@end

#endif
