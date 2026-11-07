//
// --------------------------------------------------------------------------
// Config.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#if IS_HELPER
    #import "Threads.h"
#endif

NS_ASSUME_NONNULL_BEGIN

/// RunLoop
static inline CFRunLoopRef _Nonnull configRunLoop(void) CF_RETURNS_NOT_RETAINED {
    #if IS_HELPER
        return IOThread.runLoop;
    #elif IS_MAIN_APP
        return CFRunLoopGetMain();
    #else
        return CFRunLoopGetMain();
    #endif
}

@class Config;

NSObject * _Nullable config(NSString *keyPath);
void setConfig(NSString *keyPath, NSObject *value);
void removeFromConfig(NSString *keyPath);
void commitConfig(void);

NS_ASSUME_NONNULL_END
