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
static BOOL _horizontalScrolling; // TODO: Consider moving this stuff into ScrollModifiers.m
+ (BOOL)horizontalScrolling {
    return _horizontalScrolling;
}
+ (void)setHorizontalScrolling:(BOOL)B {
    _horizontalScrolling = B;
}
static BOOL _magnificationScrolling;
+ (BOOL)magnificationScrolling {
    return _magnificationScrolling;
}
+ (void)setMagnificationScrolling:(BOOL)B { // TODO: This is called every time the user presses command. Check if efficient. Maybe only do this stuff, if the user actually scrolls before releasing command.
    if (_magnificationScrolling && !B) { // Magnification scrolling is being turned off
//        if (_scrollPhase != kMFPhaseEnd) {
            [TouchSimulator postEventWithMagnification:0.0 phase:kIOHIDEventPhaseEnded]; // These events are sent every time the user presses command while a relevant device is attached. Might want to change this.
//            [TouchSimulator postEventWithMagnification:0.0 phase:kIOHIDEventPhaseBegan];
//            [TouchSimulator postEventWithMagnification:0.0 phase:kIOHIDEventPhaseEnded];
//        }
    } else if (!_magnificationScrolling && B) { // Magnification scrolling is being turned on
        if (SmoothScroll.isRunning) { // Restarting SmoothScroll to avoid immediate zooming when pressing command while scrolling.
            [SmoothScroll stop];
            [SmoothScroll start];
        }
//        if (_scrollPhase == kMFPhaseMomentum || _scrollPhase == kMFPhaseWheel) {
            [TouchSimulator postEventWithMagnification:0.0 phase:kIOHIDEventPhaseBegan];
//        }
    }
    _magnificationScrolling = B;
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
    
    // Process event
    
    /// (Multithreading stuff described below doesn't work, yet. It somehow leads to the events being "invalidated")
    /// Possible reasons and solutions:
    /// I think events might be invalidated after this function returns. Or maybe when they're used on a different thread than the one they were created on or something like that. The `CGEventGet...` functions log "Invalid event." - so maybe an "invalid event" is just nil? Nope, testing says no. There might be some data field in the event that restricts its usage to specific situations.
    /// Creating new events and copying relevant fields over might resolve this issue.
    
    // Do prcessing of event on a different thread using `dispatch_async`, so we can return faster
    // Returning fast should prevent the system from disabling this eventTap entirely when under load
//    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
       
        /// Regarding the "invalid Event" error when trying to use `dispatch_async`. I thought maybe the original event was freed after `eventTapCallback()` returned and that that might have caused the issue, so I created a copy named `newEvent` here. This led to different errors as far as I remember, which might be a valuable lead, but it still didn't work. There might be some data field in the event that restricts its usage to specific situations which isn't copied or.
//        CGEventRef newEvent = CGEventCreateCopy(event);
        
        // `info` dictionary is used to pass data to the input handlers, so that we don't have to calculate stuff twice.
        NSDictionary *info;
        if (_isSmoothEnabled) {
            info = @{
                @"scrollDeltaAxis1": [NSNumber numberWithLongLong:scrollDeltaAxis1]
            };
            
            /// TODO: Remove the dispatch_async stuff below. It's just for testing.
            /// Testing reveals: Multi threading does seem to prevent the eventTap from breaking. Yay! Now we just need to get it working properly...
//            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
                [SmoothScroll handleInput:event info:info];
//            });
        } else {
            info = @{};
            [RoughScroll handleInput:event info:info];
        }
//    });
    
    return nil;
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
        _eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, eventTapCallback, NULL);
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

@end
