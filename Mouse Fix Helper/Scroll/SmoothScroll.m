//
// --------------------------------------------------------------------------
// SmoothScroll.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
//#import <HIServices/AXUIElement.h>

#import "SmoothScroll.h"
#import "ScrollUtility.h"

#import "AppDelegate.h"
#import "ScrollModifiers.h"
#import "../Config/ConfigFileInterface_HelperApp.h"

#import "MouseInputReceiver.h"
#import "DeviceManager.h"
#import "Utility_HelperApp.h"
#import "TouchSimulator.h"

@implementation SmoothScroll

#pragma mark - Globals

# pragma mark enum

typedef enum {
    kMFPhaseNone,
    kMFPhaseStart,
    kMFPhaseLinear,
    kMFPhaseMomentum,
    kMFPhaseEnd,
} MFScrollPhase;

#pragma mark parameters

// wheel phase
static int64_t  _pxStepSize;
static double   _msPerStep;
static double   _accelerationForScrollBuffer;
// momentum phase
static double   _frictionCoefficient;
static double   _frictionDepth;
static int      _nOfOnePixelScrollsMax;
// objects
static CVDisplayLinkRef _displayLink;

#pragma mark dynamic vars

// any phase
static int _pxToScrollThisFrame;
static int _scrollPhase; // TODO: Change type to MFScrollPhase
//static int _previousPhase; // which phase was active the last time that displayLinkCallback was called. Used to compute artificial scroll phases
static CGDirectDisplayID *_displaysUnderMousePointer;
// wheel phase
static int      _pxScrollBuffer;
static double   _msLeftForScroll;
// momentum phase
static double   _pxPerMsVelocity;
static int      _onePixelScrollsCounter;

#pragma mark - Interface

+ (void)load_Manual {
    [SmoothScroll start];
    [SmoothScroll stop];
    if (_displayLink == nil) {
        CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
        CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, nil);
        _displaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 3); // TODO: Why 3?
    }
}

/// Consider calling [ScrollControl resetDynamicGlobals] to reset not only SmoothScroll specific globals.
+ (void)resetDynamicGlobals {
    _scrollPhase                        =   kMFPhaseNone;
    _pxToScrollThisFrame                     =   0;
    _pxScrollBuffer                     =   0;
    _msLeftForScroll                    =   0;
    _pxPerMsVelocity                    =   0;
    _onePixelScrollsCounter             =   0;
}

+ (void)configureWithParameters:(NSDictionary *)params {
    _pxStepSize                         =   [[params objectForKey:@"pxPerStep"] intValue];
    _msPerStep                          =   [[params objectForKey:@"msPerStep"] intValue];
    _frictionCoefficient                =   [[params objectForKey:@"friction"] floatValue];
    _frictionDepth                      =   [[params objectForKey:@"frictionDepth"] floatValue];
    _accelerationForScrollBuffer         =   [[params objectForKey:@"acceleration"] floatValue];
    _nOfOnePixelScrollsMax              =   [[params objectForKey:@"onePixelScrollsLimit"] intValue]; // After opl+1 frames of only scrolling 1 pixel, scrolling stops. Should probably change code to stop after opl frames.
}

static BOOL _isRunning;
+ (BOOL)isRunning {
    return _isRunning;
}
+ (void)start {
    
    if (_isRunning) {
        return;
    }
    NSLog(@"SmoothScroll started");
    
    _isRunning = TRUE;
    [SmoothScroll resetDynamicGlobals];
    CGDisplayRemoveReconfigurationCallback(Handle_displayReconfiguration, NULL); // don't know if necesssary
    CGDisplayRegisterReconfigurationCallback(Handle_displayReconfiguration, NULL);
}
+ (void)stop {
    
    NSLog(@"SmoothScroll stopped");
    
    _isRunning = FALSE;
    CVDisplayLinkStop(_displayLink);
    CGDisplayRemoveReconfigurationCallback(Handle_displayReconfiguration, NULL);
}

#pragma mark - Run Loop

+ (void)handleInput:(CGEventRef)event info:(NSDictionary *)info {
    
    long long scrollDeltaAxis1 = [(NSNumber *)[info valueForKey:@"scrollDeltaAxis1"] longLongValue];
    
    // Check if scrolling direction changed
    Boolean scrollDirectionChanged = [ScrollUtility scrollDirectionDidChange:scrollDeltaAxis1]; // TODO: [I think I fixed this. Delete if no errors occur.] This doesn't work when inputting a scroll tick with a new direction near the end of a previous scroll.
    
    // Scroll ticks and scroll swipes
    if (scrollDirectionChanged) {
        [ScrollUtility resetConsecutiveTicksAndSwipes];
    }
    [ScrollUtility updateConsecutiveScrollTickAndSwipeCountersWithTickOccuringNow];
    
    int consecutiveScrollTicks = ScrollUtility.consecutiveScrollTickCounter;
    int consecutiveScrollSwipes = ScrollUtility.consecutiveScrollSwipeCounter;
    
    if (consecutiveScrollTicks == 0) { // stuff you only wanna do once - on the first tick of each series of consecutive scroll ticks
    // This code is very similar to the code under `if (consecutiveScrollTicks == 0) {` in [RoughScroll handleInput:]
    // Look to transfer any improvements

        BOOL mouseMoved = [ScrollUtility mouseDidMove];
        BOOL frontMostAppChanged = NO;
        if (!mouseMoved) {
            frontMostAppChanged = [ScrollUtility frontMostAppDidChange];
            // Only checking this if mouse didn't move, because of || in (mouseMoved || frontMostAppChanged). For optimization. Not sure if significant.
        }
        if (mouseMoved || frontMostAppChanged) {
            // TODO: Move this stuff to `ScrollControl.m`. That way you can prevent duplicate code in `SmoothScroll.m` and `RoughScroll.m` as well as avoid using the `reroutScrollEventToTop:` stuff.
            // set app overrides
            BOOL paramsDidChange = [ConfigFileInterface_HelperApp updateInternalParameters_Force:NO];
            if (paramsDidChange) {
                [ScrollControl rerouteScrollEventToTop:event];
                return;
            }
        }
        if (mouseMoved) {
            // set diplaylink to the display that is actally being scrolled - not sure if this is necessary, because having the displaylink at 30fps on a 30fps display looks just as horrible as having the display link on 60fps, if not worse
            @try {
                setDisplayLinkToDisplayUnderMousePointer(event);
            } @catch (NSException *e) {
                NSLog(@"Error while trying to set display link to display under mouse pointer: %@", [e reason]);
            }
        }
        if (CVDisplayLinkIsRunning(_displayLink) == FALSE) { // Do this after setting app overrides, because that might reroute the event. Rerouting might lead to this event being processed by RoughScroll.m instead of Smoothscroll.m (If the override turns smooth scrolling off). In that case we don't want to start the displayLink.
            CVDisplayLinkStart(_displayLink);
        }
    } else { // stuff you wanna do on every tick, except the first one of each series of consecutive scroll ticks
//        _pxScrollBuffer = _pxScrollBuffer * _accelerationForScrollQueue;
    }

    // Update global vars
    
    // Reset _pixelScrollQueue and related values if appropriate
    if (scrollDirectionChanged) { // Why are we resetting what we are resetting?
        _pxScrollBuffer = 0;
        _pxToScrollThisFrame = 0;
        _pxPerMsVelocity = 0;
    }
    // TODO: Commenting this out might cause weird behaviour. Thimk about what this actually does.
//    if (_scrollPhase != kMFPhaseLinear) { // Why are we resetting what we are resetting?
//        _onePixelScrollsCounter =   0;
//        _pxPerMsVelocity        =   0;
//        _pxScrollBuffer       =   0;
//    }
    // Update scroll phase
    if (_scrollPhase == kMFPhaseEnd || _scrollPhase == kMFPhaseNone) {
        _scrollPhase = kMFPhaseStart;
    } else {
        _scrollPhase = kMFPhaseLinear;
    }
    
    // Apply scroll wheel input to _pxScrollBuffer
    _msLeftForScroll = _msPerStep;
    if (scrollDeltaAxis1 > 0) {
        _pxScrollBuffer += _pxStepSize * ScrollControl.scrollDirection;
    } else if (scrollDeltaAxis1 < 0) {
        _pxScrollBuffer -= _pxStepSize * ScrollControl.scrollDirection;
    }
    
//    _accelerationForScrollBuffer = 1.1;
    
    // Apply acceleration to _pxScrollBuffer
    if (_scrollPhase != kMFPhaseStart && _scrollPhase != kMFPhaseNone) {
        _pxScrollBuffer = _pxScrollBuffer * _accelerationForScrollBuffer;
    }
    
    // Apply fast scroll to _pxScrollBuffer if appropriate
    if (consecutiveScrollSwipes > ScrollControl.fastScrollThreshold_inSwipes) {
        _pxScrollBuffer = _pxScrollBuffer * pow(ScrollControl.fastScrollExponentialBase, (int32_t)consecutiveScrollSwipes - ScrollControl.fastScrollThreshold_inSwipes);
    }
    
    
    NSLog(@"SCROLLPHASE: %d", _scrollPhase);
    NSLog(@"MOUSE INPUT");
}

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext) {
    
    double msSinceLastFrame = CVDisplayLinkGetActualOutputVideoRefreshPeriod(_displayLink) * 1000;
    if (msSinceLastFrame != 16.674562) {
        NSLog(@"frameTimeSpike: %fms", msSinceLastFrame);
    }
//    CVTime msBetweenFramesNominal = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(_displayLink);
//    msSinceLastFrame =
//    ( ((double)msBetweenFramesNominal.timeValue) / ((double)msBetweenFramesNominal.timeScale) ) * 1000;
    
    
# pragma mark Linear Phase
    
    if (_scrollPhase == kMFPhaseLinear || _scrollPhase == kMFPhaseStart) {
        
        _pxToScrollThisFrame = round( (_pxScrollBuffer/_msLeftForScroll) * msSinceLastFrame );
        
        if (_msLeftForScroll == 0.0) { // Diving by zero yields infinity, we don't want that.
            NSLog(@"_msLeftForScroll was 0.0");
            _pxToScrollThisFrame = _pxScrollBuffer; // TODO: But it happens sometimes - check if this handles that situation well
        }
        
                NSLog(@"thisframe: %d,  buffer: %d,     msleft: %f", _pxToScrollThisFrame, _pxScrollBuffer, _msLeftForScroll);
        
        _pxScrollBuffer   -=  _pxToScrollThisFrame;
        _msLeftForScroll    -=  msSinceLastFrame;
        
        // Entering momentum phase
        if ( (_msLeftForScroll <= 0) || (_pxScrollBuffer == 0) ) { // TODO: Why not check if _pxToScrollThisFrame == 0 here instead?
            NSLog(@"LEAVING LINEAR PHASE");
            _msLeftForScroll    =   0; // TODO: Is this necessary?
            _pxScrollBuffer   =   0; // What about this? This stuff isn't used in momentum phase and should get reset elsewhere efore getting used again
            
            _scrollPhase = kMFPhaseMomentum;
            _pxPerMsVelocity = (_pxToScrollThisFrame / msSinceLastFrame);
        }
    }
    
# pragma mark Momentum Phase
    
    else if (_scrollPhase == kMFPhaseMomentum) {
//        NSLog(@"ENTERING MOMENTUM PHASE");
        _pxToScrollThisFrame = round(_pxPerMsVelocity * msSinceLastFrame);
        double oldVel = _pxPerMsVelocity;
        double newVel = oldVel - [ScrollUtility signOf:oldVel] * pow(fabs(oldVel), _frictionDepth) * (_frictionCoefficient/100) * msSinceLastFrame;
        _pxPerMsVelocity = newVel;
        if ( ((newVel < 0) && (oldVel > 0)) || ((newVel > 0) && (oldVel < 0)) ) {
            _pxPerMsVelocity = 0;
        }
        if (_pxToScrollThisFrame == 0 || _pxPerMsVelocity == 0) {
            _scrollPhase = kMFPhaseEnd;
        }
        if (abs(_pxToScrollThisFrame) == 1) {
            _onePixelScrollsCounter += 1;
            if (_onePixelScrollsCounter > _nOfOnePixelScrollsMax) { // I think using > instead of >= might put the actual maximum at _nOfOnePixelScrollsMax + 1.
                _scrollPhase = kMFPhaseEnd;
            }
        }
    }
    
# pragma mark Send Event
    
    if (ScrollControl.magnificationScrolling) {
        [TouchSimulator postEventWithMagnification:_pxToScrollThisFrame/800.0 phase:kIOHIDEventPhaseChanged];
    } else {
        CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(ScrollControl.eventSource, kCGScrollEventUnitPixel, 1, 0);
        // CGEventSourceSetPixelsPerLine(_eventSource, 1);
        // it might be a cool idea to diable scroll acceleration and then try to make the scroll events line based (kCGScrollEventUnitPixel)
        
        // Setting event phases
        
//        if (_scrollPhase >= kMFPhaseMomentum) {
//            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventScrollPhase, _scrollPhase >> 1); // shifting bits so that values match up with appropriate NSEventPhase values.
//        } else {
//            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventScrollPhase, _scrollPhase);
//        }
        
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventScrollPhase, 0);
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventMomentumPhase, 0);
        
        // Set scrollDelta
        
        if (ScrollControl.horizontalScrolling == FALSE) {
            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis1, _pxToScrollThisFrame / 8);
            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventPointDeltaAxis1, _pxToScrollThisFrame);
        } else {
            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis2, _pxToScrollThisFrame / 8);
            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventPointDeltaAxis2, _pxToScrollThisFrame);
        }
        
        // Post event
        
        CGEventPost(kCGSessionEventTap, scrollEvent);
        CFRelease(scrollEvent);
        
    ////     set phases
    ////         the native "scrollPhase" is roughly equivalent to my "wheelPhase"
    //
    //    CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventMomentumPhase, kCGMomentumScrollPhaseNone);
    //
    //
    //
    //    NSLog(@"intern scrollphase: %d", _scrollPhase);
    //    if (_scrollPhase == kMFWheelPhase) {
    //        if (_previousPhase == kMFWheelPhase) {
    //                CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventScrollPhase, 2);
    //        } else {
    //                CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventScrollPhase, 1);
    //        }
    //    }
    //    if (_scrollPhase == kMFMomentumPhase) {
    //        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventScrollPhase, 2);
    //    }
    //
    ////    NSLog(@"scrollPhase: %lld", CGEventGetIntegerValueField(scrollEvent, kCGScrollWheelEventScrollPhase));
    ////    NSLog(@"momentumPhase: %lld \n", CGEventGetIntegerValueField(scrollEvent, kCGScrollWheelEventMomentumPhase));
    //
        
    }
    
#pragma mark Other
    
    if (_scrollPhase == kMFPhaseEnd) {
        [SmoothScroll resetDynamicGlobals];
        CVDisplayLinkStop(displayLink);
        return 0;
    } else if (_scrollPhase == kMFPhaseStart) {
        _scrollPhase = kMFPhaseLinear;
    }
    return 0;
}


#pragma mark - Utility functions

#pragma mark display link

// TODO: What does this do? Is this necessary?
static void Handle_displayReconfiguration(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo) {
    if ( (flags & kCGDisplayAddFlag) || (flags & kCGDisplayRemoveFlag) ) {
        NSLog(@"display added / removed");
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
        NSLog(@"more than one display for current mouse position");
        
    } else if (matchingDisplayCount == 0) {
        NSException *e = [NSException exceptionWithName:NSInternalInconsistencyException reason:@"there are 0 diplays under the mouse pointer" userInfo:NULL];
        @throw e;
    }
    
    free(newDisplaysUnderMousePointer);
    
}

@end

// ((From displayLinkCallback))
// stop displayLink when app under mouse pointer changes mid scroll
/*
 CGEventRef fakeEvent = CGEventCreate(NULL);
 CGPoint mouseLocation = CGEventGetLocation(fakeEvent);
 CFRelease(fakeEvent);
 AXUIElementRef elementUnderMousePointer;
 AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), mouseLocation.x, mouseLocation.y, &elementUnderMousePointer);
 pid_t elementUnderMousePointerPID;
 AXUIElementGetPid(elementUnderMousePointer, &elementUnderMousePointerPID);
 NSRunningApplication *appUnderMousePointer = [NSRunningApplication runningApplicationWithProcessIdentifier:elementUnderMousePointerPID];
 
 if ( !([_bundleIdentifierOfScrolledApp isEqualToString:[appUnderMousePointer bundleIdentifier]]) ) {
 resetDynamicGlobals();
 CVDisplayLinkStop(_displayLink);
 return 0;
 }
 */
