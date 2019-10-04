//
// --------------------------------------------------------------------------
// SmoothScroll.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SmoothScroll.h"
#import "AppDelegate.h"
#import "QuartzCore/CoreVideo.h"
//#import <HIServices/AXUIElement.h>
#import "ModifierInputReceiver.h"
#import "../Config/ConfigFileInterface_HelperApp.h"

#import "MouseInputReceiver.h"
#import "DeviceManager.h"
#import "Utility_HelperApp.h"



@interface SmoothScroll ()

@end

@implementation SmoothScroll


#pragma mark - Globals

# pragma mark properties


// whenever relevantDevicesAreAttached or isEnabled are changed, MomentumScrolls class method startOrStopDecide is called. Start or stop decide will start / stop momentum scroll and set _isRunning

static BOOL _isEnabled;
+ (BOOL)isEnabled {
    return _isEnabled;
}
+ (void)setIsEnabled:(BOOL)B {
    _isEnabled = B;
}

static BOOL _isRunning;
+ (BOOL)isRunning {
    return _isRunning;
}

# pragma mark enum

typedef enum {
    kMFWheelPhase       =   0,
    kMFMomentumPhase    =   1,
} MFScrollPhase;

#pragma mark config

// fast scroll
double          _fastScrollExponentialBase          =   0;
int             _scrollSwipeThreshhold_Ticks        =   0;
int             _fastScrollThreshhold_Swipes        =   0;
double          _consecutiveScrollTickMaxIntervall  =   0;
double          _consecutiveScrollSwipeMaxIntervall =   0;

// wheel phase
static int64_t  _pxStepSize;
static double   _msPerStep;
static int      _scrollDirection;
// momentum phase
static float    _frictionCoefficient;
static int      _nOfOnePixelScrollsMax;
// objects
static CVDisplayLinkRef _displayLink    =   nil;
static CFMachPortRef    _eventTap       =   nil;
static CGEventSourceRef _eventSource    =   nil;

#pragma mark dynamic

// fast scroll

static BOOL     _lastTickWasPartOfSwipe             =   NO;
static int      _consecutiveScrollTickCounter       =   0;
static NSTimer  *_consecutiveScrollTickTimer        =   NULL;
static int      _consecutiveScrollSwipeCounter      =   0;
static NSTimer  *_consecutiveScrollSwipeTimer       =   NULL;

// any phase
static int32_t  _pixelsToScroll;
static int      _scrollPhase;
static BOOL     _horizontalScrollModifierPressed;
static NSString *_bundleIdentifierOfScrolledApp;
static CGDirectDisplayID *_displaysUnderMousePointer;
static int _previousPhase;                              // which phase was active the last time that displayLinkCallback was called
// wheel phase
static int64_t  _pixelScrollQueue           =   0;
static double   _msLeftForScroll            =   0;
// momentum phase
static double   _pxPerMsVelocity        =   0;
static int      _onePixelScrollsCounter =   0;

#pragma mark - Interface

static void resetDynamicGlobals() {
    _horizontalScrollModifierPressed    =   NO;
    _scrollPhase                        =   kMFWheelPhase;
    _pixelScrollQueue                   =   0;
    _msLeftForScroll                    =   0;
    _pxPerMsVelocity                    =   0;
    _onePixelScrollsCounter             =   0;
}


+ (void)configureWithPxPerStep:(int)px
                     msPerStep:(int)ms
                      friction:(float)f
               scrollDirection:(MFScrollDirection)d
{
    _pxStepSize                         =   px;
    _msPerStep                          =   ms;
    _frictionCoefficient                =   f;
    _scrollDirection                    =   d;
    
    _nOfOnePixelScrollsMax              =   2;
    
    _fastScrollExponentialBase          =   1.05; //1.125 //1.0625 // 1.09375
    _scrollSwipeThreshhold_Ticks        =   3;
    _fastScrollThreshhold_Swipes        =   3;
    _consecutiveScrollTickMaxIntervall     =   0.03;
    _consecutiveScrollSwipeMaxIntervall    =   0.5;
}

+ (void)load_Manual {
    [SmoothScroll start];
    [SmoothScroll stop];
}

+ (void)startOrStopDecide {
    
    NSLog(@"Momentum start or stop");
    
    if ([DeviceManager relevantDevicesAreAttached] && _isEnabled) {
        if (_isRunning == FALSE) {
            
            [SmoothScroll start];
            [ModifierInputReceiver start];
        }
    } else {
        if (_isRunning == TRUE) {
            [SmoothScroll stop];
            [ModifierInputReceiver stop];
        }
    }
}
    

+ (void)start {
    
    NSLog(@"MomentumScroll started");
    
    _isRunning = TRUE;
    
    resetDynamicGlobals();
    
    
    if (_eventTap == nil) {
        CGEventMask mask = CGEventMaskBit(kCGEventScrollWheel);
        _eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, eventTapCallback, NULL);
        NSLog(@"_eventTap: %@", _eventTap);
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        CGEventTapEnable(_eventTap, true);
    }
    
    // the eventTap sometimes breaks when replugging in the mouse too quickly. I don't know if this helps
    @try {
        CGEventTapEnable(_eventTap, true);
    } @finally {
    }
    if (_displayLink == nil) {
        CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
        CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, nil);
        _displaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 3);
    }
    if (_eventSource == nil) {
        _eventSource = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    }
    
    CGDisplayRemoveReconfigurationCallback(Handle_displayReconfiguration, NULL); // don't know if necesssary
    CGDisplayRegisterReconfigurationCallback(Handle_displayReconfiguration, NULL);
}

+ (void)stop {
    
    NSLog(@"MomentumScroll stopped");
    
    _isRunning = FALSE;
    
    if (_displayLink) {
        CVDisplayLinkStop(_displayLink);
        CVDisplayLinkRelease(_displayLink);
        _displayLink = nil;
    } if (_eventTap) {
//        CGEventTapEnable(_eventTap, false);
//        CFRelease(_eventTap);
//        _eventTap = nil;
    } if (_eventSource) {
        CFRelease(_eventSource);
        _eventSource = nil;
    }
    
     CGDisplayRemoveReconfigurationCallback(Handle_displayReconfiguration, NULL);
}

+ (void)setHorizontalScroll:(BOOL)B {
    _horizontalScrollModifierPressed = B;
}
+ (void)temporarilyDisable:(BOOL)B {
    if (B) {
        if (_isRunning) {
            [SmoothScroll stop];
        }
    } else {
        [SmoothScroll startOrStopDecide];
    }
}



#pragma mark - Run Loop

static CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    
    
//    NSLog(@"scrollPhase: %lld", CGEventGetIntegerValueField(event, kCGScrollWheelEventScrollPhase));
//    NSLog(@"momentumPhase: %lld", CGEventGetIntegerValueField(event, kCGScrollWheelEventMomentumPhase));
    
    NSLog(@"line: %lld", CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1));
    NSLog(@"pt: %lld", CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1));
    NSLog(@"fx: %lld", CGEventGetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1));
    
    // return non-scroll-wheel events unaltered
    
    long long   isPixelBased        =   CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous);
    int64_t     scrollDeltaAxis1    =   CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    int64_t     scrollDeltaAxis2    =   CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
    if ( (isPixelBased != 0) || (scrollDeltaAxis1 == 0) || (scrollDeltaAxis2 != 0)) {
        // scroll event doesn't come from a simple scroll wheel or doesn't contain the data we need to use
        return event;
    }
    
    
    // recognize consecutive scroll ticks as "scroll swipes"
    // activate fast scrolling after a number of consecutive "scroll swipes"
    // do other stuff based on "scroll swipes"
    
    if ([_consecutiveScrollTickTimer isValid]) {
        _consecutiveScrollTickCounter += 1;
    } else {
        // do stuff you only wanna do once per scroll swipe
        
        // set app overrides
        setConfigVariablesForAppUnderMousePointer();
        
        // start display link if necessary
        
        if (CVDisplayLinkIsRunning(_displayLink) == FALSE) {
            CVDisplayLinkStart(_displayLink);
        }
        // set diplaylink to the display that is actally being scrolled - not sure if this is necessary, because having the displaylink at 30fps on a 30fps display looks just as horrible as having the display link on 60fps, if not worse
        @try {
            setDisplayLinkToDisplayUnderMousePointer(event);
        } @catch (NSException *e) {
            NSLog(@"Error while trying to set display link to display under mouse pointer: %@", [e reason]);
        }
    }
    
    // check whether enabled here, because setConfigVariablesForAppUnderMousePointer() might enable / disable
    if (_isEnabled == FALSE) {
        
        NSLog(@"NOT ENABLED");
        if (_scrollDirection == -1) {
            long long line1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
            long long point1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
            long long fixedPt1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
            CGEventSetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1, -line1);
            CGEventSetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1, -point1);
            CGEventSetIntegerValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1, -fixedPt1);
        }
        return event;
    }
    
    [_consecutiveScrollTickTimer invalidate];
    _consecutiveScrollTickTimer = [NSTimer scheduledTimerWithTimeInterval:_consecutiveScrollTickMaxIntervall target:[SmoothScroll class] selector:@selector(Handle_ConsecutiveScrollTickCallback:) userInfo:NULL repeats:NO];
    
    if (_consecutiveScrollTickCounter < _scrollSwipeThreshhold_Ticks) {
        _lastTickWasPartOfSwipe = NO;
    } else if (_lastTickWasPartOfSwipe == NO) {

        _consecutiveScrollSwipeCounter  += 1;
        [_consecutiveScrollSwipeTimer invalidate];
        dispatch_async(dispatch_get_main_queue(), ^{
            _consecutiveScrollSwipeTimer = [NSTimer scheduledTimerWithTimeInterval:_consecutiveScrollSwipeMaxIntervall target:[SmoothScroll class] selector:@selector(Handle_ConsecutiveScrollSwipeCallback:) userInfo:NULL repeats:NO];
        });
        _lastTickWasPartOfSwipe = YES;
    }
    
    
    // reset global vars from momentum phase
    
    if (_scrollPhase == kMFMomentumPhase) {
        _onePixelScrollsCounter  =   0;
        _pxPerMsVelocity        =   0;
        _pixelScrollQueue = 0;
    }
    
    // update global vars for wheel phase
    
    _scrollPhase = kMFWheelPhase;
    
    if (![Utility_HelperApp sameSign_n:(scrollDeltaAxis1 * _scrollDirection) m:_pixelsToScroll]) {
        _consecutiveScrollSwipeCounter = 0;
        _pixelScrollQueue = 0;
    };
    
    _msLeftForScroll = _msPerStep;
    if (scrollDeltaAxis1 > 0) {
        _pixelScrollQueue += _pxStepSize * _scrollDirection;
    }
    else if (scrollDeltaAxis1 < 0) {
        _pixelScrollQueue -= _pxStepSize * _scrollDirection;
    }
    
    if (_consecutiveScrollSwipeCounter > _fastScrollThreshhold_Swipes) {
        _pixelScrollQueue = _pixelScrollQueue * pow(_fastScrollExponentialBase, (int32_t)_consecutiveScrollSwipeCounter - _fastScrollThreshhold_Swipes);
    }
    
    return nil;
}

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext) {
    
    

    
//    _pixelsToScroll  = 0;
    
    
    double   msBetweenFrames = CVDisplayLinkGetActualOutputVideoRefreshPeriod(_displayLink) * 1000;
    if (msBetweenFrames != 16.674562) {
        //NSLog(@"frameTimeHike: %fms", msBetweenFrames);
    }
    CVTime msBetweenFramesNominal = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(_displayLink);
    msBetweenFrames =
    ( ((double)msBetweenFramesNominal.timeValue) / ((double)msBetweenFramesNominal.timeScale) ) * 1000;
    
    
# pragma mark Wheel Phase
    if (_scrollPhase == kMFWheelPhase) {
        
        _pixelsToScroll = round( (_pixelScrollQueue/_msLeftForScroll) * msBetweenFrames );
        
        _pixelScrollQueue   -=  _pixelsToScroll;
        _msLeftForScroll    -=  msBetweenFrames;
        
        
        if ( (_msLeftForScroll <= 0) || (_pixelScrollQueue == 0) ) {
            
            _msLeftForScroll    =   0;
            _pixelScrollQueue   =   0;
            
            _scrollPhase = kMFMomentumPhase;
            _pxPerMsVelocity = (_pixelsToScroll / msBetweenFrames);
            
            return 0;
            
        }
        
    }
    
# pragma mark Momentum Phase
    else if (_scrollPhase == kMFMomentumPhase) {
        
        _pixelsToScroll = round(_pxPerMsVelocity * msBetweenFrames);
        
        double oldVel = _pxPerMsVelocity;
        double newVel = oldVel - oldVel * (_frictionCoefficient/100) * msBetweenFrames;
        
        _pxPerMsVelocity = newVel;
        if ( ((newVel < 0) && (oldVel > 0)) || ((newVel > 0) && (oldVel < 0)) ) {
            _pxPerMsVelocity = 0;
        }
        
        
        
        if (( (_pixelsToScroll == 0) || (_pxPerMsVelocity == 0) )) {
            CVDisplayLinkStop(_displayLink);
            return 0;
        }
        
    }
    
    if (abs(_pixelsToScroll) == 1) {
        _onePixelScrollsCounter += 1;
        if (_onePixelScrollsCounter > _nOfOnePixelScrollsMax) {
            _onePixelScrollsCounter = 0;
            CVDisplayLinkStop(displayLink);
            return 0;
        }
    }
    
# pragma mark Send Event
    
    CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(_eventSource, kCGScrollEventUnitPixel, 1, 0);
    // CGEventSourceSetPixelsPerLine(_eventSource, 1);
    // it might be a cool idea to diable scroll acceleration and then try to make the scroll events line based (kCGScrollEventUnitPixel)
    
    
    CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventScrollPhase, 0);
    CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventMomentumPhase, 0);
    
    // set pixels
    
    if (_horizontalScrollModifierPressed == FALSE) {
//        if (_scrollPhase == kMFWheelPhase) {
//            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis1, [Utility_HelperApp signOf:_pixelsToScroll]);
//        }
    
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis1, _pixelsToScroll / 8);
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventPointDeltaAxis1, _pixelsToScroll);
    }
    else if (_horizontalScrollModifierPressed == TRUE) {
//        if (_scrollPhase == kMFWheelPhase) {
//            CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis2, [Utility_HelperApp signOf:_pixelsToScroll]);
//        }
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis2, _pixelsToScroll / 8);
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventPointDeltaAxis2, _pixelsToScroll);
    }
    
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
    
    CGEventPost(kCGSessionEventTap, scrollEvent);
    CFRelease(scrollEvent);
    
    
#pragma mark Other
    
    _previousPhase = _scrollPhase;
    
    
    
    return 0;
}


#pragma mark - helper functions

#pragma mark app exceptions

static void setConfigVariablesForAppUnderMousePointer() {
    
 
    // get App under mouse pointer
    
    
    
CFTimeInterval ts = CACurrentMediaTime();
    

    
    
    
    
    
    
    // 1. Even slower
    
//    CGEventRef fakeEvent = CGEventCreate(NULL);
//    CGPoint mouseLocation = CGEventGetLocation(fakeEvent);
//    CFRelease(fakeEvent);
    
//    NSInteger winNUnderMouse = [NSWindow windowNumberAtPoint:(NSPoint)mouseLocation belowWindowWithWindowNumber:0];
//    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListExcludeDesktopElements | kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
////    NSLog(@"windowList: %@", windowList);
//    int windowPID = 0;
//    for (int i = 0; i < CFArrayGetCount(windowList); i++) {
//        CFDictionaryRef w = CFArrayGetValueAtIndex(windowList, i);
//        int winN;
//        CFNumberGetValue(CFDictionaryGetValue(w, CFSTR("kCGWindowNumber")), kCFNumberIntType, &winN);
//        if (winN == winNUnderMouse) {
//            CFNumberGetValue(CFDictionaryGetValue(w, CFSTR("kCGWindowOwnerPID")), kCFNumberIntType, &windowPID);
//        }
//    }
//    NSRunningApplication *appUnderMousePointer = [NSRunningApplication runningApplicationWithProcessIdentifier:windowPID];
//    NSString *bundleIdentifierOfScrolledApp_New = appUnderMousePointer.bundleIdentifier;
  
    
    // 2. very slow
    
    CGEventRef fakeEvent = CGEventCreate(NULL);
    CGPoint mouseLocation = CGEventGetLocation(fakeEvent);
    CFRelease(fakeEvent);
    
    AXUIElementRef elementUnderMousePointer;
    AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), mouseLocation.x, mouseLocation.y, &elementUnderMousePointer);
    pid_t elementUnderMousePointerPID;
    AXUIElementGetPid(elementUnderMousePointer, &elementUnderMousePointerPID);
    NSRunningApplication *appUnderMousePointer = [NSRunningApplication runningApplicationWithProcessIdentifier:elementUnderMousePointerPID];

    NSString *bundleIdentifierOfScrolledApp_New = appUnderMousePointer.bundleIdentifier;
    
    
    // 3. fast
//    NSString *bundleIdentifierOfScrolledApp_New = [NSWorkspace.sharedWorkspace frontmostApplication].bundleIdentifier;
    
    
    NSLog(@"bench: %f", CACurrentMediaTime() - ts);
    
    
    
    
    // if app under mouse pointer changed, adjust settings
    
    if ([_bundleIdentifierOfScrolledApp isEqualToString:bundleIdentifierOfScrolledApp_New] == FALSE) {
        
        NSLog(@"changing Scroll Settings");
        
        NSDictionary *config = [ConfigFileInterface_HelperApp config];
        NSDictionary *overrides = [config objectForKey:@"AppOverrides"];
        
        NSDictionary *scrollOverrideForAppUnderMousePointer;
        
        for (NSString *b in overrides.allKeys) {
            if ([bundleIdentifierOfScrolledApp_New containsString:b]) {
                scrollOverrideForAppUnderMousePointer = [[overrides objectForKey: b] objectForKey:@"ScrollSettings"];
            }
        }
        
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
        _msPerStep                          =   [[values objectAtIndex:1] intValue];
        _frictionCoefficient                =   [[values objectAtIndex:2] floatValue];
        _scrollDirection                    =   [[values objectAtIndex:3] intValue];
    }
    
    _bundleIdentifierOfScrolledApp = bundleIdentifierOfScrolledApp_New;
}

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
