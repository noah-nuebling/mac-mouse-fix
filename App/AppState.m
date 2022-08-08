//
// --------------------------------------------------------------------------
// AppState.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "AppState.h"

@implementation AppState

/// Convenience function for accessing instance
AppState *appState() {
    return _instance;
}

/// Init the class by creating a singleton instance
static AppState *_instance;
+ (void)initialize
{
    if (self == [AppState class]) {
        _instance = [AppState new];
    }
}

/// Init the instance
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.updaterDidRelaunchApplication = NO;
    }
    return self;
}

@end
