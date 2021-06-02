//
// --------------------------------------------------------------------------
// ScrollControl.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ScrollControl.h"
#import "DeviceManager.h"
#import "SmoothScroll.h"
#import "RoughScroll.h"
#import "TouchSimulator.h"
#import "ScrollModifiers.h"
#import "MainConfigInterface.h"
#import "ScrollUtility.h"
#import "Utility_Helper.h"
#import "WannabePrefixHeader.h"
#import "ScrollAnalyzer.h"

@implementation ScrollControl

#pragma mark - Private variables

static CFMachPortRef _eventTap       =   nil;

#pragma mark - Public variables

#pragma mark Parameters

// Constant

static AXUIElementRef _systemWideAXUIElement;
+ (AXUIElementRef) systemWideAXUIElement {
    return _systemWideAXUIElement;
}
static CGEventSourceRef _eventSource = nil;
+ (CGEventSourceRef)eventSource {
    return _eventSource;
}
static dispatch_queue_t _scrollQueue;
+ (dispatch_queue_t)_scrollQueue {
    return _scrollQueue;
}

// From config

// consecutive scroll ticks, scrollSwipes, and fast scroll
double _fastScrollExponentialBase;
double _fastScrollFactor;
int    _scrollSwipeThreshold_inTicks;
int    _fastScrollThreshold_inSwipes;
double _consecutiveScrollTickMaxIntervall;
double _consecutiveScrollSwipeMaxIntervall;
+ (double)fastScrollExponentialBase {
    return _fastScrollExponentialBase;
}
+ (double)fastScrollFactor {
    return _fastScrollFactor;
}
+ (int)scrollSwipeThreshold_inTicks {
    return _scrollSwipeThreshold_inTicks;
}
+ (double)fastScrollThreshold_inSwipes {
    return _fastScrollThreshold_inSwipes;
}
+ (double)consecutiveScrollTickMaxIntervall {
    return _consecutiveScrollTickMaxIntervall;
}
+ (double)consecutiveScrollSwipeMaxIntervall {
    return _consecutiveScrollSwipeMaxIntervall;
}

#pragma mark Dynamic vars

static BOOL _isSmoothEnabled;
+ (BOOL)isSmoothEnabled {
    return _isSmoothEnabled;
}
+ (void)setIsSmoothEnabled:(BOOL)B {
    _isSmoothEnabled = B;
}
// TODO: Change type to MFScrollDirection
static int _scrollDirection;
+ (int)scrollDirection {
    return _scrollDirection;
}
+ (void)setScrollDirection:(int)dir {
    _scrollDirection = dir;
}

#pragma mark - Public functions

+ (void)load_Manual {
    
    [SmoothScroll load_Manual];
    
    // Create custom dispatch queue for multithreading while still retaining control over execution order.
    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, -1);
    _scrollQueue = dispatch_queue_create(NULL, attr);
    
    // Create AXUIElement for getting app under mouse pointer
    _systemWideAXUIElement = AXUIElementCreateSystemWide();
    // Create Event source
    if (_eventSource == nil) {
        _eventSource = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    }
    // Create/enable scrollwheel input callback
    if (_eventTap == nil) {
        CGEventMask mask = CGEventMaskBit(kCGEventScrollWheel);
        _eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, eventTapCallback, NULL);
        DDLogInfo(@"_eventTap: %@", _eventTap);
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        CGEventTapEnable(_eventTap, false); // Not sure if this does anything
    }
}

+ (void)configureWithParameters:(NSDictionary *)params {
    // How quickly fast scrolling gains speed.
    _fastScrollExponentialBase          =   [params[@"fastScrollExponentialBase"] doubleValue]; // 1.05 //1.125 //1.0625 // 1.09375
    _fastScrollFactor                   =   [params[@"fastScrollFactor"] doubleValue];
    // If `_fastScrollThreshold_inSwipes` consecutive swipes occur, fast scrolling is enabled.
    _fastScrollThreshold_inSwipes       =   [params[@"fastScrollThreshold_inSwipes"] intValue];
    // If `_scrollSwipeThreshold_inTicks` consecutive ticks occur, they are deemed a scroll-swipe.
    _scrollSwipeThreshold_inTicks       =   [params [@"scrollSwipeThreshold_inTicks"] intValue]; // 3
    // If more than `_consecutiveScrollSwipeMaxIntervall` seconds passes between two scrollwheel swipes, then they aren't deemed consecutive.
    _consecutiveScrollSwipeMaxIntervall =   [params[@"consecutiveScrollSwipeMaxIntervall"] doubleValue];
    // If more than `_consecutiveScrollTickMaxIntervall` seconds passes between two scrollwheel ticks, then they aren't deemed consecutive.
    _consecutiveScrollTickMaxIntervall  =   [params[@"consecutiveScrollTickMaxIntervall"] doubleValue]; // == _msPerStep/1000 // oldval:0.03
}

/// When scrolling is in progress, there are tons of variables holding global state. This resets some of them.
/// I determined the ones it resets through trial and error. Some misbehaviour/bugs might be caused by this not resetting all of the global variables.
+ (void)resetDynamicGlobals {
//    _horizontalScrolling    =   NO; // I can't remember why I put this here
//    _magnificationScrolling = NO; // This too. -> TODO: Remove if commenting out didn't break anything
    [ScrollAnalyzer resetConsecutiveTicksAndSwipes];
    [SmoothScroll resetDynamicGlobals];
}

/// Routes the event back to the eventTap where it originally entered the program.
///
/// Use this when internal parameters change while processing an event.
/// This will essentially restart the evaluation of the event while respecting the new internal parameters.
/// You probably wanna return after calliing this.
// TODO: This shouldn't be neede anymore. Delete if so.
+ (void)rerouteScrollEventToTop:(CGEventRef)event {
    eventTapCallback(nil, 0, event, nil);
}

/// Either activate SmoothScroll or RoughScroll or stop scroll interception entirely
/// Call this whenever a value which the decision depends on changes
+ (void)decide {
    BOOL disableAll =
    ![DeviceManager devicesAreAttached];
    //|| (!_isSmoothEnabled && _scrollDirection == 1);
//    || isEnabled == NO;
    
    if (disableAll) {
        DDLogInfo(@"Disabling scroll interception");
        // Disable scroll interception
        if (_eventTap) {
            CGEventTapEnable(_eventTap, false);
        }
        // Disable other scroll classes
        [SmoothScroll stop];
        [RoughScroll stop];
        [ScrollModifiers stop];
    } else {
        // Enable scroll interception
        CGEventTapEnable(_eventTap, true);
        // Enable other scroll classes
        [ScrollModifiers start];
        if (_isSmoothEnabled) {
            DDLogInfo(@"Enabling SmoothScroll");
            [SmoothScroll start];
            [RoughScroll stop];
        } else {
            DDLogInfo(@"Enabling RoughScroll");
            [SmoothScroll stop];
            [RoughScroll start];
        }
    }
}

#pragma mark - Private functions

static CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    // Handle eventTapDisabled messages
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        
        if (type == kCGEventTapDisabledByUserInput) {
            DDLogInfo(@"ScrollControl eventTap was disabled by timeout. Re-enabling");
            CGEventTapEnable(_eventTap, true);
        } else if (type == kCGEventTapDisabledByUserInput) {
            DDLogInfo(@"ScrollControl eventTap was disabled by user input.");
        }
        
        return event;
    }
    
    // Return non-scrollwheel events unaltered
    int64_t isPixelBased     = CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous);
    int64_t scrollPhase      = CGEventGetIntegerValueField(event, kCGScrollWheelEventScrollPhase);
    int64_t scrollDeltaAxis1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    int64_t scrollDeltaAxis2 = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
    bool isDiagonal = scrollDeltaAxis1 != 0 && scrollDeltaAxis2 != 0;
    if (isPixelBased != 0
        || isDiagonal // Ignore diagonal scroll-events
        || scrollPhase != 0) { // Adding scrollphase here is untested
        return event;
    }
    
    // Create a copy, because the original event will become invalid and unusable in the new thread.
    CGEventRef eventCopy = CGEventCreateCopy(event);
        
    //  Executing heavy stuff on a different thread to prevent the eventTap from timing out. We wrote this before knowing that you can just re-enable the eventTap when it times out. But this doesn't hurt.
    
    dispatch_async(_scrollQueue, ^{

        // Check if scroll dir changed
        //   Reset tick and swipe counters if yes
        [ScrollAnalyzer updateScrollDirectionDidChange:scrollDeltaAxis1];
        if (ScrollAnalyzer.scrollDirectionDidChange) {
            [ScrollAnalyzer resetConsecutiveTicksAndSwipes];
        }
        
        /*
         Update tick and swipe counters
            Need to updating here in the scrollQueue instead of in the eventTapCallback so that the calls aren't out of sync with the _scrollQueue.
            Calling it here leads to less accurate measured time between ticks, but the intervall between different eventTapCallback calls is very erratic and seemingly not accurate anyways, so it shouldn't make a big difference.
         */
        [ScrollAnalyzer updateConsecutiveScrollTickAndSwipeCountersWithTickOccuringNow];
        
        // Set application overrides
        
        if (ScrollAnalyzer.consecutiveScrollTickCounter == 0) { // Only do this on the first of each series of consecutive scroll ticks
            [ScrollUtility updateMouseDidMove];
            if (!ScrollUtility.mouseDidMove) {
                [ScrollUtility updateFrontMostAppDidChange];
                // Only checking this if mouse didn't move, because of || in (mouseMoved || frontMostAppChanged). For optimization. Not sure if significant.
            }
            if (ScrollUtility.mouseDidMove || ScrollUtility.frontMostAppDidChange) {
                // set app overrides
                BOOL configChanged = [MainConfigInterface applyOverridesForAppUnderMousePointer_Force:NO]; // TODO: `updateInternalParameters_Force:` should (probably) reset stuff itself, if it changes anything. This whole [SmoothScroll stop] stuff is kinda messy
                if (configChanged) {
                    [SmoothScroll stop]; // Not sure if useful
                    [RoughScroll stop]; // Not sure if useful
                }
            }
        }
    
        // Process event
        
        int16_t pxToScrollForThisTick = scrollDeltaAxis1;
        
        if (_isSmoothEnabled) {
            [SmoothScroll start];   // Not sure if useful
            [RoughScroll stop];     // Not sure if useful
            [SmoothScroll handleInput:eventCopy info:NULL];
        } else {
            [SmoothScroll stop];
            [RoughScroll start];
            [RoughScroll handleInput:eventCopy info:NULL];
        }
        CFRelease(eventCopy);
    });
    return nil;
}



@end
