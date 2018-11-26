//
//  SmoothScroll.m
//  ScrollFix Playground in OBJC weil Swift STINKT
//
//  Created by Noah Nübling on 06.11.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import "MomentumScroll.h"
#import "QuartzCore/CoreVideo.h"


@interface MomentumScroll ()

@end

@implementation MomentumScroll

#pragma mark - Global Vars


#pragma mark - Global Vars

# pragma mark properties

// there are 3 classes and 3 global variables involved in turning on/off MomentumScroll:
// InputReceiver and ConfigFileMonitor can enable/disable MomentumScroll
// Input Receiver sets relevantDevicesAreAttached, ConfigFileMonitor sets isEnabled (defined below), and MomentumScroll sets isRunning
// Based on these 3 variables ConfigFileMonitor and InputReceiver decide whether to enable / disable MomentumScroll when the config file changes or a mouse is attached / removed
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
static int64_t  _pxStepSize;
static double   _msPerScroll;
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
BOOL  _horizontalScrollModifierPressed;
// wheel phase
static int64_t  _pixelScrollQueue       =   0;
static double   _msLeftForScroll        =   0;
// momentum phase
static double   _pxPerMsVelocity        =   0;
static int      _onePixelScrollsCounter =   0;

#pragma mark - Interface


+ (void)configureWithPxPerStep:(int)px
                 msPerStep:(int)ms
                  friction:(float)f
{
    _pxStepSize                         =   px;
    _msPerScroll                        =   ms;
    _frictionCoefficient                =   f;
    
    _nOfOnePixelScrollsMax              =   2;
}

+ (void)start {
    
    NSLog(@"MomentumScroll started");
    
    _isRunning = TRUE;
    
    _horizontalScrollModifierPressed    =   NO;
    _scrollPhase                        =   kMFWheelPhase;
    _pixelScrollQueue                   =   0;
    _msLeftForScroll                    =   0;
    _pxPerMsVelocity                    =   0;
    _onePixelScrollsCounter             =   0;
    
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
    }
    if (_eventTap) {
        CGEventTapEnable(_eventTap, false);
        CFRelease(_eventTap);
        _eventTap = nil;
    }
    if (_eventSource) {
        CFRelease(_eventSource);
        _eventSource = nil;
     }
    
     CGDisplayRemoveReconfigurationCallback(Handle_displayReconfiguration, NULL);
}

+ (void)setHorizontalScroll:(BOOL)B {
    _horizontalScrollModifierPressed = B;
}



#pragma mark - Run Loop

CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    
    long long   isPixelBased        =   CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous);
    int64_t     scrollDeltaAxis1    =   CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    int64_t     scrollDeltaAxis2    =   CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
    
    if ( (isPixelBased != 0) || (scrollDeltaAxis1 == 0) || (scrollDeltaAxis2 != 0)) {
        // scroll event doesn't come from a simple scroll wheel
        return event;
    }
    
    if (CVDisplayLinkIsRunning(_displayLink) == FALSE) {
        CVDisplayLinkStart(_displayLink);
    }
    CGPoint mouseLocation = CGEventGetLocation(event);
    CGDirectDisplayID *displaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID) * 3);
    uint32_t matchingDisplayCount;
    CGGetDisplaysWithPoint(mouseLocation, 2, displaysUnderMousePointer, &matchingDisplayCount);
    if (matchingDisplayCount > 0) {
        CVDisplayLinkSetCurrentCGDisplay(_displayLink, displaysUnderMousePointer[0]);
    }
    else if (matchingDisplayCount == 0) {
        NSLog(@"no display for current Mouse Position");
        CFRelease(displaysUnderMousePointer);
        return event;
    }
    if (matchingDisplayCount > 1) {
        NSLog(@"more than one display for current mouse position");
    }
    
    if (_scrollPhase == kMFMomentumPhase) {
        _pixelScrollQueue = 0;
    }
    _scrollPhase = kMFWheelPhase;
    
    // update global vars for wheel phase
    _msLeftForScroll = _msPerScroll;
    if (scrollDeltaAxis1 > 0) {
        _pixelScrollQueue += _pxStepSize;
    }
    else if (scrollDeltaAxis1 < 0) {
        _pixelScrollQueue -= _pxStepSize;
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
    //CGEventSourceSetPixelsPerLine(_eventSource, 1);

    if (_horizontalScrollModifierPressed == FALSE) {
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis1, - pixelsToScroll / 4);
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventPointDeltaAxis1, - pixelsToScroll);
    }
    else if (_horizontalScrollModifierPressed == TRUE) {
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis2, - pixelsToScroll / 4);
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventPointDeltaAxis2, - pixelsToScroll);
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


#pragma mark - helper functions

@end
