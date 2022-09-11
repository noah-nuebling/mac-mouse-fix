
//
// --------------------------------------------------------------------------
// SmoothScroll.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
//#import <HIServices/AXUIElement.h>

#import "SmoothScroll.h"
#import "ScrollUtility.h"

#import "AppDelegate.h"
#import "ScrollModifiers.h"
#import "Config.h"

#import "DeviceManager.h"
#import "Utility_Helper.h"
#import "TouchSimulator.h"

#import "SharedUtility.h"

#import "GestureScrollSimulator.h"
#import "ScrollConfigObjC.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "CubicUnitBezier.h"

@implementation SmoothScroll

#pragma mark - Vars

// Constant

static CVDisplayLinkRef _displayLink;
static id<RealFunction> _animationCurve;
static id<RealFunction> _animationCurveLegacy;

// Dynamic

// Any phase
static MFDisplayLinkPhase _displayLinkPhase;
//static int pxToScrollThisFrame;
//static int _previousPhase; // which phase was active the last time that displayLinkCallback was called. Used to compute artificial scroll phases
static CGDirectDisplayID *_displaysUnderMousePointer;
// Animation phase
static int      _pxScrollBuffer;
static CFTimeInterval _animationStartTime;
static CFTimeInterval _animationDuration;
static int64_t _animationAlreadyScrolledPixels;

// Momentum phase
static double   _pxPerMsVelocity;
static int      _onePixelScrollsCounter;

#pragma mark - Interface

+ (void)load_Manual {
    
    [SmoothScroll start];
    [SmoothScroll stop];
    createDisplayLink();
    
    // Set up animation curve
    
    NSArray *points = @[@[@(0.0),@(0.0)], @[@(0.0),@(0.0)], @[@(1.0),@(1.0)], @[@(1.0),@(1.0)]];
    
    Bezier *bezierCurve = [[Bezier alloc] initWithControlPointsAsArrays:points];
    
    CubicUnitBezier *animationCurve = [CubicUnitBezier alloc];
    [animationCurve UnitBezierForPoint1x:[points[1][0] doubleValue] point1y:[points[1][1] doubleValue] point2x:[points[2][0] doubleValue] point2y:[points[2][1] doubleValue]];
    
    _animationCurve = bezierCurve;
    _animationCurveLegacy = animationCurve;
    
}

static void createDisplayLink() {
    if (_displayLink == nil) {
        CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
        CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, nil);
        _displaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 3); // TODO: Why 3?
    }
}

/// Consider calling [ScrollControl resetDynamicGlobals] to reset not only SmoothScroll specific globals.
+ (void)resetDynamicGlobals {
    _displayLinkPhase                   =   kMFPhaseStart; // kMFPhaseNone;
    _pxScrollBuffer                     =   0;
    _animationAlreadyScrolledPixels     =   0;
    _pxPerMsVelocity                    =   0;
    _onePixelScrollsCounter             =   0;
    
    _isScrolling = false;
}

static BOOL _isScrolling = NO;
+ (BOOL)isScrolling {
    return _isScrolling;
}
static BOOL _hasStarted;
+ (BOOL)hasStarted {
    return _hasStarted;
}
+ (void)start {
    if (_hasStarted) {
        return;
    }
    
    _hasStarted = YES;
    [SmoothScroll resetDynamicGlobals];
    CGDisplayRemoveReconfigurationCallback(Handle_displayReconfiguration, NULL); // don't know if necesssary
    CGDisplayRegisterReconfigurationCallback(Handle_displayReconfiguration, NULL);
}
+ (void)stop {
    if (!_hasStarted) {
        return;
    }
    
    _hasStarted = NO;
    _isScrolling = NO;
    CVDisplayLinkStop(_displayLink);
    CGDisplayRemoveReconfigurationCallback(Handle_displayReconfiguration, NULL);
}

#pragma mark - Run Loop

+ (void)handleInput:(CGEventRef)event scrollAnalysisResult:(ScrollAnalysisResult)scrollAnalysisResult { // TODO: Remove the scrollAnalysisResult argument once we moved that functionality over to ScrollControl
    
    long long scrollDeltaAxis1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);

    // Update global vars
    
    _isScrolling = YES;
    
    // Reset _pixelScrollQueue and related values if appropriate
    if (scrollAnalysisResult.scrollDirectionDidChange) { // Why are we resetting what we are resetting?
        _pxScrollBuffer = 0;
        _pxPerMsVelocity = 0;
        
    }
    // TODO: Commenting this out might cause weird behaviour. Think about what this actually does.
//    if (_scrollPhase != kMFPhaseLinear) { // Why are we resetting what we are resetting?
//        _onePixelScrollsCounter =   0;
//        _pxPerMsVelocity        =   0;
//        _pxScrollBuffer       =   0;
//    }
  

    // Update ms left for scroll
    
//    _msLeftForScroll = ScrollConfig.msPerStep;
    
    // Apply scroll wheel input to _pxScrollBuffer
    
//    _msLeftForScroll = 1 / (_pxPerMSBaseSpeed / _pxStepSize);
    if (scrollDeltaAxis1 > 0) {
        _pxScrollBuffer += ScrollConfig.pxPerTickBase * ScrollConfig.scrollInvert;
    } else if (scrollDeltaAxis1 < 0) {
        _pxScrollBuffer -= ScrollConfig.pxPerTickBase * ScrollConfig.scrollInvert;
    } else {
        DDLogInfo(@"scrollDeltaAxis1 is 0. This shouldn't happen.");
    }
    
    // Apply acceleration
//    if (scrollAnalysisResult.consecutiveScrollTickCounter != 0) {
//        _pxScrollBuffer = _pxScrollBuffer * ScrollConfig.accelerationForScrollBuffer;
//    }

    // Apply fast scroll
    
    int64_t fastScrollThresholdDelta = scrollAnalysisResult.consecutiveScrollSwipeCounter - (unsigned int)ScrollConfig.fastScrollThreshold_inSwipes;
    if (fastScrollThresholdDelta >= 0) {
        //&& ScrollUtility.consecutiveScrollTickCounter >= ScrollControl.scrollSwipeThreshold_inTicks) {
        _pxScrollBuffer = _pxScrollBuffer * ScrollConfig.fastScrollFactor * pow(ScrollConfig.fastScrollExponentialBase, ((int32_t)fastScrollThresholdDelta));
    }
    
    // Update animationCurve stuff
    
    _animationStartTime = CACurrentMediaTime();
    _animationDuration = ScrollConfig.msPerStep / 1000.0; // Don't need to set this every time
    _animationAlreadyScrolledPixels = 0;
    
//    DDLogDebug(@"buff: %d", _pxScrollBuffer);
//    DDLogDebug(@"--------------");
    
    // Start displaylink and stuff
    
    // Update scroll phase
    _displayLinkPhase = kMFPhaseStart;
    
    if (scrollAnalysisResult.consecutiveScrollTickCounter == 0) {
        if (ScrollUtility.mouseDidMove) {
            // Set diplaylink to the display that is actally being scrolled - not sure if this is necessary, because having the displaylink at 30fps on a 30fps display looks just as horrible as having the display link on 60fps, if not worse
            @try {
                setDisplayLinkToDisplayUnderMousePointer(event);
            } @catch (NSException *e) {
                DDLogInfo(@"Error while trying to set display link to display under mouse pointer: %@", [e reason]);
            }
        }
        while (CVDisplayLinkIsRunning(_displayLink) == NO) {
            // Executing this on _scrollQueue (like the rest of this function) leads to `CVDisplayLinkStart()` failing sometimes. Once it has failed it will fail over and over again, taking a few minutes or so to start working again, if at all.
            // Solution: I have no idea why, but executing on the main queue does the trick! ^^
            // This actually still occurs sometimes after waking the computer from sleep. It fails over and over with the return code -6661 = kCVReturnInvalidArgument
            // There also used to be a bug I wrote about in ScrollControl.h where sending events would stop working at random until switching to an app that doesnt have SmoothScroll enabled. It was also fixed by calling CVDisplayLinkStart() on the main thread. It was probably the same issue.
            dispatch_sync(dispatch_get_main_queue(), ^{
                
                if (_displayLink == nil) { // Hopefully prevent the error where it fails with kCVReturnInvalidArgument
                    createDisplayLink();
                }
                
                CVReturn rt = CVDisplayLinkStart(_displayLink);
                if (rt != kCVReturnSuccess) {
                    DDLogInfo(@"Failed to start displayLink. Trying again.");
                    DDLogInfo(@"Error code: %d", rt);
                }
                
            });
        }
    }
}

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext) {
    
    double msSinceLastFrame = CVDisplayLinkGetActualOutputVideoRefreshPeriod(_displayLink) * 1000;
    //    CVTime msBetweenFramesNominal = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(_displayLink);
    //    msSinceLastFrame =
    //    ( ((double)msBetweenFramesNominal.timeValue) / ((double)msBetweenFramesNominal.timeScale) ) * 1000;
    
//    if (msSinceLastFrame != 16.674562) {
//        DDLogDebug(@"frameTimeSpike: %fms", msSinceLastFrame);
//    }
    
    int64_t pxToScrollThisFrame = 0;
    
# pragma mark Animation curve phase
    
    if (_displayLinkPhase == kMFPhaseLinear || _displayLinkPhase == kMFPhaseStart) {
        
        // Get time offset
        
        CFTimeInterval now = CACurrentMediaTime();
        
        // Normalize time offset
        
        Interval *sourceRange = [[Interval alloc] initWithLocation:_animationStartTime length:_animationDuration];
        double normalizedTimeSinceAnimationStart;
        if (now < sourceRange.upper) { // ScaleWithValue will throw an exception if we don't do this
            normalizedTimeSinceAnimationStart = [Math scaleWithValue:now from:sourceRange to:.unitInterval];
        } else {
            normalizedTimeSinceAnimationStart = 1.0;
        }
        
        // Get scrolledPixelsTarget (How many pixels should be scrolled at this moment according to the animationCurve)
        
        CFTimeInterval ts1 = CACurrentMediaTime();
        double normalizedScrolledPixelsTarget = [_animationCurve evaluateAt:normalizedTimeSinceAnimationStart];
        CFTimeInterval ts2 = CACurrentMediaTime();
        
        CFTimeInterval ts3 = CACurrentMediaTime();
        double normalizedScrolledPixelsTargetLegacy = [_animationCurveLegacy evaluateAt:normalizedTimeSinceAnimationStart];
        CFTimeInterval ts4 = CACurrentMediaTime();
        
        DDLogDebug(@"\n\
Swift Curve time: %.7fs\n\
ObjC Curve time:  %.7fs\n\
Ratio: %f",
                   ts2 - ts1,
                   ts4 - ts3,
                   (ts2 - ts1) / (ts4 - ts3));
        
        double scrolledPixelsTarget = normalizedScrolledPixelsTarget * _pxScrollBuffer;
        
        // Get pixels to scroll this frame
        
        pxToScrollThisFrame = round(scrolledPixelsTarget - _animationAlreadyScrolledPixels);
        
        // Update already scrolled px
        
        _animationAlreadyScrolledPixels += pxToScrollThisFrame;
        
        // Analyze state
        
        int64_t pxLeftToScroll = _pxScrollBuffer - _animationAlreadyScrolledPixels;
        double msLeftForScroll = (_animationStartTime + _animationDuration) - now;
        
//        DDLogDebug(@"px left to scroll: %@", @(pxLeftToScroll));
//        DDLogDebug(@"pxToScrollThisFrame: %@", @(pxToScrollThisFrame));
//        DDLogDebug(@"pxToScrollThisFrame: %@", @(pxToScrollThisFrame));
//        DDLogDebug(@"ms left for scroll: %@", @(msLeftForScroll));
//        DDLogDebug(@"now: %@", @(now));
//        DDLogDebug(@"anim start time: %@", @(_animationStartTime));
//        DDLogDebug(@"anim duration: %@", @(_animationDuration));
//        DDLogDebug(@"normalized time since anim start: %@", @(normalizedTimeSinceAnimationStart));
//        DDLogDebug(@"normalized scrolled pixels target: %@", @(normalizedScrolledPixelsTarget));
//        DDLogDebug(@"Already scrolled pixels target: %@", @(scrolledPixelsTarget));
//        DDLogDebug(@"Already scrolled pixels: %@", @(_animationAlreadyScrolledPixels));
//        DDLogDebug(@"Scrolled pixels target: %@", @(_pxScrollBuffer));
//        DDLogDebug(@"---");
        
        // Entering momentum phase
        
        if (msLeftForScroll <= 0 || pxLeftToScroll == 0) { // TODO: Is `_pxScrollBuffer == 0` necessary? Do the conditions for entering momentum phase make sense?
            _pxScrollBuffer   =   0; // What about this? This stuff isn't used in momentum phase and should get reset elsewhere efore getting used again
            
            _displayLinkPhase = kMFPhaseMomentum;
            _pxPerMsVelocity = (pxToScrollThisFrame / msSinceLastFrame);
        }
    }
    
# pragma mark Momentum Phase
    
    else if (_displayLinkPhase == kMFPhaseMomentum) {
        
//        DDLogDebug(@"Momentum scrolling with velocity: %f", _pxPerMsVelocity);
        
        pxToScrollThisFrame = round(_pxPerMsVelocity * msSinceLastFrame);
        double thisVel = _pxPerMsVelocity;
        double nextVel = thisVel - [SharedUtility signOf:thisVel] * pow(fabs(thisVel), ScrollConfig.dragExponent) * (ScrollConfig.dragCoefficient/100) * msSinceLastFrame;
        
        _pxPerMsVelocity = nextVel;
        if ( ((nextVel < 0) && (thisVel > 0)) || ((nextVel > 0) && (thisVel < 0)) ) {
            _pxPerMsVelocity = 0;
        }
        
        if (pxToScrollThisFrame == 0 || _pxPerMsVelocity == 0) {
            _displayLinkPhase = kMFPhaseEnd;
        }
        
        if (llabs(pxToScrollThisFrame) == 1) {
            _onePixelScrollsCounter += 1;
            if (_onePixelScrollsCounter > ScrollConfig.nOfOnePixelScrollsMax) { // I think using > instead of >= might put the actual maximum at _nOfOnePixelScrollsMax + 1.
                _displayLinkPhase = kMFPhaseEnd;
            }
        }
    }
    
# pragma mark Send Event
    
    if (ScrollModifiers.magnificationScrolling) {
        [ScrollModifiers handleMagnificationScrollWithAmount:pxToScrollThisFrame/800.0];
    } else {
        
        // Get 2d delta
        double dx = 0;
        double dy = 0;
        if (ScrollModifiers.horizontalScrolling) {
            dx = pxToScrollThisFrame;
        } else {
            dy = pxToScrollThisFrame;
        }
        
        // Get phase
        
        IOHIDEventPhaseBits phase = IOHIDPhaseFromMFPhase(_displayLinkPhase);
        
//        DDLogDebug(@"displayLinkPhase: %u", _displayLinkPhase);
//        DDLogDebug(@"IOHIDEventPhase: %hu \n", phase);
        
        if (phase != kIOHIDEventPhaseEnded) { // TODO: Remove. Sending it again here is a hack to make it stop scrolling.
            [GestureScrollSimulator postGestureScrollEventWithDeltaX:dx deltaY:dy phase:phase isGestureDelta:NO];
        } else {
            [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseChanged isGestureDelta:NO];
            [GestureScrollSimulator postGestureScrollEventWithDeltaX:0 deltaY:0 phase:kIOHIDEventPhaseEnded isGestureDelta:NO];
        }
        
        
    }
    
#pragma mark Other
    
    if (_displayLinkPhase == kMFPhaseStart) {
        _displayLinkPhase = kMFPhaseLinear;
    } else if (_displayLinkPhase == kMFPhaseEnd) {
        [SmoothScroll resetDynamicGlobals];
        CVDisplayLinkStop(displayLink);
        return 0;
    }
    return 0;
}


#pragma mark - Utility functions

static IOHIDEventPhaseBits IOHIDPhaseFromMFPhase(MFDisplayLinkPhase MFPhase) {
    
    if (MFPhase == kMFPhaseNone) {
        return kIOHIDEventPhaseUndefined;
    } else if (MFPhase == kMFPhaseStart) {
        return kIOHIDEventPhaseBegan;
    } else if (MFPhase == kMFPhaseLinear || MFPhase == kMFPhaseMomentum) {
        return kIOHIDEventPhaseChanged;
    } else if (MFPhase == kMFPhaseEnd) {
        return kIOHIDEventPhaseEnded;
    } else {
        @throw [NSException exceptionWithName:@"UnknownPhaseArgumentException" reason:nil userInfo:nil];
    }
}

#pragma mark display link

// TODO: What does this do? Is this necessary?
static void Handle_displayReconfiguration(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo) {
    if ( (flags & kCGDisplayAddFlag) || (flags & kCGDisplayRemoveFlag) ) {
        DDLogInfo(@"display added / removed");
        CVDisplayLinkStop(_displayLink);
        CVDisplayLinkRelease(_displayLink);
        CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
        CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, nil);
    }
}
static void setDisplayLinkToDisplayUnderMousePointer(CGEventRef event) {
    
    CGPoint mouseLocation = CGEventGetLocation(event);
    CGDirectDisplayID *newDisplaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 3);
    uint32_t matchingDisplayCount;
    CGGetDisplaysWithPoint(mouseLocation, 2, newDisplaysUnderMousePointer, &matchingDisplayCount);
    // TODO: Check if this is slow. If so, check if there's a dedicated way for getting the active display. If so, consider using that instead of CGGetDisplaysWithPoint().
    
    if (matchingDisplayCount >= 1) {
        if (newDisplaysUnderMousePointer[0] != _displaysUnderMousePointer[0]) {
            _displaysUnderMousePointer = newDisplaysUnderMousePointer;
            //sets dsp to the master display if _displaysUnderMousePointer[0] is part of the mirror set
            CGDirectDisplayID dsp = CGDisplayPrimaryDisplay(_displaysUnderMousePointer[0]);
            CVDisplayLinkSetCurrentCGDisplay(_displayLink, dsp);
        }
    } else if (matchingDisplayCount > 1) {
        DDLogInfo(@"more than one display for current mouse position");
        
    } else if (matchingDisplayCount == 0) {
        NSException *e = [NSException exceptionWithName:NSInternalInconsistencyException reason:@"there are 0 diplays under the mouse pointer" userInfo:NULL];
        @throw e;
    }
    free(newDisplaysUnderMousePointer);
}

@end
