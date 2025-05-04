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
///
///     Edit2: [Dec 2024] I think since the `twoFingerModifiedDrag` draws a fake mouse pointer (necessarily, on the mainthread), with relatively high CPU usag,  it's probably good to put inputProcessing on a separate thread to ensure responsiveness.
///         Also, all processing of input events should be on the same thread (so on this thread, not the mainthread or some dispatchqueue) to prevent race conditions and problems where events are processed in the wrong order. (I think see order-of-events problems during click-and-drag sometimes under MMF 3.0.3. – seems like clicks and drags are processed on different threads. (?) Also, doubleclicks are – stupidly – processed on the mainthread iirc, (Mightt be wrong, don't remember how this stuff works anymore – but the threading architecture is terrible and overcomplicated.))
///         Update [Apr 2025] another practical reason to change this is the crazy crashes that happened after we tried to change scroll-event scheduling in 3.0.2. IIRC it took us months to get the multithreading bugs under control when building MMF 3, and it seems that changing the timings can make the whole house-of-cards fall apart. We don't want that! Coordinating everything on 1 thread, should allow for more 'fearless refactors'.
///     Edit3: [Apr 2025] If we put everything on IOThread (that's what we've been calling GlobalEventTapThread lately), this should greatly reduce potential for raceconditions and deadlocks and could simply some existing code a lot, since we won't need as much locking and dispatching to dispatchqueues and stuff, I think.
///         However, they are still going to be *interaction-points between the IOThread and mainThread* which have high potential for race-conditions.
///         Thread-interaction points:
///             - Remaps loading
///             - <TODO: Think about other interaction points>
///
///    Update: [Apr 2025]
///     Look into elevating thread-priority.
///         TN2169 High Precision Timers in iOS / OS X: https://developer.apple.com/library/archive/technotes/tn2169/_index.html
///             micropython GH Issue about improving timers: https://github.com/micropython/micropython/issues/8621
///                 Sidenote: They say 'nice' does nothing on macOS. We're setting that in our launchd config.
///                 SideSideNote: Is there a way to have _launchd_ start the MMF Helper faster after boot? Helper gets started *after* all the windowed apps, with all the background apps.
///

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
    ///     TODO: Add an autoreleasepool to this runLoop to prevent abandoned memory. See:
    ///         - Example implementation: https://stackoverflow.com/questions/11436826/how-to-manage-the-autorelease-pool-of-a-nsrunloop-running-in-a-secondary-thread
    ///         - Quinn eskimo on abandoned memory: https://developer.apple.com/forums/thread/716261
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
