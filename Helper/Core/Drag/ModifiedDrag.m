
//
// --------------------------------------------------------------------------
// ModifyingActions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/**

`Slow WindowServer IPC` problems [Oct 2026]
    [Oct 2026] After 'No more dispatch queues' refactor (Which put everything on IOThread+mainThread instead of many different concurrent dispatch queues),
        I noticed 2 problems with TwoFingerSwipe.m when under heavy load (When scrolling something heavy like Spotify and it gets to like 5 fps):
        - A) `Erratic momentum speeds` Summary: Momentum scrolling speeds were erratic (The thing `_smoothingAnimator` is designed to prevent)
        - B) `warpDeltas` Summary: The position of the puppet cursor and scrolled view sometimes jumped back in the opposite direction some time after starting the click-and-drag gesture.

        Cleanup idea:
            Maybe make `Erratic momentum speeds` and `warpDeltas` notes separate? Not sure how related they are [Oct 2026]

        Diagnosis / Observations:
            - When under very heavy load, some calls that do WindowServer IPC end up blocking for a super long time, like 10s or even 100s or milliseconds.
                I observed being slow: `CGEventTapEnable`, `CGWarpMouseCursorPosition`, `CGDisplayHideCursor` (I think I remember observing that one, not 100% sure)
            - When these `Slow WindowServer IPC` calls block the IOThread, then `_smoothingAnimator` won't be able to deliver regularly.
                -> This causes A) `Erratic momentum speeds`
                (That's because AppKit's NSScrollView seems to base its in-process-momentum-scroll speed on the time between the last two gesture-phase events, I surely wrote more about that a long time ago, probably around `_smoothingAnimator` or `GestureScrollSimulator.m` [Oct 2026])
            - After PointerFreeze calls `CGWarpMouseCursorPosition`, the eventTaps in ModifiedDrag.m and PointerFreeze.m
                still receive a few events with unwarped pointer location.
                The first warped event carries a delta describing (actualMovementByUserForThisEvent + warpDelta).
                Under heavy load, this warpDelta can come so late into the gesture (and therefore be so large) that it's very noticable.
                -> This causes B) `warpDeltas`
        Solution measures:
            A) `Erratic momentum speeds`:
                Solution measure: We moved the per-event callbacks (`mouseMovedCallback`) inside PointerFreeze.m (which block on `CGWarpMouseCursorPosition`) from IOThread to mainThread.
                    This unblocks IOThread and allows it to deliver `_smoothingAnimator` regularly.
                Conclusion: This immediately fixes the problem even under super heavy load.
                Caveats?: I still sometimes saw erratic momentumSpeeds but only when debug logging is enabled and I think only when Xcode is attached (which makes the log calls extra slow, I think [Oct 2026])
                Alternatives/Questions:
                    - You could have `_smoothingAnimator` on a completely separate thread, but under any normal circumstance this seems good enough
                    - Doesn't it cause problems to have the mainThread (instead of the IOThread) blocked by WindowServer IPC?
                        -> I don't notice any downsides. Explanation idea: the only other thing we're doing on mainThread during the gesture is puppetCursor drawing in ScreenDrawer.swift, and I guess if the WindowServer is that much under load, us not sending it more draw commands (because blocked by IPC) doesn't hurt overall framerate/responsiveness? Not sure. [Oct 2026]
            B) `warpDeltas`:
                Solution measures based on `Slow WindowServer IPC` theory:
                    The theory: Maybe the `Slow WindowServer IPC` calls (see above) block the IOThread, and somehow cause WindowServer to process and send us many events before our `CGWarpMouseCursorPosition` is called/starts taking effect.
                    Sub-solution measure 1: `MFEventTap` - We introduced MFEventTap as an attempt to fix this (but it might have other advantages, see `MFEventTap.h` notes [Oct 2026])
                        Mechanism: MFEventTap.m allows ModifiedDrag.m and PointerFreeze.m to share one underlying CGEventTap,
                            which avoids problem where the `CGEventTapEnable` call for PointerFreeze.m happens during ongoing gesture (in +handleBecameInUse) and takes very long, and only once it returns, will PointerFreeze start sending CGWarpMouseCursorPosition (from its CGEventTap callback).
                        Conclusion: I think this made the problem better.
                            Caveat: Didn't really try the `Reproduction` of the super bad circumstances (See below.) [Oct 2026]
                    Sub-solution measure 2: Make PointerFreeze.m > `freezePointer` not block `+handleBecameInUse` at all
                        Mechanism: freezePointer() doesn't call `CGEventTapEnable` anymore (See `MFEventTap` solution measure above),
                            but it still does another `Slow WindowServer IPC` call: `CGDisplayHideCursor`
                        Conclusion: Didn't see any improvement (in the `WarpDeltaCompensator`s logs - see below [Oct 2026])
                            -> This casts doubt that the `MFEventTap` solution measure (see above) even made a difference, or if maybe the `Caveat` (not doing `Reproduction` properly tricked me.)
                    Conclusion: I'm not sure these `Slow WindowServer IPC`-based solution measures worked. However, that shouldn't matter because the `WarpDeltaCompensator` solution measure (below [Oct 2026]) seems to work.
                        Deeper context: I'm only writing this down I guess to document that this might have been a (now stale) factor that went into the MFEventTap design, or decision to even add it to codebase. [Oct 2026]
                Solution measure: `WarpDeltaCompensator`
                    Mini object which tracks the pattern where the pointer location veers off the
                        freeze-/CGWarpMouseCursorPosition-point and then snapps back in one event which also carries the `warpDelta`.
                        `WarpDeltaCompensator` then subtracts that `warpDelta` so our algorithms always get the actual movement by the physical mouse.
                        Conclusion: This seems to work
                            What I observed: It feels like it stops the 'swallowing' of the pointer movement
                            What I haven't observed: I haven't really reproduced the super bad circumstances which caused the jank. See `Reproduction` below [Oct 2026]
                        Caveat: Observations made on macOS 27. Didn't test older versions. If they don't have the `warpDelta` this could be detrimental.
                            Reason to maybe believe this: `CGWarpMouseCursorPosition` docs say that it doesn't produce a delta event, but the `warpDelta` seemingl contradicts that. [Oct 2026]
        `Reproduction`
            B) `warpDeltas` [Oct 2026]
                - I always see the `warpDeltas` in logs, but it's not very noticable, the problem where it really janks out and makes the scrollPosition / puppetCursor jump can be hard to reproduce
                    (Update: wrote this before I implemented the `Solution measures` above, might be impossible to reproduce now) - it comes in cycles, I think only under heavy window-server load. The load I saw it under:
                    - M4 MBA, macOS 27
                    - 60 Hz screen: streaming vbldelta.m and logs from MMF helper, and watching youtube at 1080p
                    - 144 Hz screen: Xcode, streaming MMF Helper logs, using MMF 'Scroll & Navigate' in the main view.
                    - Having lots of Safari tabs and iTerm tabs, and Finder windows open in the background.
                    -> Even then the problem only occurred in 'cycles' sometimes going back to perfectly smooth scrolling, but when it was bad it happened every interaction, and usually so bad it ended up scrolling in the *opposite* direction that I moved the gesture (Don't fully understand why that happens.) 
                - Also reproduced on 3.1.0 (24898) (before 'No more dispatch queues' refactor) -> Not a regression from the refactor. Maybe new in macOS 27 / 27.2 Beta 3
                - Never noticed this issue ever before that day.
        Also see:
            The logs we added that are tagged with `[debugWarpDelta]` - they let us clearly see the `warpDeltas` problem (maybe along with vbldelta.m script)
                §cleanup: Maybe remove this tag at some point [Oct 2026]
 */

#import "Constants.h"

#import "ModifiedDrag.h"
#import "ScrollModifiers.h"
#import "GestureScrollSimulator.h"
#import "Modifiers.h"

#import "SubPixelator.h"
#import <Cocoa/Cocoa.h>

#import "ModificationUtility.h"
#import "MFMessagePort.h"
#import "Remap.h"
#import "SharedUtility.h"
#import "Config.h"

#import "HelperUtility.h"

#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "SharedUtility.h"

#import "ModifiedDragOutputThreeFingerSwipe.h"
#import "ModifiedDragOutputTwoFingerSwipe.h"
#import "ModifiedDragOutputFakeDrag.h"
#import "ModifiedDragOutputAddMode.h"

#import "Threads.h"
#import "MathObjc.h"

#import "MFEventTap.h"

@implementation CoalescableEvent @end
@implementation CoalescableEvent_Delta @end
@implementation CoalescableEvent_Deactivation @end

@implementation ModifiedDrag

/// Notes:
///     [Jun 2025]
///         We've planned to add a feature for custom drag gestures at some point,
///             I thought it should have some custom visual feedback for OneShot actions
///             - IIRC I made some mockups in the big MMF Sketch project
///             - "Gaussian Blur + Contrast" trick to simulate surface tension could be interesting. See: https://www.reddit.com/r/iOSProgramming/comments/1l2xxx5/bringing_emoji_reactions_to_life_a_creative_take/
///     TODO: Rename this to just `Drag`

#define kListenerID @"ModifiedDrag"

/// Vars

static ModifiedDragState _drag = {
    .warpDeltaCompensator = { .name = "ModifiedDrag" }
};

/// Derived props

//+ (CGPoint)pseudoPointerPosition {
//
//    return CGPointMake(_drag.origin.x + _drag.originOffset.x, _drag.origin.y + _drag.originOffset.y);
//}

/// Debug
+ (MFModifiedInputActivationState) debug_activationState {
    /// We wanted to expose `_drag` to other modules for debugging, but `_drag` can't be exposed to Swift. Maybe because it contains an ObjC pointer`id`. Right now this is fine though because we only need the activationState for debugging anyways.
    return _drag.activationState;
}

+ (NSString *)modifiedDragStateDescription:(ModifiedDragState)drag {
    NSString *output = @"";
    @try {
        output = [NSString stringWithFormat:
        @"\n\
        eventTap: %@\n\
        usageThreshold: %lld\n\
        type: %@\n\
        activationState: %u\n\
        origin: (%f, %f)\n\
        originOffset: (%f, %f)\n\
        usageAxis: %u\n\
        phase: %d\n",
                  [MFEventTap descriptionForListener: kListenerID], drag.usageThreshold, drag.type, drag.activationState, drag.origin.x, drag.origin.y, drag.originOffset.x, drag.originOffset.y, drag.usageAxis, drag.firstCallback];
    } @catch (NSException *exception) {
        DDLogInfo("Exception while generating string description of ModifiedDragState: %@", exception);
    }
    return output;
}

/// Lifecycle

+ (void)load_Manual {
    
    /// Init plugins
    [ModifiedDragOutputTwoFingerSwipe load_Manual];

    /// Setup pendingCoalescableEvents
    _drag.pendingCoalescableEvents = [NSMutableArray new];

    /// Set usage threshold
    _drag.usageThreshold = 7; // 20, 5
    
    /// Create mouse moved callback
    [MFEventTap registerListener: kListenerID forEvents: kMFEventType_Sensor callback: eventTapCallback];
}

/// Interface - start

//+ (NSDictionary *)initialModifiers {
//
//    if (_drag.activationState == kMFModifiedInputActivationStateNone) {
//        return nil;
//    } else if (_drag.activationState == kMFModifiedInputActivationStateInitialized || _drag.activationState == kMFModifiedInputActivationStateInUse) {
//        return _drag.initialModifiers;
//    } else {
//        assert(false);
//    }
//}

+ (void)initializeDragWithDict:(NSDictionary *)effectDict {
    
    assertRunLoop(IOThread.runLoop);

    /// Debug
    DDLogDebug("INITIALIZING MODIFIEDDRAG WITH previous type %@ activationState %d, newEffectDict: %@", _drag.type, _drag.activationState, effectDict);

    /// Guard state == inUse
    ///  I think if state == initialized we don't need to do anything special
    if (_drag.activationState == kMFModifiedInputActivationStateInUse) {
        if ((1)) return;
        else { /// Old code which doesn't seem to do anything [Oct 2026]
            BOOL isSame = [effectDict isEqualToDictionary:_drag.effectDict];
            BOOL isAddMode = [_drag.effectDict[kMFModifiedDragDictKeyType] isEqual:kMFModifiedDragTypeAddModeFeedback];
            if (!isSame && !isAddMode) { /*deactivate(YES)*/; return; }
            else                       return;
        }
    }

    /// Get type
    MFStringConstant type = effectDict[kMFModifiedDragDictKeyType];

    /// Init static parts of `_drag`
    _drag.type = type;
    _drag.effectDict = effectDict;
    //_drag.initialModifiers = modifiers;
    _drag.initTime = CACurrentMediaTime();

    id<ModifiedDragOutputPlugin> p;
    if      ([type isEqualToString:kMFModifiedDragTypeThreeFingerSwipe]) p = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputThreeFingerSwipe.class;
    else if ([type isEqualToString:kMFModifiedDragTypeTwoFingerSwipe])   p = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputTwoFingerSwipe.class;
    else if ([type isEqualToString:kMFModifiedDragTypeFakeDrag])         p = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputFakeDrag.class;
    else if ([type isEqualToString:kMFModifiedDragTypeAddModeFeedback])  p = (id<ModifiedDragOutputPlugin>)ModifiedDragOutputAddMode.class;
    else                                                                 assert(false);

    _drag.coalesceEvents = true;
    if (1) if (isclass(p, ModifiedDragOutputTwoFingerSwipe)) _drag.coalesceEvents = false; /// `ModifiedDragOutputTwoFingerSwipe` already has its own `TouchAnimator` which effectively coalesces output events, we think coalescing again here might responsiveness (Didn't really test) [Sep 2026]

    /// TESTING
    if ((0)) _drag.coalesceEvents = false;

    /// Link with plugin
    //[p initializeWithDragState:&_drag];
    _drag.outputPlugin = p;

    /// Init dynamic parts of _drag
    initDragState();
}
static void initDragState(void) {

    _drag.origin = getRoundedPointerLocation();
    _drag.originOffset = (Vector){0};
    _drag.activationState = kMFModifiedInputActivationStateInitialized;
    _drag.isSuspended = NO;
    _drag.displayID = 0;
    _drag.lastVBLTimeThatProcessedCoalescableEvents = 0;

    [_drag.outputPlugin initializeWithDragState:&_drag]; /// We just want to reset the plugin state here. The plugin will already hold ref to `_drag`. So this is not super pretty/semantic

    [MFEventTap enable: true forListener: kListenerID];
    DDLogDebug("Enabled drag eventTap");
}

static void eventTapCallback(MFEventType eventType, CGEventRef *eventPtr) {

    assertRunLoop(IOThread.runLoop);

    CGEventRef event = *eventPtr;



    /// Get deltas
    /// These are truly integer values, I'm not rounding anything / losing any info here
    /// However, the deltas seem to be pre-subpixelated, and often, both dx and dy are 0.
    
    int64_t dx = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
    int64_t dy = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);

    /// Debug
    if (runningDebugMode()) {

        static double tsLast = 0;
        double ts = CACurrentMediaTime();
        DDLogDebug("ModifiedDrag eventTapCallback [debugWarpDelta] type %2d, delta (%3lld, %3lld) (%3lld, %3lld), loc: (%.2f, %.2f), dt: %5.2f age: %.2f",
            CGEventGetType(event),
            dx,
            dy,
            CGEventGetIntegerValueField(event, kCGEventUnacceleratedPointerMovementX),
            CGEventGetIntegerValueField(event, kCGEventUnacceleratedPointerMovementY),
            CGEventGetLocation(event).x,
            CGEventGetLocation(event).y,
            1e3*(ts - tsLast),
            1e3*(CACurrentMediaTime() - CGEventGetTimestampInSeconds(event, kTapLocation_Listening))
        );
        tsLast = ts;

        /// Filter other event-types (might wanna log other events for debugging [Oct 2026])
        //if ((CGEventMaskBit(type) & _eventMask) == 0) return event;
    }

    /// WarpDeltaCompensator
    WarpDeltaCompensator_GetActualDelta(&_drag.warpDeltaCompensator, dx, dy, CGEventGetLocation(event), &dx, &dy);

    /// Ignore event if both deltas are zero
    /// - We do this so the phases for the gesture scroll simulation (aka twoFingerSwipe) make sense. The gesture scroll event with phase kIOHIDEventPhaseBegan should always have a non-zero delta. If we let through zero deltas here it messes those phases up. Now that we're dispatching throuch a TouchAnimator this shouldn't really matter but it doesn't hurt.
    /// - I think for all other types of modified drag (aside from the gesture scroll simulation discussed above) this shouldn't break anything, either.

    if (dx != 0 || dy != 0) {


        /// Interrupt
        ///     [Sep 2026] Update: Old comment from before `coalesceEvents` refactor, not sure if/how it still applies:
        ///         This handles race condition where `_drag.eventTap` is disabled right after `eventTapCallBack()` is called
        ///         We implemented the same idea in PointerFreeze.
        ///         Actually, the check for kMFModifiedInputActivationStateNone below (Update: [Sep 2026] Now in `processPendingCoalescableEvents`) has the same effect, but I think but this makes it clearer?
        if (![MFEventTap isEnabledForListener: kListenerID]) return;

        /// Get the display (For processing coalescable events once per frame) [Oct 2026]
        if (!_drag.displayID) _drag.displayID = [[NSScreen mainScreen] displayID];

        /// Process coalescable events
        if (!_drag.coalesceEvents) {
            processCoalescableDeltaEvent(dx, dy, CGEventGetLocation(event));
        } else {
            /// Append to pendingCoalescableEvents
            CoalescableEvent_Delta *deltaEvent = [CoalescableEvent_Delta new]; {
                deltaEvent.deltaX = dx;
                deltaEvent.deltaY = dy;
                deltaEvent.pointerLocation = CGEventGetLocation(event);
            }
            [_drag.pendingCoalescableEvents addObject: deltaEvent];

            /// Process pendingCoalescableEvents
            processPendingCoalescableEventsOncePerFrame();
        }
    }

    /// Return mouseMoved event
    /// Notes:
    /// - Sending NULL here almost works perfectly, but in screenRecordings it will make the cursor jump. That's especially annoying for DisplayLink users
    /// - The cursor jumping also goes away when you set the eventTap location to kCGAnnotatedSessionEventTap. The other two locations don't work.
    /// - Sending mouseMoved here would interfere with fakeDrag output. How will we solve that?
    /// - Just changing the type on the original event is a little hacky but it should work
    /// - Sending these mouseMoved events doesn't interfere with freezing the pointer. Not sure why.
    /// - Update [Sep 2026]: Comments above are from before 'No more dispatch queues' refactor. Not totally sure they still apply (didn't really read them)

    CGEventSetType(event, kCGEventMouseMoved);
}

static void processPendingCoalescableEventsOncePerFrame(void) {

    /// Strategy: Flush the queue of coalescable events on the first mouse event each frame [Oct 2026]
    ///     (To be precise, flush on first mouse event that comes at last vsync time + `kVBLPhase_DefaultForEventSending`)
    ///         Also see: `kVBLPhase_DefaultForEventSending` comments [Oct 2026]
    ///     Alternative approaches tested and abandoned:
    ///         - Measure SLSDisplayGetCurrentVBLDelta once at the start of the gesture and use that on a timer. Result: Works just as well, probably because the VBL times don't drift on my display. On a VRR display I suspect it would be worse UX. Don't think it makes a meaningful performance difference, so not worth using. [Oct 2026]
    ///     Other alternative approach ideas: [Oct 2026]
    ///         All the coalescing just solves *vertical* DockSwipe (Mission Control gesture) freezing and lag introduced by macOS 27 for high-polling rate mice,
    ///             but for low-polling-rate mice, could introduce
    ///                 - Extra CPU overhead (Due to timers/DisplayLink.m, which we decided to avoid here for now [Oct 2026])
    ///                 - Maybe slightly more jerkiness for horizontal swipes if you avoid timers/DisplayLink.m (see `Problem with this approach` below)
    ///             -> Maybe, more pragmatic approach is to activate coalescing only for vertical swipes. That could simplify some things.
    ///             -> Could also only activate for low-polling rate mice, but don't know how to detect that robustly - think it's probably bad approach [Oct 2026]
    ///     Problem with this approach (which is: flushing on mouse events):
    ///         Flushing every frame through DisplayLink uses a lot more CPU, but flushing on the first mouse event each frame causes irregular `VBLPhase` for lower polling-rate mice,
    ///             which I think I observed makes things a little more stuttery than no coalescing at all for horizontal DockSwipes on my [Logitech Lift 135 Hz, macOS 27, 144 Hz display].
    ///                 Also see observations on jankiness caused by sending close to phaseShift 0.0 in `kVBLPhase_DefaultForEventSending` comment [Oct 2026]
    ///             Caveat: The tracking on the Logitech Lift is super uneven and jerky anyways, so it might be placebo.
    ///         Improvement idea:
    ///             Fallback timer - set up a timer (DisplayLink.m) each frame, which waits for a regular mouse event to flush, if no mouse event before deadline, the timer flushes that frame instead
    ///                 -> This should give us good `VBLPhase` with less CPU overhead.
    ///                     I think the CPU overhead, mostly comes from the runLoop waking up for the per-frame timer in addition to the CGEventTap wakeup - I observed there's still a lot of effective CPU overhead flushing every frame through timer, even with our super-lightweight `mk_timer` based `DisplayLink` - so I concluded overhead is inherent to the additional runLoop wakeup. [Oct 2026]
    ///             §afterNoGCDTodo consider implementing this

    uint64_t now = mach_absolute_time();
    uint64_t lastVBLTime = CGDisplay_NearestVBLTime(_drag.displayID, "before", /*anchorInMachTime*/now, kVBLPhase_DefaultForEventSending) ?: fallbackPriorVBLTime(now);
    uint64_t vblDelta = SLSDisplayGetCurrentVBLDelta(_drag.displayID) ?: kFallbackVBLDelta;
    uint64_t tolerance = defaultVBLTolerance(vblDelta); /// `CGDisplay_NearestVBLTime` always extrapolates the frames a little differently so directly comparing the results will give false negatives [Oct 2026].
    if (_drag.lastVBLTimeThatProcessedCoalescableEvents < lastVBLTime - tolerance) {

        _drag.lastVBLTimeThatProcessedCoalescableEvents = lastVBLTime;
        processPendingCoalescableEvents();

        if (runningDebugMode()) {
            static double lastTS = 0;
            double ts = CACurrentMediaTime();
            if (lastTS) DDLogDebug("coalescingTimerCallback: invocation delta: %.2fms" ,(ts-lastTS)*1000.0);
            lastTS = ts;
        }
    }
}

static void processPendingCoalescableEvents(void) {

    assertRunLoop(IOThread.runLoop);

    /// Early return
    if (!_drag.pendingCoalescableEvents.count) return;

    /// Gather/coalesce data from pendingCoalescableEvents
    double deltaXSum = 0;
    double deltaYSum = 0;
    CoalescableEvent_Delta *lastDeltaEvent = nil;
    CoalescableEvent_Deactivation *deactivationEvent = nil;
    {
        for (CoalescableEvent *event in _drag.pendingCoalescableEvents) {
            if (isclass(event, CoalescableEvent_Deactivation)) {
                deactivationEvent = (id)event;
                break;
            }
            else if (isclass(event, CoalescableEvent_Delta)) {
                CoalescableEvent_Delta *event_ = (id)event;
                deltaXSum += event_.deltaX;
                deltaYSum += event_.deltaY;
                lastDeltaEvent = event_;
            }
            else mfassert(false, @"Unknown ModifiedDrag_Event: %@", event);
        }
    }
    CGPoint lastPointerLocation = getRoundedPointerLocationWithPointerLocation(lastDeltaEvent.pointerLocation);

    /// Clear pendingCoalescableEvents
    [_drag.pendingCoalescableEvents removeAllObjects];

    /// Process coalescable delta event(s)
    processCoalescableDeltaEvent(deltaXSum, deltaYSum, lastPointerLocation);

    /// Process deactivationEvent
    processCoalescableDeactivationEvent(deactivationEvent);
}

static void processCoalescableDeltaEvent(double deltaXSum, double deltaYSum, CGPoint lastPointerLocation) {
    if (deltaXSum || deltaYSum)
    {
        /// Update originOffset
        _drag.originOffset.x += deltaXSum;
        _drag.originOffset.y += deltaYSum;

        /// Suspension
        if (_drag.isSuspended) return;

        /// Debug
        DDLogDebug("ModifiedDrag handling coalescable mouseMoved");

        /// Call further handler functions depending on current state
        MFModifiedInputActivationState st = _drag.activationState;

        if (st == kMFModifiedInputActivationStateNone) {

            /// [Sep 2026] Old comment from before `coalesceEvents` refactor:
            ///     Disabling the callback triggers this function one more time apparently
            ///         That's the only case I know where I expect this. Maybe we should log this to see what's going on.

        } else if (st == kMFModifiedInputActivationStateInitialized) {

            handleMouseInputWhileInitialized(deltaXSum, deltaYSum, lastPointerLocation);

        } else if (st == kMFModifiedInputActivationStateInUse) {

            handleMouseInputWhileInUse(deltaXSum, deltaYSum);
        }
    }
}

static void processCoalescableDeactivationEvent(CoalescableEvent_Deactivation *deactivationEvent) {
    if (deactivationEvent) [_drag.outputPlugin handleDeactivationWhileInUseWithCancel: deactivationEvent.cancelled];
}

static void handleMouseInputWhileInitialized(int64_t deltaX, int64_t deltaY, CGPoint pointerLocation) {

    /// Activate the modified drag if the mouse has been moved far enough from the point where the drag started
    
    Vector ofs = _drag.originOffset;
    if (MAX(fabs(ofs.x), fabs(ofs.y)) > _drag.usageThreshold) {
        
        /// Debug
        DDLogDebug("Modified Drag entered 'in use' state");
        DDLogDebug("ModifiedDrag becameInUse [debugWarpDelta] (%lld, %lld) loc: (%d, %d)", deltaX, deltaY, (int)pointerLocation.x, (int)pointerLocation.y);

        /// Store state
        _drag.usageOrigin = pointerLocation;

        if (fabs(ofs.x) < fabs(ofs.y)) {
            _drag.usageAxis = kMFAxisVertical;
        } else {
            _drag.usageAxis = kMFAxisHorizontal;
        }
        
        /// Update state
        _drag.activationState = kMFModifiedInputActivationStateInUse;
        _drag.firstCallback = true;

        /// Do deferred init
        /// Could also do this in normal init `initializeDragWithDict`, but here is more effiicient (`initializeDragWithDict` is called on every mouse click if it's set up for that button)
        /// -> Don't use `naturalDirection` before state switches to `kMFModifiedInputActivationStateInUse`!
        /// TODO: Build UI for this
        /// Edit:
        ///   Lot's of people complained about this in 3.0.0 Beta 6. See https://github.com/noah-nuebling/mac-mouse-fix/issues?q=is%3Aissue+is%3Aopen+label%3A%223.0.0+Beta+6+Click+and+Drag+Direction%22
        ///   It think reading the userdefaults didn't work properly for many users. So we're disabling this now until we build the UI for it.
        /// Edit2: The problem was that the it fell back to naturalDirection = false when the userDefaults didn't contain a value for `com.apple.swipescrolldirection`, which is the case if the user has never edited the `natural scroll direction` system setting. But if `com.apple.swipescrolldirection` doesn't exist, then the scroll direction is actually natural on Apple Trackpad and Magic Mouse. So if we fall back to natural scroll direction, it should match Trackpad/Magic mouse behaviour and users should be happy.
    
        NSNumber *systemScrollDirection = [NSUserDefaults.standardUserDefaults objectForKey:@"com.apple.swipescrolldirection"];
        /// `Scroll.reverseClickAndDragDirection` flips the system setting. Missing key (existing configs) means false.
        ///     Flipping `naturalDirection` flips both the delta sign (see `handleMouseInputWhileInUse`) and `invertedFromDevice` in the output plugins. So the drag behaves as if the system setting was flipped, for Spaces & Mission Control and Scroll & Navigate alike.
        bool reverseClickAndDragDirection = ((NSNumber *)config(@"Scroll.reverseClickAndDragDirection")).boolValue;
        _drag.naturalDirection = (systemScrollDirection == nil ? true : systemScrollDirection.boolValue) != reverseClickAndDragDirection;
        
        /// Notify output plugin
        [_drag.outputPlugin handleBecameInUse];
        
        /// Notify TrialCounter.swift
        [TrialCounter.shared handleUse];
        
        /// Notify other modules
        [Modifiers handleModificationHasBeenUsed];
//        (void)[OutputCoordinator suspendTouchDriversFromDriver:kTouchDriverModifiedDrag];
    }
}
/// Only passing in event to obtain event location to get slightly better behaviour for fakeDrag
static void handleMouseInputWhileInUse(int64_t deltaX, int64_t deltaY) {

    /// Invert direction
    if (!_drag.naturalDirection) {
        deltaX = -deltaX;
        deltaY = -deltaY;
    }

    /// Notifiy plugin
    [_drag.outputPlugin handleMouseInputWhileInUseWithDeltaX:deltaX deltaY:deltaY];
    
    /// Update phase
    ///
    /// - firstCallback is used in `handleMouseInputWhileInUseWithDeltaX:...` (called above)
    /// - The first time we call `handleMouseInputWhileInUseWithDeltaX:...` during a drag, the `firstCallback` will be true. On subsequent calls, the `firstCallback` will be false.
    ///     - Indirectly communicating with the plugin through _drag is a little confusing, we might want to consider removing _drag from the plugins and sending the relevant data as arguments instead.
    
    _drag.firstCallback = false;
}

+ (void)deactivateWithCancel:(BOOL)cancel {

    assertRunLoop(IOThread.runLoop);
    
    /// Debug
    DDLogDebug("modifiedDrag deactivate with state: %@", [ModifiedDrag modifiedDragStateDescription:_drag]);
    
    /// Disable supension
    _drag.isSuspended = NO;


    /// Handle state == none
    ///     Return immediately
    if (_drag.activationState == kMFModifiedInputActivationStateNone) return;

    /// Clear pendingCoalescableEvents
    ///     Subtle: Usually done by `processPendingCoalescableEvents()` below, but that's only called when we're `InUse`, but events are coalesced while `Initialized`, as well [Oct 2026]
    [_drag.pendingCoalescableEvents removeAllObjects];
    
    /// Handle state == In use
    ///     Notify plugin
    if (_drag.activationState == kMFModifiedInputActivationStateInUse) {

        CoalescableEvent_Deactivation *coalescableEvent = [CoalescableEvent_Deactivation new];
        coalescableEvent.cancelled = cancel;

        if (!_drag.coalesceEvents) {
            processCoalescableDeactivationEvent(coalescableEvent);
        } else {
            [_drag.pendingCoalescableEvents addObject: coalescableEvent];
            processPendingCoalescableEvents();
        }
    }
    
    /// Set state == none
    _drag.activationState = kMFModifiedInputActivationStateNone;
    
    /// Disable eventTap
    [MFEventTap enable: false forListener: kListenerID];
    
    /// Debug
    DDLogDebug("modifiedDrag disabled drag eventTap. Caller info: %@", [SharedUtility callerInfo]);
}
                   
/// Handle interference with ModifiedScroll
///     I'm not confident this is an adequate solution.
                   
//+ (void)modifiedScrollHasBeenUsed {
//    /// It's easy to accidentally drag while trying to click and scroll. And some modifiedDrag effects can interfere with modifiedScroll effects. We built this cool ModifiedDrag `suspend()` method which effectively restarts modifiedDrag. This is cool and feels nice and has a few usability benefits, but also leads to a bunch of bugs and race conditions in its current form, so were just using `deactivate()`
//    if (_drag.activationState == kMFModifiedInputActivationStateInUse) { /// This check should probably also be performed on the _drag.queue
//        [self deactivateWithCancel:YES];
//    }
//}

#pragma mark - Helper functions

/// Get rounded pointer location

static CGPoint getRoundedPointerLocation(void) {
    /// Convenience wrapper for getRoundedPointerLocationWithEvent()
    
    CGEventRef event = CGEventCreate(NULL);
    CGPoint location = getRoundedPointerLocationWithEvent(event);
    CFRelease(event);
    return location;
}
static CGPoint getRoundedPointerLocationWithEvent(CGEventRef event) {
    return getRoundedPointerLocationWithPointerLocation(CGEventGetLocation(event));
}

static CGPoint getRoundedPointerLocationWithPointerLocation(CGPoint pointerLocation) {
    /// I thought it was necessary to use this on _drag.origin to calculate the _drag.usageOrigin properly.
    /// To get the _drag.usageOrigin, I used to take the _drag.origin (which is float) and add the kCGMouseEventDeltaX and DeltaY (which are ints)
    ///     But even with rounding it didn't work properly so we went over to getting usageOrigin directly from a CGEvent. I think with this new setup there might not be a  reason to use the getRoundedPointerLocation functions anymore. But I'll just leave them in because they don't break anything.

    CGPoint pointerLocationRounded = (CGPoint){ .x = floor(pointerLocation.x), .y = floor(pointerLocation.y) };
    return pointerLocationRounded;
}


@end
