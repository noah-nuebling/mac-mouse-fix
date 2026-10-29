//
// --------------------------------------------------------------------------
// Threads.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Threads.h"
#import "libproc.h"
#import "SharedUtility.h"
#import "MFGate.h"
#import "Logging.h"

#pragma mark - Elevating thread priority

/**
 Ideas and notes about elevating thread priority: [Oct 2026]
    (Also see `Problem: No thread priority` in the `.h` file [Oct 2026])
    NSActivityLatencyCritical – says it makes timers and IO more precise, not sure if applicable here. [Jun 2026]
    'Mach Scheduling and Thread Interfaces': https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/KernelProgramming/scheduler/scheduler.html [Jun 2026]
        Contains `thread_policy_set` which we think is core API for changing thread priority [Oct 2026]
    TN2169 High Precision Timers in iOS / OS X: https://developer.apple.com/library/archive/technotes/tn2169/_index.html
        micropython GH Issue about improving timers: https://github.com/micropython/micropython/issues/8621
            Sidenote: They say 'nice' does nothing on macOS. We're setting that in our launchd config. [Apr 2025]
            SideSideNote: Is there a way to have _launchd_ start the MMF Helper faster after boot? Helper gets started *after* all the windowed apps, with all the background apps. [Apr 2025]
*/

/// From xnu osfmk/kern/sched.h (not in the SDK)
#define MAXPRI_USER     63
#define BASEPRI_DEFAULT 31

void set_thread_priority(int priority, bool round_robin) {

    /// Increase thread priority via `thread_policy_set` mach API.
    ///     Notes:
    ///     What priority to choose?
    ///         - CVDisplayLink's 'high priority thread' sets priority to 54 (importance=23), round-robin. We can even go a little higher than that to 63 (`MAXPRI_USER`).
    ///         - `com.apple.AppleUserHIDDrivers` uses priority 63, round-robin on all its threads - so should be appropriate for drivers.
    ///     If `MAXPRI_USER` isn't enough: [Sep 2026]
    ///         - You can prioritize the thread even more (priority >= 97 band) using `THREAD_TIME_CONSTRAINT_POLICY` (That's a real time thread, you see that in `coreaudiod` for example.)
    ///         - There's also the Quality-of-Service options, but I don't understand, those [Sep 2026]
    ///     Other:
    ///         Apparently this removes the the threads from QoS says Claude, I'm not sure if/how that matters [Sep 2026]
    ///     Tips and tricks:
    ///         `ps -M -p PID` shows per-thread priorities for a process. (E.g. 63R -> priority 63, round-robin)

    kern_return_t ret = 0;

    /// Read the 'base priority' of this process via `proc_pidinfo`. (Claude says that's what CVDisplayLink does, too. Don't fully understand [Sep 2026])
    int base_priority;
    struct proc_taskallinfo info;
    int retsize = proc_pidinfo(getpid(), PROC_PIDTASKALLINFO, /*arg*/0, &info, sizeof(info));
    if (retsize > 1) base_priority = info.ptinfo.pti_priority;
    else             { base_priority = BASEPRI_DEFAULT; mfassert(false, @"proc_pidinfo returned %d. errno: %s.", retsize, strerror(errno)); }

    /// Configure the thread via `thread_policy_set`
    int importance = priority - base_priority;
    mach_port_t threadport = pthread_mach_thread_np(pthread_self());
    ret = thread_policy_set(threadport, THREAD_EXTENDED_POLICY, (thread_policy_t)&(thread_extended_policy_data_t){ .timeshare = !round_robin }, THREAD_EXTENDED_POLICY_COUNT);
    mfassert(!ret, @"thread_policy_set(THREAD_EXTENDED_POLICY) error: %s", mach_error_string(ret));
    ret = thread_policy_set(threadport, THREAD_PRECEDENCE_POLICY, (thread_policy_t)&(thread_precedence_policy_data_t){ .importance = importance }, THREAD_PRECEDENCE_POLICY_COUNT);
    mfassert(!ret, @"thread_policy_set(THREAD_PRECEDENCE_POLICY) error: %s", mach_error_string(ret));

    if (runningDebugMode()) {
        /// Read back and validate the effective policy of the thread via `thread_info` (`thread_policy_get` just returns whatever `importance` you pass it or whatever. Claude says this API works. [Sep 2026])
        thread_extended_info_data_t extended_info = {}; mach_msg_type_number_t extended_info_count = THREAD_EXTENDED_INFO_COUNT;
        ret = thread_info(threadport, THREAD_EXTENDED_INFO, (thread_info_t)&extended_info, &extended_info_count);
        mfassert(extended_info.pth_priority == priority, @"extended_info.pth_priority == %d after setting to %d", extended_info.pth_priority, priority);
        mfassert(extended_info.pth_policy == (round_robin ? POLICY_RR : POLICY_TIMESHARE), @"extended_info.pth_policy == %d after setting to %d", extended_info.pth_policy, (round_robin ? POLICY_RR : POLICY_TIMESHARE));
        mfassert(extended_info.pth_maxpriority == MAXPRI_USER, @"extended_info.pth_maxpriority == %d, expected %d (MAXPRI_USER)", extended_info.pth_maxpriority, MAXPRI_USER);
    }
}

#pragma mark - Lifecycle

#if IS_MAIN_APP
    int _enableRunLoopAsserts = 1;
#elif IS_HELPER
    int _enableRunLoopAsserts = 0; /// See where this enabled in the Helper's entry point.
#endif

void threads_configureMainThread(void) {

    /// Set the priority of the mainThread
    ///     Set this to `MAXPRI_USER-1` since the mainThread draw the cursor during twoFingerSwipe. Little lower than `IOThread` because scrolling perf is still more important. (Untested, maybe there's a case to set this low to not take resources from the scrolling app.) [Sep 2026]
    set_thread_priority(MAXPRI_USER-1, /*round_robin*/true);
}

#pragma mark - General threading helpers

/// Standard patterns (Try to use these consistently) (greppability, I guess) (We might not actually end up using this) [Oct 2026]
///     stdlib:
///         Sleep for duration: `usleep(1e6 * <seconds>)`
///         Sleep until deadline: `-[NSThread sleepUntilDate: <date>]`
///         Timers / delays / cancellable work: `+[NSTimer mf_scheduledTimerWithTimeInterval:]` / `-[NSTimer initWithFireDate:]` / `CFRunLoopTimer`
///     Our helpers:
///         Thread hops / wait on other thread / async: `mfrun` / `mfrunAndWait` / `MFGate`
///         Multi-step with waiting: (async-await pattern): `mfdetachThread` + `usleep` + `mfrunAndWait`

void mfdetachThread(NSQualityOfService qos, void (^workload)(void)) {
    NSThread *thread = [[NSThread alloc] initWithBlock: workload];
    //thread.stackSize = 16 * 1024; /// 16 KB is min size. Opus 5.5 say it's small for general purpose helper and pages won't be allocated anyways until you use them. [Oct 2026]
    thread.qualityOfService = qos;
    [thread start];
}

void mfrun(CFRunLoopRef rl, void (^workload)(void)) {

    /// This codebase's standard (greppable) way to run a block on a runLoop (Use this over `dispatch_async`) [Oct 2026]
    ///     Formerly `MFCFRunLoopPerform` [Oct 2026]

    CFRunLoopMode mode = kCFRunLoopCommonModes; /// I think this is ok to use everywhere. (Only thing non-default mode would be used for is tracking loops I think?) [Oct 2026]
    CFRunLoopPerformBlock(rl, mode, workload);
    CFRunLoopWakeUp(rl);
}

void mfrunAndWait(CFRunLoopRef rl, void (^workload)(void)) {

    /// Like `mfrun` but it blocks until the workload is done. (Use this over `dispatch_sync`) [Oct 2026]
    /// Caution: This can lead to deadlocks! See `MFGate.m` comments [Oct 2026]

    if (CFEqual(rl, CFRunLoopGetCurrent()))
        workload();
    else {
        MFGate *gate = [MFGate new];
        mfrun(rl, ^{
            workload();
            [gate signalWorkCompleted];
        });
        [gate waitForWork];
    }
}

#pragma mark - IOThread

#if IS_HELPER
@implementation IOThread

    /// Vars

    static CFRunLoopRef _runLoop;

    static NSThread *_thread;

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

        /// Increase thread priority
        set_thread_priority(63, /*round_robin*/true);

        /// Add empty source so the runLoop doesn't exit immediately
        CFRunLoopSourceRef emptySource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &(CFRunLoopSourceContext){0});
        CFRunLoopAddSource(_runLoop, emptySource, kCFRunLoopCommonModes);

        /// Disable the native per-callout autoreleasePools
        ///     This isn't necessary, I guess it creates consistency between macOS versions for everything to go through our @autoreleasePool (below) [Oct 2026]. (Update: Claude says this actually doesn't affect timers, see CFRunLoopRunInMode comment [Oct 2026])
        if (@available(macOS 11.0, *)) {
            extern Boolean _CFRunLoopSetPerCalloutAutoreleasepoolEnabled(Boolean enabled) API_AVAILABLE(macos(10.16), ios(14.0), watchos(7.0), tvos(14.0)); /// Src: [Oct 2026] https://github.com/swiftlang/swift-corelibs-foundation/blob/main/Sources/CoreFoundation/include/CFPriv.h
            _CFRunLoopSetPerCalloutAutoreleasepoolEnabled(false);
        }

        /// Run the runLoop
        ///     This thread is blocked by the runLoop now
        while (true) {
            /// Wrap in autoreleasePool
            ///     Necessary on older macOS versions. Probably before 11.0. See `_CFRunLoopSetPerCalloutAutoreleasepoolEnabled` (above) [Oct 2026]
            @autoreleasepool {
                (void)CFRunLoopRunInMode(kCFRunLoopDefaultMode, /*seconds*/DBL_MAX, /*returnAfterSourceHandled*/true); /// Claude says this doesn't return (which drains the pool) after handling CFRunLoopTimerRef/NSTimer or blocks (mfrun). Probably fine. Could alternatively use `CFRunLoopObserverRef` [Oct 2026] Claude also says `_CFRunLoopSetPerCalloutAutoreleasepoolEnabled` doesn't affect timers and timers always drain some internal pool in macOS 10.15 or later. [Oct 2026]
            }
        }
    }

    /// Getter / main interface
    + (CFRunLoopRef)runLoop {
        mfassert(_runLoop);
        return _runLoop;
    }

@end
#endif
