//
// --------------------------------------------------------------------------
// EventTapQueue.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// We've created this so that we don't have to use the main runLoop for all eventTaps
///     The main runLoop works fine but I suspect that it might cause higher CPU use to put all eventTap onto the main runLoop
///     Specifically I'm trying to get the CPU usage for twoFingerModifiedDrag lower
///     Edit: This does decrease CPU use! But only slightly.

#import "GlobalEventTapThread.h"

@implementation GlobalEventTapThread

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
    
    if (self == GlobalEventTapThread.class) {
        
        /// Setup signal
        _threadIsInitialized = NO;
        _threadIsInitializedSignal = [[NSCondition alloc] init];
        [_threadIsInitializedSignal lock];
        
        /// Setup thread
        _thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadWorkload) object:nil];
        _thread.name = @"com.nuebling.mac-mouse-fix.global-event-tap";
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

@end
