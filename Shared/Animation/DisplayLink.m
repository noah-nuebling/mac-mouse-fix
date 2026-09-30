//
// --------------------------------------------------------------------------
// DisplayLink.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

///
/// Also see:
/// - CoreVideo programming concepts:  https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/CoreVideo/CVProg_Concepts/CVProg_Concepts.html
/// - litherium post on understanding CVDisplayLink: http://litherum.blogspot.com/2021/05/understanding-cvdisplaylink.html
///
/// Overview [Sep 2026]
///     This wraps CVDisplayLink with simpler interface.
///     The interface is designed so we could swap in CADisplayLink at some point for newer macOS versions. (Only supports macOS 14.0+)

#import "DisplayLink.h"
#import <Cocoa/Cocoa.h>
#import "NSScreen+Additions.h"
#import "SharedUtility.h"
#import "IOUtility.h"

#import "Threads.h"

#import "Logging.h"

#if IS_HELPER
#import "HelperUtility.h"
#endif

@interface DisplayLink ()

@end

/// Wrapper object for CVDisplayLink that uses blocks
/// Didn't write this in Swift, because CVDisplayLink is clearly a C API that's been machine-translated to Swift. So it should be easier to deal with from ObjC
@implementation DisplayLink
{

    CVDisplayLinkRef _displayLink;
    //CGDirectDisplayID *_previousDisplaysUnderMousePointer; /// Old and unused, use `_previousDisplayUnderMousePointer` instead
    //CGDirectDisplayID _previousDisplayUnderMousePointer;
    BOOL _displayLinkIsOutdated;
    CFRunLoopRef _runLoop;
    bool _userRequestsToRun;            /// What the client wants (start/stop) Formerly `_requestedState`. [Sep 2026]
    bool _cvDisplayLinkRequestedToRun;  /// What we last told the CVDisplayLink to do (start/stop). Use for `kTicksUntilStoppingDisplayLink` stuff
    int _ticksSinceUserRequestedStop;
    MFDisplayLinkWorkType _optimizedWorkType;
    CFRunLoopSourceRef _runLoopSource;

    NSString *_name;

    MFReadWriteTracker _readWriteTracker;

    DisplayLinkCallbackTimeInfo __timeInfo; /// Used to pass info between the two `displayLinkCallback` functions. Probably invalid before first callback and when displayLink is stopped. Think before using in any other context [Sep 2026]
    int __hasPendingCVDisplayLinkCallback;  /// Used to pass info between the two `displayLinkCallback` functions
}

/**
    Discussion
        Deadlocks:
            As far as I understand, there can be no more deadlocks after 'No more dispatch queues' refactor,
                since there are only 2 threads (GlobalEventTapThread and mainThread) and the mainThread never waits on the GlobalEventTapThread anywhere in the program [Sep 2026]
            Before the refactor, this file was a core big source of deadlocks.
            The core problematic part was displayLinkCallback, which runs on private displayLinkThread holding private displayLinkLock which also locks all other interactions with the displayLink. Now you have dilemma:
                - If you sync dispatch from displayLinkCallback to displayLinkQueue, you run on the 'high priority thread',
                - but now there's a window, where you hold private lock but don't hold queue, yet, about to wait on the queue. In this window, someone can snatch the displayLink queue, then try to interact with the displayLink which you already have lock for > deadlock.
                - To fix, we async dispatched to main before interacting with displayLink. (Also did that for other sporadic error, reason, see `_interactWithCVDisplayLinkFromMainThread`) this mostly fixes it but you can still deadlock if the displayLinkQueue ever waits on main (because displayLinkQueue holds the private displayLink lock, which main will wait for before interacting with displayLink)
            After 'No more dispatch queues' refactor:
                - We make the displayLinkThread defer to the GlobalEventTapThread - we don't wait on it. This is fine we think because
                    we make the GlobalEventTap 'high priority' via `thread_policy_set` just like the displayLinkThread, and we also
                    can drop frames via CFRunLoopSourceRef, just like the displayLinkThread probably would if your work takes too long
                    -> So we think that all the benefits of running directly on displayLinkThread are gone and we can now enjoy no more deadlocks. Nice!
            Also see:
                - `Old MFDisplayLinkWorkType stuff.md > Deadlock: [Aug 2025]` ([Sep 2026] this hasn't been updated in a long time)
                - Commit before 'No more dispatch queues' refactor where DisplayLink.m still had a lot of detailed scattered notes on the specific deadlocks and stuff.
            Old notes: (to be deleted, summary above should be fine)
                From `displayLinkCallback`
                    ///     - [Aug 2025] There is a deadlock here due to lock-inversion.
                    ///         See `Old MFDisplayLinkWorkType stuff.md > Deadlock: [Aug 2025]`
                    ///         Not addressing that now for fear of causing other bugs, but restoring to 3.0.0 code may reduce chances of hitting the bug.
                    ///         I think the deadlock has been here since commit `2bd62d5` when we started using `dispatch_sync()` here
                    ///     - [Aug 2025] Eventually, we may want to move to CADisplayLink and async-dispatch to the "IOThread" we're planning. This would resolve the deadlock, too (See `Old MFDisplayLinkWorkType stuff.md`)
                From `stop_Unsafe`: (How we introduced `_requestedState`)
                    /// This has been causing deadlocks. Deadlocks explanation:
                    ///
                    /// - This function runs on `_displayLinkQueue` and waits for displayLinkCallback when it calls CVDisplayLinkStop()
                    /// - displayLinkCallback waits for `_displayLinkQueue` when it tries to sync dispatch to it
                    /// -> Classic deadlock scenaro
                    ///
                    /// The pretty solution I can come up with is to make either the displayLinkCallback or the _displayLinkQueue not acquire its resource (thread lock) before it it can acquire all the other resources that it will need. But we don't have access to the locking stuff that the CVDisplayLink uses at all afaik, so I don't know how this would be possible.
                    /// As an alternative, we could simply either
                    /// 1. not make the callback _not_ try to acquire the queue lock
                    ///     - by making the callback dispatch to queue async instead of sync
                    ///     - this will make the callback not execute on the high priotity display link thread though, potentially making scrolling performance worse
                    /// 2. make the queue _not_ try to acquire the callback lock
                    ///     - by dispatching to main async instead of sync in the `- stop` and `- start` functions (Those are the functions where the deadlocks have occured so far.)
                    ///     - This will potentially change the order of operations and introduce new bugs.
                    ///
                    /// -> For now I'll try 2.
                    ///
                    /// Edit: Seems to not make a difference so far and fixes the constant deadlocks!
                    ///
                    /// Edit2: Solution 2. breaks isRunning(). Explanation: If, in start() and stop(), the displayLinkQueue async dispatches to mainQueue to do the actual starting and stopping, then the actual starting and stopping won't have happened yet when isRunnging() runs. Possible solutions:
                    ///     - 1. Go back to sync dispatching to mainQueue in start() and stop() and hope the other changes we made coincidentally prevent the deadlocks that were happening
                    ///         -> Worth a try
                    ///     - 2. Dispatch to mainQueue also in isRunning() -> We're introducing a new sync dispatch, so this might very well lead to new deadlocks
                    ///         -> Doesn't really make sense, try if desperate
                    ///     - 3. Introduce new state variable 'requestedState' with states `requestedRunning` and `requestedStop`. Use this state to make isRunning() return the right value right after start() or stop() are called, even if the underlying CVDisplayLink hasn't started / stopped yet.
                    ///         -> Think this makes sense. Try this if 1. doesn't work.
                    ///
                    ///     Edit: 1. Still doesn't work. -> Introducing `_requestedState` variable

*/

/// Keep the displayLink alive for a few frames after the user stops it, this prevents CVDisplayLink from creating new pthreads all the time when stopping and restarting in quick succession.
///     Used to optimize the `ModifiedDrag.m > coalescingDisplayLink()` which is started and stopped every frame and normally makes CVDisplayLink create a new pthread for every frame
///     (which we have to call `set_thread_priority`on again). This isn't actually very expensive at all (I measured it only lower CPU usage `<~0.2%` (in absolute terms) during threeFingerDrag)
///     and the thread priority is pretty high anyways, so not sure this actually makes a UX difference. [Sep 2026]
///     Optimization Update: (@noGCDCleanup):
///         [Sep 2026] I saw `coalescingDisplayLink()` actually increases CPU usage compared to pre-refactor when you run low-polling rate mouse on 120 Hz display. I guess because the events come in slower than the frames, so coalescing buys nothing and just costs some CVDisplayLink stuff overhead.
#define kTicksUntilStoppingCVDisplayLink 3

/// Recreate the underlying CVDisplayLink when a new display is attached (`displayReconfigurationCallback`).
///     Discussion: [Sep 2026]
///         Contra:
///             - MOS doesn't do this (been a while since I checked [Sep 2026]) (Update: Does recreate now but doesn't retarget the displayLink - wrong)
///             - In [Sep 2026] macOS 27 tests, it's not necessary (displayLink can be created with only 60 Hz displays attached, then 120 Hz display attaches, and it retargets fine to 120 Hz.) (Tested after restart/sleep. Always works)
///             - Might cause/exacerbate reliability issues (See `kMaxTries_CVDisplayLinkCreate` and the notes by the retry loop [Sep 2026])
///         Pro:
///             - The docs sort of suggest this, but it's ambiguous:
///                 CVDisplayLinkCreateWithActiveCGDisplays() docs say that it "determines the displays actively used by the host computer and creates a display link compatible with all of them.".
///                 -> I read 'actively used' as it's not compatible with displays that aren't attached, yet - that's why I did all this.
///             - Claude told me recreating is done in Chromium and other projects and it's the 'robust' thing to do.
///                 - Update: Other Claude says this isn't true. It says, Chromium and WebKit keep per-display CVDisplayLink and don't recreate. Firefox uses retargetable API and recreates it
///                     sometimes to fix some edge case sleep/wake bug, which Claude say is plausibly because it never targets the displayLink to a display. MOS is funky and probably wrong. (Also never targets the displayLink apparently)
///                     -> Only compelling reason to recreate is maybe if the Firefox bug is *not* because it never retargets.

#define kRecreateCVDisplayLink 0 /// [Sep 2026] If we re-enable this: the deferred `_userRequestsToRun` stuff is racy and could lead to getting stuck forever! (Courtesy Opus 5.5) (Update: Changed architecture a little, might not be true anymore)

#define kMaxTries_CVDisplayLinkCreate 20 /** [Aug 2025] 20 is kinda arbitrary, but since this only seems to fail very rarely, and only runs in special situations like launching the helper, so there should be no performance impact to trying many times. */
#define kMaxTries_CVDisplayLinkStart 100

/// Defer all interactions with the CVDisplayLink to the mainThread. Might prevent reliability issues.
/// Old comments: [Sep 2026]
///     From `setUpNewDisplayLinkWithActiveDisplays`:
///         [Aug 2025] We're calling CVDisplayLinkStart() and CVDisplayLinkStop() from the mainThread, and apparently that fixed some issues, we also had some external doc that suggested mainThread should be used for some things. (See notes where we call CVDisplayLinkStart()/CVDisplayLinkStop()). I also just saw that CVDisplayLink is non-sendable.
///             - My guess rn would be that each CVDisplayLink instance should only be interacted with from one thread.
///             - On which threads is this called? [Aug 2025]
///                 - `[GestureScrollSimulator initialize]` calls this on `com.nuebling.mac-mouse-fix.helper.display-link` queue,
///                 - `[Scroll load_Manual]` calls this on mainThread.
///                 - `[ModifiedDragOutputTwoFingerSwipe load_Manual]` calls this on the mainThread.
///                 - If the displayLink is recreated after detaching/reattaching a display, it seems to always run on `com.nuebling.mac-mouse-fix.helper.display-link` (Haven't done too much testing or thinking here.)
///                 - (Haven't tested anything else)
///             - Other thought: Since this is only called rarely, (and I think always *before* that displayLink is actually used) race-conditions might be rare. But rare issues match the sporadic nature of the `scrolling-stops-intermittently_apr-2025.md` issues, and CVDisplayLinkStart()/CVDisplayLinkStop() did randomly fail when we called them from a non-main-thread according to the notes
///                 ... but my gut feeling is that it's not about race-conditions.
///     From above CVDisplayLinkStart restart loop:
///         Start the displayLink
///             If something goes wrong see notes in old SmoothScroll.m > handleInput: method
///         Starting the displayLink often fails with error code `-6660` for some reason.
///             Running on the main queue seems to fix that. (See SmoothScroll_old_).
///     From `stop_Unsafe`:
///         CVDisplayLink should be stopped from the main thread
///             According to https://cpp.hotexamples.com/examples/-/-/CVDisplayLinkStop/cpp-cvdisplaylinkstop-function-examples.html
#define _interactWithCVDisplayLinkFromMainThread 1
- (CFRunLoopRef) cvDisplayLinkInteractionRunLoop {
    return _interactWithCVDisplayLinkFromMainThread ? CFRunLoopGetMain() : self->_runLoop;
}
- (void) interactWithCVDisplayLink: (void (^)(void))workload {
    if (CFRunLoopGetCurrent() == [self cvDisplayLinkInteractionRunLoop]) workload();
    else                                                                 MFCFRunLoopPerform([self cvDisplayLinkInteractionRunLoop], nil, workload); /// [Sep 2026] `_userRequestsToRun` allows us to make all interaction with CVDisplayLink non-blocking
}

/// [Sep 2026] Disable `readsState()` / `readsAndWritesState()` in DisplayLink.m
///     since the only callout is `self.callback` at the very end of `displayLinkCallback()`. (Don't think this will ever change since DisplayLink.m is simple and sort of a 'leaf node' in the layers of the program)
//#define _readsState(tracker)          readsState(tracker)
//#define _readsAndWritesState(tracker) readsAndWritesState(tracker)
//#define _allowNestedReadOrWrite()     allowNestedReadOrWrite()
#define _readsState(tracker)
#define _readsAndWritesState(tracker)
#define _allowNestedReadOrWrite()


#pragma mark - Debug

NSString *MFCVReturn_ToString(CVReturn ret) { /// [Aug 2025] Added for debugging. Not sure this is a great place for it.
    static NSDictionary<NSNumber *, NSString *> *map;
    static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{
        map = @{

            @(kCVReturnSuccess)                         : /*0*/                 @"Success",
            @(kCVReturnError)                           : /*-6660*/             @"Error/First",
            @(kCVReturnInvalidArgument)                 : /*-6661*/             @"InvalidArgument",
            @(kCVReturnAllocationFailed)                : /*-6662*/             @"AllocationFailed",
            @(kCVReturnUnsupported)                     : /*-6663*/             @"Unsupported",

            @(kCVReturnInvalidDisplay)                  : /*-6670*/             @"InvalidDisplay",
            @(kCVReturnDisplayLinkAlreadyRunning)       : /*-6671*/             @"DisplayLinkAlreadyRunning",
            @(kCVReturnDisplayLinkNotRunning)           : /*-6672*/             @"DisplayLinkNotRunning",
            @(kCVReturnDisplayLinkCallbacksNotSet)      : /*-6673*/             @"DisplayLinkCallbacksNotSet",
            
            @(kCVReturnInvalidPixelFormat)              : /*-6680*/             @"InvalidPixelFormat",
            @(kCVReturnInvalidSize)                     : /*-6681*/             @"InvalidSize",
            @(kCVReturnInvalidPixelBufferAttributes)    : /*-6682*/             @"InvalidPixelBufferAttributes",
            @(kCVReturnPixelBufferNotOpenGLCompatible)  : /*-6683*/             @"PixelBufferNotOpenGLCompatible",
            @(kCVReturnPixelBufferNotMetalCompatible)   : /*-6684*/             @"PixelBufferNotMetalCompatible",
            
            @(kCVReturnWouldExceedAllocationThreshold)  : /*-6689*/             @"WouldExceedAllocationThreshold",
            @(kCVReturnPoolAllocationFailed)            : /*-6690*/             @"PoolAllocationFailed",
            @(kCVReturnInvalidPoolAttributes)           : /*-6691*/             @"InvalidPoolAttributes",
            @(kCVReturnRetry)                           : /*-6692*/             @"Retry",
            @(kCVReturnLast)                            : /*-6699*/             @"Last",
        };
    });
    
    NSString *result = map[@(ret)];
    return result ?: stringf(@"%d", ret);
};

NSString *MFCGDisplayChangeSummaryFlags_ToString(CGDisplayChangeSummaryFlags flags) {
    /// [Apr 2025] Added for debugging.
    static NSString *map[] = {
        [bitpos(kCGDisplayBeginConfigurationFlag)]      = @"BeginConfiguration",
        [bitpos(kCGDisplayMovedFlag)]                   = @"Moved",
        [bitpos(kCGDisplaySetMainFlag)]                 = @"SetMain",
        [bitpos(kCGDisplaySetModeFlag)]                 = @"SetMode",
        [bitpos(kCGDisplayAddFlag)]                     = @"Add",
        [bitpos(kCGDisplayRemoveFlag)]                  = @"Remove",
        [bitpos(kCGDisplayEnabledFlag)]                 = @"Enabled",
        [bitpos(kCGDisplayDisabledFlag)]                = @"Disabled",
        [bitpos(kCGDisplayMirrorFlag)]                  = @"Mirror",
        [bitpos(kCGDisplayUnMirrorFlag)]                = @"UnMirror",
        [bitpos(kCGDisplayDesktopShapeChangedFlag)]     = @"DesktopShapeChanged",
    };
    
    NSString *result = bitflagstring(flags, map, arrcount(map));
    return result;
};

#pragma mark - Lifecycle

/// Convenience init

+ (instancetype) displayLinkOptimizedForWorkType: (MFDisplayLinkWorkType)workType runLoop: (CFRunLoopRef)runLoop name: (NSString *)name {
    return [[self alloc] initOptimizedForWorkType: workType runLoop: runLoop name: name];
}

/// Init
- (instancetype)initOptimizedForWorkType:(MFDisplayLinkWorkType)workType runLoop: (CFRunLoopRef)runLoop name: (NSString *)name {

    self = [super init];
    if (self) {

        _optimizedWorkType = workType;
        _runLoop = runLoop;
        //_previousDisplaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 2); /// Init displaysUnderMousePointer cache. Why 2? - see `setDisplayToDisplayUnderMousePointerWithEvent:`
        _displayLinkIsOutdated = NO;
        _userRequestsToRun = NO; _ticksSinceUserRequestedStop = 0;
        _cvDisplayLinkRequestedToRun = NO;
        _name = stringf(@"%@.%@", name, @((uintptr_t)self));

        _runLoopSource = CFRunLoopSourceCreate(kCFAllocatorDefault, /*order*/0, &(CFRunLoopSourceContext){
            .version = 0,
            .info = (__bridge void *)self,
            .retain = NULL, .release = NULL, /// NULL to avoid retainCycle, since self owns the `_runLoopSource`
            .copyDescription = CFCopyDescription, .equal = CFEqual, .hash = CFHash, /// Not sure these are necessary/do anything
            .schedule = NULL, .cancel = NULL,
            .perform = displayLinkCallback_OnRunLoop,
        });
        CFRunLoopAddSource(_runLoop, _runLoopSource, kCFRunLoopCommonModes);

        [self interactWithCVDisplayLink:^{
            [self setUpNewCVDisplayLinkWithActiveDisplays]; /// Setup internal CVDisplayLink
            if (kRecreateCVDisplayLink) CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, (__bridge void * _Nullable)(self));
        }];

    }
    return self;
}

- (void) setUpNewCVDisplayLinkWithActiveDisplays {
    assertRunLoop([self cvDisplayLinkInteractionRunLoop]);

    /// Delete existing displayLink
    if (_displayLink != NULL) {
        CVReturn ret = CVDisplayLinkStop(_displayLink);
        MFCFRunLoopPerform(_runLoop, nil, ^{
            self->_userRequestsToRun = NO; self->_ticksSinceUserRequestedStop = 0;
            self->_cvDisplayLinkRequestedToRun = NO;
        });
        DDLogDebug("DisplayLink.m: (%@) Deleting existing CVDisplayLink for displayLink. StopCode: %@", _name, MFCVReturn_ToString(ret));
        CVDisplayLinkRelease(_displayLink);
        _displayLink = NULL;
    }
    
    /// Create new displayLink in retry loop
    ///     [Aug 2025] I think silent failure of this probably causes the `scrolling-stops-intermittently_apr-2025.md` (Aka `Scroll Stops Working Intermittently`) bug.
    ///         To address this, in case of failure, we retry in a loop and eventually crash the program. That way we should have better robustness and better debug data (crashlogs)
    ///         Update: (During 'No more dispatch queues' refactor) [Sep 2026]
    ///             IIRC, this fixed the issue and GitHub issues about this stopped.
    ///             Idea: I think before 'No more dispatch queues' refactor in [Sep 2026], this was called from many different threads, which matches how CVDisplayLinkStart() was apparently failing intermittently, before we put it on the mainThread.
    ///     [Aug 2025] Will this enter a crash-cycle if no display is attached at all?
    ///         Test result: Nope, seems like there is a dummy display in the API when no displayCable is attached to my Mac Mini 2018, and this code runs just fine. (However other parts of the codebase still experience assert-failures when no display is attached – Haven't looked into that.) See commit 6fa42122c7d38c315ad8f8f428e2b9b0fa5c8711.
    {

        CVReturn ret = 0; int i = 0;
        for (; i < kMaxTries_CVDisplayLinkCreate; i++) {
            ret = CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
            if (!ret && _displayLink && !CVDisplayLinkGetCurrentCGDisplay(_displayLink)) ret = kCVReturnInvalidDisplay; /// Opus 5.5 suggestion. Detect broken link (framework bug) See Firefox bug 1201401 / crbug.com/1218720 – CoreVideo sometimes returns success with a broken link (nulled internal pointer) that crashes later. [Sep 2026]
            if (!ret && _displayLink) break;
            if (_displayLink) { CVDisplayLinkRelease(_displayLink); _displayLink = NULL; }
        }
        mfrequire(!ret && _displayLink, "(%@) Creating CVDisplayLink failed after %d tries with error %@", _name, i, MFCVReturn_ToString(ret));

        ret = CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, (__bridge void *)self); /// Old comment from [Aug 2025] Test result: 'Silently' fails with kCVReturnInvalidArgument if you pass NULL as the `_displayLink`, that fits with our theory about this potentially causing `scrolling-stops-intermittently_apr-2025.md`.
        mfrequire(!ret, "(%@) Setting output callback on CVDisplayLink failed with error: %@", _name, MFCVReturn_ToString(ret)); /// [Sep 2026] This used to be inside the retry-loop before 'No more dispatch queues' refactor - put it back inside if this causes issues.

        DDLogDebug("(%@) Successfully created CVDisplayLink (%@) (%d retries)", _name, _displayLink, i);
    }
}

/// Dealloc

- (void)dealloc
{
    CVDisplayLinkStop(_displayLink);
    CVDisplayLinkRelease(_displayLink);
    CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, (__bridge void * _Nullable)(self)); /// The arguments need to match the ones for CGDisplayRegisterReconfigurationCallback() exactly
    //free(_previousDisplaysUnderMousePointer);
    CFRunLoopSourceInvalidate(_runLoopSource);
    CFRelease(_runLoopSource);
}

#pragma mark - Start and stop

- (void)start_UnsafeWithCallback:(DisplayLinkCallback _Nullable)callback {

    assertRunLoop(_runLoop);
    _readsAndWritesState(&_readWriteTracker);

    DDLogDebug("DisplayLink.m: (%@) starting", _name);

    if (callback) self.callback = callback; /// Pass nil to preserve existing callback

    _userRequestsToRun = YES;

    /// Early return
    ///     [Sep 2026] Added this as optimization. Bit error prone. (Always set this with every CVDisplayLinkStop and stuff, otherwise we can get stuck here!) Don't remember when/why/if this mattered.
    if (_cvDisplayLinkRequestedToRun) return;
    _cvDisplayLinkRequestedToRun = YES;
    [self interactWithCVDisplayLink: ^{

        #define retok(ret) (!(ret) || (ret) == kCVReturnDisplayLinkAlreadyRunning)

        CVReturn ret;
        int i = 0;
        do ret = CVDisplayLinkStart(self->_displayLink); /// Interactions with CVDisplayLink block until the displayLinkCallback returns. Since `displayLinkCallback` doesn't wait on anything this can't cause deadlocks [Sep 2026]
            while (!retok(ret) && ++i < kMaxTries_CVDisplayLinkStart);

        if (!retok(ret)) {
            mfassert(false, @"DisplayLink.m: (%@) Failed to start CVDisplayLink after %d tries. Giving up. Last error: %@", self->_name, i, MFCVReturn_ToString(ret));
            MFCFRunLoopPerform(self->_runLoop, nil, ^{
                self->_userRequestsToRun = NO; self->_ticksSinceUserRequestedStop = 0;
                self->_cvDisplayLinkRequestedToRun = NO; /// Command failed, so the CVDisplayLink isn't running. Reset so the next start retries.
            });
        }
        #undef retok
    }];
}

- (void)stop_Unsafe {

    assertRunLoop(_runLoop);
    _readsAndWritesState(&_readWriteTracker);
    DDLogDebug("DisplayLink.m: (%@) stop request", _name);
    _userRequestsToRun = NO; _ticksSinceUserRequestedStop = 0;
}

- (BOOL)isRunning_Unsafe {

    assertRunLoop(_runLoop); /// [Sep 2026] `_userRequestsToRun` is owned by `_runLoop` (`self->_displayLink` in the dead code below is owned by [self cvDisplayLinkInteractionRunLoop])
    _readsState(&_readWriteTracker);
    return _userRequestsToRun;

    #if 0
        /// Only call this if you're already running on `_displayLinkQueue`
        Boolean result = CVDisplayLinkIsRunning(self->_displayLink);

        /// Debug
        DDLogDebug("DisplayLink.m %@ isRunning: %d", _name, result);

        /// Return
        return result;
    #endif
}

#pragma mark - Other interface

#if 0 /** [Sep 2026] Unused. (But seems useful - maybe we should use them?) */
    - (CFTimeInterval)bestTimeBetweenFramesEstimate {

        /// This normally returns the actual timeBetweenFrames.
        /// But if the displayLink is not running, yet, then the actual timeBetweenFrames is 0.0, so in that case it returns the nominal timeBetweenFrames.

        double t = CVDisplayLinkGetActualOutputVideoRefreshPeriod(_displayLink);
        if (t == 0) {
            CVTime tCV = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(_displayLink);
            t = (tCV.timeValue / (double)tCV.timeScale);
        }
        return t;
    }

    - (CFTimeInterval)timeBetweenFrames {
        double t = CVDisplayLinkGetActualOutputVideoRefreshPeriod(_displayLink);
        return t;
    }
#endif

- (CFTimeInterval)nominalTimeBetweenFrames {
    CVTime t = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(_displayLink);
    return (t.timeValue / (double)t.timeScale);
}

/// Set display to mouse location

- (void)linkToMainScreen {

    /// Simple alternative to .`linkToDisplayUnderMousePointerWithEvent:`.
    /// [Sep 2026] 'No more dispatch queues' refactor made this deferred/non-blocking - before,
    ///     I guess it was sync to make sure displayLink is on the right thread before starting animation,
    ///     but this doesn't make any sense, since the CVDisplayLinkStart is also deferred to main, so order of operations is correct in that case,
    ///         in case of running displayLink I guess worst case, a few frames are delivered with wrong refresh rate? Not sure this happens and probably not noticable.
    ///     (Maybe keep comment since I was confused, but seems obvious now.)

    assertRunLoop(_runLoop);
    _readsAndWritesState(&_readWriteTracker);

    [self interactWithCVDisplayLink: ^{
        [self setDisplay: NSScreen.mainScreen.displayID];
    }];
}

#if 0 /** [Sep 2026] Currently dead, but should use this over linkToMainScreen. See comments inside */
    - (void)linkToDisplayUnderMousePointerWithEvent:(CGEventRef _Nullable)event {

        /// Notes:
        /// - This is unused (as of 17.09.2024, MMF 3.0.3)
        ///     -> Which leads to the scroll-scheduling updating to a new screen, only once the key window is on that screen (since we use linkToMainScreen() instead of this.)
        ///     - TODO: actually use this instead of `linkToMainScreen` and test if this new version works.
        /// - I think this would be appropriate to use for event sending, not for animation, since it's based on a CGEvent) - For animation we need another approach.
        ///     - (But I think if we move over from the deprecated CVDisplayLink to the new CADisplayLink, we'll have to use a different approach anyways.)
        /// - Update: [Sep 2026] I think `-linkToMainScreen` is wrong everywhere we use it – should replace with `-linkToDisplayUnderMousePointerWithEvent:` or equivalent.
        ///     Don't forget to update other hardcoded mainScreen references (`NSScreen.mainScreen`). Maybe other stuff.
        #if !IS_HELPER
            assert(false);
            return;
        #endif

        assertRunLoop([self cvDisplayLinkInteractionRunLoop]); /// [Sep 2026] Haven't really looked at whether all the state we access here belongs to this thread, since this code is currently dead anyways.

        __block CVReturn result;
        {
            /// Init shared return
            CVReturn rt;

            /// Get display under mouse pointer
            CGDirectDisplayID dsp;
            rt = [HelperUtility displayUnderMousePointer:&dsp withEvent:event];

            /// Premature return
            if (rt == kCVReturnError) {
                result = kCVReturnError; return; /// Coudln't get display under pointer
            }
            if (dsp == self->_previousDisplayUnderMousePointer) {
                result = kCVReturnSuccess; return; /// Display under pointer already linked to
            }

            /// Store dsp in cache
            self->_previousDisplayUnderMousePointer = dsp;

            /// Set new display
            result = [self setDisplay:dsp]; return;
        }

    }
#endif


- (CVReturn)setDisplay:(CGDirectDisplayID)displayID {

    assertRunLoop([self cvDisplayLinkInteractionRunLoop]);

    /// Setup new displayLink if displays have been attached / removed
    if (kRecreateCVDisplayLink)
    if (_displayLinkIsOutdated) {
        [self setUpNewCVDisplayLinkWithActiveDisplays];
        _displayLinkIsOutdated = NO;
    }

    if (CVDisplayLinkGetCurrentCGDisplay(_displayLink) == displayID) return kCVReturnSuccess; /// Setting the display on a running link restarts its thread, even if it's the same display [Sep 2026]

    CVReturn ret = CVDisplayLinkSetCurrentCGDisplay(_displayLink, displayID);

    DDLogDebug("DisplayLink.m: (%@) set to display %d. Error: %d", _name, displayID, ret);
    mfassert(!ret);

    return ret;
}

#pragma mark - Reconfiguration Callback

void displayReconfigurationCallback(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo) {

    /// @noGCDCleanup consider Claude's concern:
    ///     A dead CVDisplayLink now never recovers (DisplayLink.m:350, 577-585). Only two things clear _cvDisplayLinkRequestedToRun: a callback arriving, or a start that fails. If CoreVideo ever stops firing on its own while the flag is YES, every later start returns early. That DisplayLink then stays dead until the helper restarts, which looks exactly like "scroll
    ///         stops working". Before this commit, every animation ended with CVDisplayLinkStop and the next one called CVDisplayLinkStart, which gave the link a fresh start.
    ///     - I don't know whether CoreVideo actually does this (display unplug, sleep/wake). With the link no longer recreated, you've only tested display hot-plug on macOS 27, and the deployment target is 10.15.
    ///     - Cheap insurance: record when the last callback arrived. In start, if the flag is YES but nothing has arrived for about 0.5 s, queue a Stop and then a Start.

    /// See `kRecreateCVDisplayLink`
    mfassert(kRecreateCVDisplayLink);

    DisplayLink *self = (__bridge DisplayLink *)userInfo;

    /// Hop threads
    ///     [Sep 2026] Because `_displayLinkIsOutdated` is owned by `[self cvDisplayLinkInteractionRunLoop]`, and CGDisplayChangeSummaryFlags comments suggest this is called on different threads.
    ///         Either way, this is rare and not performance critical, so hopping should always be fine.
    [self interactWithCVDisplayLink: ^{

        if ((flags & kCGDisplayAddFlag)     || /// Using enabledFlag and disabledFlag here is untested. I'm not sure when they are true.
            (flags & kCGDisplayRemoveFlag)  || /// Update: [Apr 2025] I don't see a reason to recreate the displayLink when displays are *removed*.
            (flags & kCGDisplayEnabledFlag) || /// CGDisplayReconfigurationCallBack docs say this function is called twice, once before, once after display reconfiguration, but it says in the 'before' callbacks, the flags are always set only to `kCGDisplayBeginConfigurationFlag` – so we're ignoring that here.
            (flags & kCGDisplayDisabledFlag))
        {
            DDLogInfo("DisplayLink.m: (%@) added / removed. Flagging the displayLink as outdated. display: %d, flags: %@", self->_name, display, MFCGDisplayChangeSummaryFlags_ToString(flags));
            self->_displayLinkIsOutdated = YES; /// Only flagging, so the displayLink won't be recreated when the user isn't even using Mac Mouse Fix. [Sep 2026]
        }
        else {
            DDLogDebug("DisplayLink.m: (%@) Ignored display reconfiguration. display: %d, flags: %@", self->_name, display, MFCGDisplayChangeSummaryFlags_ToString(flags));
        }
    }];
}

#pragma mark - Frame Callback

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext) {

    DisplayLink *self = (__bridge DisplayLink *)displayLinkContext;

    DisplayLinkCallbackTimeInfo timeInfo = parseTimeStamps(inNow, inOutputTime);

    static _Thread_local bool didSetPriority = false; /// CVDisplayLink spawns a new thread at priority 54 (fixed) on every CVDisplayLinkStart() [Sep 2026]
    if (!didSetPriority) {
        DDLogDebug("DisplayLink.m (%@) Recreating CVDisplayLinkThread", self->_name);
        didSetPriority = true; set_thread_priority(63, /*round_robin*/true);
    }

    bool hasPending;
    @synchronized (self) { hasPending = self->__hasPendingCVDisplayLinkCallback;
                           self->__hasPendingCVDisplayLinkCallback = 1;
                           self->__timeInfo = timeInfo; }

    if (!hasPending) { /// Prevent double-wakeup race thing that can happen I think (Signaling again would cause an extra, empty perform if we signal after the runLoop clears the signal but before the perform reads `__timeInfo`. [Sep 2026]
        CFRunLoopSourceSignal(self->_runLoopSource);
        CFRunLoopWakeUp(self->_runLoop);
    }

    return kCVReturnSuccess;
}
static void displayLinkCallback_OnRunLoop(void *info) {

    DisplayLink *self = (__bridge id)info;
    assertRunLoop(self->_runLoop);
    _readsState(&self->_readWriteTracker);

    DDLogDebug("DisplayLink.m: (%@) Callback", self->_name);

    DisplayLinkCallbackTimeInfo timeInfo;
    @synchronized (self) { self->__hasPendingCVDisplayLinkCallback = 0;
                           timeInfo = self->__timeInfo; }

    if (!self->_userRequestsToRun && self->_cvDisplayLinkRequestedToRun) {
        self->_ticksSinceUserRequestedStop += 1;
        if (self->_ticksSinceUserRequestedStop > kTicksUntilStoppingCVDisplayLink) {
            DDLogDebug("DisplayLink.m: (%@) callback called %d times after requested stop. Stopping CVDisplayLink", self->_name, kTicksUntilStoppingCVDisplayLink);
            self->_cvDisplayLinkRequestedToRun = NO;
            [self interactWithCVDisplayLink: ^{ CVDisplayLinkStop(self->_displayLink); }];
        }
        return;
    }
    if (!self->_userRequestsToRun) {
        DDLogDebug("DisplayLink.m: (%@) callback called after stop. Ignoring", self->_name);
        return;
    }

    _allowNestedReadOrWrite() /// [Sep 2026] Safe because at end of function | Animators call back into us from their callback (`-stop_Unsafe` when their animation ends)
    self.callback(timeInfo);
}

#pragma mark - Timestamps

/// Parsing CVTimeStamps

typedef struct {
    CFTimeInterval hostTS;
    CFTimeInterval frameTS;
    
    CFTimeInterval period;
    CFTimeInterval nominalPeriod;
    
} ParsedCVTimeStamp;

DisplayLinkCallbackTimeInfo parseTimeStamps(const CVTimeStamp *inNow, const CVTimeStamp *inOut) {

    /// @cleanup Maybe simplify and match CADisplayLink interface.

    /// Notes:
    /// - See this SO post for info on how to interpret the timestamps: https://stackoverflow.com/a/77170398/10601702
    ///     - Apple Technote on high precision timers and real-time threads: https://developer.apple.com/library/archive/technotes/tn2169/_index.html
    ///         - (This might be useful for getting our callback to be called at the start of the frame period instead of the end)
    
    /// Get frame timestamps
    
    ParsedCVTimeStamp tsNow = parseTimeStamp(inNow);
    ParsedCVTimeStamp tsOut = parseTimeStamp(inOut);
    
    /// Analyse parsed timestamps
    
    /// Analysis of frameTS and hostTS
    /// Our analysis shows:
    ///     - ts.frameTS -> When the last frame was sent
    ///     - tsOut.frameTS -> When the currently processed frame will be displayed
    ///         - From my observations, this tends to be 33.333ms (so two frames) in the future.
    ///     - ts.hostTS -> The time when this callback is called. Equivalent to CACurrentMediaTime().
    ///     - tsOut.hostTs -> No idea what this is. Won't use it.
    
    static CFTimeInterval anchor = 0;
    if (anchor == 0) {
        anchor = CACurrentMediaTime();
    }
    
    DDLogDebug("DisplayLink.m: \nhostDiff: %.1f, %.1f, frameDiff: %.1f, %.1f", (tsNow.hostTS - anchor)*1000, (tsOut.hostTS - anchor)*1000, (tsNow.frameTS - anchor)*1000, (tsOut.frameTS - anchor)*1000);

    #if 0
        static CFTimeInterval last = 0;
        CFTimeInterval measuredFramePeriod = now - last;
        last = now;
        DDLogDebug("DisplayLink.m: Measured frame period: %f", measuredFramePeriod);

        DDLogDebug("DisplayLink.m: \nframePeriod manual %.10f, api: %.10f", (tsOut.frameTS - tsNow.frameTS)/2.0, tsOut.period);
    #endif

    /// Analysis of period
    /// Our analysis shows:
    ///     - `CVDisplayLinkGetActualOutputVideoRefreshPeriod(_displayLink)` is the same as tsOut.period
    ///     - On the next displayLinkCalback() call, tsNow.period will be the same as tsOut.period on the current call.
    ///     - I'm not sure what when to use tsNow.period vs tsOut.period.  Both should be fine -> I will just use tsOut.
    ///     - Do the values make sense?
    ///         - I observed scrolling that looked distinctly 30 fps. But tsNow.period was still around 16.666 ms.
    ///     - In my observations, (outFrame - lastFrame) is always exactly equal to `2*nominalTimeBetweenFrames`
    ///     - timeBetweenFrames gives "The current rate of the device as measured by the timestamps" (this comes from the rateScalar docs) - so frameDrops inside apps like Safari won't affect this - it's the Displays refresh rate. I don't even know why this is be different from the nominalTimeBetweenFrames. In practise it always seems to be extremely close.
    ///         - If I understand correctly, based on this litherium post, the timeBetweenFrames is the display refresh rate as measured by the system host clock. While the nominalTimeBetweenFrames is the displayRefreshRate as measured by 'vsyncs'. Very confusing.
    ///             - The litherium post: http://litherum.blogspot.com/2021/05/understanding-cvdisplaylink.html
    
    /// Fill result struct
    
    DisplayLinkCallbackTimeInfo result = {
        .cvCallbackTime = tsNow.hostTS,
        .lastFrame = tsNow.frameTS,
        .thisFrame = tsNow.frameTS + tsOut.nominalPeriod, /// Should we use nominalPeriod or period here? And from tsNow or tsOut?
        .outFrame = tsOut.frameTS,
        .timeBetweenFrames = tsOut.period,
        .nominalTimeBetweenFrames = tsOut.nominalPeriod,
    };

    /// Return
    return result;
}

ParsedCVTimeStamp parseTimeStamp(const CVTimeStamp *ts) {
    
    /// Extract info from flags
    
    CVTimeStampFlags f = ts->flags;
    
    Boolean hostTimeIsValid = (f & kCVTimeStampVideoHostTimeValid) != 0;
    Boolean isInterlaced = (f & kCVTimeStampIsInterlaced) != 0;
    Boolean SMPTETimeIsValid = (f & kCVTimeStampSMPTETimeValid) != 0;
    Boolean videoRefreshPeriodIsValid = (f & kCVTimeStampVideoRefreshPeriodValid) != 0;
    Boolean timeStampRateScalerIsValid = (f & kCVTimeStampRateScalarValid) != 0;
    
    /// Handle weird flags
    
    if (!hostTimeIsValid || isInterlaced || SMPTETimeIsValid || !videoRefreshPeriodIsValid || !timeStampRateScalerIsValid) {
        
        DDLogWarn("DisplayLink.m: \nCVTimeStamp flags are weird - hostTimeIsValid: %d, isInterlaced: %d, SMPTETimeIsValid: %d, videoRefreshPeriodIsValid: %d, timeStampRateScalerIsValid: %d", hostTimeIsValid, isInterlaced, SMPTETimeIsValid, videoRefreshPeriodIsValid, timeStampRateScalerIsValid);
    }
    
    /// Extract other data from timestamp
    ///     (Ignoring smpteTime)
    
    int32_t videoTimeScale = ts->videoTimeScale;
    int64_t videoTime = ts->videoTime;
    int64_t videoRefreshPeriod = ts->videoRefreshPeriod;
    uint64_t hostTime = ts->hostTime; /// I think 'hostTime' is 'now' whereas 'videoTime' is when a frame occurs
    double rateScalar = ts->rateScalar; /// I think this is nominalRefreshPeriod / actualRefreshPeriod
    
    /// Parse video time
    ///     Note: We're calling these CFTimeInterval instead of double because they are interoperable with CACurrentMediaTime()
    
    CFTimeInterval tsVideo = videoTime / ((double)videoTimeScale);
    
    /// Parse host time
    ///     Notes:
    ///     - hostTime is in machTime according to this SO comment: https://stackoverflow.com/a/77170398/10601702
    ///         - This also supports that theory: https://developer.apple.com/documentation/corevideo/1456915-cvgetcurrenthosttime?language=objc
    ///     - We used to just use `videoTimeScale` to scale hostTime and it seemed to work as well. Not sure why.
    
    CFTimeInterval hostTimeScaled = machTimeToSeconds(hostTime);
    
    /// Parse refresh period
    ///     Note: Since it's 'rate' it should be division, but multiplication gives us the same values as CVDisplayLinkGetActualOutputVideoRefreshPeriod()
    CFTimeInterval periodVideoNominal = videoRefreshPeriod / ((double)videoTimeScale);
    CFTimeInterval periodVideo = periodVideoNominal * rateScalar;
    
    /// Build result struct
    
    ParsedCVTimeStamp result;
    result.hostTS = hostTimeScaled;
    result.frameTS = tsVideo;
    result.period = periodVideo;
    result.nominalPeriod = periodVideoNominal;
    
    /// return parsed videoTime
    
    return result;
}
@end
