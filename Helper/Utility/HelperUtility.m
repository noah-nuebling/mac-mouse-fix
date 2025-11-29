//
// --------------------------------------------------------------------------
// HelperUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <AppKit/AppKit.h>
#import "HelperUtility.h"
#import "Constants.h"
#import "ModificationUtility.h"
#import "Locator.h"
#import "SharedUtility.h"
#import "Logging.h"

@implementation HelperUtility

#pragma mark - Display under pointer

+ (CVReturn)displayUnderMousePointer:(CGDirectDisplayID *)dspID withEvent:(CGEventRef _Nullable)event {
    
    CGPoint mouseLocation = getPointerLocationWithEvent(event);
    return [self display:dspID atPoint:mouseLocation];
    
}

+ (CVReturn)display:(CGDirectDisplayID *)dspID atPoint:(CGPoint)point {
    
    /// Null-check
    if (!dspID) { assert(false); return kCVReturnError; }
    
    /// Get display
    const uint32_t maxDisplays = 1;
    uint32_t matchingDisplayCount; CGDirectDisplayID newDisplaysUnderMousePointer[maxDisplays];
    CGError err = CGGetDisplaysWithPoint(point, maxDisplays, newDisplaysUnderMousePointer, &matchingDisplayCount);
    if (err != kCGErrorSuccess) DDLogWarn(@"Getting display with point (%@) failed with error: %d",  NSStringFromPoint(point), err);
    
    if (matchingDisplayCount == 1) {
        /// Success
        CGDirectDisplayID d = CGDisplayPrimaryDisplay(newDisplaysUnderMousePointer[0]); /// Get the the master display in case `newDisplaysUnderMousePointer[0]` is part of a mirror set
        *dspID = d;
        return kCVReturnSuccess;
    }
    else if (matchingDisplayCount == 0) {
        /// Failure
        DDLogWarn(@"There are 0 diplays under the mouse pointer");
        *dspID = kCGNullDirectDisplay;
        return kCVReturnError; /// Returning 'error' here is stupid. Just seting the result dspID to nil is enough.
    }
    else {
        /// Impossible failure
        assert(false && "This should never ever happen");
        *dspID = kCGNullDirectDisplay;
        return kCVReturnError;
    }
}

#pragma mark - App under pointer

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
#pragma mark - Other

NSString *runningApplicationDescription(NSRunningApplication *app) {
    
    /// `.debugDescription` is not very helpful
    /// What we learn from this:
    ///     - If the `NSRunningApplication` is a single executable instead of an actual app bundle (This is the case for Minecraft and many other games), then the `bundleID` is nil, but the `bundleURL` and the `executableURL` both point to the executable.
    ///
    return [NSString stringWithFormat:@"pid: %d, executable: %@, bundle: %@, bundleID: %@, exposedBindings: %@", app.processIdentifier, app.executableURL, app.bundleURL, app.bundleIdentifier, app.exposedBindings];
}

+ (void)openMainApp {
    
    NSURL *bundleURL = Locator.mainAppBundle.bundleURL;
    [NSWorkspace.sharedWorkspace openURL:bundleURL];
    
    return;
    
    /// Old method from `AccessiblityCheck.m`
    
    NSArray<NSRunningApplication *> *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:kMFBundleIDApp];
    
    for (NSRunningApplication *app in apps) {
        [app activateWithOptions:NSApplicationActivateIgnoringOtherApps]; /// Note: `NSApplicationActivateIgnoringOtherApps` is deprecated under macOS 15 Sequoia, so it's good we're not using this anymore (as of Sep 2024)
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

/// Get modifier flags

CGEventFlags getModifierFlags(void) {
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

CGPoint getPointerLocationWithEvent(CGEventRef _Nullable locEvent) {
    
    /// This might get you a more up-to-date pointerLocation than getPointerLocation()
    ///     See notes below for more.
    
    if (locEvent == NULL) {
        return getPointerLocation();
    } else {
        return CGEventGetLocation(locEvent);
    }
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
 
 - getPointerLocation:               `0.000117s`
 - pointerLocationWithEvent:    `0.000015s`
 - pointerLocationNS:               `0.001375s`
 -> TODO: Test again now that we know to use CGEventSourceFlagsState() instead of CGEventCreate(NULL) to get current flags
 
 -> All of them are plenty fast. It shouldn't matter at all which I use from a performance standpoint.
    I think I got it in my head to use these `withEvent` functions because I had some troubles where I used an `eventLess` way to get modifier flags while implementing the remapping engine and that `eventLess` function caused some mean bug because it didn't provide completely up-to-date values. So it's valuable to have both `withEvent` and `eventLess` around. But I shouldn't think about performance when deciding what to use here
 -> NSEvent.mouseLocation is actually the slowest of the bunch, so there's no reason for us to use it at all.
 
 -> I deleted all the other pointer-location-gettings functions
 
 */



@end
