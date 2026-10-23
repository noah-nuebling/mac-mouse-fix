//
// --------------------------------------------------------------------------
// Threads.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------

/**
    MMF Concurrency Model [Sep 2026]
        MainApp:    Everything on `mainThread`
        HelperApp:  Everything on `IOThread`, except for things that have to be on `mainThread` (AppKit, TISInputSource, possibly CVDisplayLinkStart/Stop, maybe more)
        -> max 2 threads per process (This possibly leaves out some background download stuff or whatever that doesn't interact much with the core, we don't see that as part of the 'architecture' or 'model' we're describing or caring about here.)

    About the 2-thread-model in HelperApp:
        Why?
            Before [Sep 2026] 'No more dispatch queues' refactor, we used many `dispatch_queues` in HelperApp.
                Why do that?
                    We thought that by isolating roughly every file in the core event processing with its own dispatch queue,
                    you'd get maximum parallelism while easily guaranteeing no races.
                        (This is roughly the Swift Actor model, but before Swift Actors, done with `dispatch_queues`)
                    The basic premise (max parallelism, no races) was true, however, in practise, this was a really bad idea, still: (To be exact, there were races in Buttons.swift, because we gave up on queue-isolation at some point because it was difficult, and races didn't actually cause problems there and stuff)
            Why *many* threads/queues was a bad idea:
                Problem: deadlocks
                    Overview: Even if per module `dispatch_queues` pretty well protect state from becoming invalid, when you have a bunch of them
                        interacting with `dispatch_sync` (necessary for reading anything from another queue) thing start deadlocking.
                        As far as I was aware, there was no good way provided by GCD to recover from this. (`dispatch_sync` doesn't even support timeouts, though correctly recovering from timeouts might also be hard)
                    Practical memories:
                        I remember spending months to get twoFingerSwipe to work without constant deadlock after coding it up when making MMF 3.0.0.
                        IIRC any later refactor attempt in the Helper's core event processing was scary because it would probably change timing in way that made things deadlock again.
                            Even remember shipping some update between 3.0.0 and 3.1.0 that caused lots more deadlocks. (The `MFDisplayLinkWorkType` stuff I think)
                        General hum of people reporting 'scrolling stopped working' which might have something to do with this (but maybe all of it was also DisplayLink.m' CVDisplayLink failing to start and stuff, I think reports stopped after adding the retry-loop, but not sure.)
                Problem: Parallelization doesn't help
                    The mouse-event processing in the helper is inherently pretty serial, I think, putting everything on different queue, won't deliver result much quicker, I'm pretty sure. (Update: [Oct 2026] We'd now have a way to test that a little better with `vblphase.m`)
                    The CPU usage of the helper is low anyways - the goal is keeping things responsive - our part in that is just processing the events faster than the display frame-period. Which we're super super easily doing on a single thread (I'm pretty sure)
                Some old comments: [Oct 2026]:
                    /// We've created `IOThread` so that we don't have to use the main runLoop for all eventTaps
                    ///     Edit2: [Dec 2024] I think since the `twoFingerModifiedDrag` draws a fake mouse pointer (necessarily, on the mainthread), with relatively high CPU usag,  it's probably good to put inputProcessing on a separate thread to ensure responsiveness.
                    ///         Also, all processing of input events should be on the same thread (so on this thread, not the mainthread or some dispatchqueue) to prevent race conditions and problems where events are processed in the wrong order. (I think see order-of-events problems during click-and-drag sometimes under MMF 3.0.3. – seems like clicks and drags are processed on different threads. (?) Also, doubleclicks are – stupidly – processed on the mainthread iirc, (Mightt be wrong, don't remember how this stuff works anymore – but the threading architecture is terrible and overcomplicated.))
                    ///         Update [Apr 2025] another practical reason to change this is the crazy crashes that happened after we tried to change scroll-event scheduling in 3.0.2. IIRC it took us months to get the multithreading bugs under control when building MMF 3, and it seems that changing the timings can make the whole house-of-cards fall apart. We don't want that! Coordinating everything on 1 thread, should allow for more 'fearless refactors'.
                    ///     Edit3: [Apr 2025] If we put everything on IOThread, this should greatly reduce potential for raceconditions and deadlocks and could simply some existing code a lot, since we won't need as much locking and dispatching to dispatchqueues and stuff, I think.
                    ///         However, they are still going to be *interaction-points between the IOThread and mainThread* which have high potential for race-conditions.
                    ///         Thread-interaction points:
                    ///             - Remaps loading
                    ///             - <TODO: Think about/document other interaction points>
            Why *dispatch queues* instead of threads are bad idea?
                Problem: No thread priority
                        (Also see `Ideas and notes about elevating thread priority` and `set_thread_priority` in the `.m` file [Oct 2026])
                    My theory for how MMF Helper can cause framedrops / unresponsiveness at all (even though it uses little CPU), is when system is under load and deprioritizes helper to keep the foreground app responsive (but then actually makes forground app less responsive, because the mouse driver is being throttled, which everything depends on).
                        (Update: [Oct 2026] We saw PointerFreeze > CGEventTapEnable() cause long stalls under heavy load (See `[debugWarpDelta]`)- so I guess waiting on WindowServer could also cause delays, but  then there are heavy framedrops anways, probably - feel like priority `normalApps < MMF < WindowServer` makes sense (Untested))
                    -> If you use normal threads instead of GCD, you can tell kernel to prioritize thread with `thread_set_policy` - pretty sure this will help much more for responsiveness.
                        (Update: [Oct 2026] Not sure I noticed a difference  due to `thread_policy_set`. It's all pretty good [macOS 27, M4 MBA] - haven't gone above `MAXPRI_USER`, round-robin, yet (Option above that would be realtime threads) (See our `set_thread_priority`))
                Dispatch queues have less powerful primitives:
                    You can't even check which `dispatch_queue` you're on. `dispatch_sync` can't time out. Thread primitives are more powerful (Maybe I didn't understand GCD properly, but to be fair it's also more obscure)
                    -> Weak philosophical point: It's like this kinda weird experimental, platform-specific reeinvention of the wheel, with limitations that I think designers didn't really design against real world - better to use robust, rock solid, well known threading primitives. Because it's already hard.
                They solve no problem:
                    As far as I'm aware, the only thing that `dispatch_queues` do better than normal threads with runLoops, is they are faster and cheaper to create/destroy (they are green threads) ... however,
                        - NSThread is already really fast and fine for any reasonable amount of threads for a GUI app or a mouse driver.
                        - `dispatch_queue` still has weird edge case, when you wait on too many queues, you can get thread explosion.
                        - If your work is CPU bound (not just waiting for IO) then having more queues/threads than CPU cores won't help anyways. (That many threads is basically free with NSThread)
                        -> Why the heck is this being promoted for GUI app developers
            Why 2 threads? (IOThread and MainThread)
                The only thing that I think could contend CPU with the main event processing is the ScreenDrawer.swift's AppKit drawing driven through twoFingerSwipe -> PointerFreeze > ScreenDrawer.
                    -> This is pretty expensive since it's AppKit (I'm pretty sure [Sep 2026]), and it HAS to be on the mainThread.
                So we want the eventProcessing to be on a separate thread from mainThread to not contend with expensive AppKit drawing -> That's IOThread.
                    Everything peripheral like Licensing and Config and Remaps then got pulled onto IOThread as well since it all heavily interacts with eventProcessing
                    and with each other and would need complicated locking or thread-hops otherwise.
                    -> The only thing left on main is the stuff that needs to be - mostly AppKit - MenuBarItem, TrialNotification, ScreenDrawer, maybe CVDisplayLinkStart/Stop
                        maybe other small parts of input-processing-chain calling mainThread-only Apple APIs like TISInput stuff, also maybe NSScreen. Can't think of anything else. [Sep 2026]
        Ideas/usage policy:
            `main-thread-never-waits` might be good and doable: [Sep 2026]
                If we avoid mainThread ever waiting on anything, then input-processing could theoretically wait on main to do parts of its processing, with easy-to-audit no deadlock risk - I think we can do this.
                (As for input processing waiting for mainThread - can only think of NSScreen, to get screen under mouse pointer, but feel like that's safe to access off of main, anyways, not sure we even need it.)
                Update: [Oct 2026] ModifiedDrag.m > PointerFreeze.m > ScreenDrawer.swift has `IOThread` waiting on mainThread I think. Not aware of any other places.
        Note about moving things off of IOThread, if necessary:
            - Should only do this if it's pretty clearly causing some performance issue.
            - Should maybe make core modules accessed by multiple threads threadsafe with locks instead of isolating to a thread. (Would prevent all the threadhops / deadlocks potentially)
                -> Preliminary analysis looked like locking is pretty doable inside Config.m and SecureStorage.swift (leave the Config-did-change update callouts out of the critical zone and stuff)
            - Evidence/observations in favor of additional thread. [Oct 2026]
                In `vblphase.m` I think I saw delayed/uneven phases during click and drag which look like they are caused by processing the input events on the same thread as the animator.
                    But I haven't noticed any actual UX degradation. (that would be twoFingerSwipe gesture phase being less smooth/responsive than momentum phase.)
*/

#import "Logging.h"
#import "pthread.h"

extern int _enableRunLoopAsserts;
void set_thread_priority(int priority, bool round_robin);
void threads_configureMainThread(void);

/// General threading helpers
void mfdetachThread(NSQualityOfService qos, void (^workload)(void));
void mfrun(CFRunLoopRef rl, void (^workload)(void));
void mfrunAndWait(CFRunLoopRef rl, void (^workload)(void));

/// Race condition protection
static inline void assertRunLoop(CFRunLoopRef runLoop) { /// Note: Making this static inline instead of macro so Swift can use it. Downside: the mfrequire macro will have wrong source code location [Oct 2026]
    if (_enableRunLoopAsserts)
    mfrequire(CFRunLoopGetCurrent() == (runLoop), @"assertRunLoop failure. Expected vs actual:\n%@\nvs\n%@", (runLoop), CFRunLoopGetCurrent());
}

/** Nested read/write protection.

    Overview/Explanation: [Sep 2026]
        When a function updates state, it temporarily leaves state invalid. When anything else reads/writes the state during invalid window, you get corruption. (or lost updates if parent update 'caches' state in stack variables or whatever before calling nested update.)
        This problem is also what thread race is. Serializing access (See `assertRunLoop`) mostly fixes this but not completely. Same issue can happen when function accidentally, in middle of its update, recurses into another function that tries to read/write the state.
        That's what the `readsState()` etc macros below are there to check against: They make sure state isn't read or written from a nested call while it may be invalid (and isn't made invalid while someone is still reading it.)
    When to use this / why we added this: [Sep 2026]
        In the core of the Helper like Scroll.m and TouchAnimator.swift, it's not easy to see that this corrupting kind of recursion doesn't happen.
        Historical reason [Sep 2026] After 'No more dispatch queues' refactor, we made a bunch of things that were previously deferred via `dispatch_async` into directly blocking calls.
        This has chance of introducing such recursion corruptions. Since we change so much stuff in the refactor, I thought it's good idea to add checks like this to be confident in correctness.
            However, after the refactor is done and everything works, maybe remove the checks, or feel ok to neglect to update these checks, because of deterministic nature making bugs not so bad anyways and maybe not worth complexity of these annotations:
                (When these corrupting recursions occur, they are deterministic, because everything is already serialized on one thread, and you can probably debug the corruption ok, even without having the readsState() / readsAndWritesState() checks.)
    Practical rules discovered (about when (not) to use this): [Sep 2026]
        - You can omit checks for a module, when you can see that nothing calls out in a way that could recurse during invalid-state window of an update. I think that's most code in MMF.
        - You can annotate any callout with `allowNestedReadOrWrite()` when it appears at the very start / end of an update function (before the update reads anything it relies on, or after its last write).
        - You can annotate any callout to another update function with `allowNestedReadOrWrite()` when the calling update function calls the nested one *directly* - then it's clearly intentional (We're trying to catch the accidental ones, that happen indirectly through recursion)
        - For non trivial cases of `allowNestedReadOrWrite()` explain where the call-tree re-enters the module, and maybe why that's ok here. (Non trivial cases: re-enter module indirectly through non-obvious recursion, and in the middle of another update of the same module.)
        - Every entry point to module that touches the state needs `readsState()` / `readsAndWritesState()` annotation. (Otherwise callouts can come back in without the tracker seeing it.)
            - Private helpers don't need `readsState()` / `readsAndWritesState()` annotation (they can only be called by entry points - where readsState() or readsAndWritesState() guarantees are already held)
        - Almost always use `readsAndWritesState()` (not `readsState()`):
            - Any mutated non-local variable is a 'write' (even caches)
            - All callouts could 'write' somewhere deep in their call-tree - so default to readsAndWritesState(), when there's any callouts unless all callouts are pure/read-only (when it's not obvious why they are pure, explain in comment) (obvious would be: callout to another function that only `readsState()`, logging function, maths routine with no side-effects, ...)
            - (Erring on side of readsAndWritesState() will only produce additional false positives, which you can opt out of with `allowNestedReadOrWrite()`, so should be harmless.)
        - You don't need to add readsState() / readsAndWritesState() to a function that just forwards to another function that is readsAndWritesState() (Leave a comment if non-obvious, we think comment is less cumbersom than `allowNestedReadOrWrite()` ritual as of [Sep 2026])
        What the checks cannot cover:
            If parent update changes state of submodule A, and then calls [submoduleB update] which itself updates submodule A's state again
            (indirectly from parent's perspective) that's basically the same issue, but our checks can't catch it, since the update
            to submodule A through [submoduleB update] doesn't go through parent module's tracker, (doesn't actually recurse back into the parent) even though submodule A's state is logically 'owned' by parent.
            (If you really wanted to prove correctness, it gets really complicated with the submodules - definitely not worth it)
        Alternative:
            - Restructure code such that in all update functions on some state S, you do all callouts before the first read or after the last write (before or after your update) - then it's easy to see that the corrupting recursion can't happen and you don't need the checks.
 */

NS_SWIFT_UNAVAILABLE("")
typedef struct { int readerCount; int writerCount; } MFReadWriteTracker;

#define readsState(tracker) \
    mfassert(!(tracker)->writerCount, @"Nested read while state is being written."); \
    (tracker)->readerCount += 1; \
    __attribute__((cleanup(__decrementInt))) int *__readerWriterCount = &(tracker)->readerCount

#define readsAndWritesState(tracker) \
    mfassert(!(tracker)->readerCount && !(tracker)->writerCount, @"Nested write while state is being read or written."); \
    (tracker)->writerCount += 1; \
    __attribute__((cleanup(__decrementInt))) int *__readerWriterCount = &(tracker)->writerCount


#define allowNestedReadOrWrite() /** Caution: break / return breaks this [Oct 2026] */\
    for (int _once = ({ (*__readerWriterCount)--; 1; }); _once; _once = ({ (*__readerWriterCount)++; 0; }))

    NS_SWIFT_UNAVAILABLE("")
    static inline void __decrementInt(int **someInt) { **someInt -= 1; }

#if IS_HELPER
@interface IOThread : NSObject

    + (void) load_Manual;
    + (void) start;
    + (CFRunLoopRef)runLoop CF_RETURNS_NOT_RETAINED;

@end
#endif
