//
// --------------------------------------------------------------------------
// Config_Bridge.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Config.h"

#if IS_HELPER
#import "Mac_Mouse_Fix_Helper-Swift.h"
#else
#import "Mac_Mouse_Fix-Swift.h"
#endif

NSObject * _Nullable config(NSString *keyPath) {
    return [Config configForKeyPath:keyPath];
}

void setConfig(NSString *keyPath, NSObject *value) {
    [Config setConfigValue:value forKeyPath:keyPath];
}

void removeFromConfig(NSString *keyPath) {
    [Config removeFromConfigForKeyPath:keyPath];
}

void commitConfig(void) {
    [Config commitConfig];
}
