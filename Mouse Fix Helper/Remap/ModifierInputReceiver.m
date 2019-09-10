//
// --------------------------------------------------------------------------
// ModifierInputReceiver.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ModifierInputReceiver.h"
#import "SmoothScroll.h"

@implementation ModifierInputReceiver

CFMachPortRef _eventTapKey;

+ (void)initialize {
    setupModifierKeyCallback();
}
+ (void)start {
    CGEventTapEnable(_eventTapKey, true);
}
+ (void)stop {
    CGEventTapEnable(_eventTapKey, false);
}

static void setupModifierKeyCallback() {
    /* Register event Tap Callback */
    CGEventMask mask = CGEventMaskBit(kCGEventFlagsChanged);
    _eventTapKey = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, mask, Handle_ModifierChanged, NULL);
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTapKey, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    CFRelease(runLoopSource);
}

CGEventRef Handle_ModifierChanged(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    CGEventFlags flags = CGEventGetFlags(event);
    
    if (flags & kCGEventFlagMaskShift) {    // I used 1 << 17 here - should be the same as kCGEventFlagMaskShift, idk why I didn't use that instead
        [SmoothScroll setHorizontalScroll:TRUE];
    } else {
        [SmoothScroll setHorizontalScroll:FALSE];
    }
    
    /*
     if (flags & kCGEventFlagMaskSecondaryFn) {
     [MomentumScroll temporarilyDisable:TRUE];
     } else {
     [MomentumScroll temporarilyDisable:FALSE];
     }
     */
    
    return event;
}

@end
