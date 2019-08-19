#import "MomentumScroll.h"
#import "AppDelegate.h"
#import "QuartzCore/CoreVideo.h"
//#import <HIServices/AXUIElement.h>
#import "ModifierInputReceiver.h"

#import "MouseInputReceiver.h"
#import "DeviceManager.h"



@interface MomentumScroll ()

@end

@implementation MomentumScroll


#pragma mark - Global Vars

# pragma mark properties

// there are 3 classes and 3 global variables involved in turning on/off MomentumScroll:
// InputReceiver and ConfigFileMonitor can enable/disable MomentumScroll
// InputReceiver sets relevantDevicesAreAttached, ConfigFileMonitor sets isEnabled (defined below), and MomentumScroll sets isRunning
// Based on these 3 variables ConfigFileMonitor and InputReceiver decide whether to enable / disable MomentumScroll when the config file changes or a mouse is attached/removed

// version 2: (I'd like to implement this)
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

// wheel phase
static int64_t  _pxStepSizeBase;
static double   _msPerScroll;
static int      _scrollDirection;
// momentum phase
static float    _frictionCoefficient;
static int      _nOfOnePixelScrollsMax;
// objects
static CVDisplayLinkRef _displayLink    =   nil;
static CFMachPortRef    _eventTap       =   nil;
static CGEventSourceRef _eventSource    =   nil;

#pragma mark dynamic

// any phase
static int      _scrollPhase;
static BOOL     _horizontalScrollModifierPressed;
static NSString *_bundleIdentifierOfScrolledApp;
static CGDirectDisplayID *_displaysUnderMousePointer;
// wheel phase
static int64_t  _pixelScrollQueue           =   0;
static double   _msLeftForScroll            =   0;
static long     _consecutiveScrollsCounter  =   0;
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
    _pxStepSizeBase                         =   px;
    _msPerScroll                        =   ms;
    _frictionCoefficient                =   f;
    
    _nOfOnePixelScrollsMax              =   2;
    
    _scrollDirection = d;
}

+ (void)startOrStopDecide {
    if ([DeviceManager relevantDevicesAreAttached] && _isEnabled) {
        if (_isRunning == FALSE) {
            [MomentumScroll start];
            [ModifierInputReceiver start];
        }
    } else {
        if (_isRunning == TRUE) {
            [MomentumScroll stop];
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
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        CGEventTapEnable(_eventTap, true);
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
        CGEventTapEnable(_eventTap, false);
        CFRelease(_eventTap);
        _eventTap = nil;
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
            [MomentumScroll stop];
        }
    } else {
        [MomentumScroll startOrStopDecide];
    }
}



#pragma mark - Run Loop

CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    if (_isEnabled == FALSE) {
        return event;
    }
    
    // return non-scroll-wheel events unaltered
    
    long long   isPixelBased        =   CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous);
    int64_t     scrollDeltaAxis1    =   CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    int64_t     scrollDeltaAxis2    =   CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
    if ( (isPixelBased != 0) || (scrollDeltaAxis1 == 0) || (scrollDeltaAxis2 != 0)) {
        // scroll event doesn't come from a simple scroll wheel or doesn't contain the data we need to use
        return event;
    }
    
    // start display link if necessary
    
    if (CVDisplayLinkIsRunning(_displayLink) == FALSE) {
        CVDisplayLinkStart(_displayLink);
    }

    // set diplaylink to the display that is actally being scrolled - not sure if this is necessary or even works, bacause I don't have monitors to test on..
    @try {
        setDisplayLinkToDisplayUnderMousePointer(event);
    } @catch (NSException *e) {
        NSLog(@"Error while trying to set display link to display under mouse pointer: %@", [e reason]);
    }
    
    //setConfigVariablesForAppUnderMousePointer();
    
    if (_scrollPhase == kMFMomentumPhase) {
        _pixelScrollQueue = 0;
    }
    _scrollPhase = kMFWheelPhase;
    
    // update global vars for wheel phase

    long pxStepSize = _pxStepSizeBase;
    
    /*
    if (_consecutiveScrollsCounter > 4) {
        _consecutiveScrollsCounter *= 2;
        pxStepSize = _pxStepSizeBase + _consecutiveScrollsCounter;
    }
     */
    
    _msLeftForScroll = _msPerScroll;
    if (scrollDeltaAxis1 > 0) {
        _pixelScrollQueue += pxStepSize * _scrollDirection;
    }
    else if (scrollDeltaAxis1 < 0) {
        _pixelScrollQueue -= pxStepSize * _scrollDirection;
    }

    // reset global vars from momentum phase
    _onePixelScrollsCounter  =   0;
    _pxPerMsVelocity        =   0;
    
    return nil;
}

CVReturn displayLinkCallback (CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext)
{
    
    int32_t pixelsToScroll  = 0;
    double   msBetweenFrames = CVDisplayLinkGetActualOutputVideoRefreshPeriod(_displayLink) * 1000;
    if (msBetweenFrames != 16.674562) {
        NSLog(@"frameTimeHike: %fms", msBetweenFrames);
    }
    CVTime msBetweenFramesNominal = CVDisplayLinkGetNominalOutputVideoRefreshPeriod(_displayLink);
    msBetweenFrames =
    ( ((double)msBetweenFramesNominal.timeValue) / ((double)msBetweenFramesNominal.timeScale) ) * 1000;
    
    
# pragma mark Wheel Phase
    if (_scrollPhase == kMFWheelPhase)
    {
        pixelsToScroll = round( (_pixelScrollQueue/_msLeftForScroll) * msBetweenFrames );
        _pixelScrollQueue   -=  pixelsToScroll;
        _msLeftForScroll    -=  msBetweenFrames;
        
        // TODO: trigger "if statement" if _pixelScrollQueue sign changed?
        
        if ( (_msLeftForScroll <= 0) || (_pixelScrollQueue == 0) )
        {
            _msLeftForScroll    =   0;
            _pixelScrollQueue   =   0;
            
            _scrollPhase = kMFMomentumPhase;
            _pxPerMsVelocity = (pixelsToScroll / msBetweenFrames);
            
        }
    }
    
# pragma mark Momentum Phase
    else if (_scrollPhase == kMFMomentumPhase)
    {
        pixelsToScroll = round(_pxPerMsVelocity * msBetweenFrames);
        
        double oldVel = _pxPerMsVelocity;
        double newVel = oldVel - oldVel * (_frictionCoefficient/100) * msBetweenFrames;
        
        _pxPerMsVelocity = newVel;
        if ( ((newVel < 0) && (oldVel > 0)) || ((newVel > 0) && (oldVel < 0)) ) {
            _pxPerMsVelocity = 0;
        }
        
        if ( (pixelsToScroll == 0) || (_pxPerMsVelocity == 0) )
        {
            CVDisplayLinkStop(_displayLink);
            return 0;
        }
        
        
    }
    if (abs(pixelsToScroll) == 1) {
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

    if (_horizontalScrollModifierPressed == FALSE) {
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis1, pixelsToScroll / 4);
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventPointDeltaAxis1, pixelsToScroll);
    }
    else if (_horizontalScrollModifierPressed == TRUE) {
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis2, pixelsToScroll / 4);
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventPointDeltaAxis2, pixelsToScroll);
    }
    
    CGEventPost(kCGSessionEventTap, scrollEvent);
    CFRelease(scrollEvent);
    
    return 0;
}

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
    
    if (matchingDisplayCount > 0) {
        if (newDisplaysUnderMousePointer[0] != _displaysUnderMousePointer[0]) {
            CVDisplayLinkSetCurrentCGDisplay(_displayLink, _displaysUnderMousePointer[0]);
            _displaysUnderMousePointer = newDisplaysUnderMousePointer;
        }
    }
    else if (matchingDisplayCount == 0) {
        NSException *e = [NSException exceptionWithName:NSInternalInconsistencyException reason:@"there are 0 diplays under the mouse pointer" userInfo:NULL];
        @throw e;
    }
    else if (matchingDisplayCount > 1) {
        NSLog(@"more than one display for current mouse position");
        NSException *e = [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"there are %d diplays under the mouse pointer",matchingDisplayCount] userInfo:NULL];
        @throw e;
    }
}


#pragma mark - helper functions

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
