//
// --------------------------------------------------------------------------
// InputThread.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

/// We've created this so that we don't have to use the main runLoop for all eventTaps, and input handling
/// (All the input handling - clicks, drags, scrolls - should happen on the same thread/queue so the inputs are processed in the right order. Otherwise gestures can be unreliable especially when the computer is slow)
/// We could just use the main thread for this, but that leads to slightly higher CPU usage and maybe other performance drawbacks.
/// We originally created this to get the CPU usage for twoFingerModifiedDrag lower. It helped a little.

#import "InputThread.h"

@implementation InputThread

/// Vars

static CFRunLoopRef _runLoop;

static NSThread *_thread;
/// ^ I usually use dispatch queue but it doesn't let you guarantee that you're not on the main thread. So we're using threads directly.

static BOOL _threadIsInitialized;
static NSCondition *_threadIsInitializedSignal;

/// Init

+ (void)coolInitialize {
    /// We can't use +initialize because
    ///     In +initialize we call [NSThread -start] and then wait for it to do stuff
    ///     But for some reason [NSThread -start] waits for any +initialize functions to finish, which leads to deadlock.
    
    if (self == InputThread.class) {
        
        /// Setup signal
        _threadIsInitialized = NO;
        _threadIsInitializedSignal = [[NSCondition alloc] init];
        [_threadIsInitializedSignal lock];
        
        /// Setup thread
        _thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadWorkload) object:nil];
        _thread.name = @"com.nuebling.mac-mouse-fix.input-thread";
        _thread.qualityOfService = NSQualityOfServiceUserInteractive;
        _thread.threadPriority = 1.0;
        [_thread start];
        
        /// Wait unil thread is initialized
        while (!_threadIsInitialized) {
            [_threadIsInitializedSignal waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]]; /// I saw this deadlock once (which is strange, since POSIX condition vars never do that I think, and I'm using this just the way I would use POSIX vars). The `waitUntilDate:` should work as a fallback if that happens.
        }
        
    }
}

/// Thread workload

+ (void)threadWorkload {
    
    /// Store runLoop of new thread
    _runLoop = CFRunLoopGetCurrent();
    
    /// Add empty source so the runLoop doesn't exit immediately
    CFRunLoopSourceContext ctx = {
        .cancel = NULL,
        .copyDescription = NULL,
        .equal = NULL,
        .hash = NULL,
        .info = NULL,
        .perform = NULL,
        .release = NULL,
        .retain = NULL,
        .schedule = NULL,
        .version = 0,
    };
    CFRunLoopSourceRef emptySource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &ctx);
    CFRunLoopAddSource(_runLoop, emptySource, kCFRunLoopCommonModes);
    
    /// Notify initialize function that we're done
    _threadIsInitialized = YES;
    [_threadIsInitializedSignal signal];
    
    /// Run the runLoop
    ///     This thread is blocked by the runLoop now
    while (true) {
        CFRunLoopRun();
    }
}

/// Interface

+ (CFRunLoopRef)runLoop {
    
    /// Init
    if (!_threadIsInitialized) {
        [self coolInitialize];
    }
    
    /// Validate
    assert(_runLoop != NULL);
    
    /// Return runLoop
    return _runLoop;
}
+ (NSRunLoop *)nsRunLoop {
    assert(false); /// Bridging to NSRunLoop doesn't really seem to work. (Calling addTimer: crashes)
    return (__bridge NSRunLoop *)self.runLoop;
}

+ (void)executeSyncIfPossible:(nonnull void (^)(void))block {
    if (self.runningOnInputThread) {
        block();
    } else {
        [self execute:block];
    }
}

+ (void)execute:(nonnull void (^)(void))block {
    
    CFRunLoopPerformBlock(self.runLoop, kCFRunLoopDefaultMode, block);
    CFRunLoopWakeUp(self.runLoop);
    
//    [self.nsRunLoop performBlock:block];
}

+ (NSTimer *)executeAfter:(CFTimeInterval)interval block:(nonnull void (^)(NSTimer * _Nonnull))block {
    
    /// Create timer
    NSTimer *timer = [NSTimer timerWithTimeInterval:interval repeats:NO block:block];
    
    /// Schedule timer
    CFRunLoopAddTimer(self.runLoop, (__bridge CFRunLoopTimerRef)timer, kCFRunLoopDefaultMode); /// Not sure which mode to use
    
    /// Return
    return timer;
}

+ (BOOL)runningOnInputThread {
    
    /// NOTE: Actually checks if we're running on `self._runLoop`, but that should be the same as running on `self._thread` for all practical purposes
    
    return CFEqual(self.runLoop, CFRunLoopGetCurrent());
}

@end
