
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
#import "ConfigFileInterface_App.h"

#import "DeviceManager.h"
#import "Utility_Helper.h"
#import "TouchSimulator.h"

#import "SharedUtility.h"

#import "GestureScrollSimulator.h"
#import "ScrollAnalyzer.h"

@implementation SmoothScroll

#pragma mark - Globals

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
static MFDisplayLinkPhase _displayLinkPhase;
static int _pxToScrollThisFrame;
//static int _previousPhase; // which phase was active the last time that displayLinkCallback was called. Used to compute artificial scroll phases
static CGDirectDisplayID *_displaysUnderMousePointer;
// linear phase
static int      _pxScrollBuffer;
static double   _msLeftForScroll;
// momentum phase
static double   _pxPerMsVelocity;
static int      _onePixelScrollsCounter;

#pragma mark - Interface

static void createDisplayLink() {
    if (_displayLink == nil) {
        CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
        CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, nil);
        _displaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 3); // TODO: Why 3?
    }
}

+ (void)load_Manual {
    [SmoothScroll start];
    [SmoothScroll stop];
    createDisplayLink();
}

/// Consider calling [ScrollControl resetDynamicGlobals] to reset not only SmoothScroll specific globals.
+ (void)resetDynamicGlobals {
    _displayLinkPhase                   =   kMFPhaseStart; // kMFPhaseNone;
    _pxToScrollThisFrame                =   0;
    _pxScrollBuffer                     =   0;
    _msLeftForScroll                    =   0;
    _pxPerMsVelocity                    =   0;
    _onePixelScrollsCounter             =   0;
    
//    [ScrollUtility resetConsecutiveTicksAndSwipes]; // MARK: Put this here, because it fixes problem with magnification scrolling. I feel like this might lead to issues. UPDATE: Yep, this breaks fast scrolling. I disabled it now and magnifications scrolling still seems to work.
    // TODO: Delete this if no problems occur.
    _isScrolling = false;
}

+ (void)configureWithParameters:(NSDictionary *)params {
    _pxStepSize                         =   [[params objectForKey:@"pxPerStep"] intValue];
    _msPerStep                          =   [[params objectForKey:@"msPerStep"] intValue];
    _frictionCoefficient                =   [[params objectForKey:@"friction"] floatValue];
    _frictionDepth                      =   [[params objectForKey:@"frictionDepth"] floatValue];
    _accelerationForScrollBuffer         =   [[params objectForKey:@"acceleration"] floatValue];
    _nOfOnePixelScrollsMax              =   [[params objectForKey:@"onePixelScrollsLimit"] intValue]; // After opl+1 frames of only scrolling 1 pixel, scrolling stops. Should probably change code to stop after opl frames.
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

+ (void)handleInput:(CGEventRef)event info:(NSDictionary * _Nullable)info {
    
    long long scrollDeltaAxis1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);

    // Update global vars
    
    _isScrolling = YES;
    
    // Reset _pixelScrollQueue and related values if appropriate
    if (ScrollAnalyzer.scrollDirectionDidChange) { // Why are we resetting what we are resetting?
        _pxScrollBuffer = 0;
        _pxToScrollThisFrame = 0;
        _pxPerMsVelocity = 0;
        
    }
    // TODO: Commenting this out might cause weird behaviour. Think about what this actually does.
//    if (_scrollPhase != kMFPhaseLinear) { // Why are we resetting what we are resetting?
//        _onePixelScrollsCounter =   0;
//        _pxPerMsVelocity        =   0;
//        _pxScrollBuffer       =   0;
//    }
  

    // Apply scroll wheel input to _pxScrollBuffer
    
    _msLeftForScroll = _msPerStep;
//    _msLeftForScroll = 1 / (_pxPerMSBaseSpeed / _pxStepSize);
    if (scrollDeltaAxis1 > 0) {
        _pxScrollBuffer += _pxStepSize * ScrollControl.scrollDirection;
    } else if (scrollDeltaAxis1 < 0) {
        _pxScrollBuffer -= _pxStepSize * ScrollControl.scrollDirection;
    } else {
        DDLogInfo(@"scrollDeltaAxis1 is 0. This shouldn't happen.");
    }
    
    // Apply acceleration to _pxScrollBuffer
    if (ScrollAnalyzer.consecutiveScrollTickCounter != 0) {
        _pxScrollBuffer = _pxScrollBuffer * _accelerationForScrollBuffer;
    }
    
//    if (ScrollUtility.consecutiveScrollTickCounter == 0) {
//        DDLogDebug(@"tick: %d", ScrollUtility.consecutiveScrollTickCounter);
//        DDLogDebug(@"swip: %d", ScrollUtility.consecutiveScrollSwipeCounter);
//    }
    
    int fastScrollThresholdDelta = ScrollAnalyzer.consecutiveScrollSwipeCounter - ScrollControl.fastScrollThreshold_inSwipes;
    if (fastScrollThresholdDelta >= 0) {
        //&& ScrollUtility.consecutiveScrollTickCounter >= ScrollControl.scrollSwipeThreshold_inTicks) {
        _pxScrollBuffer = _pxScrollBuffer * ScrollControl.fastScrollFactor * pow(ScrollControl.fastScrollExponentialBase, ((int32_t)fastScrollThresholdDelta));
    }
    
//    DDLogDebug(@"buff: %d", _pxScrollBuffer);
//    DDLogDebug(@"--------------");
    
    // Start displaylink and stuff
    
    // Update scroll phase
    _displayLinkPhase = kMFPhaseStart;
    
    if (ScrollAnalyzer.consecutiveScrollTickCounter == 0) {
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
    
    
# pragma mark Linear Phase
    
    if (_displayLinkPhase == kMFPhaseLinear || _displayLinkPhase == kMFPhaseStart) {
        
        _pxToScrollThisFrame = round( (_pxScrollBuffer/_msLeftForScroll) * msSinceLastFrame );
        
        if (_msLeftForScroll == 0.0) { // Diving by zero yields infinity, we don't want that.
            DDLogInfo(@"_msLeftForScroll was 0.0");
            _pxToScrollThisFrame = _pxScrollBuffer; // TODO: But it happens sometimes - check if this handles that situation well
        }

        _pxScrollBuffer   -=  _pxToScrollThisFrame;
        _msLeftForScroll    -=  msSinceLastFrame;
        
        // Entering momentum phase
        if (_msLeftForScroll <= 0 || _pxScrollBuffer == 0) { // TODO: Is `_pxScrollBuffer == 0` necessary? Do the conditions for entering momentum phase make sense?
            _msLeftForScroll    =   0; // TODO: Is this necessary?
            _pxScrollBuffer   =   0; // What about this? This stuff isn't used in momentum phase and should get reset elsewhere efore getting used again
            
            _displayLinkPhase = kMFPhaseMomentum;
            _pxPerMsVelocity = (_pxToScrollThisFrame / msSinceLastFrame);
        }
    }
    
# pragma mark Momentum Phase
    
    else if (_displayLinkPhase == kMFPhaseMomentum) {
        
        _pxToScrollThisFrame = round(_pxPerMsVelocity * msSinceLastFrame);
        double thisVel = _pxPerMsVelocity;
        double nextVel = thisVel - [SharedUtility signOf:thisVel] * pow(fabs(thisVel), _frictionDepth) * (_frictionCoefficient/100) * msSinceLastFrame;
        
        _pxPerMsVelocity = nextVel;
        if ( ((nextVel < 0) && (thisVel > 0)) || ((nextVel > 0) && (thisVel < 0)) ) {
            _pxPerMsVelocity = 0;
        }
        
        if (_pxToScrollThisFrame == 0 || _pxPerMsVelocity == 0) {
            _displayLinkPhase = kMFPhaseEnd;
        }
        
        if (abs(_pxToScrollThisFrame) == 1) {
            _onePixelScrollsCounter += 1;
            if (_onePixelScrollsCounter > _nOfOnePixelScrollsMax) { // I think using > instead of >= might put the actual maximum at _nOfOnePixelScrollsMax + 1.
                _displayLinkPhase = kMFPhaseEnd;
            }
        }
    }
    
# pragma mark Send Event
    
    if (ScrollModifiers.magnificationScrolling) {
        [ScrollModifiers handleMagnificationScrollWithAmount:_pxToScrollThisFrame/800.0];
    } else {
        
        // Get 2d delta
        double dx = 0;
        double dy = 0;
        if (ScrollModifiers.horizontalScrolling) {
            dx = _pxToScrollThisFrame;
        } else {
            dy = _pxToScrollThisFrame;
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
