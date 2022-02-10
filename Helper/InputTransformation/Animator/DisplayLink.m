//
// --------------------------------------------------------------------------
// DisplayLink.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "DisplayLink.h"
#import <Cocoa/Cocoa.h>
#import "WannabePrefixHeader.h"
#import "NSScreen+Additions.h"
#import "HelperUtility.h"

@interface DisplayLink ()

@end

/// Wrapper object for CVDisplayLink that uses blocks
/// Didn't write this in Swift, because CVDisplayLink is clearly a C API that's been machine-translated to Swift. So it should be easier to deal with from ObjC
@implementation DisplayLink {
    
    CVDisplayLinkRef _displayLink;
    CGDirectDisplayID *_previousDisplaysUnderMousePointer; /// Old and unused, use `_previousDisplayUnderMousePointer` instead
    CGDirectDisplayID _previousDisplayUnderMousePointer;                                                       ///
    BOOL _displayLinkIsOutdated;
    dispatch_queue_t _displayLinkQueue;
}

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

/// Start and stop

- (void)startWithCallback:(DisplayLinkCallback _Nonnull)callback {
    /// The passed in block will be executed every time the display refreshes until `- stop` is called or this instance is deallocated.
    /// Call `setToMainScreen` to link with the screen that currently has keyboard focus.
    ///     This is synchronous, when called from the main thread and asynchronous otherwise
    
    dispatch_async(_displayLinkQueue, ^{
        
        
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
                CVReturn rt = CVDisplayLinkStart(self->_displayLink);
                if (rt == kCVReturnSuccess) break;
                
                failedAttempts += 1;
                if (failedAttempts >= maxAttempts) {
                    DDLogInfo(@"Failed to start CVDisplayLink after %lld tries. Last error code: %d", failedAttempts, rt);
                    break;
                }
            }
        };
        
        /// Make sure block is running on the main thread
        
        if (NSThread.isMainThread) {
            /// Already running on main thread
            startDisplayLinkBlock();
        } else {
            /// Not yet running on main thread - dispatch on main - synchronously, so that subsequent isRunning calls return true
            dispatch_sync(dispatch_get_main_queue(), startDisplayLinkBlock);
        }
        
    });
}

- (void)stop {
    
    dispatch_async(_displayLinkQueue, ^{
        
        if (isRunning_Internal(self->_displayLink)) {
            
            /// CVDisplayLink should be stopped from the main thread
            ///     According to https://cpp.hotexamples.com/examples/-/-/CVDisplayLinkStop/cpp-cvdisplaylinkstop-function-examples.html
            
            void (^workload)(void) = ^{
                CVDisplayLinkStop(self->_displayLink);
            };
            
            if (NSThread.isMainThread) {
                workload();
            } else {
                dispatch_sync(dispatch_get_main_queue(), workload);
            }
        }
    });
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
    __block BOOL result;
    dispatch_sync(_displayLinkQueue, ^{
        result = isRunning_Internal(_displayLink);
    });
    return result;
}
BOOL isRunning_Internal(CVDisplayLinkRef dl) {
    /// Only call this if you're already running on _displayLinkQueue
    return CVDisplayLinkIsRunning(dl);
}

/// Set display to mouse location

- (void)linkToMainScreen {
    /// Simple alternative to .`linkToDisplayUnderMousePointerWithEvent:`.
    /// TODO: Test which is faster
    
    __block CVReturn result;
    
    dispatch_async(_displayLinkQueue, ^{
        result = [self setDisplay:NSScreen.mainScreen.displayID];
    });
}

- (void)linkToDisplayUnderMousePointerWithEvent:(CGEventRef)event {
    /// TODO: Test if this new version works
    
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
}

- (CVReturn)old_linkToDisplayUnderMousePointerWithEvent:(CGEventRef)event {
    /// - Made a new version of this that is simpler and more modular.
    /// - Pass in a CGEvent to get pointer location from. Not sure if signification optimization
    
    CGPoint mouseLocation = CGEventGetLocation(event);
    CGDirectDisplayID *newDisplaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 2);
    /// ^ We only make the buffer 2 (instead of 1) so that we can check if there are several displays under the mouse pointer. If there are more than 2 under the pointer, we'll get the primary onw with CGDisplayPrimaryDisplay().
    uint32_t matchingDisplayCount;
    CGGetDisplaysWithPoint(mouseLocation, 2, newDisplaysUnderMousePointer, &matchingDisplayCount);
    
    if (matchingDisplayCount >= 1) {
        if (newDisplaysUnderMousePointer[0] != _previousDisplaysUnderMousePointer[0]) { /// Why are we only checking at index 0? Should make more sense to check current master display against the previous master display
            free(_previousDisplaysUnderMousePointer); // We need to free this memory before we lose the pointer to it in the next line. (If I understand how raw C work in ObjC)
            _previousDisplaysUnderMousePointer = newDisplaysUnderMousePointer;
            // Sets dsp to the master display if _displaysUnderMousePointer[0] is part of the mirror set
            CGDirectDisplayID dsp = CGDisplayPrimaryDisplay(_previousDisplaysUnderMousePointer[0]);
            return [self setDisplay:dsp];
        }
    } else if (matchingDisplayCount == 0) {
        DDLogWarn(@"There are 0 diplays under the mouse pointer");
        return kCVReturnError;
    }
    
    return kCVReturnSuccess;
}

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

/// Display link callback

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext) {
    
    /// Get self
    DisplayLink *self = (__bridge DisplayLink *)displayLinkContext;
        
    /// Parse timestamps
    DisplayLinkCallbackTimeInfo timeInfo = parseTimeStamps(inNow, inOutputTime);
    
    /// Call block
    self.callback(timeInfo);
    
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

/// MARK: Parsing CVTimeStamp

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
    ///     - tsOut.hostTs -> No idea what this is.
    
//    CFTimeInterval now = CACurrentMediaTime();
    
//    DDLogDebug(@"\nhostDiff: %.1f, %.1f, frameDiff: %.1f, %.1f", (tsNow.hostTS - now)*1000, (tsNext.hostTS - now)*1000, (tsNow.frameTS - now)*1000, (tsNext.frameTS - now)*1000);
    
//    static CFTimeInterval last = 0;
//    CFTimeInterval measuredFramePeriod = now - last;
//    last = now;
//    DDLogDebug(@"Measured frame period: %f", measuredFramePeriod);
    
    /// Analysis of period
    /// Our analysis shows:
    ///     - CVDisplayLinkGetActualOutputVideoRefreshPeriod(_displayLink) is the same as tsOut.period
    ///     - On the next displayLinkCalback() call, tsNow.period will be the same as tsOut.period on the current call.
    ///     - I'm not sure what when to use tsNow.period vs tsOut.period.  Both should be fine -> I will just use tsOut.
    ///     - Do the values make sense?
    ///         - I observed scrolling that looked distinctly 30 fps. But tsNow.period was still around 16.666 ms.
    
    /// Fill result struct
    
    DisplayLinkCallbackTimeInfo result = {
        .now = tsNow.hostTS,
        .frameOutTS = tsOut.frameTS,
        .period = tsOut.period,
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
