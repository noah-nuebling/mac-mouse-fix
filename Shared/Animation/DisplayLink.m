//
// --------------------------------------------------------------------------
// DisplayLink.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "DisplayLink.h"
#import <Cocoa/Cocoa.h>
#import "WannabePrefixHeader.h"
#import "NSScreen+Additions.h"
#import "SharedUtility.h"

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
    CGDirectDisplayID _previousDisplayUnderMousePointer;                                                       ///
    BOOL _displayLinkIsOutdated;
    dispatch_queue_t _displayLinkQueue;
    MFDisplayLinkRequestedState _requestedState;
}

@synthesize dispatchQueue=_displayLinkQueue;

#pragma mark - Init

/// Convenience init

+ (instancetype)displayLink {
    
    return [[DisplayLink alloc] init];
}

/// Init

- (instancetype)init {
    
    self = [super init];
    if (self) {
        
        /// Setup queue
        dispatch_queue_attr_t attrs = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, -1);
        _displayLinkQueue = dispatch_queue_create("com.nuebling.mac-mouse-fix.helper.display-link", attrs);
        
        /// Setup internal CVDisplayLink
        [self setUpNewDisplayLinkWithActiveDisplays];
        
        /// Init displaysUnderMousePointer cache
        _previousDisplaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 2);
        /// ^ Why 2? - see `setDisplayToDisplayUnderMousePointerWithEvent:`
        
        /// Init _displayLinkIsOutdated flag
        _displayLinkIsOutdated = NO;
        
        /// Init _requestedState
        _requestedState = kMFDisplayLinkRequestedStateStopped;
        
        /// Setup display reconfiguration callback
        CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, (__bridge void * _Nullable)(self));
        
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
        ///
        ///     This has been causing deadlocks. Deadlocks explanation:
        ///         - This function runs on _displayLinkQueue and waits for displayLinkCallback when it calls CVDisplayLinkStop()
        ///         - displayLinkCallback waits for _displayLinkQueue when it tries to sync dispatch to it
        ///         -> Classic deadlock scenaro
        ///     The pretty solution I can come up with is to make either the displayLinkCallback or the _displayLinkQueue not acquire its resource (thread lock) before it it can acquire all the other resources that it will need. But we don't have access to the locking stuff that the CVDisplayLink uses at all afaik, so I don't know how this would be possible.
        ///     As an alternative, we could simply either
        ///     1. not make the callback _not_ try to acquire the queue lock
        ///         - by making the callback dispatch to queue async instead of sync
        ///         - this will make the callback not execute on the high priotity display link thread though, potentially making scrolling performance worse
        ///     2. make the queue _not_ try to acquire the callback lock
        ///         - by dispatching to main async instead of sync in the `- stop` and `- start` functions (Those are the functions where the deadlocks have occured so far.)
        ///         - This will potentially change the order of operations and introduce new bugs.
        ///
        ///     -> For now I'll try 2.
        ///
        ///     Edit: Seems to not make a difference so far and fixes the constant deadlocks!
        ///
        ///     Edit2: Solution 2. breaks isRunning(). Explanation: If, in start() and stop(), the displayLinkQueue async dispatches to mainQueue to do the actual starting and stopping, then the actual starting and stopping won't have happened yet when isRunnging() runs. Possible solutions:
        ///         - 1. Go back to sync dispatching to mainQueue in start() and stop() and hope the other changes we made coincidentally prevent the deadlocks that were happening
        ///             -> Worth a try
        ///         - 2. Dispatch to mainQueue also in isRunning() -> We're introducing a new sync dispatch, so this might very well lead to new deadlocks
        ///             -> Doesn't really make sense, try if desperate
        ///         - 3. Introduce new state variable 'requestedState' with states `requestedRunning` and `requestedStop`. Use this state to make isRunning() return the right value right after start() or stop() are called, even if the underlying CVDisplayLink hasn't started / stopped yet.
        ///             -> Think this makes sense. Try this if 1. doesn't work.
        ///
        ///         Edit: 1. Still doesn't work. -> Introducing _requestedState variable
        
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
    /// But if the displayLink is not running, yet the actual timeBetweenFrames is 0.0, so in that case it returns the nominal timeBetweenFrames.
    
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
    
    
    assert(false); /// Update this: We moved getting display under pointer to HelperState
    [self setDisplay:NSScreen.mainScreen.displayID];
}

- (void)linkToDisplayUnderMousePointerWithEvent:(CGEventRef _Nullable)event {
    
    assert(false); /// Update this: We moved getting display under pointer to HelperState NOTE: Why are we doing nothing with the return code? NOTE: Why is this unused in favor of linkToMainScreen?
    
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
    
    if (_displayLinkIsOutdated) {
        [self setUpNewDisplayLinkWithActiveDisplays];
        _displayLinkIsOutdated = NO;
    }
    
    return CVDisplayLinkSetCurrentCGDisplay(_displayLink, displayID);
}

/// Display reconfiguration callback

void displayReconfigurationCallback(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo) {
    /// This is called whenever a display is added or removed. If that happens we need to set up a new displayLink for it to be compatible with all the new displays (I think)
    ///     I get this idea from the `CVDisplayLinkCreateWithActiveCGDisplays` docs at https://developer.apple.com/documentation/corevideo/1456863-cvdisplaylinkcreatewithactivecgd
    /// To optimize, in this function, we only set the _displayLinkIsOutdated flag to true.
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

#pragma mark - Display Link Callback

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext) {
    
    /// Get self
    DisplayLink *self = (__bridge DisplayLink *)displayLinkContext;
        
    dispatch_sync(self.dispatchQueue, ^{ /// Use sync so this is actually executed on the high-priority display-linked thread // Why are we using self.dispatchQueue instead of `self->_displayLinkQueue`? I think self.dispatchQueue might cause some weird timing stuff since objc props are often atomic and stuff..
        
        /// Dispatch-sync-ing here is an experiment. Move it back to the callback if this fails
        
        /// Debug
        DDLogDebug(@"Callback displayLinkkk %@", [DisplayLink identifierForDisplayLink:displayLink]);
        
        /// Parse timestamps
        DisplayLinkCallbackTimeInfo timeInfo = parseTimeStamps(inNow, inOutputTime);
        
        /// Check requestedState
        if (self->_requestedState == kMFDisplayLinkRequestedStateStopped) {
            DDLogDebug(@"displayLinkkk callback called after requested stop. Returning");
            return;
        }
        
        /// Call block
        self.callback(timeInfo);
    });
    
    /// Return
    return kCVReturnSuccess;
}

/// Dealloc

- (void)dealloc
{
    CVDisplayLinkRelease(_displayLink);
    CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, (__bridge void * _Nullable)(self));
    /// ^ The arguments need to match the ones for CGDisplayRegisterReconfigurationCallback() exactly
    free(_previousDisplaysUnderMousePointer);
}

#pragma mark - Helper

/// Parsing CVTimeStamps

typedef struct {
    CFTimeInterval hostTS;
    CFTimeInterval frameTS;
    
    CFTimeInterval period;
    CFTimeInterval nominalPeriod;
    
} ParsedCVTimeStamp;

DisplayLinkCallbackTimeInfo parseTimeStamps(const CVTimeStamp *inNow, const CVTimeStamp *inOut) {
    
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
    ///     - CVDisplayLinkGetActualOutputVideoRefreshPeriod(_displayLink) is the same as tsOut.period
    ///     - On the next displayLinkCalback() call, tsNow.period will be the same as tsOut.period on the current call.
    ///     - I'm not sure what when to use tsNow.period vs tsOut.period.  Both should be fine -> I will just use tsOut.
    ///     - Do the values make sense?
    ///         - I observed scrolling that looked distinctly 30 fps. But tsNow.period was still around 16.666 ms.
    ///     - In my observations, (outFrame - lastFrame) is always exactly equal to 2*nominalTimeBetweenFrames
    
    /// Fill result struct
    
    DisplayLinkCallbackTimeInfo result = {
        .now = tsNow.hostTS,
        .lastFrame = tsNow.frameTS,
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
    
    CFTimeInterval tsVideo = videoTime / ((double)videoTimeScale);
    /// ^ We're calling these CFTimeInterval instead of double because they are interoperable with CACurrentMediaTime()
    
    /// Parse host time
    CFTimeInterval hostTimeScaled = hostTime / ((double)videoTimeScale);
    /// ^ The documentation doesn't say that videoTimeScale is supposed to be used for scaling hostTime. But it works.
    
    /// Parse refresh period
    CFTimeInterval periodVideoNominal = videoRefreshPeriod / ((double)videoTimeScale);
    CFTimeInterval periodVideo = periodVideoNominal * rateScalar;
    /// ^ Since it's 'rate' it should be division, but multiplication gives us the same values as CVDisplayLinkGetActualOutputVideoRefreshPeriod()
    
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
