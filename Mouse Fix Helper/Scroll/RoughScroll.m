//
// --------------------------------------------------------------------------
// RoughScroll.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "RoughScroll.h"
#import "ScrollControl.h"
#import "TouchSimulator.h"
#import "ScrollUtility.h"

@implementation RoughScroll

#pragma mark - Globals

static CFMachPortRef _eventTap;

// TODO: Should this be load or load_Manual? I can't remember why I used load_Manual everywhere?
+ (void)load {
    if (_eventTap == nil) {
        CGEventMask mask = CGEventMaskBit(kCGEventScrollWheel);
        _eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, eventTapCallback, NULL);
        NSLog(@"_eventTap: %@", _eventTap);
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        CGEventTapEnable(_eventTap, false); // not sure if necessary
    }
}

+ (void)start {
    CGEventTapEnable(_eventTap, true);
}

+ (void)stop {
    CGEventTapEnable(_eventTap, false);
}

static CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
//    if (mouseMoved == TRUE) {
//        setConfigVariablesForActiveApp();
//    }
    if (ScrollControl.scrollDirection == -1) {
        event = [ScrollUtility invertScrollEvent:event direction:ScrollControl.scrollDirection];
    }
    if (ScrollControl.magnificationScrolling) { //TODO: TODO: Consider acitvating displayLink to send magnification events instead (After sorting out activity states of SmoothScroll.m)
        [TouchSimulator postEventWithMagnification:CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1)/200.0 phase:kIOHIDEventPhaseChanged];
        return nil;
    } else {
        return event;
    }
}

@end
