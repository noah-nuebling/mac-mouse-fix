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
#import "Utility_Helper.h"

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
        rt = [Utility_Helper displayUnderMousePointer:&dsp withEvent:event];
        
        /// Premature return
        if (rt == kCVReturnError) {
            result = kCVReturnError; return; /// Coudln't get display under pointer
        }
        if (dsp == self->_previousDisplayUnderMousePointer) {
            result = kCVReturnSuccess; return; /// Display under pointer already linked to
        }
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
    
    // Get self
    DisplayLink *self = (__bridge DisplayLink *)displayLinkContext;
        
    // Call block
    self.callback(); // Not passing in anything. None of the arguments to the CVDisplayLinkCallback are useful. Use CACurrentMediatime() to get current time inside the callback.
    
    // Return
    return kCVReturnSuccess;
}

/// Dealloc

- (void)dealloc
{
    CVDisplayLinkRelease(_displayLink);
    CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, (__bridge void * _Nullable)(self));
    // ^ The arguments need to match the ones for CGDisplayRegisterReconfigurationCallback() exactly
    free(_previousDisplaysUnderMousePointer);
}

@end
