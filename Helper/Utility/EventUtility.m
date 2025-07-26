//
// --------------------------------------------------------------------------
// EventUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//


#import "EventUtility.h"
#import "MFHIDEventImports.h"
#import "IOUtility.h"
#import "SharedUtility.h"
#import "CGEventHIDEventBridge.h"
#import "VectorUtility.h"
#import "Logging.h"

#import "libproc.h"

@implementation EventUtility

extern CFTimeInterval CATimeWithHostTime(UInt64 mach_absolute_time); /// I saw this in assembly but linking failed I think. Update: We built our own implementation of this at SharedUtility > machTimeToSeconds()

#pragma mark - Scroll Events

int64_t fixedScrollDelta(double scrollDelta) {
    /// We round instead of just truncating because that makes the values look more like real scrollWheel values. Probably doesn't make a difference.
    return (int64_t)round(scrollDelta * pow(2, 16));
}

#pragma mark - Event filtering

bool CGEvent_IsWacomEvent(CGEventRef event) {
    
    /// Determine if event comes from Wacom device
    /// Discussion:
    ///     - This is used in the eventTapCallback of `Scroll.m` [Jul 2025]
    ///     - This is aimed at fixing interference with Wacom Tablets. Should solve https://github.com/noah-nuebling/mac-mouse-fix/issues/1233
    ///     - Testing results: This successfully fixes scrolling in my testing. I didn't test other wacom features. The driver always crashed when I tried to send keyboard shortcuts via the ExpressKeys.
    ///         Tested: Wacom Intuos S CTL-4100, Tablet Driver Version 6.4.10-3, macOS Sequoia 15.5, Intel Mac Mini 2018
    ///     - Scope and Long term plans:
    ///         - I'm not applying this in ButtonInputReceiver.m since I don't know of any specific issues there, and I don't wanna cause accidental regressions – this is supposed to be a hotfix. [Jul 2025]
    ///         - I think generally, intercepting button events from a userspace driver (like the Wacom one) shouldn't cause issues – while intercepting (and then trying to smooth and accelerate) scroll events is more likely to cause issues. (but might be totally wrong.) Based on this I thought it might make sense to ignore all scroll events that appear to come from a userspace driver – but I'm not sure and I don't wanna cause accidental regresssions, so I'm keeping it Wacom-specific for now [Jul 2025]
    ///             - We should probably also be ignoring non-wacom drawing tablets though.
    ///         - In `ButtonInputReceiver.m` I also discuss the idea of just filtering events based on attachedDevices – that feels like the simplest, most robust approach in a way, but I don't wanna change architecture now [Jul 2025]
    ///     - Caching & Performance:
    ///         - Running this on every scrollEvent produced by my Wacom Intuos S (which I think must be at least 60 fps) on 2018 Intel Mac Mini has pretty small CPU impact. IIRC ~0.3 without caching, and ~0.1 with caching.
    ///         - I disabled caching, cause I was worried about the small chance of the cache becoming stale due to pid reuse (pid was the cacheKey). I hadn't really thought that through though.
    ///     - How do other apps do this?
    ///         I looked at LinearMouse and MOS source code to see if they're filtering drawing tablets, but I couldn't see anything specific.
    ///         Update: [Jul 2025] Tested the Wacom with MOS and scrolling got super fast – so no filtering in place.
    ///     Also see:
    ///         - `EventLoggerForBrad > Investigate_Wacom.m`
    ///             -> Here we found that looking at the sender fields is probably the only reliable way to differentiate the Wacom's scroll events. Field 102 was also interesting – it always contained 63
    ///         - Other notes and code about event-filtering in `ButtonInputReceiver.m` and `Scroll.m`
    
    /// Get sender pid
    ///     Meta: I think presence of a pid generally indicates that the event has been generated artificially by a userspace driver, instead of by a IOKit/DriverKit driver (I think, I haven't tested this much, but this is how things look comparing Wacom driver's scroll events vs real mouse scroll events. [Jul 2025])
    int64_t sender_pid = CGEventGetIntegerValueField(event, kCGEventSourceUnixProcessID);
    if (!sender_pid) return false;
    
    /// Sanity check
    ///     Presence of `kMFCGEventFieldSenderID` indicates an ioreg sender while `kCGEventSourceUnixProcessID` indicates a userspace sender. I don't expect both to be present
    assert(CGEventGetIntegerValueField(event, (CGEventField)kMFCGEventFieldSenderID) == 0);
    
    /// Calculate
    NSString *senderPath = GetPathForPid((pid_t)sender_pid);
    bool result = [[[senderPath lastPathComponent] lowercaseString] containsString: @"wacom"]; /// Specifically, we saw the `Wacom_IOManager` process send the events. [Jul 2025]
    
    /// Return
    return result;
}

NSString *_Nullable GetPathForPid(pid_t sender_pid) {
    
    /// Meta: This doesn't really belong in EventUtility.m [Jul 2025]
    
    /// Get pid's executable path
    ///     Discussion on using `proc_pidpath`: [Jul 2025]
    ///         - This API is totally undocumented and finnicky, but I can't find a better option.
    ///         - It has 0 documentation that  I could find, but there are some SO posts about it. Also XNU source code and tests show how to use it.
    ///         - `NSRunningApplication` is nicer but can't find `Wacom_IODriver` process. (Can it only find processes running in an app bundle? I thought otherwise, but memory is fuzzy.)
    ///         - I also tried the simpler `proc_name()` function, but it's seems to have a 32 char limit
    ///     Safety:
    ///         - I tested entering an invalid pid, and our error-handling works.
    
    /// Calculate result
    char sender_path[PROC_PIDPATHINFO_MAXSIZE];
    int sender_path_len = proc_pidpath(sender_pid, sender_path, sizeof(sender_path));
    
    /// Handle errors
    if (sender_path_len <= 0) {
        DDLogError(@"Getting path for event sender pid %u failed with error: %s", sender_pid, strerror(errno));
        return nil;
    }
    
    /// Return
    NSString *result = @(sender_path);
    return result;
}

#pragma mark - Sending device

IOHIDDeviceRef _Nullable CGEventGetSendingDevice(CGEventRef cgEvent) {
    /// Sometimes CGEventGetHIDEvent() doesn't work. I observed this in the `PollingRateMeasurer` where it doesn't work for mouseDragged events. (Only mouseMoved). This works for `mouseDragged` events as well! -> Use this instead of `HIDEventGetSendingDevice()` as long as `CGEventGetHIDEvent()` isn't reliable.
    /// When the event is artificially generated by another program. (E.g. by MiddleClick-Ventura), then the senderID field is 0. In that case, we just return NULL.
    
    /// Main Logic
    int64_t senderFieldValue = CGEventGetIntegerValueField(cgEvent, (CGEventField)kMFCGEventFieldSenderID);
    uint64_t senderID;
    memcpy(&senderID, &senderFieldValue, sizeof(int64_t));
    
    if (senderID == 0) {
        return NULL;
    }
    return getSendingDeviceWithSenderID(senderID);
}

IOHIDDeviceRef _Nullable HIDEventGetSendingDevice(HIDEvent *hidEvent) {
    
    assert(hidEvent != NULL);
    if (hidEvent == NULL) return NULL;
    
    uint64_t senderID;
    
    if ([hidEvent respondsToSelector:@selector(senderID)]) {
        senderID = hidEvent.senderID;
    } else {
        senderID = IOHIDEventGetSenderID((__bridge IOHIDEventRef)hidEvent);
    }
    /// ^ Sometimes `- senderID` gives an unrecognized selector error. Only when I'm not starting the app via the debugger though. Weird. IOHIDEventGetSenderID() works in those cases. Even though `- senderID` just calls it. Really weird.
    
    return getSendingDeviceWithSenderID(senderID);
}

IOHIDDeviceRef _Nullable getSendingDeviceWithSenderID(uint64_t senderID) {
    
    /// Pass in the senderID obtained from a CGEvent from field 87
    ///     This uses a cache to avoid calling IOHIDDeviceCreate() (which is super slow) over and over.
    ///     \note Do we need to reset the cache at certain points? What do if a device is disconnected?
    ///         Update: [May 2025] Just saw a crash which might be related to not resetting the cache. See Scroll.m:279 for more.
    ///             But theoretically this should be fine I think? I think IOHIDDeviceRef should still be safe to use after disconnect, just if you try to read/write from it that should fail (I haven't tested this, and it would still be cleaner to return nil here after disconnect)
    ///                 We could either use a weak reference or check if the IOHIDDeviceRef is still physically connected  before returning it. For a weak ref, we could create something like an MFWeakWrapper object or use NSMapTable with weak values. Using NSCache / staticobject() / threadobject() instead of raw static NSDictionary would probably be good. (static NSDictionary is also not thread-safe – as long as we're not using a single 'IOThread', that could be problematic.)
    
    static NSMutableDictionary *_hidDeviceCache = nil;
    if (_hidDeviceCache == nil) {
        _hidDeviceCache = [NSMutableDictionary dictionary];
    }
    
    id iohidDeviceFromCache = _hidDeviceCache[@(senderID)];
    
    if (iohidDeviceFromCache != nil) {
        return (__bridge IOHIDDeviceRef)iohidDeviceFromCache;
    }
    
    IOHIDDeviceRef iohidDevice = copySendingDevice_Reliable(senderID);
    
    _hidDeviceCache[@(senderID)] = (__bridge_transfer id _Nullable)(iohidDevice); /// Should we do this when the iohidDevice is NULL? || [May 2025] Setting nil to an NSDictionary like this should simply remove the key. Casting to `_Nullable` here makes no sense.
    
    return iohidDevice;
}

IOHIDDeviceRef copySendingDevice_Faster(uint64_t senderID) {
    /// This gets the second parent of the registryEntry that sent the hidEvent. If that doesn't work, it returns NULL.
    /// This is still super slow because IOHIDDeviceCreate() is super slow
    /// -> Just use `_Reliable` instead. Once a device is cached, it's plenty fast anyways.
    
    
    /// Get IOService
    CFMutableDictionaryRef idMatching = IORegistryEntryIDMatching(senderID);
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, idMatching);
    
    io_service_t parent1;
    io_service_t parent2;
    IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent1); /// Why are we return the return values here?
    IORegistryEntryGetParentEntry(parent1, kIOServicePlane, &parent2);
    
    IOHIDDeviceRef iohidDevice = IOHIDDeviceCreate(kCFAllocatorDefault, parent2);
    
    IOObjectRelease(parent1);
    IOObjectRelease(parent2);
    
    return iohidDevice;
}

IOHIDDeviceRef _Nullable copySendingDevice_Reliable(uint64_t senderID) {
    /// This iterates all parents of the service which send the hidEvent until it finds one that it can convert to and IOHIDDevice.
    /// Calling IOHIDDeviceCreate() on all these non-hid device is super slow unfortunately.
    
    /// Get IOService
    CFMutableDictionaryRef idMatching = IORegistryEntryIDMatching(senderID);
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, idMatching);
    
    /// Get IOHIDDevice
    __block IOHIDDeviceRef iohidDevice;
    [IOUtility iterateParentsOfEntry:service forEach:^Boolean(io_registry_entry_t parent) {
        iohidDevice = IOHIDDeviceCreate(kCFAllocatorDefault, parent);
        return (iohidDevice == NULL); /// Keep going while device not found
    }];
    
    /// Validate
    if (runningPreRelease()) {
        BOOL isTakingLocalizationScreenshots = [NSProcessInfo.processInfo.arguments containsObject:@"-MF_ANNOTATE_LOCALIZED_STRINGS"];
        if (!isTakingLocalizationScreenshots) {
            assert(iohidDevice != NULL); /// NULL for events sent by localizedScreenshot XCUITest runner, otherwise shouldn't be NULL.
        }
    }
    
    /// Return
    return iohidDevice;
}

#pragma mark - Timestamps

CFTimeInterval CGEventGetTimestampInSeconds(CGEventRef event) {
    
    /// Gets timestamp in seconds from CGEvent. More accurate and less volatile than calling CACurrentMediaTime() in the eventTapCallback.
    ///     I've found that this doesn't work for for some events like mouseMoved events in PollingRateMeasurer. Those timestamps are already in nanosecs instead of mach time
    
    /// Get raw mach timestamp
    CGEventTimestamp tsMach = CGEventGetTimestamp(event);
    
    /// Convert
    CFTimeInterval tsSeconds = machTimeToSeconds(tsMach);
    
    return tsSeconds;
    
    if (/* DISABLES CODE */ (false)) {
        
        CFTimeInterval tickTimeCG = (100/2.4)*tsMach/NSEC_PER_SEC;
        /// ^ The docs say that CGEventGetTimestamp() is in nanoseconds, no idea where the extra (100/2.4) factor comes from. But it works, to make it scaled the same as CACurrentMediaTime()
        ///     I hope this also works on other macOS versions?
        /// Edit: We should to use mach_timebase_info() to convert insteads of 100/2.4
        
        /// Debug
        
        CFTimeInterval tickTime = CACurrentMediaTime();
        /// ^ This works but is less accurate than getting the time from the CGEvent
        
        static CFTimeInterval lastTickTime = 0;
        static CFTimeInterval lastTickTimeCG = 0;
        double tickPeriod = 0;
        double tickPeriodCG = 0;
        if (lastTickTime != 0) {
            tickPeriod = tickTime - lastTickTime;
            tickPeriodCG = tickTimeCG - lastTickTimeCG;
        }
        lastTickTime = tickTime;
        lastTickTimeCG = tickTimeCG;
        static double pSum = 0;
        static double pSumCG = 0;
        pSum += tickPeriod;
        pSumCG += tickPeriodCG;
        DDLogDebug(@"tickPeriod: %.3f, CG: %.3f", tickPeriod*1000, tickPeriodCG*1000);
        DDLogDebug(@"ticksPerSec: %.3f, CG: %.3f", 1/tickPeriod, 1/tickPeriodCG);
        DDLogDebug(@"tickPeriodSum: %.0f, CG: %.0f, ratio: %.5f", pSum, pSumCG, pSumCG/pSum);
    }
}



NSString *scrollEventDescription(CGEventRef scrollEvent) {
    return scrollEventDescriptionWithOptions(scrollEvent, YES, YES);
}
NSString *scrollEventDescriptionWithOptions(CGEventRef scrollEvent, BOOL allDeltas, BOOL phases) {
    
    ///
    /// Gather info
    ///
    
    /// Gather deltas
    
    double delta1 = CGEventGetDoubleValueField(scrollEvent, 11); /// 11 -> kCGScrollWheelEventDeltaAxis1
    double point1 = CGEventGetDoubleValueField(scrollEvent, 96); /// 96 -> kCGScrollWheelEventPointDeltaAxis1
    double fixedPt1 = CGEventGetDoubleValueField(scrollEvent, 93); /// 93 -> kCGScrollWheelEventFixedPtDeltaAxis1
    
    double delta2 = CGEventGetDoubleValueField(scrollEvent, 12); /// 12 -> kCGScrollWheelEventDeltaAxis2
    double point2 = CGEventGetDoubleValueField(scrollEvent, 97); /// 97 -> kCGScrollWheelEventPointDeltaAxis2
    double fixedPt2 = CGEventGetDoubleValueField(scrollEvent, 94); /// 94 -> kCGScrollWheelEventFixedPtDeltaAxis2
    
    /// Put deltas together
    
    Vector delta = (Vector){ .x = delta2, .y = delta1 };
    Vector point = (Vector){ .x = point2, .y = point1 };
    Vector fixedPt = (Vector){ .x = fixedPt2, .y = fixedPt1 };
    
    /// Gather phases
    int64_t phase = CGEventGetIntegerValueField(scrollEvent, kCGScrollWheelEventScrollPhase);
    int64_t momentumPhase = CGEventGetIntegerValueField(scrollEvent, kCGScrollWheelEventMomentumPhase);
    
    /// Assemble result string
    NSString *description = @"";
    description = [description stringByAppendingFormat:@"point: %@", vectorDescription(delta)];
    if (allDeltas) {
        description = [description stringByAppendingFormat:@" \t line: %@ \t fixed: %@", vectorDescription(point), vectorDescription(fixedPt)];
    }
    if (phases) {
        description = [description stringByAppendingFormat:@", \t phases: (%lld, %lld)", phase, momentumPhase];
    }
    
    /// Return
    return description;
}

@end
