
//
// --------------------------------------------------------------------------
// DisplayLink.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Discussion [Oct 2026]
///     This is a custom displayLink based on mach timer (`mk_timer`) and VSync timestamp APIs (`SLSDisplayGetPriorVBLTime` and `SLSDisplayGetCurrentVBLDelta`).
///     Why use custom implementation instead of Apple displayLink (`CVDisplayLink` or `CADisplayLink`):
///         Complications and reliability:
///             - We used to use CVDisplayLink - had lots of complications and reliability issues.
///                 Historical: Think we cleaned them up and fixed them in 'No more dispatch queues' refactor with lots of Opus 5.5. help. But then replace with `mk_timer` shortly after. [Oct 2026]
///             - This is only ~200 lines of code.
///                 - CVDisplayLink was 3x more code than this (even after the 'No more dispatch queues' cleanup)
///             - CVDisplayLink delivers to its own thread, which it recreates on every start/stop, you then have to hop to your `_runLoop` and synchronize things, and reapply `thread_policy_set` and hope everything's fast - just complicating.
///             - CADisplayLink is only available on newer macOS versions. (At least in public SDK, didn't check if it could already be used before) So you'd have to maintain both CVDisplayLink and CADisplayLink backends.
///             - CADisplayLink is per-display and can't be retargeted to a new display which is a little bit complicating.
///         Performance and control:
///             - This guarantees that repeatedly calling start/stop is extremely cheap (Maybe it cheap as well on CVDisplayLink but I didn't fully trust that I guess)
///             - This gives us full control over the `VBLPhase` which we think is important for smoothness when sending events.
///             - Any time you wanna wait for the next frame once - you can just use DisplayLink.m and stop it from the callback, and it's optimal for that, too.
///                 (History: We wanted to do that for the coalescing stuff in ModifiedDrag.m, which prompted us to rewrite DisplayLink.m on top of `mk_timer` instead of using one-off implementation of CFRunLoopTimer + `SLSDisplayGetPriorVBLTime` and `SLSDisplayGetCurrentVBLDelta` which is more complicated at callsite and I think a little slower. [Oct 2026])
///     Improvement ideas:
///         Work-time-estimation: (don't think we need this)
///             Only possible downside I can see vs CVDisplayLink and CADisplayLink is I think they measure the amount
///             of time that the callback takes and then reschedule the start time so that the work is finished by a certain vblPhases (See `VBLPhase`)
///             However, I don't see any evidence that this helps us at all, and would be pretty easy to implement if we decide otherwise.
///                 Why I don't think it helps?: Our work should be super cheap, if it's not near-instant it's because whole system is getting unresponsive and the delays are rather unpredictable.
///                 We're generally hitting vblPhases better than the real trackpad driver, I think. (Test with `vblphase.m`)
///         Avoid callbacks in bad vblPhase 'zones'
///             - Phase can be delayed a lot to random points when under load - maybe should skip / delay callbacks when in 'bad' zone?
///                 Why this might matter: Our tests in ModifiedDrag.m [Oct 2026] showed that sending (all of the) DockSwipes close to phase 0.0 caused noticable stutter. (For Scroll event I didn't yet notice specific phase causing stutters [Oct 2026])
///                 (See `VBLPhase` and test phase with `vblphase.m`)
///         Avoid callbacks close together?
///             I sometimes saw pattern where every second frame callback is delayed, and delivers really close to the next one. Might be better to skip?
///                 However, I saw same pattern for real Trackpad events (using `vblphase.m`). Probably fine [Oct 2026]
///         Use real time thread (instead of max priority in the normal band (`MAXPRI_USER`) via our `set_thread_priority()` [Oct 2026]) (@afterNoGCDTodo)
///             -> Might solve bad-phase-zone and close-together-callabacks issues (above). Haven't tried real time scheduling at all so far. [Oct 2026]
///     Other info:
///         Opus 5.5 says CADisplayLink and CFRunLoopTimer are built on `mk_timer`, too, just like this DisplayLink
///     Credits to Opus 5.5:
///         The private APIs this was built on were discovered / shown to me by Opus 5.5 (`mk_timer`, `SLSDisplayGetCurrentVBLDelta`, `SLSDisplayGetPriorVBLTime`).

#import "DisplayLink.h"
#import "Logging.h"
#import "mach/port.h"
#import "NSScreen+Additions.h"
#import "SharedUtility.h"
#import "Threads.h"
#import "MathObjc.h"
#import "mk_timer.h"

#define range(i, n) (int i = 0; i < (n); i++)

#pragma mark - VSync helpers

uint64_t CGDisplay_NearestVBLTime(CGDirectDisplayID displayID, const char *beforeOrAfter, uint64_t anchorInMachTime, VBLPhase phaseShift) {
    /// Helper
    /// Usage: Pass `mach_absolute_time()` as the `anchorInMachTime` to get the nearest VSync time relative to now.
    /// Background: VBL stands for `vertical blank` it's the time between the display reading the last pixel of the previous frame to reading the first pixel of the next frame.

    /// Gather the raw VSync data for the display
    ///     Opus 5.5 says this is what CADisplayLink uses for vsync on macOS 27.
    ///     Opus 5.5. says this could be multiple frames stale, or even in the future (somehow? Didn't understand that part)
    uint64_t lastVBLTime = SLSDisplayGetPriorVBLTime(displayID);    /// Gets last VSync time from WindowServer via shared memory - should be pretty fast and accurate! [Oct 2026]
    uint64_t lastVBLDelta = SLSDisplayGetCurrentVBLDelta(displayID);

    uint64_t result;
    if (!lastVBLTime || !lastVBLDelta) {
        /// Error
        result = 0;
    } else {
        /// Extrapolate the VSync data to the frame-cycle closest to our anchor
        ///     Note: This is arithmetic version, before,  we were using simpler-to-understand loops. Arithmetic is faster in case `SLSDisplayGetPriorVBLTime` is really old. Not sure this can happen. Opus 5.5 was concerned about it. [Oct 2026]
        int64_t grid0 = lastVBLTime + (phaseShift * lastVBLDelta);
        int64_t grid1 = grid0 + lastVBLDelta;
        if      (!strcmp(beforeOrAfter, "before")) result = roundToGrid_Int(anchorInMachTime-1, grid0, grid1, "down");
        else if (!strcmp(beforeOrAfter, "after"))  result = roundToGrid_Int(anchorInMachTime+1, grid0, grid1, "up");
        else                                       mfrequire(false, @"Invalid argument");
    }

    return result;
}

#pragma mark - DisplayLink class

#define kUseCriticalTimer (1) /** Feel like this lowers framedrops. When using DisplayLink to coalesce DockSwipes in ModifiedDrag.m [Oct 2026]. Could be placebo. Not sure if (also) appropriate for `kVBLPhase_DefaultForAppKitUpdates` */

@implementation DisplayLink
    {

        /// Init
        VBLPhase _phaseShift;
        CFRunLoopRef _runLoop;
        NSString *_name;
        mach_port_name_t _mkTimer;

        /// Link display
        CGDirectDisplayID _linkedDisplay;

        /// Start/stop
        DisplayLinkCallback _callback;
        bool _timerIsArmed;
        bool _isRunning;

        /// Callback
        uint64_t _lastLastFrame;

        /// Debug
        uint64_t _lastNow;

        /// For dealloc [Oct 2026]
        CFMachPortRef _timerMachPort;
    }

    #define _mfrequire(condition, reason, args...) mfrequire((condition), @"DisplayLink (%@) " reason, self->_name, ##args)
    #define _mfassert(condition, reason, args...)  mfassert((condition), @"DisplayLink (%@) " reason, self->_name, ##args)
    #define _DDLogDebug(message, args...)          DDLogDebug("DisplayLink (%@) " message, self->_name, ##args)

    + (instancetype) displayLinkWithPhaseShift: (VBLPhase)phaseShift runLoop: (CFRunLoopRef)runLoop name: (NSString *)name {
        return [[DisplayLink alloc] initWithPhaseShift: phaseShift runLoop: runLoop name: name];
    }
    - (instancetype) initWithPhaseShift: (VBLPhase)phaseShift runLoop: (CFRunLoopRef)runLoop name: (NSString *)name {
        if (!(self = [super init])) return nil;

        _phaseShift = phaseShift;
        _runLoop = runLoop;
        _name = name;
        _mkTimer = mk_timer_create();
        _mfrequire(_mkTimer, "mk_timer_create failed");
        _timerIsArmed = false;
        _isRunning = false;

        _timerMachPort = (void *)CFAutorelease(CFMachPortCreateWithPort(kCFAllocatorDefault, _mkTimer, mkTimerCallback, &(CFMachPortContext){
            .info = (__bridge void *)self,
            .retain = NULL, .release = NULL, /// Don't need to own this since we destroy this stuff in -dealloc [Oct 2026]
        }, /*shouldFreeInfo*/NULL));
        CFRunLoopSourceRef timerSource = (void *)CFAutorelease(CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _timerMachPort, /*order*/0));
        _mfrequire(timerSource, "Wrapping _mkTimer in a CFRunLoopSourceRef failed");
        CFRunLoopAddSource(_runLoop, timerSource, kCFRunLoopCommonModes);

        return self;
    }

    - (CFRunLoopRef) runLoop { return _runLoop; }

    static void mkTimerCallback(CFMachPortRef port, void *msg, CFIndex size, void *info) {
        DisplayLink *self = (__bridge id)info;

        self->_timerIsArmed = false;

        if (!self->_isRunning) return;

        uint64_t now = mach_absolute_time();
        uint64_t lastFrame = CGDisplay_NearestVBLTime(self->_linkedDisplay, "before", now, self->_phaseShift) ?: fallbackPriorVBLTime(now);
        uint64_t frameTime = SLSDisplayGetCurrentVBLDelta(self->_linkedDisplay) ?: kFallbackVBLDelta;

        uint64_t tolerance = defaultVBLTolerance(frameTime); /// Prevent quick-succession wakeups in case the VBLTime window shifts forwards a little bit. Not sure this happens. Opus 5.5 is concerned [Oct 2026]
                                                             /// Update: There are a few more framedrops than I'd expect - maybe setting to 0.0 helps? Not sure. [Oct 2026]

        if (lastFrame <= self->_lastLastFrame + tolerance) { /// [Oct 2026] Last frame being equal rarely happens but causes division by zero in the animators. Have never seen wakeups in quick succession within `tolerance`.
            _DDLogDebug("Woke up twice lastFrame: %f, _lastLastFrame: %f",
                machTimeToSeconds(now - lastFrame) * 1e3, machTimeToSeconds(now - self->_lastLastFrame) * 1e3);
        }
        else {

            uint64_t nextFrame = lastFrame + frameTime;
            DisplayLinkCallbackTimeInfo timeInfo = {
                .lastFrame         = machTimeToSeconds(lastFrame),
                .timeBetweenFrames = machTimeToSeconds(frameTime),
                .nextFrame         = machTimeToSeconds(nextFrame)
            };

            uint64_t tsBeforeCallback = mach_absolute_time();
            self->_callback(timeInfo);
            uint64_t tsAfterCallback = mach_absolute_time();

            if (runningDebugMode()) {
                if (self->_lastNow) {
                    uint64_t realLastFrame = CGDisplay_NearestVBLTime(self->_linkedDisplay, "before", now, /*phaseShift*/0.0);
                    double phaseShift = ((double)(now - realLastFrame) / frameTime);

                    char phaseShiftString[21]; { int p = 0; /// Little visualization inspired by Claude's vbldelta.m [Oct 2026]
                        int phaseShiftRounded = roundToGrid(phaseShift * 20, /*grid0*/0, /*grid1*/1, "down");
                        for range(i, 20) phaseShiftString[p++] = i == phaseShiftRounded ? '#' : '_';
                        phaseShiftString[20] = 0;
                    }
                    _DDLogDebug("delta: %06.2f, phaseShift: %.2f (%{public}s), callbackPhaseDuration %05.2f", 1e3*machTimeToSeconds(now - self->_lastNow), phaseShift, phaseShiftString, ((double)(tsAfterCallback - tsBeforeCallback))/frameTime);
                }
                self->_lastNow = now;
            }

            self->_lastLastFrame = lastFrame;
        }

        if (self->_isRunning) scheduleNextCallback(self);
    }

    static void scheduleNextCallback(DisplayLink *self) {
        if (self->_timerIsArmed) return;

        uint64_t now = mach_absolute_time();
        uint64_t nextCallbackTime = CGDisplay_NearestVBLTime(self->_linkedDisplay, "after", now, self->_phaseShift) ?: (fallbackPriorVBLTime(now) + kFallbackVBLDelta);

        kern_return_t ret;
        if ((kUseCriticalTimer)) ret = mk_timer_arm_leeway(self->_mkTimer, MK_TIMER_CRITICAL, nextCallbackTime, /*mk_timer_leeway*/0);
        else                     ret = mk_timer_arm(self->_mkTimer, nextCallbackTime);
        _mfrequire(!ret, "mk_timer_arm failed");
        self->_timerIsArmed = true;
    }

    - (void) startWithCallback: (DisplayLinkCallback _Nullable)callback {
        assertRunLoop(_runLoop);

        if (callback) _callback = callback;

        if (_isRunning) return;

        _mfrequire(_callback, "DisplayLink started without a callback set.");
        if (!_linkedDisplay) { /// This can happen in some rare edge-cases currently says Opus 5.5 [Oct 2026]
            _linkedDisplay = CGMainDisplayID();
            _mfassert(false, "DisplayLink started without a linked display set");
        }
        scheduleNextCallback(self);
        _isRunning = true;

        _lastLastFrame = 0;
    }
    - (void) stop {
        assertRunLoop(_runLoop);

        if (!_isRunning) return;
        _isRunning = false;

        if (!_timerIsArmed) return;

        uint64_t canceledWakeUpTime = 0;
        kern_return_t ret = mk_timer_cancel(_mkTimer, &canceledWakeUpTime);
        _mfassert(!ret, @"mk_timer_cancel failed");

        if (!ret && !canceledWakeUpTime) {
            /// Handle minor race, where the timer has already fired but the runLoop hasn't invoked `mkTimerCallback`, yet.
            ///     This can lead to weird behavior, if you're stopping and then restarting the DisplayLink in this period (the period between timer firing and `mkTimerCallback`) the next `mkTimerCallback` may fire for a scheduled time that is *before* the last start command. Which is inconsistent with how start normally works. (Normally it schedules the first timer for the first VSync *after* the start command)
            ///         Is this just theoretical problem? Maybe. Opus 5.5 says the 'fallback timer' strategy we're thinking about implementing in ModifiedDrag.m might be messed up by this inconsistency. Consistent behavior is better either way, probably. [Oct 2026]
            ///     Solution: Drain the mach port.
            ///     Credits: Opus 5.5

            struct { mk_timer_expire_msg_t msg; mach_msg_trailer_t trailer; } buf = {};
            mach_msg_timeout_t timeoutInMs = 10;
            mach_msg_return_t ret = mach_msg((mach_msg_header_t *)&buf, MACH_RCV_MSG | MACH_RCV_TIMEOUT, /*send_size*/0, /*rcv_size*/sizeof(buf), /*rcv_name*/_mkTimer, /*timeout*/timeoutInMs, /*notify*/MACH_PORT_NULL);
            if (!ret) _DDLogDebug("Drained stale mk_timer.");
            else      _mfassert(false, @"Draining stale mk_timer message failed: %s", mach_error_string(ret));
        }

        _timerIsArmed = false;
    }
    - (BOOL) isRunning {
        assertRunLoop(_runLoop);
        return _isRunning;
    }

    - (void) linkToMainScreen { /// @afterNoGCDTodo: Use displayUnderMousePointer instead of mainScreen instead (across the entire program) [Oct 2026]
        assertRunLoop(_runLoop);
        _linkedDisplay = [[NSScreen mainScreen] displayID];
    }

    - (void)dealloc {
        CFMachPortInvalidate(_timerMachPort); /// [Oct 2026] Opus 5.5 says this is necessary on macOS 27, even though the docs say it gets invalidated automatically when the `mach_port` gets destroyed.
        mk_timer_destroy(_mkTimer);
    }

@end
