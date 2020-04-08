//
// --------------------------------------------------------------------------
// SmoothScroll.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SmoothScroll.h"
#import "ScrollUtility.h"

#import "AppDelegate.h"
#import "QuartzCore/CoreVideo.h"
//#import <HIServices/AXUIElement.h>
#import "ScrollModifiers.h"
#import "../Config/ConfigFileInterface_HelperApp.h"

#import "MouseInputReceiver.h"
#import "DeviceManager.h"
#import "Utility_HelperApp.h"
#import "TouchSimulator.h"

//#import "Mouse_Fix_Helper-Swift.h"


//@class AppOverrides;
//@interface AppOverrides : NSObject
//- (AppOverrides *)returnSwiftObject;
//- (NSString *)getBundleIdFromMouseLocation:(CGEventRef)event;
//@end


@interface SmoothScroll ()

@end

@implementation SmoothScroll



#pragma mark - Globals

# pragma mark properties


static BOOL _isRunning;
+ (BOOL)isRunning {
    return _isRunning;
}

# pragma mark enum

typedef enum {
    kMFPhaseNone        =   0,
    kMFPhaseStart       =   1,
    kMFPhaseWheel       =   2,
    kMFPhaseMomentum    =   4,
    kMFPhaseEnd         =   8,
} MFScrollPhase;

#pragma mark config

// wheel phase
static int64_t  _pxStepSize;
static double   _msPerStep;
static double   _accelerationForScrollQueue;
// momentum phase
static double   _frictionCoefficient;
static double   _frictionDepth;
static int      _nOfOnePixelScrollsMax;
// objects
static CVDisplayLinkRef _displayLink    =   nil;

#pragma mark dynamic

// consecutive scroll ticks, scroll swipes, and fast scroll
//static BOOL     _lastTickWasPartOfSwipe             =   NO;
//static int      _consecutiveScrollTickCounter       =   0;
//static NSTimer  *_consecutiveScrollTickTimer        =   NULL;
//static int      _consecutiveScrollSwipeCounter      =   0;
//static NSTimer  *_consecutiveScrollSwipeTimer       =   NULL;

// any phase
static int32_t  _pixelsToScroll;
static int      _scrollPhase; // TODO: Change type to MFScrollPhase
static int _previousPhase; // which phase was active the last time that displayLinkCallback was called
static CGDirectDisplayID *_displaysUnderMousePointer;
// wheel phase
static int64_t  _pixelScrollQueue           =   0;
static double   _msLeftForScroll            =   0;
static long long _previousScrollDeltaAxis1  =   0;; // to detect scroll direction change
// momentum phase
static double   _pxPerMsVelocity        =   0;
static int      _onePixelScrollsCounter =   0;

#pragma mark - Interface

/// Consider calling [ScrollControl resetDynamicGlobals] instead of this. It will reset not only SmoothScroll specific globals.
+ (void)resetDynamicGlobals {
    _scrollPhase                        =   kMFPhaseWheel;
    _pixelsToScroll                     =   0;
    _pixelScrollQueue                   =   0;
    _previousScrollDeltaAxis1           =   0;
    _msLeftForScroll                    =   0;
    _pxPerMsVelocity                    =   0;
    _onePixelScrollsCounter             =   0;
//    _consecutiveScrollTickCounter       =   0;
//    _consecutiveScrollSwipeCounter      =   0;
//    [_consecutiveScrollTickTimer invalidate];
//    [_consecutiveScrollSwipeTimer invalidate];
}

+ (void)configureWithParameters:(NSDictionary *)params {
    _pxStepSize                         =   [[params objectForKey:@"pxPerStep"] intValue];
    _msPerStep                          =   [[params objectForKey:@"msPerStep"] intValue];
    _frictionCoefficient                =   [[params objectForKey:@"friction"] floatValue];
    _frictionDepth                      =   [[params objectForKey:@"frictionDepth"] floatValue];
    _accelerationForScrollQueue         =   [[params objectForKey:@"acceleration"] floatValue];
    
    // After opl+1 frames of only scrolling 1 pixel, scrolling stops. Should probably change code to stop after opl frames.
    _nOfOnePixelScrollsMax              =   [[params objectForKey:@"onePixelScrollsLimit"] intValue];
}

//AppOverrides *_appOverrides;
+ (void)load_Manual {
    [SmoothScroll start];
    [SmoothScroll stop];
    if (_displayLink == nil) {
        CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
        CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, nil);
        _displaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 3); // TODO: Why 3?
    }
//    _appOverrides = [AppOverrides new];
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

+ (CGEventRef)handleInput:(CGEventRef)event info:(NSDictionary *)info {
  
    
    // TODO: Delete this, if moving it down didn't break anything. Or maybe move it to ScrollControl -> eventTapCallback().
    // Check if Mouse Location changed
    
//    Boolean mouseMoved = FALSE;
//    CGPoint mouseLocation = CGEventGetLocation(event);
//    if (![ScrollUtility point:mouseLocation isAboutTheSameAs:ScrollControl.previousMouseLocation threshold:10]) {
//        mouseMoved = TRUE;
//    }
//    ScrollControl.previousMouseLocation = mouseLocation;
    
    // Check if Scrolling Direction changed
    
    long long scrollDeltaAxis1 = [(NSNumber *)[info valueForKey:@"scrollDeltaAxis1"] longLongValue];
    Boolean newScrollDirection = FALSE;
    if (![ScrollUtility sameSign_n:scrollDeltaAxis1 m:_previousScrollDeltaAxis1]) {
        newScrollDirection = TRUE;
    }
    _previousScrollDeltaAxis1 = scrollDeltaAxis1;
    
    
    if (newScrollDirection) {
        [ScrollUtility resetConsecutiveTicksAndSwipes];
    }

    
    // Scroll ticks and scroll swipes - but with timestamps instead of timers
    
    // recognize consecutive scroll ticks as "scroll swipes"
    // activate fast scrolling after a number of consecutive "scroll swipes"
    // do other stuff based on "scroll swipes"
        
    [ScrollUtility updateConsecutiveScrollTickCounterWithTickOccuringNow];
    int consecutiveScrollTicks = ScrollUtility.consecutiveScrollTickCounter;
    
    if (consecutiveScrollTicks == 0) {
        
        // stuff you only wanna do once - on the first tick of each series of consecutive scroll ticks

        if (CVDisplayLinkIsRunning(_displayLink) == FALSE) {
            CVDisplayLinkStart(_displayLink);
        }
        BOOL mouseMoved = [ScrollUtility mouseDidMove];
        BOOL frontMostAppChanged = NO;
        if (!mouseMoved) {
            frontMostAppChanged = [ScrollUtility frontMostAppDidChange];
            // Only need to check this if mouse didn't move, because of OR in (mouseMoved || frontMostAppChanged). For optimization. Not sure if significant.
        }
        if (mouseMoved || frontMostAppChanged) {

            // TODO: Either set appOverrides regardless of mouse moved, or also set it if mouse hasn't moved but frontmost app has changed. (appOverrdides are applied by setProgramStateToConfig). Otherwise, changing app without moving the mouse pointer will not lead to the proper override being applied.
            // set app overrides
            BOOL paramsDidChange = [ConfigFileInterface_HelperApp updateInternalParameters];
            if (paramsDidChange) {
                return [ScrollControl reinsertScrollEvent:event];
            }

            // set diplaylink to the display that is actally being scrolled - not sure if this is necessary, because having the displaylink at 30fps on a 30fps display looks just as horrible as having the display link on 60fps, if not worse
            @try {
                setDisplayLinkToDisplayUnderMousePointer(event);
            } @catch (NSException *e) {
                NSLog(@"Error while trying to set display link to display under mouse pointer: %@", [e reason]);
            }
        }
    } else {
        
        // stuff you wanna do on every tick, except the first one of each series of consecutive scroll ticks

        // accelerate
        _pixelScrollQueue = _pixelScrollQueue * _accelerationForScrollQueue;
    }
    
    if (consecutiveScrollTicks == ScrollControl.scrollSwipeThreshold_inTicks) {
        [ScrollUtility updateConsecutiveScrollSwipeCounterWithSwipeOccuringNow]; // Shouldn't use _consecutiveScrollSwipeCounter before this point
    }
    
    
    // Update global vars
    
    if (newScrollDirection) { // Why are we resetting what we are resetting?
        _pixelScrollQueue = 0;
        _pixelsToScroll = 0;
        _pxPerMsVelocity = 0;
    }
    if (_scrollPhase != kMFPhaseWheel) { // Same question
        _onePixelScrollsCounter =   0;
        _pxPerMsVelocity        =   0;
        _pixelScrollQueue       =   0;
    }
    if (_scrollPhase == kMFPhaseMomentum) {
        _scrollPhase = kMFPhaseWheel;
    } else if (_scrollPhase == kMFPhaseEnd) {
        _scrollPhase = kMFPhaseStart;
    }
    
    _msLeftForScroll = _msPerStep;
    if (scrollDeltaAxis1 > 0) {
        _pixelScrollQueue += _pxStepSize * ScrollControl.scrollDirection;
    } else if (scrollDeltaAxis1 < 0) {
        _pixelScrollQueue -= _pxStepSize * ScrollControl.scrollDirection;
    }
    if (ScrollUtility.consecutiveScrollSwipeCounter > ScrollControl.fastScrollThreshold_inSwipes) {
        _pixelScrollQueue = _pixelScrollQueue * pow(ScrollControl.fastScrollExponentialBase, (int32_t)ScrollUtility.consecutiveScrollSwipeCounter - ScrollControl.fastScrollThreshold_inSwipes);
    }
    

    return nil;
}

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext) {
    
//    NSLog(@"display Link CALLBACK");
    
//    CFTimeInterval ts = CACurrentMediaTime();
    
    
//    _pixelsToScroll  = 0;
    
    double   msBetweenFrames = CVDisplayLinkGetActualOutputVideoRefreshPeriod(_displayLink) * 1000;
//    if (msBetweenFrames != 16.674562) {
//        NSLog(@"frameTimeHike: %fms", msBetweenFrames);
//    }
    CVTime msBetweenFramesNominal = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(_displayLink);
    msBetweenFrames =
    ( ((double)msBetweenFramesNominal.timeValue) / ((double)msBetweenFramesNominal.timeScale) ) * 1000;
    
    
# pragma mark Wheel Phase
    if (_scrollPhase == kMFPhaseWheel || _scrollPhase == kMFPhaseStart) {
        
        if (_msLeftForScroll != 0.0) {
            _pixelsToScroll = round( (_pixelScrollQueue/_msLeftForScroll) * msBetweenFrames );
        } else {
            _pixelsToScroll = 0; // Diving by zero yields infinity, we don't want that. This should never happen, except if the displayLink is started by something other than the inputHandler, which we prpbably don't want.
            NSLog(@"_msLeftForScroll was 0.0");
        }
        
        _pixelScrollQueue   -=  _pixelsToScroll;
        _msLeftForScroll    -=  msBetweenFrames;
        
        // Entering momentum phase
        if ( (_msLeftForScroll <= 0) || (_pixelScrollQueue == 0) ) {
            
            _msLeftForScroll    =   0;
            _pixelScrollQueue   =   0;
            
            _scrollPhase = kMFPhaseMomentum;
            _pxPerMsVelocity = (_pixelsToScroll / msBetweenFrames);
            
        }
        
    }
    
# pragma mark Momentum Phase
    else if (_scrollPhase == kMFPhaseMomentum) {
        // very smooth
//        _frictionDepth = 0.5;
//        _frictionCoefficient = 0.7;
        _pixelsToScroll = round(_pxPerMsVelocity * msBetweenFrames);
        double oldVel = _pxPerMsVelocity;
        double newVel = oldVel - [ScrollUtility signOf:oldVel] * pow(fabs(oldVel), _frictionDepth) * (_frictionCoefficient/100) * msBetweenFrames;
        _pxPerMsVelocity = newVel;
        if ( ((newVel < 0) && (oldVel > 0)) || ((newVel > 0) && (oldVel < 0)) ) {
            _pxPerMsVelocity = 0;
        }
        if (_pixelsToScroll == 0 || _pxPerMsVelocity == 0) {
            _scrollPhase = kMFPhaseEnd;
        }
    }
    if (abs(_pixelsToScroll) == 1) { // TODO: TODO: Why is this outside of the momentum phase if block
        _onePixelScrollsCounter += 1;
        if (_onePixelScrollsCounter > _nOfOnePixelScrollsMax) { // Using > instead of >= puts the actual maximum at _nOfOnePixelScrollsMax + 1. Idk why I did that.
            _scrollPhase = kMFPhaseEnd;
            _onePixelScrollsCounter = 0;
        }
    }
    
# pragma mark Send Event
    if (ScrollControl.magnificationScrolling) {
                    NSLog(@"Pixels TO ZOOM: %d", _pixelsToScroll);
        [TouchSimulator postEventWithMagnification:_pixelsToScroll/800.0 phase:kIOHIDEventPhaseChanged];
    } else {
        CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(ScrollControl.eventSource, kCGScrollEventUnitPixel, 1, 0);
        // CGEventSourceSetPixelsPerLine(_eventSource, 1);
        // it might be a cool idea to diable scroll acceleration and then try to make the scroll events line based (kCGScrollEventUnitPixel)
        
//        if (_scrollPhase >= kMFPhaseMomentum) {
//            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventScrollPhase, _scrollPhase >> 1); // shifting bits so that values match up with appropriate NSEventPhase values.
//        } else {
//            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventScrollPhase, _scrollPhase);
//        }
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventScrollPhase, 0);
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventMomentumPhase, 0);
        
        // set scrollDelta
        if (ScrollControl.horizontalScrolling == FALSE) {
    //        if (_scrollPhase == kMFWheelPhase) {
    //            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis1, [Utility_HelperApp signOf:_pixelsToScroll]);
    //        }
            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis1, _pixelsToScroll / 8);
            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventPointDeltaAxis1, _pixelsToScroll);
        } else {
    //        if (_scrollPhase == kMFWheelPhase) {
    //            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis2, [Utility_HelperApp signOf:_pixelsToScroll]);
    //        }
            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis2, _pixelsToScroll / 8);
            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventPointDeltaAxis2, _pixelsToScroll);
        }

        
        CGEventPost(kCGSessionEventTap, scrollEvent);
        CFRelease(scrollEvent);
        
    //<<<<<<< Updated upstream
    //=======
    //<<<<<<< HEAD
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
    //=======
    //>>>>>>> 519321477a37764c0b95076d91d80f5238284af3
    //>>>>>>> Stashed changes
        
    }
    
    
#pragma mark Other
    
    if (_scrollPhase == kMFPhaseEnd) {
        [SmoothScroll resetDynamicGlobals]; // Note: Only resetting SmoothScroll globals, not all scroll globals (we would do that using [ScrollControl resetDynamicGlobals])
        CVDisplayLinkStop(displayLink);
        return 0;
    }
    if (_scrollPhase == kMFPhaseStart) {
        _scrollPhase = kMFPhaseWheel;
    }
//    _previousPhase = _scrollPhase;
    
    
    
//    NSLog(@"dispLink bench: %f", CACurrentMediaTime() - ts);
    
    return 0;
}


#pragma mark - helper functions

#pragma mark display link

static void Handle_displayReconfiguration(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo) {
    // TODO: Is this necessary?
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




// (in Handle_eventTapCallback) change settings, when app under mouse pointer changes
/*
static void setConfigVariablesForAppUnderMousePointer() {
 
    // get App under mouse pointer
    
    CGEventRef fakeEvent = CGEventCreate(NULL);
    CGPoint mouseLocation = CGEventGetLocation(fakeEvent);
    CFRelease(fakeEvent);
    
    AXUIElementRef elementUnderMousePointer;
    AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), mouseLocation.x, mouseLocation.y, &elementUnderMousePointer);
    pid_t elementUnderMousePointerPID;
    AXUIElementGetPid(elementUnderMousePointer, &elementUnderMousePointerPID);
    NSRunningApplication *appUnderMousePointer = [NSRunningApplication runningApplicationWithProcessIdentifier:elementUnderMousePointerPID];
    
    // if app under mouse pointer changed, adjust settings
    
    if ([_bundleIdentifierOfScrolledApp isEqualToString:[appUnderMousePointer bundleIdentifier]] == FALSE) {
        
        NSLog(@"changing Scroll Settings");
        
        AppDelegate *delegate = [NSApp delegate];
        NSDictionary *config = [delegate configDictFromFile];
        NSDictionary *overrides = [config objectForKey:@"AppOverrides"];
        NSDictionary *scrollOverrideForAppUnderMousePointer = [[overrides objectForKey:
                                                                [appUnderMousePointer bundleIdentifier]]
                                                               objectForKey:@"ScrollSettings"];
        BOOL enabled;
        NSArray *values;
        if (scrollOverrideForAppUnderMousePointer) {
            enabled = [[scrollOverrideForAppUnderMousePointer objectForKey:@"enabled"] boolValue];
            values = [scrollOverrideForAppUnderMousePointer objectForKey:@"values"];
        }
        else {
            NSDictionary *defaultScrollSettings = [config objectForKey:@"ScrollSettings"];
            enabled = [[defaultScrollSettings objectForKey:@"enabled"] boolValue];
            values = [defaultScrollSettings objectForKey:@"values"];
        }
        _isEnabled                          =   enabled;
        _pxStepSize                         =   [[values objectAtIndex:0] intValue];
        _msPerScroll                        =   [[values objectAtIndex:1] intValue];
        _frictionCoefficient                =   [[values objectAtIndex:2] floatValue];
    }
    
    _bundleIdentifierOfScrolledApp = [appUnderMousePointer bundleIdentifier];
}
 */


// (in Handle_displayLinkCallback) stop displayLink when app under mouse pointer changes mid scroll
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
