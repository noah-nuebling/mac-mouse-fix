//
// --------------------------------------------------------------------------
// NSTimer+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "NSTimer+Additions.h"
#import "Threads.h"

@implementation NSTimer (Additions)
    + (instancetype) mf_scheduledTimerWithTimeInterval: (NSTimeInterval)timeInterval mode: (NSRunLoopMode)mode block: (void (^)(NSTimer *timer))block {
        /// See `Threads.m` > `Standard patterns` [Oct 2026]
        mfrequire( /// Any other contexts don't have runLoops that actually run, making this silently fail. Also see (now deleted) `CoolTimer.swift` [Oct 2026]
            #if IS_HELPER
            CFRunLoopGetCurrent() == IOThread.runLoop ||
            #endif
            CFRunLoopGetCurrent() == CFRunLoopGetMain()
        );
        NSTimer *timer = [[NSTimer alloc] initWithFireDate: [NSDate dateWithTimeIntervalSinceNow: timeInterval] interval: DBL_MAX repeats: NO block: block];
        [[NSRunLoop currentRunLoop] addTimer: timer forMode: mode];
        return timer;
    }
@end
