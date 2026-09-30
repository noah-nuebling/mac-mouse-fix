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

#if IS_MAIN_APP
    int _enableRunLoopAsserts = 1;
#elif IS_HELPER
    int _enableRunLoopAsserts = 0; /// See where this enabled in the Helper's entry point.
#endif

/// From xnu osfmk/kern/sched.h (not in the SDK)
#define MAXPRI_USER     63
#define BASEPRI_DEFAULT 31

void set_thread_priority(int priority, bool round_robin) {

    /// Increase thread priority via `thread_policy_set` mach API.
    ///     Notes:
    ///     What priority to choose?
    ///         - CVDisplayLink's 'high priority thread' sets priority to 54, round-robin. We can even go a little higher than that to 63 (`MAXPRI_USER`).
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

    if (runningPreRelease()) {
        /// Read back and validate the effective policy of the thread via `thread_info` (`thread_policy_get` just returns whatever `importance` you pass it or whatever. Claude says this API works. [Sep 2026])
        thread_extended_info_data_t extended_info = {}; mach_msg_type_number_t extended_info_count = THREAD_EXTENDED_INFO_COUNT;
        ret = thread_info(threadport, THREAD_EXTENDED_INFO, (thread_info_t)&extended_info, &extended_info_count);
        mfassert(extended_info.pth_priority == priority, @"extended_info.pth_priority == %d after setting to %d", extended_info.pth_priority, priority);
        mfassert(extended_info.pth_policy == (round_robin ? POLICY_RR : POLICY_TIMESHARE), @"extended_info.pth_policy == %d after setting to %d", extended_info.pth_policy, (round_robin ? POLICY_RR : POLICY_TIMESHARE));
        mfassert(extended_info.pth_maxpriority == MAXPRI_USER, @"extended_info.pth_maxpriority == %d, expected %d (MAXPRI_USER)", extended_info.pth_maxpriority, MAXPRI_USER);
    }
}

void manuallyLoadThreadsDotH(void) {

    /// Set the priority of the mainThread
    ///     Set this to `MAXPRI_USER-1` since the mainThread draw the cursor during twoFingerSwipe. Little lower than `GlobalEventTapThread` because scrolling perf is still more important. (Untested, maybe there's a case to set this low to not take resources from the scrolling app.) [Sep 2026]
    set_thread_priority(MAXPRI_USER-1, /*round_robin*/true);
}
