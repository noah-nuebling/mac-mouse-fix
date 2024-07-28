//
// --------------------------------------------------------------------------
// TestLogging.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "TestLogging.h"
#import "Logging.h"

@implementation TestLogging

+ (void)doTestLogs_objc {
    NSLog(@"Begin doTestLogs_objc");
    NSLog(@"Test DDLogError:");
    DDLogError(@"DDLogError is logging");
    NSLog(@"Test DDLogWarn:");
    DDLogWarn(@"DDLogWarn is logging");
    NSLog(@"Test DDLogInfo:");
    DDLogInfo(@"DDLogInfo is logging");
    NSLog(@"Test DDLogDebug:");
    DDLogDebug(@"DDLogDebug is logging");
    NSLog(@"End doTestLogs_objc");
}

@end
