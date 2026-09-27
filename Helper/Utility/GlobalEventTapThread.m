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
///             - <TODO: Think about/document other interaction points>
///
///    Update: [Apr 2025]
///     Look into elevating thread-priority.
///         TN2169 High Precision Timers in iOS / OS X: https://developer.apple.com/library/archive/technotes/tn2169/_index.html
///             micropython GH Issue about improving timers: https://github.com/micropython/micropython/issues/8621
///                 Sidenote: They say 'nice' does nothing on macOS. We're setting that in our launchd config.
///                 SideSideNote: Is there a way to have _launchd_ start the MMF Helper faster after boot? Helper gets started *after* all the windowed apps, with all the background apps.
///     Update: [Jun 2026]
///         NSActivityLatencyCritical – says it makes timers and IO more precise, not sure if applicable here.
///         'Mach Scheduling and Thread Interfaces': https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/KernelProgramming/scheduler/scheduler.html
///     Update: [Sep 2026]
///         Did more digging (asking Claude) - `thread_policy_set` is the core API for doing this. (Also described in 'Mach Scheduling and Thread Interfaces')
///         `thread_policy_get` says that the CVDisplayLink 'high priority' thread uses timeshare=NO (doesn't get deprioritized when running more) and importance=23 (moderately elevated) IIRC.
///             The next step up from that would be raising importance to max and if that is not enough, going to real-time scheduling.

#import "GlobalEventTapThread.h"
#import "MFGate.h"
#import "Logging.h"

@implementation GlobalEventTapThread

/// Vars

static CFRunLoopRef _runLoop;

static NSThread *_thread;
/// ^ I usually use dispatch queue but it doesn't let you guarantee that you're not on the main thread. So we're using threads directly.

static MFGate *_runLoopGate;
static MFGate *_startGate;

/// Init

+ (void)load_Manual {

    /// [Sep 2026] `+load_Manual`and `+start` are only called from the Helper's entry point/start sequence in `AccessibilityCheck.m`
    ///     see there to convince yourself that this is thread safe and stuff.

    /// Setup gates
    _runLoopGate = [MFGate new];
    _startGate = [MFGate new];

    /// Setup thread
    _thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadWorkload) object:nil];
    _thread.name = @"com.nuebling.mac-mouse-fix.global-event-tap";
    _thread.qualityOfService = NSQualityOfServiceUserInteractive;
    _thread.threadPriority = 1.0;
    [_thread start];

    /// Wait unil runLoop is available
    [_runLoopGate waitForWork];
}

+ (void)start {
    [_startGate signalWorkCompleted];
}

/// Thread workload
+ (void)threadWorkload {
    
    /// Store runLoop of new thread
    _runLoop = CFRunLoopGetCurrent();
    [_runLoopGate signalWorkCompleted];

    /// Wait for +start
    [_startGate waitForWork];

    /// Add empty source so the runLoop doesn't exit immediately
    CFRunLoopSourceRef emptySource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &(CFRunLoopSourceContext){0});
    CFRunLoopAddSource(_runLoop, emptySource, kCFRunLoopCommonModes);

    /// Run the runLoop
    ///     This thread is blocked by the runLoop now
    ///     TODO: Add an autoreleasepool to this runLoop to prevent abandoned memory. See:
    ///         - Example implementation: https://stackoverflow.com/questions/11436826/how-to-manage-the-autorelease-pool-of-a-nsrunloop-running-in-a-secondary-thread
    ///         - Quinn eskimo on abandoned memory: https://developer.apple.com/forums/thread/716261
    while (true) CFRunLoopRun();
}

/// Getter / main interface
+ (CFRunLoopRef)runLoop {
    mfassert(_runLoop);
    return _runLoop;
}

@end
