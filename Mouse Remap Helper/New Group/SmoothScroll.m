//
//  SmoothScroll.m
//  ScrollFix Playground in OBJC weil Swift STINKT
//
//  Created by Noah Nübling on 06.11.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import "SmoothScroll.h"
#import "QuartzCore/CoreVideo.h"
#import "AnimationCurve.h"


@interface SmoothScroll ()

@end


@implementation SmoothScroll

#pragma mark - consts and init()
// settings
static int64_t _pxStepSizeBase = 76;
//
static float _msPerScrollBase = 250;
static float _msPerScrollMax = 250;
static float _continuousScrollSmoothingFactor = 1.09;



//
static int64_t _consequtiveScrollsAtMaxSmoothing = 0;
static float _msPerScroll = 0;
static int64_t   _pxStepSize = 0;
static int64_t _pixelScrollQueue = 0;
static float _msLeftForScroll = 0;
static float _msBetweenFrames = 0;

//
static CVDisplayLinkRef _displayLink = nil;
static CFMachPortRef _eventTap = nil;
static CGEventSourceRef _eventSource = nil;
//
AnimationCurve * _animationCurve;


BOOL _horizontalScrollModifierPressed;
+ (void) setHorizontalScroll: (BOOL)B {
    NSLog(@"HORIZONTAL SCROLL SET: %d", B);
    _horizontalScrollModifierPressed = B;
}

+ (void) stop {
    enable(FALSE);
    
    if (_displayLink) {
        CVDisplayLinkRelease(_displayLink);
        _displayLink = nil;
    }
    if (_eventTap) {
        CFRelease(_eventTap);
        _eventTap = nil;
    }
    if (_eventSource) {
        CFRelease(_eventSource);
        _eventSource = nil;
     }
    
}
+ (void)startWithAnimationCurve:(AnimationCurve *)curve
                      pxPerStep:(int)pxB
                         msBase:(int)msB
                          msMax:(int)msM
                       msFactor:(float)msF
{
    _animationCurve                     =   curve;
    _pxStepSizeBase                     =   pxB;
    _msPerScrollBase                    =   msB;
    _msPerScrollMax                     =   msM;
    _continuousScrollSmoothingFactor    =   msF;


    
    _horizontalScrollModifierPressed = FALSE;
    
    if (_eventTap == nil) {
        CGEventMask mask = CGEventMaskBit(kCGEventScrollWheel);
        _eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, eventTapCallback, NULL);
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
    }
    if (_displayLink == nil) {
        CVDisplayLinkCreateWithCGDisplay(CGMainDisplayID(), &_displayLink);
        CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, nil);
    }
    if (_eventSource == nil) {
        _eventSource = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    }
    
    enable(TRUE);
}


static void enable(BOOL B) {
    
    if (_eventTap != nil) {
        if (B) {
            CGEventTapEnable(_eventTap, true);
        }
        else {
            CGEventTapEnable(_eventTap, false);
        }
    }
    
    if (_displayLink != nil) {
        if (B) {
            CVDisplayLinkStart(_displayLink);
        }
        else {
            CVDisplayLinkStop(_displayLink);
        }
    }
    
}


#pragma mark - run Loop

CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {

    
    long long isContinuous  =   CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous);
    
    int64_t scrollDeltaAxis1    =   CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    
    // (scrollPhase != 0) || (isContinuous != 0) || (momentumPhase != 0)
    
    if ( (isContinuous != 0) || (scrollDeltaAxis1 == 0) ) {
        // scroll event doesn't come from simple scroll wheel
        return event;
    }
    
    BOOL scrollEventFollowsCurrentScrollingDirection
    = (scrollDeltaAxis1 >= 0 && _pixelScrollQueue > 0) || (scrollDeltaAxis1 <= 0 && _pixelScrollQueue < 0);
    
    if (
        CVDisplayLinkIsRunning(_displayLink) == FALSE          ||
        scrollEventFollowsCurrentScrollingDirection == FALSE
        )
    {
        CVDisplayLinkStart(_displayLink);
        _msPerScroll    =   _msPerScrollBase;
        _pxStepSize     =   _pxStepSizeBase;
    }
    else {
        _msPerScroll        *=  _continuousScrollSmoothingFactor;
        if (_msPerScroll > _msPerScrollMax) {
            _msPerScroll    =   _msPerScrollMax;
        }
        else {
            _consequtiveScrollsAtMaxSmoothing = 0;
        }
    }
    _msLeftForScroll = _msPerScroll;
    
    
    if (scrollDeltaAxis1 > 0) {
        _pixelScrollQueue += _pxStepSize;
    }
    else if (scrollDeltaAxis1 < 0) {
        _pixelScrollQueue -= _pxStepSize;
    }
    
    return nil;
}

CVReturn displayLinkCallback (CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext) {
    
    
    //NSLog(@"_msPerScroll: %f", _msPerScroll);
    //NSLog(@"_pxStepSize : %d", _pxStepSize);
    
    // gets called every time the display is refreshed
    
    
    if ( (_msLeftForScroll <= 0) || (_pixelScrollQueue == 0) ) {
        _msLeftForScroll    =   0;
        _pixelScrollQueue   =   0;
        _msPerScroll        =  _msPerScrollBase;
        _pxStepSize         =  _pxStepSizeBase;
        CVDisplayLinkStop(displayLink);
        return 0;
    }
    
    
    _msBetweenFrames = CVDisplayLinkGetActualOutputVideoRefreshPeriod(_displayLink) * 1000;
    
    int32_t pixelsToScroll;

    // curve based scrolling
    CGFloat completedScrollTimeFractionNow // fraction of _msPerScroll weve "used up"
    = ((CGFloat)(_msPerScroll - _msLeftForScroll)) / ((CGFloat)_msPerScroll);
    CGFloat completedScrollTimeFractionNextFrame
    = (CGFloat)(_msPerScroll - (_msLeftForScroll-_msBetweenFrames)) / ((CGFloat)_msPerScroll);

    // calculate offset at this point during the animation - offset is in (0..1)
    double animationOffsetNow           =   [_animationCurve solve:completedScrollTimeFractionNow epsilon:0.008];
    double animationOffsetNextFrame     =   [_animationCurve solve:completedScrollTimeFractionNextFrame epsilon:0.008];
    float  animationOffsetToNextFrame   =   animationOffsetNextFrame - animationOffsetNow;
    float  animationOffsetLeft          =   1 - animationOffsetNow; // distance to maximal offset value (1)
    
    pixelsToScroll = round( (_pixelScrollQueue/animationOffsetLeft) * animationOffsetToNextFrame );
    
    
        
        
    
    
    
    // send scroll event
    //int scrollVal = 2;
    //NSLog(@"pixelsPerLine: %f", CGEventSourceGetPixelsPerLine(_eventSource));
    CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(_eventSource, kCGScrollEventUnitPixel, 1, 0);

    if (_horizontalScrollModifierPressed == FALSE) {
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis1, - pixelsToScroll / 4);
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventPointDeltaAxis1, - pixelsToScroll);
    }
    else if (_horizontalScrollModifierPressed == TRUE) {
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventDeltaAxis2, - pixelsToScroll / 4);
        CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventPointDeltaAxis2, - pixelsToScroll);
    }
    
    //CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventIsContinuous, 0);
    CGEventPost(kCGSessionEventTap, scrollEvent);
    CFRelease(scrollEvent);
    
    _pixelScrollQueue   -=  pixelsToScroll;
    _msLeftForScroll    -=  _msBetweenFrames;
    
    return 0;
}


@end










/*
 int64_t scrollDeltaAxis1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
 int64_t scrollDeltaAxis1Pixel = CGEventGetIntegerValueField(event, kCGScrollWheelEventPointDeltaAxis1);
 double scrollDeltaAxis1Float = CGEventGetDoubleValueField(event, kCGScrollWheelEventFixedPtDeltaAxis1);
 
 NSLog(@"scrollDeltaAxis1: %lld", scrollDeltaAxis1);
 NSLog(@"scrollDeltaAxis1Pixel: %lld", scrollDeltaAxis1Pixel);
 NSLog(@"scrollDeltaAxis1Float: %f", scrollDeltaAxis1Float * 10);
 */
