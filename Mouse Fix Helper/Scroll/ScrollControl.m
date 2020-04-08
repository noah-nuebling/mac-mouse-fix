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

@implementation ScrollControl

#pragma mark - Private variables

static CFMachPortRef _eventTap       =   nil;

#pragma mark - Public variables

#pragma mark Parameters

// Constants
static AXUIElementRef _systemWideAXUIElement;
+ (AXUIElementRef) systemWideAXUIElement {
    return _systemWideAXUIElement;
}
static CGEventSourceRef _eventSource = nil;
+ (CGEventSourceRef)eventSource {
    return _eventSource;
}

// TODO: migrate consecutiveScrollTick functions and variables from SmoothScroll to ScrollControl
// From config
//static float _consecutiveScrollTickMaxIntervall; // Should only be set by - updateInternalParameters.
//// Originally part of the SmoothScroll.m, but we also need this for AppOverride loading optimization in RoughScroll.m. Sibling parameters like _consecutiveScrollSwipeMaxIntervall are still in SmoothScroll.m
//+ (float)consecutiveScrollTickMaxIntervall {
//    return _consecutiveScrollTickMaxIntervall;
//}
//+ (void)setConsecutiveScrollTickMaxIntervall:(float)inp {
//    _consecutiveScrollTickMaxIntervall = inp;
//}

#pragma mark - Dynamic

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
static BOOL _horizontalScrolling;
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
+ (void)setMagnificationScrolling:(BOOL)B {
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


+ (CGEventRef)routeToTop:(CGEventRef)event { // TODO: Put this in a spot that makes sense
    return eventTapCallback(nil, 0, event, nil);
}

#pragma mark - Private functions

static CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
//    NSLog(@"scrollPhase: %lld", CGEventGetIntegerValueField(event, kCGScrollWheelEventScrollPhase));
//    NSLog(@"momentumPhase: %lld", CGEventGetIntegerValueField(event, kCGScrollWheelEventMomentumPhase));
    
//        CFTimeInterval ts = CACurrentMediaTime();
//            NSLog(@"event tap bench: %f", CACurrentMediaTime() - ts);
    
    // Return non-scroll-wheel events unaltered
    
    long long   isPixelBased            =   CGEventGetIntegerValueField(event, kCGScrollWheelEventIsContinuous);
    long long   scrollPhase             =   CGEventGetIntegerValueField(event, kCGScrollWheelEventScrollPhase);
    long long   scrollDeltaAxis1        =   CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    long long   scrollDeltaAxis2        =   CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
    if ( (isPixelBased != 0) || (scrollDeltaAxis1 == 0) || (scrollDeltaAxis2 != 0) || (scrollPhase != 0)) { // adding scrollphase here is untested
        // scroll event doesn't come from a simple scroll wheel or doesn't contain the data we need to use
        return event;
    }
    
    // `info` dictionary is used to pass data to the input handlers, so that we don't have to calculate stuff twice.
    NSDictionary *info;
    if (_isSmoothEnabled) {
        info = @{
            @"scrollDeltaAxis1": [NSNumber numberWithLongLong:scrollDeltaAxis1]
        };
        return [SmoothScroll handleInput:event info:info];
    } else {
        info = @{};
        return [RoughScroll handleInput:event info:info];
    }
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

/// When scrolling is in progress, there are tons of variables holding global state. This resets some of them.
/// I determined the ones it resets through trial and error. Some misbehaviour/bugs might be caused by this not resetting all of the global variables.
+ (void)resetDynamicGlobals {
    _horizontalScrolling    =   NO;
    _magnificationScrolling = NO;
    [SmoothScroll resetDynamicGlobals];
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
