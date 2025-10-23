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
/// Higher-level-plan [Apr 2025]:
///     We plan to move to putting everything on an IOThread (aka GlobalEventTapThread), including callbacks and interaction with the DisplayLink.
///     This should be easy with the newer CADisplayLink, since you can tell it to deliver on a specific runLoop.
///         But since CADisplayLink is only supported on very new macOS versions, we'll have to keep using CVDisplayLink.
///     For CVDisplayLink we'd have to create a wrapper that 'contains' all its multithreading complexity and makes it deliver on a runLoop. This might cause worse CPU usage or event-timings, but I assume that won't matter too much.
///         On newer macOS versions we could implement CADisplayLink which should have optimal performance.
///     See more at GlobalEventTapThread.m

#import "DisplayLink.h"
#import <Cocoa/Cocoa.h>
#import "NSScreen+Additions.h"
#import "SharedUtility.h"
#import "IOUtility.h"

#import "Logging.h"

#if IS_HELPER
#import "HelperUtility.h"
#endif

@interface DisplayLink ()

typedef enum {
    kMFDisplayLinkRequestedStateStopped = 0,
    kMFDisplayLinkRequestedStateRunning,
} MFDisplayLinkRequestedState;

@end

/// Wrapper object for CVDisplayLink that uses blocks
/// Didn't write this in Swift, because CVDisplayLink is clearly a C API that's been machine-translated to Swift. So it should be easier to deal with from ObjC
@implementation DisplayLink {
    
    CVDisplayLinkRef _displayLink;
    CGDirectDisplayID *_previousDisplaysUnderMousePointer; /// Old and unused, use `_previousDisplayUnderMousePointer` instead
    CGDirectDisplayID _previousDisplayUnderMousePointer;
    BOOL _displayLinkIsOutdated;
    dispatch_queue_t _displayLinkQueue;
    MFDisplayLinkRequestedState _requestedState;
    MFDisplayLinkWorkType _optimizedWorkType;
}

@synthesize dispatchQueue=_displayLinkQueue;

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

+ (instancetype)displayLinkOptimizedForWorkType:(MFDisplayLinkWorkType)workType {
    return [[DisplayLink alloc] initOptimizedForWorkType:workType];
}

/// Init

- (instancetype)initOptimizedForWorkType:(MFDisplayLinkWorkType)workType {
    
    self = [super init];
    if (self) {
        
        /// Store type of work for which to optimize
        self->_optimizedWorkType = workType;
        
        /// Setup queue
        dispatch_queue_attr_t attrs = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, -1);
        _displayLinkQueue = dispatch_queue_create("com.nuebling.mac-mouse-fix.helper.display-link", attrs); /// TODO: Remove .helper from the queue name. This is used in the mainApp, too.
        
        /// Setup internal CVDisplayLink
        [self setUpNewDisplayLinkWithActiveDisplays];
        
        /// Init displaysUnderMousePointer cache
        _previousDisplaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 2);
        /// ^ Why 2? - see `setDisplayToDisplayUnderMousePointerWithEvent:`
        
        /// Init `_displayLinkIsOutdated` flag
        _displayLinkIsOutdated = NO;
        
        /// Init `_requestedState`
        _requestedState = kMFDisplayLinkRequestedStateStopped;
        
        /// Setup display reconfiguration callback
        CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, (__bridge void * _Nullable)(self));
    }
    return self;
}

- (void)setUpNewDisplayLinkWithActiveDisplays {
    
    /// Discussion
    ///     - Should be called `setupNew*CV*DisplayLink...` [Apr 2025] 
    ///     - MOS doesn't recreate the displaylink every time a new display is connected, so it's probably unnecessary. Why did we do all this elaborate stuff without testing? Should've at least left a comment that we haven't confirmed it to be necessary. [Oct 2025]

    /// Validate thread
    {
        /// [Aug 2025] We're calling CVDisplayLinkStart() and CVDisplayLinkStop() from the mainThread, and apparently that fixed some issues, we also had some external doc that suggested mainThread should be used for some things. (See notes where we call CVDisplayLinkStart()/CVDisplayLinkStop()). I also just saw that CVDisplayLink is non-sendable.
        ///     - My guess rn would be that each CVDisplayLink instance should only be interacted with from one thread.
        ///     - On which threads is this called? [Aug 2025]
        ///         - `[GestureScrollSimulator initialize]` calls this on `com.nuebling.mac-mouse-fix.helper.display-link` queue,
        ///         - `[Scroll load_Manual]` calls this on mainThread.
        ///         - `[ModifiedDragOutputTwoFingerSwipe load_Manual]` calls this on the mainThread.
        ///         - If the displayLink is recreated after detaching/reattaching a display, it seems to always run on `com.nuebling.mac-mouse-fix.helper.display-link` (Haven't done too much testing or thinking here.)
        ///         - (Haven't tested anything else)
        ///     - Other thought: Since this is only called rarely, (and I think always *before* that displayLink is actually used) race-conditions might be rare. But rare issues match the sporadic nature of the `scrolling-stops-intermittently_apr-2025.md` issues, and CVDisplayLinkStart()/CVDisplayLinkStop() did randomly fail when we called them from a non-main-thread according to the notes
        ///         ... but my gut feeling is that it's not about race-conditions.
        
        DDLogDebug(@"DisplayLink.m: (%@) Running -[setUpNewDisplayLinkWithActiveDisplays] on thread %@", [self identifier], NSThread.currentThread);
    }
    

    /// Delete existing displayLink
    if (_displayLink != NULL) {
        CVReturn ret = CVDisplayLinkStop(_displayLink);
        assert(ret == kCVReturnDisplayLinkNotRunning);
        DDLogDebug(@"DisplayLink.m: (%@) Deleting existing CVDisplayLink for displayLink. StopCode: %@", [self identifier], MFCVReturn_ToString(ret));
        CVDisplayLinkRelease(_displayLink);
        _displayLink = NULL;
    }
    
    /// Create new displayLink
    ///     [Aug 2025] I think silent failure of this probably causes the `scrolling-stops-intermittently_apr-2025.md` (Aka `Scroll Stops Working Intermittently`) bug.
    ///         To address this, in case of failure, we retry in a loop and eventually crash the program. That way we should have better robustness and better debug data (crashlogs)
    ///     [Aug 2025] Will this enter a crash-cycle if no display is attached at all?
    ///         Test result: Nope, seems like there is a dummy display in the API when no displayCable is attached to my Mac Mini 2018, and this code runs just fine. (However other parts of the codebase still experience assert-failures when no display is attached – Haven't looked into that.) See commit 6fa42122c7d38c315ad8f8f428e2b9b0fa5c8711.
    {
        const int max_tries = 20;       /// [Aug 2025] 20 is kinda arbitrary, but since this only seems to fail very rarely, and only runs in special situations like launching the helper, so there should be no performance impact to trying many times.
        CVReturn ret  = -1;             /// [Aug 2025] Init to silence stupid compiler warnings
        CVReturn ret2 = -1;
        
        for (int i = 0; i < max_tries; i++) {
            
            ret  = CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
            ret2 = CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, (__bridge void *_Nullable)(self)); /// [Aug 2025] Why is self `_Nullable`? || [Aug 2025] Test result: 'Silently' fails with kCVReturnInvalidArgument if you pass NULL as the `_displayLink`, that fits with our theory about this potentially causing `scrolling-stops-intermittently_apr-2025.md`.
            
            bool valid = (ret == kCVReturnSuccess) && (ret2 == kCVReturnSuccess) && (_displayLink != NULL);
            if (valid) {
                DDLogDebug(@"DisplayLink.m: (%@) Created CVDisplayLink (%@) on try %d", [self identifier], _displayLink, i);
                return;
            }
            
            CVDisplayLinkRelease(_displayLink);
            _displayLink = NULL; /// I'm pretty sure CVDisplayLinkCreateWithActiveCGDisplays() always overrides the `_displayLink` to be either NULL or valid. If it sometimes leaves the value untouched, then we'd have to set it to NULL after releasing to prevent use-after-free.
        }
        
        mfabort(@"DisplayLink.m: (%@) Failed to create CVDisplayLink (%@) after %d tries. Last codes: (%@, %@)", [self identifier], _displayLink, max_tries, MFCVReturn_ToString(ret), MFCVReturn_ToString(ret2));
    }
}

/// Dealloc

- (void)dealloc
{
    CVDisplayLinkRelease(_displayLink);
    CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, (__bridge void * _Nullable)(self));
    /// ^ The arguments need to match the ones for CGDisplayRegisterReconfigurationCallback() exactly
    free(_previousDisplaysUnderMousePointer);
}

#pragma mark - Start and stop

- (void)startWithCallback:(DisplayLinkCallback _Nonnull)callback {
    /// The passed in block will be executed every time the display refreshes until `- stop` is called or this instance is deallocated.
    /// Call `setToMainScreen` to link with the screen that currently has keyboard focus.
    ///     This is synchronous, when called from the main thread and asynchronous otherwise
    
    dispatch_async(_displayLinkQueue, ^{
        [self start_UnsafeWithCallback:callback];
    });
}

- (void)start_UnsafeWithCallback:(DisplayLinkCallback _Nonnull)callback {

    
    /// Debug
    DDLogDebug(@"DisplayLink.m: (%@) starting", [self identifier]);
    
    /// Store callback
    
    self.callback = callback;
    
    /// Start the displayLink
    ///     If something goes wrong see notes in old SmoothScroll.m > handleInput: method
    
    /// Starting the displayLink often fails with error code `-6660` for some reason.
    ///     Running on the main queue seems to fix that. (See SmoothScroll_old_).
    ///     We don't wanna use `dispatch_sync(dispatch_get_main_queue())` here because if were already running on the main thread(/queue?) then that'll crash
    
    /// Define block that starts displayLink
    
    void (^startDisplayLinkBlock)(void) = ^{
        
        int64_t failedAttempts = 0;
        int64_t maxAttempts = 100;
        
        while (true) {
            CVReturn rt = CVDisplayLinkStart(self->_displayLink); /// This locks until the displayLinkCallback is done
            if (rt == kCVReturnSuccess) break;
            
            failedAttempts += 1;
            if (failedAttempts >= maxAttempts) {
                DDLogInfo(@"DisplayLink.m: (%@) Failed to start CVDisplayLink after %lld tries. Last error code: %d", [self identifier], failedAttempts, rt);
                break;
            }
        }
    };
    
    /// Set requestedState
    ///     before async dispatching to main -> so that isRunning() works properly
    _requestedState = kMFDisplayLinkRequestedStateRunning;
    
    /// Make sure block is running on the main thread
    
    if ((NO)) {
        
        /// Dispatch to main synchronously
        
        if (NSThread.isMainThread) {
            /// Already running on main thread
            startDisplayLinkBlock();
        } else {
            /// Not yet running on main thread - dispatch on main - synchronously, so that subsequent isRunning calls return true
            dispatch_sync(dispatch_get_main_queue(), startDisplayLinkBlock);
        }
        
    } else {
     
        /// Dispatch to main asynchronously
        
        dispatch_async(dispatch_get_main_queue(), startDisplayLinkBlock);
        
    }
}
                   
- (void)stop {
    
    dispatch_async(_displayLinkQueue, ^{
        [self stop_Unsafe];
    });
}

- (void)stop_Unsafe {
    /// Debug
    DDLogDebug(@"DisplayLink.m: (%@) stopping", [self identifier]);
    
    if ([self isRunning_Unsafe]) {
        
        /// CVDisplayLink should be stopped from the main thread
        ///     According to https://cpp.hotexamples.com/examples/-/-/CVDisplayLinkStop/cpp-cvdisplaylinkstop-function-examples.html
        
        void (^workload)(void) = ^{
            CVDisplayLinkStop(self->_displayLink); /// This locks until the displayLinkCallback is done
        };
        
        /// Make sure block is running on the main thread
        
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
        
        /// Set requestedState
        ///     before async dispatching to main -> so that isRunning() works properly
        
        _requestedState = kMFDisplayLinkRequestedStateStopped;
        
        if ((NO)) {
            
            /// Dispatching to main synchronously
            
            if (NSThread.isMainThread) {
                workload();
            } else {
                dispatch_sync(dispatch_get_main_queue(), workload);
            }
            
        } else {
            
            /// Dispatch to main async
            
            dispatch_async(dispatch_get_main_queue(), workload);
        }
    }
}

//- (void)stop_FromDisplayLinkedThread {
//    /// The normal `stop` function is synchronous. But because of that, it'll deadlock when called from the displayLinkCallback's thread. So we have this asynchronous variant of the function just for that purpose.
//    ///     I'm not sure the standard stop function even has to be synchronous
//    ///         Edit: Actually we've since changed the normal `stop` function to be asynchronous, as well. There were more deadlocking problems and it's not necessary.. So this function is now redundant.
//    ///         I think the displayLinkCallback might run for another frame or even more after calling `stop()`, when we stop it asynchronously. I hope that's not a problem.
//    
//    dispatch_async(dispatch_get_main_queue(), ^{
//        if (self.isRunning) {
//            CVDisplayLinkStop(self->_displayLink);
//        }
//    });
//}

- (BOOL)isRunning {
    BOOL __block result = NO;
    dispatch_sync(_displayLinkQueue, ^{
        result = [self isRunning_Unsafe];
    });
    return result;
}

- (BOOL)isRunning_Unsafe {
    
    return _requestedState;
    
    /// Only call this if you're already running on `_displayLinkQueue`
    Boolean result = CVDisplayLinkIsRunning(self->_displayLink);
    
    /// Debug
    DDLogDebug(@"DisplayLink.m %@ isRunning: %d", [self identifier], result);
    
    /// Return
    return result;
}

#pragma mark - Other interface

+ (BOOL)callerIsRunningOnDisplayLinkThread {
    return [NSThread.currentThread.name isEqual:@"CVDisplayLink"];
}

+ (NSString *)identifierForDisplayLink:(CVDisplayLinkRef)dl { /// This id stuff is for debugging
    int64_t pointerNumber = (int64_t)(void *)dl;
    return [NSString stringWithFormat:@"%lld", pointerNumber];
}
- (NSString *)identifier { /// [Apr 2025] for debugging it would be handy to give the displayLink a 'name' based on where it's used
    return [DisplayLink identifierForDisplayLink:_displayLink];
}

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

- (CFTimeInterval)nominalTimeBetweenFrames {
    CVTime t = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(_displayLink);
    return (t.timeValue / (double)t.timeScale);
}

/// Set display to mouse location

- (void)linkToMainScreen {
    
    dispatch_async(_displayLinkQueue, ^{
        [self linkToMainScreen_Unsafe];
    });
}

- (void)linkToMainScreen_Unsafe {
    
    /// Simple alternative to .`linkToDisplayUnderMousePointerWithEvent:`.
    /// TODO: Test which is faster
    
    [self setDisplay:NSScreen.mainScreen.displayID];
}

- (void)linkToDisplayUnderMousePointerWithEvent:(CGEventRef _Nullable)event {
    
    /// Notes:
    /// - This is unused (as of 17.09.2024, MMF 3.0.3)
    ///     -> Which leads to the scroll-scheduling updating to a new screen, only once the key window is on that screen (since we use linkToMainScreen() instead of this.)
    ///     - TODO: actually use this instead of `linkToMainScreen` and test if this new version works.
    /// - I think this would be appropriate to use for event sending, not for animation, since it's based on a CGEvent) - For animation we need another approach.
    ///     - (But I think if we move over from the deprecated CVDisplayLink to the new CADisplayLink, we'll have to use a different approach anyways.)
    
#if IS_HELPER
    
    __block CVReturn result;
    
    dispatch_async(_displayLinkQueue, ^{
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
    });
    
#else
    assert(false);
#endif
}

//- (CVReturn)old_linkToDisplayUnderMousePointerWithEvent:(CGEventRef)event {
//    
//    /// - Made a new version of this that is simpler and more modular.
//    /// - Pass in a CGEvent to get pointer location from. Not sure if signification optimization
//    
//    CGPoint mouseLocation = CGEventGetLocation(event);
//    CGDirectDisplayID *newDisplaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 2);
//    /// ^ We only make the buffer 2 (instead of 1) so that we can check if there are several displays under the mouse pointer. If there are more than 2 under the pointer, we'll get the primary onw with CGDisplayPrimaryDisplay().
//    uint32_t matchingDisplayCount;
//    CGGetDisplaysWithPoint(mouseLocation, 2, newDisplaysUnderMousePointer, &matchingDisplayCount);
//    
//    CVReturn returnCode = kCVReturnSuccess;
//    bool doFreeDisplays = true;
//    
//    if (matchingDisplayCount >= 1) {
//        if (newDisplaysUnderMousePointer[0] != _previousDisplaysUnderMousePointer[0]) { /// Why are we only checking at index 0? Should make more sense to check current master display against the previous master display
//            free(_previousDisplaysUnderMousePointer); /// We need to free this memory before we lose the pointer to it in the next line. (If I understand how raw C work in ObjC)
//            _previousDisplaysUnderMousePointer = newDisplaysUnderMousePointer;
//            doFreeDisplays = false;
//            /// Sets dsp to the master display if _displaysUnderMousePointer[0] is part of the mirror set
//            CGDirectDisplayID dsp = CGDisplayPrimaryDisplay(_previousDisplaysUnderMousePointer[0]);
//            returnCode = [self setDisplay:dsp];
//        }
//    } else if (matchingDisplayCount == 0) {
//        DDLogWarn(@"DisplayLink.m: (%@) There are 0 diplays under the mouse pointer", [self identifier]);
//        returnCode = kCVReturnError;
//    }
//    
//    if (doFreeDisplays) {
//        free(newDisplaysUnderMousePointer);
//    }
//    
//    return returnCode;
//}


- (CVReturn)setDisplay:(CGDirectDisplayID)displayID {
    
    /// Note: [Apr 2025] Why doesn't this have the `_Unsafe` suffix? .. Maybe cause it's not made public in the header? Perhaps we should make it a static c function to signify that.
    
    /// Setup new displayLink if displays have been attached / removed
    ///     Note: Not sure if this is necessary
    if (_displayLinkIsOutdated) {
        [self setUpNewDisplayLinkWithActiveDisplays];
        _displayLinkIsOutdated = NO;
    }
    
    /// Set new display
    CVReturn ret = CVDisplayLinkSetCurrentCGDisplay(_displayLink, displayID);
    
    /// Log
    DDLogDebug(@"DisplayLink.m: (%@) set to display %d. Error: %d", [self identifier], displayID, ret);
    
    if (ret) {
        assert(false);
        return ret;
    }
    
    /// Return
    return kCGErrorSuccess;
}

#pragma mark - Reconfiguration Callback

void displayReconfigurationCallback(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo) {
    
    /// This is called whenever a display is added or removed. 
    ///     If that happens we need to set up a new displayLink for it to be compatible with all the new displays (I think)
    ///     I got this idea, because the CVDisplayLinkCreateWithActiveCGDisplays() docs say that it "determines the displays actively used by the host computer and creates a display link compatible with all of them.". I took this to mean that when a new display is attached, we need to call CVDisplayLinkCreateWithActiveCGDisplays() again. But I'm not sure if that's true. Either way, I guess recreating the displayLink when a new display is attached doesn't hurt.
    /// To optimize, in this function, we only set the `_displayLinkIsOutdated` flag to true.
    ///     Then we use that flag in `- setDisplay`, to set up a new displayLink when needed.
    ///     That way, the displayLink won't be recreated when the user isn't even using Mac Mouse Fix.
    /// Update: [Mar 2025]
    ///     - TODO: Test this! This is way to complicated and important to just not test and optimize it.
    ///     - CGDisplayReconfigurationCallBack docs say this is called twice, once before, once after display reconfiguration, but it says in the 'before' callbacks, the flags are always set only to `kCGDisplayBeginConfigurationFlag` – so we're ignoring that here.
    ///     - Threading:
    ///         Comments above CGDisplayChangeSummaryFlags definition say that callbacks might be called from different threads.
    ///         As I understand it would always be called from the 'event-processing thread' (which is what we call the 'displayLink thread' I think) in our case since our code doesn't manually change the display configuration (Not sure about this).
    ///         Either way, the code that uses the mutable state we manipulate here `_displayLinkIsOutdated` runs on the `_displayLinkQueue`, so there's potential for a race-condition here.
    ///             (After thinking about it, only race condition I can see is when there's a *double* display configuration change and, the second change is swallowed, and doesn't cause a -[setUpNewDisplayLinkWithActiveDisplays] call)
    ///             TODO: Probably dispatch this workload to the `_displayLinkQueue` to be very safe against race conditions.
    ///     - Optimization/Architecture:
    ///         - We do this for each DisplayLink instance separately. Would it make sense to only do it once for all DisplayLink instances? ... Probably wouldn't bring practical benefit though, and might make code more error-prone.
    
    /// Get self
    DisplayLink *self = (__bridge DisplayLink *)userInfo;
    
    if ((flags & kCGDisplayAddFlag)     || /// Using enabledFlag and disabledFlag here is untested. I'm not sure when they are true.
        (flags & kCGDisplayRemoveFlag)  || /// Update: [Apr 2025] I don't see a reason to recreate the displayLink when displays are *removed*.
        (flags & kCGDisplayEnabledFlag) ||
        (flags & kCGDisplayDisabledFlag))
    {
        DDLogInfo(@"DisplayLink.m: (%@) added / removed. Flagging the displayLink as outdated. display: %d, flags: %@", [self identifier], display, MFCGDisplayChangeSummaryFlags_ToString(flags));
        self->_displayLinkIsOutdated = YES;
    }
    else {
        DDLogDebug(@"DisplayLink.m: (%@) Ignored display reconfiguration. display: %d, flags: %@", [self identifier], display, MFCGDisplayChangeSummaryFlags_ToString(flags));
    }
    
}

#pragma mark - Frame Callback

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext) {
    
    /// Notes:
    ///     - [Aug 2025] We used to try to delay events here to reduce scrolling stutters. (See `MFDisplayLinkWorkType`) But we've now moved all that into `Old MFDisplayLinkWorkType stuff.md` and restored the 3.0.0 version of this code.
    ///     - [Aug 2025] There is a deadlock here due to lock-inversion.
    ///         See `Old MFDisplayLinkWorkType stuff.md > Deadlock: [Aug 2025]`
    ///         Not addressing that now for fear of causing other bugs, but restoring to 3.0.0 code may reduce chances of hitting the bug.
    ///         I think the deadlock has been here since commit `2bd62d5` when we started using `dispatch_sync()` here
    ///     - [Aug 2025] Eventually, we may want to move to CADisplayLink and async-dispatch to the "IOThread" we're planning. This would resolve the deadlock, too (See `Old MFDisplayLinkWorkType stuff.md`)
    
    DisplayLink *self = (__bridge DisplayLink *)displayLinkContext; /// [Aug 2025] Why are we getting this outside `dispatch_sync()`? Spending time outside `dispatch_sync()` increases chances of deadlock.
    
    dispatch_sync(self.dispatchQueue, ^{ /// [Aug 2025] Recovered notes from 3.0.0: Use sync so this is actually executed on the high-priority display-linked thread // Why are we using self.dispatchQueue instead of `self->_displayLinkQueue`? I think self.dispatchQueue might cause some weird timing stuff since objc props are often atomic and stuff..
            
        DDLogDebug(@"DisplayLink.m: (%@) Callback", [self identifier]);
         
        DisplayLinkCallbackTimeInfo timeInfo = parseTimeStamps(inNow, inOutputTime);
         
        if (self->_requestedState == kMFDisplayLinkRequestedStateStopped) {
            DDLogDebug(@"DisplayLink.m: (%@) callback called after requested stop. Returning", [self identifier]);
            return;
        }
        
        self.callback(timeInfo);
    });
    
    return kCVReturnSuccess;
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
    
    DDLogDebug(@"DisplayLink.m: \nhostDiff: %.1f, %.1f, frameDiff: %.1f, %.1f", (tsNow.hostTS - anchor)*1000, (tsOut.hostTS - anchor)*1000, (tsNow.frameTS - anchor)*1000, (tsOut.frameTS - anchor)*1000);
    
//    static CFTimeInterval last = 0;
//    CFTimeInterval measuredFramePeriod = now - last;
//    last = now;
//    DDLogDebug(@"DisplayLink.m: Measured frame period: %f", measuredFramePeriod);
    
//    DDLogDebug(@"DisplayLink.m: \nframePeriod manual %.10f, api: %.10f", (tsOut.frameTS - tsNow.frameTS)/2.0, tsOut.period);
    
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
        
        DDLogWarn(@"DisplayLink.m: \nCVTimeStamp flags are weird - hostTimeIsValid: %d, isInterlaced: %d, SMPTETimeIsValid: %d, videoRefreshPeriodIsValid: %d, timeStampRateScalerIsValid: %d", hostTimeIsValid, isInterlaced, SMPTETimeIsValid, videoRefreshPeriodIsValid, timeStampRateScalerIsValid);
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
