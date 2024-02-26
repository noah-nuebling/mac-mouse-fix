//
// --------------------------------------------------------------------------
// Apps.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

///
/// We're creating the Apps class to speed up accessing of 
///

#import "AppUtilityObjC.h"
#import "SharedUtility.h"
@import AppKit.NSWindow;
#import "Locator.h"

@implementation AppUtilityObjC

+ (NSRunningApplication * _Nullable)getRunningAppWithPID:(pid_t)pid {
    
    /// Notes:
    /// - We implemented the same thing in AppUtility.swift and it seems faster - use that instead.
    
    assert(false);
    
    /// Create cache
    static NSMutableDictionary *_cache = nil;
    if (_cache == nil) {
        _cache = [NSMutableDictionary dictionary];
    }
    
    /// Create cache key
    NSNumber *cacheKey = @(pid);
    
    /// Look up in cache
    NSRunningApplication *result = nil;
    result = _cache[cacheKey];
    
    /// TODO: Check if the app instance is valid? or something?
    ///     Can the same pid be assigned to different processes while the computer is booted?
    
    /// Return cached
    if (result != nil) return result;
    
    /// Get fresh value
    result = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    
    /// Store in cache
    if (result != nil) {
        _cache[cacheKey] = result;
    }
    
    /// Return result
    return result;
}

pid_t getPIDUnderMousePointerObjC(CGPoint pointerLocCG) {
    
    /// Update: From my testing, the Swift implementation of this inside HelperState.swift seems to be faster and more consistent time-wise than this implementation! And that's even though we're using native C/ObjC APIs. First time I've seen Swift be faster than C/ObjC for something like this.
    
    /// Get the pid of the app that owns the window that would be hit if the user clicked at `pointerLocCG`
    
    assert(false);
    
    NSPoint pointerLoc = [SharedUtility quartzToCocoaScreenSpace_Point:pointerLocCG];
    
    CGWindowID windowID = (CGWindowID)[NSWindow windowNumberAtPoint:pointerLoc belowWindowWithWindowNumber:0];
    
    if (windowID == kCGNullWindowID) {
        return kMFInvalidPID;
    }
    
    /// Get windowInfo using NS apis
    
//    NSArray<NSDictionary *> *windowInfoArray = (__bridge_transfer NSArray*)CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, windowID);
//    NSDictionary *windowInfo = windowInfoArray.firstObject;
    
    /// Get windowInfo using CG apis
    ///     And using CGWindowListCreateDescriptionFromArray()
    ///     -> Conclusion seems to be slower than the NS API stuff.
    
    const void *windowIDArrr[] = { (const void *)(long)windowID };
    CFArrayRef windowIDArray = CFArrayCreate(kCFAllocatorDefault, windowIDArrr, 1, NULL);
    CFArrayRef windowInfoArray = CGWindowListCreateDescriptionFromArray(windowIDArray);
    NSDictionary *windowInfo = nil;
    if (CFArrayGetCount(windowInfoArray) >= 1) {
        windowInfo = (__bridge NSDictionary *)CFArrayGetValueAtIndex(windowInfoArray, 0);
    }
    
    CFRelease(windowIDArray);
    CFRelease(windowInfoArray);
    
    if (windowInfo == nil) {
        return kMFInvalidPID;
    }
    
    NSNumber *pidNS = windowInfo[(__bridge NSString *)kCGWindowOwnerPID];
    if (pidNS == nil) {
        return kMFInvalidPID;
    }
    
    pid_t pid = pidNS.intValue;
    
    return pid;
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

NSString *runningApplicationDescription(NSRunningApplication *app) {
    
    /// `.debugDescription` is not very helpful
    /// What we learn from this:
    ///     - If the `NSRunningApplication` is a single executable instead of an actual app bundle (This is the case for Minecraft and many other games), then the `bundleID` is nil, but the `bundleURL` and the `executableURL` both point to the executable.
    ///
    return [NSString stringWithFormat:@"pid: %d, executable: %@, bundle: %@, bundleID: %@, exposedBindings: %@", app.processIdentifier, app.executableURL, app.bundleURL, app.bundleIdentifier, app.exposedBindings];
}

@end
