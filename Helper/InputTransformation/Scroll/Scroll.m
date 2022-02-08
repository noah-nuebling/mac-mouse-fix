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
#import "HelperUtility.h"
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
#import "Actions.h"

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

+ (void)resetState {
    /// This is untested
    
    [_animator stop];
    [GestureScrollSimulator stopMomentumScroll];
    [ScrollAnalyzer resetState];
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
            BOOL configChanged = [Config applyOverridesForAppUnderMousePointer_Force:NO];
            if (configChanged) {
                [Scroll resetState];
                /// TODO: Test if this works
                /// TODO: `applyOverridesForAppUnderMousePointer_Force:` should (probably) reset stuff itself, if it changes anything. This whole [SmoothScroll stop] stuff is kinda messy
                
            }
        }
        
        /// Update linked display
        
        if (ScrollUtility.mouseDidMove) {
            /// Update animator to currently used display
            [_animator linkToMainScreen];
        }
        
        /// Update modfications
        
        _modifications = [ScrollModifiers currentScrollModificationsWithEvent:event];
    }
    
    /// Get effective direction
    ///  -> With user settings etc. applied
    
    MFScrollDirection scrollDirection = [ScrollUtility directionForInputAxis:inputAxis inputDelta:scrollDelta invertSetting:[ScrollConfig scrollInvertWithEvent:event] horizontalModifier:(_modifications.effect == kMFScrollEffectModificationHorizontalScroll)];
    
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
        
    } else if ((_modifications.effect == kMFScrollEffectModificationCommandTab)
               || (!ScrollConfig.smoothEnabled
                   && !(_modifications.effect == kMFScrollEffectModificationFourFingerPinch
                        || _modifications.effect == kMFScrollEffectModificationZoom
                        || _modifications.effect == kMFScrollEffectModificationRotate
                        || _modifications.effect == kMFScrollEffectModificationThreeFingerSwipeHorizontal))) {
        ///                 ^ These modification effects simulate gestures. They need eventPhases to work properly. So they only work when when driven by the animator.
        
        /// Send scroll event directly - without the animator. Will scroll all of pxToScrollForThisTick at once.
        
        sendScroll(pxToScrollForThisTick, scrollDirection, NO, kMFAnimationPhaseNone);
        
    } else {
        /// Send scroll events through animator, spread out over time.
        
        /// Start animation
        
        [_animator startWithParams:^NSDictionary<NSString *,id> * _Nonnull(double valueLeft, BOOL isRunning, id<AnimationCurve> animationCurve) {
            
            /// Declare result dict (animator start params)
            
            NSMutableDictionary *p = [NSMutableDictionary dictionary];
            
            /// Get base scroll duration
            CFTimeInterval baseTimeRange = ((CFTimeInterval)ScrollConfig.msPerStep) / 1000.0; /// Need to cast to CFTimeInterval (double), to make this a float division
            
            /// Get px that the animator still wants to scroll
            double pxLeftToScroll;
            if (scrollAnalysisResult.scrollDirectionDidChange || !isRunning) {
                pxLeftToScroll = 0;
            } else {
                pxLeftToScroll = valueLeft;
            }
            
            if (_modifications.effect == kMFScrollEffectModificationFourFingerPinch
                || _modifications.effect == kMFScrollEffectModificationThreeFingerSwipeHorizontal
                || _modifications.input == kMFScrollInputModificationQuick) {

                /// Use linear curve for 4 finger pinch and 3 finger swipe
                ///     because it feels much smoother
                /// Using linear for horizontal scroll
                ///     feels smoother for navigating between pages
                ///         We could not suppress natural momentum scrolling on horizontal scroll events to balance out the linear curve? But then we should probably also decrease the animationDuration... Edit: I tried it and it sucks for normal scrolling.
                
                p[@"duration"] = @(baseTimeRange);
                p[@"value"] = @(pxToScrollForThisTick + pxLeftToScroll);
                p[@"curve"] = ScrollConfig.linearCurve;
                
                return p;
                
            } else {
                /// Use hybrid curve
                
                /// Update pxLeftToScroll
                if (pxLeftToScroll > 0) {
                    
                    id c = animationCurve;
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
                p[@"duration"] = @(c.timeRange);
                p[@"value"]  = @(c.valueRange);
                p[@"curve"]  = c;
            }
            
            return p;
            
        } integerCallback:^(NSInteger valueDelta, double timeDelta, MFAnimationPhase animationPhase) {
         
         /// This will be called each frame
            
            /// Debug
            
//            static CFTimeInterval lastTs = 0;
//            CFTimeInterval ts = CACurrentMediaTime();
//            DDLogInfo(@"scrollSendInterval: %@, dT: %@, dPx: %@", @(ts - lastTs), @(timeDelta), @(valueDelta));
//            lastTs = ts;
//            DDLogDebug(@"DELTA: %ld, PHASE: %d", (long)valueDelta, animationPhase);
            
            /// Test if PixelatedAnimator works properly
            assert(valueDelta != 0);
            
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
    
//    IOHIDEventPhaseBits deltaPhase = kIOHIDEventPhaseUndefined;
    BOOL isFirstEvent;
    BOOL isFinalEvent;
    MFScrollOutputType outputType;
    
    
    if (!gesture) {
        /// line-based scroll event
        
        isFirstEvent = YES;
        isFinalEvent = YES;
        outputType = kMFScrollOutputTypeLineScroll;
        
    } else {
        /// Gesture scroll events
        
        /// Get isFirst
        
        if (animationPhase == kMFAnimationPhaseStart
            || animationPhase == kMFAnimationPhaseStartAndEnd) {
            
            isFirstEvent = YES;
            
        } else if (animationPhase == kMFAnimationPhaseRunningStart
                   || animationPhase == kMFAnimationPhaseContinue
                   || animationPhase == kMFAnimationPhaseEnd) {
            
            isFirstEvent = NO;
            
        } else {
            assert(false);
        }
        
        /// Get isFinal
        
        if (animationPhase == kMFAnimationPhaseEnd
            || animationPhase == kMFAnimationPhaseStartAndEnd) {
            
            isFinalEvent = YES;
        } else {
            isFinalEvent = NO;
        }
        
        /// Get outputType
        
        outputType = kMFScrollOutputTypeGestureScroll;
    }
    
    /// TODO: Is a third set of constants for the same thing (?) really necessary??
    if (_modifications.effect == kMFScrollEffectModificationZoom) {
        outputType = kMFScrollOutputTypeZoom;
    } else if (_modifications.effect == kMFScrollEffectModificationRotate) {
        outputType = kMFScrollOutputTypeRotation;
    } else if (_modifications.effect == kMFScrollEffectModificationFourFingerPinch) {
        outputType = kMFScrollOutputTypeFourFingerPinch;
    } else if (_modifications.effect == kMFScrollEffectModificationCommandTab) {
        outputType = kMFScrollOutputTypeCommandTab;
    } else if (_modifications.effect == kMFScrollEffectModificationThreeFingerSwipeHorizontal) {
        outputType = kMFScrollOutputTypeThreeFingerSwipeHorizontal;
    } /// kMFScrollEffectModificationHorizontalScroll is handled above when determining scroll direction
    
    /// Debug
    
    DDLogDebug(@"Sending touch event with dx: %lld, dy: %lld, isFirst: %d, isFinal: %d", dx, dy, isFirstEvent, isFinalEvent);
    
    /// Send event
    
    sendOutputEvents(dx, dy, isFirstEvent, isFinalEvent, outputType);
}

/// Define output types

typedef enum {
    kMFScrollOutputTypeGestureScroll,
    kMFScrollOutputTypeFourFingerPinch,
    kMFScrollOutputTypeThreeFingerSwipeHorizontal,
    kMFScrollOutputTypeZoom,
    kMFScrollOutputTypeRotation,
    kMFScrollOutputTypeCommandTab,
    kMFScrollOutputTypeLineScroll,
} MFScrollOutputType;

/// Output

static void sendOutputEvents(int64_t dx, int64_t dy, BOOL isFirstEvent, BOOL isFinalEvent, MFScrollOutputType outputType) {
    
    /// Init eventPhase
    
    IOHIDEventPhaseBits eventPhase = isFirstEvent ? kIOHIDEventPhaseBegan : kIOHIDEventPhaseChanged;
    
    /// Send events based on outputType
    
    if (outputType == kMFScrollOutputTypeGestureScroll) {
        
        /// --- GestureScroll ---
        
        if (_modifications.input == kMFScrollInputModificationQuick) {
            
            /// QuickScroll is active
            
            /// When quick scroll is active, we don't want to suppress natural momentum scroll (which `kMFScrollOutputTypeGestureScroll()` does), so we're sending the events directly instead of calling kMFScrollOutputTypeGestureScroll in that case
            ///     For momentumScroll to work properly in certain apps like Xcode which implement their own momentumScroll algorithm, there are the following problems that would occur if we used kMFScrollOutputTypeGestureScroll but just turned off the momentumScroll suppression
            ///         1. The delta of the last event before the kIOHIDEventPhaseEnded event seems to determine how fast the momentum scroll will be in apps like Xcode.
            ///             -> Since this is driven by a PixelatedAnimator the last delta will almost always be much smaller than the rest, leading momentum scroll to be too slow.
            ///         2. If the time between the kIOHIDEventPhaseEnded event and the previous one is very small, there will be a stuttery jump at the start of the momentumScroll
            ///             -> The default touchEventSending code (below) sends the kIOHIDEventPhaseEnded event immediately after the last delta event which leads to a very exagerated stuttery jump
            ///     To fix these two issues we simply ignore the deltas on the final event and set its phase to kIOHIDEventPhaseEnded (kIOHIDEventPhaseEnded can't have deltas (at least on the touch events we've observed), because they signal the user lifting off their fingers). Ignoring the final deltas is not ideal but this is the simplest and most robust solution I can come up with.
            ///
            ///     When sending zoom events, it also seems to cause problems (I saw them in Maps) if the `end` event is posted immediately after the last delta event. So we're cutting off the last delta event and sending and `end` event instead
            ///
            ///     Notes:
            ///     - It might also be more ideal to have the last event before the kIOHIDEventPhaseEnded event have the smoothed delta that we use to start our custom momentumScroll in [GestureScrollSimulator postGestureScrollEventWithDeltaX:]. This would create greater consistency between apps that use our momentumScroll algorithm like Safari and apps that have their own like Xcode.
            ///     - We could also maybe turn off the smoothing in GestureScrollSimulator, because it doesn't work for apps with their own momentumScroll algorithm anyways. Instead we could base the initial speed of our own momentumScroll algorithm solely on the last event delta and the time between that event and the kIOHIDEventPhaseEnded event, just like the Xcode momentumScroll apparently does. And then we'd have to make sure to drive the GestureSimulator such that those values are reasonable. (Like we're doing now anyways because that's necessary for apps that implement their own momentumScroll)
            ///     - We're pretty much the same thing in ModifiedDrag to drive the [GestureScrollSimulator postGestureScrollEventWithDeltaX:]. Maybeee it would be smart to abstract this behaviour away if we end up using it more. But for now this works.
            
            if (isFinalEvent) {
                dx = 0;
                dy = 0;
                eventPhase = kIOHIDEventPhaseEnded;
            }
            
            [GestureScrollSimulator postGestureScrollEventWithDeltaX:dx deltaY:dy phase:eventPhase];
            
        } else {
            
            /// Default (QuickScroll is *not* active)
            
            [GestureScrollSimulator postGestureScrollEventWithDeltaX:dx deltaY:dy phase:eventPhase];
            
            /// Suppress natural momentumScroll and GestureScrollSimulator's momentumScroll
            if (isFinalEvent) {
                
                [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase: kIOHIDEventPhaseEnded];
                [GestureScrollSimulator stopMomentumScroll];
            }
            
        }
        
    } else if (outputType == kMFScrollOutputTypeZoom) {
        
        /// --- Zoom ---
        
        double eventDelta;
        
        if (isFinalEvent) {
            
            /// When sending zoom events, it  seems to cause problems if the `end` event is posted immediately after the last delta event. (In Maps it would abruptly  jump to a different zoom level sometimes) So we're cutting off the final delta event and sending and `end` event with zero deltas instead - to preserve time gap between the last delta event and the `end` event.
            
            eventDelta = 0;
            eventPhase = kIOHIDEventPhaseEnded;
        } else {
            eventDelta = (dx + dy)/800.0; /// This works because, if dx != 0 -> dy == 0, and the other way around.
        }
        
        [TouchSimulator postMagnificationEventWithMagnification:eventDelta phase:eventPhase];
        
        
        
    } else if (outputType == kMFScrollOutputTypeRotation) {
        
        /// --- Rotation ---
        
        double eventDelta = (dx + dy)/8.0; /// This works because, if dx != 0 -> dy == 0, and the other way around.
        
        [TouchSimulator postRotationEventWithRotation:eventDelta phase:eventPhase];
        
        if (isFinalEvent) {
            [TouchSimulator postRotationEventWithRotation:0 phase:kIOHIDEventPhaseEnded];
        }
        
    } else if (outputType == kMFScrollOutputTypeFourFingerPinch
               || outputType == kMFScrollOutputTypeThreeFingerSwipeHorizontal) {
        
        /// --- FourFingerPinch or ThreeFingerSwipeHorizontal ---
        ///         ^ Used to access Launchpad or show desktop
        ///                           ^ Used to switch Spaces
        
        MFDockSwipeType type;
        double eventDelta;
        
        if (outputType == kMFScrollOutputTypeFourFingerPinch) {
            type = kMFDockSwipeTypePinch;
            eventDelta = -(dx + dy)/600.0;
            /// ^ Launchpad feels a lot less sensitive than Show Desktop, but to improve this we'd have to somehow detect which of both is active atm. Negate delta to mirror the way that zooming works
        } else if (outputType == kMFScrollOutputTypeThreeFingerSwipeHorizontal) {
            type = kMFDockSwipeTypeHorizontal;
            eventDelta = -(dx + dy)/600.0;
        } else {
            assert(false);
        }
        
        [TouchSimulator postDockSwipeEventWithDelta:eventDelta type:type phase:eventPhase];
        
        if (isFinalEvent) {
            
            [TouchSimulator postDockSwipeEventWithDelta:0.0 type:type phase:kIOHIDEventPhaseEnded];
            
            /// v Dock swipes will sometimes get stuck when the computer is slow. This can be solved by sending several "end" events in a row with a delay (see "stuck bug" in ModifiedDrag)
            ///     Edit: Even with sending the event again after 0.2 seconds, the stuck bug still happens a bunch here for some reason. Event though this almost completely eliminates the bug in ModifiedDrag.
            ///         Hopefully, sending it again after 0.5 seconds works... Edit: Yes, seems to work better but still sometimes happens
            ///   Edit2: I don't experience the stuck bug anymore here. I'm on an M1 now, maybe that's it.
            ///     TODO: I should probably move the "sending several end events" code to the postDockSwipeEventWithDelta: function, because otherwise there might be interference when the scroll engine and the drag engine try to send those 'end' events at the same time. We also need further safety measures if several sources try to use postDockSwipeEventWithDelta: at the same time.
            ///     TODO: We should probably change the "sending several end events" code in ModifiedDrag over to using timers that we can invalidate like here - We should do this to avoid too many 'end' events being sent from old timers.
            
            static NSTimer *timer1;
            static NSTimer *timer2;
            
            [timer1 invalidate];
            [timer2 invalidate];
            
            double zero = 0.0;
            
            IOHIDEventPhaseBits iohidPhase = kIOHIDEventPhaseEnded;
            
            SEL selector = @selector(postDockSwipeEventWithDelta:type:phase:);
            NSMethodSignature *signature = [TouchSimulator methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            invocation.target = TouchSimulator.class;
            invocation.selector = selector;
            [invocation setArgument:&zero atIndex:2];
            [invocation setArgument:&type atIndex:3];
            [invocation setArgument:&iohidPhase atIndex:4];
            
            timer1 = [NSTimer scheduledTimerWithTimeInterval:0.2 invocation:invocation repeats:NO];
            timer2 = [NSTimer scheduledTimerWithTimeInterval:0.5 invocation:invocation repeats:NO];
            
        }
        
    } else if (outputType == kMFScrollOutputTypeCommandTab) {
        
        double d = -(dx + dy);
        assert (d != 0);
        
        /// Send events
        
        if (!_appSwitcherIsOpen) {
            /// Send command down event
            sendKeyEvent(55, kCGEventFlagMaskCommand, true);
            _appSwitcherIsOpen = YES;
            
        }
        
        /// Send tab down and up events
        
        if (d > 0) {
            sendKeyEvent(48, kCGEventFlagMaskCommand, true);
            sendKeyEvent(48, kCGEventFlagMaskCommand, false);
        } else {
            sendKeyEvent(48, kCGEventFlagMaskCommand | kCGEventFlagMaskShift, true);
            sendKeyEvent(48, kCGEventFlagMaskCommand | kCGEventFlagMaskShift, false);
        }

        
    } else if (outputType == kMFScrollOutputTypeLineScroll) {
        
        /// --- LineScroll ---
        
        /// We ignore the phases and isFinalEvent here, they don't matter
        
        /// TODO: line delta should always be around 1/10 of pixel delta. Also subpixelate line delta.
        ///     See CGEventSource pixelsPerLine - it's 10.
        
        CGEventRef event = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 1, 0);
        
        int64_t dyLine;
        int64_t dxLine;
        
        /// Make line deltas 1/10 of pixel deltas
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
        
    } else {
        assert(false);
    }
    
}

/// Output - Helper funcs

static BOOL _appSwitcherIsOpen = NO;

+ (void)appSwitcherModificationHasBeenDeactivated {
    /// AppSwitcherModification is aka CommandTab. Should rename to AppSwitcher.
    if (_appSwitcherIsOpen) { /// Not sure if this check is necessary. Should only be called when the appSwitcher is open.
        sendKeyEvent(55, 0, false);
        _appSwitcherIsOpen = NO;
    }
}

void sendKeyEvent(CGKeyCode keyCode, CGEventFlags flags, bool keyDown) {
    
    CGEventTapLocation tapLoc = kCGSessionEventTap;
    
    CGEventRef event = CGEventCreateKeyboardEvent(NULL, keyCode, keyDown);
    CGEventSetFlags(event, flags);
    
    CGEventPost(tapLoc, event);
    CFRelease(event);
    
}

@end
