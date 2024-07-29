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

#if !REPLACE_COCOALUMBERJACK

@implementation Logging

+ (void)setUpDDLog {
    
    /// Call this at the entry point of an app, so that DDLog statements work.
    
    /// Start logging to console and to Xcode output
    ///     The `DDOSLogger` uses Apple's relatively new and fast `os_log` as the logging backend afaik
    [DDLog addLogger:DDOSLogger.sharedInstance];
    
    /// Find swift subclass
    ///     Discussion: Retrieving the class dynamically through the objc runtime is a bit weird but otherwise we'd have to import the `"<TargetName>-Swift.h"` header to have access to the swiftSubclass which would make the code here not target-independent, which I don't like (I probably have my priorities wrong?). Also I tested and the search only took 1.2ms so it should be ok to use this in production.
    NSArray<Class> *swiftSubclasses = searchClasses(@{ @"superclass": self, @"framework": getExecutablePath() });
    assert(swiftSubclasses.count <= 1);
    Class swiftSubclass = swiftSubclasses.firstObject;
    
    /// Call swift setup
    if (swiftSubclass != nil) {
        [swiftSubclass performSelector:@selector(setUpDDLogSwift)];
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
