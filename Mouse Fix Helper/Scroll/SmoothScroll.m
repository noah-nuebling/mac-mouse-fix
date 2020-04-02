//
// --------------------------------------------------------------------------
// SmoothScroll.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
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

// fast scroll
double          _fastScrollExponentialBase          =   0;
int             _scrollSwipeThreshold_inTicks        =   0;
int             _fastScrollThreshold_inSwipes        =   0;
double          _consecutiveScrollTickMaxIntervall  =   0;
double          _consecutiveScrollSwipeMaxIntervall =   0;

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

// fast scroll
static BOOL     _lastTickWasPartOfSwipe             =   NO;
static int      _consecutiveScrollTickCounter       =   0;
static NSTimer  *_consecutiveScrollTickTimer        =   NULL;
static int      _consecutiveScrollSwipeCounter      =   0;
static NSTimer  *_consecutiveScrollSwipeTimer       =   NULL;

// any phase
static int32_t  _pixelsToScroll;
static int      _scrollPhase; // TODO: Change type to MFScrollPhase
static int _previousPhase; // which phase was active the last time that displayLinkCallback was called
static CGDirectDisplayID *_displaysUnderMousePointer;
// wheel phase
static int64_t  _pixelScrollQueue           =   0;
static double   _msLeftForScroll            =   0;
static long long _previousScrollDeltaAxis1; // to detect scroll direction change
// momentum phase
static double   _pxPerMsVelocity        =   0;
static int      _onePixelScrollsCounter =   0;

#pragma mark - Interface

/// Consider calling [ScrollControl resetDynamicGlobals] instead of this. It will reset not only SmoothScroll specific globals.
+ (void)resetDynamicGlobals {
    _scrollPhase                        =   kMFPhaseWheel;
    _pixelScrollQueue                   =   0;
    _msLeftForScroll                    =   0;
    _pxPerMsVelocity                    =   0;
    _onePixelScrollsCounter             =   0;
    _consecutiveScrollTickCounter       =   0;
    _consecutiveScrollSwipeCounter      =   0;
    [_consecutiveScrollTickTimer invalidate];
    [_consecutiveScrollSwipeTimer invalidate];
}

+ (void)configureWithParameters:(NSDictionary *)params {
    _pxStepSize                         =   [[params objectForKey:@"pxPerStep"] intValue];
    _msPerStep                          =   [[params objectForKey:@"msPerStep"] intValue];
    _frictionCoefficient                =   [[params objectForKey:@"friction"] floatValue];
    _frictionDepth                      =   [[params objectForKey:@"frictionDepth"] floatValue];
    _accelerationForScrollQueue         =   [[params objectForKey:@"acceleration"] floatValue];
    
    // After opl+1 frames of only scrolling 1 pixel, scrolling stops. Should probably change code to stop after opl frames.
    _nOfOnePixelScrollsMax              =   [[params objectForKey:@"onePixelScrollsLimit"] intValue];
    
    // How quickly fast scrolling gains speed.
    _fastScrollExponentialBase          =   [[params objectForKey:@"fastScrollExponentialBase"] floatValue]; // 1.05 //1.125 //1.0625 // 1.09375
    // If fs_thr consecutive swipes occur, fast scrolling is enabled.
    _fastScrollThreshold_inSwipes       =   [[params objectForKey:@"fastScrollThreshold_inSwipes"] intValue];
    // If sw_thr consecutive ticks occur, they are deemed a scroll-swipe.
    _scrollSwipeThreshold_inTicks       =   [[params objectForKey:@"scrollSwipeThreshold_inTicks"] intValue]; // 3
    // If more than sw_int seconds passes between two scrollwheel swipes, then they aren't deemed consecutive.
    _consecutiveScrollSwipeMaxIntervall =   [[params objectForKey:@"consecutiveScrollSwipeMaxIntervall"] floatValue];
    // If more than ti_int seconds passes between two scrollwheel ticks, then they aren't deemed consecutive.
    _consecutiveScrollTickMaxIntervall  =   [[params objectForKey:@"consecutiveScrollTickMaxIntervall"] floatValue]; // == _msPerStep/1000 // oldval:0.03
}

+ (void)configureWithPxPerStep:(int)px
                     msPerStep:(int)ms
                      friction:(float)f
                 fricitonDepth:(float)fd
                  acceleration:(float)acc
          onePixelScrollsLimit:(int)opl
     fastScrollExponentialBase:(float)fs_exp
  fastScrollThreshold_inSwipes:(int)fs_thr
  scrollSwipeThreshold_inTicks:(int)sw_thr
consecutiveScrollSwipeMaxIntervall:(float)sw_int
consecutiveScrollTickMaxIntervall:(float)ti_int
{
    _pxStepSize                         =   px;
    _msPerStep                          =   ms;
    _frictionCoefficient                =   f;
    _frictionDepth                      =   fd;
    _accelerationForScrollQueue         =   acc;
    
    // After opl+1 frames of only scrolling 1 pixel, scrolling stops. Should probably change code to stop after opl frames.
    _nOfOnePixelScrollsMax              =   opl;
    
    // How quickly fast scrolling gains speed.
    _fastScrollExponentialBase          =   fs_exp; // 1.05 //1.125 //1.0625 // 1.09375
    // If fs_thr consecutive swipes occur, fast scrolling is enabled.
    _fastScrollThreshold_inSwipes       =   fs_thr;
    // If sw_thr consecutive ticks occur, they are deemed a scroll-swipe.
    _scrollSwipeThreshold_inTicks       =   sw_thr; // 3
    // If more than sw_int seconds passes between two scrollwheel swipes, then they aren't deemed consecutive.
    _consecutiveScrollSwipeMaxIntervall =   sw_int;
    // If more than ti_int seconds passes between two scrollwheel ticks, then they aren't deemed consecutive.
    _consecutiveScrollTickMaxIntervall  =   ti_int; // == _msPerStep/1000 // oldval:0.03
    
}

//AppOverrides *_appOverrides;
+ (void)load_Manual {
    [SmoothScroll start];
    [SmoothScroll stop];
//    _appOverrides = [AppOverrides new];
}

+ (void)start {
    
    if (_isRunning) {
        return;
    }
    
    NSLog(@"SmoothScroll started");
    
    _isRunning = TRUE;
    
    [SmoothScroll resetDynamicGlobals];
    
    if (_displayLink == nil) {
        CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
        CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, nil);
        _displaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 3);
    }
    CGDisplayRemoveReconfigurationCallback(Handle_displayReconfiguration, NULL); // don't know if necesssary
    CGDisplayRegisterReconfigurationCallback(Handle_displayReconfiguration, NULL);
    
}

+ (void)stop {
    
    NSLog(@"SmoothScroll stopped");
    
    _isRunning = FALSE;
    
    if (_displayLink) {
        CVDisplayLinkStop(_displayLink);
        CVDisplayLinkRelease(_displayLink);
        _displayLink = nil;
    }
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
    
    // Update global vars

    if (_scrollPhase != kMFPhaseWheel) {
        _onePixelScrollsCounter  =   0;
        _pxPerMsVelocity        =   0;
        _pixelScrollQueue = 0;
    }
    if (_scrollPhase == kMFPhaseMomentum) {
        _scrollPhase = kMFPhaseWheel;
    } else if (_scrollPhase == kMFPhaseEnd) {
        _scrollPhase = kMFPhaseStart;
    }
    if (newScrollDirection) {
        _pixelScrollQueue = 0;
        _pixelsToScroll = 0;
        _pxPerMsVelocity = 0;
    };
    _msLeftForScroll = _msPerStep;
    if (scrollDeltaAxis1 > 0) {
        _pixelScrollQueue += _pxStepSize * ScrollControl.scrollDirection;
    }
    else if (scrollDeltaAxis1 < 0) {
        _pixelScrollQueue -= _pxStepSize * ScrollControl.scrollDirection;
    }
    if (_consecutiveScrollSwipeCounter > _fastScrollThreshold_inSwipes) {
        _pixelScrollQueue = _pixelScrollQueue * pow(_fastScrollExponentialBase, (int32_t)_consecutiveScrollSwipeCounter - _fastScrollThreshold_inSwipes);
    }
    
    // Scroll ticks and scroll swipes
    
        // recognize consecutive scroll ticks as "scroll swipes"
        // activate fast scrolling after a number of consecutive "scroll swipes"
        // do other stuff based on "scroll swipes"
    
    if (newScrollDirection) {
        _consecutiveScrollTickCounter = 0;
        _consecutiveScrollSwipeCounter = 0;
        [_consecutiveScrollTickTimer invalidate];
        [_consecutiveScrollSwipeTimer invalidate];
    };
    if (![_consecutiveScrollTickTimer isValid]) {
        // stuff you only wanna do once - on the first tick of each series of consecutive scroll ticks
        
        if (CVDisplayLinkIsRunning(_displayLink) == FALSE) {
            CVDisplayLinkStart(_displayLink);
        }
        // Check if Mouse Location changed
        Boolean mouseMoved = FALSE;
        CGPoint mouseLocation = CGEventGetLocation(event);
        if (![ScrollUtility point:mouseLocation isAboutTheSameAs:ScrollControl.previousMouseLocation threshold:10]) {
            mouseMoved = TRUE;
            ScrollControl.previousMouseLocation = mouseLocation;
        }
        
        if (mouseMoved) {
            
            // TODO: Either set appOverrides regardless of mouse moved, or also set it if mouse hasn't moved but frontmost app has changed. (appOverrdides are applied by setProgramStateToConfig). Otherwise, changing app without moving the mouse pointer will not lead to the proper override being applied.
            // set app overrides
            [ConfigFileInterface_HelperApp setProgramStateToConfig];
            // set diplaylink to the display that is actally being scrolled - not sure if this is necessary, because having the displaylink at 30fps on a 30fps display looks just as horrible as having the display link on 60fps, if not worse
            @try {
                setDisplayLinkToDisplayUnderMousePointer(event);
            } @catch (NSException *e) {
                NSLog(@"Error while trying to set display link to display under mouse pointer: %@", [e reason]);
            }
        }
    } else {
        _consecutiveScrollTickCounter += 1;
        // stuff you wanna do on every tick, except the first one of each series of consecutive scroll ticks
        
        // accelerate
        _pixelScrollQueue = _pixelScrollQueue * _accelerationForScrollQueue;
    }
    // Reset the _consecutiveScrollTickCounter when no "consecutive" tick occurs after this one. (consecutive meaning occuring within _consecutiveScrollTickMaxIntervall after this one)
    [_consecutiveScrollTickTimer invalidate];
    _consecutiveScrollTickTimer = [NSTimer scheduledTimerWithTimeInterval:_consecutiveScrollTickMaxIntervall target:[SmoothScroll class] selector:@selector(Handle_ConsecutiveScrollTickCallback:) userInfo:NULL repeats:NO];
    
    if (_consecutiveScrollTickCounter < _scrollSwipeThreshold_inTicks) {
        _lastTickWasPartOfSwipe = NO;
    } else {
        // stuff you wanna do on every tick after and including the one which started the scroll swipe. Will probably never use this.
        // (nothing here)
        
        if (_lastTickWasPartOfSwipe == NO) {
            // stuff you wanna do once - on the first tick of the swipe (swipe starts after _scrollSwipeThreshold_inTicks consecutive ticks have occured).
            // If you want to do something once per series of consecutive scroll ticks, even if they don't pass the swipe threshold, you should use the space right under `if (![_consecutiveScrollTickTimer isValid]) {`
            
            _lastTickWasPartOfSwipe = YES;
            _consecutiveScrollSwipeCounter  += 1;
            // Reset the _consecutiveScrollSwipeCounter when no "consecutive" swipe occurs after this one. (consecutive meaning occuring within _consecutiveScrollSwipeMaxIntervall after this one)
            [_consecutiveScrollSwipeTimer invalidate];
            dispatch_async(dispatch_get_main_queue(), ^{ // TODO: TODO: is executing on the main thread here necessary / useful?
                _consecutiveScrollSwipeTimer = [NSTimer scheduledTimerWithTimeInterval:_consecutiveScrollSwipeMaxIntervall target:[SmoothScroll class] selector:@selector(Handle_ConsecutiveScrollSwipeCallback:) userInfo:NULL repeats:NO];
            });
        }
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
        
        
        _pixelsToScroll = round( (_pixelScrollQueue/_msLeftForScroll) * msBetweenFrames );
        
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

#pragma mark fast scroll

+ (void)Handle_ConsecutiveScrollSwipeCallback:(NSTimer *)timer {
    _consecutiveScrollSwipeCounter = 0;
    [timer invalidate];
}
+ (void)Handle_ConsecutiveScrollTickCallback:(NSTimer *)timer {
    _consecutiveScrollTickCounter = 0;
    [timer invalidate];
}

#pragma mark display link

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
