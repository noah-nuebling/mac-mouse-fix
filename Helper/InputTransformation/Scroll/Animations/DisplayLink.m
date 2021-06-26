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

@interface DisplayLink ()

@end

/// Wrapper object for CVDisplayLink that uses blocks
/// Didn't write this in Swift, because CVDisplayLink is clearly a C API that's been machine-translated to Swift. So it should be easier to deal with from ObjC
@implementation DisplayLink {
    
    CVDisplayLinkRef _displayLink;
    CGDirectDisplayID *_previousDisplaysUnderMousePointer;
    BOOL _displayLinkIsOutdated;
}

// Convenience init

+ (instancetype)displayLink {
    
    return [[DisplayLink alloc] init];
}

// Init

- (instancetype)init {
    
    self = [super init];
    if (self) {
        
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

// Start and stop

- (void)startWithCallback:(DisplayLinkCallback _Nonnull)callback {
    /// The passed in block will be executed every time the display refreshes until `- stop` is called or this instance is deallocated.
    /// Call `setToMainScreen` to link with the screen that currently has keyboard focus.
    
    /// Store callback
    
    self.callback = callback;
    
    /// Start the displayLink
    ///     If something goes wrong see notes in old SmoothScroll.m > handleInput: method
    CVReturn code = CVDisplayLinkStart(_displayLink);
    if (code != kCVReturnSuccess) {
        DDLogInfo(@"Failed to start CVDisplayLink. Error code: %d", code);
    } else {
//        DDLogDebug(@"Started displayLinkCallback");
    }
}
- (void)stop {
    CVDisplayLinkStop(_displayLink);
//    DDLogDebug(@"Stopped displayLinkCallback");
}

- (BOOL)isRunning {
    return CVDisplayLinkIsRunning(_displayLink);
}

// Set display to mouse location

- (CVReturn)linkToMainScreen {
    /// Simple alternative to .`setDisplayToDisplayUnderMousePointerWithEvent:`.
    /// TODO: Test which is faster by setting
    
    return [self setDisplay:NSScreen.mainScreen.displayID];
}

- (CVReturn)linkToDisplayUnderMousePointerWithEvent:(CGEventRef)event {
    /// Pass in a CGEvent to get pointer location from. Not sure if signification optimization
    
    CGPoint mouseLocation = CGEventGetLocation(event);
    CGDirectDisplayID *newDisplaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 2);
    // ^ We only make the buffer 2 (instead of 1) so that we can check if there are several displays under the mouse pointer. If there are more than 2 under the pointer, we'll get the primary onw with CGDisplayPrimaryDisplay()
    uint32_t matchingDisplayCount;
    CGGetDisplaysWithPoint(mouseLocation, 2, newDisplaysUnderMousePointer, &matchingDisplayCount);
    
    if (matchingDisplayCount >= 1) {
        if (newDisplaysUnderMousePointer[0] != _previousDisplaysUnderMousePointer[0]) { /// Why are we only checking at index 0?
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

// Display reconfiguration callback

void displayReconfigurationCallback(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo) {
    /// This is called whenever a display is added or removed. If that happens we need to set up a new displayLink for it to be compatible with all the new displays (I think)
    ///     I get this idea from the `CVDisplayLinkCreateWithActiveCGDisplays` docs at https://developer.apple.com/documentation/corevideo/1456863-cvdisplaylinkcreatewithactivecgd
    /// To optimize, in this function, we only set the _displayLinkIsOutdated flag to true.
    ///     Then we use that flag in `- setDisplay`, to set up a new displayLink when needed.
    ///     That way, the displayLink won't be recreated when the user isn't even using Mac Mouse Fix.
    
    // Get self and displayLink
    DisplayLink *self = (__bridge DisplayLink *)userInfo;
    
    if ((flags & kCGDisplayAddFlag) ||
        (flags & kCGDisplayRemoveFlag) ||
        (flags & kCGDisplayEnabledFlag) ||
        (flags & kCGDisplayDisabledFlag)) { /// Using enabledFlag and disabledFlag here is untested. I'm not sure when they are true.
        
        DDLogInfo(@"Display added / removed. Setting up displayLink to work with the new display configuration");
        self->_displayLinkIsOutdated = YES;
    }
    
}

// Display link callback

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext) {
    
    // Get self
    DisplayLink *self = (__bridge DisplayLink *)displayLinkContext;
        
    // Call block
    self.callback(); // Not passing in anything. None of the arguments to the CVDisplayLinkCallback are useful. Use CACurrentMediatime() to get current time inside the callback.
    
    // Return
    return kCVReturnSuccess;
}

// Dealloc

- (void)dealloc
{
    CVDisplayLinkRelease(_displayLink);
    CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, (__bridge void * _Nullable)(self));
    // ^ The arguments need to match the ones for CGDisplayRegisterReconfigurationCallback() exactly
    free(_previousDisplaysUnderMousePointer);
}

@end
