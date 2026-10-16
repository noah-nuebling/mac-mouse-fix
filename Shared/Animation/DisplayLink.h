//
// --------------------------------------------------------------------------
// DisplayLink.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#pragma mark - VSync helpers

/// VBLPhase
///     Passed to `CGDisplay_NearestVBLTime`. Pretends like the grid of VSync times is shifted by this many frame periods. Only the fractional part matters (0.25 == 1.25).
///     Also see:
///         `vblphase.m` - Opus 5.5 script visualizing the phase
///         `Old MFDisplayLinkWorkType stuff.md` - MFDisplayLinkWorkType was an earlier attempt at doing the phaseShifts to improve stuttering, which we rolled back because it caused deadlocks. Deadlocks are no longer a risk after 'No more dispatch queues' refactor! [Oct 2026]
///     Alternative optimization idea:
///         [Sep 2026] On macOS 27, M4 MBA, after 'No more dispatch queues' refactor, responsiveness feels exactly the same as a trackpad, (so MFDisplayLinkWorkType delay idea may not help anymore)
///              - that is except for Safari, where we found that you need to attach an IOHIDEvent to get it to do the in-process momentum scrolling that you also get in NSScrollView and which keeps it more responsive under load.
///              -> TODO: Look into attaching the IOHIDEvent in GestureScrollSimulator.m to optimize Safari.
///                 (Opus 5.5 knows where in the WebKit source code is the implementation [Sep 2026])
///                 (Don't have time for this now because it changes the scrolling curve and stuff which Safari loads via `kMFCGEventFieldSenderID` and stuff [Sep 2026])

typedef double VBLPhase;

/** Observation justifying this value: The CVDisplayLink in the old impl called its callback at phaseShift=0.5-0.6 this might be optimal for AppKit updates. Untested [Oct 2026] */
#define kVBLPhase_DefaultForAppKitUpdates 0.5

/** Observations justifying this value:
    - Looks like Trackpad's DockSwipe and Scroll CGEvents are all dispatched at phaseShift=0.25 on macOS 27.
        - There's actually a lot of variance especially for the Scroll CGEvents, but looks like 0.25 is the target
    - DockSwipe simulation: Dispatching DockSwipes at close to 0.0 causes a lot of stutter (0.9 - 0.05 was clearly bad). Dispatching at 0.75 was mostly fine but dips into stutter, 0.25 more consistent (Not sure about that observation). Tested [Oct 2026, macOS 27, M4 MBA]
        - Interesting: If you look at the DockSwipe's HIDEvent's timestamps it looks like the trackpad driver dispatches every 8.00 ms but the CGEvents wrapping them are delivered in-sync with the display. (Every couple events has a delta of 0) Actually delivering CGEvents at 8.00 ms causes stuttering. [Oct 2026, macOS 27, M4 MBA, 144 Hz display] */

#define kVBLPhase_DefaultForEventSending 0.25

extern uint64_t SLSDisplayGetPriorVBLTime(CGDirectDisplayID displayID);
extern uint64_t SLSDisplayGetCurrentVBLDelta(CGDirectDisplayID displayID);
uint64_t CGDisplay_NearestVBLTime(CGDirectDisplayID displayID, const char *beforeOrAfter, uint64_t anchorInMachTime, VBLPhase phaseShift);

#define fallbackPriorVBLTime(now) (now)
#define kFallbackVBLDelta secondsToMachTime(1.0/60) /** Opus 5.5 says `SLSDisplayGetPriorVBLTime` etc can return 0, and in that case the displayLink should keep ticking because the downstream code expects that so gestures don't get stuck or whatever. Not sure if Opus is overly concerned. [Oct 2026] */
#define defaultVBLTolerance(vblDelta) (vblDelta / 2.0)

#pragma mark - Typedefs for the DisplayLink class


typedef struct {
    /// These are just `CGDisplay_NearestVBLTime()` result values passed to callbacks for convenience [Oct 2026]
    CFTimeInterval lastFrame;           ///< Last VSync time (shifted by `phaseShift`) before the callback. Guaranteed to increase between callbacks (Tiny bug: Clients use `nextFrame` and rely on *that* to increase, not `lastFrame` and on VRR display there might be small chance this fails) [Oct 2026]
    CFTimeInterval timeBetweenFrames;   ///< Can be used to extrapolate to adjacent frames relative to `lastFrame` [Oct 2026]
    CFTimeInterval nextFrame;           ///< `lastFrame + timeBetweenFrames` [Oct 2026]
} DisplayLinkCallbackTimeInfo;

typedef void(^DisplayLinkCallback)(DisplayLinkCallbackTimeInfo timeInfo);

#pragma mark - DisplayLink class

@interface DisplayLink : NSObject


    + (instancetype)displayLinkWithPhaseShift: (VBLPhase)phaseShift runLoop: (CFRunLoopRef)runLoop name: (NSString *)name;
    - (instancetype)init NS_UNAVAILABLE;

    - (CFRunLoopRef)runLoop CF_RETURNS_NOT_RETAINED; /// Expose runLoop so that Animators (which build on top of DisplayLink) can access it, too [Oct 2026]

    - (void)startWithCallback:(DisplayLinkCallback)callback;
    - (void)stop;
    - (BOOL)isRunning;

    - (void)linkToMainScreen;

@end
