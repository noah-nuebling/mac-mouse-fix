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
#import "Locator.h"

@implementation Logging

+ (void)setUpDDLog {
    
    #define kMFOSLogSubsystem   @"com.nuebling.mac-mouse-fix"
    #define kMFOSLogCategory    @"main-category"
    DDOSLogger *logger = [[DDOSLogger alloc] initWithSubsystem: kMFOSLogSubsystem category: kMFOSLogCategory logLevelMapper: [[DDOSLogLevelMapperDefault alloc] init]];
    [DDLog addLogger: logger];
    
    NSArray<Class> *swiftSubclasses = searchClasses(@{ @"superclass": self, @"framework": getExecutablePath() ?: @"" });
    assert(swiftSubclasses.count <= 1);
    Class swiftSubclass = swiftSubclasses.firstObject;
    
    if (swiftSubclass != nil) {
        nowarn_push()
        [swiftSubclass performSelector:@selector(setUpDDLogSwift)];
        nowarn_pop()
    }
    
    if (YES /*runningPreRelease()*/) {
        DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
        fileLogger.rollingFrequency = 60 * 60 * 24; /// 24 hour rolling
        fileLogger.logFileManager.maximumNumberOfLogFiles = 20;
        
        [DDLog addLogger:fileLogger];
        
        DDLogInfo(@"Logging to directory: \'%@\'", fileLogger.logFileManager.logsDirectory);
        NSLog(@"[MacMouseFix] FILE LOGGING STARTED. Directory: %@", fileLogger.logFileManager.logsDirectory);
    }
}

@end

bool runningPrereleaseBuild(void) {

    #if IS_XC_TEST
        assert(false);
        return 1;
    #elif DEBUG
        return 1;
    #endif

    static int _result;
    static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{
        NSString *versionName = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        _result = [versionName localizedCaseInsensitiveContainsString: @"alpha"] ||
                  [versionName localizedCaseInsensitiveContainsString: @"beta"];
    });

    return _result;
}
