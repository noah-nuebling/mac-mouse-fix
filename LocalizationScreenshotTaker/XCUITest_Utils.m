//
// --------------------------------------------------------------------------
// XCUITest_Utils.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "XCUITest_Utils.h"

NSString *XCUIApplicationState_ToString(XCUIApplicationState state) {
    
    switch (state) {
    case XCUIApplicationStateUnknown:                           return @"Unknown";
    case XCUIApplicationStateNotRunning:                        return @"NotRunning";
    #if !TARGET_OS_OSX
        case XCUIApplicationStateRunningBackgroundSuspended:    return @"RunningBackgroundSuspended";
    #endif
    case XCUIApplicationStateRunningBackground:                 return @"RunningBackground";
    case XCUIApplicationStateRunningForeground:                 return @"RunningForeground";
    }
    
    return [NSString stringWithFormat: @"(%@)", @(state)];
}
