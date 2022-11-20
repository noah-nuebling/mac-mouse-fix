//
// --------------------------------------------------------------------------
// HelperUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <AppKit/AppKit.h>
#import "HelperUtility.h"
#import "Constants.h"
#import "ModificationUtility.h"
#import "WannabePrefixHeader.h"
#import "Locator.h"
#import "SharedUtility.h"

@implementation HelperUtility

+ (NSRunningApplication * _Nullable)appUnderMousePointerWithEvent:(CGEventRef _Nullable)event {
    
    ///
    /// Get PID under mouse pointer
    ///
    
    pid_t pidUnderPointer = -1; /// I hope -1 is actually unused?
    
    /// v New version. Should be a lot faster!
    
    NSPoint pointerLoc;
    if (event != NULL) {
        pointerLoc = getFlippedPointerLocationWithEvent(event);
    } else {
        pointerLoc = getFlippedPointerLocation();
    }
    
    CGWindowID windowNumber = (CGWindowID)[NSWindow windowNumberAtPoint:pointerLoc belowWindowWithWindowNumber:0];
    NSArray *windowInfo = (__bridge_transfer NSArray *)CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, windowNumber);
    if (windowInfo.count > 0) {
        pidUnderPointer = [windowInfo[0][(__bridge NSString *)kCGWindowOwnerPID] intValue];
    }
    
    if ((NO)) {
        
        /// v Old version. Uses AXUI API. Inspired by MOS' approach. AXUIElementCopyElementAtPosition() was incredibly slow sometimes. Right now it takes a second to return when scrolling on new Reddit in Safari on M1 Ventura Beta. On other windows and websites it's not noticably slow but still very slow in code terms.
        
//        CGPoint mouseLocation = getPointerLocation();
//        AXUIElementRef elementUnderMousePointer;
//        AXUIElementCopyElementAtPosition(Scroll.systemWideAXUIElement, mouseLocation.x, mouseLocation.y, &elementUnderMousePointer);
//        if (elementUnderMousePointer != nil) {
//            AXUIElementGetPid(elementUnderMousePointer, &pidUnderPointer);
//            CFRelease(elementUnderMousePointer);
//        }
    }
    
    /// Get runningApplication
    NSRunningApplication *appUnderMousePointer = [NSRunningApplication runningApplicationWithProcessIdentifier:pidUnderPointer];
    
    return appUnderMousePointer;
}

+ (void)openMainApp {
    
    NSURL *bundleURL = Locator.mainAppBundle.bundleURL;
    [NSWorkspace.sharedWorkspace openURL:bundleURL];
    
    return;
    
    /// Old method from `AccessiblityCheck.m`
    
    NSArray<NSRunningApplication *> *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:kMFBundleIDApp];
    
    for (NSRunningApplication *app in apps) {
        [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    }
}

+ (void)printEventFieldDifferencesBetween:(CGEventRef)event1 and:(CGEventRef)event2 {
    DDLogInfo(@"Field differences for event: %@, and event: %@", event1, event2);
    for (int field = 0; field < 256; field++) { /// I think there are only 256 fields, that's what we seem to have assumed in macos-touch-reverse-engineering
        int64_t value1 = CGEventGetIntegerValueField(event1, field);
        int64_t value2 = CGEventGetIntegerValueField(event2, field);
        if (value1 != value2) {
            DDLogInfo(@"%@: %@ vs %@", @(field), @(value1), @(value2));
        }
    }
}

+ (NSString *)binaryRepresentation:(int64_t)value {
    
    uint64_t one = 1; /// A literal 1 is apparently 32 bits, so we need to declare it here to make it 64 bits. Declaring as unsigned only to silence an error when shiftting this left by 63 places.
    
    int64_t nibbleCount = sizeof(value) * 2;
    NSMutableString *bitString = [NSMutableString stringWithCapacity:nibbleCount * 5];
    
    for (int64_t index = 4 * nibbleCount - 1; index >= 0; index--)
    {
        [bitString appendFormat:@"%i", value & (one << index) ? 1 : 0];
        if (index % 4 == 0)
        {
            [bitString appendString:@" "];
        }
    }
    return bitString;
}

/// Get modifier flags

CGEventFlags getModifierFlags() {
    CGEventRef flagEvent = CGEventCreate(NULL);
    CGEventFlags flags = CGEventGetFlags(flagEvent);
    CFRelease(flagEvent);
    return flags;
}

CGEventFlags getModifierFlagsWithEvent(CGEventRef flagEvent) {
    /// This might get you more up-to-date flags than getModifierFlags()
    ///     See notes below for more.
    
    CGEventFlags flags = CGEventGetFlags(flagEvent);
    return flags;
}

/// Get pointer location

CGPoint getPointerLocation(void) {
    CGEventRef locEvent = CGEventCreate(NULL);
    CGPoint mouseLoc = CGEventGetLocation(locEvent);
    CFRelease(locEvent);
    return mouseLoc;
}

CGPoint getPointerLocationWithEvent(CGEventRef locEvent) {
    /// This might get you a more up-to-date pointerLocation than getPointerLocation()
    ///     See notes below for more.
    
    CGPoint mouseLoc = CGEventGetLocation(locEvent);
    return mouseLoc;
}

NSPoint getFlippedPointerLocation(void) {
    CGPoint p = getPointerLocation();
    return [SharedUtility quartzToCocoaScreenSpace_Point:p];
}

NSPoint getFlippedPointerLocationWithEvent(CGEventRef locEvent) {
    CGPoint p = getPointerLocationWithEvent(locEvent);
    return [SharedUtility quartzToCocoaScreenSpace_Point:p];
}

/**
 I just did some performance testing on 3 functions to get pointer locations functions found in this file:
 For a thousand runs I got these times:
 
 - getPointerLocation: 0.000117s
 - pointerLocationWithEvent: 0.000015s
 - pointerLocationNS: 0.001375s
 
 -> All of them are plenty fast. It shouldn't matter at all which I use from a performance standpoint.
    I think I got it in my head to use these `withEvent` functions because I had some troubles where I used an `eventLess` way to get modifier flags while implementing the remapping engine and that `eventLess` function caused some mean bug because it didn't provide completely up-to-date values. So it's valuable to have both `withEvent` and `eventLess` around. But I shouldn't think about performance when deciding what to use here
 -> NSEvent.mouseLocation is actually the slowest of the bunch, so there's no reason for us to use it at all.
 
 -> I deleted all the other pointer-location-gettings functions
 
 */

@end
