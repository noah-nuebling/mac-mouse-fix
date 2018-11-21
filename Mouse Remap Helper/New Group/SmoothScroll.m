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

static BOOL _bezierScroll = TRUE;
static int64_t _pxStepSizeBase = 76;
static int64_t _pxStepSizeMax = 5000;
static float _scrollStepSizeAddent = 0;  // this is only used when we've been continuously scrolling for a while
static int64_t _fastScrollThreshold_asConsequtiveScrollsAtMaxSmoothing = 35;
//
static float _msPerScrollBase = 250;
static float _msPerScrollMax = 250;
static float _continuousScrollSmoothingFactor = 1.09;



//static float _msPerScrollMaxBase = 400;     // longer deceleration at high speed
//static float _msPerScrollMax = 0;          //

//
static int64_t _consequtiveScrollsAtMaxSmoothing = 0;
static float _msPerScroll = 0;
static int64_t   _pxStepSize = 0;
static int64_t _pixelScrollQueue = 0;
static float _msLeftForScroll = 0;
static float _msBetweenFrames = 0;
//
static CVDisplayLinkRef _displayLink;
CGEventSourceRef _eventSource = nil;
//
AnimationCurve * _animationCurve;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _animationCurve = [[AnimationCurve alloc] init];
        [_animationCurve UnitBezierForPoint1x:0.2 point1y:0.2 point2x:0.2 point2y:1.0];
              //
        _eventSource = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
        
        //
        CVDisplayLinkCreateWithCGDisplay(CGMainDisplayID(), &_displayLink);
        CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, nil);
        CVDisplayLinkStart(_displayLink);
        
        //
    }
    return self;
}

- (void)start {
    
    // setup eventTap
    CGEventMask mask = CGEventMaskBit(kCGEventScrollWheel);
    CFMachPortRef eventTap = CGEventTapCreate(kCGAnnotatedSessionEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, mask, eventTapCallback, NULL);
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(eventTap, true);
    
    // setup display refresh callback
    CVDisplayLinkRef displayLink;
    CVDisplayLinkCreateWithCGDisplay(CGMainDisplayID(), &displayLink);
    CVDisplayLinkSetOutputCallback(displayLink, displayLinkCallback, nil);
    
}


#pragma mark - run Loop

CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {

    long long scrollPhase   =   CGEventGetIntegerValueField(event, kCGScrollWheelEventScrollPhase);
    long long isContinuous  =   CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous);
    long long momentumPhase =   CGEventGetIntegerValueField(event, kCGScrollWheelEventMomentumPhase);
    
    if ( (scrollPhase != 0) || (isContinuous != 0) || (momentumPhase != 0) ) {
        // scroll event doesn't come from simple scroll wheel
        return event;
     }
    
    int64_t scrollDeltaAxis1    =   CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    
    BOOL scrollEventFollowsCurrentScrollingDirection
    = (scrollDeltaAxis1 >= 0 && _pixelScrollQueue > 0) || (scrollDeltaAxis1 <= 0 && _pixelScrollQueue < 0);
    
    if (
        (_bezierScroll   == FALSE)                             ||
        CVDisplayLinkIsRunning(_displayLink) == FALSE          ||
        scrollEventFollowsCurrentScrollingDirection == FALSE
        )
    {
        CVDisplayLinkStart(_displayLink);
        _msPerScroll    =   _msPerScrollBase;
        _pxStepSize     =   _pxStepSizeBase;
        // _msPerScrollMax = _msPerScrollMaxBase;                   // longer deceleration at high speed
    }
    else {
        _msPerScroll        *=  _continuousScrollSmoothingFactor; //6 * (_msInThisContinuousScroll/_msPerScrollBase);
        if (_msPerScroll > _msPerScrollMax) {
            _msPerScroll    =   _msPerScrollMax;
        }
        // activate acceleration, after a few scrolls at max smoothing
        if (_msPerScroll == _msPerScrollMax) {
            _consequtiveScrollsAtMaxSmoothing += 1;
            if (_consequtiveScrollsAtMaxSmoothing > _fastScrollThreshold_asConsequtiveScrollsAtMaxSmoothing) {
                //NSLog(@"_consequtiveScrollsAtMaxSmoothing: %d", _consequtiveScrollsAtMaxSmoothing);
                _pxStepSize         += _scrollStepSizeAddent;
                if (_pxStepSize > _pxStepSizeMax) {
                    _pxStepSize = _pxStepSizeMax;
                }
                
                //_msPerScrollMax += 12;                              // longer deceleration at high speed
                //if (_msPerScrollMax > 2000) {                       //
                //    _msPerScrollMax = 2000;                         //
                //}
            }
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
    
    
    NSLog(@"_msPerScroll: %f", _msPerScroll);
    NSLog(@"_pxStepSize : %d", _pxStepSize);
    
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
    if (_bezierScroll == FALSE) {
        // linear scrolling
        float pixelsPerMillisec =   ((float)_pixelScrollQueue/(float)_msLeftForScroll);
        pixelsToScroll          =   round(pixelsPerMillisec * _msBetweenFrames);
    }
    else {
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
    
    
        
        
    }
    
    
    // send scroll event
    CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(_eventSource, kCGScrollEventUnitPixel, 1, - pixelsToScroll);
    //CGEventSetIntegerValueField(scrollEvent, kCGScrollWheelEventIsContinuous, 1);
    CGEventPost(kCGHIDEventTap, scrollEvent);
    
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
