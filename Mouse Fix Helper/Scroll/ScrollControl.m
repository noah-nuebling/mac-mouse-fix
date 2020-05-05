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
#import "ConfigFileInterface_HelperApp.h"
#import "ScrollUtility.h"

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

// From config

// consecutive scroll ticks, scrollSwipes, and fast scroll
double _fastScrollExponentialBase;
int    _scrollSwipeThreshold_inTicks;
int    _fastScrollThreshold_inSwipes;
double _consecutiveScrollTickMaxIntervall;
double _consecutiveScrollSwipeMaxIntervall;
+ (double)fastScrollExponentialBase {
    return _fastScrollExponentialBase;
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
    _systemWideAXUIElement = AXUIElementCreateSystemWide();
    // Create Event source
    if (_eventSource == nil) {
        _eventSource = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    }
    // Create/enable scrollwheel input callback
    if (_eventTap == nil) {
        CGEventMask mask = CGEventMaskBit(kCGEventScrollWheel);
        _eventTap = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap /*kCGHeadInsertEventTap*/, kCGEventTapOptionDefault, mask, eventTapCallback, NULL); // Using `kCGTailAppendEventTap` instead of `kCGHeadInsertEventTap` because I think it might help with the bug of 87. It's also how MOS does things. Don't think it helps :'/
        NSLog(@"_eventTap: %@", _eventTap);
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        CGEventTapEnable(_eventTap, false); // Not sure if this does anything
    }
}

+ (void)configureWithParameters:(NSDictionary *)params {
    // How quickly fast scrolling gains speed.
    _fastScrollExponentialBase          =   [[params objectForKey:@"fastScrollExponentialBase"] floatValue]; // 1.05 //1.125 //1.0625 // 1.09375
    // If `_fastScrollThreshold_inSwipes` consecutive swipes occur, fast scrolling is enabled.
    _fastScrollThreshold_inSwipes       =   [[params objectForKey:@"fastScrollThreshold_inSwipes"] intValue];
    // If `_scrollSwipeThreshold_inTicks` consecutive ticks occur, they are deemed a scroll-swipe.
    _scrollSwipeThreshold_inTicks       =   [[params objectForKey:@"scrollSwipeThreshold_inTicks"] intValue]; // 3
    // If more than `_consecutiveScrollSwipeMaxIntervall` seconds passes between two scrollwheel swipes, then they aren't deemed consecutive.
    _consecutiveScrollSwipeMaxIntervall =   [[params objectForKey:@"consecutiveScrollSwipeMaxIntervall"] floatValue];
    // If more than `_consecutiveScrollTickMaxIntervall` seconds passes between two scrollwheel ticks, then they aren't deemed consecutive.
    _consecutiveScrollTickMaxIntervall  =   [[params objectForKey:@"consecutiveScrollTickMaxIntervall"] floatValue]; // == _msPerStep/1000 // oldval:0.03
}

/// When scrolling is in progress, there are tons of variables holding global state. This resets some of them.
/// I determined the ones it resets through trial and error. Some misbehaviour/bugs might be caused by this not resetting all of the global variables.
+ (void)resetDynamicGlobals {
//    _horizontalScrolling    =   NO; // I can't remember why I put this here
//    _magnificationScrolling = NO; // This too. -> TODO: Remove if commenting out didn't break anything
    [ScrollUtility resetConsecutiveTicksAndSwipes];
    [SmoothScroll resetDynamicGlobals];
}

/// Routes the event back to the eventTap where it originally entered the program.
///
/// Use this when internal parameters change while processing an event.
/// This will essentially restart the evaluation of the event while respecting the new internal parameters.
/// You probably wanna return after calliing this.
+ (void)rerouteScrollEventToTop:(CGEventRef)event {
    eventTapCallback(nil, 0, event, nil);
}

/// Either activate SmoothScroll or RoughScroll or stop scroll interception entirely
+ (void)decide {
    BOOL disableAll =
    ![DeviceManager relevantDevicesAreAttached];
    //|| (!_isSmoothEnabled && _scrollDirection == 1);
//    || isEnabled == NO;
    
    if (disableAll) {
        NSLog(@"Disabling scroll interception");
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
            NSLog(@"Enabling SmoothScroll");
            [SmoothScroll start];
            [RoughScroll stop];
        } else {
            NSLog(@"Enabling RoughScroll");
            [SmoothScroll stop];
            [RoughScroll start];
        }
    }
}

#pragma mark - Private functions

static CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    // Return non-scrollwheel events unaltered
    
    long long   isPixelBased            =   CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous);
    long long   scrollPhase             =   CGEventGetIntegerValueField(event, kCGScrollWheelEventScrollPhase);
    long long   scrollDeltaAxis1        =   CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    long long   scrollDeltaAxis2        =   CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
    if (isPixelBased != 0 ||
        scrollDeltaAxis1 == 0 ||
        scrollDeltaAxis2 != 0 ||
        scrollPhase != 0) { // adding scrollphase here is untested
        return event;
    }
    // Create a copy, because the original event will become invalid and unusable in the new thread.
    CGEventRef eventCopy = [ScrollUtility createScrollEventWithValuesFromEvent:event];
        
    // Do heavy processing of event on a different thread using `dispatch_async`, so we can return faster
    // Returning fast should prevent the system from disabling this eventTap entirely when under load
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
    
        // Check if scrolling direction changed
        
        [ScrollUtility updateScrollDirectionDidChange:scrollDeltaAxis1];
        
        if (ScrollUtility.scrollDirectionDidChange) {
            [ScrollUtility resetConsecutiveTicksAndSwipes];
        }
        
        // Set application overrides
        
        [ScrollUtility updateConsecutiveScrollTickAndSwipeCountersWithTickOccuringNow];
        
        if (ScrollUtility.consecutiveScrollTickCounter == 0) { // Only do this on the first of each series of consecutive scroll ticks
            [ScrollUtility updateMouseDidMove];
            if (!ScrollUtility.mouseDidMove) {
                [ScrollUtility updateFrontMostAppDidChange];
                // Only checking this if mouse didn't move, because of || in (mouseMoved || frontMostAppChanged). For optimization. Not sure if significant.
            }
            if (ScrollUtility.mouseDidMove || ScrollUtility.frontMostAppDidChange) {
                // set app overrides
                [ConfigFileInterface_HelperApp updateInternalParameters_Force:NO];
            }
        }
    
    // Process event
        
        if (_isSmoothEnabled) {
            [SmoothScroll handleInput:eventCopy info:NULL];
        } else {
            [RoughScroll handleInput:eventCopy info:NULL];
        }
        CFRelease(eventCopy);
    });
    
    return nil;
}

@end
