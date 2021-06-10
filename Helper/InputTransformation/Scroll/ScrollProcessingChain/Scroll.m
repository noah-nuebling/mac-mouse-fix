//
// --------------------------------------------------------------------------
// ScrollControl.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Scroll.h"
#import "DeviceManager.h"
#import "SmoothScroll.h"
#import "RoughScroll.h"
#import "TouchSimulator.h"
#import "ScrollModifiers.h"
#import "Config.h"
#import "ScrollUtility.h"
#import "Utility_Helper.h"
#import "WannabePrefixHeader.h"
#import "ScrollAnalyzer.h"
#import "ScrollConfigObjC.h"
#import <Cocoa/Cocoa.h>
#import "Queue.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "SubPixelator.h"
#import "GestureScrollSimulator.h"

@implementation Scroll

#pragma mark - Variables

static CFMachPortRef _eventTap;
static CGEventSourceRef _eventSource;

static dispatch_queue_t _scrollQueue;

static Animator *_animator;
static SubPixelator *_subPixelator;

static AXUIElementRef _systemWideAXUIElement; // TODO: should probably move this to Config or some sort of OverrideManager class
+ (AXUIElementRef) systemWideAXUIElement {
    return _systemWideAXUIElement;
}

#pragma mark - Public functions

+ (void)load_Manual {
    
    // Load SmoothScroll
    [SmoothScroll load_Manual];
    
    // Setup dispatch queue
    //  For multithreading while still retaining control over execution order.
    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, -1);
    _scrollQueue = dispatch_queue_create(NULL, attr);
    
    // Create AXUIElement for getting app under mouse pointer
    _systemWideAXUIElement = AXUIElementCreateSystemWide();
    // Create Event source
    if (_eventSource == nil) {
        _eventSource = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    }
    
    // Create/enable scrollwheel input callback
    if (_eventTap == nil) {
        CGEventMask mask = CGEventMaskBit(kCGEventScrollWheel);
        _eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, eventTapCallback, NULL);
        DDLogDebug(@"_eventTap: %@", _eventTap);
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        CGEventTapEnable(_eventTap, false); // Not sure if this does anything
    }
    
    // Create animator
    _animator = [[Animator alloc] init];
    
    // Create subpixelator for scroll output
    _subPixelator = [SubPixelator pixelator] ;
}

+ (void)resetDynamicGlobals {
    /// When scrolling is in progress, there are tons of variables holding global state. This resets some of them.
    /// I determined the ones it resets through trial and error. Some misbehaviour/bugs might be caused by this not resetting all of the global variables.
    
    [ScrollAnalyzer resetState];
    [SmoothScroll resetDynamicGlobals];
}

+ (void)rerouteScrollEventToTop:(CGEventRef)event {
    /// Routes the event back to the eventTap where it originally entered the program.
    ///
    /// Use this when internal parameters change while processing an event.
    /// This will essentially restart the evaluation of the event while respecting the new internal parameters.
    /// You probably wanna return after calliing this.
    // TODO: This shouldn't be neede anymore. Delete if so.
    
    eventTapCallback(nil, 0, event, nil);
}

+ (void)decide {
    /// Either activate SmoothScroll or RoughScroll or stop scroll interception entirely
    /// Call this whenever a value which the decision depends on changes
    
    BOOL disableAll =
    ![DeviceManager devicesAreAttached];
    //|| (!_isSmoothEnabled && _scrollDirection == 1);
//    || isEnabled == NO;
    
    if (disableAll) {
        DDLogInfo(@"Disabling scroll interception");
        // Disable scroll interception
        if (_eventTap) {
            CGEventTapEnable(_eventTap, false);
        }
        // Disable other scroll classes
        [SmoothScroll stop];
        [RoughScroll stop];
        [ScrollModifiers stop];
    } else {
        // Enable scroll interception
        CGEventTapEnable(_eventTap, true);
        // Enable other scroll classes
        [ScrollModifiers start];
        if (ScrollConfig.smoothEnabled) {
            DDLogInfo(@"Enabling SmoothScroll");
            [SmoothScroll start];
            [RoughScroll stop];
        } else {
            DDLogInfo(@"Enabling RoughScroll");
            [SmoothScroll stop];
            [RoughScroll start];
        }
    }
}

#pragma mark - Private functions

static CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    /// Handle eventTapDisabled messages
    
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        
        if (type == kCGEventTapDisabledByUserInput) {
            DDLogInfo(@"ScrollControl eventTap was disabled by timeout. Re-enabling");
            CGEventTapEnable(_eventTap, true);
        } else if (type == kCGEventTapDisabledByUserInput) {
            DDLogInfo(@"ScrollControl eventTap was disabled by user input.");
        }
        
        return event;
    }
    
    /// Return non-scrollwheel events unaltered
    
    int64_t isPixelBased     = CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous);
    int64_t scrollPhase      = CGEventGetIntegerValueField(event, kCGScrollWheelEventScrollPhase);
    int64_t scrollDeltaAxis1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    int64_t scrollDeltaAxis2 = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
    bool isDiagonal = scrollDeltaAxis1 != 0 && scrollDeltaAxis2 != 0;
    if (isPixelBased != 0
        || scrollPhase != 0 // Adding scrollphase here is untested
        || isDiagonal) { // Ignore diagonal scroll-events
        return event;
    }
    
    // Get axis
    
    MFAxis inputAxis = [ScrollUtility axisForVerticalDelta:scrollDeltaAxis1 horizontalDelta:scrollDeltaAxis2];
    
    // Get scrollDelta
    
    int64_t scrollDelta = 0; // Only initing this to 0 to silence Xcode warnings
    int64_t scrollDeltaPoint = 0;
    
    if (inputAxis == kMFAxisVertical) {
        scrollDelta = scrollDeltaAxis1;
        scrollDeltaPoint = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
    } else if (inputAxis == kMFAxisHorizontal) {
        scrollDelta = scrollDeltaAxis2;
        scrollDeltaPoint = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2);
    } else {
        NSCAssert(NO, @"Invalid scroll axis");
    }
    
    // Get effective direction
    //  -> With user settings etc. applied
    
    MFScrollDirection scrollDirection = [ScrollUtility directionForInputAxis:inputAxis inputDelta:scrollDelta invertSetting:ScrollConfig.scrollInvert horizontalModifier:ScrollModifiers.horizontalScrolling];
    
    // Run scrollAnalysis
    //  We want to do this here, not in _scrollQueue for more accurate timing
    
    ScrollAnalysisResult scrollAnalysisResult = [ScrollAnalyzer updateWithTickOccuringNowWithDirection:scrollDirection];
    
    //  Executing heavy stuff on a different thread to prevent the eventTap from timing out. We wrote this before knowing that you can just re-enable the eventTap when it times out. But this doesn't hurt.
    
    CGEventRef eventCopy = CGEventCreateCopy(event); // Create a copy, because the original event will become invalid and unusable in the new queue.
    
    dispatch_async(_scrollQueue, ^{
        
        heavyProcessing(eventCopy, scrollAnalysisResult, scrollDirection);
    });
    
    return nil;
}

static void heavyProcessing(CGEventRef event, ScrollAnalysisResult scrollAnalysisResult, MFScrollDirection scrollDirection) {
    
    /// Update configuration
///         Checking which app is under the mouse pointer is really slow, so we only do it when necessary
    
    if (scrollAnalysisResult.consecutiveScrollTickCounter == 0) {
        
        [ScrollUtility updateMouseDidMoveWithEvent:event];
        if (!ScrollUtility.mouseDidMove) {
            [ScrollUtility updateFrontMostAppDidChange];
            /// Only checking this if mouse didn't move, because of || in (mouseMoved || frontMostAppChanged). For optimization. Not sure if significant.
        }
        
        if (ScrollUtility.mouseDidMove || ScrollUtility.frontMostAppDidChange) {
            /// Set app overrides
            BOOL configChanged = [Config applyOverridesForAppUnderMousePointer_Force:NO]; // TODO: `updateInternalParameters_Force:` should (probably) reset stuff itself, if it changes anything. This whole [SmoothScroll stop] stuff is kinda messy
            if (configChanged) {
                [SmoothScroll stop]; // Not sure if useful
                [RoughScroll stop]; // Not sure if useful
                /// TODO: Reset _animator here
            }
        }
        if (ScrollUtility.mouseDidMove) {
            /// Update animator to currently used display
            [_animator linkToMainScreen];
        }
    }
    
    /// Get distance to scroll
    
    int64_t pxToScrollForThisTick = getPxPerTick(scrollAnalysisResult.smoothedTimeBetweenTicks);
    
    /// Apply fast scroll to distance
    
    int64_t fastScrollThresholdDelta = scrollAnalysisResult.consecutiveScrollSwipeCounter - (unsigned int)ScrollConfig.fastScrollThreshold_inSwipes;
    if (fastScrollThresholdDelta >= 0) {
        pxToScrollForThisTick *= ScrollConfig.fastScrollFactor * pow(ScrollConfig.fastScrollExponentialBase, ((int32_t)fastScrollThresholdDelta)); /// TODO: Tune this up a little
    }
    
    if (pxToScrollForThisTick == 0) {
        
        DDLogWarn(@"px to scroll for this tick is 0");
        
    } else if (!ScrollConfig.smoothEnabled) {
        /// Send scroll event directly. Will scroll all of pxToScrollForThisTick at once.
        
        sendScroll(pxToScrollForThisTick, scrollDirection, NO, 0);
        
    } else {
        /// Send scroll events through animator, spread out over time.
    
        /// Get parameters for animator
        
        /// Duration
        CFTimeInterval animationDuration = ((CFTimeInterval)ScrollConfig.msPerStep) / 1000.0; /// Need to cast to CFTimeInterval (double), to make this a float division instead of int division, yiedling 0
        
        /// Animation interval
        double pxLeftToScroll;
        if (scrollAnalysisResult.scrollDirectionDidChange) {
            pxLeftToScroll = 0;
        } else {
            pxLeftToScroll = _animator.animationValueLeft;
        }
        Interval *animationValueInterval = [[Interval alloc] initWithStart:0 end:(pxToScrollForThisTick + pxLeftToScroll)];
        
        /// Curve
        id<RealFunction> animationCurve = ScrollConfig.animationCurve;
        
        /// Debug
//        DDLogDebug(@"animationDuration: %@, animationValueInterval: %@", @(animationDuration), animationValueInterval);
        
        
        /// Start animation
        [_animator startWithDuration:animationDuration valueInterval:animationValueInterval animationCurve:animationCurve
                            callback:^(double valueDelta, double timeDelta, MFAnimationPhase animationPhase) {
            /// This will be called each frame
            
            /// Get phase
            
            IOHIDEventPhaseBits scrollPhase;
            
            if (animationPhase == kMFAnimationPhaseStart) {
                scrollPhase = kIOHIDEventPhaseBegan;
            } else if (animationPhase == kMFAnimationPhaseRunningStart || animationPhase == kMFAnimationPhaseContinue) {
                scrollPhase = kIOHIDEventPhaseChanged;
            } else if (animationPhase == kMFAnimationPhaseEnd) {
                scrollPhase = kIOHIDEventPhaseEnded;
            } else {
                assert(false);
            }
            
            /// Scroll
            
            sendScroll(valueDelta, scrollDirection, YES, scrollPhase);
        }];
    }
    
    CFRelease(event);
}

static int64_t getPxPerTick(CFTimeInterval timeBetweenTicks) {
    /// @discussion See the RawAccel guide for more info on acceleration curves https://github.com/a1xd/rawaccel/blob/master/doc/Guide.md
    ///     -> Edit: I read up on it and I don't see why the sensitivity-based approach that RawAccel uses is useful.
    ///     They define the base curve as for sensitivity, but then go through complex maths and many hurdles to make the implied outputVelocity(inputVelocity) function and its derivative smooth. Because that is what makes the acceleration feel predictable and nice. (See their "Gain" algorithm)
    ///     Then why not just define the the outputVelocity(inputVelocity) curve to be a smooth curve to begin with? Why does sensitivity matter? It doesn't make sens to me.
    ///     I'm just gonna use a BezierCurve to define the outputVelocity(inputVelocity) curve. Then I'll extrapolate the curve linearly at the end, so its defined everywhere. That is guaranteed to be smooth and easy to configure.
    
    double scrollSpeed = 1/timeBetweenTicks; /// In tick/s
    
    double animationSpeed = [ScrollConfig.accelerationCurve() evaluateAt:scrollSpeed]; /// In px/s
    
    double scaling = animationSpeed / scrollSpeed; /// In px/tick
    
    return 40; /// We could use a SubPixelator balance out the rounding errors, but I don't think that'll be noticable
}

static void sendScroll(double px, MFScrollDirection scrollDirection, BOOL gesture, IOHIDEventPhaseBits scrollPhase) {
    /// scrollPhase is only used when `gesture` is YES
    
    /// Subpixelate px to balance out rounding errors
    
    int64_t pxToScrollThisFrame = [_subPixelator intDeltaWithDoubleDelta:px];
    
    /// Get x and y deltas
    
    double dx = 0;
    double dy = 0;
    
    if (scrollDirection == kMFScrollDirectionUp) {
        dy = -px;
    } else if (scrollDirection == kMFScrollDirectionDown) {
        dy = px;
    } else if (scrollDirection == kMFScrollDirectionLeft) {
        dx = -px;
    } else if (scrollDirection == kMFScrollDirectionRight) {
        dx = px;
    } else {
        assert(false);
    }
    
    if (ScrollModifiers.magnificationScrolling) {
        /// Send zoom event
        ///  This doesn't need subpixelation, so we could subpixelate after this instead of before
        
        double anyAxisDelta = dx + dy; /// This works because, if dx != 0 -> dy == 0, and the other way around.
        
        [ScrollModifiers handleMagnificationScrollWithAmount:anyAxisDelta/800.0];
        
    } else if (!gesture) {
        /// Send line-based scroll event
        
        CGEventRef event = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitLine, 1, 0);
        
        CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, dy / fabs(dy)); /// Always 1, 0, or -1. These values are probably too small. We should study what these values should be more
        CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, dy);
        CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, dy);
        
        CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, dx / fabs(dx));
        CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, dx);
        CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, dx);
        
        CGEventPost(kCGSessionEventTap, event);
        
    } else {
        /// Send simulated two-finger swipe event
        
        [GestureScrollSimulator postGestureScrollEventWithDeltaX:dx deltaY:dy phase:scrollPhase isGestureDelta:NO];
        
        if (scrollPhase == kIOHIDEventPhaseEnded) { /// Hack to prevent momentum scroll. Should finds a better solution
            [GestureScrollSimulator postGestureScrollEventWithDeltaX:dx/fabs(dx) deltaY:dy/fabs(dy) phase:kIOHIDEventPhaseEnded isGestureDelta:NO];
        }
    }
}


@end
