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
    
    /// Shared memory
    BOOL _sharedMemoryIsMappedIn;
    StdFBShmem_t *_currentDisplayFrameBufferSharedMemory;
}

@synthesize dispatchQueue=_displayLinkQueue;

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
        _displayLinkQueue = dispatch_queue_create("com.nuebling.mac-mouse-fix.helper.display-link", attrs);
        
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
        
        /// Init shared memory
        _sharedMemoryIsMappedIn = NO;
        
    }
    return self;
}

- (void)setUpNewDisplayLinkWithActiveDisplays {
    
    if (_displayLink != nil) {
        CVDisplayLinkStop(_displayLink);
        CVDisplayLinkRelease(_displayLink);
    }
    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
    CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, (__bridge void * _Nullable)(self));
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
    DDLogDebug(@"Starting displayLinkkk %@", self.identifier);
    
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
                DDLogInfo(@"Failed to start CVDisplayLink after %lld tries. Last error code: %d", failedAttempts, rt);
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
    DDLogDebug(@"Stopping displayLinkkk %@", self.identifier);
    
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
    DDLogDebug(@"displayLinkkk %@ isRunning: %d", self.identifier, result);
    
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
- (NSString *)identifier {
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
    /// - What do we use for animations instead of this? (I think this would be appropriate to use for event sending, not for animation) - how do we link an animator driven by DisplayLink.m to the display where the animation takes place?
    /// TODO:
    /// - Actually use this instead of `linkToMainScreen` and test if this new version works
    
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
//        DDLogWarn(@"There are 0 diplays under the mouse pointer");
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
    
    /// Setup new displayLink if displays have been attached / removed
    ///     Note: Not sure if this is necessary
    if (_displayLinkIsOutdated) {
        [self setUpNewDisplayLinkWithActiveDisplays];
        _displayLinkIsOutdated = NO;
    }
    
    /// Set new display
    CGError cgErr = CVDisplayLinkSetCurrentCGDisplay(_displayLink, displayID);
    
    if (cgErr) {
        assert(false);
        return cgErr;
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
    
    // Get self
    DisplayLink *self = (__bridge DisplayLink *)userInfo;
    
    if ((flags & kCGDisplayAddFlag) ||
        (flags & kCGDisplayRemoveFlag) ||
        (flags & kCGDisplayEnabledFlag) ||
        (flags & kCGDisplayDisabledFlag)) { /// Using enabledFlag and disabledFlag here is untested. I'm not sure when they are true.
        
        DDLogInfo(@"Display added / removed. Setting up displayLink to work with the new display configuration");
        self->_displayLinkIsOutdated = YES;
    }
    
}

#pragma mark - Frame Callback

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext) {
    
    /// Get self
    DisplayLink *self = (__bridge DisplayLink *)displayLinkContext;
        
    /// Parse timestamps
    DisplayLinkCallbackTimeInfo timeInfo = parseTimeStamps(inNow, inOutputTime);
    
    /// Define workload
    
    void (^workload)(DisplayLinkCallbackTimeInfo) = ^(DisplayLinkCallbackTimeInfo timeInfo){
        
        /// Check requestedState
        if (self->_requestedState == kMFDisplayLinkRequestedStateStopped) {
            DDLogDebug(@"displayLinkkk callback called after requested stop. Returning");
            return;
        }
        
        /// Call block
        self.callback(timeInfo);
                
    };
    
    if (self->_optimizedWorkType == kMFDisplayLinkWorkTypeGraphicsRendering) {
        
        /// Notes:
        /// - For workType graphicsRendering we do the workload immediately. So we keep the scheduling from CVDisplayLink. CVDisplayLink seems to be designed for drawing graphics, so this should make sense.
        ///     - Actually, thinking about this a bit, I feel like our graphics animations that are driven by DisplayLink (at time of writing just the DynamicSystemAnimator.swift stuff) might also reduce framedrops by scheduling them differently. Evidence: We're currently articially slowing down DynamicSystemAnimator by making the sampleRate super high because for some reason that lead to much smoother framerates. This smells like better scheduling could improve things.
        ///     - The new CADisplayLink framework which was ported from iOS to macOS might have better scheduling?
        ///     - TODO: See if different scheduling can improve animation performance.
        /// - Use dispatch_sync so this is actually executed immediately on the high-priority display-linked thread - not sure if this is necessary or helpful in any way.
        /// - Why are we using `self.dispatchQueue` instead of `self->_displayLinkQueue`? I think self.dispatchQueue might cause some weird timing stuff since self.dispatchQueue is atomic.
        ///
        
        dispatch_sync(self.dispatchQueue, ^{
            workload(timeInfo);
        });
        
    } else if (self->_optimizedWorkType == kMFDisplayLinkWorkTypeEventSending) {
        
        ///
        /// Notes:
        /// - For workType eventSending, we execute the workload at the start of the next frame instead of right before the nextFrame. We hope that this will reduce stuttering in Safari and other apps.
        /// - From my understanding, timeInfo.thisFrame is in vsyncTime aka videoTime, and the dispatch_after call is in hostTime aka machTime. When the two time scales are out of sync, then that might lead to problems. I think you can sync them with rateScalar somehow, but not sure how that works.
        ///     - More on hostTime and videoTime/vsynctime in this litherium post on understanding CVDisplayLink: http://litherum.blogspot.com/2021/05/understanding-cvdisplaylink.html
        /// - I think dispatching at the start of the next frame helps performance. Sometimes on reddit it scrolls perfectly, but then sometimes it will get stuttery again. While the trackpad still scrolls smoothly. Not sure what's going on.
        /// - To get the time of the next frame for dispatch_after we should just be able to use `secondsToMachTime(timeInfo.nextFrame + nextFrameOffset);`, but I did a tiny bit of testing and there were some problems iirc. Either way the method we use now with dispatch_time is accurate and works well so it doesn't matter.
        /// - On this website --- https://mindofastoic.com/stoic-quotes?utm_content=cmp-true --- I can get pretty consistent framedrops
        ///
        /// Investigation into scrolling framedrops
        ///     (This investigation lead to the creation of the code for kMFDisplayLinkWorkTypeEventSending)
        /// - Results:
        ///     - The workload (so the actual stuff MMF is doing) takes less than 1 ms, so it can't be the source of the frame drops.
        ///     - It seems the callback is called ca. 4 ms before the next outFrame. This is really late. Maybe if our callback was called earlier in the 16.66ms period between frames we could avoid the framedrops
        ///
        /// - Other notes:
        ///     - See this Hacker News post on CVDisplayLink not actually syncing to your display: https://news.ycombinator.com/item?id=15889549
        ///         - The linked article corrects most of the claims it makes in an update, but then in the correction still says that `CVDisplayLinkCreateWithActiveCGDisplays` creates a non-vsynced display link. Which doesn't make sense I think since you can still assign that displayLink a `currentDisplay` which it should then sync to.
        ///             - The article links to this article on CADisplayLink on iOS for game loops. The link is dead but I think this is a mirror: https://www.gamedeveloper.com/programming/game-loops-on-ios
        ///             - The correction of the article says that CADisplayLink gets the vsync times from the kernel via StdFBSmem_t. Usage example here: https://stackoverflow.com/questions/2433207/different-cursor-formats-in-ioframebuffershared
        ///     - Since macOS 14.0 there is also the CADisplayLink API which was previously only available on iOS. There should be more resources on how to get it to work properly, since it's an iOS api. I haven't tested it, could it have different scheduling that might help with framedrops?
        ///
        /// - Experiments with usleep
        ///     - If we sleep for 17ms inside our dispatch_sync callback, then the framerate drops to 30 fps as expected.
        ///     - If we sleep for 8ms everything seems to work the same - light websites like hacker news run perfectly smooth, but websites like reddit stutter
        ///         - (remember that the whole dispatch_sync callback usually only takes around 1 ms, not 8 - so our code being slow doesn't seem to be the reason for stuttering)
        ///     - Conclusion:
        ///         - Theory: The displayLink tries to schedule the call of this callback so that it's done right before the frame is rendered (in the hackernews post that was mentioned somewhere, also, IIRC, this aligns with our observations about how timeInfo.lastFrame relates to the time when the CVDisplayLinkCallback is called). This scheduling makes sense (I think?) if we're *drawing* from the displayLink callback - which is what the displayLink callback is designed for. However, we're not drawing - we're outputting scroll events. Safari then still has to draw stuff based on these scroll events during the same frame. Since the scroll events are sent very late in the frame, that gives Safari very little time to draw its updates based on the incoming scroll events. Possible solution to framedrops: Output the scroll events *early* in the frame instead of late.
        /// - Experiments with scheduling
        ///     - We tried call our self.callback right after the next frame using dispatch_after. (Instead of right before the frame, which seems to be the natural behaviour of CVDisplayLink)
        ///         - I used this new scheduling for a day - in Safari and Chrome, scrolling peformance seems to now be on par with Trackpad scroling. I'm not 100% sure it's not a placebo that it's working better than dispatch_sync which we were using before, but as I said it' on par with the trackpad, so I think it's close to as good as it gets. However, in Safari, with a real trackpad, the scrolling performance is still better during momentumPhase. My best theories are
        ///             1. Safari stops listening to input events during momentumPhase and just drives the animations itself - leading to better performance. I know Xcode and some other apps do this, but I thought Safari didn't?
        ///             2. The scheduling of events coming from the trackpad driver during momentumPhase is faster than the screen refreshRate or aligned with the screen refresh rate in a different way, leading to less stuttering somehow.
        ///                 - I tried sending double the amount of scroll events but it didn't help I think. That was in commit db15199233b8be30036696105a8435dc83fa3efa
        ///         - Note on dispatch_after: I was worried that using `dispatch_after` would have worse performance than executing directly on the 'high performance display link thread' which the CVDisplayLink callback apparently runs on. But this doesn't seem to matter. From my observations (didn't reproduce this several times, so not 100% sure), using `dispatch_after`, it looks like the code we dispatch to consistently finishes within 2 ms of the preceding frame (Or more than 14 ms before the next frame). Even when there is heavy scroll stuttering in Safari. So using `dispatch_after` should be more than accurate and fast enough, and the stuttering seems to be caused by scheduling issues/issues in Safari.
        ///
        /// - Update after 3.0.2 release
        ///     - See this GH Issue by V-Coba: https://github.com/noah-nuebling/mac-mouse-fix/issues/875
        ///     - These change from 3.0.2 didn't really help in Safari. Sometimes MMF is smooth and the trackpad stutters, but sometimes the trackpad stutters and MMF is smooth. In Firefox, these changes seem to have created additional stutters, and it was very smooth before. So our experiment was unsuccessful. (And we shouldn't have published it in a stable release)
        ///     - We created two alternative builds: 3.0.2-v-coba and 3.0.2-v-coba-2. The original 3.0.2 build's scheduling (right after a frame) made things noticably worse in Firefox, and I got several feedbacks that scrolling was more stuttery. The first `v-coba` build went back to the native schduling (right before the frame), and restored the original performance characteristics. The `v-coba-2` build tried alternative scheduling optimized to get the best perfromance for scrolling on Reddit in Safari on my M1 MBA. However, in some situations, I observed it having more stutters on light websites like GitHub.
        ///         - Overall, I'm not sure which of the builds is better on average, they all stutter at times. But the original scheduling at least seemed to be stutter free on Firefox. While the 3.0.2 scheduling is not stutter free on Firefox anymore. For the `v-coba-2` scheduling, I haven't tested how it works with Firefox.
        ///         -> I think for now, **it's best to go back to the original scheduling**, since I'm confident that it's good on Firefox, and I'm not confident in the benefits of the 2 other schedulings we tried.
        ///             - See this comment for further discussion of this decisin: https://github.com/noah-nuebling/mac-mouse-fix/issues/875#issuecomment-2016869451
        ///         -> Maybe later, we can explore trying to analyze the CVDisplayLinkThread of the scrolled app in order to improve scheduling. That's the best idea I have right now. See https://github.com/noah-nuebling/mac-mouse-fix/issues/875#issuecomment-1986811798 for more info and potential libraries we could use to achieve this.

        
        /// Get timestamp for start of callback
        CFTimeInterval startTs = CACurrentMediaTime();
        
        /// Declare debug vars
        static CFTimeInterval rts;
        __block CFTimeInterval startTsSync;
        __block CFTimeInterval endTsSync;
        static CFTimeInterval lastEndTsSync;
        
        /// Add debug logging to workload
        
        if (runningPreRelease()) {
            
            workload = ^(DisplayLinkCallbackTimeInfo timeInfo){
                
                /// Debug
                DDLogDebug(@"Callback displayLinkkk %@", [DisplayLink identifierForDisplayLink:displayLink]);
                startTsSync = CACurrentMediaTime();
                
                /// Do work
                workload(timeInfo);
                
                /// Debug
                    
                /// Get timestamp
                endTsSync = CACurrentMediaTime();
                
                /// Get vsync info from shared memory
                uint64_t vblCount = 0;
                CFTimeInterval vblTime = 0.0;
                CFTimeInterval vblDelta = 0.0;
                if (self->_sharedMemoryIsMappedIn) {
                    vblCount = self->_currentDisplayFrameBufferSharedMemory->vblCount;
                    AbsoluteTime vblTimeWide = self->_currentDisplayFrameBufferSharedMemory->vblTime;
                    AbsoluteTime vblDeltaWide = self->_currentDisplayFrameBufferSharedMemory->vblDelta;
                    uint64_t vblTimeHost = (vblTimeWide.hi << 4) + vblTimeWide.lo;
                    uint64_t vblDeltaHost = (vblDeltaWide.hi << 4) + vblDeltaWide.lo;
                    vblTime = machTimeToSeconds(vblTimeHost);
                    vblDelta = machTimeToSeconds(vblDeltaHost);
                }
                
                /// Print
                DDLogDebug(@"displayLinkkk callback times - last %f, now %f, now2 %f, next %f, send %f\n|| overallProcessing %f, workProcessing %f, workPeriod %f, nextFrameToWorkCompletion %f\n||vblTime: %f, vblDelta: %f, vblCount: %llu",
                           (timeInfo.lastFrame - rts) * 1000,
                           (timeInfo.cvCallbackTime - rts) * 1000,
                           (startTs - rts) * 1000,
                           (timeInfo.thisFrame - rts) * 1000,
                           (endTsSync - rts) * 1000,
                           
                           (endTsSync - startTs) * 1000,
                           (endTsSync - startTsSync) * 1000,
                           (endTsSync - lastEndTsSync) * 1000,
                           (endTsSync - timeInfo.thisFrame) * 1000,
                           
                           vblTime - rts,
                           vblDelta, vblCount);
                
                lastEndTsSync = endTsSync;
                
            };
        }
        
        /// Calculate delay for doing workload
        ///
        /// Explanation:
        /// - The goal is that we do the workload at time `anchorTs + offset`
        ///
        /// Values to use:
        /// - Timestamps you might want to use for `anchorTs`: `timeInfo.lastFrame`, `timeInfo.nextFrame`, or `startTs`
        /// - Set `anchorTs` to -1 to do the work immediately (i.e use native CVDisplayLink scheduling)
        ///     - (`offset` should be set to 0 in this case)
        /// - `offset` can also be negative to do the workload before `anchorTs`.
        ///
        /// Values to recreate behavior of past versions:
        /// - Pre-3.0.2 + 3.0.2-v-coba behavior:
        ///     - anchorTs = -1, offset = 0
        /// - 3.0.2 behavior:
        ///     - anchorTs = timeInfo.nextFrame, offset = 0
        /// - 3.0.2-v-coba-2 behavior:
        ///     - anchorTs = `startTs`, offset = `3.75/16.0 * timeInfo.nominalTimeBetweenFrames`
        ///       (In the **Old experiments** you can find below, and in the `v-coba-2` source code, we wrote this offset as`-12.25/16.0 * timeInfo.nominalTimeBetweenFrames + timeInfo.nominalTimeBetweenFrames`)
        ///
        ///
        /// **Old experiments** that led us to the v-coba-2 behavior:
        ///
        /// **nextFrameOffset** testing in Safari:
        ///
        /// - 0.0 ok - 3.0.2 shipped with it
        /// - -0.2 better (??)
        /// - -0.4 worse (??) (This is basically same as native CVDisplayLink time rn)
        ///
        /// - 4ms+ gets noticably worse
        /// - 8ms+ gets better again
        /// - 12ms+ gets worse again (should be around same behaviour as -0.4 I think, since it's ca. nextNextFrameTime-0.4?)
        /// - 16.16ms+ is really bad
        ///
        /// **nextCallbackOffset** testing in Safari on Reddit frontpage.
        ///
        /// I think making things relative to the CVDisplayLinkCallbacks instead of frametimes might make more sense, since I looked into Firefox and Safari and they both also use CVDisplayLinkCallbacks for synchronization.
        ///
        /// - 14/16 idk
        /// - 12/16 ok. Worse than -12/16
        /// - 10/16 really bad
        /// - 8/16 worse
        /// - 6/16 idk
        /// - 4/16    **good**      feels the same as -12/16. Maybe little smoother, but since the delay is longer we prefer -12/16 over this
        /// - 2/16 idk
        ///
        /// - 0.0 baseline
        ///
        /// - -2/16 idk
        /// - -4/16 pretty good. Worse than -12/16. I think `-4/16 * 16.666` is worse than the approximation we used before -4.0;
        /// - -6/16 idk
        /// - -8/16 worse
        /// - -10/16 really bad
        /// - -11/16 worse than -12/16, better than -13/16 I think
        /// - -11.5/16 worse than -12/16
        /// - -11.75/16 same as -12/16
        /// - -11.9/16 same as -12/16
        /// - -12/16 **good**
        /// - -12.1/16 same as -12/16
        /// - -12.2/16 same as 12.25/16 I think
        /// - -12.25/16 might be **better** than -12/16                     -> we ended up using this for the **3.0.2-v-coba-2** build
        /// - -12.3/16 maybe worse than 12.25/16
        /// - -12.4/16 I think worse than 12.25
        /// - -12.5/16 I think worse than -12.25/16
        /// - -13/16 noticably worse than -12/16
        /// - -14/16 not great
        
        CFTimeInterval anchorTs = -1;   //startTs;
        CFTimeInterval offset   = 0;    //3.75/16.0 * timeInfo.nominalTimeBetweenFrames;
        
        CFTimeInterval workTs = anchorTs + offset;
        CFTimeInterval workDelay = workTs - startTs;
        
        if (anchorTs == -1) {
            assert(offset == 0);
        }
        if (workDelay <= 0) {
            assert(anchorTs == -1); /// If there's no delay, then we should have explicitly turned that off by setting anchorTs = -1
        }
        
        /// 
        /// Do workload
        ///
        
        if (workDelay <= 0) {
            dispatch_sync(self.dispatchQueue, ^{ /// Classic way of scheduling the workload
                workload(timeInfo);
            });
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC*workDelay), self->_displayLinkQueue, ^{ /// Schedule the workload to run after `workDelay`
                workload(timeInfo);
            });
        }
        
    } else { /// if `self->_optimizedWorkType` is unknown
        assert(false);
    }
    
    /// Return
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
    
    DDLogDebug(@"\nhostDiff: %.1f, %.1f, frameDiff: %.1f, %.1f", (tsNow.hostTS - anchor)*1000, (tsOut.hostTS - anchor)*1000, (tsNow.frameTS - anchor)*1000, (tsOut.frameTS - anchor)*1000);
    
//    static CFTimeInterval last = 0;
//    CFTimeInterval measuredFramePeriod = now - last;
//    last = now;
//    DDLogDebug(@"Measured frame period: %f", measuredFramePeriod);
    
//    DDLogDebug(@"\nframePeriod manual %.10f, api: %.10f", (tsOut.frameTS - tsNow.frameTS)/2.0, tsOut.period);
    
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
        
        DDLogWarn(@"\nCVTimeStamp flags are weird - hostTimeIsValid: %d, isInterlaced: %d, SMPTETimeIsValid: %d, videoRefreshPeriodIsValid: %d, timeStampRateScalerIsValid: %d", hostTimeIsValid, isInterlaced, SMPTETimeIsValid, videoRefreshPeriodIsValid, timeStampRateScalerIsValid);
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

#pragma mark - Shared Memory

- (CVReturn)mapInSharedMemoryForDisplay:(CGDirectDisplayID)displayID {
    
    assert(false);
    
    ///
    /// Map in shared memory from kernel
    ///     To get vsync timestamps directly form kernel to see if cvdisplaylink timestamps align with that
    ///
    /// Notes:
    /// - This code is copied from: https://stackoverflow.com/q/2433207/10601702
    /// - In the article from the ycombinator post on how cvdisplaylink doesn't actually sync to the display, there is a mention that CVDisplayLink itself gets the vsync times from shared memory (aka shmem) with the kernel in form of the publicly documented `StdFBShmem_t` struct. From my research you used to be able to map `StdFBShmem_t` into your processes memory through a series of steps building on`CGDisplayIOServicePort()`, which was then deprecated but replaced by the private `IOServicePortFromCGDisplayID()`, which was then removed but people replaced with a custom implementation using `IOServiceMatching("IODisplayConnect")`, which stopped working on Apple Silicon Macs. All these methods gave you access to an IODisplay instance and a 'FrameBuffer' which underlies the IODisplay as far as I understand. I think there also used to be `IOServiceMatching("IOFramebuffer")` but this seems to have been replaced by `IOServiceMatching("IOMobileFramebuffer")` on Apple Silicon Macs. There's a private set of functions to interact with it in the .tbd file of `MacOSX.sdk/System/Library/PrivateFrameworks/IOMobileFramebuffer.framework`. The most relevant function I could see was `_IOMobileFramebufferEnableVSyncNotifications` which has some documentation at https://iphonedev.wiki/IOMobileFramebuffer . Displays show up in the registry as objects of class `AppleCLCD2`, they have a bunch of attributes prefixed with `IOMFB` which seem to relate to the MobileFrameBuffer. I've also seen the prefix `IOFB`, which likely is an earlier prefix for the framebuffer, before it became the 'mobileFrameBuffer'. I assume that the `MobileFrameBuffer` APIs have been ported to macOS from iOS for the Apple Silicon transition. That would explain the `Mobile` prefix and the fact those APIs also seem to be present on iOS and seem to only exist on Apple Silicon Macs.
    ///
    /// Conclusion:
    /// - So far I haven't found a way to access the framebuffer stuff directly. It might be possible with private APIs, even on M1 Macs running the latest macOS version, but it's probably quite difficult.
    ///     - I'm pretty sure I have not found a way to access the framebuffer but I'm not 100% sure. It's been over a month between writing the code and writing these comments. Also see this GitHub comment I wrote as evidence that I haven't found a way: https://github.com/noah-nuebling/mac-mouse-fix/issues/875#issuecomment-1986394616
    /// - Accessing the framebuffer directly to get the vsync times would only help us if the timestamps that the CVDisplayLinkCallback receives from the system are not already giving us the correct vsync times. AND if, on top of that, bad syncing between our CGEvent-sending and the monitors' vsync is even the factor that causes the stuttering in the first place.
    ///     - From my observations, I lean towards thinking that these 2 factors are not the cause of the stuttering. Instead, I think that the problem is more likely bad syncing between the invocation time of the CVDisplayLinkCallbacks inside scrolled apps like Safari, with the send-time of the scroll events from MMF. I explain this theory more in this GitHub comment: https://github.com/noah-nuebling/mac-mouse-fix/issues/875#issuecomment-1986797450
    /// -> So since accessing the framebuffer is hard and I don't expect it to help us, **we gave up on trying to access the framebuffer**. Instead we planned to use system APIs to try and understand how the CVDisplayLinkCallback invocations are scheduled inside the scrolled app (like Safari), and to then schedule our event-sending relative to that. See this GitHub comment for more info: https://github.com/noah-nuebling/mac-mouse-fix/issues/875#issuecomment-1986811798
    
    ///
    /// Open IOService for this displays framebuffer
    ///
    
    /// Get framebuffer iterator
    /// Note:
    /// - Getting IOServiceGetMatchingService*s* and iterating over them probably makes more sense? But couldn't get that to work in short experiments.
    IOReturn ioErr;
    io_iterator_t iter;
    CFDictionaryRef frameBufferServiceMatching = IOServiceMatching("IOMobileFramebuffer"); /// MobileFrameBuffer is an Apple Silicon thing I think, see https://stackoverflow.com/questions/66812863/mac-m1-get-iomobileframebufferuserclient-interface
    io_service_t frameBufferService = IOServiceGetMatchingService(kIOMasterPortDefault, frameBufferServiceMatching);

    
    //    if (ioErr) {
//        assert(false);
//    }
    
    /// Iterate framebuffers
//    io_service_t frameBufferService = IO_OBJECT_NULL;
//    while (true) {
//        if (frameBufferService != IO_OBJECT_NULL) assert(false); /// There are multiple framebuffers
//        frameBufferService = IOIteratorNext(iter);
//        if (frameBufferService != IO_OBJECT_NULL) break;
//    }
    
    /// Validate
    assert(frameBufferService != IO_OBJECT_NULL);
    
    /// Retain framebuffer
    ///     Not sure if this leaks
//    IOObjectRetain(frameBufferService);
    
    /// Release iterator
//    IOObjectRelease(iter);
    
    
    
//    io_service_t displayService = IOServicePortFromCGDisplayID(displayID); // CGDisplayIOServicePort(displayID);
//    assert(displayService != 0);
    
    io_connect_t frameBufferConnect;
    ioErr = IOFramebufferOpen(frameBufferService, mach_task_self(), kIOFBSharedConnectType, &frameBufferConnect);
    
    ///
    /// Map shared memory
    ///
    
    if (ioErr == KERN_SUCCESS) {
            
        /// Unmap old memory
        ioErr = IOConnectUnmapMemory(frameBufferConnect, kIOFBCursorMemory, mach_task_self(), &_currentDisplayFrameBufferSharedMemory);
        if (ioErr) {
            assert(false);
        }
        
        /// Map new memory
        ///
        mach_vm_size_t size;
        IOConnectMapMemory(frameBufferConnect, kIOFBCursorMemory, mach_task_self(), &_currentDisplayFrameBufferSharedMemory, &size, /*kIOMapAnywhere +*/ kIOMapDefaultCache + kIOMapReadOnly);
        
        if (ioErr == KERN_SUCCESS) {
            assert(size == sizeof(StdFBShmem_t));
            
            AbsoluteTime vsyncTime = _currentDisplayFrameBufferSharedMemory->vblTime;
            DDLogDebug(@"Created framebuffer for new display with vsyncTime: vsyncTime: %u, %u", vsyncTime.hi, vsyncTime.lo);
            
        } else {
            assert(false);
        }
    } else {
        assert(false);
    }
    
    /// Cleanup
    IOServiceClose(frameBufferConnect);
    
    /// Set flag
    ///     NOTE: At the time of writing, we're not unsetting this flag anywhere, which we should do e.g. if a display is disconnected.
    _sharedMemoryIsMappedIn = YES;
    
    /// Return
    return kCVReturnSuccess;
}

static io_service_t IOServicePortFromCGDisplayID(CGDirectDisplayID displayID) {
    
    assert(false);
    
    /// - Helper function for `mapInSharedMemoryForDisplay:`
    /// - copied from here: https://github.com/glfw/glfw/blob/e0a6772e5e4c672179fc69a90bcda3369792ed1f/src/cocoa_monitor.m
    /// - UPDATE: IOServiceMatching("IODisplayConnect") is not supported on apple silicon macs: https://developer.apple.com/forums/thread/666383
    ///
    /// Original comments:
    ///     Returns the `io_service_t` corresponding to a CG display ID, or 0 on failure.
    ///     The `io_service_t` should be released with IOObjectRelease when not needed
    
    io_iterator_t iter;
    io_service_t serv, servicePort = 0;
    
    CFMutableDictionaryRef matching = IOServiceMatching("IODisplayConnect");
    
    // releases matching for us
    kern_return_t err = IOServiceGetMatchingServices(kIOMasterPortDefault,
                                                     matching,
                                                     &iter);
    if (err)
        return 0;
    
    while ((serv = IOIteratorNext(iter)) != 0)
    {
        CFDictionaryRef info;
        CFIndex vendorID, productID, serialNumber;
        CFNumberRef vendorIDRef, productIDRef, serialNumberRef;
        Boolean success;
        
        info = IODisplayCreateInfoDictionary(serv,
                                             kIODisplayOnlyPreferredName);
        
        vendorIDRef = CFDictionaryGetValue(info,
                                           CFSTR(kDisplayVendorID));
        productIDRef = CFDictionaryGetValue(info,
                                            CFSTR(kDisplayProductID));
        serialNumberRef = CFDictionaryGetValue(info,
                                               CFSTR(kDisplaySerialNumber));
        
        success = CFNumberGetValue(vendorIDRef, kCFNumberCFIndexType,
                                   &vendorID);
        success &= CFNumberGetValue(productIDRef, kCFNumberCFIndexType,
                                    &productID);
        success &= CFNumberGetValue(serialNumberRef, kCFNumberCFIndexType,
                                    &serialNumber);
        
        if (!success)
        {
            CFRelease(info);
            continue;
        }
        
        // If the vendor and product id along with the serial don't match
        // then we are not looking at the correct monitor.
        // NOTE: The serial number is important in cases where two monitors
        //       are the exact same.
        if (CGDisplayVendorNumber(displayID) != vendorID  ||
            CGDisplayModelNumber(displayID) != productID  ||
            CGDisplaySerialNumber(displayID) != serialNumber)
        {
            CFRelease(info);
            continue;
        }
        
        // The VendorID, Product ID, and the Serial Number all Match Up!
        // Therefore we have found the appropriate display io_service
        servicePort = serv;
        CFRelease(info);
        break;
    }
    
    IOObjectRelease(iter);
    return servicePort;
}



@end
