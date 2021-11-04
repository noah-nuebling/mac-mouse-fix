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
#import "Utility_HelperApp.h"

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
    [ScrollUtility resetConsecutiveTicksAndSwipes];
    [SmoothScroll resetDynamicGlobals];
}

/// Routes the event back to the eventTap where it originally entered the program.
///
/// Use this when internal parameters change while processing an event.
/// This will essentially restart the evaluation of the event while respecting the new internal parameters.
/// You probably wanna return after calling this.
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
    int64_t isPixelBased     = CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous);
    int64_t scrollPhase      = CGEventGetIntegerValueField(event, kCGScrollWheelEventScrollPhase);
    int64_t scrollDeltaAxis1 = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    int64_t scrollDeltaAxis2 = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
    if (isPixelBased != 0
        || scrollDeltaAxis1 == 0
        || scrollDeltaAxis2 != 0
        || scrollPhase != 0) { // Adding scrollphase here is untested
        return event;
    }
    
    // Check if scrolling direction changed
    [ScrollUtility updateScrollDirectionDidChange:scrollDeltaAxis1];
    if (ScrollUtility.scrollDirectionDidChange) {
        [ScrollUtility resetConsecutiveTicksAndSwipes];
    }
    
    // Create a copy, because the original event will become invalid and unusable in the new thread.
//    CGEventRef eventCopy = [Utility_HelperApp createEventWithValuesFromEvent:event]; // This function doesn't work right
//    CGEventRef eventCopy = [ScrollUtility createPixelBasedScrollEventWithValuesFromEvent:event]; // This doesn't either
    CGEventRef eventCopy = CGEventCreateCopy(event);
    // ^ I remember having trouble with the memory / multithreading stuff with this
    //      So I wrote my own createEventWithValuesFrom... function. It doesn't work perfectly either though and caused other troubles.
    //      So we're trying CGEventCreateCopy again, in hopes we wrongly attributed our previous troubles to it. For now it seems fine.
        
    // Do heavy processing of event on a different thread using `dispatch_async`, so we can return faster
    // Returning fast should prevent the system from disabling this eventTap entirely when under load. This doesn't happen in MOS for some reason, maybe there's a better solution than multithreading.
    
    // \discussion With multithreading enabled, scrolling sometimes - seemingly at random - stops working entirely. So the tap still works but sending events doesn't.
    // \discussion - Switching to an app that doesn't have smoothscroll enabled seems to fix it. -> Somethings in my code must be breaking. -> The solution was executing displayLinkActivate() on the main thread, so idk why this happened.
    // \discussion Sometimes the scroll direction is wrong for one tick, seemingly at random. I don't think this happened before the multithreading stuff. Also, I changed other things as well around the time it started happening so not sure if it really has to do with multithreading.
    dispatch_async(_scrollQueue, ^{

        // Set application overrides
        
        [ScrollUtility updateConsecutiveScrollTickAndSwipeCountersWithTickOccurringNow];
        
        if (ScrollUtility.consecutiveScrollTickCounter == 0) { // Only do this on the first of each series of consecutive scroll ticks
            [ScrollUtility updateMouseDidMove];
            if (!ScrollUtility.mouseDidMove) {
                [ScrollUtility updateFrontMostAppDidChange];
                // Only checking this if mouse didn't move, because of || in (mouseMoved || frontMostAppChanged). For optimization. Not sure if significant.
            }
            if (ScrollUtility.mouseDidMove || ScrollUtility.frontMostAppDidChange) {
                // set app overrides
                BOOL configChanged = [ConfigFileInterface_HelperApp updateInternalParameters_Force:NO]; // TODO: `updateInternalParameters_Force:` should (probably) reset stuff itself, if it changes anything. This whole [SmoothScroll stop] stuff is kinda messy
                if (configChanged) {
                    [SmoothScroll stop]; // Not sure if useful
                    [RoughScroll stop]; // Not sure if useful
                }
            }
        }
    
        // Process event
        
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
