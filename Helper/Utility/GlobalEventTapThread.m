//
// --------------------------------------------------------------------------
// EventTapQueue.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/**
    @noGCDCleanup Maybe update / go over this one more time at the end of the refactor 'No more dispatch queues' refactor.

    MMF Concurrency Model [Sep 2026]
        MainApp:    Everything on `mainThread`
        HelperApp:  Everything on `GlobalEventTapThread`, except for things that have to be on `mainThread` (AppKit, TISInputSource, possibly CVDisplayLinkStart/Stop, maybe more)
        -> max 2 threads per process (This possibly leaves out some background download stuff or whatever that doesn't interact much with the core, we don't see that as part of the 'architecture' or 'model' we're describing or caring about here.)

    About the 2-thread-model in HelperApp:
        Why?
            Before [Sep 2026] 'No more dispatch queues' refactor, we used many `dispatch_queues` in HelperApp.
                Why do that?
                    We thought that by isolating roughly every file in the core event processing with its own dispatch queue,
                    you'd get maximum parallelism while easily guaranteeing no races.
                        (This is roughly the Swift Actor model, but before Swift Actors, done with `dispatch_queues`)
                    The basic premise (max parallelism, no races) was true, however, in practise, this was a really bad idea, still: (To be exact, there were races in Buttons.swift, because we gave up on queue-isolation at some point because it was difficult, and races didn't actually cause problems there and stuff)
            Why *many* threads/queues is a bad idea:
                Problem: deadlocks
                    Overviewiew: Even if per module `dispatch_queues` pretty well protect state from becoming invalid, when you have a bunch of them
                        interacting with `dispatch_sync` (necessary for reading anything from another queue) thing start deadlocking.
                        As far as I was aware, there was no good way provided by GCD to recover from this. (`dispatch_sync` doesn't even support timeouts, though doing timeouts right might also be really hard)
                    Practical memories:
                        I remember spending months to get twoFingerSwipe to work without constant deadlock after coding it up when making MMF 3.0.0.
                        IIRC any later refactor attempt in the Helper's core event processing was scary because it would probably change timing in way that made things deadlock again.
                            Even remember shipping some update between 3.0.0 and 3.1.0 that caused lots more deadlocks. (The `MFDisplayLinkWorkType` stuff I think)
                        General hum of people reporting 'scrolling stopped working' which might have something to do with this (but maybe all of it was also DisplayLink.m failing to start and stuff, I think reports stopped after adding the retry-loop, but not sure.)
                Problem: Parallelization doesn't help
                    The mouse-event processing in the helper is inherently pretty serial, I think, putting everything on different queue, won't deliver result much quicker, I'm pretty sure.
                    The CPU usage of the helper is low anyways - the goal is keeping things responsive - our part in that is just processing the events faster than the display frame-period. Which we're super super easily doing (I'm pretty sure)
            Why *dispatch queues* instead of threads are bad idea?
                (like before  'No more dispatch queues' refactor)
                Problem: No thread priority
                    My theory for how MMF Helper can cause framedrops / unresponsiveness at all (even though it uses little CPU), is when system is under load and deprioritizes helper to keep the foreground app responsive (but then actually makes forground app less responsive, because the mouse driver is being throttled).
                    -> If you use normal threads instead of GCD, you can tell kernel to prioritize thread with `thread_set_policy` - pretty sure this will help much more for responsiveness. (Will implement soon in GlobalEventTapThread) @noGCDCleanup
                Dispatch queues have less powerful primitives:
                    You can't even check which `dispatch_queue` you're on. `dispatch_sync` can't time out. Thread primitives are more powerful (Maybe I didn't understand GCD properly, but to be fair it's also more obscure)
                    -> Weak philosophical point: It's like this kinda weird experimental, platform-specific reeinvention of the wheel, with limitations that I think designers didn't really design against real world - better to use robust, rock solid, well known threading primitives. Because it's already hard.
                They solve no problem:
                    As far as I'm aware, the only thing that `dispatch_queues` do better than normal threads, is they are faster and cheaper to create/destroy (they are green threads) ... however,
                        - NSThread is already really fast and fine for any reasonable amount of threads for a GUI app or a mouse driver.
                        - `dispatch_queue` still has weird edge case, when you wait on too many queues, you can get thread explosion.
                        - If your work is CPU bound (not just waiting for IO) then having more queues/threads than CPU cores won't help anyways.
                        -> Why the heck is this being promoted for GUI app developers.
            Why 2 threads? (GlobalEventTapThread and MainThread)
                The only thing that I think could contend CPU with the main event processing is the ScreenDrawer.swift's AppKit drawing driven through twoFingerSwipe -> PointerFreeze > ScreenDrawer.
                    -> This is pretty expensive since it's AppKit (I'm pretty sure [Sep 2026]), and it HAS to be on the mainThread.
                So we want the eventProcessing to be on a separate thread from mainThread to not contend with expensive AppKit drawing -> That's GlobalEventTapThread.
                    Everything peripheral like Licensing and Config and Remaps then got pulled onto GlobalEventTapThread as well since it all heavily interacts with eventProcessing
                    and with each other and would need complicated locking or thread-hops otherwise.
                    -> The only thing left on main is the stuff that needs to be - mostly AppKit - MenuBarItem, TrialNotification, ScreenDrawer, maybe CVDisplayLinkStart/Stop
                        maybe other small parts of input-processing-chain calling mainThread-only Apple APIs like TISInput stuff, also maybe NSScreen. Can't think of anything else. [Sep 2026]
        Ideas/usage policy:
            mainThread-never-waits might be good and doable: [Sep 2026]
                If we avoid mainThread ever waiting on anything, then input-processing could theoretically wait on main to do parts of its processing, with easy-to-audit no deadlock risk - I think we can do this.
                (As for input processing waiting for mainThread - can only think of NSScreen, to get screen under mouse pointer, but feel like that's safe to access off of main, anyways, not sure we even need it.)
        Note about moving things off of GlobalEventTapThread, if necessary:
            - Should only do this if it's pretty clearly causing some performance issue.
            - Should maybe make core modules accessed by multiple threads threadsafe with locks instead of isolating to a thread. (Would prevent all the threadhops / deadlocks potentially)
                -> Preliminary analysis looked like locking is pretty doable with Config.m and SecureStorage.swift (leave the Config-did-change update callouts out of the critical zone and stuff)
 */

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
