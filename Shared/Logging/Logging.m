//
// --------------------------------------------------------------------------
// Logging.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Logging.h"
#import "AnnotationUtility.h"
#import "SharedUtility.h"

#if !REPLACE_COCOALUMBERJACK

@implementation Logging

+ (void)setUpDDLog {
    
    /// Start logging to console and to Xcode output
    /// Call this at the entry point of an app, so that DDLog statements work.
    
    /// Need to enable Console.app > Action > Include Info Messages & Include Debug Messages to see these messages in Console. See https://stackoverflow.com/questions/65205310/ddoslogger-sharedinstance-logging-only-seems-to-log-error-level-logging-in-conso
    /// Will have to update instructions on Mac Mouse Fix Feedback Assistant when this releases.
    ///     Update: [Apr 10 2025] Removed logging section from Feedback Assistant for now until we have time to make instructions for properly collecting logs using sysdiagnose.
    
    /// Use `os_log` backend for CocoaLumberjack.
    ///     Notes:
    ///     - This should log to console and terminal and be faster than the old methods. ([Apr 2025] What are the 'old methods'?)
    ///     - Specifying a subsystem and category allows us to configure logging using `Info.plist > OSLogPreferences`
    ///         > Also See: https://github.com/noah-nuebling/notes-public/blob/main/mmf/error-logging-improvement-ideas_oct-2024.md
    
    #define kMFOSLogSubsystem   @"com.nuebling.mac-mouse-fix"
    #define kMFOSLogCategory    @"main-category"
    DDOSLogger *logger = [[DDOSLogger alloc] initWithSubsystem: kMFOSLogSubsystem category: kMFOSLogCategory logLevelMapper: [[DDOSLogLevelMapperDefault alloc] init]];
    [DDLog addLogger: logger];
    
    /// Set logging format
    //    DDOSLogger.sharedInstance.logFormatter = DDLogFormatter.
    
    /// Find swift subclass
    ///     Discussion: Retrieving the class dynamically through the objc runtime is a bit weird but otherwise we'd have to import the `"<TargetName>-Swift.h"` header to have access to the swiftSubclass which would make the code here not target-independent, which I don't like (I probably have my priorities wrong?). Also I tested and the search only took 1.2ms so it should be ok to use this in production.
    ///     Update: [Apr 2025] Why not just use `NSClassFromString()` here.
    NSArray<Class> *swiftSubclasses = searchClasses(@{ @"superclass": self, @"framework": getExecutablePath() });
    assert(swiftSubclasses.count <= 1);
    Class swiftSubclass = swiftSubclasses.firstObject;
    
    /// Call swift setup
    if (swiftSubclass != nil) {
        nowarn_push()
        [swiftSubclass performSelector:@selector(setUpDDLogSwift)];
        nowarn_pop()
    }
    
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
