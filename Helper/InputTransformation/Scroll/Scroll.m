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
#import "SharedUtility.h"
#import "ScrollModifiers.h"

@implementation Scroll

#pragma mark - Variables - static

static CFMachPortRef _eventTap;
static CGEventSourceRef _eventSource;

static dispatch_queue_t _scrollQueue;

static PixelatedAnimator *_animator;
static SubPixelator *_subPixelator;

static AXUIElementRef _systemWideAXUIElement; // TODO: should probably move this to Config or some sort of OverrideManager class
+ (AXUIElementRef) systemWideAXUIElement {
    return _systemWideAXUIElement;
}

#pragma mark - Variables - dynamic

static MFScrollModificationResult _modifications;

#pragma mark - Public functions

+ (void)load_Manual {
    
    // Setup dispatch queue
    //  For multithreading while still retaining control over execution order.
    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, -1);
    _scrollQueue = dispatch_queue_create("com.nuebling.mac-mouse-fix.helper.scroll", attr);
    
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
    _animator = [[PixelatedAnimator alloc] init];
    
    // Create subpixelator for scroll output
    _subPixelator = [SubPixelator roundPixelator];
}

+ (void)resetDynamicGlobals {
    /// When scrolling is in progress, there are tons of variables holding global state. This resets some of them.
    /// I determined the ones it resets through trial and error. Some misbehaviour/bugs might be caused by this not resetting all of the global variables.
    
    [ScrollAnalyzer resetState];
//    [SmoothScroll resetDynamicGlobals];
}

+ (void)decide {
    /// TODO: Think about / update this
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
//        [ScrollModifiers stop];
//        [SmoothScroll stop];
//        [RoughScroll stop];
    } else {
        // Enable scroll interception
        CGEventTapEnable(_eventTap, true);
        // Enable other scroll classes
//        [ScrollModifiers start];
//        if (ScrollConfig.smoothEnabled) {
//            DDLogInfo(@"Enabling SmoothScroll");
//            [SmoothScroll start];
//            [RoughScroll stop];
//        } else {
//            DDLogInfo(@"Enabling RoughScroll");
//            [SmoothScroll stop];
//            [RoughScroll start];
//        }
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
        
        /// Debug
//        DDLogDebug(@"Ignored scroll event: (%f,%f), (%f,%f), phase: %f, %f",
//                   CGEventGetDoubleValueField(event, kCGScrollWheelEventDeltaAxis1),
//                   CGEventGetDoubleValueField(event, kCGScrollWheelEventDeltaAxis2),
//                   CGEventGetDoubleValueField(event, kCGScrollWheelEventPointDeltaAxis1),
//                   CGEventGetDoubleValueField(event, kCGScrollWheelEventPointDeltaAxis2),
//                   CGEventGetDoubleValueField(event, kCGScrollWheelEventScrollPhase),
//                   CGEventGetDoubleValueField(event, kCGScrollWheelEventMomentumPhase));
        
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
        
    // Run scrollAnalysis
    //  We want to do this here, not in _scrollQueue for more accurate timing
    
    ScrollAnalysisResult scrollAnalysisResult = [ScrollAnalyzer updateWithTickOccuringNowWithDirection:scrollDelta];
    
    //  Executing heavy stuff on a different thread to prevent the eventTap from timing out. We wrote this before knowing that you can just re-enable the eventTap when it times out. But this doesn't hurt.
    
    CGEventRef eventCopy = CGEventCreateCopy(event); // Create a copy, because the original event will become invalid and unusable in the new queue.
    
    dispatch_async(_scrollQueue, ^{
        heavyProcessing(eventCopy, scrollAnalysisResult, scrollDelta, scrollDeltaPoint, inputAxis);
    });
    
    return nil;
}

static void heavyProcessing(CGEventRef event, ScrollAnalysisResult scrollAnalysisResult, int64_t scrollDelta, int64_t scrollDeltaPoint, MFAxis inputAxis) {
    
    /// Update configuration
    ///     Checking which app is under the mouse pointer is really slow, so we only do it when necessary
    
    if (scrollAnalysisResult.consecutiveScrollTickCounter == 0) {
        
        /// Update application Overrides
        
        [ScrollUtility updateMouseDidMoveWithEvent:event];
        if (!ScrollUtility.mouseDidMove) {
            [ScrollUtility updateFrontMostAppDidChange];
            /// Only checking this if mouse didn't move, because of || in (mouseMoved || frontMostAppChanged). For optimization. Not sure if significant.
        }
        
        if (ScrollUtility.mouseDidMove || ScrollUtility.frontMostAppDidChange) {
            /// Set app overrides
            BOOL configChanged = [Config applyOverridesForAppUnderMousePointer_Force:NO]; // TODO: `updateInternalParameters_Force:` should (probably) reset stuff itself, if it changes anything. This whole [SmoothScroll stop] stuff is kinda messy
            if (configChanged) {
//                [SmoothScroll stop]; // Not sure if useful
//                [RoughScroll stop]; // Not sure if useful
                /// TODO: Reset _animator here
                /// Edit: But why?
                
            }
        }
        
        /// Update linked display
        
        if (ScrollUtility.mouseDidMove) {
            /// Update animator to currently used display
            [_animator linkToMainScreen];
        }
        
        /// Update modfications
        
        _modifications = [ScrollModifiers currentScrollModifications];
    }
    
    /// Get effective direction
    ///  -> With user settings etc. applied
    
    MFScrollDirection scrollDirection = [ScrollUtility directionForInputAxis:inputAxis inputDelta:scrollDelta invertSetting:ScrollConfig.scrollInvert horizontalModifier:(_modifications.effect == kMFScrollEffectModificationHorizontalScroll)];
    
    /// Get distance to scroll
    
    int64_t pxToScrollForThisTick = getPxPerTick(scrollAnalysisResult.timeBetweenTicks, scrollDeltaPoint);
    
    /// Apply fast scroll to distance
        
    /// Get fast scroll params
    int64_t fsThreshold = ScrollConfig.fastScrollThreshold_inSwipes;
    double fsFactor = ScrollConfig.fastScrollFactor;
    double fsBase = ScrollConfig.fastScrollExponentialBase;
    
    /// Override fast scroll params if quickScroll / preciseScroll is active
    if (_modifications.input == kMFScrollInputModificationQuick) {
        /// (Amp up fast scroll)
        fsThreshold = 1;
        fsFactor = 3.0;
        fsBase = 2.0;
    } else if (_modifications.input == kMFScrollInputModificationPrecise) {
        /// (Turn off fast scroll)
        fsThreshold = 69; /// Haha sex number
        fsFactor = 1.0;
        fsBase = 1.0;
    }
    
    /// Evaulate fast scroll
    int64_t fastScrollThresholdDelta = scrollAnalysisResult.consecutiveScrollSwipeCounter_ForFreeScrollWheel - fsThreshold;
    if (fastScrollThresholdDelta >= 0) {
        pxToScrollForThisTick *= fsFactor * pow(fsBase, fastScrollThresholdDelta);
    }
    
    /// Debug
    
    //    DDLogDebug(@"consecTicks: %lld, consecSwipes: %lld, consecSwipesFree: %lld", scrollAnalysisResult.consecutiveScrollTickCounter, scrollAnalysisResult.consecutiveScrollSwipeCounter, scrollAnalysisResult.consecutiveScrollSwipeCounter_ForFreeScrollWheel);
    
    DDLogDebug(@"timeBetweenTicks: %f, timeBetweenTicksRaw: %f, diff: %f, ticks: %lld", scrollAnalysisResult.timeBetweenTicks, scrollAnalysisResult.timeBetweenTicksRaw, scrollAnalysisResult.timeBetweenTicks - scrollAnalysisResult.timeBetweenTicksRaw, scrollAnalysisResult.consecutiveScrollTickCounter);
    
    /// Send scroll events
    
    if (pxToScrollForThisTick == 0) {
        
        DDLogWarn(@"pxToScrollForThisTick is 0");
        
    } else if (!ScrollConfig.smoothEnabled
               && !(_modifications.effect == kMFScrollEffectModificationFourFingerPinch
                    || _modifications.effect == kMFScrollEffectModificationZoom
                    || _modifications.effect == kMFScrollEffectModificationRotate)) {
        ///             ^ These modification effects simulate gestures. They need eventPhases to work properly. So they only work when when driven by the animator.
        
        /// Send scroll event directly. Will scroll all of pxToScrollForThisTick at once.
        
        sendScroll(pxToScrollForThisTick, scrollDirection, NO, kMFAnimationPhaseNone);
        
    } else {
        /// Send scroll events through animator, spread out over time.
    
        /// Get parameters for animator
        
        double animationDuration;
        Interval *animationValueInterval;
        id<AnimationCurve> animationCurve;
        
        /// Base scroll duration
        CFTimeInterval baseTimeRange;
        baseTimeRange = ((CFTimeInterval)ScrollConfig.msPerStep) / 1000.0; /// Need to cast to CFTimeInterval (double), to make this a float division instead of int division yiedling 0
//        animationDuration = scrollAnalysisResult.smoothedTimeBetweenTicks;
        
        /// Base px that the animator still wants to scroll
        double pxLeftToScroll;
        if (scrollAnalysisResult.scrollDirectionDidChange || !_animator.isRunning) {
            pxLeftToScroll = 0;
        } else {
            pxLeftToScroll = _animator.animationValueLeft;
        }
        
        if (_modifications.effect == kMFScrollEffectModificationFourFingerPinch
            || _modifications.input == kMFScrollInputModificationQuick) {
            /// Use linear curve for 4 finger pinch
            ///     because it feels much smoother
            /// Using linear for horizontal scroll
            ///     feels smoother for navigating between pages
            ///         We could not suppress natural momentum scrolling on horizontal scroll events to balance out the linear curve? But then we should probably also decrease the animationDuration... Edit: I tried it and it sucks for normal scrolling.
            
            animationDuration = baseTimeRange;
            animationValueInterval = [[Interval alloc] initWithStart:0 end:pxToScrollForThisTick + pxLeftToScroll];
            animationCurve = ScrollConfig.linearCurve;
            
        } else {
            /// Use hybrid curve
            
            /// Update pxLeftToScroll
            if (pxLeftToScroll > 0) {
                
                id c = _animator.animationCurve;
                if ([c isKindOfClass:HybridCurve.class]) {
                    pxLeftToScroll -= ((HybridCurve *)c).dragValueRange;
                    if (pxLeftToScroll < 0) pxLeftToScroll = 0;
                    /// ^ HybridCurve (and a bunch of other stuff to support it) was engineered to give us the overall distance that the Bezier *and* the DragCurve will scroll, so that the distance that would be scrolled via the Drag algorithm isn't lost here (like in older MMF versions)
                    ///     But this leads to a very strong, hard to control acceleration that also depends on the anmation time `msPerStep`. To undo this, we subtract the distance that is to be scrolled via the DragCurve back out here.
                    ///     This is inefficient because we init and calculate the drag curve on each mouse wheel tick for nothing, even if we don't need it, and just subtract the result we got from it back out here. But I don't think it makes a practical difference cause it's really fast.
                }
            }
            
            /// Base distance to scroll
            double baseValueRange = pxLeftToScroll + pxToScrollForThisTick;
            
            /// Decrease friction if fastScroll is active
            ///     Overriding params in all these different places if quickScroll is active is a little messy. Would maybe be better to have ScrollConfig return a struct with all params and to then override the values in the struct in one place.
            Bezier *baseCurve = ScrollConfig.baseCurve;
            double dragCoefficient = ScrollConfig.dragCoefficient;
            double dragExponent = ScrollConfig.dragExponent;
            
            if (_modifications.input == kMFScrollInputModificationQuick) {
//                baseCurve = ScrollConfig.linearCurve;
//                dragCoefficient = 30;
//                dragExponent = 0.8;
                
            }
            
            /// Curve
            HybridCurve *c = [[HybridCurve alloc] initWithBaseCurve:baseCurve
                                                      baseTimeRange:baseTimeRange
                                                     baseValueRange:baseValueRange
                                                    dragCoefficient:dragCoefficient
                                                       dragExponent:dragExponent
                                                          stopSpeed:ScrollConfig.stopSpeed];
            
            /// Get values for animator from hybrid curve
            animationCurve = c;
            animationDuration = c.timeRange;
            animationValueInterval = c.valueInterval;
        }
        
        /// Start animation
        
        [_animator startWithDuration:animationDuration valueInterval:animationValueInterval animationCurve:animationCurve
                     integerCallback:^(NSInteger valueDelta, double timeDelta, MFAnimationPhase animationPhase) {
            /// This will be called each frame
            
            /// Debug
            
            //            static CFTimeInterval lastTs = 0;
            //            CFTimeInterval ts = CACurrentMediaTime();
            //            DDLogInfo(@"scrollSendInterval: %@, dT: %@, dPx: %@", @(ts - lastTs), @(timeDelta), @(valueDelta));
            //            lastTs = ts;
            
            /// Test if PixelatedAnimator works properly
            
            assert(valueDelta != 0);
            //            DDLogDebug(@"DELTA: %ld, PHASE: %d", (long)valueDelta, animationPhase);
            
            /// Send scroll
            
            sendScroll(valueDelta, scrollDirection, YES, animationPhase);
            
        }];
    }
    
    CFRelease(event);
}

static int64_t getPxPerTick(CFTimeInterval timeBetweenTicks, int64_t cgEventScrollDeltaPoint) {
    /// @discussion See the RawAccel guide for more info on acceleration curves https://github.com/a1xd/rawaccel/blob/master/doc/Guide.md
    ///     -> Edit: I read up on it and I don't see why the sensitivity-based approach that RawAccel uses is useful.
    ///     They define the base curve as for sensitivity, but then go through complex maths and many hurdles to make the implied outputVelocity(inputVelocity) function and its derivative smooth. Because that is what makes the acceleration feel predictable and nice. (See their "Gain" algorithm)
    ///     Then why not just define the the outputVelocity(inputVelocity) curve to be a smooth curve to begin with? Why does sensitivity matter? It doesn't make sens to me.
    ///     I'm just gonna use a BezierCurve to define the outputVelocity(inputVelocity) curve. Then I'll extrapolate the curve linearly at the end, so its defined everywhere. That is guaranteed to be smooth and easy to configure.
    ///     Edit: Actuallyyy we ended up outputting pixels to scroll for a given tick here (so sensitivity), not speed. I don't think perfectly smooth curves are that important. This is good enough and is more easy and natural to think about and configure.
    
    AccelerationBezier *curve;
    
    if (_modifications.input == kMFScrollInputModificationPrecise) {
        curve = ScrollConfig.preciseAccelerationCurve;
    } else if (_modifications.input == kMFScrollInputModificationQuick) {
        curve = ScrollConfig.quickAccelerationCurve;
    } else if (ScrollConfig.useAppleAcceleration) {
        return llabs(cgEventScrollDeltaPoint); // Use delta from Apple's acceleration algorithm
    } else {
        curve = ScrollConfig.accelerationCurve();
    }
    
    if (timeBetweenTicks == DBL_MAX) timeBetweenTicks = ScrollConfig.consecutiveScrollTickIntervalMax;
    double scrollSpeed = 1/timeBetweenTicks; /// In tick/s
                                             ///
    double pxForThisTick = [curve evaluateAt:scrollSpeed]; /// In px/s
    
//    DDLogDebug(@"Time between ticks: %f, scrollSpeed: %f, pxForThisTick: %f", timeBetweenTicks, scrollSpeed, pxForThisTick);
    
    if (pxForThisTick <= 0) {
        DDLogError(@"pxForThisTick is smaller equal 0. This is invalid. Exiting. scrollSpeed: %f, pxForThisTick: %f", scrollSpeed, pxForThisTick);
        assert(false);
    }
    
    return pxForThisTick; /// We could use a SubPixelator balance out the rounding errors, but I don't think that'll be noticable
}

static void sendScroll(int64_t px, MFScrollDirection scrollDirection, BOOL gesture, MFAnimationPhase animationPhase) {
    /// scrollPhase is only used when `gesture` is YES
    
    if (px == 0) {
        DDLogDebug(@"Pixels to scroll are 0");
    }
    
    /// Get x and y deltas
    
    int64_t dx = 0;
    int64_t dy = 0;
    
    if (scrollDirection == kMFScrollDirectionUp) {
        dy = -px;
    } else if (scrollDirection == kMFScrollDirectionDown) {
        dy = px;
    } else if (scrollDirection == kMFScrollDirectionLeft) {
        dx = -px;
    } else if (scrollDirection == kMFScrollDirectionRight) {
        dx = px;
    } else if (scrollDirection == kMFScrollDirectionNone) {
        
    } else {
        assert(false);
    }
    
    /// Get params for sending event
    
    IOHIDEventPhaseBits deltaPhase = kIOHIDEventPhaseUndefined;
    BOOL isFinalEvent = NO;
    void (*sendEventFunction)(int64_t, int64_t, IOHIDEventPhaseBits);
    
    
    if (!gesture) {
        /// line-based scroll event
        
        deltaPhase = kIOHIDEventPhaseBegan;
        isFinalEvent = YES;
        sendEventFunction = sendLineScroll;
        
    } else {
        /// Gesture scroll events
        
        /// get deltaPhase
        
        if (animationPhase == kMFAnimationPhaseStart
            || animationPhase == kMFAnimationPhaseStartAndEnd) {
            
            deltaPhase = kIOHIDEventPhaseBegan;
            
        } else if (animationPhase == kMFAnimationPhaseRunningStart
                   || animationPhase == kMFAnimationPhaseContinue
                   || animationPhase == kMFAnimationPhaseEnd) {
            
            deltaPhase = kIOHIDEventPhaseChanged;
        } else {
            assert(false);
        }
        
        /// Get isFinalEvent
        
        if (animationPhase == kMFAnimationPhaseEnd
            || animationPhase == kMFAnimationPhaseStartAndEnd) {
            
            isFinalEvent = YES;
        }
        
        /// Get sendTouchEventFunction
        
        sendEventFunction = sendGestureScroll;
    }
    
    if (_modifications.effect == kMFScrollEffectModificationZoom) {
        sendEventFunction = sendZoomEvent;
    } else if (_modifications.effect == kMFScrollEffectModificationRotate) {
        sendEventFunction = sendRotationEvent;
    } else if (_modifications.effect == kMFScrollEffectModificationFourFingerPinch) {
        sendEventFunction = sendFourFingerPinch;
    } /// kMFScrollEffectModificationHorizontalScroll is handled above when determining scroll direction
    
    /// Debug
    
    DDLogDebug(@"Sending touch event with dx: %lld, dy: %lld, phase: %d, isFinal: %d", dx, dy, deltaPhase, isFinalEvent);
    
    /// Send event
    
    sendTouchEvent(dx, dy, deltaPhase, isFinalEvent, sendEventFunction);
}

/// Generic touch sending func

static void sendTouchEvent(int64_t dx, int64_t dy, IOHIDEventPhaseBits deltaPhase, BOOL isFinalEvent, void (*sendTouchEventFunction)(int64_t, int64_t, IOHIDEventPhaseBits)) {
    
    assert(deltaPhase == kIOHIDEventPhaseBegan || deltaPhase == kIOHIDEventPhaseChanged);
    
//    if (isFinalEvent) deltaPhase = kIOHIDEventPhaseEnded; /// Debug
    
    sendTouchEventFunction(dx, dy, deltaPhase);
    
    if (isFinalEvent) {
        /// The "end" event in touch events usually signals the user lifting off their fingers and has a 0,0 delta. The events that our scrolling engine produces have non-zero deltas on their final events events. That's why we need to send this extra event
        sendTouchEventFunction(0, 0, kIOHIDEventPhaseEnded);
    }
    
}

/// Specific touch sending functions
///     That plug into `sendTouchEvent`

static void sendGestureScroll(int64_t dx, int64_t dy, IOHIDEventPhaseBits eventPhase) {
    /// Send simulated two-finger swipe event
    
    [GestureScrollSimulator postGestureScrollEventWithDeltaX:dx deltaY:dy phase:eventPhase];
    
    if (_modifications.input == kMFScrollInputModificationQuick) {
        /// Don't suppress natural momentum scroll if quickScroll is active
        ///     Overriding params in all these different places if quickScroll is active is a little messy. Would maybe be better to have ScrollConfig return a struct with all params and to then override the values in the struct in one place.
        return;
    }
    
    /// Suppress natural momentumScroll and GestureScrollSimulator's momentumScroll
    if (eventPhase == kIOHIDEventPhaseEnded) {
        [GestureScrollSimulator stopMomentumScroll];
    }
}

static void sendZoomEvent(int64_t dx, int64_t dy, IOHIDEventPhaseBits eventPhase) {
    /// Send zoom event
    ///  This doesn't need subpixelation, so we could subpixelate after this instead of before (in sendScroll())
    
    double anyAxisDelta = dx + dy; /// This works because, if dx != 0 -> dy == 0, and the other way around.
    double eventDelta = anyAxisDelta/800.0;
    
    [TouchSimulator postMagnificationEventWithMagnification:eventDelta phase:eventPhase];
    
    DDLogDebug(@"Sent zoom event with delta: %f, phase: %d", eventDelta, eventPhase);
}
static void sendRotationEvent(int64_t dx, int64_t dy, IOHIDEventPhaseBits eventPhase) {
    /// Send zoom event
    ///  This doesn't need subpixelation, so we could subpixelate after this instead of before (in sendScroll())
    
    double anyAxisDelta = dx + dy; /// This works because, if dx != 0 -> dy == 0, and the other way around.
    double eventDelta = anyAxisDelta/50.0;
    
    [TouchSimulator postRotationEventWithRotation:eventDelta phase:eventPhase];
}

static void sendFourFingerPinch(int64_t dx, int64_t dy, IOHIDEventPhaseBits eventPhase) {
    /// Send 4 finger pinch event - used to access Launchpad or show desktop
    
    double anyAxisDelta = dx + dy;
    double eventDelta = anyAxisDelta/600.0;
    /// ^ Launchpad feels a lot less sensitive than Show Desktop, but to improve this we'd have to somehow detect which of both is active atm
    eventDelta = -eventDelta;
    /// ^ Flip delta to mirror the way that zooming works
    
    [TouchSimulator postDockSwipeEventWithDelta:eventDelta type:kMFDockSwipeTypePinch phase:eventPhase];
    
    if (eventPhase == kIOHIDEventPhaseEnded) {
        /// Dock swipes will sometimes get stuck when the computer is slow. This can be solved by sending several "end" events in a row with a delay (see "stuck bug" in ModifiedDrag)
        ///     Edit: Even with sending the event again after 0.2 seconds, the stuck bug still happens a bunch here for some reason. Event though this almost completely eliminates the bug in ModifiedDrag.
        ///         Hopefully, sending it again after 0.5 seconds works... Edit: Yes, seems to work better but still sometimes happens
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypePinch phase:kIOHIDEventPhaseEnded];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [TouchSimulator postDockSwipeEventWithDelta:0.0 type:kMFDockSwipeTypePinch phase:kIOHIDEventPhaseEnded];
        });
        
    }
    
}

static void sendLineScroll(int64_t dx, int64_t dy, IOHIDEventPhaseBits eventPhase) {
    /// Send line-based scroll event
    ///     We ignore the `eventPhase` argument
    
    /// TODO: line delta should always be around 1/10 of pixel delta. Also subpixelate line delta.
    ///     See CGEventSource pixelsPerLine - it's 10.
    
    CGEventRef event = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 1, 0);
    
    int64_t dyLine;
    int64_t dxLine;
    
    /// Make line deltas 1/10 or pixel deltas
    dyLine = round(dy / 10);
    dxLine = round(dx / 10);
    
    /// Make line deltas always 1, 0, or -1. These values are probably too small. We should study what these values should be more
//    if (dy != 0) dyLine = dy / llabs(dy);
//    if (dx != 0) dxLine = dx / llabs(dx);
    
    CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, dyLine);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, dy);
    CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, dy);
    
    CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2, dxLine);
    CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis2, dx);
    CGEventSetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis2, dx);
    
    CGEventPost(kCGSessionEventTap, event);
}


@end
