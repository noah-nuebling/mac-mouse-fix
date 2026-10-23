//
// --------------------------------------------------------------------------
// universalControlTest.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2026
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//


#import <Foundation/Foundation.h>
#import <CoreGraphics/CGEvent.h>

static CFMachPortRef _eventTap = NULL;

static CGEventRef __nullable eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef  event, void * __nullable userInfo) {

    if (type == kCGEventTapDisabledByTimeout) { CGEventTapEnable(_eventTap, true); return event; }
    if (type == kCGEventTapDisabledByUserInput) { return event; }

    /// Print events
    ///     Findings: Universal control events from other MacBook arrive at the earliest `kCGHIDEventTap` - MMF is already receiving them [Oct 2026]
    if ((1))
        printf("type: %d\n", type);

    return event;
}
int universalControlTest_Start(void) {

    _eventTap = CGEventTapCreate(kCGSessionEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, kCGEventMaskForAllEvents, eventTapCallback, /*userInfo*/NULL);
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, /*order*/0);
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopCommonModes);

    while (1) CFRunLoopRun();

    return 0;
}
