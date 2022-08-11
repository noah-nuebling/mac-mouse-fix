//
// --------------------------------------------------------------------------
// EventUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "WannabePrefixHeader.h"

#import "EventUtility.h"
#import "MFHIDEventImports.h"
#import "IOUtility.h"
#import "SharedUtility.h"
#import "CGEventHIDEventBridge.h"

@implementation EventUtility

extern CFTimeInterval CATimeWithHostTime(UInt64 mach_absolute_time); /// I saw this in assembly but linking failed I think -> remove

#pragma mark - Sending device

NSMutableDictionary *_hidDeviceCache = nil;

IOHIDDeviceRef _Nullable CGEventGetSendingDevice(CGEventRef cgEvent) {
    /// Sometimes CGEventGetHIDEvent() doesn't work. I observed this in the `PollingRateMeasurer` where it doesn't work for mouseDragged events. (Only mouseMoved). This works for `mouseDragged` events as well! -> Use this instead of `HIDEventGetSendingDevice()` as long as `CGEventGetHIDEvent()` isn't reliable.
    
    /// Main Logic
    int64_t senderFieldValue = CGEventGetIntegerValueField(cgEvent, 87);
    uint64_t senderID;
    memcpy(&senderID, &senderFieldValue, sizeof(int64_t));
    
    if (senderID == 0) {
        assert(false);
    }
    return getSendingDeviceWithSenderID(senderID);
}

IOHIDDeviceRef _Nullable HIDEventGetSendingDevice(HIDEvent *hidEvent) {
    /// This version uses a cache to avoid calling IOHIDDeviceCreate() (which is super slow) over and over.
    ///     \note Do we need to reset the cache at certain points?
    
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
    
    
    if (_hidDeviceCache == nil) {
        _hidDeviceCache = [NSMutableDictionary dictionary];
    }
    
    id iohidDeviceFromCache = _hidDeviceCache[@(senderID)];
    
    if (iohidDeviceFromCache != nil) {
        return (__bridge IOHIDDeviceRef)iohidDeviceFromCache;
    }
    
    IOHIDDeviceRef iohidDevice = copySendingDevice_Reliable(senderID);
    assert(iohidDevice != NULL);
    
    _hidDeviceCache[@(senderID)] = (__bridge_transfer id _Nullable)(iohidDevice);
    
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
    IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent1);
    IORegistryEntryGetParentEntry(parent1, kIOServicePlane, &parent2);
    
    IOHIDDeviceRef iohidDevice = IOHIDDeviceCreate(kCFAllocatorDefault, parent2);
    
    IOObjectRelease(parent1);
    IOObjectRelease(parent2);
    
    return iohidDevice;
}

IOHIDDeviceRef copySendingDevice_Reliable(uint64_t senderID) {
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
    
    assert(iohidDevice != NULL);
    
    return iohidDevice;
}

#pragma mark - Timestamps

CFTimeInterval CGEventGetTimestampInSeconds(CGEventRef event) {
    /// Gets timestamp in seconds from CGEvent. More accurate and less volatile than calling CACurrentMediaTime() in the eventTapCallback.
    ///     I've found that this doesn't work for mouseMoved events in PollingRateMeasurer. Those timestamps are already in nanosecs. No idea why.
    
    /// Stuff below doesn't work properly ;?
    
    /// Get raw mach timestamp
    CGEventTimestamp tsMach = CGEventGetTimestamp(event);
    
    /// Get the timebase info
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    
    /// Convert to nanoseconds
    double tsNano = tsMach;
    tsNano *= info.numer;
    tsNano /= info.denom;
    
    /// Convert to seconds
    CFTimeInterval tsSeconds = tsNano / NSEC_PER_SEC;
    
    return tsSeconds;
    
    if (/* DISABLES CODE */ (NO)) {
        
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

@end
